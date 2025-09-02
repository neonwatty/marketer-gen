import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'
import { z } from 'zod'

import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/db'
import { updateTaskStatus, updateTaskDetails, deleteTask, assignTask } from '@/lib/task-operations'

const updateTaskSchema = z.object({
  stageId: z.string(),
  status: z.enum(['pending', 'in_progress', 'completed', 'blocked']).optional(),
  priority: z.enum(['low', 'medium', 'high', 'urgent']).optional(),
  assigneeId: z.string().optional(),
  assigneeName: z.string().optional(),
  name: z.string().optional(),
  description: z.string().optional(),
  dueDate: z.string().optional(),
  estimatedHours: z.number().optional(),
  actualHours: z.number().optional(),
  notes: z.string().optional(),
  tags: z.array(z.string()).optional()
})

const assignTaskSchema = z.object({
  stageId: z.string(),
  assigneeId: z.string(),
  assigneeName: z.string()
})

// PUT /api/journeys/[id]/tasks/[taskId] - Update specific task
export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; taskId: string }> }
) {
  try {
    const { id: journeyId, taskId } = await params
    const session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Verify journey access
    const journey = await prisma.journey.findFirst({
      where: {
        id: journeyId,
        deletedAt: null,
        campaign: {
          userId: session.user.id,
          deletedAt: null
        }
      }
    })

    if (!journey) {
      return NextResponse.json({ error: 'Journey not found' }, { status: 404 })
    }

    const body = await request.json()
    const validatedData = updateTaskSchema.parse(body)

    // Check if this is just a status update (most common operation)
    if (validatedData.status && Object.keys(validatedData).length === 2) { // stageId + status
      const result = await updateTaskStatus(
        journeyId,
        validatedData.stageId,
        taskId,
        validatedData.status,
        session.user.id
      )
      
      if (!result.success) {
        return NextResponse.json({ error: result.error }, { status: 400 })
      }

      return NextResponse.json({
        success: true,
        journeyData: result.journeyData
      })
    } else {
      // Full task update
      const { stageId, ...updates } = validatedData
      const result = await updateTaskDetails(
        journeyId,
        stageId,
        taskId,
        updates,
        session.user.id
      )
      
      if (!result.success) {
        return NextResponse.json({ error: result.error }, { status: 400 })
      }

      return NextResponse.json({
        success: true,
        journeyData: result.journeyData
      })
    }
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json({ 
        error: 'Validation error', 
        details: error.errors 
      }, { status: 400 })
    }
    
    console.error('Error updating task:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

// DELETE /api/journeys/[id]/tasks/[taskId] - Delete specific task
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; taskId: string }> }
) {
  try {
    const { id: journeyId, taskId } = await params
    const session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Verify journey access
    const journey = await prisma.journey.findFirst({
      where: {
        id: journeyId,
        deletedAt: null,
        campaign: {
          userId: session.user.id,
          deletedAt: null
        }
      }
    })

    if (!journey) {
      return NextResponse.json({ error: 'Journey not found' }, { status: 404 })
    }

    const url = new URL(request.url)
    const stageId = url.searchParams.get('stageId')
    
    if (!stageId) {
      return NextResponse.json({ error: 'stageId is required' }, { status: 400 })
    }

    const result = await deleteTask(journeyId, stageId, taskId, session.user.id)
    
    if (!result.success) {
      return NextResponse.json({ error: result.error }, { status: 400 })
    }

    return NextResponse.json({
      success: true,
      journeyData: result.journeyData
    })
  } catch (error) {
    console.error('Error deleting task:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

// PATCH /api/journeys/[id]/tasks/[taskId] - Assign task
export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; taskId: string }> }
) {
  try {
    const { id: journeyId, taskId } = await params
    const session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Verify journey access
    const journey = await prisma.journey.findFirst({
      where: {
        id: journeyId,
        deletedAt: null,
        campaign: {
          userId: session.user.id,
          deletedAt: null
        }
      }
    })

    if (!journey) {
      return NextResponse.json({ error: 'Journey not found' }, { status: 404 })
    }

    const body = await request.json()
    const validatedData = assignTaskSchema.parse(body)

    const result = await assignTask(
      journeyId,
      validatedData.stageId,
      taskId,
      validatedData.assigneeId,
      validatedData.assigneeName,
      session.user.id
    )
    
    if (!result.success) {
      return NextResponse.json({ error: result.error }, { status: 400 })
    }

    return NextResponse.json({
      success: true,
      journeyData: result.journeyData
    })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json({ 
        error: 'Validation error', 
        details: error.errors 
      }, { status: 400 })
    }
    
    console.error('Error assigning task:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}