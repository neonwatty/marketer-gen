import { API_CONFIG } from '@/lib/constants'

import type { ApiResponse } from '@/lib/types'

/**
 * API client configuration and utilities
 */

export interface RequestConfig extends RequestInit {
  timeout?: number
  retry?: number
}

class ApiClient {
  private baseUrl: string
  private defaultTimeout: number

  constructor(baseUrl: string = API_CONFIG.baseUrl, timeout: number = API_CONFIG.timeout) {
    this.baseUrl = baseUrl
    this.defaultTimeout = timeout
  }

  /**
   * Make an HTTP request with timeout and retry logic
   */
  private async request<T>(endpoint: string, config: RequestConfig = {}): Promise<ApiResponse<T>> {
    const {
      timeout = this.defaultTimeout,
      retry = API_CONFIG.retryAttempts,
      ...fetchConfig
    } = config

    const url = `${this.baseUrl}${endpoint}`

    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), timeout)

    const requestConfig: RequestInit = {
      ...fetchConfig,
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        ...fetchConfig.headers,
      },
    }

    try {
      const response = await fetch(url, requestConfig)
      clearTimeout(timeoutId)

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const data = await response.json()
      return {
        success: true,
        data,
      }
    } catch (error) {
      clearTimeout(timeoutId)

      if (retry > 0 && error instanceof Error && error.name !== 'AbortError') {
        // Retry with exponential backoff
        await new Promise(resolve =>
          setTimeout(resolve, 1000 * (API_CONFIG.retryAttempts - retry + 1))
        )
        return this.request<T>(endpoint, { ...config, retry: retry - 1 })
      }

      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error occurred',
      }
    }
  }

  /**
   * GET request
   */
  async get<T>(endpoint: string, config?: RequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, { ...config, method: 'GET' })
  }

  /**
   * POST request
   */
  async post<T>(endpoint: string, data?: any, config?: RequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      ...config,
      method: 'POST',
      body: data ? JSON.stringify(data) : undefined,
    })
  }

  /**
   * PUT request
   */
  async put<T>(endpoint: string, data?: any, config?: RequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      ...config,
      method: 'PUT',
      body: data ? JSON.stringify(data) : undefined,
    })
  }

  /**
   * PATCH request
   */
  async patch<T>(endpoint: string, data?: any, config?: RequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      ...config,
      method: 'PATCH',
      body: data ? JSON.stringify(data) : undefined,
    })
  }

  /**
   * DELETE request
   */
  async delete<T>(endpoint: string, config?: RequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, { ...config, method: 'DELETE' })
  }

  /**
   * Set authorization header for authenticated requests
   */
  setAuthToken(token: string): void {
    this.defaultHeaders = {
      ...this.defaultHeaders,
      Authorization: `Bearer ${token}`,
    }
  }

  /**
   * Remove authorization header
   */
  clearAuthToken(): void {
    const { Authorization: _auth, ...headers } = this.defaultHeaders
    this.defaultHeaders = headers
  }

  private defaultHeaders: Record<string, string> = {}
}

// Export singleton instance
export const apiClient = new ApiClient()
