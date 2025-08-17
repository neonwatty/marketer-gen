import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'
import { prisma } from '@/lib/db'
import { authOptions } from '@/lib/auth'
import { 
  duplicateCampaignSchema,
  type DuplicateCampaignData
} from '@/lib/validation/campaigns'
import '@/lib/types/auth'
import { Prisma } from '@/generated/prisma'

export async function POST(
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
    const validation = duplicateCampaignSchema.safeParse(body)
    
    if (!validation.success) {
      return NextResponse.json(
        { error: 'Invalid request data', details: validation.error.format() },
        { status: 400 }
      )
    }

    const { name } = validation.data

    // Fetch the original campaign with all related data
    const { id } = await params
    const originalCampaign = await prisma.campaign.findUnique({
      where: {
        id,
        userId: session.user.id,
        deletedAt: null
      },
      include: {
        journeys: {
          where: {
            deletedAt: null
          },
          include: {
            content: {
              where: {
                deletedAt: null
              }
            }
          }
        }
      }
    })

    if (!originalCampaign) {
      return NextResponse.json(
        { error: 'Campaign not found' },
        { status: 404 }
      )
    }

    // Use transaction to ensure atomicity
    const duplicatedCampaign = await prisma.$transaction(async (tx) => {
      // Create the new campaign
      const newCampaign = await tx.campaign.create({
        data: {
          name,
          purpose: originalCampaign.purpose,
          goals: originalCampaign.goals as Prisma.InputJsonValue,
          brandId: originalCampaign.brandId,
          userId: session.user.id,
          status: 'DRAFT', // Always start duplicated campaigns as draft
          createdBy: session.user.id,
          updatedBy: session.user.id
        }
      })

      // Duplicate all journeys and their content
      for (const journey of originalCampaign.journeys) {
        const newJourney = await tx.journey.create({
          data: {
            campaignId: newCampaign.id,
            stages: journey.stages as Prisma.InputJsonValue,
            status: 'DRAFT', // Always start duplicated journeys as draft
            createdBy: session.user.id,
            updatedBy: session.user.id
          }
        })

        // Duplicate all content for this journey
        for (const content of journey.content) {
          await tx.content.create({
            data: {
              journeyId: newJourney.id,
              type: content.type,
              content: content.content,
              status: 'DRAFT', // Always start duplicated content as draft
              variants: content.variants as Prisma.InputJsonValue,
              metadata: content.metadata as Prisma.InputJsonValue,
              createdBy: session.user.id,
              updatedBy: session.user.id
            }
          })
        }
      }

      // Return the new campaign with includes
      return await tx.campaign.findUnique({
        where: {
          id: newCampaign.id
        },
        include: {
          brand: {
            select: {
              id: true,
              name: true
            }
          },
          journeys: {
            include: {
              content: {
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
          _count: {
            select: {
              journeys: true
            }
          }
        }
      })
    })

    return NextResponse.json(duplicatedCampaign, { status: 201 })
  } catch (error) {
    console.error('Error duplicating campaign:', error)
    return NextResponse.json(
      { error: 'Failed to duplicate campaign' },
      { status: 500 }
    )
  }
}