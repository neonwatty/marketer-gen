import { NextRequest, NextResponse } from "next/server"

import { z } from "zod"

import { prisma } from "@/lib/database"

// Brand asset validation schema
const CreateBrandAssetSchema = z.object({
  name: z.string().min(1, "Asset name is required"),
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
  ]),
  category: z.string().optional(),
  fileUrl: z.string().min(1, "File URL is required"),
  fileName: z.string().min(1, "File name is required"),
  fileSize: z.number().positive().optional(),
  mimeType: z.string().optional(),
  metadata: z.record(z.string(), z.any()).optional(),
  tags: z.array(z.string()).optional(),
  version: z.string().optional(),
})

const UpdateBrandAssetSchema = CreateBrandAssetSchema.partial()

// GET /api/brands/[id]/assets - Get all assets for a brand
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: brandId } = await params
    const url = new URL(request.url)
    const type = url.searchParams.get("type")
    const category = url.searchParams.get("category")
    const search = url.searchParams.get("search")

    // Verify brand exists
    const brand = await prisma.brand.findFirst({
      where: {
        id: brandId,
        deletedAt: null,
      },
    })

    if (!brand) {
      return NextResponse.json(
        { error: "Brand not found" },
        { status: 404 }
      )
    }

    // Build where clause
    const where: any = {
      brandId,
      deletedAt: null,
    }

    if (type) {
      where.type = type
    }

    if (category) {
      where.category = { contains: category, mode: "insensitive" }
    }

    if (search) {
      where.OR = [
        { name: { contains: search, mode: "insensitive" } },
        { description: { contains: search, mode: "insensitive" } },
        { fileName: { contains: search, mode: "insensitive" } },
      ]
    }

    const assets = await prisma.brandAsset.findMany({
      where,
      orderBy: [
        { isActive: "desc" },
        { createdAt: "desc" },
      ],
    })

    return NextResponse.json({ assets })
  } catch (error) {
    console.error("[BRAND_ASSETS_GET]", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}

// POST /api/brands/[id]/assets - Create a new brand asset
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: brandId } = await params
    const body = await request.json()
    const validatedData = CreateBrandAssetSchema.parse(body)

    // Verify brand exists
    const brand = await prisma.brand.findFirst({
      where: {
        id: brandId,
        deletedAt: null,
      },
    })

    if (!brand) {
      return NextResponse.json(
        { error: "Brand not found" },
        { status: 404 }
      )
    }

    // For now, we'll use a hardcoded user ID. In a real app, you'd get this from the session
    const userId = "cmefuzqdo0000nutz18es59jr" // This should come from session/auth

    const asset = await prisma.brandAsset.create({
      data: {
        ...validatedData,
        brandId,
        createdBy: userId,
      },
    })

    // Update brand's updatedAt timestamp
    await prisma.brand.update({
      where: { id: brandId },
      data: { updatedBy: userId },
    })

    return NextResponse.json(asset, { status: 201 })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: "Validation error", details: error.issues },
        { status: 400 }
      )
    }

    console.error("[BRAND_ASSETS_POST]", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}