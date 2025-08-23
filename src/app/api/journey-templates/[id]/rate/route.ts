import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'

import { authOptions } from '@/lib/auth'
import { JourneyTemplateService } from '@/lib/services/journey-template-service'

interface RouteParams {
  id: string
}

/**
 * POST /api/journey-templates/[id]/rate
 * Rate a journey template
 */
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<RouteParams> }
) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user) {
      return NextResponse.json(
        { error: 'Authentication required' },
        { status: 401 }
      )
    }

    const body = await request.json()
    const { rating } = body

    if (!rating || typeof rating !== 'number' || rating < 1 || rating > 5) {
      return NextResponse.json(
        { error: 'Rating must be a number between 1 and 5' },
        { status: 400 }
      )
    }

    // Check if template exists
    const resolvedParams = await params
    const template = await JourneyTemplateService.getTemplateById(resolvedParams.id)
    if (!template) {
      return NextResponse.json(
        { error: 'Template not found' },
        { status: 404 }
      )
    }

    // Check if user can access this template
    if (!template.isPublic && template.createdBy !== session.user.id) {
      return NextResponse.json(
        { error: 'Access denied' },
        { status: 403 }
      )
    }

    // Update template rating
    const updatedTemplate = await JourneyTemplateService.updateTemplateRating(resolvedParams.id, rating)

    if (!updatedTemplate) {
      return NextResponse.json(
        { error: 'Failed to update rating' },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      data: {
        newRating: updatedTemplate.rating,
        ratingCount: updatedTemplate.ratingCount,
      },
    })
  } catch (error: any) {
    console.error('Error rating journey template:', error)
    return NextResponse.json(
      { error: 'Failed to rate template', details: error.message },
      { status: 500 }
    )
  }
}