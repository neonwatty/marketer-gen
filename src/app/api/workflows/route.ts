import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { z } from 'zod'

const prisma = new PrismaClient()

// Validation schemas
const createWorkflowSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().optional(),
  teamId: z.string(),
  applicableTypes: z.array(z.enum(['CAMPAIGN', 'JOURNEY', 'CONTENT', 'BRAND'])),
  autoStart: z.boolean().default(false),
  allowParallelStages: z.boolean().default(false),
  requireAllApprovers: z.boolean().default(true),
  defaultTimeoutHours: z.number().min(1).max(720).default(72),
  isActive: z.boolean().default(true),
  stages: z.array(z.object({
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
  }))
})

const workflowQuerySchema = z.object({
  teamId: z.string().optional(),
  isActive: z.string().transform(val => val === 'true').optional(),
  applicableType: z.enum(['CAMPAIGN', 'JOURNEY', 'CONTENT', 'BRAND']).optional(),
  limit: z.string().transform(val => parseInt(val, 10)).optional(),
  offset: z.string().transform(val => parseInt(val, 10)).optional(),
})

// GET /api/workflows - Fetch workflows
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const query = workflowQuerySchema.parse(Object.fromEntries(searchParams))

    const {
      teamId,
      isActive,
      applicableType,
      limit = 50,
      offset = 0
    } = query

    const where: any = {}

    if (teamId) where.teamId = teamId
    if (isActive !== undefined) where.isActive = isActive
    if (applicableType) {
      where.applicableTypes = {
        contains: applicableType
      }
    }

    const workflows = await prisma.approvalWorkflow.findMany({
      where,
      include: {
        stages: {
          orderBy: { order: 'asc' },
        },
        requests: {
          select: {
            id: true,
            status: true,
            createdAt: true,
          },
          orderBy: { createdAt: 'desc' },
          take: 5, // Latest 5 requests per workflow
        },
        _count: {
          select: {
            requests: true,
            stages: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
    })

    const total = await prisma.approvalWorkflow.count({ where })

    // Transform applicableTypes from JSON string to array
    const transformedWorkflows = workflows.map(workflow => ({
      ...workflow,
      applicableTypes: JSON.parse(workflow.applicableTypes),
      stages: workflow.stages.map(stage => ({
        ...stage,
        approvers: JSON.parse(stage.approvers),
        approverRoles: stage.approverRoles ? JSON.parse(stage.approverRoles) : [],
        skipConditions: stage.skipConditions ? JSON.parse(stage.skipConditions) : [],
      })),
    }))

    return NextResponse.json({
      success: true,
      data: transformedWorkflows,
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + workflows.length < total,
      },
    })
  } catch (error) {
    console.error('Error fetching workflows:', error)
    
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid query parameters', details: error.errors },
        { status: 400 }
      )
    }

    return NextResponse.json(
      { success: false, error: 'Failed to fetch workflows' },
      { status: 500 }
    )
  }
}

// POST /api/workflows - Create new workflow
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const validatedData = createWorkflowSchema.parse(body)

    // TODO: Get actual user ID from authentication
    const currentUserId = 'temp-user-id'

    // TODO: Validate user has permission to create workflows for this team
    // TODO: Validate team exists

    // Create workflow with stages
    const workflow = await prisma.approvalWorkflow.create({
      data: {
        name: validatedData.name,
        description: validatedData.description,
        teamId: validatedData.teamId,
        createdBy: currentUserId,
        applicableTypes: JSON.stringify(validatedData.applicableTypes),
        autoStart: validatedData.autoStart,
        allowParallelStages: validatedData.allowParallelStages,
        requireAllApprovers: validatedData.requireAllApprovers,
        defaultTimeoutHours: validatedData.defaultTimeoutHours,
        isActive: validatedData.isActive,
        stages: {
          create: validatedData.stages.map((stage, index) => ({
            name: stage.name,
            description: stage.description,
            order: index,
            approversRequired: stage.approversRequired,
            approvers: JSON.stringify(stage.approvers),
            approverRoles: stage.approverRoles ? JSON.stringify(stage.approverRoles) : null,
            autoApprove: stage.autoApprove,
            timeoutHours: stage.timeoutHours,
            skipConditions: stage.skipConditions ? JSON.stringify(stage.skipConditions) : null,
          })),
        },
      },
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
    }, { status: 201 })
  } catch (error) {
    console.error('Error creating workflow:', error)
    
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid request data', details: error.errors },
        { status: 400 }
      )
    }

    return NextResponse.json(
      { success: false, error: 'Failed to create workflow' },
      { status: 500 }
    )
  }
}