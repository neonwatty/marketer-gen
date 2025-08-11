import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/db'
import { CampaignStatus } from '@prisma/client'
import { z } from 'zod'

// Validation schema for updating campaigns
const updateCampaignSchema = z.object({
  name: z.string().min(1, 'Campaign name is required').max(100, 'Campaign name must be less than 100 characters').optional(),
  description: z.string().optional(),
  status: z.nativeEnum(CampaignStatus).optional(),
  goals: z.string().optional(), // JSON string
  targetKPIs: z.string().optional(), // JSON string
  timeline: z.string().optional(), // JSON string
  budget: z.number().positive().optional(),
  metadata: z.string().optional() // JSON string
})

interface RouteParams {
  params: Promise<{
    id: string
  }>
}

// Helper function to validate campaign ID
function isValidCuid(id: string): boolean {
  // More flexible CUID validation - allow different formats
  // Check for reasonable length and alphanumeric characters
  if (!id || typeof id !== 'string') return false
  if (id.length < 10 || id.length > 30) return false
  // Allow alphanumeric characters and hyphens for flexibility
  const cuidRegex = /^[a-zA-Z0-9\-_]+$/
  return cuidRegex.test(id)
}

// GET /api/campaigns/[id] - Get single campaign
export async function GET(
  request: NextRequest,
  { params }: RouteParams
) {
  try {
    const { id } = await params
    
    // Validate campaign ID format
    if (!isValidCuid(id)) {
      return NextResponse.json(
        { error: 'Invalid campaign ID format', success: false },
        { status: 400 }
      )
    }
    
    // Get campaign with related data
    const campaign = await prisma.campaign.findUnique({
      where: { id },
      include: {
        brand: {
          select: { 
            id: true, 
            name: true, 
            description: true,
            primaryColor: true,
            secondaryColor: true 
          }
        },
        journeys: {
          select: { 
            id: true, 
            name: true, 
            description: true,
            status: true,
            createdAt: true,
            updatedAt: true
          },
          orderBy: { updatedAt: 'desc' }
        },
        analytics: {
          select: { 
            id: true,
            eventType: true,
            views: true, 
            clicks: true, 
            conversions: true,
            engagementRate: true,
            conversionRate: true,
            revenue: true,
            cost: true,
            timestamp: true
          },
          orderBy: { timestamp: 'desc' },
          take: 50 // Limit recent analytics
        },
        _count: {
          select: { 
            journeys: true, 
            analytics: true 
          }
        }
      }
    })
    
    if (!campaign) {
      return NextResponse.json(
        { error: 'Campaign not found', success: false },
        { status: 404 }
      )
    }
    
    return NextResponse.json({
      data: campaign,
      success: true
    })
    
  } catch (error) {
    console.error('Error fetching campaign:', error)
    return NextResponse.json(
      { error: 'Failed to fetch campaign', success: false },
      { status: 500 }
    )
  }
}

// PUT /api/campaigns/[id] - Update campaign
export async function PUT(
  request: NextRequest,
  { params }: RouteParams
) {
  try {
    const { id } = await params
    const body = await request.json()
    
    // Validate campaign ID format
    if (!isValidCuid(id)) {
      return NextResponse.json(
        { error: 'Invalid campaign ID format', success: false },
        { status: 400 }
      )
    }
    
    // Validate request body
    const validationResult = updateCampaignSchema.safeParse(body)
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
    
    // Check if campaign exists
    const existingCampaign = await prisma.campaign.findUnique({
      where: { id }
    })
    
    if (!existingCampaign) {
      return NextResponse.json(
        { error: 'Campaign not found', success: false },
        { status: 404 }
      )
    }
    
    // Update campaign
    const updatedCampaign = await prisma.campaign.update({
      where: { id },
      data: {
        ...data,
        updatedAt: new Date()
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
      data: updatedCampaign,
      success: true,
      message: 'Campaign updated successfully'
    })
    
  } catch (error) {
    console.error('Error updating campaign:', error)
    return NextResponse.json(
      { error: 'Failed to update campaign', success: false },
      { status: 500 }
    )
  }
}

// DELETE /api/campaigns/[id] - Delete campaign
export async function DELETE(
  request: NextRequest,
  { params }: RouteParams
) {
  try {
    const { id } = await params
    
    // Validate campaign ID format
    if (!isValidCuid(id)) {
      return NextResponse.json(
        { error: 'Invalid campaign ID format', success: false },
        { status: 400 }
      )
    }
    
    // Check if campaign exists
    const existingCampaign = await prisma.campaign.findUnique({
      where: { id },
      include: {
        _count: {
          select: { 
            journeys: true, 
            analytics: true 
          }
        }
      }
    })
    
    if (!existingCampaign) {
      return NextResponse.json(
        { error: 'Campaign not found', success: false },
        { status: 404 }
      )
    }
    
    // Check if campaign has associated data
    const hasAssociatedData = existingCampaign._count.journeys > 0 || existingCampaign._count.analytics > 0
    
    if (hasAssociatedData) {
      // Option 1: Soft delete by setting status to ARCHIVED
      const archivedCampaign = await prisma.campaign.update({
        where: { id },
        data: { 
          status: CampaignStatus.ARCHIVED,
          updatedAt: new Date()
        }
      })
      
      return NextResponse.json({
        data: archivedCampaign,
        success: true,
        message: 'Campaign archived successfully (has associated data)'
      })
    } else {
      // Option 2: Hard delete if no associated data
      await prisma.campaign.delete({
        where: { id }
      })
      
      return NextResponse.json({
        data: { id },
        success: true,
        message: 'Campaign deleted successfully'
      })
    }
    
  } catch (error) {
    console.error('Error deleting campaign:', error)
    return NextResponse.json(
      { error: 'Failed to delete campaign', success: false },
      { status: 500 }
    )
  }
}