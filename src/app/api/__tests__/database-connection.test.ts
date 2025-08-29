/**
 * @jest-environment node
 */

import { GET } from '../health/route'

// Mock the database module
jest.mock('@/lib/database', () => ({
  checkDatabaseHealth: jest.fn(),
}))

// Mock the monitoring module
jest.mock('@/lib/api/monitoring', () => ({
  getSystemHealth: jest.fn().mockResolvedValue({
    status: 'healthy',
    timestamp: '2024-01-01T00:00:00.000Z',
    uptime: 100,
    memory: {
      used: 50,
      total: 100,
      percentage: 50,
    },
    api: {
      total: 10,
      lastHour: 5,
      averageResponseTime: 100,
      errorRate: 0,
      slowRequests: 0,
    },
    version: '1.0.0',
  }),
  checkPerformanceAlerts: jest.fn().mockReturnValue([]),
  withRequestMonitoring: jest.fn((handler) => handler),
}))

// Mock Next.js Response
global.Response = {
  json: jest.fn().mockImplementation((data, init) => {
    const response = {
      json: () => Promise.resolve(data),
      status: init?.status || 200,
      ok: (init?.status || 200) >= 200 && (init?.status || 200) < 300,
    }
    return response
  }),
} as any

describe('/api/health Database Connection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('should return success when database connection works', async () => {
    const { checkDatabaseHealth } = require('@/lib/database')
    checkDatabaseHealth.mockResolvedValue({
      status: 'healthy',
      latency: 50,
    })

    const response = await GET()
    const data = await response.json()

    expect(response.status).toBe(200)
    expect(data.status).toBe('healthy')
    expect(data.services.database.status).toBe('healthy')
    expect(data.services.database.latency).toBeDefined()
    expect(data.timestamp).toBeDefined()
  })

  it('should handle database connection failures', async () => {
    const { checkDatabaseHealth } = require('@/lib/database')
    checkDatabaseHealth.mockResolvedValue({
      status: 'unhealthy',
      latency: 1000,
      error: 'Connection failed',
    })

    const response = await GET()
    const data = await response.json()

    expect(response.status).toBe(503)
    expect(data.status).toBe('unhealthy')
    expect(data.services.database.status).toBe('unhealthy')
    expect(data.services.database.error).toBe('Connection failed')
  })

  it('should return system health metrics', async () => {
    const { checkDatabaseHealth } = require('@/lib/database')
    checkDatabaseHealth.mockResolvedValue({
      status: 'healthy',
      latency: 25,
    })

    const response = await GET()
    const data = await response.json()

    expect(data.services.api).toBeDefined()
    expect(data.services.api.uptime).toBeDefined()
    expect(data.services.api.memory).toBeDefined()
    expect(data.services.api.stats).toBeDefined()
    expect(data.version).toBeDefined()
  })

  it('should handle health check errors gracefully', async () => {
    const { checkDatabaseHealth } = require('@/lib/database')
    checkDatabaseHealth.mockRejectedValue(new Error('Database error'))

    const response = await GET()
    const data = await response.json()

    expect(response.status).toBe(503)
    expect(data.status).toBe('unhealthy')
    expect(data.error).toBe('Health check failed')
  })
})