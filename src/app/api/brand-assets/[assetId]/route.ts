import { NextRequest, NextResponse } from 'next/server'
import { promises as fs } from 'fs'
import path from 'path'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

interface Params {
  assetId: string
}

export async function GET(
  request: NextRequest,
  { params }: { params: Params }
) {
  try {
    const { searchParams } = new URL(request.url)
    const brandId = searchParams.get('brandId')

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

    const assets = brand.brandAssets ? JSON.parse(brand.brandAssets) : []
    const asset = assets.find((asset: any) => asset.id === params.assetId)

    if (!asset) {
      return NextResponse.json(
        { error: 'Asset not found' },
        { status: 404 }
      )
    }

    return NextResponse.json({
      success: true,
      asset: asset
    })

  } catch (error) {
    console.error('Asset fetch error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch asset' },
      { status: 500 }
    )
  }
}

export async function PUT(
  request: NextRequest,
  { params }: { params: Params }
) {
  try {
    const { brandId, name, category, tags, metadata } = await request.json()

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

    const assets = brand.brandAssets ? JSON.parse(brand.brandAssets) : []
    const assetIndex = assets.findIndex((asset: any) => asset.id === params.assetId)

    if (assetIndex === -1) {
      return NextResponse.json(
        { error: 'Asset not found' },
        { status: 404 }
      )
    }

    // Update asset metadata
    assets[assetIndex] = {
      ...assets[assetIndex],
      name: name || assets[assetIndex].name,
      category: category || assets[assetIndex].category,
      tags: tags || assets[assetIndex].tags,
      metadata: { ...assets[assetIndex].metadata, ...metadata },
      updatedAt: new Date().toISOString()
    }

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
      asset: assets[assetIndex],
      message: 'Asset updated successfully'
    })

  } catch (error) {
    console.error('Asset update error:', error)
    return NextResponse.json(
      { error: 'Failed to update asset' },
      { status: 500 }
    )
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Params }
) {
  try {
    const { searchParams } = new URL(request.url)
    const brandId = searchParams.get('brandId')

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

    const assets = brand.brandAssets ? JSON.parse(brand.brandAssets) : []
    const assetIndex = assets.findIndex((asset: any) => asset.id === params.assetId)

    if (assetIndex === -1) {
      return NextResponse.json(
        { error: 'Asset not found' },
        { status: 404 }
      )
    }

    const asset = assets[assetIndex]

    // Delete file from disk
    try {
      const UPLOAD_DIR = path.join(process.cwd(), 'public/uploads/brand-assets')
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