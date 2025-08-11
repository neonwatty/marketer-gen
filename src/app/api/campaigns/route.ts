import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/db'
import { CampaignStatus } from '@prisma/client'
import { z } from 'zod'

// Validation schema for creating campaigns
const createCampaignSchema = z.object({
  name: z.string().min(1, 'Campaign name is required').max(100, 'Campaign name must be less than 100 characters'),
  description: z.string().optional(),
  brandId: z.string().min(1, 'Brand ID is required'),
  status: z.nativeEnum(CampaignStatus).default(CampaignStatus.DRAFT),
  goals: z.string().optional(), // JSON string
  targetKPIs: z.string().optional(), // JSON string
  timeline: z.string().optional(), // JSON string
  budget: z.number().positive().optional(),
  metadata: z.string().optional() // JSON string
})

// GET /api/campaigns - List campaigns with pagination
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    
    // Parse query parameters
    const page = parseInt(searchParams.get('page') ?? '1', 10)
    const limit = parseInt(searchParams.get('limit') ?? '10', 10)
    const search = searchParams.get('search') ?? ''
    const status = searchParams.get('status') as CampaignStatus | null
    const brandId = searchParams.get('brandId') ?? ''
    
    // Validate pagination parameters
    if (page < 1 || limit < 1 || limit > 100) {
      return NextResponse.json(
        { error: 'Invalid pagination parameters', success: false },
        { status: 400 }
      )
    }
    
    const skip = (page - 1) * limit
    
    // Build where clause
    const where: any = {}
    
    if (search) {
      where.OR = [
        { name: { contains: search } },
        { description: { contains: search } }
      ]
    }
    
    if (status) {
      where.status = status
    }
    
    if (brandId) {
      where.brandId = brandId
    }
    
    // Get campaigns with related data
    const [campaigns, total] = await Promise.all([
      prisma.campaign.findMany({
        where,
        skip,
        take: limit,
        orderBy: { updatedAt: 'desc' },
        include: {
          brand: {
            select: { id: true, name: true }
          },
          journeys: {
            select: { id: true, name: true, status: true }
          },
          analytics: {
            select: { id: true, views: true, clicks: true, conversions: true }
          },
          _count: {
            select: { journeys: true, analytics: true }
          }
        }
      }),
      prisma.campaign.count({ where })
    ])
    
    const totalPages = Math.ceil(total / limit)
    
    return NextResponse.json({
      data: campaigns,
      success: true,
      pagination: {
        page,
        limit,
        total,
        totalPages
      }
    })
    
  } catch (error) {
    console.error('Error fetching campaigns:', error)
    return NextResponse.json(
      { error: 'Failed to fetch campaigns', success: false },
      { status: 500 }
    )
  }
}

// POST /api/campaigns - Create new campaign
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    
    // Validate request body
    const validationResult = createCampaignSchema.safeParse(body)
    if (!validationResult.success) {
      return NextResponse.json(
        { 
          error: 'Validation failed', 
          details: validationResult.error.format(),
          success: false 
        },
        { status: 400 }
      )
    }
    
    const data = validationResult.data
    
    // Check if brand exists
    const brand = await prisma.brand.findUnique({
      where: { id: data.brandId }
    })
    
    if (!brand) {
      return NextResponse.json(
        { error: 'Brand not found', success: false },
        { status: 404 }
      )
    }
    
    // Create campaign
    const campaign = await prisma.campaign.create({
      data: {
        name: data.name,
        description: data.description,
        brandId: data.brandId,
        status: data.status,
        goals: data.goals,
        targetKPIs: data.targetKPIs,
        timeline: data.timeline,
        budget: data.budget,
        metadata: data.metadata
      },
      include: {
        brand: {
          select: { id: true, name: true }
        },
        _count: {
          select: { journeys: true, analytics: true }
        }
      }
    })
    
    return NextResponse.json({
      data: campaign,
      success: true,
      message: 'Campaign created successfully'
    }, { status: 201 })
    
  } catch (error) {
    console.error('Error creating campaign:', error)
    return NextResponse.json(
      { error: 'Failed to create campaign', success: false },
      { status: 500 }
    )
  }
}