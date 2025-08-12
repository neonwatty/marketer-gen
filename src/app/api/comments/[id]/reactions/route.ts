import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { z } from 'zod'

const prisma = new PrismaClient()

// Validation schemas
const reactionSchema = z.object({
  type: z.enum(['LIKE', 'DISLIKE', 'LOVE', 'LAUGH', 'ANGRY', 'SAD', 'THUMBS_UP', 'THUMBS_DOWN']),
})

// GET /api/comments/[id]/reactions - Get comment reactions
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const reactions = await prisma.commentReaction.findMany({
      where: { commentId: params.id },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    })

    // Group reactions by type with counts
    const reactionCounts = reactions.reduce((acc, reaction) => {
      if (!acc[reaction.type]) {
        acc[reaction.type] = {
          count: 0,
          users: [],
        }
      }
      acc[reaction.type].count++
      acc[reaction.type].users.push(reaction.user)
      return acc
    }, {} as Record<string, { count: number; users: any[] }>)

    return NextResponse.json({
      success: true,
      data: {
        reactions,
        counts: reactionCounts,
        total: reactions.length,
      },
    })
  } catch (error) {
    console.error('Error fetching reactions:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to fetch reactions' },
      { status: 500 }
    )
  }
}

// POST /api/comments/[id]/reactions - Add reaction to comment
export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const body = await request.json()
    const validatedData = reactionSchema.parse(body)

    // TODO: Get actual user ID from authentication
    const currentUserId = 'temp-user-id'

    // Check if comment exists
    const comment = await prisma.comment.findUnique({
      where: { id: params.id },
      select: { id: true, isDeleted: true },
    })

    if (!comment || comment.isDeleted) {
      return NextResponse.json(
        { success: false, error: 'Comment not found' },
        { status: 404 }
      )
    }

    // Check if user already has a reaction on this comment
    const existingReaction = await prisma.commentReaction.findUnique({
      where: {
        userId_commentId: {
          userId: currentUserId,
          commentId: params.id,
        },
      },
    })

    let reaction

    if (existingReaction) {
      if (existingReaction.type === validatedData.type) {
        // Same reaction type - remove it (toggle off)
        await prisma.commentReaction.delete({
          where: { id: existingReaction.id },
        })

        return NextResponse.json({
          success: true,
          data: null,
          message: 'Reaction removed',
        })
      } else {
        // Different reaction type - update it
        reaction = await prisma.commentReaction.update({
          where: { id: existingReaction.id },
          data: { type: validatedData.type },
          include: {
            user: {
              select: {
                id: true,
                name: true,
                email: true,
              },
            },
          },
        })
      }
    } else {
      // No existing reaction - create new one
      reaction = await prisma.commentReaction.create({
        data: {
          type: validatedData.type,
          userId: currentUserId,
          commentId: params.id,
        },
        include: {
          user: {
            select: {
              id: true,
              name: true,
              email: true,
            },
          },
        },
      })
    }

    return NextResponse.json({
      success: true,
      data: reaction,
      message: existingReaction ? 'Reaction updated' : 'Reaction added',
    }, { status: existingReaction ? 200 : 201 })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid request data', details: error.errors },
        { status: 400 }
      )
    }

    console.error('Error adding reaction:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to add reaction' },
      { status: 500 }
    )
  }
}

// DELETE /api/comments/[id]/reactions - Remove user's reaction from comment
export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    // TODO: Get actual user ID from authentication
    const currentUserId = 'temp-user-id'

    // Find and delete the user's reaction
    const reaction = await prisma.commentReaction.findUnique({
      where: {
        userId_commentId: {
          userId: currentUserId,
          commentId: params.id,
        },
      },
    })

    if (!reaction) {
      return NextResponse.json(
        { success: false, error: 'Reaction not found' },
        { status: 404 }
      )
    }

    await prisma.commentReaction.delete({
      where: { id: reaction.id },
    })

    return NextResponse.json({
      success: true,
      message: 'Reaction removed successfully',
    })
  } catch (error) {
    console.error('Error removing reaction:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to remove reaction' },
      { status: 500 }
    )
  }
}