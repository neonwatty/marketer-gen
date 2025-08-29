import { NextResponse } from 'next/server'

import { z } from 'zod'

/**
 * Standard API error response structure
 */
export interface ApiErrorResponse {
  error: string
  message?: string
  details?: any
  timestamp: string
}

/**
 * Standard API success response structure
 */
export interface ApiSuccessResponse<T = any> {
  data?: T
  success?: boolean
  timestamp: string
  [key: string]: any
}

/**
 * Creates a standardized error response
 */
export function createErrorResponse(
  error: string,
  message?: string,
  status: number = 500,
  details?: any
): NextResponse {
  const response: ApiErrorResponse = {
    error,
    message,
    details,
    timestamp: new Date().toISOString(),
  }

  return NextResponse.json(response, { status })
}

/**
 * Creates a standardized success response
 */
export function createSuccessResponse<T>(
  data: T,
  status: number = 200,
  additionalFields?: Record<string, any>
): NextResponse {
  const response: ApiSuccessResponse<T> = {
    ...additionalFields,
    data,
    timestamp: new Date().toISOString(),
  }

  return NextResponse.json(response, { status })
}

/**
 * Handles Zod validation errors with consistent formatting
 */
export function handleValidationError(error: z.ZodError): NextResponse {
  return createErrorResponse(
    'Validation error',
    'The request data is invalid',
    400,
    error.format()
  )
}

/**
 * Handles JSON parsing errors
 */
export function handleJsonParseError(): NextResponse {
  return createErrorResponse(
    'Invalid JSON',
    'Request body must be valid JSON',
    400
  )
}

/**
 * Handles content type errors
 */
export function handleContentTypeError(): NextResponse {
  return createErrorResponse(
    'Invalid content type',
    'Content-Type must be application/json',
    415
  )
}

/**
 * Handles authentication errors
 */
export function handleAuthError(): NextResponse {
  return createErrorResponse(
    'Authentication required',
    'You must be authenticated to access this resource',
    401
  )
}

/**
 * Handles authorization errors
 */
export function handleAuthzError(resource?: string): NextResponse {
  return createErrorResponse(
    'Access denied',
    resource 
      ? `You do not have permission to access ${resource}`
      : 'You do not have permission to access this resource',
    403
  )
}

/**
 * Handles not found errors
 */
export function handleNotFoundError(resource?: string): NextResponse {
  return createErrorResponse(
    'Resource not found',
    resource 
      ? `The requested ${resource} could not be found`
      : 'The requested resource could not be found',
    404
  )
}

/**
 * Comprehensive error logging utility
 */
export function logError(
  context: string,
  error: unknown,
  request?: Request,
  userId?: string
) {
  const errorInfo = {
    context,
    error: error instanceof Error ? error.message : String(error),
    stack: error instanceof Error ? error.stack : undefined,
    timestamp: new Date().toISOString(),
    url: request?.url,
    method: request?.method,
    userId,
  }

  console.error(`[${context}] Error:`, errorInfo)
}

/**
 * Validates request content type and parses JSON body
 */
export async function validateAndParseJson(request: Request): Promise<{
  success: true
  data: any
} | {
  success: false
  response: NextResponse
}> {
  // Check content type
  if (!request.headers.get('content-type')?.includes('application/json')) {
    return {
      success: false,
      response: handleContentTypeError()
    }
  }

  // Parse JSON
  try {
    const data = await request.json()
    return { success: true, data }
  } catch (parseError) {
    return {
      success: false,
      response: handleJsonParseError()
    }
  }
}

/**
 * Adds caching headers to a response
 */
export function addCacheHeaders(
  response: NextResponse,
  maxAge: number = 300,
  etag?: string
): NextResponse {
  response.headers.set('Cache-Control', `private, max-age=${maxAge}`)
  
  if (etag) {
    response.headers.set('ETag', `"${etag}"`)
  }
  
  return response
}

/**
 * Query parameter validation schema
 */
export const PaginationQuerySchema = z.object({
  page: z.string().optional().transform((val) => {
    if (!val) return 1
    const num = parseInt(val)
    return isNaN(num) || num < 1 ? 1 : num
  }),
  limit: z.string().optional().transform((val) => {
    if (!val) return 10
    const num = parseInt(val)
    return isNaN(num) || num < 1 ? 10 : Math.min(num, 100) // Cap at 100
  }),
})