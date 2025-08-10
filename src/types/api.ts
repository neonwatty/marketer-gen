import type { NextApiRequest, NextApiResponse } from "next"
import type { ApiResponse, PaginatedResponse } from "./index"

// Extended API Request with typed body
export interface TypedApiRequest<T = unknown> extends NextApiRequest {
  body: T
}

// API Route Handler Types
export type ApiHandler<T = unknown> = (
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse<T>>
) => Promise<void> | void

export type PaginatedApiHandler<T = unknown> = (
  req: NextApiRequest,
  res: NextApiResponse<PaginatedResponse<T>>
) => Promise<void> | void

// HTTP Method Types
export type HttpMethod = "GET" | "POST" | "PUT" | "PATCH" | "DELETE"

// Query Parameter Types
export interface PaginationQuery {
  page?: string
  limit?: string
  sort?: string
  order?: "asc" | "desc"
}

export interface SearchQuery extends PaginationQuery {
  q?: string
  filter?: string
  tags?: string
}

// API Endpoint Configurations
export interface ApiEndpoint {
  method: HttpMethod
  path: string
  handler: ApiHandler
  protected?: boolean
  rateLimit?: number
}

// Request/Response Types for specific endpoints

// Campaigns API
export interface CreateCampaignRequest {
  name: string
  description?: string
  type: string
  startDate?: string
  endDate?: string
  budget?: number
  tags?: string[]
}

export interface UpdateCampaignRequest extends Partial<CreateCampaignRequest> {
  status?: string
}

// Content Generation API
export interface GenerateContentRequest {
  prompt: string
  type: string
  tone: string
  length: string
  context?: string
}

// Assets API
export interface CreateAssetRequest {
  name: string
  type: string
  content?: string
  campaignId?: string
  tags?: string[]
}

export interface UploadAssetRequest {
  file: File
  name?: string
  campaignId?: string
  tags?: string[]
}

// Authentication API
export interface LoginRequest {
  email: string
  password: string
}

export interface RegisterRequest extends LoginRequest {
  name: string
}

export interface AuthResponse {
  user: {
    id: string
    email: string
    name: string
    role: string
  }
  token: string
  refreshToken?: string
}

// Analytics API
export interface AnalyticsQuery {
  startDate: string
  endDate: string
  metric?: string
  groupBy?: "day" | "week" | "month"
  campaignId?: string
}

export interface AnalyticsResponse {
  metrics: Record<string, number>
  timeSeries: Array<{
    date: string
    value: number
  }>
}

// Error Response Types
export interface ApiErrorResponse {
  error: string
  message: string
  code?: string
  details?: Record<string, unknown>
  timestamp: string
}

// Webhook Types
export interface WebhookPayload {
  event: string
  data: Record<string, unknown>
  timestamp: string
  signature?: string
}

// Rate Limiting Types
export interface RateLimitInfo {
  limit: number
  remaining: number
  reset: number
}

export interface RateLimitResponse extends ApiErrorResponse {
  rateLimit: RateLimitInfo
}