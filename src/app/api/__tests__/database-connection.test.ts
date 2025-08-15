/**
 * @jest-environment node
 */
import { PrismaClient } from '@prisma/client'

import { GET } from '../health/route'

// Mock Prisma
jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    $connect: jest.fn(),
    $disconnect: jest.fn(),
  })),
}))

const MockedPrismaClient = PrismaClient as jest.MockedClass<typeof PrismaClient>

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
    const mockPrisma = {
      $connect: jest.fn().mockResolvedValue(undefined),
      $disconnect: jest.fn().mockResolvedValue(undefined),
    }
    MockedPrismaClient.mockImplementation(() => mockPrisma)

    const response = await GET()
    const data = await response.json()

    expect(response.status).toBe(200)
    expect(data).toEqual({ status: 'connected' })
    expect(mockPrisma.$connect).toHaveBeenCalled()
    expect(mockPrisma.$disconnect).toHaveBeenCalled()
  })

  it('should handle database connection failures', async () => {
    const mockPrisma = {
      $connect: jest.fn().mockRejectedValue(new Error('Connection failed')),
      $disconnect: jest.fn().mockResolvedValue(undefined),
    }
    MockedPrismaClient.mockImplementation(() => mockPrisma)

    const response = await GET()
    const data = await response.json()

    expect(response.status).toBe(500)
    expect(data).toEqual({ error: 'Connection failed' })
  })

  it('should always disconnect from database', async () => {
    const mockPrisma = {
      $connect: jest.fn().mockRejectedValue(new Error('Connection failed')),
      $disconnect: jest.fn().mockResolvedValue(undefined),
    }
    MockedPrismaClient.mockImplementation(() => mockPrisma)

    await GET()

    expect(mockPrisma.$disconnect).toHaveBeenCalled()
  })

  it('should handle disconnection errors gracefully', async () => {
    const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {})
    const mockPrisma = {
      $connect: jest.fn().mockResolvedValue(undefined),
      $disconnect: jest.fn().mockRejectedValue(new Error('Disconnection failed')),
    }
    MockedPrismaClient.mockImplementation(() => mockPrisma)

    // Should not throw even if disconnection fails
    const response = await GET()
    const data = await response.json()

    expect(response.status).toBe(200)
    expect(data).toEqual({ status: 'connected' })
    
    consoleSpy.mockRestore()
  })
})