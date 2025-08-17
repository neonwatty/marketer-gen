import '@/lib/types/auth'

import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'

import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/db'
import {
  campaignQuerySchema,
  createCampaignSchema} from '@/lib/validation/campaigns'

export async function GET(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    
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
        include: {
          brand: {
            select: {
              id: true,
              name: true
            }
          },
          journeys: {
            select: {
              id: true,
              status: true
            }
          },
          _count: {
            select: {
              journeys: true
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

    return NextResponse.json({
      campaigns,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    })
  } catch (error) {
    console.error('Error fetching campaigns:', error)
    return NextResponse.json(
      { error: 'Failed to fetch campaigns' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    
    // Validate request body
    const validation = createCampaignSchema.safeParse(body)
    
    if (!validation.success) {
      return NextResponse.json(
        { error: 'Invalid request data', details: validation.error.format() },
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
        { error: 'Brand not found or access denied' },
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

    return NextResponse.json(campaign, { status: 201 })
  } catch (error) {
    console.error('Error creating campaign:', error)
    return NextResponse.json(
      { error: 'Failed to create campaign' },
      { status: 500 }
    )
  }
}