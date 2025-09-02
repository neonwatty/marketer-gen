import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'
import { z } from 'zod'

import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/db'
import { bulkUpdateTasks, addTask } from '@/lib/task-operations'

const bulkUpdateSchema = z.object({
  updates: z.array(z.object({
    stageId: z.string(),
    taskId: z.string(),
    updates: z.object({
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
  }))
})

const addTaskSchema = z.object({
  stageId: z.string(),
  name: z.string().min(1, 'Task name is required'),
  description: z.string().optional(),
  priority: z.enum(['low', 'medium', 'high', 'urgent']).default('medium'),
  assigneeId: z.string().optional(),
  assigneeName: z.string().optional(),
  dueDate: z.string().optional(),
  estimatedHours: z.number().optional(),
  tags: z.array(z.string()).optional()
})

// GET /api/journeys/[id]/tasks - Get all tasks for a journey
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
        status: true
      }
    })

    if (!journey) {
      return NextResponse.json({ error: 'Journey not found' }, { status: 404 })
    }

    // Extract all tasks from all stages
    const journeyData = journey.stages as any
    const allTasks = journeyData.stages?.flatMap((stage: any) => 
      stage.tasks?.map((task: any) => ({
        ...task,
        stageId: stage.id,
        stageName: stage.name
      })) || []
    ) || []

    return NextResponse.json({
      success: true,
      tasks: allTasks,
      metadata: journeyData.metadata
    })
  } catch (error) {
    console.error('Error fetching tasks:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

// POST /api/journeys/[id]/tasks - Add new task or bulk update
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Verify journey access
    const journey = await prisma.journey.findFirst({
      where: {
        id,
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

    // Check if this is a bulk update or new task
    if (body.updates) {
      // Bulk update
      const validatedData = bulkUpdateSchema.parse(body)
      const result = await bulkUpdateTasks(id, validatedData.updates, session.user.id)
      
      if (!result.success) {
        return NextResponse.json({ error: result.error }, { status: 400 })
      }

      return NextResponse.json({
        success: true,
        journeyData: result.journeyData
      })
    } else {
      // Add new task
      const validatedData = addTaskSchema.parse(body)
      const result = await addTask(
        id,
        validatedData.stageId,
        {
          name: validatedData.name,
          description: validatedData.description,
          priority: validatedData.priority,
          assigneeId: validatedData.assigneeId,
          assigneeName: validatedData.assigneeName,
          dueDate: validatedData.dueDate,
          estimatedHours: validatedData.estimatedHours,
          tags: validatedData.tags
        },
        session.user.id
      )
      
      if (!result.success) {
        return NextResponse.json({ error: result.error }, { status: 400 })
      }

      return NextResponse.json({
        success: true,
        task: result.task,
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
    
    console.error('Error processing task request:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}