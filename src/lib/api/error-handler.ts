import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'
import { Prisma } from '@/generated/prisma'

// Custom API error class
export class ApiError extends Error {
  constructor(
    public message: string,
    public statusCode: number = 500,
    public code?: string,
    public details?: any
  ) {
    super(message)
    this.name = 'ApiError'
  }
}

// Standard error response format
export interface ErrorResponse {
  error: string
  code?: string
  details?: any
  timestamp: string
  path?: string
  requestId?: string
}

// Error handling utility
export const handleApiError = (
  error: unknown,
  request?: NextRequest,
  operation?: string
): NextResponse<ErrorResponse> => {
  const timestamp = new Date().toISOString()
  const path = request?.nextUrl?.pathname
  const requestId = request?.headers.get('x-request-id') || undefined
  
  // Log error details
  console.error(`[API_ERROR] ${operation || 'Unknown operation'}:`, {
    error: error instanceof Error ? error.message : 'Unknown error',
    stack: error instanceof Error ? error.stack : undefined,
    timestamp,
    path,
    requestId,
  })

  // Handle different error types
  if (error instanceof ApiError) {
    return NextResponse.json<ErrorResponse>(
      {
        error: error.message,
        code: error.code,
        details: error.details,
        timestamp,
        path,
        requestId,
      },
      { status: error.statusCode }
    )
  }

  // Handle Zod validation errors
  if (error instanceof z.ZodError) {
    return NextResponse.json<ErrorResponse>(
      {
        error: 'Validation failed',
        code: 'VALIDATION_ERROR',
        details: error.issues.map(issue => ({
          field: issue.path.join('.'),
          message: issue.message,
          code: issue.code,
        })),
        timestamp,
        path,
        requestId,
      },
      { status: 400 }
    )
  }

  // Handle Prisma errors
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    let message = 'Database operation failed'
    let statusCode = 500
    let code = error.code

    switch (error.code) {
      case 'P2002':
        message = 'Resource already exists'
        statusCode = 409
        break
      case 'P2025':
        message = 'Resource not found'
        statusCode = 404
        break
      case 'P2003':
        message = 'Foreign key constraint failed'
        statusCode = 400
        break
      case 'P2014':
        message = 'Required relation is missing'
        statusCode = 400
        break
    }

    return NextResponse.json<ErrorResponse>(
      {
        error: message,
        code,
        details: process.env.NODE_ENV === 'development' ? error.meta : undefined,
        timestamp,
        path,
        requestId,
      },
      { status: statusCode }
    )
  }

  // Handle other Prisma errors
  if (error instanceof Prisma.PrismaClientValidationError) {
    return NextResponse.json<ErrorResponse>(
      {
        error: 'Invalid database operation',
        code: 'DATABASE_VALIDATION_ERROR',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
        timestamp,
        path,
        requestId,
      },
      { status: 400 }
    )
  }

  if (error instanceof Prisma.PrismaClientInitializationError) {
    return NextResponse.json<ErrorResponse>(
      {
        error: 'Database connection failed',
        code: 'DATABASE_CONNECTION_ERROR',
        timestamp,
        path,
        requestId,
      },
      { status: 503 }
    )
  }

  // Handle network/timeout errors
  if (error instanceof Error && error.message.includes('timeout')) {
    return NextResponse.json<ErrorResponse>(
      {
        error: 'Request timeout',
        code: 'REQUEST_TIMEOUT',
        timestamp,
        path,
        requestId,
      },
      { status: 408 }
    )
  }

  // Handle generic errors
  const errorMessage = error instanceof Error ? error.message : 'An unexpected error occurred'
  
  return NextResponse.json<ErrorResponse>(
    {
      error: process.env.NODE_ENV === 'production' ? 'Internal server error' : errorMessage,
      code: 'INTERNAL_SERVER_ERROR',
      details: process.env.NODE_ENV === 'development' && error instanceof Error ? {
        message: error.message,
        stack: error.stack,
      } : undefined,
      timestamp,
      path,
      requestId,
    },
    { status: 500 }
  )
}

// Async error handler wrapper
export const withErrorHandler = <T extends any[], R>(
  handler: (...args: T) => Promise<NextResponse<R>>,
  operation?: string
) => {
  return async (...args: T): Promise<NextResponse<R | ErrorResponse>> => {
    try {
      return await handler(...args)
    } catch (error) {
      const request = args.find(arg => arg instanceof NextRequest) as NextRequest | undefined
      return handleApiError(error, request, operation)
    }
  }
}

// Route handler wrapper
export const createApiHandler = <T = any>(config: {
  GET?: (request: NextRequest, context?: any) => Promise<NextResponse<T>>
  POST?: (request: NextRequest, context?: any) => Promise<NextResponse<T>>
  PUT?: (request: NextRequest, context?: any) => Promise<NextResponse<T>>
  PATCH?: (request: NextRequest, context?: any) => Promise<NextResponse<T>>
  DELETE?: (request: NextRequest, context?: any) => Promise<NextResponse<T>>
  operation?: string
}) => {
  const handlers: Record<string, any> = {}
  
  Object.entries(config).forEach(([method, handler]) => {
    if (method !== 'operation' && typeof handler === 'function') {
      handlers[method] = withErrorHandler(handler, `${method} ${config.operation || 'unknown'}`)
    }
  })
  
  return handlers
}

// Common API error factories
export const createApiError = {
  badRequest: (message: string, details?: any) => new ApiError(message, 400, 'BAD_REQUEST', details),
  unauthorized: (message = 'Unauthorized') => new ApiError(message, 401, 'UNAUTHORIZED'),
  forbidden: (message = 'Forbidden') => new ApiError(message, 403, 'FORBIDDEN'),
  notFound: (resource = 'Resource') => new ApiError(`${resource} not found`, 404, 'NOT_FOUND'),
  conflict: (message: string, details?: any) => new ApiError(message, 409, 'CONFLICT', details),
  unprocessable: (message: string, details?: any) => new ApiError(message, 422, 'UNPROCESSABLE_ENTITY', details),
  tooManyRequests: (message = 'Too many requests') => new ApiError(message, 429, 'TOO_MANY_REQUESTS'),
  internal: (message = 'Internal server error') => new ApiError(message, 500, 'INTERNAL_SERVER_ERROR'),
  serviceUnavailable: (message = 'Service unavailable') => new ApiError(message, 503, 'SERVICE_UNAVAILABLE'),
}

// Request validation helper
export const validateRequest = <T>(schema: z.ZodSchema<T>, data: unknown): T => {
  try {
    return schema.parse(data)
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw error // Will be handled by withErrorHandler
    }
    throw createApiError.badRequest('Invalid request data')
  }
}

// Success response helper
export const createSuccessResponse = <T>(
  data: T,
  status: number = 200,
  headers?: Record<string, string>
): NextResponse<T> => {
  return NextResponse.json(data, { status, headers })
}

// Pagination response helper
export const createPaginatedResponse = <T>(
  data: T[],
  pagination: {
    page: number
    limit: number
    total: number
    pages?: number
  },
  status: number = 200
): NextResponse<{
  data: T[]
  pagination: {
    page: number
    limit: number
    total: number
    pages: number
  }
}> => {
  return NextResponse.json({
    data,
    pagination: {
      ...pagination,
      pages: pagination.pages || Math.ceil(pagination.total / pagination.limit),
    }
  }, { status })
}