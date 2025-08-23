import { NextRequest, NextResponse } from 'next/server'

import { z } from 'zod'

import { brandComplianceService } from '@/lib/services/brand-compliance'
import { BrandComplianceConfigSchema,BrandContextSchema } from '@/lib/types/content-generation'

// Request validation schema
const ContentComplianceRequestSchema = z.object({
  content: z.string().min(1, 'Content is required').max(10000, 'Content too long'),
  brandContext: BrandContextSchema,
  config: BrandComplianceConfigSchema.optional().default({
    enforceBrandVoice: true,
    checkRestrictedTerms: true,
    validateMessaging: true
  })
})

// Response schema for API documentation (used for type inference only)
const _ContentComplianceResponseSchema = z.object({
  success: z.boolean(),
  compliance: z.object({
    isCompliant: z.boolean(),
    violations: z.array(z.string()),
    suggestions: z.array(z.string()).optional(),
    score: z.number().min(0).max(100).optional(),
    brandAlignmentScore: z.number().min(0).max(100),
    processing: z.object({
      duration: z.number(),
      timestamp: z.string(),
      model: z.string().optional()
    })
  }).optional(),
  error: z.string().optional()
})

type ContentComplianceRequest = z.infer<typeof ContentComplianceRequestSchema>
type ContentComplianceResponse = z.infer<typeof _ContentComplianceResponseSchema>

/**
 * POST /api/ai/content-compliance
 * Validate content against brand compliance rules and OpenAI moderation
 */
export async function POST(request: NextRequest): Promise<NextResponse<ContentComplianceResponse>> {
  try {
    // Parse and validate request body
    const body = await request.json()
    const validatedRequest = ContentComplianceRequestSchema.parse(body)

    // Validate content against brand compliance
    const complianceResult = await brandComplianceService.instance.validateContent(
      validatedRequest.content,
      validatedRequest.brandContext,
      validatedRequest.config
    )

    // Return compliance result
    return NextResponse.json({
      success: true,
      compliance: {
        isCompliant: complianceResult.isCompliant,
        violations: complianceResult.violations.map(v => v.message),
        suggestions: complianceResult.suggestions,
        score: complianceResult.score,
        brandAlignmentScore: complianceResult.brandAlignmentScore,
        processing: complianceResult.processing
      }
    })

  } catch (error) {
    console.error('Content compliance validation error:', error)

    // Handle validation errors
    if (error instanceof z.ZodError) {
      return NextResponse.json({
        success: false,
        error: `Invalid request: ${error.issues.map((e) => e.message).join(', ')}`
      }, { status: 400 })
    }

    // Handle service errors
    if (error instanceof Error) {
      return NextResponse.json({
        success: false,
        error: `Compliance validation failed: ${error.message}`
      }, { status: 500 })
    }

    // Handle unknown errors
    return NextResponse.json({
      success: false,
      error: 'An unexpected error occurred during compliance validation'
    }, { status: 500 })
  }
}

/**
 * GET /api/ai/content-compliance/health
 * Health check endpoint for the compliance service
 */
export async function GET(): Promise<NextResponse> {
  try {
    const isHealthy = await brandComplianceService.instance.testConnection()
    
    if (isHealthy) {
      return NextResponse.json({
        status: 'healthy',
        service: 'content-compliance',
        timestamp: new Date().toISOString()
      })
    } else {
      return NextResponse.json({
        status: 'unhealthy',
        service: 'content-compliance',
        timestamp: new Date().toISOString(),
        error: 'Failed to connect to OpenAI Moderation API'
      }, { status: 503 })
    }

  } catch (error) {
    console.error('Health check failed:', error)
    
    return NextResponse.json({
      status: 'unhealthy',
      service: 'content-compliance',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 503 })
  }
}

