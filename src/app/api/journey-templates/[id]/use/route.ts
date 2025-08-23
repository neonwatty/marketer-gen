import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'

import { authOptions } from '@/lib/auth'
import { JourneyTemplateService } from '@/lib/services/journey-template-service'

interface RouteParams {
  id: string
}

/**
 * POST /api/journey-templates/[id]/use
 * Increment usage count when template is used
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

    // Increment usage count
    await JourneyTemplateService.incrementUsageCount(resolvedParams.id)

    return NextResponse.json({
      success: true,
      message: 'Usage count incremented',
    })
  } catch (error: any) {
    console.error('Error incrementing template usage:', error)
    return NextResponse.json(
      { error: 'Failed to update usage count', details: error.message },
      { status: 500 }
    )
  }
}