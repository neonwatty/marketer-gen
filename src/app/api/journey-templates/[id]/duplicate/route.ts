import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'

import { authOptions } from '@/lib/auth'
import { JourneyTemplateService } from '@/lib/services/journey-template-service'

interface RouteParams {
  id: string
}

/**
 * POST /api/journey-templates/[id]/duplicate
 * Duplicate a journey template
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
    const { name } = body

    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return NextResponse.json(
        { error: 'Template name is required' },
        { status: 400 }
      )
    }

    // Check if original template exists
    const resolvedParams = await params
    const originalTemplate = await JourneyTemplateService.getTemplateById(resolvedParams.id)
    if (!originalTemplate) {
      return NextResponse.json(
        { error: 'Original template not found' },
        { status: 404 }
      )
    }

    // Check if user can access the original template
    if (!originalTemplate.isPublic && originalTemplate.createdBy !== session.user.id) {
      return NextResponse.json(
        { error: 'Access denied to original template' },
        { status: 403 }
      )
    }

    const duplicatedTemplate = await JourneyTemplateService.duplicateTemplate(
      resolvedParams.id,
      name.trim(),
      session.user.id
    )

    if (!duplicatedTemplate) {
      return NextResponse.json(
        { error: 'Failed to duplicate template' },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      data: duplicatedTemplate,
    }, { status: 201 })
  } catch (error: any) {
    console.error('Error duplicating journey template:', error)
    return NextResponse.json(
      { error: 'Failed to duplicate template', details: error.message },
      { status: 500 }
    )
  }
}