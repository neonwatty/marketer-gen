import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'

import { authOptions } from '@/lib/auth'
import { JourneyTemplateService } from '@/lib/services/journey-template-service'
import { JourneyTemplateSchema } from '@/lib/types/journey'

interface RouteParams {
  id: string
}

/**
 * GET /api/journey-templates/[id]
 * Get a specific journey template by ID
 */
export async function GET(
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

    return NextResponse.json({
      success: true,
      data: template,
    })
  } catch (error: any) {
    console.error('Error fetching journey template:', error)
    return NextResponse.json(
      { error: 'Failed to fetch template', details: error.message },
      { status: 500 }
    )
  }
}

/**
 * PUT /api/journey-templates/[id]
 * Update a journey template
 */
export async function PUT(
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

    // Check if template exists and user has permission
    const resolvedParams = await params
    const existingTemplate = await JourneyTemplateService.getTemplateById(resolvedParams.id)
    if (!existingTemplate) {
      return NextResponse.json(
        { error: 'Template not found' },
        { status: 404 }
      )
    }

    // Only allow the creator or admin to update
    if (existingTemplate.createdBy !== session.user.id && session.user.role !== 'ADMIN') {
      return NextResponse.json(
        { error: 'Permission denied' },
        { status: 403 }
      )
    }

    const body = await request.json()
    
    // Add updater information
    const updateData = {
      ...body,
      updatedBy: session.user.id,
    }

    // Validate if stages are being updated
    if (updateData.stages) {
      JourneyTemplateSchema.parse(updateData)
    }

    const updatedTemplate = await JourneyTemplateService.updateTemplate(resolvedParams.id, updateData)

    if (!updatedTemplate) {
      return NextResponse.json(
        { error: 'Failed to update template' },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      data: updatedTemplate,
    })
  } catch (error: any) {
    console.error('Error updating journey template:', error)
    
    if (error.name === 'ZodError') {
      return NextResponse.json(
        { error: 'Invalid template data', details: error.errors },
        { status: 400 }
      )
    }

    return NextResponse.json(
      { error: 'Failed to update template', details: error.message },
      { status: 500 }
    )
  }
}

/**
 * DELETE /api/journey-templates/[id]
 * Soft delete a journey template
 */
export async function DELETE(
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

    // Check if template exists and user has permission
    const resolvedParams = await params
    const existingTemplate = await JourneyTemplateService.getTemplateById(resolvedParams.id)
    if (!existingTemplate) {
      return NextResponse.json(
        { error: 'Template not found' },
        { status: 404 }
      )
    }

    // Only allow the creator or admin to delete
    if (existingTemplate.createdBy !== session.user.id && session.user.role !== 'ADMIN') {
      return NextResponse.json(
        { error: 'Permission denied' },
        { status: 403 }
      )
    }

    const deleted = await JourneyTemplateService.deleteTemplate(resolvedParams.id)

    if (!deleted) {
      return NextResponse.json(
        { error: 'Failed to delete template' },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      message: 'Template deleted successfully',
    })
  } catch (error: any) {
    console.error('Error deleting journey template:', error)
    return NextResponse.json(
      { error: 'Failed to delete template', details: error.message },
      { status: 500 }
    )
  }
}