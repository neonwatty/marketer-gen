import { NextRequest, NextResponse } from 'next/server'

import { checkPerformanceAlerts, exportMetrics, getSystemHealth, withRequestMonitoring } from '@/lib/api/monitoring'
import { checkDatabaseHealth } from '@/lib/database'

// Enhanced health check endpoint
export const GET = withRequestMonitoring(async (): Promise<NextResponse> => {
  try {
    // Check database health
    const dbHealth = await checkDatabaseHealth()
    
    // Get system health metrics
    const systemHealth = await getSystemHealth()
    
    // Check for performance alerts
    const alerts = checkPerformanceAlerts()
    
    // Determine overall health status
    const isHealthy = dbHealth.status === 'healthy' && 
                     systemHealth.status === 'healthy' && 
                     alerts.length === 0
    
    const healthStatus = {
      status: isHealthy ? 'healthy' : 
              dbHealth.status === 'unhealthy' || systemHealth.status === 'unhealthy' ? 'unhealthy' : 'degraded',
      timestamp: new Date().toISOString(),
      services: {
        database: {
          status: dbHealth.status,
          latency: dbHealth.latency,
          error: dbHealth.error,
        },
        api: {
          status: systemHealth.status,
          uptime: systemHealth.uptime,
          memory: systemHealth.memory,
          stats: systemHealth.api,
        },
      },
      alerts: alerts.length > 0 ? alerts : undefined,
      version: systemHealth.version,
    }
    
    const statusCode = isHealthy ? 200 : 
                      systemHealth.status === 'unhealthy' || dbHealth.status === 'unhealthy' ? 503 : 200
    
    return NextResponse.json(healthStatus, { status: statusCode })
  } catch (error) {
    console.error('[HEALTH_CHECK]', error)
    return NextResponse.json(
      {
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        error: 'Health check failed',
        details: process.env.NODE_ENV === 'development' ? 
                 (error instanceof Error ? error.message : 'Unknown error') : 
                 undefined,
      },
      { status: 503 }
    )
  }
}, 'health-check')

// Metrics endpoint (for monitoring systems)
export const POST = withRequestMonitoring(async (request: NextRequest) => {
  try {
    const url = new URL(request.url)
    const format = url.searchParams.get('format') as 'json' | 'prometheus' || 'json'
    
    const metrics = exportMetrics(format)
    
    const contentType = format === 'prometheus' ? 'text/plain' : 'application/json'
    
    return new NextResponse(
      format === 'prometheus' ? metrics as string : JSON.stringify(metrics),
      {
        status: 200,
        headers: {
          'Content-Type': contentType,
          'Cache-Control': 'no-cache, no-store, must-revalidate',
        },
      }
    )
  } catch (error) {
    console.error('[METRICS_EXPORT]', error)
    return NextResponse.json(
      { error: 'Failed to export metrics' },
      { status: 500 }
    )
  }
}, 'metrics-export')