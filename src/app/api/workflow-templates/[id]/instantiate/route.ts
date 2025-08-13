import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { z } from 'zod'

const prisma = new PrismaClient()

// Validation schema for instantiating template
const instantiateTemplateSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().optional(),
  teamId: z.string(),
  customizations: z.object({
    applicableTypes: z.array(z.enum(['CAMPAIGN', 'JOURNEY', 'CONTENT', 'BRAND'])).optional(),
    autoStart: z.boolean().optional(),
    allowParallelStages: z.boolean().optional(),
    requireAllApprovers: z.boolean().optional(),
    defaultTimeoutHours: z.number().min(1).max(720).optional(),
    isActive: z.boolean().optional(),
    stageCustomizations: z.array(z.object({
      order: z.number(),
      name: z.string().optional(),
      description: z.string().optional(),
      approversRequired: z.number().min(1).optional(),
      approvers: z.array(z.string()).optional(),
      approverRoles: z.array(z.string()).optional(),
      autoApprove: z.boolean().optional(),
      timeoutHours: z.number().min(1).max(720).optional(),
      skipConditions: z.array(z.object({
        type: z.enum(['user_role', 'content_type', 'budget_threshold', 'custom']),
        operator: z.enum(['equals', 'not_equals', 'greater_than', 'less_than', 'contains']),
        value: z.union([z.string(), z.number()])
      })).optional()
    })).optional()
  }).optional()
})

// POST /api/workflow-templates/[id]/instantiate - Create workflow from template
export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const body = await request.json()
    const validatedData = instantiateTemplateSchema.parse(body)

    // TODO: Get actual user ID from authentication
    const currentUserId = 'temp-user-id'

    // TODO: Validate user has permission to create workflows for the specified team

    // Fetch the template with its stages
    const template = await prisma.workflowTemplate.findUnique({
      where: { id: params.id },
      include: {
        stages: {
          orderBy: { order: 'asc' },
        },
      },
    })

    if (!template) {
      return NextResponse.json(
        { success: false, error: 'Workflow template not found' },
        { status: 404 }
      )
    }

    // Parse template data
    const templateApplicableTypes = JSON.parse(template.applicableTypes)

    // Build workflow configuration from template with customizations
    const customizations = validatedData.customizations || {}
    
    const workflowData = {
      name: validatedData.name,
      description: validatedData.description || template.description,
      teamId: validatedData.teamId,
      createdBy: currentUserId,
      applicableTypes: JSON.stringify(
        customizations.applicableTypes || templateApplicableTypes
      ),
      autoStart: customizations.autoStart || false,
      allowParallelStages: customizations.allowParallelStages || false,
      requireAllApprovers: customizations.requireAllApprovers !== false,
      defaultTimeoutHours: customizations.defaultTimeoutHours || 72,
      isActive: customizations.isActive !== false,
    }

    // Build stages with customizations
    const stages = template.stages.map((templateStage, index) => {
      // Find stage customization if provided
      const stageCustomization = customizations.stageCustomizations?.find(
        c => c.order === templateStage.order
      )

      return {
        name: stageCustomization?.name || templateStage.name,
        description: stageCustomization?.description || templateStage.description,
        order: index,
        approversRequired: stageCustomization?.approversRequired || templateStage.approversRequired,
        approvers: stageCustomization?.approvers ? JSON.stringify(stageCustomization.approvers) : '[]',
        approverRoles: (() => {
          if (stageCustomization?.approverRoles) {
            return JSON.stringify(stageCustomization.approverRoles)
          }
          return templateStage.approverRoles
        })(),
        autoApprove: stageCustomization?.autoApprove ?? templateStage.autoApprove,
        timeoutHours: stageCustomization?.timeoutHours || templateStage.timeoutHours,
        skipConditions: (() => {
          if (stageCustomization?.skipConditions) {
            return JSON.stringify(stageCustomization.skipConditions)
          }
          return templateStage.skipConditions
        })(),
      }
    })

    // Create the workflow
    const workflow = await prisma.approvalWorkflow.create({
      data: {
        ...workflowData,
        stages: {
          create: stages,
        },
      },
      include: {
        stages: {
          orderBy: { order: 'asc' },
        },
      },
    })

    // Update template usage count
    await prisma.workflowTemplate.update({
      where: { id: params.id },
      data: {
        usageCount: {
          increment: 1,
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
      message: `Workflow created successfully from template "${template.name}"`,
      templateUsed: {
        id: template.id,
        name: template.name,
        category: template.category,
      },
    }, { status: 201 })

  } catch (error) {
    console.error('Error instantiating workflow from template:', error)
    
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid request data', details: error.errors },
        { status: 400 }
      )
    }

    return NextResponse.json(
      { success: false, error: 'Failed to create workflow from template' },
      { status: 500 }
    )
  }
}

// GET /api/workflow-templates/[id]/instantiate - Get template with instantiation preview
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    // Fetch the template with its stages
    const template = await prisma.workflowTemplate.findUnique({
      where: { id: params.id },
      include: {
        stages: {
          orderBy: { order: 'asc' },
        },
      },
    })

    if (!template) {
      return NextResponse.json(
        { success: false, error: 'Workflow template not found' },
        { status: 404 }
      )
    }

    // Transform template data for preview
    const transformedTemplate = {
      ...template,
      applicableTypes: JSON.parse(template.applicableTypes),
      stages: template.stages.map(stage => ({
        ...stage,
        approverRoles: stage.approverRoles ? JSON.parse(stage.approverRoles) : [],
        skipConditions: stage.skipConditions ? JSON.parse(stage.skipConditions) : [],
      })),
    }

    // Generate default workflow structure
    const defaultWorkflow = {
      name: `${template.name} Workflow`,
      description: template.description,
      applicableTypes: transformedTemplate.applicableTypes,
      autoStart: false,
      allowParallelStages: false,
      requireAllApprovers: true,
      defaultTimeoutHours: 72,
      isActive: true,
      stages: transformedTemplate.stages.map((stage, index) => ({
        name: stage.name,
        description: stage.description,
        order: index,
        approversRequired: stage.approversRequired,
        approvers: [], // Will be customized by user
        approverRoles: stage.approverRoles,
        autoApprove: stage.autoApprove,
        timeoutHours: stage.timeoutHours,
        skipConditions: stage.skipConditions,
      })),
    }

    return NextResponse.json({
      success: true,
      data: {
        template: transformedTemplate,
        preview: defaultWorkflow,
        customizableFields: {
          workflow: [
            'name',
            'description',
            'applicableTypes',
            'autoStart',
            'allowParallelStages',
            'requireAllApprovers',
            'defaultTimeoutHours',
            'isActive'
          ],
          stages: [
            'name',
            'description',
            'approversRequired',
            'approvers',
            'approverRoles',
            'autoApprove',
            'timeoutHours',
            'skipConditions'
          ]
        }
      },
    })

  } catch (error) {
    console.error('Error fetching template for instantiation:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to fetch template' },
      { status: 500 }
    )
  }
}