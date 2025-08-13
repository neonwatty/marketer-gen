import { PrismaClient, AuditExportType, AuditExportStatus } from '@prisma/client'
import { writeFile, mkdir } from 'fs/promises'
import { join } from 'path'
import { format } from 'date-fns'

export interface ExportConfig {
  exportType: AuditExportType
  format: 'csv' | 'json' | 'pdf' | 'xlsx'
  filters: {
    dateFrom?: Date
    dateTo?: Date
    eventTypes?: string[]
    eventCategories?: string[]
    entityTypes?: string[]
    severities?: string[]
    userIds?: string[]
    includePersonalData?: boolean
  }
  options: {
    includeMetadata?: boolean
    includeChanges?: boolean
    compressOutput?: boolean
    splitByDate?: boolean
    maxRecordsPerFile?: number
  }
  requestedBy: string
}

export interface ExportResult {
  exportId: string
  status: AuditExportStatus
  filename?: string
  fileUrl?: string
  fileSize?: number
  recordCount: number
  error?: string
  createdAt: Date
  completedAt?: Date
}

export class AuditExportManager {
  private prisma: PrismaClient
  private exportDir: string

  constructor(prisma: PrismaClient, exportDir = './exports/audit') {
    this.prisma = prisma
    this.exportDir = exportDir
  }

  /**
   * Start an audit log export
   */
  async startExport(config: ExportConfig): Promise<string> {
    // Create export record
    const exportRecord = await this.prisma.auditExport.create({
      data: {
        exportType: config.exportType,
        status: AuditExportStatus.PENDING,
        filters: JSON.stringify(config.filters),
        dateRange: JSON.stringify({
          from: config.filters.dateFrom,
          to: config.filters.dateTo
        }),
        format: config.format,
        requestedBy: config.requestedBy,
        metadata: JSON.stringify(config.options)
      }
    })

    // Start async export process
    this.processExport(exportRecord.id, config).catch(error => {
      console.error(`Export ${exportRecord.id} failed:`, error)
      this.updateExportStatus(exportRecord.id, AuditExportStatus.FAILED, error.message)
    })

    return exportRecord.id
  }

  /**
   * Get export status and details
   */
  async getExport(exportId: string): Promise<ExportResult | null> {
    const exportRecord = await this.prisma.auditExport.findUnique({
      where: { id: exportId }
    })

    if (!exportRecord) return null

    return {
      exportId: exportRecord.id,
      status: exportRecord.status,
      filename: exportRecord.filename || undefined,
      fileUrl: exportRecord.fileUrl || undefined,
      fileSize: exportRecord.fileSize || undefined,
      recordCount: 0, // Would be calculated during export
      error: exportRecord.errorMessage || undefined,
      createdAt: exportRecord.createdAt,
      completedAt: exportRecord.completedAt || undefined
    }
  }

  /**
   * Get list of exports for a user
   */
  async getUserExports(userId: string, limit = 50): Promise<ExportResult[]> {
    const exports = await this.prisma.auditExport.findMany({
      where: { requestedBy: userId },
      orderBy: { createdAt: 'desc' },
      take: limit
    })

    return exports.map(exp => ({
      exportId: exp.id,
      status: exp.status,
      filename: exp.filename || undefined,
      fileUrl: exp.fileUrl || undefined,
      fileSize: exp.fileSize || undefined,
      recordCount: 0,
      error: exp.errorMessage || undefined,
      createdAt: exp.createdAt,
      completedAt: exp.completedAt || undefined
    }))
  }

  /**
   * Process an export asynchronously
   */
  private async processExport(exportId: string, config: ExportConfig): Promise<void> {
    await this.updateExportStatus(exportId, AuditExportStatus.PROCESSING)

    try {
      // Build query
      const where = this.buildWhereClause(config.filters)
      
      // Get data in batches
      const batchSize = config.options.maxRecordsPerFile || 10000
      let skip = 0
      let hasMore = true
      let totalRecords = 0
      const files: string[] = []

      while (hasMore) {
        const logs = await this.prisma.auditLog.findMany({
          where,
          orderBy: { createdAt: 'desc' },
          skip,
          take: batchSize,
          select: {
            id: true,
            createdAt: true,
            eventType: true,
            eventCategory: true,
            entityType: true,
            entityId: true,
            action: true,
            description: true,
            userId: true,
            username: true,
            userRole: true,
            sessionId: true,
            ipAddress: true,
            userAgent: true,
            referrer: true,
            requestId: true,
            oldValues: config.options.includeChanges ? true : false,
            newValues: config.options.includeChanges ? true : false,
            changedFields: config.options.includeChanges ? true : false,
            hostname: true,
            environment: true,
            applicationVersion: true,
            metadata: config.options.includeMetadata ? true : false,
            tags: true,
            severity: true,
            isPersonalData: true,
            duration: true
          }
        })

        if (logs.length === 0) {
          hasMore = false
          break
        }

        // Generate filename
        const timestamp = format(new Date(), 'yyyy-MM-dd-HHmmss')
        const fileIndex = config.options.splitByDate ? skip / batchSize : 0
        const filename = `audit-export-${exportId}-${timestamp}${fileIndex > 0 ? `-${fileIndex}` : ''}.${config.format}`
        
        // Process and save file
        const filePath = await this.generateFile(logs, config, filename)
        files.push(filePath)

        totalRecords += logs.length
        skip += batchSize

        if (logs.length < batchSize) {
          hasMore = false
        }
      }

      // If multiple files and compression is enabled, create archive
      let finalFilePath: string
      if (files.length > 1 && config.options.compressOutput) {
        finalFilePath = await this.createArchive(files, exportId)
      } else {
        finalFilePath = files[0]
      }

      // Get file stats
      const stats = await this.getFileStats(finalFilePath)

      // Update export record
      await this.prisma.auditExport.update({
        where: { id: exportId },
        data: {
          status: AuditExportStatus.COMPLETED,
          filename: this.getFilenameFromPath(finalFilePath),
          fileUrl: this.generateDownloadUrl(finalFilePath),
          fileSize: stats.size,
          completedAt: new Date()
        }
      })

    } catch (error) {
      await this.updateExportStatus(
        exportId, 
        AuditExportStatus.FAILED, 
        error instanceof Error ? error.message : 'Unknown error'
      )
      throw error
    }
  }

  /**
   * Generate export file in specified format
   */
  private async generateFile(
    logs: any[], 
    config: ExportConfig, 
    filename: string
  ): Promise<string> {
    // Ensure export directory exists
    await mkdir(this.exportDir, { recursive: true })
    
    const filePath = join(this.exportDir, filename)

    // Process logs to remove JSON strings and handle personal data
    const processedLogs = logs.map(log => {
      const processed = { ...log }
      
      // Parse JSON fields
      if (processed.oldValues) {
        try {
          processed.oldValues = JSON.parse(processed.oldValues)
        } catch {}
      }
      if (processed.newValues) {
        try {
          processed.newValues = JSON.parse(processed.newValues)
        } catch {}
      }
      if (processed.changedFields) {
        try {
          processed.changedFields = JSON.parse(processed.changedFields)
        } catch {}
      }
      if (processed.metadata) {
        try {
          processed.metadata = JSON.parse(processed.metadata)
        } catch {}
      }
      if (processed.tags) {
        try {
          processed.tags = JSON.parse(processed.tags)
        } catch {}
      }

      // Handle personal data
      if (processed.isPersonalData && !config.filters.includePersonalData) {
        processed.username = '[REDACTED]'
        processed.ipAddress = '[REDACTED]'
        processed.userAgent = '[REDACTED]'
        processed.oldValues = '[REDACTED]'
        processed.newValues = '[REDACTED]'
        processed.metadata = '[REDACTED]'
      }

      return processed
    })

    switch (config.format) {
      case 'json':
        await writeFile(filePath, JSON.stringify(processedLogs, null, 2))
        break

      case 'csv':
        const csv = this.convertToCSV(processedLogs)
        await writeFile(filePath, csv)
        break

      case 'xlsx':
        // Would require xlsx library
        throw new Error('XLSX export not implemented')

      case 'pdf':
        // Would require PDF generation library
        throw new Error('PDF export not implemented')

      default:
        throw new Error(`Unsupported export format: ${config.format}`)
    }

    return filePath
  }

  /**
   * Convert data to CSV format
   */
  private convertToCSV(data: any[]): string {
    if (data.length === 0) return ''

    // Get all unique keys
    const keys = new Set<string>()
    data.forEach(item => {
      Object.keys(item).forEach(key => keys.add(key))
    })

    const headers = Array.from(keys)
    const csvHeaders = headers.map(this.escapeCSVField).join(',')

    const csvRows = data.map(item => {
      return headers.map(header => {
        const value = item[header]
        if (value === null || value === undefined) return ''
        
        // Handle complex objects
        if (typeof value === 'object') {
          return this.escapeCSVField(JSON.stringify(value))
        }
        
        return this.escapeCSVField(String(value))
      }).join(',')
    })

    return [csvHeaders, ...csvRows].join('\n')
  }

  /**
   * Escape CSV field
   */
  private escapeCSVField(field: string): string {
    if (field.includes(',') || field.includes('"') || field.includes('\n')) {
      return `"${field.replace(/"/g, '""')}"`
    }
    return field
  }

  /**
   * Create archive from multiple files
   */
  private async createArchive(files: string[], exportId: string): Promise<string> {
    // For now, just return the first file
    // In production, you'd create a zip archive
    return files[0]
  }

  /**
   * Get file statistics
   */
  private async getFileStats(filePath: string) {
    const fs = await import('fs/promises')
    const stat = await fs.stat(filePath)
    return { size: stat.size }
  }

  /**
   * Extract filename from path
   */
  private getFilenameFromPath(filePath: string): string {
    return filePath.split('/').pop() || 'export'
  }

  /**
   * Generate download URL
   */
  private generateDownloadUrl(filePath: string): string {
    const filename = this.getFilenameFromPath(filePath)
    return `/api/audit/exports/download/${filename}`
  }

  /**
   * Build where clause from filters
   */
  private buildWhereClause(filters: ExportConfig['filters']): any {
    const where: any = {}

    // Date range
    if (filters.dateFrom || filters.dateTo) {
      where.createdAt = {}
      if (filters.dateFrom) where.createdAt.gte = filters.dateFrom
      if (filters.dateTo) where.createdAt.lte = filters.dateTo
    }

    // Array filters
    if (filters.eventTypes?.length) {
      where.eventType = { in: filters.eventTypes }
    }
    if (filters.eventCategories?.length) {
      where.eventCategory = { in: filters.eventCategories }
    }
    if (filters.entityTypes?.length) {
      where.entityType = { in: filters.entityTypes }
    }
    if (filters.severities?.length) {
      where.severity = { in: filters.severities }
    }
    if (filters.userIds?.length) {
      where.userId = { in: filters.userIds }
    }

    // Personal data filter
    if (!filters.includePersonalData) {
      where.OR = [
        { isPersonalData: false },
        { isPersonalData: true, anonymizedAt: { not: null } }
      ]
    }

    return where
  }

  /**
   * Update export status
   */
  private async updateExportStatus(
    exportId: string, 
    status: AuditExportStatus, 
    errorMessage?: string
  ): Promise<void> {
    await this.prisma.auditExport.update({
      where: { id: exportId },
      data: {
        status,
        errorMessage,
        ...(status === AuditExportStatus.PROCESSING && { startedAt: new Date() }),
        ...(status === AuditExportStatus.COMPLETED && { completedAt: new Date() })
      }
    })
  }

  /**
   * Clean up old export files
   */
  async cleanupOldExports(olderThanDays = 30): Promise<number> {
    const cutoffDate = new Date()
    cutoffDate.setDate(cutoffDate.getDate() - olderThanDays)

    const oldExports = await this.prisma.auditExport.findMany({
      where: {
        createdAt: { lt: cutoffDate },
        status: AuditExportStatus.COMPLETED
      }
    })

    let cleanedCount = 0

    for (const exp of oldExports) {
      try {
        // Delete file if it exists
        if (exp.filename) {
          const fs = await import('fs/promises')
          const filePath = join(this.exportDir, exp.filename)
          await fs.unlink(filePath).catch(() => {}) // Ignore file not found errors
        }

        // Update database record
        await this.prisma.auditExport.update({
          where: { id: exp.id },
          data: { status: AuditExportStatus.EXPIRED }
        })

        cleanedCount++
      } catch (error) {
        console.error(`Failed to cleanup export ${exp.id}:`, error)
      }
    }

    return cleanedCount
  }
}

export default AuditExportManager