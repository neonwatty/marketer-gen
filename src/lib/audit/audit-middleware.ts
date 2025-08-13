import { NextRequest, NextResponse } from 'next/server'
import { nanoid } from 'nanoid'
import { PrismaClient } from '@prisma/client'
import { getAuditService, AuditContext } from './audit-service'

export interface AuditMiddlewareConfig {
  enableApiTracking?: boolean
  enablePerformanceTracking?: boolean
  enableErrorTracking?: boolean
  excludeRoutes?: string[]
  sensitiveFields?: string[]
  maxBodySize?: number
}

export interface AuditableRequest extends NextRequest {
  auditContext?: AuditContext
  requestId?: string
  startTime?: number
}

const defaultConfig: AuditMiddlewareConfig = {
  enableApiTracking: true,
  enablePerformanceTracking: true,
  enableErrorTracking: true,
  excludeRoutes: ['/api/health', '/api/_next'],
  sensitiveFields: ['password', 'token', 'secret', 'key', 'auth'],
  maxBodySize: 10000 // 10KB max body size for logging
}

export class AuditMiddleware {
  private config: AuditMiddlewareConfig
  private auditService: ReturnType<typeof getAuditService>

  constructor(prisma: PrismaClient, config: Partial<AuditMiddlewareConfig> = {}) {
    this.config = { ...defaultConfig, ...config }
    this.auditService = getAuditService(prisma)
  }

  /**
   * Extract audit context from request
   */
  private extractAuditContext(request: AuditableRequest): AuditContext {
    const headers = request.headers
    const url = new URL(request.url)
    
    return {
      requestId: request.requestId || nanoid(),
      ipAddress: this.getClientIp(request),
      userAgent: headers.get('user-agent') || undefined,
      referrer: headers.get('referer') || undefined,
      hostname: url.hostname,
      // Note: In a real application, you'd extract userId, username, etc. from authentication
      // userId: request.user?.id,
      // username: request.user?.username,
      // userRole: request.user?.role,
      // sessionId: request.session?.id
    }
  }

  /**
   * Get client IP address from request
   */
  private getClientIp(request: NextRequest): string {
    const headers = request.headers
    return (
      headers.get('x-forwarded-for')?.split(',')[0] ||
      headers.get('x-real-ip') ||
      headers.get('x-client-ip') ||
      headers.get('cf-connecting-ip') ||
      'unknown'
    )
  }

  /**
   * Check if route should be excluded from audit logging
   */
  private shouldExcludeRoute(pathname: string): boolean {
    return this.config.excludeRoutes?.some(route => 
      pathname.startsWith(route)
    ) || false
  }

  /**
   * Sanitize request/response data by removing sensitive fields
   */
  private sanitizeData(data: any): any {
    if (!data || typeof data !== 'object') return data
    
    const sanitized = { ...data }
    
    for (const field of this.config.sensitiveFields || []) {
      if (field in sanitized) {
        sanitized[field] = '[REDACTED]'
      }
    }
    
    return sanitized
  }

  /**
   * Truncate data if it exceeds max size
   */
  private truncateData(data: any): any {
    const jsonString = JSON.stringify(data)
    if (jsonString.length > (this.config.maxBodySize || 10000)) {
      return {
        ...data,
        _truncated: true,
        _originalSize: jsonString.length
      }
    }
    return data
  }

  /**
   * Middleware for Next.js API routes
   */
  withAudit = <T extends any[], R>(
    handler: (request: AuditableRequest, ...args: T) => Promise<R> | R
  ) => {
    return async (request: AuditableRequest, ...args: T): Promise<R> => {
      const startTime = Date.now()
      const url = new URL(request.url)
      const pathname = url.pathname
      const method = request.method

      // Skip excluded routes
      if (this.shouldExcludeRoute(pathname)) {
        return handler(request, ...args)
      }

      // Set up request context
      request.requestId = nanoid()
      request.startTime = startTime
      request.auditContext = this.extractAuditContext(request)

      let response: R
      let error: Error | null = null
      let statusCode = 200

      try {
        response = await handler(request, ...args)
        
        // Extract status code from response if it's a NextResponse
        if (response instanceof NextResponse) {
          statusCode = response.status
        }
      } catch (err) {
        error = err as Error
        statusCode = 500
        throw err
      } finally {
        const duration = Date.now() - startTime

        // Log API call if enabled
        if (this.config.enableApiTracking) {
          await this.auditService.logApiCall(
            pathname,
            method || 'UNKNOWN',
            statusCode,
            duration,
            request.auditContext,
            {
              metadata: {
                query: this.sanitizeData(Object.fromEntries(url.searchParams)),
                userAgent: request.auditContext?.userAgent,
                error: error?.message
              }
            }
          )
        }

        // Log error if one occurred and error tracking is enabled
        if (error && this.config.enableErrorTracking) {
          await this.auditService.logSecurityEvent(
            'api_error',
            `API error on ${method} ${pathname}: ${error.message}`,
            request.auditContext,
            {
              severity: 'ERROR' as any,
              metadata: {
                stack: error.stack,
                statusCode,
                duration
              }
            }
          )
        }
      }

      return response
    }
  }

  /**
   * Middleware wrapper for database operations
   */
  withDatabaseAudit = <T extends any[], R>(
    operation: (...args: T) => Promise<R>,
    auditConfig: {
      entityType: string
      action: string
      getEntityId: (...args: T) => string
      getData?: (...args: T) => Record<string, any>
      context?: AuditContext
    }
  ) => {
    return async (...args: T): Promise<R> => {
      const startTime = Date.now()
      let result: R
      let error: Error | null = null

      try {
        result = await operation(...args)
      } catch (err) {
        error = err as Error
        throw err
      } finally {
        const duration = Date.now() - startTime
        const entityId = auditConfig.getEntityId(...args)
        const data = auditConfig.getData ? auditConfig.getData(...args) : {}

        // Log the database operation
        await this.auditService.log({
          eventType: this.getEventTypeFromAction(auditConfig.action),
          eventCategory: 'SYSTEM_ADMINISTRATION' as any,
          entityType: auditConfig.entityType as any,
          entityId,
          action: auditConfig.action,
          description: `Database ${auditConfig.action} on ${auditConfig.entityType}`,
          newValues: data,
          duration,
          metadata: {
            error: error?.message,
            success: !error
          }
        }, auditConfig.context)
      }

      return result
    }
  }

  /**
   * Helper to convert action strings to event types
   */
  private getEventTypeFromAction(action: string): string {
    const actionMap: Record<string, string> = {
      create: 'CREATE',
      update: 'UPDATE',
      delete: 'DELETE',
      read: 'VIEW',
      view: 'VIEW'
    }
    
    return actionMap[action.toLowerCase()] || 'SYSTEM_EVENT'
  }
}

/**
 * Create audit middleware instance
 */
export function createAuditMiddleware(
  prisma: PrismaClient, 
  config?: Partial<AuditMiddlewareConfig>
): AuditMiddleware {
  return new AuditMiddleware(prisma, config)
}

/**
 * Decorator for automatic audit logging on class methods
 */
export function auditLog(
  eventType: string,
  entityType: string,
  options?: {
    getEntityId?: (target: any, args: any[]) => string
    getDescription?: (target: any, args: any[]) => string
    getData?: (target: any, args: any[]) => Record<string, any>
  }
) {
  return function (target: any, propertyName: string, descriptor: PropertyDescriptor) {
    const method = descriptor.value

    descriptor.value = async function (...args: any[]) {
      const startTime = Date.now()
      let result: any
      let error: Error | null = null

      try {
        result = await method.apply(this, args)
      } catch (err) {
        error = err as Error
        throw err
      } finally {
        const duration = Date.now() - startTime
        
        // Try to get audit service from context (would need to be implemented based on your DI setup)
        if (this.auditService || global.auditService) {
          const auditService = this.auditService || global.auditService
          const entityId = options?.getEntityId ? options.getEntityId(this, args) : 'unknown'
          const description = options?.getDescription ? options.getDescription(this, args) : `${propertyName} executed`
          const data = options?.getData ? options.getData(this, args) : {}

          await auditService.log({
            eventType: eventType as any,
            eventCategory: 'SYSTEM_ADMINISTRATION' as any,
            entityType: entityType as any,
            entityId,
            action: propertyName,
            description,
            newValues: data,
            duration,
            metadata: {
              methodName: propertyName,
              error: error?.message,
              success: !error
            }
          })
        }
      }

      return result
    }

    return descriptor
  }
}

export default AuditMiddleware