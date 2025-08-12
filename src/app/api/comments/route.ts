import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { z } from 'zod'

const prisma = new PrismaClient()

// Validation schemas
const createCommentSchema = z.object({
  content: z.string().min(1).max(2000),
  targetType: z.enum(['CAMPAIGN', 'JOURNEY', 'CONTENT', 'BRAND']),
  targetId: z.string(),
  parentCommentId: z.string().optional(),
  mentions: z.array(z.string()).optional(),
})

const commentQuerySchema = z.object({
  targetType: z.enum(['CAMPAIGN', 'JOURNEY', 'CONTENT', 'BRAND']).optional(),
  targetId: z.string().optional(),
  limit: z.string().transform(val => parseInt(val, 10)).optional(),
  offset: z.string().transform(val => parseInt(val, 10)).optional(),
  includeReplies: z.string().transform(val => val === 'true').optional(),
  status: z.enum(['all', 'resolved', 'unresolved']).optional(),
})

// GET /api/comments - Fetch comments
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const query = commentQuerySchema.parse(Object.fromEntries(searchParams))

    const {
      targetType,
      targetId,
      limit = 50,
      offset = 0,
      includeReplies = true,
      status = 'all'
    } = query

    const where: any = {
      isDeleted: false,
    }

    if (targetType) where.targetType = targetType
    if (targetId) where.targetId = targetId
    
    if (status === 'resolved') {
      where.isResolved = true
    } else if (status === 'unresolved') {
      where.isResolved = false
    }

    // Get root comments first (no parent)
    const rootWhere = { ...where, parentCommentId: null }

    const comments = await prisma.comment.findMany({
      where: rootWhere,
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
        replies: includeReplies ? {
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
          orderBy: { createdAt: 'asc' },
        } : false,
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
    })

    const total = await prisma.comment.count({ where: rootWhere })

    return NextResponse.json({
      success: true,
      data: comments,
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + comments.length < total,
      },
    })
  } catch (error) {
    console.error('Error fetching comments:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to fetch comments' },
      { status: 500 }
    )
  }
}

// POST /api/comments - Create new comment
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const validatedData = createCommentSchema.parse(body)

    // TODO: Get actual user ID from authentication
    const authorId = 'temp-user-id'

    const comment = await prisma.comment.create({
      data: {
        content: validatedData.content,
        targetType: validatedData.targetType,
        targetId: validatedData.targetId,
        authorId,
        parentCommentId: validatedData.parentCommentId,
        mentions: validatedData.mentions ? JSON.stringify(validatedData.mentions) : null,
      },
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

    // TODO: Send notifications to mentioned users
    if (validatedData.mentions && validatedData.mentions.length > 0) {
      // Implementation for sending mention notifications
    }

    return NextResponse.json({
      success: true,
      data: comment,
    }, { status: 201 })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid request data', details: error.errors },
        { status: 400 }
      )
    }

    console.error('Error creating comment:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to create comment' },
      { status: 500 }
    )
  }
}