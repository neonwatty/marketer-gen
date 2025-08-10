// Common base types
export type ID = string | number

export interface BaseEntity {
  id: ID
  createdAt: Date
  updatedAt: Date
}

// User and Authentication Types
export interface User extends BaseEntity {
  email: string
  name: string
  avatar?: string
  role: UserRole
  preferences: UserPreferences
}

export type UserRole = "admin" | "user" | "viewer"

export interface UserPreferences {
  theme: "light" | "dark" | "auto"
  notifications: boolean
  language: string
}

// Campaign Types
export interface Campaign extends BaseEntity {
  name: string
  description?: string
  status: CampaignStatus
  type: CampaignType
  startDate?: Date
  endDate?: Date
  budget?: number
  tags: string[]
  userId: ID
  assets: Asset[]
  journeys: Journey[]
}

export type CampaignStatus = "draft" | "active" | "paused" | "completed" | "archived"
export type CampaignType = "email" | "social" | "web" | "print" | "video" | "mixed"

// Content and Asset Types
export interface Asset extends BaseEntity {
  name: string
  type: AssetType
  url?: string
  content?: string
  metadata: AssetMetadata
  campaignId?: ID
  tags: string[]
}

export type AssetType = "text" | "image" | "video" | "audio" | "template" | "other"

export interface AssetMetadata {
  size?: number
  dimensions?: { width: number; height: number }
  duration?: number
  format?: string
  [key: string]: unknown
}

// Journey and Template Types
export interface Journey extends BaseEntity {
  name: string
  description?: string
  campaignId: ID
  steps: JourneyStep[]
  status: "draft" | "active" | "inactive"
}

export interface JourneyStep {
  id: ID
  name: string
  type: "email" | "wait" | "condition" | "action"
  config: Record<string, unknown>
  order: number
}

// AI and Content Generation Types
export interface ContentRequest {
  prompt: string
  type: "copy" | "subject_line" | "headline" | "description"
  tone: "professional" | "casual" | "friendly" | "urgent" | "creative"
  length: "short" | "medium" | "long"
  context?: string
}

export interface ContentResponse {
  content: string[]
  confidence: number
  metadata: {
    model: string
    timestamp: Date
    tokens: number
  }
}

// Form and UI Types
export interface FormState<T = Record<string, unknown>> {
  data: T
  errors: Record<string, string>
  isSubmitting: boolean
  isDirty: boolean
}

export interface SelectOption<T = string> {
  label: string
  value: T
  disabled?: boolean
}

// API Response Types
export interface ApiResponse<T = unknown> {
  data?: T
  error?: string
  message?: string
  success: boolean
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
  pagination: {
    page: number
    limit: number
    total: number
    totalPages: number
  }
}

// Error Types
export interface AppError {
  code: string
  message: string
  details?: Record<string, unknown>
}

// Feature Flag Types
export interface FeatureFlags {
  aiContentGeneration: boolean
  advancedAnalytics: boolean
  teamCollaboration: boolean
  customBranding: boolean
}