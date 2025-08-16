import { NextRequest } from 'next/server'

// Mock the problematic ESM modules first
jest.mock('@auth/prisma-adapter', () => ({
  PrismaAdapter: jest.fn(() => ({
    createUser: jest.fn(),
    getUser: jest.fn(),
    getUserByEmail: jest.fn(),
    getUserByAccount: jest.fn(),
    updateUser: jest.fn(),
    deleteUser: jest.fn(),
    linkAccount: jest.fn(),
    unlinkAccount: jest.fn(),
    createSession: jest.fn(),
    getSessionAndUser: jest.fn(),
    updateSession: jest.fn(),
    deleteSession: jest.fn(),
    createVerificationToken: jest.fn(),
    useVerificationToken: jest.fn(),
  })),
}))

jest.mock('next-auth/providers/google', () => 
  jest.fn(() => ({
    id: 'google',
    name: 'Google',
    type: 'oauth',
  }))
)

jest.mock('next-auth/providers/github', () => 
  jest.fn(() => ({
    id: 'github',
    name: 'GitHub',
    type: 'oauth',
  }))
)

jest.mock('next-auth', () => ({
  default: jest.fn(() => ({
    GET: jest.fn(),
    POST: jest.fn(),
  })),
}))

import { prisma } from '@/lib/db'
import { authOptions } from '@/lib/auth'

// Mock the Prisma client
jest.mock('@/lib/db', () => ({
  prisma: {
    user: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    account: {
      findFirst: jest.fn(),
      create: jest.fn(),
    },
    session: {
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    verificationToken: {
      findFirst: jest.fn(),
      delete: jest.fn(),
    },
  },
}))

// Mock NextAuth
jest.mock('next-auth', () => ({
  __esModule: true,
  default: jest.fn((options) => ({
    GET: jest.fn(),
    POST: jest.fn(),
    options,
  })),
}))

// Mock environment variables for testing
const originalEnv = process.env

describe('NextAuth Configuration', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    // Reset environment variables
    process.env = { ...originalEnv }
  })

  afterAll(() => {
    process.env = originalEnv
  })

  describe('Authentication Options', () => {
    it('should have correct basic configuration', () => {
      expect(authOptions.session.strategy).toBe('database')
      expect(authOptions.pages?.signIn).toBe('/auth/signin')
      expect(authOptions.debug).toBe(process.env.NODE_ENV === 'development')
    })

    it('should use PrismaAdapter', () => {
      expect(authOptions.adapter).toBeDefined()
      // The adapter should be configured with prisma instance
    })

    it('should have empty providers array when no environment variables set', () => {
      // Clear provider environment variables
      delete process.env.GOOGLE_CLIENT_ID
      delete process.env.GOOGLE_CLIENT_SECRET
      delete process.env.GITHUB_CLIENT_ID
      delete process.env.GITHUB_CLIENT_SECRET

      // Re-require the auth module to get fresh config
      jest.resetModules()
      const { authOptions: freshAuthOptions } = require('@/lib/auth')
      
      expect(freshAuthOptions.providers).toHaveLength(0)
    })

    it('should include Google provider when environment variables are set', () => {
      process.env.GOOGLE_CLIENT_ID = 'test-google-client-id'
      process.env.GOOGLE_CLIENT_SECRET = 'test-google-client-secret'

      // Re-require the auth module to get fresh config
      jest.resetModules()
      const { authOptions: freshAuthOptions } = require('@/lib/auth')
      
      expect(freshAuthOptions.providers).toHaveLength(1)
      expect(freshAuthOptions.providers[0].id).toBe('google')
    })

    it('should include GitHub provider when environment variables are set', () => {
      process.env.GITHUB_CLIENT_ID = 'test-github-client-id'
      process.env.GITHUB_CLIENT_SECRET = 'test-github-client-secret'

      // Re-require the auth module to get fresh config
      jest.resetModules()
      const { authOptions: freshAuthOptions } = require('@/lib/auth')
      
      expect(freshAuthOptions.providers).toHaveLength(1)
      expect(freshAuthOptions.providers[0].id).toBe('github')
    })

    it('should include both providers when both sets of environment variables are set', () => {
      process.env.GOOGLE_CLIENT_ID = 'test-google-client-id'
      process.env.GOOGLE_CLIENT_SECRET = 'test-google-client-secret'
      process.env.GITHUB_CLIENT_ID = 'test-github-client-id'
      process.env.GITHUB_CLIENT_SECRET = 'test-github-client-secret'

      // Re-require the auth module to get fresh config
      jest.resetModules()
      const { authOptions: freshAuthOptions } = require('@/lib/auth')
      
      expect(freshAuthOptions.providers).toHaveLength(2)
      const providerIds = freshAuthOptions.providers.map((p: any) => p.id)
      expect(providerIds).toContain('google')
      expect(providerIds).toContain('github')
    })
  })

  describe('Session Callback', () => {
    const mockPrismaUser = {
      id: 'user-123',
      role: 'USER',
      email: 'test@example.com',
      name: 'Test User',
    }

    beforeEach(() => {
      ;(prisma.user.findUnique as jest.Mock).mockResolvedValue(mockPrismaUser)
    })

    it('should add user ID to session', async () => {
      const mockSession = {
        user: {
          email: 'test@example.com',
          name: 'Test User',
        },
      }
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
      }

      const result = await authOptions.callbacks?.session?.({
        session: mockSession,
        user: mockUser,
        token: {},
      })

      expect(result?.user).toHaveProperty('id', 'user-123')
    })

    it('should add user role to session from database', async () => {
      const mockSession = {
        user: {
          email: 'test@example.com',
          name: 'Test User',
        },
      }
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
      }

      const result = await authOptions.callbacks?.session?.({
        session: mockSession,
        user: mockUser,
        token: {},
      })

      expect(prisma.user.findUnique).toHaveBeenCalledWith({
        where: { id: 'user-123' },
        select: { role: true },
      })
      expect(result?.user).toHaveProperty('role', 'USER')
    })

    it('should handle session without user gracefully', async () => {
      const mockSession = { user: undefined }
      const mockUser = undefined

      const result = await authOptions.callbacks?.session?.({
        session: mockSession,
        user: mockUser,
        token: {},
      })

      expect(result).toEqual(mockSession)
      expect(prisma.user.findUnique).not.toHaveBeenCalled()
    })

    it('should handle database user not found', async () => {
      ;(prisma.user.findUnique as jest.Mock).mockResolvedValue(null)

      const mockSession = {
        user: {
          email: 'test@example.com',
          name: 'Test User',
        },
      }
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
      }

      const result = await authOptions.callbacks?.session?.({
        session: mockSession,
        user: mockUser,
        token: {},
      })

      expect(result?.user).toHaveProperty('id', 'user-123')
      expect(result?.user).not.toHaveProperty('role')
    })
  })

  describe('JWT Callback', () => {
    it('should add role to token when user is provided', async () => {
      const mockUser = {
        id: 'user-123',
        role: 'ADMIN',
      }
      const mockToken = {
        sub: 'user-123',
      }

      const result = await authOptions.callbacks?.jwt?.({
        user: mockUser,
        token: mockToken,
        account: null,
        profile: undefined,
        isNewUser: false,
      })

      expect(result).toHaveProperty('role', 'ADMIN')
    })

    it('should preserve existing token when no user provided', async () => {
      const mockToken = {
        sub: 'user-123',
        role: 'USER',
      }

      const result = await authOptions.callbacks?.jwt?.({
        user: undefined,
        token: mockToken,
        account: null,
        profile: undefined,
        isNewUser: false,
      })

      expect(result).toEqual(mockToken)
    })
  })

  describe('Events', () => {
    it('should log user creation', async () => {
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation()
      
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
      }

      await authOptions.events?.createUser?.({ user: mockUser })

      expect(consoleSpy).toHaveBeenCalledWith('New user created: test@example.com')
      
      consoleSpy.mockRestore()
    })
  })

  describe('Security Configuration', () => {
    it('should be configured for database sessions', () => {
      expect(authOptions.session.strategy).toBe('database')
    })

    it('should have custom sign-in page configured', () => {
      expect(authOptions.pages?.signIn).toBe('/auth/signin')
    })

    it('should enable debug mode in development', () => {
      process.env.NODE_ENV = 'development'
      jest.resetModules()
      const { authOptions: devAuthOptions } = require('@/lib/auth')
      expect(devAuthOptions.debug).toBe(true)
    })

    it('should disable debug mode in production', () => {
      process.env.NODE_ENV = 'production'
      jest.resetModules()
      const { authOptions: prodAuthOptions } = require('@/lib/auth')
      expect(prodAuthOptions.debug).toBe(false)
    })
  })
})

describe('NextAuth API Route Handler', () => {
  it('should export GET and POST handlers', () => {
    const handler = require('@/app/api/auth/[...nextauth]/route')
    
    expect(handler.GET).toBeDefined()
    expect(handler.POST).toBeDefined()
  })

  it('should use the correct auth options', () => {
    jest.clearAllMocks()
    jest.resetModules()
    const NextAuth = require('next-auth').default
    require('@/app/api/auth/[...nextauth]/route')
    
    expect(NextAuth).toHaveBeenCalledWith(expect.any(Object))
  })
})

describe('Provider Configuration Edge Cases', () => {
  it('should handle partial Google environment variables', () => {
    process.env.GOOGLE_CLIENT_ID = 'test-id'
    delete process.env.GOOGLE_CLIENT_SECRET

    jest.resetModules()
    const { authOptions: freshAuthOptions } = require('@/lib/auth')
    
    expect(freshAuthOptions.providers).toHaveLength(0)
  })

  it('should handle partial GitHub environment variables', () => {
    process.env.GITHUB_CLIENT_ID = 'test-id'
    delete process.env.GITHUB_CLIENT_SECRET

    jest.resetModules()
    const { authOptions: freshAuthOptions } = require('@/lib/auth')
    
    expect(freshAuthOptions.providers).toHaveLength(0)
  })

  it('should handle empty string environment variables', () => {
    process.env.GOOGLE_CLIENT_ID = ''
    process.env.GOOGLE_CLIENT_SECRET = 'secret'

    jest.resetModules()
    const { authOptions: freshAuthOptions } = require('@/lib/auth')
    
    expect(freshAuthOptions.providers).toHaveLength(0)
  })
})