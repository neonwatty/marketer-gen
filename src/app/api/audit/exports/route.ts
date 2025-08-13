import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient, AuditExportType } from '@prisma/client'
import AuditExportManager from '@/lib/audit/export-manager'

const prisma = new PrismaClient()
const exportManager = new AuditExportManager(prisma)

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const exportId = searchParams.get('id')
    const userId = searchParams.get('userId')

    if (exportId) {
      // Get specific export
      const exportRecord = await exportManager.getExport(exportId)
      
      if (!exportRecord) {
        return NextResponse.json(
          { success: false, error: 'Export not found' },
          { status: 404 }
        )
      }

      return NextResponse.json({
        success: true,
        data: exportRecord
      })
    } else if (userId) {
      // Get exports for user
      const limit = parseInt(searchParams.get('limit') || '50')
      const exports = await exportManager.getUserExports(userId, limit)
      
      return NextResponse.json({
        success: true,
        data: exports
      })
    } else {
      return NextResponse.json(
        { success: false, error: 'Either exportId or userId is required' },
        { status: 400 }
      )
    }
  } catch (error) {
    console.error('Error fetching audit exports:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to fetch exports' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    
    // Validate required fields
    const {
      exportType = AuditExportType.MANUAL,
      format = 'json',
      filters = {},
      options = {},
      requestedBy
    } = body

    if (!requestedBy) {
      return NextResponse.json(
        { success: false, error: 'requestedBy is required' },
        { status: 400 }
      )
    }

    // Parse date filters
    if (filters.dateFrom) {
      filters.dateFrom = new Date(filters.dateFrom)
    }
    if (filters.dateTo) {
      filters.dateTo = new Date(filters.dateTo)
    }

    // Start export
    const exportId = await exportManager.startExport({
      exportType,
      format,
      filters,
      options: {
        includeMetadata: options.includeMetadata || false,
        includeChanges: options.includeChanges || false,
        compressOutput: options.compressOutput || false,
        splitByDate: options.splitByDate || false,
        maxRecordsPerFile: options.maxRecordsPerFile || 10000
      },
      requestedBy
    })

    return NextResponse.json({
      success: true,
      data: { exportId }
    })

  } catch (error) {
    console.error('Error starting audit export:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to start export' },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const action = searchParams.get('action')

    if (action === 'cleanup') {
      // Cleanup old exports
      const olderThanDays = parseInt(searchParams.get('olderThanDays') || '30')
      const cleanedCount = await exportManager.cleanupOldExports(olderThanDays)
      
      return NextResponse.json({
        success: true,
        data: { cleanedCount }
      })
    } else {
      return NextResponse.json(
        { success: false, error: 'Invalid action' },
        { status: 400 }
      )
    }
  } catch (error) {
    console.error('Error in export cleanup:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to cleanup exports' },
      { status: 500 }
    )
  }
}