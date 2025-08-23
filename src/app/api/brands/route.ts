import { NextRequest, NextResponse } from "next/server"

import { z } from "zod"

import { prisma } from "@/lib/database"

// Brand validation schema
const CreateBrandSchema = z.object({
  name: z.string().min(1, "Brand name is required"),
  description: z.string().optional(),
  industry: z.string().optional(),
  website: z.string().url().optional().or(z.literal("")),
  tagline: z.string().optional(),
  mission: z.string().optional(),
  vision: z.string().optional(),
  values: z.array(z.string()).optional(),
  personality: z.array(z.string()).optional(),
  voiceDescription: z.string().optional(),
  toneAttributes: z.record(z.string(), z.number()).optional(),
  communicationStyle: z.string().optional(),
  messagingFramework: z.record(z.string(), z.any()).optional(),
  brandPillars: z.array(z.string()).optional(),
  targetAudience: z.record(z.string(), z.any()).optional(),
  competitivePosition: z.string().optional(),
  brandPromise: z.string().optional(),
  complianceRules: z.record(z.string(), z.any()).optional(),
  usageGuidelines: z.record(z.string(), z.any()).optional(),
  restrictedTerms: z.array(z.string()).optional(),
})

const UpdateBrandSchema = CreateBrandSchema.partial()

// GET /api/brands - List all brands for the authenticated user
export async function GET(request: NextRequest) {
  try {
    const url = new URL(request.url)
    const page = parseInt(url.searchParams.get("page") || "1")
    const limit = parseInt(url.searchParams.get("limit") || "10")
    const search = url.searchParams.get("search") || ""
    const industry = url.searchParams.get("industry") || ""

    const skip = (page - 1) * limit

    // Build where clause
    const where: any = {
      deletedAt: null,
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

    // Get brands with related data
    const [brands, total] = await Promise.all([
      prisma.brand.findMany({
        where,
        include: {
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
          },
          brandAssets: {
            select: {
              id: true,
              name: true,
              type: true,
              fileUrl: true,
            },
            where: { deletedAt: null, isActive: true },
          },
          colorPalette: {
            select: {
              id: true,
              name: true,
              isPrimary: true,
            },
            where: { deletedAt: null, isActive: true },
          },
          typography: {
            select: {
              id: true,
              name: true,
              fontFamily: true,
              isPrimary: true,
            },
            where: { deletedAt: null, isActive: true },
          },
          _count: {
            select: {
              campaigns: true,
              brandAssets: true,
            },
          },
        },
        orderBy: { updatedAt: "desc" },
        skip,
        take: limit,
      }),
      prisma.brand.count({ where }),
    ])

    return NextResponse.json({
      brands,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    })
  } catch (error) {
    console.error("[BRANDS_GET]", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}

// POST /api/brands - Create a new brand
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const validatedData = CreateBrandSchema.parse(body)

    // For now, we'll use a hardcoded user ID. In a real app, you'd get this from the session
    const userId = "cmefuzqdo0000nutz18es59jr" // This should come from session/auth

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

    return NextResponse.json(brand, { status: 201 })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: "Validation error", details: error.issues },
        { status: 400 }
      )
    }

    console.error("[BRANDS_POST]", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}