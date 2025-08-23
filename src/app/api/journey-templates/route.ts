import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'

import { authOptions } from '@/lib/auth'
import { JourneyTemplateService } from '@/lib/services/journey-template-service'
import { 
  JourneyTemplateFilters,
  JourneyTemplateFiltersSchema, 
  JourneyTemplateSchema,
  JourneyTemplateSortBy,
  JourneyTemplateSortOrder
} from '@/lib/types/journey'

/**
 * GET /api/journey-templates
 * Get journey templates with filtering, sorting, and pagination
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
    
    // Parse query parameters
    const filters: JourneyTemplateFilters = {}
    
    const industry = searchParams.get('industry')
    if (industry) {
      filters.industry = industry.split(',') as any
    }
    
    const category = searchParams.get('category')
    if (category) {
      filters.category = category.split(',') as any
    }
    
    const difficulty = searchParams.get('difficulty')
    if (difficulty) {
      filters.difficulty = difficulty.split(',') as any
    }
    
    const tags = searchParams.get('tags')
    if (tags) {
      filters.tags = tags.split(',')
    }
    
    const channels = searchParams.get('channels')
    if (channels) {
      filters.channels = channels.split(',')
    }
    
    const minRating = searchParams.get('minRating')
    if (minRating) {
      filters.minRating = parseFloat(minRating)
    }
    
    const isPublic = searchParams.get('isPublic')
    if (isPublic !== null) {
      filters.isPublic = isPublic === 'true'
    }
    
    const searchQuery = searchParams.get('search')
    if (searchQuery) {
      filters.searchQuery = searchQuery
    }

    // Parse pagination and sorting
    const page = parseInt(searchParams.get('page') || '1', 10)
    const pageSize = Math.min(parseInt(searchParams.get('pageSize') || '20', 10), 100) // Cap at 100
    const sortBy = (searchParams.get('sortBy') || 'createdAt') as JourneyTemplateSortBy
    const sortOrder = (searchParams.get('sortOrder') || 'desc') as JourneyTemplateSortOrder

    // Validate filters
    const validatedFilters = JourneyTemplateFiltersSchema.parse(filters)
    
    // Get templates
    const result = await JourneyTemplateService.getTemplates(
      validatedFilters,
      sortBy,
      sortOrder,
      page,
      pageSize
    )

    return NextResponse.json({
      success: true,
      data: result,
    })
  } catch (error: any) {
    console.error('Error fetching journey templates:', error)
    return NextResponse.json(
      { error: 'Failed to fetch templates', details: error.message },
      { status: 500 }
    )
  }
}

/**
 * POST /api/journey-templates
 * Create a new journey template
 */
export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user) {
      return NextResponse.json(
        { error: 'Authentication required' },
        { status: 401 }
      )
    }

    const body = await request.json()
    
    // Add creator information
    const templateData = {
      ...body,
      createdBy: session.user.id,
      updatedBy: session.user.id,
    }

    // Validate template data
    const validatedData = JourneyTemplateSchema.parse(templateData)

    // Create template
    const newTemplate = await JourneyTemplateService.createTemplate(validatedData)

    return NextResponse.json({
      success: true,
      data: newTemplate,
    }, { status: 201 })
  } catch (error: any) {
    console.error('Error creating journey template:', error)
    
    if (error.name === 'ZodError') {
      return NextResponse.json(
        { error: 'Invalid template data', details: error.errors },
        { status: 400 }
      )
    }

    return NextResponse.json(
      { error: 'Failed to create template', details: error.message },
      { status: 500 }
    )
  }
}