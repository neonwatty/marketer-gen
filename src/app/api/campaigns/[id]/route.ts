import '@/lib/types/auth'

import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'

import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/db'
import {
  updateCampaignSchema} from '@/lib/validation/campaigns'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { id } = await params
    const campaign = await prisma.campaign.findUnique({
      where: {
        id,
        userId: session.user.id,
        deletedAt: null
      },
      include: {
        brand: {
          select: {
            id: true,
            name: true,
            description: true,
            tagline: true,
            mission: true,
            vision: true
          }
        },
        journeys: {
          where: {
            deletedAt: null
          },
          include: {
            content: {
              where: {
                deletedAt: null
              },
              select: {
                id: true,
                type: true,
                status: true
              }
            },
            _count: {
              select: {
                content: true
              }
            }
          }
        },
        analytics: {
          select: {
            id: true,
            eventType: true,
            metrics: true,
            timestamp: true
          },
          orderBy: {
            timestamp: 'desc'
          },
          take: 10
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
        { error: 'Campaign not found' },
        { status: 404 }
      )
    }

    return NextResponse.json(campaign)
  } catch (error) {
    console.error('Error fetching campaign:', error)
    return NextResponse.json(
      { error: 'Failed to fetch campaign' },
      { status: 500 }
    )
  }
}

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    
    // Validate request body
    const validation = updateCampaignSchema.safeParse(body)
    
    if (!validation.success) {
      return NextResponse.json(
        { error: 'Invalid request data', details: validation.error.format() },
        { status: 400 }
      )
    }

    const { name, purpose, goals, brandId, startDate, endDate, status } = validation.data

    // Verify the campaign exists and belongs to the user
    const { id } = await params
    const existingCampaign = await prisma.campaign.findUnique({
      where: {
        id,
        userId: session.user.id,
        deletedAt: null
      }
    })

    if (!existingCampaign) {
      return NextResponse.json(
        { error: 'Campaign not found' },
        { status: 404 }
      )
    }

    // If brandId is being changed, verify the new brand belongs to the user
    if (brandId && brandId !== existingCampaign.brandId) {
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
    }

    const updateData: any = {
      updatedBy: session.user.id
    }

    if (name !== undefined) updateData.name = name
    if (purpose !== undefined) updateData.purpose = purpose
    if (goals !== undefined) updateData.goals = goals
    if (brandId !== undefined) updateData.brandId = brandId
    if (startDate !== undefined) updateData.startDate = startDate ? new Date(startDate) : null
    if (endDate !== undefined) updateData.endDate = endDate ? new Date(endDate) : null
    if (status !== undefined) updateData.status = status

    const campaign = await prisma.campaign.update({
      where: {
        id
      },
      data: updateData,
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

    return NextResponse.json(campaign)
  } catch (error) {
    console.error('Error updating campaign:', error)
    return NextResponse.json(
      { error: 'Failed to update campaign' },
      { status: 500 }
    )
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Check if campaign exists and belongs to user
    const { id } = await params
    const existingCampaign = await prisma.campaign.findUnique({
      where: {
        id,
        userId: session.user.id,
        deletedAt: null
      }
    })

    if (!existingCampaign) {
      return NextResponse.json(
        { error: 'Campaign not found' },
        { status: 404 }
      )
    }

    // Use transaction for soft delete to ensure consistency
    await prisma.$transaction(async (tx) => {
      // Soft delete all related journeys
      await tx.journey.updateMany({
        where: {
          campaignId: id,
          deletedAt: null
        },
        data: {
          deletedAt: new Date(),
          updatedBy: session.user.id
        }
      })

      // Soft delete all related content through journeys
      const journeyIds = await tx.journey.findMany({
        where: {
          campaignId: id
        },
        select: {
          id: true
        }
      })

      if (journeyIds.length > 0) {
        await tx.content.updateMany({
          where: {
            journeyId: {
              in: journeyIds.map(j => j.id)
            },
            deletedAt: null
          },
          data: {
            deletedAt: new Date(),
            updatedBy: session.user.id
          }
        })
      }

      // Soft delete the campaign
      await tx.campaign.update({
        where: {
          id
        },
        data: {
          deletedAt: new Date(),
          updatedBy: session.user.id
        }
      })
    })

    return NextResponse.json({ message: 'Campaign deleted successfully' })
  } catch (error) {
    console.error('Error deleting campaign:', error)
    return NextResponse.json(
      { error: 'Failed to delete campaign' },
      { status: 500 }
    )
  }
}