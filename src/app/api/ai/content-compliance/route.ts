import { NextRequest, NextResponse } from 'next/server'

import { z } from 'zod'

import { AdvancedBrandComplianceConfigSchema,brandComplianceService } from '@/lib/services/brand-compliance'
import { BrandComplianceConfigSchema, BrandContextSchema } from '@/lib/types/content-generation'

// Request validation schema (supports both basic and advanced configs)
const ContentComplianceRequestSchema = z.object({
  content: z.string().min(1, 'Content is required').max(10000, 'Content too long'),
  brandContext: BrandContextSchema,
  config: z.union([
    BrandComplianceConfigSchema,
    AdvancedBrandComplianceConfigSchema
  ]).optional().default({
    enforceBrandVoice: true,
    checkRestrictedTerms: true,
    validateMessaging: true
  }),
  options: z.object({
    includePredictions: z.boolean().default(false),
    includePreventiveSuggestions: z.boolean().default(false),
    enableAutoFix: z.boolean().default(false),
    targetAudience: z.string().optional(),
    contentType: z.string().optional()
  }).optional()
})

// Batch request schema
const BatchComplianceRequestSchema = z.object({
  contents: z.array(z.object({
    id: z.string(),
    content: z.string().min(1, 'Content is required').max(10000, 'Content too long')
  })).min(1, 'At least one content item is required').max(10, 'Maximum 10 content items allowed'),
  brandContext: BrandContextSchema,
  config: z.union([
    BrandComplianceConfigSchema,
    AdvancedBrandComplianceConfigSchema
  ]).optional().default({
    enforceBrandVoice: true,
    checkRestrictedTerms: true,
    validateMessaging: true
  }),
  maxConcurrency: z.number().min(1).max(5).default(3)
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
 * Enhanced content validation with advanced features
 */
export async function POST(request: NextRequest): Promise<NextResponse<any>> {
  try {
    const url = new URL(request.url)
    const endpoint = url.pathname

    // Handle batch processing endpoint
    if (endpoint.includes('/batch')) {
      return handleBatchValidation(request)
    }

    // Handle prediction endpoint
    if (endpoint.includes('/predict')) {
      return handlePredictionAnalysis(request)
    }

    // Handle main validation endpoint
    const body = await request.json()
    const validatedRequest = ContentComplianceRequestSchema.parse(body)

    // Enhanced validation with optional features
    const complianceResult = await brandComplianceService.instance.validateContent(
      validatedRequest.content,
      validatedRequest.brandContext,
      validatedRequest.config
    )

    // Build response with optional enhancements
    const response: any = {
      success: true,
      compliance: {
        isCompliant: complianceResult.isCompliant,
        violations: complianceResult.violations.map(v => ({
          type: v.type,
          severity: v.severity,
          message: v.message,
          suggestion: v.suggestion,
          context: v.context,
          confidence: v.confidence
        })),
        suggestions: complianceResult.suggestions,
        score: complianceResult.score,
        brandAlignmentScore: complianceResult.brandAlignmentScore,
        processing: complianceResult.processing
      }
    }

    // Add predictions if requested
    if (validatedRequest.options?.includePredictions) {
      try {
        const predictions = await brandComplianceService.instance.predictViolations(
          validatedRequest.content,
          validatedRequest.brandContext,
          validatedRequest.config
        )
        response.predictions = predictions
      } catch (error) {
        console.warn('Prediction analysis failed:', error)
      }
    }

    // Add preventive suggestions if requested
    if (validatedRequest.options?.includePreventiveSuggestions) {
      try {
        const preventiveSuggestions = await brandComplianceService.instance.generatePreventiveSuggestions(
          validatedRequest.content,
          validatedRequest.brandContext,
          validatedRequest.options?.targetAudience,
          validatedRequest.options?.contentType
        )
        response.preventiveSuggestions = preventiveSuggestions
      } catch (error) {
        console.warn('Preventive suggestions failed:', error)
      }
    }

    // Auto-fix violations if requested and violations exist
    if (validatedRequest.options?.enableAutoFix && complianceResult.violations.length > 0) {
      try {
        const autoFixResult = await brandComplianceService.instance.autoFixViolations(
          validatedRequest.content,
          complianceResult.violations,
          validatedRequest.brandContext
        )
        response.autoFix = autoFixResult
      } catch (error) {
        console.warn('Auto-fix failed:', error)
      }
    }

    return NextResponse.json(response)

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
 * Handle batch validation requests
 */
async function handleBatchValidation(request: NextRequest): Promise<NextResponse> {
  try {
    const body = await request.json()
    const validatedRequest = BatchComplianceRequestSchema.parse(body)

    const results = await brandComplianceService.instance.batchValidateContent(
      validatedRequest.contents,
      validatedRequest.brandContext,
      validatedRequest.config,
      validatedRequest.maxConcurrency
    )

    return NextResponse.json({
      success: true,
      results: results.map(result => ({
        id: result.id,
        compliance: result.result ? {
          isCompliant: result.result.isCompliant,
          violations: result.result.violations.map(v => ({
            type: v.type,
            severity: v.severity,
            message: v.message,
            suggestion: v.suggestion,
            context: v.context,
            confidence: v.confidence
          })),
          suggestions: result.result.suggestions,
          score: result.result.score,
          brandAlignmentScore: result.result.brandAlignmentScore,
          processing: result.result.processing
        } : null,
        error: result.error
      })),
      summary: {
        total: results.length,
        compliant: results.filter(r => r.result?.isCompliant).length,
        nonCompliant: results.filter(r => r.result && !r.result.isCompliant).length,
        errors: results.filter(r => r.error).length
      }
    })
  } catch (error) {
    console.error('Batch validation error:', error)
    
    if (error instanceof z.ZodError) {
      return NextResponse.json({
        success: false,
        error: `Invalid request: ${error.issues.map(e => e.message).join(', ')}`
      }, { status: 400 })
    }

    return NextResponse.json({
      success: false,
      error: 'Batch validation failed'
    }, { status: 500 })
  }
}

/**
 * Handle prediction analysis requests
 */
async function handlePredictionAnalysis(request: NextRequest): Promise<NextResponse> {
  try {
    const body = await request.json()
    const validatedRequest = ContentComplianceRequestSchema.parse(body)

    const predictions = await brandComplianceService.instance.predictViolations(
      validatedRequest.content,
      validatedRequest.brandContext,
      validatedRequest.config
    )

    const preventiveSuggestions = await brandComplianceService.instance.generatePreventiveSuggestions(
      validatedRequest.content,
      validatedRequest.brandContext,
      validatedRequest.options?.targetAudience,
      validatedRequest.options?.contentType
    )

    return NextResponse.json({
      success: true,
      predictions,
      preventiveSuggestions
    })
  } catch (error) {
    console.error('Prediction analysis error:', error)
    
    if (error instanceof z.ZodError) {
      return NextResponse.json({
        success: false,
        error: `Invalid request: ${error.issues.map(e => e.message).join(', ')}`
      }, { status: 400 })
    }

    return NextResponse.json({
      success: false,
      error: 'Prediction analysis failed'
    }, { status: 500 })
  }
}

/**
 * GET /api/ai/content-compliance/health
 * Health check endpoint for the compliance service
 */
export async function GET(request: NextRequest): Promise<NextResponse> {
  try {
    const url = new URL(request.url)
    const includeMetrics = url.searchParams.get('metrics') === 'true'
    
    const isHealthy = await brandComplianceService.instance.testConnection()
    
    const response: any = {
      status: isHealthy ? 'healthy' : 'unhealthy',
      service: 'content-compliance',
      timestamp: new Date().toISOString(),
      version: '2.0', // Enhanced version
      features: [
        'advanced-moderation-api',
        'context-aware-analysis',
        'intelligent-caching',
        'complex-rule-validation',
        'gpt4-compliance-analysis',
        'violation-prediction',
        'auto-fix-capabilities',
        'batch-processing',
        'performance-monitoring'
      ]
    }
    
    if (!isHealthy) {
      response.error = 'Failed to connect to OpenAI Moderation API'
    }
    
    // Include performance metrics if requested
    if (includeMetrics && isHealthy) {
      try {
        const metrics = await brandComplianceService.instance.getPerformanceMetrics()
        response.performanceMetrics = metrics
      } catch (error) {
        console.warn('Failed to get performance metrics:', error)
      }
    }
    
    return NextResponse.json(response, { 
      status: isHealthy ? 200 : 503 
    })

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

