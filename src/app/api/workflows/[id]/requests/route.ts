import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { z } from 'zod'
import { workflowEngine } from '@/lib/workflow-engine'
import { approvalRoutingEngine } from '@/lib/approval-routing'

const prisma = new PrismaClient()

// Validation schemas
const createRequestSchema = z.object({
  targetType: z.enum(['CAMPAIGN', 'JOURNEY', 'CONTENT', 'BRAND']),
  targetId: z.string(),
  notes: z.string().optional(),
  dueDate: z.string().transform(val => new Date(val)).optional(),
  priority: z.enum(['LOW', 'MEDIUM', 'HIGH', 'URGENT']).default('MEDIUM'),
})

const requestQuerySchema = z.object({
  status: z.enum(['PENDING', 'IN_PROGRESS', 'APPROVED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'ESCALATED']).optional(),
  targetType: z.enum(['CAMPAIGN', 'JOURNEY', 'CONTENT', 'BRAND']).optional(),
  requesterId: z.string().optional(),
  approverId: z.string().optional(),
  limit: z.string().transform(val => parseInt(val, 10)).optional(),
  offset: z.string().transform(val => parseInt(val, 10)).optional(),
})

// GET /api/workflows/[id]/requests - Get approval requests for workflow
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { searchParams } = new URL(request.url)
    const query = requestQuerySchema.parse(Object.fromEntries(searchParams))

    const {
      status,
      targetType,
      requesterId,
      approverId,
      limit = 50,
      offset = 0
    } = query

    // Check if workflow exists
    const workflow = await prisma.approvalWorkflow.findUnique({
      where: { id: params.id },
      select: { id: true },
    })

    if (!workflow) {
      return NextResponse.json(
        { success: false, error: 'Workflow not found' },
        { status: 404 }
      )
    }

    const where: any = {
      workflowId: params.id,
    }

    if (status) where.status = status
    if (targetType) where.targetType = targetType
    if (requesterId) where.requesterId = requesterId

    // If filtering by approver, need to join with actions
    let approverFilter = {}
    if (approverId) {
      approverFilter = {
        actions: {
          some: {
            approverId: approverId,
          },
        },
      }
    }

    const requests = await prisma.approvalRequest.findMany({
      where: { ...where, ...approverFilter },
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
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
    })

    const total = await prisma.approvalRequest.count({ 
      where: { ...where, ...approverFilter } 
    })

    // Transform response to parse JSON fields
    const transformedRequests = requests.map(request => ({
      ...request,
      currentStage: request.currentStage ? {
        ...request.currentStage,
        approvers: JSON.parse(request.currentStage.approvers),
      } : null,
    }))

    return NextResponse.json({
      success: true,
      data: transformedRequests,
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + requests.length < total,
      },
    })
  } catch (error) {
    console.error('Error fetching approval requests:', error)
    
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid query parameters', details: error.errors },
        { status: 400 }
      )
    }

    return NextResponse.json(
      { success: false, error: 'Failed to fetch approval requests' },
      { status: 500 }
    )
  }
}

// POST /api/workflows/[id]/requests - Create new approval request
export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const body = await request.json()
    const validatedData = createRequestSchema.parse(body)

    // TODO: Get actual user ID from authentication
    const currentUserId = 'temp-user-id'

    // Check if workflow exists and is active
    const workflow = await prisma.approvalWorkflow.findUnique({
      where: { id: params.id },
      include: {
        stages: {
          orderBy: { order: 'asc' },
        },
      },
    })

    if (!workflow) {
      return NextResponse.json(
        { success: false, error: 'Workflow not found' },
        { status: 404 }
      )
    }

    if (!workflow.isActive) {
      return NextResponse.json(
        { success: false, error: 'Workflow is not active' },
        { status: 400 }
      )
    }

    // Check if workflow applies to this content type
    const applicableTypes = JSON.parse(workflow.applicableTypes)
    if (!applicableTypes.includes(validatedData.targetType)) {
      return NextResponse.json(
        { 
          success: false, 
          error: `Workflow does not apply to ${validatedData.targetType} content` 
        },
        { status: 400 }
      )
    }

    // Check if there's already an active request for this content
    const existingRequest = await prisma.approvalRequest.findFirst({
      where: {
        targetType: validatedData.targetType,
        targetId: validatedData.targetId,
        status: { in: ['PENDING', 'IN_PROGRESS'] },
      },
    })

    if (existingRequest) {
      return NextResponse.json(
        { 
          success: false, 
          error: 'An approval request for this content is already in progress',
          existingRequestId: existingRequest.id
        },
        { status: 409 }
      )
    }

    // Transform workflow stages for engine
    const transformedStages = workflow.stages.map(stage => ({
      ...stage,
      approvers: JSON.parse(stage.approvers),
      approverRoles: stage.approverRoles ? JSON.parse(stage.approverRoles) : [],
      skipConditions: stage.skipConditions ? JSON.parse(stage.skipConditions) : [],
    }))

    const transformedWorkflow = {
      ...workflow,
      applicableTypes: applicableTypes,
      stages: transformedStages,
    }

    // Use enhanced workflow engine to start the approval process
    try {
      const approvalRequest = await workflowEngine.startWorkflow(
        params.id,
        validatedData.targetType,
        validatedData.targetId,
        currentUserId,
        validatedData.notes,
        validatedData.dueDate,
        validatedData.priority
      )

      // Get team members for intelligent routing (mock for now)
      const mockTeamMembers = [
        { id: 'user1', name: 'John Doe', email: 'john@example.com', role: 'reviewer' as const },
        { id: 'user2', name: 'Jane Smith', email: 'jane@example.com', role: 'approver' as const },
        { id: 'user3', name: 'Bob Wilson', email: 'bob@example.com', role: 'admin' as const },
      ]

      // Apply intelligent routing for the first stage
      if (approvalRequest.currentStage) {
        const routingContext = {
          request: approvalRequest,
          stage: approvalRequest.currentStage,
          targetContent: {}, // Would fetch actual content in real implementation
          requester: { id: currentUserId } as any,
          teamMembers: mockTeamMembers,
          urgencyLevel: validatedData.priority
        }

        const routingDecision = await approvalRoutingEngine.routeApproval(routingContext)
        
        // TODO: Update stage approvers based on routing decision
        // TODO: Send targeted notifications based on routing
        console.log('Routing Decision:', {
          targetApprovers: routingDecision.targetApprovers,
          estimatedTime: routingDecision.estimatedTime,
          confidence: routingDecision.confidence,
          reasoning: routingDecision.reasoning
        })
      }

      // TODO: Send notifications to approvers
      // This would integrate with the notification system

      // Get routing decision for response
      let routingInfo = null
      if (approvalRequest.currentStage) {
        const routingContext = {
          request: approvalRequest,
          stage: approvalRequest.currentStage,
          targetContent: {},
          requester: { id: currentUserId } as any,
          teamMembers: mockTeamMembers,
          urgencyLevel: validatedData.priority
        }
        const routingDecision = await approvalRoutingEngine.routeApproval(routingContext)
        routingInfo = {
          targetApprovers: routingDecision.targetApprovers,
          estimatedTime: routingDecision.estimatedTime,
          confidence: routingDecision.confidence,
          reasoning: routingDecision.reasoning
        }
      }

      return NextResponse.json({
        success: true,
        data: {
          request: approvalRequest,
          routing: routingInfo
        },
        message: 'Approval request created successfully',
      }, { status: 201 })
    } catch (engineError) {
      console.error('Workflow engine error:', engineError)
      return NextResponse.json(
        { 
          success: false, 
          error: 'Failed to start approval workflow',
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

    console.error('Error creating approval request:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to create approval request' },
      { status: 500 }
    )
  }
}