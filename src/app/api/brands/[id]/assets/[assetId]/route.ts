import { NextRequest, NextResponse } from "next/server"
import { z } from "zod"

import { prisma } from "@/lib/database"

// Brand asset validation schema
const UpdateBrandAssetSchema = z.object({
  name: z.string().min(1, "Asset name is required").optional(),
  description: z.string().optional(),
  type: z.enum([
    "LOGO",
    "BRAND_MARK", 
    "COLOR_PALETTE",
    "TYPOGRAPHY",
    "BRAND_GUIDELINES",
    "IMAGERY",
    "ICON",
    "PATTERN",
    "TEMPLATE",
    "DOCUMENT",
    "VIDEO",
    "AUDIO",
    "OTHER"
  ]).optional(),
  category: z.string().optional(),
  fileUrl: z.string().min(1, "File URL is required").optional(),
  fileName: z.string().min(1, "File name is required").optional(),
  fileSize: z.number().positive().optional(),
  mimeType: z.string().optional(),
  metadata: z.record(z.string(), z.any()).optional(),
  tags: z.array(z.string()).optional(),
  version: z.string().optional(),
  isActive: z.boolean().optional(),
})

// GET /api/brands/[id]/assets/[assetId] - Get a specific brand asset
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; assetId: string }> }
) {
  try {
    const { id: brandId, assetId } = await params

    const asset = await prisma.brandAsset.findFirst({
      where: {
        id: assetId,
        brandId,
        deletedAt: null,
      },
      include: {
        brand: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    })

    if (!asset) {
      return NextResponse.json(
        { error: "Asset not found" },
        { status: 404 }
      )
    }

    return NextResponse.json(asset)
  } catch (error) {
    console.error("[BRAND_ASSET_GET]", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}

// PUT /api/brands/[id]/assets/[assetId] - Update a specific brand asset
export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; assetId: string }> }
) {
  try {
    const { id: brandId, assetId } = await params
    const body = await request.json()
    const validatedData = UpdateBrandAssetSchema.parse(body)

    // Check if asset exists
    const existingAsset = await prisma.brandAsset.findFirst({
      where: {
        id: assetId,
        brandId,
        deletedAt: null,
      },
    })

    if (!existingAsset) {
      return NextResponse.json(
        { error: "Asset not found" },
        { status: 404 }
      )
    }

    // For now, we'll use a hardcoded user ID. In a real app, you'd get this from the session
    const userId = "cmefuzqdo0000nutz18es59jr" // This should come from session/auth

    const updatedAsset = await prisma.brandAsset.update({
      where: { id: assetId },
      data: {
        ...validatedData,
        updatedBy: userId,
      },
    })

    // Update brand's updatedAt timestamp
    await prisma.brand.update({
      where: { id: brandId },
      data: { updatedBy: userId },
    })

    return NextResponse.json(updatedAsset)
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: "Validation error", details: error.issues },
        { status: 400 }
      )
    }

    console.error("[BRAND_ASSET_PUT]", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}

// DELETE /api/brands/[id]/assets/[assetId] - Soft delete a specific brand asset
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; assetId: string }> }
) {
  try {
    const { id: brandId, assetId } = await params

    // Check if asset exists
    const existingAsset = await prisma.brandAsset.findFirst({
      where: {
        id: assetId,
        brandId,
        deletedAt: null,
      },
    })

    if (!existingAsset) {
      return NextResponse.json(
        { error: "Asset not found" },
        { status: 404 }
      )
    }

    // For now, we'll use a hardcoded user ID. In a real app, you'd get this from the session
    const userId = "cmefuzqdo0000nutz18es59jr" // This should come from session/auth

    // Soft delete the asset
    await prisma.brandAsset.update({
      where: { id: assetId },
      data: {
        deletedAt: new Date(),
        updatedBy: userId,
      },
    })

    // Update brand's updatedAt timestamp
    await prisma.brand.update({
      where: { id: brandId },
      data: { updatedBy: userId },
    })

    return NextResponse.json(
      { message: "Asset deleted successfully" },
      { status: 200 }
    )
  } catch (error) {
    console.error("[BRAND_ASSET_DELETE]", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}

// PATCH /api/brands/[id]/assets/[assetId] - Track asset usage
export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; assetId: string }> }
) {
  try {
    const { id: brandId, assetId } = await params
    const body = await request.json()
    const action = body.action // 'download' or 'view'

    // Check if asset exists
    const existingAsset = await prisma.brandAsset.findFirst({
      where: {
        id: assetId,
        brandId,
        deletedAt: null,
      },
    })

    if (!existingAsset) {
      return NextResponse.json(
        { error: "Asset not found" },
        { status: 404 }
      )
    }

    if (action === "download") {
      // Increment download count and update last used
      await prisma.brandAsset.update({
        where: { id: assetId },
        data: {
          downloadCount: { increment: 1 },
          lastUsed: new Date(),
        },
      })
    } else if (action === "view") {
      // Update last used time
      await prisma.brandAsset.update({
        where: { id: assetId },
        data: {
          lastUsed: new Date(),
        },
      })
    }

    return NextResponse.json(
      { message: "Asset usage tracked" },
      { status: 200 }
    )
  } catch (error) {
    console.error("[BRAND_ASSET_PATCH]", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}