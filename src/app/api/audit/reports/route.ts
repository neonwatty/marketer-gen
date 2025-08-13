import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient, AuditEventType, AuditEventCategory, AuditEntityType, AuditSeverity } from '@prisma/client'

const prisma = new PrismaClient()

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const reportId = searchParams.get('id')

    if (reportId) {
      // Get specific report
      const report = await prisma.auditReport.findUnique({
        where: { id: reportId }
      })

      if (!report) {
        return NextResponse.json(
          { success: false, error: 'Report not found' },
          { status: 404 }
        )
      }

      return NextResponse.json({
        success: true,
        data: {
          ...report,
          filters: JSON.parse(report.filters),
          dateRange: JSON.parse(report.dateRange),
          groupBy: report.groupBy ? JSON.parse(report.groupBy) : [],
          sortBy: report.sortBy ? JSON.parse(report.sortBy) : [],
          chartConfig: report.chartConfig ? JSON.parse(report.chartConfig) : null,
          recipients: report.recipients ? JSON.parse(report.recipients) : [],
          lastResults: report.lastResults ? JSON.parse(report.lastResults) : null
        }
      })
    } else {
      // List all reports
      const page = parseInt(searchParams.get('page') || '1')
      const limit = parseInt(searchParams.get('limit') || '20')
      const skip = (page - 1) * limit
      const isPublic = searchParams.get('public') === 'true'

      const where = isPublic ? { isPublic: true } : {}

      const [reports, total] = await Promise.all([
        prisma.auditReport.findMany({
          where,
          orderBy: { updatedAt: 'desc' },
          skip,
          take: limit,
          select: {
            id: true,
            name: true,
            description: true,
            createdAt: true,
            updatedAt: true,
            isPublic: true,
            createdBy: true,
            isScheduled: true,
            lastRunAt: true
          }
        }),
        prisma.auditReport.count({ where })
      ])

      return NextResponse.json({
        success: true,
        data: reports,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit)
        }
      })
    }
  } catch (error) {
    console.error('Error fetching audit reports:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to fetch reports' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { action, ...reportConfig } = body

    if (action === 'run') {
      // Run a report (either existing or ad-hoc)
      const result = await runReport(reportConfig)
      return NextResponse.json({ success: true, data: result })
    } else if (action === 'preview') {
      // Preview a report (limited data)
      const result = await runReport({ ...reportConfig, limit: 100 })
      return NextResponse.json({ success: true, data: result })
    } else {
      // Create a new report configuration
      const report = await prisma.auditReport.create({
        data: {
          name: reportConfig.name,
          description: reportConfig.description,
          isPublic: reportConfig.isPublic || false,
          createdBy: reportConfig.createdBy || 'system',
          filters: JSON.stringify(reportConfig.filters || {}),
          dateRange: JSON.stringify(reportConfig.dateRange || {}),
          groupBy: JSON.stringify(reportConfig.groupBy || []),
          sortBy: JSON.stringify(reportConfig.sortBy || []),
          chartType: reportConfig.visualization?.chartType || 'bar',
          chartConfig: JSON.stringify(reportConfig.visualization || {}),
          isScheduled: reportConfig.schedule?.enabled || false,
          schedule: reportConfig.schedule?.frequency || null,
          recipients: JSON.stringify(reportConfig.schedule?.recipients || [])
        }
      })

      return NextResponse.json({
        success: true,
        data: { id: report.id, createdAt: report.createdAt }
      })
    }
  } catch (error) {
    console.error('Error creating/running audit report:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to process report request' },
      { status: 500 }
    )
  }
}

export async function PUT(request: NextRequest) {
  try {
    const body = await request.json()
    const { id, ...updates } = body

    const report = await prisma.auditReport.update({
      where: { id },
      data: {
        name: updates.name,
        description: updates.description,
        isPublic: updates.isPublic,
        filters: JSON.stringify(updates.filters || {}),
        dateRange: JSON.stringify(updates.dateRange || {}),
        groupBy: JSON.stringify(updates.groupBy || []),
        sortBy: JSON.stringify(updates.sortBy || []),
        chartType: updates.visualization?.chartType || 'bar',
        chartConfig: JSON.stringify(updates.visualization || {}),
        isScheduled: updates.schedule?.enabled || false,
        schedule: updates.schedule?.frequency || null,
        recipients: JSON.stringify(updates.schedule?.recipients || [])
      }
    })

    return NextResponse.json({
      success: true,
      data: { id: report.id, updatedAt: report.updatedAt }
    })
  } catch (error) {
    console.error('Error updating audit report:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to update report' },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const id = searchParams.get('id')

    if (!id) {
      return NextResponse.json(
        { success: false, error: 'Report ID is required' },
        { status: 400 }
      )
    }

    await prisma.auditReport.delete({
      where: { id }
    })

    return NextResponse.json({
      success: true,
      message: 'Report deleted successfully'
    })
  } catch (error) {
    console.error('Error deleting audit report:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to delete report' },
      { status: 500 }
    )
  }
}

// Helper function to run a report
async function runReport(config: any) {
  const {
    filters = {},
    groupBy = ['eventType'],
    sortBy = [{ field: 'createdAt', direction: 'desc' }],
    limit = 1000
  } = config

  // Build where clause from filters
  const where: any = {}

  // Date range filter
  if (filters.dateRange) {
    const { type, startDate, endDate } = filters.dateRange
    
    if (type !== 'custom') {
      const now = new Date()
      const days = type === 'last_7_days' ? 7 : type === 'last_30_days' ? 30 : 90
      where.createdAt = {
        gte: new Date(now.getTime() - days * 24 * 60 * 60 * 1000)
      }
    } else if (startDate || endDate) {
      where.createdAt = {}
      if (startDate) where.createdAt.gte = new Date(startDate)
      if (endDate) where.createdAt.lte = new Date(endDate)
    }
  }

  // Filter arrays
  if (filters.eventTypes?.length > 0) {
    where.eventType = { in: filters.eventTypes }
  }
  if (filters.eventCategories?.length > 0) {
    where.eventCategory = { in: filters.eventCategories }
  }
  if (filters.entityTypes?.length > 0) {
    where.entityType = { in: filters.entityTypes }
  }
  if (filters.severities?.length > 0) {
    where.severity = { in: filters.severities }
  }
  if (filters.userIds?.length > 0) {
    where.userId = { in: filters.userIds }
  }

  // Environment filter
  if (filters.environment) {
    where.environment = filters.environment
  }

  // Personal data filter
  if (!filters.includePersonalData) {
    where.OR = [
      { isPersonalData: false },
      { isPersonalData: true, anonymizedAt: { not: null } }
    ]
  }

  // Execute the query based on groupBy configuration
  if (groupBy.length === 0) {
    // No grouping - return raw data
    const logs = await prisma.auditLog.findMany({
      where,
      orderBy: sortBy.map(sort => ({ [sort.field]: sort.direction })),
      take: limit,
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
        severity: true,
        duration: true,
        environment: true
      }
    })

    return {
      type: 'raw',
      data: logs,
      summary: {
        totalRecords: logs.length,
        timeRange: filters.dateRange
      }
    }
  } else {
    // Grouped data
    const groupings = await Promise.all(
      groupBy.map(async (field: string) => {
        let groupField = field
        let selectField = field

        // Handle special grouping fields
        if (field === 'hourOfDay') {
          // For hour of day grouping, we need to extract the hour
          groupField = 'createdAt'
          selectField = 'createdAt'
        } else if (field === 'dayOfWeek') {
          // For day of week grouping
          groupField = 'createdAt'
          selectField = 'createdAt'
        } else if (field === 'date') {
          // For date grouping
          groupField = 'createdAt'
          selectField = 'createdAt'
        }

        const results = await prisma.auditLog.groupBy({
          by: [groupField as any],
          where,
          _count: { id: true },
          _avg: field === 'duration' ? { duration: true } : undefined,
          orderBy: { _count: { id: 'desc' } }
        })

        // Process results for special fields
        let processedResults = results

        if (field === 'hourOfDay') {
          const hourlyData: Record<number, number> = {}
          for (const result of results) {
            const hour = new Date(result.createdAt as any).getHours()
            hourlyData[hour] = (hourlyData[hour] || 0) + result._count.id
          }
          processedResults = Object.entries(hourlyData).map(([hour, count]) => ({
            [field]: parseInt(hour),
            _count: { id: count }
          })) as any
        } else if (field === 'dayOfWeek') {
          const dailyData: Record<number, number> = {}
          for (const result of results) {
            const day = new Date(result.createdAt as any).getDay()
            dailyData[day] = (dailyData[day] || 0) + result._count.id
          }
          processedResults = Object.entries(dailyData).map(([day, count]) => ({
            [field]: parseInt(day),
            _count: { id: count }
          })) as any
        } else if (field === 'date') {
          const dateData: Record<string, number> = {}
          for (const result of results) {
            const date = new Date(result.createdAt as any).toISOString().split('T')[0]
            dateData[date] = (dateData[date] || 0) + result._count.id
          }
          processedResults = Object.entries(dateData).map(([date, count]) => ({
            [field]: date,
            _count: { id: count }
          })) as any
        }

        return {
          field,
          data: processedResults.slice(0, 50), // Limit to top 50 results per group
          total: processedResults.reduce((sum: number, item: any) => sum + item._count.id, 0)
        }
      })
    )

    // Calculate summary statistics
    const totalCount = await prisma.auditLog.count({ where })
    const avgDuration = await prisma.auditLog.aggregate({
      where: { ...where, duration: { not: null } },
      _avg: { duration: true }
    })

    // Get top entities, users, etc.
    const topEntities = await prisma.auditLog.groupBy({
      by: ['entityType', 'entityId'],
      where,
      _count: { id: true },
      orderBy: { _count: { id: 'desc' } },
      take: 10
    })

    const topUsers = await prisma.auditLog.groupBy({
      by: ['userId', 'username'],
      where: { ...where, userId: { not: null } },
      _count: { id: true },
      orderBy: { _count: { id: 'desc' } },
      take: 10
    })

    return {
      type: 'grouped',
      groupings,
      summary: {
        totalRecords: totalCount,
        averageDuration: avgDuration._avg.duration,
        timeRange: filters.dateRange,
        topEntities: topEntities.map(e => ({
          entityType: e.entityType,
          entityId: e.entityId,
          count: e._count.id
        })),
        topUsers: topUsers.map(u => ({
          userId: u.userId,
          username: u.username,
          count: u._count.id
        }))
      }
    }
  }
}