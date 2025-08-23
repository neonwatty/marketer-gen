import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'

import { authOptions } from '@/lib/auth'
import { JourneyTemplateService } from '@/lib/services/journey-template-service'
import { JourneyCategoryValue,JourneyIndustryValue } from '@/lib/types/journey'

/**
 * GET /api/journey-templates/recommended
 * Get recommended journey templates based on preferences
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
    
    const industries = searchParams.get('industries')?.split(',') as JourneyIndustryValue[] || []
    const categories = searchParams.get('categories')?.split(',') as JourneyCategoryValue[] || []
    const limit = Math.min(parseInt(searchParams.get('limit') || '10', 10), 50) // Cap at 50

    const recommendedTemplates = await JourneyTemplateService.getRecommendedTemplates(
      industries,
      categories,
      limit
    )

    return NextResponse.json({
      success: true,
      data: recommendedTemplates,
    })
  } catch (error: any) {
    console.error('Error fetching recommended journey templates:', error)
    return NextResponse.json(
      { error: 'Failed to fetch recommended templates', details: error.message },
      { status: 500 }
    )
  }
}