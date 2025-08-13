import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { z } from 'zod'

const prisma = new PrismaClient()

// Validation schemas
const createTemplateSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().optional(),
  category: z.enum(['MARKETING', 'CONTENT', 'BRAND', 'COMPLIANCE', 'GENERAL']),
  applicableTypes: z.array(z.enum(['CAMPAIGN', 'JOURNEY', 'CONTENT', 'BRAND'])),
  isPublic: z.boolean().default(true),
  stages: z.array(z.object({
    name: z.string().min(1),
    description: z.string().optional(),
    order: z.number().min(0),
    approversRequired: z.number().min(1).default(1),
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

const templateQuerySchema = z.object({
  category: z.enum(['MARKETING', 'CONTENT', 'BRAND', 'COMPLIANCE', 'GENERAL']).optional(),
  applicableType: z.enum(['CAMPAIGN', 'JOURNEY', 'CONTENT', 'BRAND']).optional(),
  isPublic: z.string().transform(val => val === 'true').optional(),
  search: z.string().optional(),
  limit: z.string().transform(val => parseInt(val, 10)).optional(),
  offset: z.string().transform(val => parseInt(val, 10)).optional(),
})

// Pre-defined workflow templates
const DEFAULT_TEMPLATES = [
  {
    name: 'Simple Content Review',
    description: 'Basic approval workflow for content creation with single reviewer',
    category: 'CONTENT',
    applicableTypes: ['CONTENT'],
    isPublic: true,
    stages: [
      {
        name: 'Content Review',
        description: 'Review content for quality and compliance',
        order: 0,
        approversRequired: 1,
        approverRoles: ['reviewer', 'approver'],
        autoApprove: false,
        timeoutHours: 48
      }
    ]
  },
  {
    name: 'Marketing Campaign Approval',
    description: 'Multi-stage approval for marketing campaigns including budget and compliance review',
    category: 'MARKETING',
    applicableTypes: ['CAMPAIGN'],
    isPublic: true,
    stages: [
      {
        name: 'Marketing Review',
        description: 'Review campaign strategy and messaging',
        order: 0,
        approversRequired: 1,
        approverRoles: ['reviewer'],
        autoApprove: false,
        timeoutHours: 24
      },
      {
        name: 'Budget Approval',
        description: 'Approve campaign budget and resource allocation',
        order: 1,
        approversRequired: 1,
        approverRoles: ['approver', 'admin'],
        autoApprove: false,
        timeoutHours: 48,
        skipConditions: [
          {
            type: 'budget_threshold',
            operator: 'less_than',
            value: 1000
          }
        ]
      },
      {
        name: 'Final Approval',
        description: 'Final sign-off for campaign launch',
        order: 2,
        approversRequired: 1,
        approverRoles: ['admin'],
        autoApprove: false,
        timeoutHours: 24
      }
    ]
  },
  {
    name: 'Brand Asset Review',
    description: 'Approval workflow for brand assets ensuring brand compliance',
    category: 'BRAND',
    applicableTypes: ['BRAND'],
    isPublic: true,
    stages: [
      {
        name: 'Brand Compliance',
        description: 'Ensure asset meets brand guidelines',
        order: 0,
        approversRequired: 1,
        approverRoles: ['reviewer', 'approver'],
        autoApprove: false,
        timeoutHours: 48
      },
      {
        name: 'Legal Review',
        description: 'Review for legal and compliance requirements',
        order: 1,
        approversRequired: 1,
        approverRoles: ['admin'],
        autoApprove: false,
        timeoutHours: 72
      }
    ]
  },
  {
    name: 'Customer Journey Approval',
    description: 'Comprehensive review process for customer journey workflows',
    category: 'MARKETING',
    applicableTypes: ['JOURNEY'],
    isPublic: true,
    stages: [
      {
        name: 'Strategy Review',
        description: 'Review journey strategy and flow logic',
        order: 0,
        approversRequired: 1,
        approverRoles: ['reviewer'],
        autoApprove: false,
        timeoutHours: 48
      },
      {
        name: 'Technical Review',
        description: 'Review technical implementation and integrations',
        order: 1,
        approversRequired: 1,
        approverRoles: ['approver'],
        autoApprove: false,
        timeoutHours: 72
      },
      {
        name: 'Stakeholder Approval',
        description: 'Final approval from key stakeholders',
        order: 2,
        approversRequired: 2,
        approverRoles: ['admin'],
        autoApprove: false,
        timeoutHours: 48
      }
    ]
  },
  {
    name: 'Quick Approval',
    description: 'Fast-track approval for minor changes',
    category: 'GENERAL',
    applicableTypes: ['CONTENT', 'CAMPAIGN', 'JOURNEY', 'BRAND'],
    isPublic: true,
    stages: [
      {
        name: 'Quick Review',
        description: 'Rapid review for minor updates',
        order: 0,
        approversRequired: 1,
        approverRoles: ['reviewer', 'approver', 'admin'],
        autoApprove: false,
        timeoutHours: 12,
        skipConditions: [
          {
            type: 'user_role',
            operator: 'equals',
            value: 'admin'
          }
        ]
      }
    ]
  },
  {
    name: 'Compliance Review',
    description: 'Thorough compliance and risk assessment workflow',
    category: 'COMPLIANCE',
    applicableTypes: ['CONTENT', 'CAMPAIGN', 'BRAND'],
    isPublic: true,
    stages: [
      {
        name: 'Content Compliance',
        description: 'Review content for regulatory compliance',
        order: 0,
        approversRequired: 1,
        approverRoles: ['reviewer'],
        autoApprove: false,
        timeoutHours: 48
      },
      {
        name: 'Risk Assessment',
        description: 'Assess potential risks and liabilities',
        order: 1,
        approversRequired: 1,
        approverRoles: ['approver'],
        autoApprove: false,
        timeoutHours: 72
      },
      {
        name: 'Legal Sign-off',
        description: 'Final legal approval',
        order: 2,
        approversRequired: 1,
        approverRoles: ['admin'],
        autoApprove: false,
        timeoutHours: 96
      }
    ]
  }
]

// GET /api/workflow-templates - Fetch workflow templates
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const query = templateQuerySchema.parse(Object.fromEntries(searchParams))

    const {
      category,
      applicableType,
      isPublic,
      search,
      limit = 50,
      offset = 0
    } = query

    const where: any = {}

    if (category) where.category = category
    if (isPublic !== undefined) where.isPublic = isPublic
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } }
      ]
    }
    if (applicableType) {
      where.applicableTypes = {
        contains: applicableType
      }
    }

    const templates = await prisma.workflowTemplate.findMany({
      where,
      include: {
        stages: {
          orderBy: { order: 'asc' },
        },
        _count: {
          select: {
            stages: true,
          },
        },
      },
      orderBy: [
        { isPublic: 'desc' }, // Public templates first
        { createdAt: 'desc' }
      ],
      take: limit,
      skip: offset,
    })

    const total = await prisma.workflowTemplate.count({ where })

    // Transform applicableTypes from JSON string to array
    const transformedTemplates = templates.map(template => ({
      ...template,
      applicableTypes: JSON.parse(template.applicableTypes),
      stages: template.stages.map(stage => ({
        ...stage,
        approverRoles: stage.approverRoles ? JSON.parse(stage.approverRoles) : [],
        skipConditions: stage.skipConditions ? JSON.parse(stage.skipConditions) : [],
      })),
    }))

    return NextResponse.json({
      success: true,
      data: transformedTemplates,
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + templates.length < total,
      },
    })
  } catch (error) {
    console.error('Error fetching workflow templates:', error)
    
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid query parameters', details: error.errors },
        { status: 400 }
      )
    }

    return NextResponse.json(
      { success: false, error: 'Failed to fetch workflow templates' },
      { status: 500 }
    )
  }
}

// POST /api/workflow-templates - Create new workflow template
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const validatedData = createTemplateSchema.parse(body)

    // TODO: Get actual user ID from authentication
    const currentUserId = 'temp-user-id'

    // TODO: Validate user has permission to create templates
    // TODO: Check if template name already exists

    // Create template with stages
    const template = await prisma.workflowTemplate.create({
      data: {
        name: validatedData.name,
        description: validatedData.description,
        category: validatedData.category as any,
        createdBy: currentUserId,
        applicableTypes: JSON.stringify(validatedData.applicableTypes),
        isPublic: validatedData.isPublic,
        stages: {
          create: validatedData.stages.map((stage, index) => ({
            name: stage.name,
            description: stage.description,
            order: index,
            approversRequired: stage.approversRequired,
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
    const transformedTemplate = {
      ...template,
      applicableTypes: JSON.parse(template.applicableTypes),
      stages: template.stages.map(stage => ({
        ...stage,
        approverRoles: stage.approverRoles ? JSON.parse(stage.approverRoles) : [],
        skipConditions: stage.skipConditions ? JSON.parse(stage.skipConditions) : [],
      })),
    }

    return NextResponse.json({
      success: true,
      data: transformedTemplate,
    }, { status: 201 })
  } catch (error) {
    console.error('Error creating workflow template:', error)
    
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Invalid request data', details: error.errors },
        { status: 400 }
      )
    }

    return NextResponse.json(
      { success: false, error: 'Failed to create workflow template' },
      { status: 500 }
    )
  }
}

// POST /api/workflow-templates/seed - Seed default templates (development only)
export async function PUT(request: NextRequest) {
  try {
    // TODO: Add proper authentication and restrict to admin users
    // TODO: Add environment check to only allow in development

    const currentUserId = 'system'
    const createdTemplates = []

    for (const templateData of DEFAULT_TEMPLATES) {
      // Check if template already exists
      const existingTemplate = await prisma.workflowTemplate.findFirst({
        where: { name: templateData.name }
      })

      if (!existingTemplate) {
        const template = await prisma.workflowTemplate.create({
          data: {
            name: templateData.name,
            description: templateData.description,
            category: templateData.category as any,
            createdBy: currentUserId,
            applicableTypes: JSON.stringify(templateData.applicableTypes),
            isPublic: templateData.isPublic,
            stages: {
              create: templateData.stages.map((stage, index) => ({
                name: stage.name,
                description: stage.description,
                order: index,
                approversRequired: stage.approversRequired,
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

        createdTemplates.push(template)
      }
    }

    return NextResponse.json({
      success: true,
      message: `Seeded ${createdTemplates.length} workflow templates`,
      data: createdTemplates.map(template => ({
        ...template,
        applicableTypes: JSON.parse(template.applicableTypes),
      })),
    })
  } catch (error) {
    console.error('Error seeding workflow templates:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to seed workflow templates' },
      { status: 500 }
    )
  }
}