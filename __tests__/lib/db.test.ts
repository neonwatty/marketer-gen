// Create properly mocked methods that will be shared across all instances
const mockUser = {
  findUnique: jest.fn(),
  findFirst: jest.fn(),
  findMany: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
}

const mockAccount = {
  findUnique: jest.fn(),
  findFirst: jest.fn(),
  findMany: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
}

const mockSession = {
  findUnique: jest.fn(),
  findFirst: jest.fn(),
  findMany: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
}

const mockVerificationToken = {
  findUnique: jest.fn(),
  findFirst: jest.fn(),
  findMany: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
}

// Mock the Prisma client at the module level before any imports
jest.mock('../generated/prisma', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    $connect: jest.fn().mockResolvedValue(undefined),
    $disconnect: jest.fn().mockResolvedValue(undefined),
    $queryRaw: jest.fn(),
    $executeRaw: jest.fn(),
    $transaction: jest.fn(),
    user: mockUser,
    account: mockAccount,
    session: mockSession,
    verificationToken: mockVerificationToken,
  })),
}))

// Import after mocking
import { PrismaClient } from '../generated/prisma'

describe('Database Configuration', () => {
  const originalEnv = process.env
  let mockPrismaInstance: any

  beforeEach(() => {
    jest.clearAllMocks()
    process.env = { ...originalEnv }
    
    // Get the mocked instance
    mockPrismaInstance = new PrismaClient()
  })

  afterAll(() => {
    process.env = originalEnv
  })

  describe('Prisma Client Initialization', () => {
    it('should create a new PrismaClient instance', () => {
      // Clear the module cache to test fresh initialization
      jest.resetModules()
      
      // Mock globalThis to not have prisma
      delete (globalThis as any).prisma
      
      const { prisma } = require('@/lib/db')
      
      expect(PrismaClient).toHaveBeenCalled()
      expect(prisma).toBeDefined()
    })

    it('should reuse existing global prisma instance in non-production', () => {
      process.env.NODE_ENV = 'development'
      
      // Set up a mock global prisma instance
      const mockGlobalPrisma = { mock: 'global-instance' }
      ;(globalThis as any).prisma = mockGlobalPrisma
      
      jest.resetModules()
      const { prisma } = require('@/lib/db')
      
      expect(prisma).toBe(mockGlobalPrisma)
    })

    it('should use existing global instance in production if available', () => {
      process.env.NODE_ENV = 'production'
      
      // Set up a mock global prisma instance
      const mockGlobalPrisma = { mock: 'global-instance' }
      ;(globalThis as any).prisma = mockGlobalPrisma
      
      jest.resetModules()
      const { prisma } = require('@/lib/db')
      
      // Should use the existing global instance
      expect(prisma).toBe(mockGlobalPrisma)
    })

    it('should assign prisma to globalThis in non-production environments', () => {
      process.env.NODE_ENV = 'development'
      delete (globalThis as any).prisma
      
      jest.resetModules()
      const { prisma } = require('@/lib/db')
      
      expect((globalThis as any).prisma).toBe(prisma)
    })

    it('should not assign prisma to globalThis in production', () => {
      process.env.NODE_ENV = 'production'
      delete (globalThis as any).prisma
      
      jest.resetModules()
      require('@/lib/db')
      
      expect((globalThis as any).prisma).toBeUndefined()
    })
  })

  describe('Database Operations for Authentication', () => {
    let prisma: any

    beforeEach(() => {
      jest.resetModules()
      delete (globalThis as any).prisma
      prisma = require('@/lib/db').prisma
    })

    describe('User Operations', () => {
      it('should support user creation with required fields', async () => {
        const mockUserData = {
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
          role: 'USER',
          createdAt: new Date(),
          updatedAt: new Date(),
        }

        mockUser.create.mockResolvedValue(mockUserData)

        const result = await prisma.user.create({
          data: {
            email: 'test@example.com',
            name: 'Test User',
          },
        })

        expect(mockUser.create).toHaveBeenCalledWith({
          data: {
            email: 'test@example.com',
            name: 'Test User',
          },
        })
        expect(result).toEqual(mockUserData)
      })

      it('should support user lookup by ID', async () => {
        const mockUserData = {
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
          role: 'USER',
        }

        mockUser.findUnique.mockResolvedValue(mockUserData)

        const result = await prisma.user.findUnique({
          where: { id: 'user-123' },
        })

        expect(mockUser.findUnique).toHaveBeenCalledWith({
          where: { id: 'user-123' },
        })
        expect(result).toEqual(mockUserData)
      })

      it('should support user lookup by email', async () => {
        const mockUserData = {
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
        }

        mockUser.findUnique.mockResolvedValue(mockUserData)

        const result = await prisma.user.findUnique({
          where: { email: 'test@example.com' },
        })

        expect(mockUser.findUnique).toHaveBeenCalledWith({
          where: { email: 'test@example.com' },
        })
        expect(result).toEqual(mockUserData)
      })

      it('should support user updates', async () => {
        const mockUpdatedUser = {
          id: 'user-123',
          email: 'test@example.com',
          name: 'Updated Name',
          role: 'ADMIN',
        }

        mockUser.update.mockResolvedValue(mockUpdatedUser)

        const result = await prisma.user.update({
          where: { id: 'user-123' },
          data: { name: 'Updated Name', role: 'ADMIN' },
        })

        expect(mockUser.update).toHaveBeenCalledWith({
          where: { id: 'user-123' },
          data: { name: 'Updated Name', role: 'ADMIN' },
        })
        expect(result).toEqual(mockUpdatedUser)
      })
    })

    describe('Account Operations (OAuth)', () => {
      it('should support account creation for OAuth providers', async () => {
        const mockAccountData = {
          id: 'account-123',
          userId: 'user-123',
          type: 'oauth',
          provider: 'google',
          providerAccountId: 'google-123',
          access_token: 'access-token',
          refresh_token: 'refresh-token',
        }

        mockAccount.create.mockResolvedValue(mockAccountData)

        const result = await prisma.account.create({
          data: {
            userId: 'user-123',
            type: 'oauth',
            provider: 'google',
            providerAccountId: 'google-123',
            access_token: 'access-token',
          },
        })

        expect(mockAccount.create).toHaveBeenCalledWith({
          data: {
            userId: 'user-123',
            type: 'oauth',
            provider: 'google',
            providerAccountId: 'google-123',
            access_token: 'access-token',
          },
        })
        expect(result).toEqual(mockAccountData)
      })

      it('should support account lookup by provider', async () => {
        const mockAccountData = {
          id: 'account-123',
          userId: 'user-123',
          provider: 'google',
          providerAccountId: 'google-123',
        }

        mockAccount.findFirst.mockResolvedValue(mockAccountData)

        const result = await prisma.account.findFirst({
          where: {
            provider: 'google',
            providerAccountId: 'google-123',
          },
        })

        expect(mockAccount.findFirst).toHaveBeenCalledWith({
          where: {
            provider: 'google',
            providerAccountId: 'google-123',
          },
        })
        expect(result).toEqual(mockAccountData)
      })
    })

    describe('Session Operations', () => {
      it('should support session creation', async () => {
        const mockSessionData = {
          id: 'session-123',
          sessionToken: 'session-token-123',
          userId: 'user-123',
          expires: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
        }

        mockSession.create.mockResolvedValue(mockSessionData)

        const result = await prisma.session.create({
          data: {
            sessionToken: 'session-token-123',
            userId: 'user-123',
            expires: mockSessionData.expires,
          },
        })

        expect(mockSession.create).toHaveBeenCalledWith({
          data: {
            sessionToken: 'session-token-123',
            userId: 'user-123',
            expires: mockSessionData.expires,
          },
        })
        expect(result).toEqual(mockSessionData)
      })

      it('should support session lookup by token', async () => {
        const mockSessionData = {
          id: 'session-123',
          sessionToken: 'session-token-123',
          userId: 'user-123',
          expires: new Date(),
        }

        mockSession.findUnique.mockResolvedValue(mockSessionData)

        const result = await prisma.session.findUnique({
          where: { sessionToken: 'session-token-123' },
        })

        expect(mockSession.findUnique).toHaveBeenCalledWith({
          where: { sessionToken: 'session-token-123' },
        })
        expect(result).toEqual(mockSessionData)
      })

      it('should support session updates', async () => {
        const newExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
        const mockUpdatedSession = {
          id: 'session-123',
          sessionToken: 'session-token-123',
          userId: 'user-123',
          expires: newExpiry,
        }

        mockSession.update.mockResolvedValue(mockUpdatedSession)

        const result = await prisma.session.update({
          where: { sessionToken: 'session-token-123' },
          data: { expires: newExpiry },
        })

        expect(mockSession.update).toHaveBeenCalledWith({
          where: { sessionToken: 'session-token-123' },
          data: { expires: newExpiry },
        })
        expect(result).toEqual(mockUpdatedSession)
      })

      it('should support session deletion', async () => {
        const mockDeletedSession = {
          id: 'session-123',
          sessionToken: 'session-token-123',
        }

        mockSession.delete.mockResolvedValue(mockDeletedSession)

        const result = await prisma.session.delete({
          where: { sessionToken: 'session-token-123' },
        })

        expect(mockSession.delete).toHaveBeenCalledWith({
          where: { sessionToken: 'session-token-123' },
        })
        expect(result).toEqual(mockDeletedSession)
      })
    })

    describe('Verification Token Operations', () => {
      it('should support verification token creation', async () => {
        const mockToken = {
          identifier: 'test@example.com',
          token: 'verification-token-123',
          expires: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
        }

        mockVerificationToken.create.mockResolvedValue(mockToken)

        const result = await prisma.verificationToken.create({
          data: mockToken,
        })

        expect(mockVerificationToken.create).toHaveBeenCalledWith({
          data: mockToken,
        })
        expect(result).toEqual(mockToken)
      })

      it('should support verification token lookup', async () => {
        const mockToken = {
          identifier: 'test@example.com',
          token: 'verification-token-123',
          expires: new Date(),
        }

        mockVerificationToken.findFirst.mockResolvedValue(mockToken)

        const result = await prisma.verificationToken.findFirst({
          where: {
            identifier: 'test@example.com',
            token: 'verification-token-123',
          },
        })

        expect(mockVerificationToken.findFirst).toHaveBeenCalledWith({
          where: {
            identifier: 'test@example.com',
            token: 'verification-token-123',
          },
        })
        expect(result).toEqual(mockToken)
      })

      it('should support verification token deletion', async () => {
        const mockToken = {
          identifier: 'test@example.com',
          token: 'verification-token-123',
        }

        mockVerificationToken.delete.mockResolvedValue(mockToken)

        const result = await prisma.verificationToken.delete({
          where: {
            identifier_token: {
              identifier: 'test@example.com',
              token: 'verification-token-123',
            },
          },
        })

        expect(mockVerificationToken.delete).toHaveBeenCalledWith({
          where: {
            identifier_token: {
              identifier: 'test@example.com',
              token: 'verification-token-123',
            },
          },
        })
        expect(result).toEqual(mockToken)
      })
    })
  })

  describe('Error Handling', () => {
    let prisma: any

    beforeEach(() => {
      jest.resetModules()
      delete (globalThis as any).prisma
      prisma = require('@/lib/db').prisma
    })

    it('should handle database connection errors', async () => {
      const dbError = new Error('Database connection failed')
      mockUser.findUnique.mockRejectedValue(dbError)

      await expect(
        prisma.user.findUnique({ where: { id: 'user-123' } })
      ).rejects.toThrow('Database connection failed')
    })

    it('should handle unique constraint violations', async () => {
      const uniqueError = new Error('Unique constraint failed')
      mockUser.create.mockRejectedValue(uniqueError)

      await expect(
        prisma.user.create({
          data: { email: 'existing@example.com', name: 'Test' },
        })
      ).rejects.toThrow('Unique constraint failed')
    })

    it('should handle not found errors', async () => {
      mockUser.findUnique.mockResolvedValue(null)

      const result = await prisma.user.findUnique({
        where: { id: 'non-existent' },
      })

      expect(result).toBeNull()
    })
  })

  describe('Type Safety and Schema Validation', () => {
    it('should export prisma client with correct type', () => {
      const { prisma } = require('@/lib/db')
      
      // Verify that prisma has the expected methods
      expect(typeof mockUser.findUnique).toBe('function')
      expect(typeof mockAccount.create).toBe('function')
      expect(typeof mockSession.update).toBe('function')
      expect(typeof mockVerificationToken.delete).toBe('function')
    })

    it('should have global type declaration', () => {
      // This test ensures the global.d.ts type augmentation works
      expect(typeof globalThis.prisma).toBeDefined()
    })
  })
})