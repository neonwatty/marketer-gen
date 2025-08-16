import { AUTH_CONFIG } from '@/lib/constants'
import { signIn as nextAuthSignIn, signOut as nextAuthSignOut, getSession as nextAuthGetSession } from 'next-auth/react'

import { apiClient } from './api'

import type { User } from '@/lib/types'

interface AuthResult {
  success: boolean
  error?: string
}

interface Session {
  user: User
  expires: string
}

/**
 * Authentication service for handling user authentication
 */
class AuthService {
  /**
   * Sign in user with email and password
   */
  async signIn(credentials: { email: string; password: string }): Promise<AuthResult> {
    try {
      const result = await nextAuthSignIn('credentials', {
        email: credentials.email,
        password: credentials.password,
        redirect: false,
      })

      if (!result) {
        return { success: false, error: 'Authentication failed' }
      }

      if (result.error) {
        return { success: false, error: result.error }
      }

      return { success: true }
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : 'Authentication failed' }
    }
  }

  /**
   * Sign in with OAuth provider
   */
  async signInWithProvider(provider: string): Promise<AuthResult> {
    try {
      const result = await nextAuthSignIn(provider, {
        callbackUrl: '/dashboard',
      })

      if (result?.error) {
        return { success: false, error: result.error }
      }

      return { success: true }
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : 'OAuth authentication failed' }
    }
  }

  /**
   * Legacy sign in method for backward compatibility
   */
  async legacySignIn(email: string, password: string): Promise<{ user: User; token: string }> {
    const response = await apiClient.post<{ user: User; token: string }>('/auth/signin', {
      email,
      password,
    })

    if (response.success && response.data) {
      this.setToken(response.data.token)
      return response.data
    }

    throw new Error(response.error || 'Sign in failed')
  }

  /**
   * Sign up new user
   */
  async signUp(userData: {
    email: string
    password: string
    name: string
  }): Promise<{ user: User; token: string }> {
    const response = await apiClient.post<{ user: User; token: string }>('/auth/signup', userData)

    if (response.success && response.data) {
      this.setToken(response.data.token)
      return response.data
    }

    throw new Error(response.error || 'Sign up failed')
  }

  /**
   * Sign out current user
   */
  async signOut(callbackUrl?: string): Promise<AuthResult> {
    try {
      await nextAuthSignOut({
        callbackUrl: callbackUrl || '/',
        redirect: false,
      })
      return { success: true }
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : 'Sign out failed' }
    }
  }

  /**
   * Get current session
   */
  async getSession(): Promise<Session | null> {
    try {
      const session = await nextAuthGetSession()
      return session as Session | null
    } catch (error) {
      console.error('Failed to get session:', error)
      return null
    }
  }

  /**
   * Legacy sign out method for backward compatibility
   */
  async legacySignOut(): Promise<void> {
    try {
      await apiClient.post('/auth/signout')
    } finally {
      this.clearToken()
    }
  }

  /**
   * Get current user
   */
  async getCurrentUser(): Promise<User | null> {
    const session = await this.getSession()
    return session?.user || null
  }

  /**
   * Refresh authentication token
   */
  async refreshToken(): Promise<string | null> {
    const refreshToken = this.getRefreshToken()
    if (!refreshToken) return null

    const response = await apiClient.post<{ token: string }>('/auth/refresh', {
      refreshToken,
    })

    if (response.success && response.data) {
      this.setToken(response.data.token)
      return response.data.token
    }

    return null
  }

  /**
   * Reset password
   */
  async resetPassword(email: string): Promise<void> {
    const response = await apiClient.post('/auth/reset-password', { email })

    if (!response.success) {
      throw new Error(response.error || 'Password reset failed')
    }
  }

  /**
   * Confirm password reset
   */
  async confirmPasswordReset(token: string, newPassword: string): Promise<void> {
    const response = await apiClient.post('/auth/confirm-reset', {
      token,
      password: newPassword,
    })

    if (!response.success) {
      throw new Error(response.error || 'Password reset confirmation failed')
    }
  }

  /**
   * Store authentication token
   */
  private setToken(token: string): void {
    if (typeof window !== 'undefined') {
      localStorage.setItem(AUTH_CONFIG.tokenKey, token)
      apiClient.setAuthToken(token)
    }
  }

  /**
   * Get stored authentication token
   */
  private getToken(): string | null {
    if (typeof window !== 'undefined') {
      return localStorage.getItem(AUTH_CONFIG.tokenKey)
    }
    return null
  }

  /**
   * Get stored refresh token
   */
  private getRefreshToken(): string | null {
    if (typeof window !== 'undefined') {
      return localStorage.getItem(AUTH_CONFIG.refreshTokenKey)
    }
    return null
  }

  /**
   * Clear stored tokens
   */
  private clearToken(): void {
    if (typeof window !== 'undefined') {
      localStorage.removeItem(AUTH_CONFIG.tokenKey)
      localStorage.removeItem(AUTH_CONFIG.refreshTokenKey)
      apiClient.clearAuthToken()
    }
  }

  /**
   * Check if user is authenticated
   */
  async isAuthenticated(): Promise<boolean> {
    const session = await this.getSession()
    return !!session
  }

  /**
   * Check if current session is valid
   */
  async isSessionValid(): Promise<boolean> {
    const session = await this.getSession()
    if (!session) return false

    try {
      const expiryDate = new Date(session.expires)
      return expiryDate.getTime() > Date.now()
    } catch (error) {
      return false
    }
  }

  /**
   * Check if user is authenticated (legacy sync method)
   */
  isAuthenticatedSync(): boolean {
    return this.getToken() !== null
  }
}

export const authService = new AuthService()
