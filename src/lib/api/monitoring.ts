import { NextRequest, NextResponse } from 'next/server'

// Request tracking and metrics
export interface RequestMetrics {
  requestId: string
  method: string
  path: string
  userAgent: string
  ip: string
  timestamp: number
  duration?: number
  statusCode?: number
  responseSize?: number
  error?: string
  userId?: string
  cached?: boolean
  queryCount?: number
  queryDuration?: number
}

// Performance thresholds
export const performanceThresholds = {
  slow: 1000, // 1 second
  verySlow: 5000, // 5 seconds
  critical: 10000, // 10 seconds
} as const

// In-memory metrics storage (in production, use Redis, DataDog, etc.)
class MetricsStore {
  private requests = new Map<string, RequestMetrics>()
  private maxSize = 10000 // Keep last 10k requests

  add(metrics: RequestMetrics): void {
    // Remove oldest entries if we exceed max size
    if (this.requests.size >= this.maxSize) {
      const oldestKey = this.requests.keys().next().value
      if (oldestKey) {
        this.requests.delete(oldestKey)
      }
    }
    
    this.requests.set(metrics.requestId, metrics)
  }

  get(requestId: string): RequestMetrics | undefined {
    return this.requests.get(requestId)
  }

  getRecent(limit = 100): RequestMetrics[] {
    const entries = Array.from(this.requests.values())
    return entries
      .sort((a, b) => b.timestamp - a.timestamp)
      .slice(0, limit)
  }

  getStats(): {
    total: number
    lastHour: number
    averageResponseTime: number
    errorRate: number
    slowRequests: number
  } {
    const now = Date.now()
    const hourAgo = now - 60 * 60 * 1000
    const allRequests = Array.from(this.requests.values())
    
    const lastHourRequests = allRequests.filter(r => r.timestamp > hourAgo)
    const completedRequests = allRequests.filter(r => r.duration !== undefined)
    const errorRequests = allRequests.filter(r => r.error || (r.statusCode && r.statusCode >= 400))
    const slowRequests = allRequests.filter(r => r.duration && r.duration > performanceThresholds.slow)

    const totalDuration = completedRequests.reduce((sum, r) => sum + (r.duration || 0), 0)
    const averageResponseTime = completedRequests.length > 0 
      ? Math.round(totalDuration / completedRequests.length)
      : 0

    const errorRate = allRequests.length > 0 
      ? Math.round((errorRequests.length / allRequests.length) * 100 * 100) / 100
      : 0

    return {
      total: allRequests.length,
      lastHour: lastHourRequests.length,
      averageResponseTime,
      errorRate,
      slowRequests: slowRequests.length,
    }
  }

  clear(): void {
    this.requests.clear()
  }
}

// Global metrics store
export const metricsStore = new MetricsStore()

// Generate unique request ID
export const generateRequestId = (): string => {
  return `req_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
}

// Extract client IP address
export const getClientIP = (request: NextRequest): string => {
  const xForwardedFor = request.headers.get('x-forwarded-for')
  const xRealIP = request.headers.get('x-real-ip')
  
  if (xForwardedFor) {
    return xForwardedFor.split(',')[0].trim()
  }
  
  if (xRealIP) {
    return xRealIP.trim()
  }
  
  return 'unknown'
}

// Extract user ID from request (implement based on your auth system)
export const extractUserId = (request: NextRequest): string | undefined => {
  // This is a placeholder - implement based on your authentication system
  const authHeader = request.headers.get('Authorization')
  if (authHeader?.startsWith('Bearer ')) {
    // Extract user ID from JWT token or session
    // This is just an example
    try {
      // Decode JWT or validate session here
      return undefined // Replace with actual user ID extraction
    } catch {
      return undefined
    }
  }
  return undefined
}

// Start request tracking
export const startRequestTracking = (request: NextRequest): RequestMetrics => {
  const requestId = generateRequestId()
  
  const metrics: RequestMetrics = {
    requestId,
    method: request.method,
    path: request.nextUrl.pathname,
    userAgent: request.headers.get('user-agent') || 'unknown',
    ip: getClientIP(request),
    timestamp: Date.now(),
    userId: extractUserId(request),
  }

  // Add request ID to headers for response tracking
  request.headers.set('x-request-id', requestId)
  
  return metrics
}

// Complete request tracking
export const completeRequestTracking = (
  metrics: RequestMetrics,
  response: NextResponse,
  error?: Error,
  queryMetrics?: { count: number; duration: number }
): void => {
  const endTime = Date.now()
  const duration = endTime - metrics.timestamp

  // Update metrics
  metrics.duration = duration
  metrics.statusCode = response.status
  metrics.error = error?.message
  metrics.queryCount = queryMetrics?.count
  metrics.queryDuration = queryMetrics?.duration

  // Estimate response size (rough approximation)
  const responseText = JSON.stringify(response)
  metrics.responseSize = new TextEncoder().encode(responseText).length

  // Check if response was cached
  metrics.cached = response.headers.get('x-cache-status') === 'HIT'

  // Store metrics
  metricsStore.add(metrics)

  // Log based on performance
  logRequestMetrics(metrics)

  // Add tracking headers to response
  response.headers.set('x-request-id', metrics.requestId)
  response.headers.set('x-response-time', `${duration}ms`)
  
  if (queryMetrics) {
    response.headers.set('x-db-queries', queryMetrics.count.toString())
    response.headers.set('x-db-time', `${queryMetrics.duration}ms`)
  }
}

// Log request metrics based on performance and status
export const logRequestMetrics = (metrics: RequestMetrics): void => {
  const { method, path, duration = 0, statusCode, error, userId, requestId } = metrics

  const logData = {
    requestId,
    method,
    path,
    duration,
    statusCode,
    userId,
    queryCount: metrics.queryCount,
    queryDuration: metrics.queryDuration,
    cached: metrics.cached,
  }

  if (process.env.NODE_ENV === 'test') {
    return // Skip logging in tests
  }

  // Error logging
  if (error || (statusCode && statusCode >= 500)) {
    console.error('🚨 API Error:', {
      ...logData,
      error,
      stack: error ? new Error().stack : undefined,
    })
    return
  }

  // Client error logging
  if (statusCode && statusCode >= 400) {
    console.warn('⚠️ API Client Error:', logData)
    return
  }

  // Performance-based logging
  if (duration > performanceThresholds.critical) {
    console.error('🐌 Critical Performance:', logData)
  } else if (duration > performanceThresholds.verySlow) {
    console.warn('🐌 Very Slow Request:', logData)
  } else if (duration > performanceThresholds.slow) {
    console.warn('🐌 Slow Request:', logData)
  } else if (process.env.NODE_ENV === 'development') {
    console.log('✅ API Request:', logData)
  }
}

// Request monitoring middleware
export const withRequestMonitoring = <T extends any[], R>(
  handler: (...args: T) => Promise<NextResponse<R>>,
  operation?: string
) => {
  return async (...args: T): Promise<NextResponse<R>> => {
    const request = args.find(arg => arg instanceof NextRequest) as NextRequest
    
    if (!request) {
      return handler(...args)
    }

    // Start tracking
    const metrics = startRequestTracking(request)
    
    // Track query metrics
    let queryCount = 0
    let queryStartTime = Date.now()
    let totalQueryDuration = 0

    // Override console.log to track database queries (basic implementation)
    const originalLog = console.log
    console.log = (...logArgs: any[]) => {
      const message = logArgs.join(' ')
      if (message.includes('prisma:query')) {
        queryCount++
      }
      originalLog(...logArgs)
    }

    let response: NextResponse<R>
    let error: Error | undefined

    try {
      queryStartTime = Date.now()
      response = await handler(...args)
    } catch (err) {
      error = err instanceof Error ? err : new Error(String(err))
      throw err
    } finally {
      // Restore original console.log
      console.log = originalLog
      
      totalQueryDuration = Date.now() - queryStartTime

      // Complete tracking
      if (response!) {
        completeRequestTracking(
          metrics,
          response,
          error,
          { count: queryCount, duration: totalQueryDuration }
        )
      }
    }

    return response!
  }
}

// Health check endpoint data
export const getSystemHealth = async (): Promise<{
  status: 'healthy' | 'degraded' | 'unhealthy'
  timestamp: string
  uptime: number
  memory: {
    used: number
    total: number
    percentage: number
  }
  api: {
    total: number
    lastHour: number
    averageResponseTime: number
    errorRate: number
    slowRequests: number
  }
  version: string
}> => {
  const stats = metricsStore.getStats()
  
  // Memory usage
  const memoryUsage = process.memoryUsage()
  const memoryPercentage = Math.round((memoryUsage.heapUsed / memoryUsage.heapTotal) * 100)

  // Determine overall health
  let status: 'healthy' | 'degraded' | 'unhealthy' = 'healthy'
  
  if (stats.errorRate > 10 || stats.averageResponseTime > performanceThresholds.verySlow) {
    status = 'unhealthy'
  } else if (stats.errorRate > 5 || stats.averageResponseTime > performanceThresholds.slow) {
    status = 'degraded'
  }

  return {
    status,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: {
      used: Math.round(memoryUsage.heapUsed / 1024 / 1024), // MB
      total: Math.round(memoryUsage.heapTotal / 1024 / 1024), // MB
      percentage: memoryPercentage,
    },
    api: stats,
    version: process.env.npm_package_version || '1.0.0',
  }
}

// Performance alerts
export const checkPerformanceAlerts = (): string[] => {
  const stats = metricsStore.getStats()
  const alerts: string[] = []

  if (stats.errorRate > 15) {
    alerts.push(`High error rate: ${stats.errorRate}%`)
  }

  if (stats.averageResponseTime > performanceThresholds.verySlow) {
    alerts.push(`Very slow average response time: ${stats.averageResponseTime}ms`)
  }

  if (stats.slowRequests > stats.total * 0.2) {
    alerts.push(`High percentage of slow requests: ${Math.round(stats.slowRequests / stats.total * 100)}%`)
  }

  const memoryUsage = process.memoryUsage()
  const memoryPercentage = Math.round((memoryUsage.heapUsed / memoryUsage.heapTotal) * 100)
  
  if (memoryPercentage > 90) {
    alerts.push(`High memory usage: ${memoryPercentage}%`)
  }

  return alerts
}

// Export metrics for external monitoring systems
export const exportMetrics = (format: 'json' | 'prometheus' = 'json') => {
  const stats = metricsStore.getStats()
  const recent = metricsStore.getRecent(1000)

  if (format === 'prometheus') {
    // Prometheus format
    return `# HELP api_requests_total Total number of API requests
# TYPE api_requests_total counter
api_requests_total ${stats.total}

# HELP api_request_duration_ms Average request duration in milliseconds
# TYPE api_request_duration_ms gauge
api_request_duration_ms ${stats.averageResponseTime}

# HELP api_error_rate Error rate percentage
# TYPE api_error_rate gauge
api_error_rate ${stats.errorRate}

# HELP api_slow_requests_total Total number of slow requests
# TYPE api_slow_requests_total counter
api_slow_requests_total ${stats.slowRequests}
`
  }

  // JSON format (default)
  return {
    summary: stats,
    recent: recent.slice(0, 100), // Last 100 requests
    timestamp: new Date().toISOString(),
  }
}

// Clear metrics (for testing or manual reset)
export const clearMetrics = (): void => {
  metricsStore.clear()
}