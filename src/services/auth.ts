import { AUTH_CONFIG } from '@/lib/constants'

import { apiClient } from './api'

import type { User } from '@/lib/types'

/**
 * Authentication service for handling user authentication
 */
class AuthService {
  /**
   * Sign in user with email and password
   */
  async signIn(email: string, password: string): Promise<{ user: User; token: string }> {
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
  async signOut(): Promise<void> {
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
    const token = this.getToken()
    if (!token) return null

    const response = await apiClient.get<User>('/auth/me')
    return response.success && response.data ? response.data : null
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
  isAuthenticated(): boolean {
    return this.getToken() !== null
  }
}

export const authService = new AuthService()
