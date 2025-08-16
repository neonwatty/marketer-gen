/**
 * @jest-environment jsdom
 */

// Mock next-auth with factory function to avoid hoisting issues
jest.mock('next-auth/react', () => ({
  signIn: jest.fn(),
  signOut: jest.fn(),
  getSession: jest.fn(),
}))

import { authService } from '@/services/auth'
import { signIn, signOut, getSession } from 'next-auth/react'

// Get mocked functions
const mockSignIn = signIn as jest.MockedFunction<typeof signIn>
const mockSignOut = signOut as jest.MockedFunction<typeof signOut>
const mockGetSession = getSession as jest.MockedFunction<typeof getSession>

// Mock router
const mockPush = jest.fn()
const mockReplace = jest.fn()

jest.mock('next/navigation', () => ({
  useRouter: () => ({
    push: mockPush,
    replace: mockReplace,
  }),
}))

describe('AuthService', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('signIn', () => {
    it('should sign in with email and password', async () => {
      const credentials = {
        email: 'test@example.com',
        password: 'password123',
      }

      mockSignIn.mockResolvedValue({
        ok: true,
        status: 200,
        error: null,
        url: null,
      })

      const result = await authService.signIn(credentials)

      expect(mockSignIn).toHaveBeenCalledWith('credentials', {
        email: credentials.email,
        password: credentials.password,
        redirect: false,
      })
      expect(result.success).toBe(true)
    })

    it('should handle sign in errors', async () => {
      const credentials = {
        email: 'test@example.com',
        password: 'wrongpassword',
      }

      mockSignIn.mockResolvedValue({
        ok: false,
        status: 401,
        error: 'Invalid credentials',
        url: null,
      })

      const result = await authService.signIn(credentials)

      expect(result.success).toBe(false)
      expect(result.error).toBe('Invalid credentials')
    })

    it('should sign in with OAuth provider', async () => {
      mockSignIn.mockResolvedValue({
        ok: true,
        status: 200,
        error: null,
        url: 'http://localhost:3000/dashboard',
      })

      const result = await authService.signInWithProvider('google')

      expect(mockSignIn).toHaveBeenCalledWith('google', {
        callbackUrl: '/dashboard',
      })
      expect(result.success).toBe(true)
    })

    it('should handle OAuth provider errors', async () => {
      mockSignIn.mockResolvedValue({
        ok: false,
        status: 400,
        error: 'OAuth error',
        url: null,
      })

      const result = await authService.signInWithProvider('github')

      expect(result.success).toBe(false)
      expect(result.error).toBe('OAuth error')
    })
  })

  describe('signOut', () => {
    it('should sign out successfully', async () => {
      mockSignOut.mockResolvedValue({
        url: 'http://localhost:3000/',
      })

      const result = await authService.signOut()

      expect(mockSignOut).toHaveBeenCalledWith({
        callbackUrl: '/',
        redirect: false,
      })
      expect(result.success).toBe(true)
    })

    it('should handle sign out with redirect', async () => {
      mockSignOut.mockResolvedValue({
        url: 'http://localhost:3000/login',
      })

      const result = await authService.signOut('/login')

      expect(mockSignOut).toHaveBeenCalledWith({
        callbackUrl: '/login',
        redirect: false,
      })
      expect(result.success).toBe(true)
    })

    it('should handle sign out errors', async () => {
      mockSignOut.mockRejectedValue(new Error('Sign out failed'))

      const result = await authService.signOut()

      expect(result.success).toBe(false)
      expect(result.error).toBe('Sign out failed')
    })
  })

  describe('getSession', () => {
    it('should get current session', async () => {
      const mockSession = {
        user: {
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
          image: '/avatar.jpg',
        },
        expires: '2024-12-31T23:59:59.999Z',
      }

      mockGetSession.mockResolvedValue(mockSession)

      const session = await authService.getSession()

      expect(mockGetSession).toHaveBeenCalled()
      expect(session).toEqual(mockSession)
    })

    it('should return null when no session exists', async () => {
      mockGetSession.mockResolvedValue(null)

      const session = await authService.getSession()

      expect(session).toBeNull()
    })

    it('should handle session retrieval errors', async () => {
      mockGetSession.mockRejectedValue(new Error('Session error'))

      const session = await authService.getSession()

      expect(session).toBeNull()
    })
  })

  describe('isAuthenticated', () => {
    it('should return true when user is authenticated', async () => {
      mockGetSession.mockResolvedValue({
        user: { id: 'user-123' },
        expires: '2024-12-31T23:59:59.999Z',
      })

      const isAuth = await authService.isAuthenticated()

      expect(isAuth).toBe(true)
    })

    it('should return false when user is not authenticated', async () => {
      mockGetSession.mockResolvedValue(null)

      const isAuth = await authService.isAuthenticated()

      expect(isAuth).toBe(false)
    })
  })

  describe('getCurrentUser', () => {
    it('should return current user from session', async () => {
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        image: '/avatar.jpg',
      }

      mockGetSession.mockResolvedValue({
        user: mockUser,
        expires: '2024-12-31T23:59:59.999Z',
      })

      const user = await authService.getCurrentUser()

      expect(user).toEqual(mockUser)
    })

    it('should return null when no session exists', async () => {
      mockGetSession.mockResolvedValue(null)

      const user = await authService.getCurrentUser()

      expect(user).toBeNull()
    })
  })

  describe('session validation', () => {
    it('should validate active session', async () => {
      const futureDate = new Date(Date.now() + 60000).toISOString()
      mockGetSession.mockResolvedValue({
        user: { id: 'user-123' },
        expires: futureDate,
      })

      const isValid = await authService.isSessionValid()

      expect(isValid).toBe(true)
    })

    it('should invalidate expired session', async () => {
      const pastDate = new Date(Date.now() - 60000).toISOString()
      mockGetSession.mockResolvedValue({
        user: { id: 'user-123' },
        expires: pastDate,
      })

      const isValid = await authService.isSessionValid()

      expect(isValid).toBe(false)
    })

    it('should handle invalid session format', async () => {
      mockGetSession.mockResolvedValue({
        user: { id: 'user-123' },
        expires: 'invalid-date',
      })

      const isValid = await authService.isSessionValid()

      expect(isValid).toBe(false)
    })
  })

  describe('error handling', () => {
    it('should handle network errors during sign in', async () => {
      mockSignIn.mockRejectedValue(new Error('Network error'))

      const result = await authService.signIn({
        email: 'test@example.com',
        password: 'password',
      })

      expect(result.success).toBe(false)
      expect(result.error).toBe('Network error')
    })

    it('should handle malformed response data', async () => {
      mockSignIn.mockResolvedValue(null)

      const result = await authService.signIn({
        email: 'test@example.com',
        password: 'password',
      })

      expect(result.success).toBe(false)
      expect(result.error).toBe('Authentication failed')
    })
  })
})