// Setup for Prisma tests
import { jest } from '@jest/globals'

// Mock Prisma Client globally for tests
jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    $connect: jest.fn().mockResolvedValue(undefined),
    $disconnect: jest.fn().mockResolvedValue(undefined),
    $queryRaw: jest.fn(),
    $executeRaw: jest.fn(),
    $transaction: jest.fn(),
  })),
  PrismaClientKnownRequestError: class extends Error {
    constructor(message, meta) {
      super(message)
      this.name = 'PrismaClientKnownRequestError'
      this.code = meta?.code || 'P2000'
      this.clientVersion = meta?.clientVersion || '4.0.0'
    }
  },
}))

// Set test environment variables
process.env.NODE_ENV = 'test'
process.env.DATABASE_URL = 'file:./test.db'

// Global test setup
beforeEach(() => {
  jest.clearAllMocks()
})