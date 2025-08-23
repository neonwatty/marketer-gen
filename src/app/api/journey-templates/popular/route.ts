import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'

import { authOptions } from '@/lib/auth'
import { JourneyTemplateService } from '@/lib/services/journey-template-service'

/**
 * GET /api/journey-templates/popular
 * Get popular journey templates
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

    const { searchParams } = new URL(request.url)
    const limit = Math.min(parseInt(searchParams.get('limit') || '10', 10), 50) // Cap at 50

    const popularTemplates = await JourneyTemplateService.getPopularTemplates(limit)

    return NextResponse.json({
      success: true,
      data: popularTemplates,
    })
  } catch (error: any) {
    console.error('Error fetching popular journey templates:', error)
    return NextResponse.json(
      { error: 'Failed to fetch popular templates', details: error.message },
      { status: 500 }
    )
  }
}