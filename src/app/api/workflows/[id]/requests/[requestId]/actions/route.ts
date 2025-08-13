import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { z } from 'zod'
import { workflowEngine } from '@/lib/workflow-engine'

const prisma = new PrismaClient()

// Validation schemas
const createActionSchema = z.object({
  action: z.enum(['approve', 'reject', 'request_changes', 'delegate', 'escalate']),
  comment: z.string().optional(),
  delegateToId: z.string().optional(),
  escalationReason: z.string().optional(),
  attachments: z.array(z.object({
    name: z.string(),
    url: z.string(),
    size: z.number(),
    type: z.string()
  })).optional()
})

const actionQuerySchema = z.object({
  action: z.enum(['approve', 'reject', 'request_changes', 'delegate', 'escalate']).optional(),
  approverId: z.string().optional(),
  stageId: z.string().optional(),
  limit: z.string().transform(val => parseInt(val, 10)).optional(),
  offset: z.string().transform(val => parseInt(val, 10)).optional(),
})

// GET /api/workflows/[id]/requests/[requestId]/actions - Get actions for approval request
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string; requestId: string } }
) {
  try {
    const { searchParams } = new URL(request.url)
    const query = actionQuerySchema.parse(Object.fromEntries(searchParams))

    const {
      action,
      approverId,
      stageId,
      limit = 50,
      offset = 0
    } = query

    // Check if workflow and request exist
    const approvalRequest = await prisma.approvalRequest.findUnique({
      where: { 
        id: params.requestId,
        workflowId: params.id
      },
      select: { id: true },
    })

    if (!approvalRequest) {
      return NextResponse.json(
        { success: false, error: 'Approval request not found' },
        { status: 404 }
      )
    }

    const where: any = {
      requestId: params.requestId,
    }

    if (action) where.action = action
    if (approverId) where.approverId = approverId
    if (stageId) where.stageId = stageId

    const actions = await prisma.approvalAction.findMany({
      where,
      include: {
        stage: {
          select: {
            id: true,
            name: true,
            order: true,
          },
        },
        request: {
          select: {
            id: true,
            targetType: true,
            targetId: true,
            status: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
    })

    const total = await prisma.approvalAction.count({ where })

    // Transform response to parse JSON fields
    const transformedActions = actions.map(action => ({
      ...action,
      attachments: action.attachments ? JSON.parse(action.attachments) : [],
    }))

    return NextResponse.json({
      success: true,
      data: transformedActions,
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + actions.length < total,
      },
    })
  } catch (error) {
    console.error('Error fetching approval actions:', error)
    
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid query parameters', details: error.errors },
        { status: 400 }
      )
    }

    return NextResponse.json(
      { success: false, error: 'Failed to fetch approval actions' },
      { status: 500 }
    )
  }
}

// POST /api/workflows/[id]/requests/[requestId]/actions - Create approval action
export async function POST(
  request: NextRequest,
  { params }: { params: { id: string; requestId: string } }
) {
  try {
    const body = await request.json()
    const validatedData = createActionSchema.parse(body)

    // TODO: Get actual user ID from authentication
    const currentUserId = 'temp-user-id'

    // Fetch the approval request with workflow and current stage
    const approvalRequest = await prisma.approvalRequest.findUnique({
      where: { 
        id: params.requestId,
        workflowId: params.id
      },
      include: {
        workflow: {
          include: {
            stages: {
              orderBy: { order: 'asc' },
            },
          },
        },
        currentStage: true,
        actions: {
          include: {
            stage: {
              select: {
                id: true,
                name: true,
                order: true,
              },
            },
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    })

    if (!approvalRequest) {
      return NextResponse.json(
        { success: false, error: 'Approval request not found' },
        { status: 404 }
      )
    }

    // Check if request is in a state that allows actions
    if (!['pending', 'in_progress'].includes(approvalRequest.status)) {
      return NextResponse.json(
        { 
          success: false, 
          error: `Cannot take action on request with status: ${approvalRequest.status}` 
        },
        { status: 400 }
      )
    }

    // Validate delegation if action is delegate
    if (validatedData.action === 'delegate') {
      if (!validatedData.delegateToId) {
        return NextResponse.json(
          { success: false, error: 'delegateToId is required for delegation action' },
          { status: 400 }
        )
      }

      // Check if delegate user exists (in real implementation)
      // const delegateUser = await prisma.user.findUnique({ where: { id: validatedData.delegateToId } })
      // if (!delegateUser) {
      //   return NextResponse.json(
      //     { success: false, error: 'Delegate user not found' },
      //     { status: 400 }
      //   )
      // }
    }

    // Validate escalation if action is escalate
    if (validatedData.action === 'escalate') {
      if (!validatedData.escalationReason) {
        return NextResponse.json(
          { success: false, error: 'escalationReason is required for escalation action' },
          { status: 400 }
        )
      }
    }

    // Transform workflow data for engine
    const transformedStages = approvalRequest.workflow.stages.map(stage => ({
      ...stage,
      approvers: JSON.parse(stage.approvers),
      approverRoles: stage.approverRoles ? JSON.parse(stage.approverRoles) : [],
      skipConditions: stage.skipConditions ? JSON.parse(stage.skipConditions) : [],
    }))

    const transformedWorkflow = {
      ...approvalRequest.workflow,
      applicableTypes: JSON.parse(approvalRequest.workflow.applicableTypes),
      stages: transformedStages,
    }

    // Transform current stage
    const transformedCurrentStage = approvalRequest.currentStage ? {
      ...approvalRequest.currentStage,
      approvers: JSON.parse(approvalRequest.currentStage.approvers),
      approverRoles: approvalRequest.currentStage.approverRoles ? JSON.parse(approvalRequest.currentStage.approverRoles) : [],
      skipConditions: approvalRequest.currentStage.skipConditions ? JSON.parse(approvalRequest.currentStage.skipConditions) : [],
    } : null

    // Transform existing actions for engine
    const transformedActions = approvalRequest.actions.map(action => ({
      ...action,
      attachments: action.attachments ? JSON.parse(action.attachments) : [],
      approver: { id: action.approverId }, // Would be populated from DB
    }))

    // Create transformed request for engine
    const transformedRequest = {
      ...approvalRequest,
      workflow: transformedWorkflow,
      currentStage: transformedCurrentStage,
      approvals: transformedActions, // Engine expects 'approvals' property
    }

    // Prepare metadata for delegation
    const actionMetadata = validatedData.action === 'delegate' 
      ? { delegateToId: validatedData.delegateToId }
      : validatedData.action === 'escalate'
      ? { escalationReason: validatedData.escalationReason }
      : {}

    // Use workflow engine to process the action
    try {
      const engineResult = await workflowEngine.processApprovalAction(
        transformedRequest,
        approvalRequest.currentStageId!,
        currentUserId,
        validatedData.action,
        validatedData.comment,
        actionMetadata
      )

      // Create the action in database
      const approvalAction = await prisma.approvalAction.create({
        data: {
          requestId: params.requestId,
          stageId: approvalRequest.currentStageId!,
          approverId: currentUserId,
          action: validatedData.action,
          comment: validatedData.comment,
          attachments: validatedData.attachments ? JSON.stringify(validatedData.attachments) : null,
        },
        include: {
          stage: {
            select: {
              id: true,
              name: true,
              order: true,
            },
          },
          request: {
            select: {
              id: true,
              targetType: true,
              targetId: true,
              status: true,
            },
          },
        },
      })

      // Update the approval request with new status and stage
      const updatedRequest = await prisma.approvalRequest.update({
        where: { id: params.requestId },
        data: {
          status: engineResult.request.status,
          currentStageId: engineResult.request.currentStageId,
          completedAt: engineResult.request.completedAt,
          escalatedAt: engineResult.request.escalatedAt,
          escalationLevel: engineResult.request.escalationLevel,
          updatedAt: new Date(),
        },
        include: {
          workflow: {
            select: {
              name: true,
              stages: {
                select: {
                  id: true,
                  name: true,
                  order: true,
                },
                orderBy: { order: 'asc' },
              },
            },
          },
          currentStage: {
            select: {
              id: true,
              name: true,
              order: true,
              approversRequired: true,
              approvers: true,
            },
          },
          actions: {
            include: {
              stage: {
                select: {
                  id: true,
                  name: true,
                  order: true,
                },
              },
            },
            orderBy: { createdAt: 'desc' },
          },
        },
      })

      // TODO: Send notifications from engineResult.notifications
      // This would integrate with the notification system
      console.log('Notifications to send:', engineResult.notifications)

      // Transform response
      const transformedAction = {
        ...approvalAction,
        attachments: approvalAction.attachments ? JSON.parse(approvalAction.attachments) : [],
      }

      const transformedUpdatedRequest = {
        ...updatedRequest,
        currentStage: updatedRequest.currentStage ? {
          ...updatedRequest.currentStage,
          approvers: JSON.parse(updatedRequest.currentStage.approvers),
        } : null,
        actions: updatedRequest.actions.map(action => ({
          ...action,
          attachments: action.attachments ? JSON.parse(action.attachments) : [],
        })),
      }

      return NextResponse.json({
        success: true,
        data: {
          action: transformedAction,
          request: transformedUpdatedRequest,
          notifications: engineResult.notifications.length,
        },
        message: `Action ${validatedData.action} processed successfully`,
      }, { status: 201 })

    } catch (engineError) {
      console.error('Workflow engine error:', engineError)
      return NextResponse.json(
        { 
          success: false, 
          error: 'Failed to process approval action',
          details: (engineError as Error).message
        },
        { status: 500 }
      )
    }
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid request data', details: error.errors },
        { status: 400 }
      )
    }

    console.error('Error processing approval action:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to process approval action' },
      { status: 500 }
    )
  }
}