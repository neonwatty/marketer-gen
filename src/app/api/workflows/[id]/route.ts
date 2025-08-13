import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { z } from 'zod'

const prisma = new PrismaClient()

// Validation schemas
const updateWorkflowSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  description: z.string().optional(),
  applicableTypes: z.array(z.enum(['CAMPAIGN', 'JOURNEY', 'CONTENT', 'BRAND'])).optional(),
  autoStart: z.boolean().optional(),
  allowParallelStages: z.boolean().optional(),
  requireAllApprovers: z.boolean().optional(),
  defaultTimeoutHours: z.number().min(1).max(720).optional(),
  isActive: z.boolean().optional(),
  stages: z.array(z.object({
    id: z.string().optional(), // For existing stages
    name: z.string().min(1),
    description: z.string().optional(),
    order: z.number().min(0),
    approversRequired: z.number().min(1).default(1),
    approvers: z.array(z.string()),
    approverRoles: z.array(z.string()).optional(),
    autoApprove: z.boolean().default(false),
    timeoutHours: z.number().min(1).max(720).optional(),
    skipConditions: z.array(z.object({
      type: z.enum(['user_role', 'content_type', 'budget_threshold', 'custom']),
      operator: z.enum(['equals', 'not_equals', 'greater_than', 'less_than', 'contains']),
      value: z.union([z.string(), z.number()])
    })).optional()
  })).optional()
})

// GET /api/workflows/[id] - Get specific workflow
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const workflow = await prisma.approvalWorkflow.findUnique({
      where: { id: params.id },
      include: {
        stages: {
          orderBy: { order: 'asc' },
        },
        requests: {
          include: {
            actions: {
              include: {
                stage: {
                  select: {
                    name: true,
                  },
                },
              },
              orderBy: { createdAt: 'desc' },
            },
          },
          orderBy: { createdAt: 'desc' },
          take: 10, // Latest 10 requests
        },
        _count: {
          select: {
            requests: true,
            stages: true,
          },
        },
      },
    })

    if (!workflow) {
      return NextResponse.json(
        { success: false, error: 'Workflow not found' },
        { status: 404 }
      )
    }

    // Transform response
    const transformedWorkflow = {
      ...workflow,
      applicableTypes: JSON.parse(workflow.applicableTypes),
      stages: workflow.stages.map(stage => ({
        ...stage,
        approvers: JSON.parse(stage.approvers),
        approverRoles: stage.approverRoles ? JSON.parse(stage.approverRoles) : [],
        skipConditions: stage.skipConditions ? JSON.parse(stage.skipConditions) : [],
      })),
    }

    return NextResponse.json({
      success: true,
      data: transformedWorkflow,
    })
  } catch (error) {
    console.error('Error fetching workflow:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to fetch workflow' },
      { status: 500 }
    )
  }
}

// PATCH /api/workflows/[id] - Update workflow
export async function PATCH(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const body = await request.json()
    const validatedData = updateWorkflowSchema.parse(body)

    // TODO: Get actual user ID from authentication and check permissions
    const currentUserId = 'temp-user-id'

    // Check if workflow exists and user has permission to edit
    const existingWorkflow = await prisma.approvalWorkflow.findUnique({
      where: { id: params.id },
      select: { 
        id: true, 
        teamId: true,
        createdBy: true,
        stages: { select: { id: true } }
      },
    })

    if (!existingWorkflow) {
      return NextResponse.json(
        { success: false, error: 'Workflow not found' },
        { status: 404 }
      )
    }

    // TODO: Add permission check - user must be workflow creator or have team admin rights

    // Prepare update data
    const updateData: any = {}
    
    if (validatedData.name !== undefined) updateData.name = validatedData.name
    if (validatedData.description !== undefined) updateData.description = validatedData.description
    if (validatedData.applicableTypes !== undefined) {
      updateData.applicableTypes = JSON.stringify(validatedData.applicableTypes)
    }
    if (validatedData.autoStart !== undefined) updateData.autoStart = validatedData.autoStart
    if (validatedData.allowParallelStages !== undefined) {
      updateData.allowParallelStages = validatedData.allowParallelStages
    }
    if (validatedData.requireAllApprovers !== undefined) {
      updateData.requireAllApprovers = validatedData.requireAllApprovers
    }
    if (validatedData.defaultTimeoutHours !== undefined) {
      updateData.defaultTimeoutHours = validatedData.defaultTimeoutHours
    }
    if (validatedData.isActive !== undefined) updateData.isActive = validatedData.isActive

    // Handle stages update if provided
    if (validatedData.stages) {
      // Get existing stage IDs
      const existingStageIds = existingWorkflow.stages.map(s => s.id)
      const newStageIds = validatedData.stages
        .filter(s => s.id)
        .map(s => s.id!)

      // Delete stages that are no longer in the update
      const stagesToDelete = existingStageIds.filter(id => !newStageIds.includes(id))
      
      if (stagesToDelete.length > 0) {
        await prisma.approvalStage.deleteMany({
          where: {
            id: { in: stagesToDelete },
            workflowId: params.id,
          },
        })
      }

      // Update or create stages
      for (const [index, stageData] of validatedData.stages.entries()) {
        const stageUpdateData = {
          name: stageData.name,
          description: stageData.description,
          order: index,
          approversRequired: stageData.approversRequired,
          approvers: JSON.stringify(stageData.approvers),
          approverRoles: stageData.approverRoles ? JSON.stringify(stageData.approverRoles) : null,
          autoApprove: stageData.autoApprove,
          timeoutHours: stageData.timeoutHours,
          skipConditions: stageData.skipConditions ? JSON.stringify(stageData.skipConditions) : null,
        }

        if (stageData.id) {
          // Update existing stage
          await prisma.approvalStage.update({
            where: { id: stageData.id },
            data: stageUpdateData,
          })
        } else {
          // Create new stage
          await prisma.approvalStage.create({
            data: {
              ...stageUpdateData,
              workflowId: params.id,
            },
          })
        }
      }
    }

    // Update workflow
    const workflow = await prisma.approvalWorkflow.update({
      where: { id: params.id },
      data: updateData,
      include: {
        stages: {
          orderBy: { order: 'asc' },
        },
      },
    })

    // Transform response
    const transformedWorkflow = {
      ...workflow,
      applicableTypes: JSON.parse(workflow.applicableTypes),
      stages: workflow.stages.map(stage => ({
        ...stage,
        approvers: JSON.parse(stage.approvers),
        approverRoles: stage.approverRoles ? JSON.parse(stage.approverRoles) : [],
        skipConditions: stage.skipConditions ? JSON.parse(stage.skipConditions) : [],
      })),
    }

    return NextResponse.json({
      success: true,
      data: transformedWorkflow,
    })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid request data', details: error.errors },
        { status: 400 }
      )
    }

    console.error('Error updating workflow:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to update workflow' },
      { status: 500 }
    )
  }
}

// DELETE /api/workflows/[id] - Delete workflow
export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    // TODO: Get actual user ID from authentication and check permissions
    const currentUserId = 'temp-user-id'

    // Check if workflow exists and user has permission to delete
    const existingWorkflow = await prisma.approvalWorkflow.findUnique({
      where: { id: params.id },
      select: { 
        id: true, 
        teamId: true,
        createdBy: true,
        _count: {
          select: {
            requests: {
              where: {
                status: { in: ['PENDING', 'IN_PROGRESS'] }
              }
            }
          }
        }
      },
    })

    if (!existingWorkflow) {
      return NextResponse.json(
        { success: false, error: 'Workflow not found' },
        { status: 404 }
      )
    }

    // TODO: Add permission check - user must be workflow creator or have team admin rights

    // Check if workflow has active requests
    if (existingWorkflow._count.requests > 0) {
      return NextResponse.json(
        { 
          success: false, 
          error: 'Cannot delete workflow with active approval requests. Complete or cancel pending requests first.' 
        },
        { status: 400 }
      )
    }

    // Delete workflow (stages will be deleted due to cascade)
    await prisma.approvalWorkflow.delete({
      where: { id: params.id },
    })

    return NextResponse.json({
      success: true,
      message: 'Workflow deleted successfully',
    })
  } catch (error) {
    console.error('Error deleting workflow:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to delete workflow' },
      { status: 500 }
    )
  }
}