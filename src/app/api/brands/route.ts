import { NextRequest, NextResponse } from "next/server"
import { getServerSession } from 'next-auth/next'

import { z } from "zod"

import { authOptions } from '@/lib/auth'
import { prisma } from "@/lib/database"

// Query parameter validation schema
const BrandQuerySchema = z.object({
  page: z.string().nullable().optional().transform((val) => {
    if (!val) return 1
    const num = parseInt(val)
    return isNaN(num) || num < 1 ? 1 : num
  }),
  limit: z.string().nullable().optional().transform((val) => {
    if (!val) return 10
    const num = parseInt(val)
    return isNaN(num) || num < 1 ? 10 : Math.min(num, 100) // Cap at 100
  }),
  search: z.string().nullable().optional().transform((val) => val?.trim() || ""),
  industry: z.string().nullable().optional().transform((val) => val?.trim() || "")
})

// Brand validation schema
const CreateBrandSchema = z.object({
  name: z.string().min(1, "Brand name is required").max(100, "Brand name must be 100 characters or less"),
  description: z.string().max(1000, "Description must be 1000 characters or less").optional(),
  industry: z.string().max(100, "Industry must be 100 characters or less").optional(),
  website: z.string().url("Must be a valid URL").max(500, "URL must be 500 characters or less").optional().or(z.literal("")),
  tagline: z.string().max(200, "Tagline must be 200 characters or less").optional(),
  mission: z.string().max(2000, "Mission must be 2000 characters or less").optional(),
  vision: z.string().max(2000, "Vision must be 2000 characters or less").optional(),
  values: z.array(z.string().max(100, "Each value must be 100 characters or less")).max(10, "Maximum 10 values allowed").optional(),
  personality: z.array(z.string().max(50, "Each personality trait must be 50 characters or less")).max(10, "Maximum 10 personality traits allowed").optional(),
  voiceDescription: z.string().max(1000, "Voice description must be 1000 characters or less").optional(),
  toneAttributes: z.record(z.string(), z.number().min(0).max(10, "Tone attributes must be between 0 and 10")).optional(),
  communicationStyle: z.string().max(500, "Communication style must be 500 characters or less").optional(),
  messagingFramework: z.record(z.string(), z.any()).optional(),
  brandPillars: z.array(z.string().max(100, "Each brand pillar must be 100 characters or less")).max(5, "Maximum 5 brand pillars allowed").optional(),
  targetAudience: z.record(z.string(), z.any()).optional(),
  competitivePosition: z.string().max(1000, "Competitive position must be 1000 characters or less").optional(),
  brandPromise: z.string().max(500, "Brand promise must be 500 characters or less").optional(),
  complianceRules: z.record(z.string(), z.any()).optional(),
  usageGuidelines: z.record(z.string(), z.any()).optional(),
  restrictedTerms: z.array(z.string().max(50, "Each restricted term must be 50 characters or less")).max(50, "Maximum 50 restricted terms allowed").optional(),
})

const UpdateBrandSchema = CreateBrandSchema.partial()

// GET /api/brands - List all brands for the authenticated user
export async function GET(request: NextRequest) {
  let session: any
  try {
    session = await getServerSession(authOptions)
    
    // For MVP development - allow access without authentication
    // In production, this should require authentication
    const userId = session?.user?.id || 'demo-user'

    const { searchParams } = new URL(request.url)
    
    // Validate query parameters
    const queryValidation = BrandQuerySchema.safeParse({
      page: searchParams.get("page"),
      limit: searchParams.get("limit"),
      search: searchParams.get("search"),
      industry: searchParams.get("industry")
    })

    if (!queryValidation.success) {
      return NextResponse.json(
        { 
          error: "Invalid query parameters", 
          details: queryValidation.error.format(),
          timestamp: new Date().toISOString()
        },
        { status: 400 }
      )
    }

    const { page, limit, search, industry } = queryValidation.data
    const skip = (page - 1) * limit

    // Build where clause
    const where: any = {
      deletedAt: null,
      // For MVP - show all brands regardless of user, in production filter by userId
      // userId: userId,
    }

    if (search) {
      where.OR = [
        { name: { contains: search, mode: "insensitive" } },
        { description: { contains: search, mode: "insensitive" } },
        { tagline: { contains: search, mode: "insensitive" } },
      ]
    }

    if (industry) {
      where.industry = { contains: industry, mode: "insensitive" }
    }

    // Get brands with related data - optimized for performance
    const [brands, total] = await prisma.$transaction([
      prisma.brand.findMany({
        where,
        select: {
          id: true,
          name: true,
          description: true,
          industry: true,
          website: true,
          tagline: true,
          createdAt: true,
          updatedAt: true,
          user: {
            select: {
              id: true,
              name: true,
              email: true,
            },
          },
          campaigns: {
            select: {
              id: true,
              name: true,
              status: true,
            },
            where: { deletedAt: null },
            take: 5, // Limit for performance
            orderBy: { updatedAt: "desc" },
          },
          brandAssets: {
            select: {
              id: true,
              name: true,
              type: true,
              fileUrl: true,
            },
            where: { deletedAt: null, isActive: true },
            take: 10, // Limit for performance
            orderBy: { updatedAt: "desc" },
          },
          colorPalette: {
            select: {
              id: true,
              name: true,
              isPrimary: true,
            },
            where: { deletedAt: null, isActive: true },
            take: 5, // Most recent palettes
            orderBy: { isPrimary: "desc" },
          },
          typography: {
            select: {
              id: true,
              name: true,
              fontFamily: true,
              isPrimary: true,
            },
            where: { deletedAt: null, isActive: true },
            take: 5, // Most recent typography
            orderBy: { isPrimary: "desc" },
          },
          _count: {
            select: {
              campaigns: { where: { deletedAt: null } },
              brandAssets: { where: { deletedAt: null, isActive: true } },
              colorPalette: { where: { deletedAt: null, isActive: true } },
              typography: { where: { deletedAt: null, isActive: true } },
            },
          },
        },
        orderBy: { updatedAt: "desc" },
        skip,
        take: limit,
      }),
      prisma.brand.count({ where }),
    ])

    const response = NextResponse.json({
      brands,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
      timestamp: new Date().toISOString()
    })

    // Add caching headers for GET requests
    response.headers.set('Cache-Control', 'private, max-age=300') // 5 minutes
    response.headers.set('ETag', `"brands-${total}-${new Date().getTime()}"`)
    
    return response
  } catch (error) {
    console.error("[BRANDS_GET] Error:", {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
      timestamp: new Date().toISOString(),
      url: request.url,
      method: request.method,
      userId: (session as any)?.user?.id
    })
    
    return NextResponse.json(
      { 
        error: "Internal server error", 
        message: "Failed to fetch brands",
        timestamp: new Date().toISOString()
      },
      { status: 500 }
    )
  }
}

// POST /api/brands - Create a new brand
export async function POST(request: NextRequest) {
  let session: any
  try {
    session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json(
        { 
          error: 'Unauthorized',
          message: 'Authentication required',
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

    // Validate request body
    const validation = CreateBrandSchema.safeParse(body)
    
    if (!validation.success) {
      return NextResponse.json(
        { 
          error: "Validation error", 
          details: validation.error.format(),
          timestamp: new Date().toISOString()
        },
        { status: 400 }
      )
    }

    const validatedData = validation.data
    const userId = session.user.id

    const brand = await prisma.brand.create({
      data: {
        ...validatedData,
        userId,
        createdBy: userId,
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
        brandAssets: true,
        colorPalette: true,
        typography: true,
        _count: {
          select: {
            campaigns: true,
            brandAssets: true,
          },
        },
      },
    })

    return NextResponse.json({
      ...brand,
      timestamp: new Date().toISOString()
    }, { status: 201 })
  } catch (error) {
    console.error("[BRANDS_POST] Error:", {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
      timestamp: new Date().toISOString(),
      url: request.url,
      method: request.method,
      userId: (session as any)?.user?.id
    })
    
    return NextResponse.json(
      { 
        error: "Internal server error", 
        message: "Failed to create brand",
        timestamp: new Date().toISOString()
      },
      { status: 500 }
    )
  }
}