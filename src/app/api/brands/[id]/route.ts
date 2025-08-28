import { NextRequest, NextResponse } from "next/server"

import { z } from "zod"

import { prisma } from "@/lib/database"

// Brand validation schema
const UpdateBrandSchema = z.object({
  name: z.string().min(1, "Brand name is required").optional(),
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

// GET /api/brands/[id] - Get a specific brand
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    const brand = await prisma.brand.findFirst({
      where: {
        id,
        deletedAt: null,
      },
      select: {
        id: true,
        name: true,
        description: true,
        industry: true,
        website: true,
        tagline: true,
        mission: true,
        vision: true,
        values: true,
        personality: true,
        voiceDescription: true,
        toneAttributes: true,
        communicationStyle: true,
        messagingFramework: true,
        brandPillars: true,
        targetAudience: true,
        competitivePosition: true,
        brandPromise: true,
        complianceRules: true,
        usageGuidelines: true,
        restrictedTerms: true,
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
            createdAt: true,
            updatedAt: true,
          },
          where: { deletedAt: null },
          orderBy: { updatedAt: "desc" },
          take: 20, // Reasonable limit
        },
        brandAssets: {
          select: {
            id: true,
            name: true,
            description: true,
            type: true,
            category: true,
            fileUrl: true,
            fileName: true,
            fileSize: true,
            mimeType: true,
            isActive: true,
            downloadCount: true,
            lastUsed: true,
            createdAt: true,
            updatedAt: true,
          },
          where: { deletedAt: null },
          orderBy: { createdAt: "desc" },
          take: 50, // Reasonable limit for detail view
        },
        colorPalette: {
          select: {
            id: true,
            name: true,
            description: true,
            colors: true,
            isPrimary: true,
            isActive: true,
            createdAt: true,
            updatedAt: true,
          },
          where: { deletedAt: null },
          orderBy: { isPrimary: "desc" },
          take: 20,
        },
        typography: {
          select: {
            id: true,
            name: true,
            description: true,
            fontFamily: true,
            fontWeight: true,
            fontSize: true,
            lineHeight: true,
            letterSpacing: true,
            usage: true,
            isPrimary: true,
            isActive: true,
            fontFileUrl: true,
            fallbackFonts: true,
            createdAt: true,
            updatedAt: true,
          },
          where: { deletedAt: null },
          orderBy: { isPrimary: "desc" },
          take: 20,
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
    })

    if (!brand) {
      return NextResponse.json(
        { error: "Brand not found" },
        { status: 404 }
      )
    }

    return NextResponse.json(brand)
  } catch (error) {
    console.error("[BRAND_GET]", error)
    return NextResponse.json(
      { error: "Failed to fetch brand" },
      { status: 500 }
    )
  }
}

// PUT /api/brands/[id] - Update a specific brand
export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const body = await request.json()
    const validatedData = UpdateBrandSchema.parse(body)

    // Check if brand exists
    const existingBrand = await prisma.brand.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    })

    if (!existingBrand) {
      return NextResponse.json(
        { error: "Brand not found" },
        { status: 404 }
      )
    }

    // For now, we'll use a hardcoded user ID. In a real app, you'd get this from the session
    const userId = "cmefuzqdo0000nutz18es59jr" // This should come from session/auth

    const updatedBrand = await prisma.brand.update({
      where: { id },
      data: {
        ...validatedData,
        updatedBy: userId,
      },
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
          where: { deletedAt: null },
        },
        colorPalette: {
          where: { deletedAt: null },
        },
        typography: {
          where: { deletedAt: null },
        },
        _count: {
          select: {
            campaigns: true,
            brandAssets: true,
            colorPalette: true,
            typography: true,
          },
        },
      },
    })

    return NextResponse.json(updatedBrand)
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: "Validation error", details: error.issues },
        { status: 400 }
      )
    }

    console.error("[BRAND_PUT]", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}

// DELETE /api/brands/[id] - Soft delete a specific brand
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    // Check if brand exists
    const existingBrand = await prisma.brand.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    })

    if (!existingBrand) {
      return NextResponse.json(
        { error: "Brand not found" },
        { status: 404 }
      )
    }

    // Check if brand has active campaigns
    const activeCampaigns = await prisma.campaign.count({
      where: {
        brandId: id,
        deletedAt: null,
        status: {
          in: ["ACTIVE", "DRAFT"],
        },
      },
    })

    if (activeCampaigns > 0) {
      return NextResponse.json(
        { 
          error: "Cannot delete brand with active campaigns",
          details: `This brand has ${activeCampaigns} active campaigns. Please complete or delete them first.`
        },
        { status: 400 }
      )
    }

    // For now, we'll use a hardcoded user ID. In a real app, you'd get this from the session
    const userId = "cmefuzqdo0000nutz18es59jr" // This should come from session/auth

    // Soft delete the brand
    await prisma.brand.update({
      where: { id },
      data: {
        deletedAt: new Date(),
        updatedBy: userId,
      },
    })

    return NextResponse.json(
      { message: "Brand deleted successfully" },
      { status: 200 }
    )
  } catch (error) {
    console.error("[BRAND_DELETE]", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}