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
  let session: any
  try {
    session = await getServerSession(authOptions)
    if (!session?.user) {
      return NextResponse.json(
        { 
          error: 'Authentication required',
          message: 'You must be authenticated to access this resource',
          timestamp: new Date().toISOString()
        },
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
    const filtersValidation = JourneyTemplateFiltersSchema.safeParse(filters)
    
    if (!filtersValidation.success) {
      return NextResponse.json(
        { 
          error: 'Invalid query parameters', 
          details: filtersValidation.error.format(),
          timestamp: new Date().toISOString()
        },
        { status: 400 }
      )
    }
    
    const validatedFilters = filtersValidation.data
    
    // Get templates
    const result = await JourneyTemplateService.getTemplates(
      validatedFilters,
      sortBy,
      sortOrder,
      page,
      pageSize
    )

    const response = NextResponse.json({
      success: true,
      data: result,
      timestamp: new Date().toISOString()
    })

    // Add caching headers for GET requests
    response.headers.set('Cache-Control', 'private, max-age=600') // 10 minutes for templates
    response.headers.set('ETag', `"journey-templates-${result.totalCount || 0}-${new Date().getTime()}"`)
    
    return response
  } catch (error: any) {
    console.error('[JOURNEY_TEMPLATES_GET] Error:', {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
      timestamp: new Date().toISOString(),
      url: request.url,
      method: request.method,
      userId: (session as any)?.user?.id
    })
    
    return NextResponse.json(
      { 
        error: 'Internal server error',
        message: 'Failed to fetch templates',
        details: error instanceof Error ? error.message : undefined,
        timestamp: new Date().toISOString()
      },
      { status: 500 }
    )
  }
}

/**
 * POST /api/journey-templates
 * Create a new journey template
 */
export async function POST(request: NextRequest) {
  let session: any
  try {
    session = await getServerSession(authOptions)
    if (!session?.user) {
      return NextResponse.json(
        { 
          error: 'Authentication required',
          message: 'You must be authenticated to access this resource',
          timestamp: new Date().toISOString()
        },
        { status: 401 }
      )
    }

    // Check content type
    if (!request.headers.get('content-type')?.includes('application/json')) {
      return NextResponse.json(
        { 
          error: "Invalid content type", 
          message: "Content-Type must be application/json",
          timestamp: new Date().toISOString()
        },
        { status: 415 }
      )
    }

    let body
    try {
      body = await request.json()
    } catch {
      return NextResponse.json(
        { 
          error: "Invalid JSON", 
          message: "Request body must be valid JSON",
          timestamp: new Date().toISOString()
        },
        { status: 400 }
      )
    }
    
    // Add creator information
    const templateData = {
      ...body,
      createdBy: session.user.id,
      updatedBy: session.user.id,
    }

    // Validate template data
    const validation = JourneyTemplateSchema.safeParse(templateData)
    
    if (!validation.success) {
      return NextResponse.json(
        { 
          error: 'Invalid template data', 
          details: validation.error.format(),
          timestamp: new Date().toISOString()
        },
        { status: 400 }
      )
    }
    
    const validatedData = validation.data

    // Create template
    const newTemplate = await JourneyTemplateService.createTemplate(validatedData)

    return NextResponse.json({
      success: true,
      data: newTemplate,
      timestamp: new Date().toISOString()
    }, { status: 201 })
  } catch (error: any) {
    console.error('[JOURNEY_TEMPLATES_POST] Error:', {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
      timestamp: new Date().toISOString(),
      url: request.url,
      method: request.method,
      userId: (session as any)?.user?.id
    })
    
    return NextResponse.json(
      { 
        error: 'Internal server error',
        message: 'Failed to create template',
        details: error instanceof Error ? error.message : undefined,
        timestamp: new Date().toISOString()
      },
      { status: 500 }
    )
  }
}