import { NextRequest, NextResponse } from 'next/server'
import { promises as fs } from 'fs'
import path from 'path'
import { v4 as uuidv4 } from 'uuid'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

// Ensure upload directory exists
const UPLOAD_DIR = path.join(process.cwd(), 'public/uploads/brand-assets')

async function ensureUploadDir() {
  try {
    await fs.access(UPLOAD_DIR)
  } catch {
    await fs.mkdir(UPLOAD_DIR, { recursive: true })
  }
}

export async function POST(request: NextRequest) {
  try {
    await ensureUploadDir()

    const formData = await request.formData()
    const files = formData.getAll('files') as File[]
    const brandId = formData.get('brandId') as string
    const category = formData.get('category') as string || 'general'
    const tags = formData.get('tags') as string || ''

    if (!files || files.length === 0) {
      return NextResponse.json(
        { error: 'No files provided' },
        { status: 400 }
      )
    }

    if (!brandId) {
      return NextResponse.json(
        { error: 'Brand ID is required' },
        { status: 400 }
      )
    }

    const uploadedAssets = []

    for (const file of files) {
      if (!(file instanceof File)) continue

      // Generate unique filename
      const fileExtension = path.extname(file.name)
      const fileName = `${uuidv4()}${fileExtension}`
      const filePath = path.join(UPLOAD_DIR, fileName)

      // Save file to disk
      const bytes = await file.arrayBuffer()
      const buffer = Buffer.from(bytes)
      await fs.writeFile(filePath, buffer)

      // Determine asset type based on MIME type
      let assetType = 'document'
      if (file.type.startsWith('image/')) assetType = 'image'
      else if (file.type.startsWith('video/')) assetType = 'video'
      else if (file.type.startsWith('audio/')) assetType = 'audio'

      // Create asset record with metadata stored in brandAssets JSON field
      const asset = {
        id: uuidv4(),
        name: file.name,
        originalName: file.name,
        fileName: fileName,
        type: assetType,
        mimeType: file.type,
        size: file.size,
        url: `/uploads/brand-assets/${fileName}`,
        category: category,
        tags: tags ? tags.split(',').map(tag => tag.trim()).filter(Boolean) : [],
        version: 1,
        uploadedAt: new Date().toISOString(),
        metadata: {
          lastModified: file.lastModified,
          width: null,
          height: null,
          duration: null,
        }
      }

      uploadedAssets.push(asset)
    }

    // Update brand record with new assets
    if (uploadedAssets.length > 0) {
      const brand = await prisma.brand.findUnique({
        where: { id: brandId }
      })

      if (!brand) {
        return NextResponse.json(
          { error: 'Brand not found' },
          { status: 404 }
        )
      }

      // Parse existing brand assets or start with empty array
      const existingAssets = brand.brandAssets 
        ? JSON.parse(brand.brandAssets) 
        : []

      // Add new assets to existing ones
      const updatedAssets = [...existingAssets, ...uploadedAssets]

      // Update brand record
      await prisma.brand.update({
        where: { id: brandId },
        data: {
          brandAssets: JSON.stringify(updatedAssets),
          updatedAt: new Date()
        }
      })
    }

    return NextResponse.json({
      success: true,
      assets: uploadedAssets,
      message: `Successfully uploaded ${uploadedAssets.length} asset(s)`
    })

  } catch (error) {
    console.error('Asset upload error:', error)
    return NextResponse.json(
      { error: 'Failed to upload assets' },
      { status: 500 }
    )
  }
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const brandId = searchParams.get('brandId')
    const category = searchParams.get('category')
    const search = searchParams.get('search')
    const type = searchParams.get('type')

    if (!brandId) {
      return NextResponse.json(
        { error: 'Brand ID is required' },
        { status: 400 }
      )
    }

    const brand = await prisma.brand.findUnique({
      where: { id: brandId }
    })

    if (!brand) {
      return NextResponse.json(
        { error: 'Brand not found' },
        { status: 404 }
      )
    }

    let assets = brand.brandAssets ? JSON.parse(brand.brandAssets) : []

    // Apply filters
    if (category && category !== 'all') {
      assets = assets.filter((asset: any) => asset.category === category)
    }

    if (type && type !== 'all') {
      assets = assets.filter((asset: any) => asset.type === type)
    }

    if (search) {
      const searchLower = search.toLowerCase()
      assets = assets.filter((asset: any) =>
        asset.name.toLowerCase().includes(searchLower) ||
        asset.tags.some((tag: string) => tag.toLowerCase().includes(searchLower))
      )
    }

    return NextResponse.json({
      success: true,
      assets: assets,
      total: assets.length
    })

  } catch (error) {
    console.error('Asset fetch error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch assets' },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const brandId = searchParams.get('brandId')
    const assetId = searchParams.get('assetId')

    if (!brandId || !assetId) {
      return NextResponse.json(
        { error: 'Brand ID and Asset ID are required' },
        { status: 400 }
      )
    }

    const brand = await prisma.brand.findUnique({
      where: { id: brandId }
    })

    if (!brand) {
      return NextResponse.json(
        { error: 'Brand not found' },
        { status: 404 }
      )
    }

    const assets = brand.brandAssets ? JSON.parse(brand.brandAssets) : []
    const assetIndex = assets.findIndex((asset: any) => asset.id === assetId)

    if (assetIndex === -1) {
      return NextResponse.json(
        { error: 'Asset not found' },
        { status: 404 }
      )
    }

    const asset = assets[assetIndex]

    // Delete file from disk
    try {
      const filePath = path.join(UPLOAD_DIR, asset.fileName)
      await fs.unlink(filePath)
    } catch (error) {
      console.warn('Failed to delete file from disk:', error)
    }

    // Remove asset from array
    assets.splice(assetIndex, 1)

    // Update brand record
    await prisma.brand.update({
      where: { id: brandId },
      data: {
        brandAssets: JSON.stringify(assets),
        updatedAt: new Date()
      }
    })

    return NextResponse.json({
      success: true,
      message: 'Asset deleted successfully'
    })

  } catch (error) {
    console.error('Asset deletion error:', error)
    return NextResponse.json(
      { error: 'Failed to delete asset' },
      { status: 500 }
    )
  }
}