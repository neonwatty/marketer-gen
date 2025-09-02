import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'

import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/db'

// GET /api/journeys/[id] - Get specific journey
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const journey = await prisma.journey.findFirst({
      where: {
        id,
        deletedAt: null,
        campaign: {
          userId: session.user.id,
          deletedAt: null
        }
      },
      select: {
        id: true,
        stages: true,
        status: true,
        createdAt: true,
        updatedAt: true,
        campaign: {
          select: {
            id: true,
            name: true,
            purpose: true,
            status: true,
            brand: {
              select: {
                id: true,
                name: true
              }
            }
          }
        },
        content: {
          select: {
            id: true,
            type: true,
            status: true,
            createdAt: true
          },
          where: { deletedAt: null },
          orderBy: { createdAt: 'desc' }
        }
      }
    })

    if (!journey) {
      return NextResponse.json({ error: 'Journey not found' }, { status: 404 })
    }

    return NextResponse.json(journey)
  } catch (error) {
    console.error('Error fetching journey:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}