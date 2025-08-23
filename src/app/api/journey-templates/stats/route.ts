import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'

import { authOptions } from '@/lib/auth'
import { JourneyTemplateService } from '@/lib/services/journey-template-service'

/**
 * GET /api/journey-templates/stats
 * Get journey template statistics
 */
export async function GET(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user) {
      return NextResponse.json(
        { error: 'Authentication required' },
        { status: 401 }
      )
    }

    const stats = await JourneyTemplateService.getTemplateStats()

    return NextResponse.json({
      success: true,
      data: stats,
    })
  } catch (error: any) {
    console.error('Error fetching journey template stats:', error)
    return NextResponse.json(
      { error: 'Failed to fetch template statistics', details: error.message },
      { status: 500 }
    )
  }
}