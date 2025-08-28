import '@/lib/types/auth'

import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'

import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/db'
import {
  campaignQuerySchema,
  createCampaignSchema} from '@/lib/validation/campaigns'

export async function GET(request: NextRequest) {
  let session: any
  try {
    session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { searchParams } = new URL(request.url)
    
    // Validate query parameters
    const queryValidation = campaignQuerySchema.safeParse({
      page: searchParams.get('page'),
      limit: searchParams.get('limit'),
      status: searchParams.get('status'),
      brandId: searchParams.get('brandId')
    })

    if (!queryValidation.success) {
      return NextResponse.json(
        { error: 'Invalid query parameters', details: queryValidation.error.format() },
        { status: 400 }
      )
    }

    const { page, limit, status, brandId } = queryValidation.data
    const skip = (page - 1) * limit

    const where = {
      userId: session.user.id,
      deletedAt: null,
      ...(status && { status }),
      ...(brandId && { brandId })
    }

    const [campaigns, total] = await prisma.$transaction([
      prisma.campaign.findMany({
        where,
        select: {
          id: true,
          name: true,
          purpose: true,
          goals: true,
          status: true,
          startDate: true,
          endDate: true,
          createdAt: true,
          updatedAt: true,
          brand: {
            select: {
              id: true,
              name: true,
              industry: true,
            }
          },
          journeys: {
            select: {
              id: true,
              status: true,
              createdAt: true,
            },
            where: { deletedAt: null },
            take: 10, // Limit for performance
            orderBy: { updatedAt: 'desc' }
          },
          _count: {
            select: {
              journeys: { where: { deletedAt: null } },
              analytics: { where: { deletedAt: null } }
            }
          }
        },
        orderBy: {
          updatedAt: 'desc'
        },
        skip,
        take: limit
      }),
      prisma.campaign.count({ where })
    ])

    const response = NextResponse.json({
      campaigns,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      },
      timestamp: new Date().toISOString()
    })

    // Add caching headers for GET requests
    response.headers.set('Cache-Control', 'private, max-age=300') // 5 minutes
    response.headers.set('ETag', `"campaigns-${session.user.id}-${total}-${new Date().getTime()}"`)
    
    return response
  } catch (error) {
    console.error('[CAMPAIGNS_GET] Error:', {
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
        message: 'Failed to fetch campaigns',
        timestamp: new Date().toISOString()
      },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  let session: any
  try {
    session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json({ 
        error: 'Unauthorized',
        message: 'Authentication required',
        timestamp: new Date().toISOString()
      }, { status: 401 })
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
    
    // Validate request body
    const validation = createCampaignSchema.safeParse(body)
    
    if (!validation.success) {
      return NextResponse.json(
        { 
          error: 'Invalid request data', 
          details: validation.error.format(),
          timestamp: new Date().toISOString()
        },
        { status: 400 }
      )
    }

    const { name, purpose, goals, brandId, startDate, endDate, status } = validation.data

    // Verify the brand belongs to the user
    const brand = await prisma.brand.findUnique({
      where: {
        id: brandId,
        userId: session.user.id,
        deletedAt: null
      }
    })

    if (!brand) {
      return NextResponse.json(
        { 
          error: 'Brand not found or access denied',
          message: 'The specified brand does not exist or you do not have permission to access it',
          timestamp: new Date().toISOString()
        },
        { status: 404 }
      )
    }

    const campaign = await prisma.campaign.create({
      data: {
        name,
        purpose,
        goals,
        brandId,
        userId: session.user.id,
        status,
        startDate: startDate ? new Date(startDate) : null,
        endDate: endDate ? new Date(endDate) : null,
        createdBy: session.user.id,
        updatedBy: session.user.id
      },
      include: {
        brand: {
          select: {
            id: true,
            name: true
          }
        },
        journeys: true,
        _count: {
          select: {
            journeys: true
          }
        }
      }
    })

    return NextResponse.json({
      ...campaign,
      timestamp: new Date().toISOString()
    }, { status: 201 })
  } catch (error) {
    console.error('[CAMPAIGNS_POST] Error:', {
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
        message: 'Failed to create campaign',
        timestamp: new Date().toISOString()
      },
      { status: 500 }
    )
  }
}