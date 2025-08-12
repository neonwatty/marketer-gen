import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { z } from 'zod'

const prisma = new PrismaClient()

// Validation schemas
const moderationSchema = z.object({
  action: z.enum(['approve', 'reject', 'hide', 'show', 'flag', 'resolve', 'unresolve']),
  reason: z.string().optional(),
  metadata: z.record(z.any()).optional(),
})

// POST /api/comments/[id]/moderate - Perform moderation action
export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const body = await request.json()
    const validatedData = moderationSchema.parse(body)

    // TODO: Get actual user ID from authentication and check moderation permissions
    const currentUserId = 'temp-moderator-id'

    // Check if comment exists
    const comment = await prisma.comment.findUnique({
      where: { id: params.id },
      select: { 
        id: true, 
        isDeleted: true, 
        isResolved: true,
        authorId: true,
        content: true,
      },
    })

    if (!comment) {
      return NextResponse.json(
        { success: false, error: 'Comment not found' },
        { status: 404 }
      )
    }

    // TODO: Add proper permission check for moderation rights
    // For now, assume user has moderation permissions

    let updateData: any = {}
    let actionMessage = ''

    switch (validatedData.action) {
      case 'approve':
        // Custom approval logic can be added here
        actionMessage = 'Comment approved'
        break

      case 'reject':
        updateData.isDeleted = true
        actionMessage = 'Comment rejected and hidden'
        if (validatedData.reason) {
          updateData.metadata = JSON.stringify({
            moderationReason: validatedData.reason,
            moderatedBy: currentUserId,
            moderatedAt: new Date().toISOString(),
          })
        }
        break

      case 'hide':
        updateData.isDeleted = true
        actionMessage = 'Comment hidden from public view'
        updateData.metadata = JSON.stringify({
          moderationAction: 'hidden',
          moderatedBy: currentUserId,
          moderatedAt: new Date().toISOString(),
          reason: validatedData.reason,
        })
        break

      case 'show':
        if (comment.isDeleted) {
          updateData.isDeleted = false
          actionMessage = 'Comment restored to public view'
        } else {
          return NextResponse.json(
            { success: false, error: 'Comment is already visible' },
            { status: 400 }
          )
        }
        break

      case 'flag':
        actionMessage = 'Comment flagged for review'
        updateData.metadata = JSON.stringify({
          flagged: true,
          flaggedBy: currentUserId,
          flaggedAt: new Date().toISOString(),
          flagReason: validatedData.reason,
        })
        break

      case 'resolve':
        updateData.isResolved = true
        updateData.resolvedAt = new Date()
        actionMessage = 'Comment thread marked as resolved'
        break

      case 'unresolve':
        updateData.isResolved = false
        updateData.resolvedAt = null
        actionMessage = 'Comment thread marked as unresolved'
        break

      default:
        return NextResponse.json(
          { success: false, error: 'Invalid moderation action' },
          { status: 400 }
        )
    }

    // Update the comment if there are changes
    let updatedComment = comment
    if (Object.keys(updateData).length > 0) {
      updatedComment = await prisma.comment.update({
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
    }

    // TODO: Create audit log entry for moderation action
    // TODO: Send notification to comment author if needed
    // TODO: Update any related approval workflows

    return NextResponse.json({
      success: true,
      data: updatedComment,
      message: actionMessage,
      action: validatedData.action,
    })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid request data', details: error.errors },
        { status: 400 }
      )
    }

    console.error('Error performing moderation action:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to perform moderation action' },
      { status: 500 }
    )
  }
}

// GET /api/comments/[id]/moderate - Get moderation history/info
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    // TODO: Check if user has moderation permissions
    
    const comment = await prisma.comment.findUnique({
      where: { id: params.id },
      select: {
        id: true,
        isDeleted: true,
        isResolved: true,
        resolvedAt: true,
        metadata: true,
        createdAt: true,
        updatedAt: true,
      },
    })

    if (!comment) {
      return NextResponse.json(
        { success: false, error: 'Comment not found' },
        { status: 404 }
      )
    }

    // Parse metadata to extract moderation history
    let moderationHistory = []
    if (comment.metadata) {
      try {
        const metadata = JSON.parse(comment.metadata)
        moderationHistory.push(metadata)
      } catch (e) {
        // Ignore JSON parse errors
      }
    }

    return NextResponse.json({
      success: true,
      data: {
        commentId: comment.id,
        isDeleted: comment.isDeleted,
        isResolved: comment.isResolved,
        resolvedAt: comment.resolvedAt,
        moderationHistory,
        lastModified: comment.updatedAt,
      },
    })
  } catch (error) {
    console.error('Error fetching moderation info:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to fetch moderation info' },
      { status: 500 }
    )
  }
}