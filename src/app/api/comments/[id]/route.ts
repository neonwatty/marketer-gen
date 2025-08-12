import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { z } from 'zod'

const prisma = new PrismaClient()

// Validation schemas
const updateCommentSchema = z.object({
  content: z.string().min(1).max(2000).optional(),
  isResolved: z.boolean().optional(),
  isDeleted: z.boolean().optional(),
})

const reactionSchema = z.object({
  type: z.enum(['LIKE', 'DISLIKE', 'LOVE', 'LAUGH', 'ANGRY', 'SAD', 'THUMBS_UP', 'THUMBS_DOWN']),
})

// GET /api/comments/[id] - Get specific comment
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const comment = await prisma.comment.findUnique({
      where: { id: params.id },
      include: {
        author: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
        reactions: {
          include: {
            user: {
              select: {
                id: true,
                name: true,
                email: true,
              },
            },
          },
        },
        replies: {
          include: {
            author: {
              select: {
                id: true,
                name: true,
                email: true,
              },
            },
            reactions: {
              include: {
                user: {
                  select: {
                    id: true,
                    name: true,
                    email: true,
                  },
                },
              },
            },
          },
          orderBy: { createdAt: 'asc' },
        },
      },
    })

    if (!comment || comment.isDeleted) {
      return NextResponse.json(
        { success: false, error: 'Comment not found' },
        { status: 404 }
      )
    }

    return NextResponse.json({
      success: true,
      data: comment,
    })
  } catch (error) {
    console.error('Error fetching comment:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to fetch comment' },
      { status: 500 }
    )
  }
}

// PATCH /api/comments/[id] - Update comment
export async function PATCH(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const body = await request.json()
    const validatedData = updateCommentSchema.parse(body)

    // TODO: Get actual user ID from authentication and check permissions
    const currentUserId = 'temp-user-id'

    // Check if comment exists and user has permission to edit
    const existingComment = await prisma.comment.findUnique({
      where: { id: params.id },
      select: { authorId: true, isDeleted: true },
    })

    if (!existingComment || existingComment.isDeleted) {
      return NextResponse.json(
        { success: false, error: 'Comment not found' },
        { status: 404 }
      )
    }

    // TODO: Add permission check - user must be author or have moderation rights
    // For now, allow if user is the author
    if (existingComment.authorId !== currentUserId) {
      return NextResponse.json(
        { success: false, error: 'Insufficient permissions' },
        { status: 403 }
      )
    }

    const updateData: any = {}
    
    if (validatedData.content !== undefined) {
      updateData.content = validatedData.content
      updateData.isEdited = true
    }
    
    if (validatedData.isResolved !== undefined) {
      updateData.isResolved = validatedData.isResolved
      if (validatedData.isResolved) {
        updateData.resolvedAt = new Date()
      } else {
        updateData.resolvedAt = null
      }
    }
    
    if (validatedData.isDeleted !== undefined) {
      updateData.isDeleted = validatedData.isDeleted
    }

    const comment = await prisma.comment.update({
      where: { id: params.id },
      data: updateData,
      include: {
        author: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
        reactions: {
          include: {
            user: {
              select: {
                id: true,
                name: true,
                email: true,
              },
            },
          },
        },
        replies: {
          include: {
            author: {
              select: {
                id: true,
                name: true,
                email: true,
              },
            },
            reactions: {
              include: {
                user: {
                  select: {
                    id: true,
                    name: true,
                    email: true,
                  },
                },
              },
            },
          },
          orderBy: { createdAt: 'asc' },
        },
      },
    })

    return NextResponse.json({
      success: true,
      data: comment,
    })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid request data', details: error.errors },
        { status: 400 }
      )
    }

    console.error('Error updating comment:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to update comment' },
      { status: 500 }
    )
  }
}

// DELETE /api/comments/[id] - Delete comment
export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    // TODO: Get actual user ID from authentication and check permissions
    const currentUserId = 'temp-user-id'

    // Check if comment exists and user has permission to delete
    const existingComment = await prisma.comment.findUnique({
      where: { id: params.id },
      select: { authorId: true, isDeleted: true },
    })

    if (!existingComment || existingComment.isDeleted) {
      return NextResponse.json(
        { success: false, error: 'Comment not found' },
        { status: 404 }
      )
    }

    // TODO: Add permission check - user must be author or have moderation rights
    if (existingComment.authorId !== currentUserId) {
      return NextResponse.json(
        { success: false, error: 'Insufficient permissions' },
        { status: 403 }
      )
    }

    // Soft delete the comment
    await prisma.comment.update({
      where: { id: params.id },
      data: { isDeleted: true },
    })

    return NextResponse.json({
      success: true,
      message: 'Comment deleted successfully',
    })
  } catch (error) {
    console.error('Error deleting comment:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to delete comment' },
      { status: 500 }
    )
  }
}