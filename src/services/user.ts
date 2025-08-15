import { apiClient } from './api'

import type { User } from '@/lib/types'

/**
 * User service for managing user-related operations
 */
class UserService {
  /**
   * Get user by ID
   */
  async getUserById(userId: string): Promise<User | null> {
    const response = await apiClient.get<User>(`/users/${userId}`)
    return response.success && response.data ? response.data : null
  }

  /**
   * Update user profile
   */
  async updateProfile(userId: string, updates: Partial<User>): Promise<User> {
    const response = await apiClient.patch<User>(`/users/${userId}`, updates)

    if (response.success && response.data) {
      return response.data
    }

    throw new Error(response.error || 'Failed to update profile')
  }

  /**
   * Upload user avatar
   */
  async uploadAvatar(userId: string, file: File): Promise<string> {
    const formData = new FormData()
    formData.append('avatar', file)

    const response = await apiClient.post<{ url: string }>(`/users/${userId}/avatar`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    })

    if (response.success && response.data) {
      return response.data.url
    }

    throw new Error(response.error || 'Failed to upload avatar')
  }

  /**
   * Delete user account
   */
  async deleteAccount(userId: string): Promise<void> {
    const response = await apiClient.delete(`/users/${userId}`)

    if (!response.success) {
      throw new Error(response.error || 'Failed to delete account')
    }
  }

  /**
   * Change user password
   */
  async changePassword(
    userId: string,
    currentPassword: string,
    newPassword: string
  ): Promise<void> {
    const response = await apiClient.post(`/users/${userId}/change-password`, {
      currentPassword,
      newPassword,
    })

    if (!response.success) {
      throw new Error(response.error || 'Failed to change password')
    }
  }

  /**
   * Get user preferences
   */
  async getPreferences(userId: string): Promise<Record<string, any>> {
    const response = await apiClient.get<Record<string, any>>(`/users/${userId}/preferences`)
    return response.success ? response.data || {} : {}
  }

  /**
   * Update user preferences
   */
  async updatePreferences(
    userId: string,
    preferences: Record<string, any>
  ): Promise<Record<string, any>> {
    const response = await apiClient.patch<Record<string, any>>(
      `/users/${userId}/preferences`,
      preferences
    )

    if (response.success && response.data) {
      return response.data
    }

    throw new Error(response.error || 'Failed to update preferences')
  }

  /**
   * Search users
   */
  async searchUsers(query: string, limit: number = 10): Promise<User[]> {
    const response = await apiClient.get<User[]>(
      `/users/search?q=${encodeURIComponent(query)}&limit=${limit}`
    )

    return response.success ? response.data || [] : []
  }

  /**
   * Get user activity log
   */
  async getActivityLog(
    userId: string,
    page: number = 1,
    limit: number = 20
  ): Promise<{
    activities: Array<{
      id: string
      action: string
      timestamp: string
      metadata: Record<string, any>
    }>
    pagination: {
      page: number
      limit: number
      total: number
      totalPages: number
    }
  }> {
    const response = await apiClient.get<{
      activities: Array<{
        id: string
        action: string
        timestamp: string
        metadata: Record<string, any>
      }>
      pagination: {
        page: number
        limit: number
        total: number
        totalPages: number
      }
    }>(`/users/${userId}/activity?page=${page}&limit=${limit}`)

    return response.success && response.data
      ? response.data
      : { activities: [], pagination: { page, limit, total: 0, totalPages: 0 } }
  }

  /**
   * Verify user email
   */
  async verifyEmail(token: string): Promise<void> {
    const response = await apiClient.post('/users/verify-email', { token })

    if (!response.success) {
      throw new Error(response.error || 'Email verification failed')
    }
  }

  /**
   * Resend email verification
   */
  async resendEmailVerification(email: string): Promise<void> {
    const response = await apiClient.post('/users/resend-verification', { email })

    if (!response.success) {
      throw new Error(response.error || 'Failed to resend verification email')
    }
  }
}

export const userService = new UserService()
