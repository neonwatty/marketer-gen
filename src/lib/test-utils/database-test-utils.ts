import { PrismaClient } from '@prisma/client'

export const createMockPrismaClient = () => {
  return {
    $connect: jest.fn().mockResolvedValue(undefined),
    $disconnect: jest.fn().mockResolvedValue(undefined),
    $queryRaw: jest.fn(),
    $executeRaw: jest.fn(),
    $transaction: jest.fn(),
  } as unknown as jest.Mocked<PrismaClient>
}

export const setupTestDatabase = async () => {
  // Setup test database utilities
  const prisma = new PrismaClient({
    datasources: {
      db: {
        url: 'file:./test.db'
      }
    }
  })

  return prisma
}

export const cleanupTestDatabase = async (prisma: PrismaClient) => {
  // Cleanup test database
  try {
    await prisma.$disconnect()
  } catch (error) {
    console.warn('Error disconnecting from test database:', error)
  }
}

export const resetTestDatabase = async (prisma: PrismaClient) => {
  // This would typically truncate all tables or run migrations
  // For now, we'll just ensure connection is clean
  try {
    await prisma.$disconnect()
    await prisma.$connect()
  } catch (error) {
    console.warn('Error resetting test database:', error)
  }
}

// Mock database responses for common operations
export const mockDatabaseResponses = {
  user: {
    id: 1,
    email: 'test@example.com',
    name: 'Test User',
    createdAt: new Date('2023-01-01T00:00:00Z'),
    updatedAt: new Date('2023-01-01T00:00:00Z'),
  },
  users: [
    {
      id: 1,
      email: 'test1@example.com',
      name: 'Test User 1',
      createdAt: new Date('2023-01-01T00:00:00Z'),
      updatedAt: new Date('2023-01-01T00:00:00Z'),
    },
    {
      id: 2,
      email: 'test2@example.com',
      name: 'Test User 2',
      createdAt: new Date('2023-01-02T00:00:00Z'),
      updatedAt: new Date('2023-01-02T00:00:00Z'),
    },
  ],
}

// Test database configuration helpers
export const getTestDatabaseUrl = () => {
  return process.env.TEST_DATABASE_URL || 'file:./test.db'
}

export const isTestEnvironment = () => {
  return process.env.NODE_ENV === 'test'
}