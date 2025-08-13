import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { 
  AuditMiddleware, 
  AuditMiddlewareConfig, 
  AuditableRequest 
} from '@/lib/audit/audit-middleware'
import { getAuditService } from '@/lib/audit/audit-service'
import { nanoid } from 'nanoid'
import { vi } from 'vitest'

// Mock dependencies
vi.mock('nanoid', () => ({
  nanoid: vi.fn(() => 'test-request-id-456')
}))

vi.mock('@/lib/audit/audit-service', () => ({
  getAuditService: vi.fn()
}))

const mockAuditService = {
  log: vi.fn(),
  logApiRequest: vi.fn(),
  logApiResponse: vi.fn(),
  logError: vi.fn(),
  logPerformance: vi.fn()
}

const mockPrismaClient = {} as PrismaClient

describe('AuditMiddleware', () => {
  let auditMiddleware: AuditMiddleware

  beforeEach(() => {
    vi.clearAllMocks()
    ;(getAuditService as vi.Mock).mockReturnValue(mockAuditService)
    auditMiddleware = new AuditMiddleware(mockPrismaClient)
  })

  describe('Initialization', () => {
    test('should initialize with default configuration', () => {
      const middleware = new AuditMiddleware(mockPrismaClient)
      expect(middleware).toBeInstanceOf(AuditMiddleware)
      expect(getAuditService).toHaveBeenCalledWith(mockPrismaClient)
    })

    test('should initialize with custom configuration', () => {
      const customConfig: Partial<AuditMiddlewareConfig> = {
        enableApiTracking: false,
        excludeRoutes: ['/api/custom-exclude'],
        maxBodySize: 5000
      }

      const middleware = new AuditMiddleware(mockPrismaClient, customConfig)
      expect(middleware).toBeInstanceOf(AuditMiddleware)
    })

    test('should merge custom config with defaults', () => {
      const customConfig: Partial<AuditMiddlewareConfig> = {
        enableApiTracking: false,
        excludeRoutes: ['/api/test']
      }

      const middleware = new AuditMiddleware(mockPrismaClient, customConfig)
      expect(middleware).toBeInstanceOf(AuditMiddleware)
    })
  })

  describe('Request Context Extraction', () => {
    test('should extract basic audit context from request', () => {
      const mockRequest = new NextRequest('https://example.com/api/test', {
        method: 'GET',
        headers: {
          'user-agent': 'Test Browser/1.0',
          'referer': 'https://example.com/dashboard',
          'x-forwarded-for': '192.168.1.1',
          'authorization': 'Bearer token123'
        }
      }) as AuditableRequest

      // Access private method through type assertion for testing
      const context = (auditMiddleware as any).extractAuditContext(mockRequest)

      expect(context).toMatchObject({
        requestId: 'test-request-id-456',
        userAgent: 'Test Browser/1.0',
        referrer: 'https://example.com/dashboard'
      })
      expect(context.ipAddress).toBeDefined()
    })

    test('should handle missing headers gracefully', () => {
      const mockRequest = new NextRequest('https://example.com/api/test', {
        method: 'GET'
      }) as AuditableRequest

      const context = (auditMiddleware as any).extractAuditContext(mockRequest)

      expect(context).toMatchObject({
        requestId: 'test-request-id-456',
        userAgent: undefined,
        referrer: undefined
      })
    })

    test('should extract IP address from various headers', () => {
      const scenarios = [
        { header: 'x-forwarded-for', value: '192.168.1.1, 10.0.0.1', expected: '192.168.1.1' },
        { header: 'x-real-ip', value: '192.168.1.2', expected: '192.168.1.2' },
        { header: 'cf-connecting-ip', value: '192.168.1.3', expected: '192.168.1.3' }
      ]

      scenarios.forEach(scenario => {
        const mockRequest = new NextRequest('https://example.com/api/test', {
          method: 'GET',
          headers: {
            [scenario.header]: scenario.value
          }
        }) as AuditableRequest

        const context = (auditMiddleware as any).extractAuditContext(mockRequest)
        expect(context.ipAddress).toBe(scenario.expected)
      })
    })

    test('should use existing request ID if present', () => {
      const mockRequest = new NextRequest('https://example.com/api/test', {
        method: 'GET'
      }) as AuditableRequest

      mockRequest.requestId = 'existing-request-id'

      const context = (auditMiddleware as any).extractAuditContext(mockRequest)
      expect(context.requestId).toBe('existing-request-id')
    })
  })

  describe('Route Filtering', () => {
    test('should exclude configured routes from tracking', () => {
      const excludedRoutes = ['/api/health', '/api/_next', '/api/metrics']
      const middleware = new AuditMiddleware(mockPrismaClient, { 
        excludeRoutes: excludedRoutes 
      })

      excludedRoutes.forEach(route => {
        const mockRequest = new NextRequest(`https://example.com${route}`, {
          method: 'GET'
        })

        const shouldTrack = (middleware as any).shouldTrackRoute(mockRequest.url)
        expect(shouldTrack).toBe(false)
      })
    })

    test('should track non-excluded routes', () => {
      const trackedRoutes = ['/api/campaigns', '/api/users', '/api/analytics']
      
      trackedRoutes.forEach(route => {
        const mockRequest = new NextRequest(`https://example.com${route}`, {
          method: 'GET'
        })

        const shouldTrack = (auditMiddleware as any).shouldTrackRoute(mockRequest.url)
        expect(shouldTrack).toBe(true)
      })
    })

    test('should handle wildcard exclusions', () => {
      const middleware = new AuditMiddleware(mockPrismaClient, {
        excludeRoutes: ['/api/internal/*', '/api/health*']
      })

      const excludedRoutes = [
        '/api/internal/metrics',
        '/api/internal/debug/trace',
        '/api/health',
        '/api/healthcheck'
      ]

      excludedRoutes.forEach(route => {
        const mockRequest = new NextRequest(`https://example.com${route}`)
        const shouldTrack = (middleware as any).shouldTrackRoute(mockRequest.url)
        expect(shouldTrack).toBe(false)
      })
    })
  })

  describe('Request Body Processing', () => {
    test('should sanitize sensitive fields from request body', async () => {
      const requestBody = {
        username: 'testuser',
        password: 'secretpassword',
        email: 'test@example.com',
        apiKey: 'api-key-123',
        data: {
          token: 'bearer-token',
          normalField: 'normal-value'
        }
      }

      const sanitized = (auditMiddleware as any).sanitizeBody(requestBody)

      expect(sanitized).toEqual({
        username: 'testuser',
        password: '[REDACTED]',
        email: 'test@example.com',
        apiKey: '[REDACTED]',
        data: {
          token: '[REDACTED]',
          normalField: 'normal-value'
        }
      })
    })

    test('should handle large request bodies', () => {
      const largeBody = {
        data: 'x'.repeat(15000) // Larger than default maxBodySize (10KB)
      }

      const processed = (auditMiddleware as any).processRequestBody(largeBody)
      expect(processed).toBe('[Body too large for audit logging]')
    })

    test('should handle circular references in request body', () => {
      const bodyWithCircular: any = { name: 'test' }
      bodyWithCircular.self = bodyWithCircular

      const processed = (auditMiddleware as any).processRequestBody(bodyWithCircular)
      expect(processed).toBe('[Unable to serialize request body]')
    })

    test('should handle null and undefined request bodies', () => {
      expect((auditMiddleware as any).processRequestBody(null)).toBe(null)
      expect((auditMiddleware as any).processRequestBody(undefined)).toBe(null)
    })
  })

  describe('API Request Tracking', () => {
    test('should track API requests when enabled', async () => {
      const mockRequest = new NextRequest('https://example.com/api/campaigns', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer token123'
        },
        body: JSON.stringify({ name: 'New Campaign', password: 'secret' })
      }) as AuditableRequest

      mockRequest.startTime = Date.now()

      await (auditMiddleware as any).trackApiRequest(mockRequest)

      expect(mockAuditService.logApiRequest).toHaveBeenCalledWith({
        method: 'POST',
        url: 'https://example.com/api/campaigns',
        headers: expect.objectContaining({
          'content-type': 'application/json'
        }),
        body: expect.objectContaining({
          name: 'New Campaign',
          password: '[REDACTED]'
        }),
        timestamp: expect.any(Number)
      }, expect.objectContaining({
        requestId: 'test-request-id-456'
      }))
    })

    test('should not track API requests when disabled', async () => {
      const middleware = new AuditMiddleware(mockPrismaClient, {
        enableApiTracking: false
      })

      const mockRequest = new NextRequest('https://example.com/api/test')

      await (middleware as any).trackApiRequest(mockRequest)

      expect(mockAuditService.logApiRequest).not.toHaveBeenCalled()
    })

    test('should track API responses', async () => {
      const mockRequest = new NextRequest('https://example.com/api/campaigns') as AuditableRequest
      mockRequest.startTime = Date.now()

      const mockResponse = new NextResponse(JSON.stringify({ id: '123', name: 'Campaign' }), {
        status: 200,
        headers: { 'content-type': 'application/json' }
      })

      await (auditMiddleware as any).trackApiResponse(mockRequest, mockResponse)

      expect(mockAuditService.logApiResponse).toHaveBeenCalledWith({
        statusCode: 200,
        headers: expect.objectContaining({
          'content-type': 'application/json'
        }),
        body: expect.objectContaining({
          id: '123',
          name: 'Campaign'
        }),
        duration: expect.any(Number)
      }, expect.objectContaining({
        requestId: 'test-request-id-456'
      }))
    })

    test('should handle response body sanitization', async () => {
      const mockRequest = new NextRequest('https://example.com/api/auth') as AuditableRequest
      const responseBody = {
        user: { id: '123', name: 'User' },
        token: 'jwt-token-123',
        refreshToken: 'refresh-token-456'
      }

      const mockResponse = new NextResponse(JSON.stringify(responseBody), {
        status: 200,
        headers: { 'content-type': 'application/json' }
      })

      await (auditMiddleware as any).trackApiResponse(mockRequest, mockResponse)

      expect(mockAuditService.logApiResponse).toHaveBeenCalledWith(
        expect.objectContaining({
          body: expect.objectContaining({
            user: { id: '123', name: 'User' },
            token: '[REDACTED]',
            refreshToken: '[REDACTED]'
          })
        }),
        expect.any(Object)
      )
    })
  })

  describe('Performance Tracking', () => {
    test('should track request performance when enabled', async () => {
      const mockRequest = new NextRequest('https://example.com/api/slow-endpoint') as AuditableRequest
      mockRequest.startTime = Date.now() - 2500 // 2.5 seconds ago

      const mockResponse = new NextResponse('OK', { status: 200 })

      await (auditMiddleware as any).trackPerformance(mockRequest, mockResponse)

      expect(mockAuditService.logPerformance).toHaveBeenCalledWith({
        endpoint: '/api/slow-endpoint',
        method: 'GET',
        duration: expect.any(Number),
        statusCode: 200,
        isSlowRequest: true
      }, expect.objectContaining({
        requestId: 'test-request-id-456'
      }))
    })

    test('should identify slow requests', async () => {
      const mockRequest = new NextRequest('https://example.com/api/test') as AuditableRequest
      mockRequest.startTime = Date.now() - 5000 // 5 seconds ago

      const mockResponse = new NextResponse('OK', { status: 200 })

      await (auditMiddleware as any).trackPerformance(mockRequest, mockResponse)

      const call = mockAuditService.logPerformance.mock.calls[0][0]
      expect(call.isSlowRequest).toBe(true)
      expect(call.duration).toBeGreaterThan(4000)
    })

    test('should not track performance when disabled', async () => {
      const middleware = new AuditMiddleware(mockPrismaClient, {
        enablePerformanceTracking: false
      })

      const mockRequest = new NextRequest('https://example.com/api/test') as AuditableRequest
      const mockResponse = new NextResponse('OK', { status: 200 })

      await (middleware as any).trackPerformance(mockRequest, mockResponse)

      expect(mockAuditService.logPerformance).not.toHaveBeenCalled()
    })
  })

  describe('Error Tracking', () => {
    test('should track errors when enabled', async () => {
      const mockRequest = new NextRequest('https://example.com/api/error-endpoint') as AuditableRequest
      const error = new Error('Database connection failed')
      
      await (auditMiddleware as any).trackError(mockRequest, error)

      expect(mockAuditService.logError).toHaveBeenCalledWith({
        error: 'Database connection failed',
        stack: expect.stringContaining('Error: Database connection failed'),
        endpoint: '/api/error-endpoint',
        method: 'GET',
        timestamp: expect.any(Number)
      }, expect.objectContaining({
        requestId: 'test-request-id-456'
      }))
    })

    test('should handle different error types', async () => {
      const mockRequest = new NextRequest('https://example.com/api/test') as AuditableRequest

      const scenarios = [
        { error: new Error('Standard error'), expectedMessage: 'Standard error' },
        { error: 'String error', expectedMessage: 'String error' },
        { error: { message: 'Object error' }, expectedMessage: 'Object error' },
        { error: null, expectedMessage: 'Unknown error' },
        { error: undefined, expectedMessage: 'Unknown error' }
      ]

      for (const scenario of scenarios) {
        await (auditMiddleware as any).trackError(mockRequest, scenario.error)

        expect(mockAuditService.logError).toHaveBeenCalledWith(
          expect.objectContaining({
            error: scenario.expectedMessage
          }),
          expect.any(Object)
        )
      }
    })

    test('should not track errors when disabled', async () => {
      const middleware = new AuditMiddleware(mockPrismaClient, {
        enableErrorTracking: false
      })

      const mockRequest = new NextRequest('https://example.com/api/test') as AuditableRequest
      const error = new Error('Test error')

      await (middleware as any).trackError(mockRequest, error)

      expect(mockAuditService.logError).not.toHaveBeenCalled()
    })
  })

  describe('Main Middleware Function', () => {
    test('should process request and response successfully', async () => {
      const mockRequest = new NextRequest('https://example.com/api/campaigns', {
        method: 'GET'
      })

      const handler = async () => {
        return new NextResponse(JSON.stringify({ campaigns: [] }), {
          status: 200,
          headers: { 'content-type': 'application/json' }
        })
      }

      const wrappedHandler = (auditMiddleware as any).middleware(handler)
      const response = await wrappedHandler(mockRequest)

      expect(response).toBeInstanceOf(NextResponse)
      expect(response.status).toBe(200)
      
      // Verify tracking methods were called
      expect(mockAuditService.logApiRequest).toHaveBeenCalled()
      expect(mockAuditService.logApiResponse).toHaveBeenCalled()
      expect(mockAuditService.logPerformance).toHaveBeenCalled()
    })

    test('should handle handler errors gracefully', async () => {
      const mockRequest = new NextRequest('https://example.com/api/error')

      const handler = async () => {
        throw new Error('Handler error')
      }

      const wrappedHandler = (auditMiddleware as any).middleware(handler)

      await expect(wrappedHandler(mockRequest)).rejects.toThrow('Handler error')
      
      // Should still track the error
      expect(mockAuditService.logError).toHaveBeenCalledWith(
        expect.objectContaining({
          error: 'Handler error'
        }),
        expect.any(Object)
      )
    })

    test('should skip tracking for excluded routes', async () => {
      const mockRequest = new NextRequest('https://example.com/api/health')

      const handler = async () => {
        return new NextResponse('OK', { status: 200 })
      }

      const wrappedHandler = (auditMiddleware as any).middleware(handler)
      const response = await wrappedHandler(mockRequest)

      expect(response.status).toBe(200)
      
      // Should not have called any tracking methods
      expect(mockAuditService.logApiRequest).not.toHaveBeenCalled()
      expect(mockAuditService.logApiResponse).not.toHaveBeenCalled()
      expect(mockAuditService.logPerformance).not.toHaveBeenCalled()
    })

    test('should attach audit context to request', async () => {
      const mockRequest = new NextRequest('https://example.com/api/test')

      const handler = async (req: AuditableRequest) => {
        // Verify audit context is attached
        expect(req.auditContext).toBeDefined()
        expect(req.requestId).toBeDefined()
        expect(req.startTime).toBeDefined()
        
        return new NextResponse('OK', { status: 200 })
      }

      const wrappedHandler = (auditMiddleware as any).middleware(handler)
      await wrappedHandler(mockRequest)
    })
  })

  describe('Security and Privacy', () => {
    test('should redact authorization headers', async () => {
      const mockRequest = new NextRequest('https://example.com/api/test', {
        headers: {
          'authorization': 'Bearer secret-token',
          'x-api-key': 'api-key-123',
          'cookie': 'session=secret-session'
        }
      }) as AuditableRequest

      await (auditMiddleware as any).trackApiRequest(mockRequest)

      const call = mockAuditService.logApiRequest.mock.calls[0][0]
      expect(call.headers.authorization).toBe('[REDACTED]')
      expect(call.headers['x-api-key']).toBe('[REDACTED]')
      expect(call.headers.cookie).toBe('[REDACTED]')
    })

    test('should handle custom sensitive fields', async () => {
      const middleware = new AuditMiddleware(mockPrismaClient, {
        sensitiveFields: ['customSecret', 'privateData', 'confidential']
      })

      const requestBody = {
        publicData: 'visible',
        customSecret: 'should-be-hidden',
        privateData: 'should-be-hidden',
        confidential: 'should-be-hidden',
        normalField: 'visible'
      }

      const sanitized = (middleware as any).sanitizeBody(requestBody)

      expect(sanitized).toEqual({
        publicData: 'visible',
        customSecret: '[REDACTED]',
        privateData: '[REDACTED]',
        confidential: '[REDACTED]',
        normalField: 'visible'
      })
    })

    test('should handle nested sensitive data', async () => {
      const requestBody = {
        user: {
          name: 'John',
          password: 'secret123',
          profile: {
            email: 'john@example.com',
            secret: 'nested-secret'
          }
        },
        settings: {
          apiKey: 'api-key-456'
        }
      }

      const sanitized = (auditMiddleware as any).sanitizeBody(requestBody)

      expect(sanitized).toEqual({
        user: {
          name: 'John',
          password: '[REDACTED]',
          profile: {
            email: 'john@example.com',
            secret: '[REDACTED]'
          }
        },
        settings: {
          apiKey: '[REDACTED]'
        }
      })
    })
  })

  describe('Configuration Edge Cases', () => {
    test('should handle empty configuration', () => {
      const middleware = new AuditMiddleware(mockPrismaClient, {})
      expect(middleware).toBeInstanceOf(AuditMiddleware)
    })

    test('should handle null/undefined configuration', () => {
      const middleware1 = new AuditMiddleware(mockPrismaClient, null as any)
      const middleware2 = new AuditMiddleware(mockPrismaClient, undefined)
      
      expect(middleware1).toBeInstanceOf(AuditMiddleware)
      expect(middleware2).toBeInstanceOf(AuditMiddleware)
    })

    test('should handle extreme configuration values', () => {
      const middleware = new AuditMiddleware(mockPrismaClient, {
        maxBodySize: 0,
        excludeRoutes: [],
        sensitiveFields: []
      })

      expect(middleware).toBeInstanceOf(AuditMiddleware)
    })
  })

  describe('Memory and Performance', () => {
    test('should handle rapid sequential requests', async () => {
      const requests = Array.from({ length: 100 }, (_, i) => 
        new NextRequest(`https://example.com/api/test-${i}`, { method: 'GET' })
      )

      const handler = async () => new NextResponse('OK', { status: 200 })
      const wrappedHandler = (auditMiddleware as any).middleware(handler)

      const promises = requests.map(req => wrappedHandler(req))
      const responses = await Promise.all(promises)

      expect(responses).toHaveLength(100)
      responses.forEach(response => {
        expect(response.status).toBe(200)
      })

      // Verify all requests were tracked
      expect(mockAuditService.logApiRequest).toHaveBeenCalledTimes(100)
    })

    test('should handle concurrent requests safely', async () => {
      const concurrentRequests = 50
      const requests = Array.from({ length: concurrentRequests }, (_, i) => 
        new NextRequest(`https://example.com/api/concurrent-${i}`)
      )

      const handler = async () => {
        // Simulate some async work
        await new Promise(resolve => setTimeout(resolve, Math.random() * 10))
        return new NextResponse('OK', { status: 200 })
      }

      const wrappedHandler = (auditMiddleware as any).middleware(handler)
      
      const startTime = Date.now()
      const promises = requests.map(req => wrappedHandler(req))
      const responses = await Promise.all(promises)
      const endTime = Date.now()

      expect(responses).toHaveLength(concurrentRequests)
      expect(endTime - startTime).toBeLessThan(1000) // Should complete quickly due to concurrency

      // All requests should have been tracked
      expect(mockAuditService.logApiRequest).toHaveBeenCalledTimes(concurrentRequests)
    })
  })
})