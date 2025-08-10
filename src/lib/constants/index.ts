// Application Constants
export const APP_NAME = "Marketer Gen" as const
export const APP_DESCRIPTION = "AI-powered marketing content generator" as const
export const APP_VERSION = "1.0.0" as const

// API Configuration
export const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "/api"
export const API_TIMEOUT = 30000 // 30 seconds

// Pagination
export const DEFAULT_PAGE_SIZE = 20
export const MAX_PAGE_SIZE = 100

// Rate Limiting
export const RATE_LIMIT_WINDOW = 15 * 60 * 1000 // 15 minutes
export const RATE_LIMIT_MAX_REQUESTS = 100

// Content Generation
export const CONTENT_TYPES = {
  COPY: "copy",
  SUBJECT_LINE: "subject_line", 
  HEADLINE: "headline",
  DESCRIPTION: "description",
  SOCIAL_POST: "social_post",
  AD_COPY: "ad_copy"
} as const

export const CONTENT_TONES = {
  PROFESSIONAL: "professional",
  CASUAL: "casual",
  FRIENDLY: "friendly",
  URGENT: "urgent",
  CREATIVE: "creative",
  HUMOROUS: "humorous"
} as const

export const CONTENT_LENGTHS = {
  SHORT: "short", // 1-2 sentences
  MEDIUM: "medium", // 2-4 sentences
  LONG: "long" // 4+ sentences
} as const

// Campaign Status
export const CAMPAIGN_STATUS = {
  DRAFT: "draft",
  ACTIVE: "active",
  PAUSED: "paused",
  COMPLETED: "completed",
  ARCHIVED: "archived"
} as const

export const CAMPAIGN_TYPES = {
  EMAIL: "email",
  SOCIAL: "social",
  WEB: "web",
  PRINT: "print",
  VIDEO: "video",
  MIXED: "mixed"
} as const

// Asset Types
export const ASSET_TYPES = {
  TEXT: "text",
  IMAGE: "image", 
  VIDEO: "video",
  AUDIO: "audio",
  TEMPLATE: "template",
  OTHER: "other"
} as const

// File Upload
export const MAX_FILE_SIZE = 50 * 1024 * 1024 // 50MB
export const ALLOWED_IMAGE_TYPES = [
  "image/jpeg",
  "image/png",
  "image/gif",
  "image/webp",
  "image/svg+xml"
]
export const ALLOWED_VIDEO_TYPES = [
  "video/mp4",
  "video/webm",
  "video/quicktime"
]
export const ALLOWED_AUDIO_TYPES = [
  "audio/mpeg",
  "audio/wav",
  "audio/ogg"
]

// User Roles
export const USER_ROLES = {
  ADMIN: "admin",
  USER: "user", 
  VIEWER: "viewer"
} as const

// Theme
export const THEMES = {
  LIGHT: "light",
  DARK: "dark",
  AUTO: "auto"
} as const

// Local Storage Keys
export const STORAGE_KEYS = {
  THEME: "marketer-gen-theme",
  USER: "marketer-gen-user",
  PREFERENCES: "marketer-gen-preferences",
  DRAFTS: "marketer-gen-drafts"
} as const

// Error Codes
export const ERROR_CODES = {
  UNAUTHORIZED: "UNAUTHORIZED",
  FORBIDDEN: "FORBIDDEN",
  NOT_FOUND: "NOT_FOUND",
  VALIDATION_ERROR: "VALIDATION_ERROR",
  RATE_LIMITED: "RATE_LIMITED",
  INTERNAL_ERROR: "INTERNAL_ERROR",
  SERVICE_UNAVAILABLE: "SERVICE_UNAVAILABLE"
} as const

// HTTP Status Codes
export const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  NO_CONTENT: 204,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  METHOD_NOT_ALLOWED: 405,
  CONFLICT: 409,
  UNPROCESSABLE_ENTITY: 422,
  TOO_MANY_REQUESTS: 429,
  INTERNAL_SERVER_ERROR: 500,
  SERVICE_UNAVAILABLE: 503
} as const

// Validation Rules
export const VALIDATION_RULES = {
  PASSWORD_MIN_LENGTH: 8,
  NAME_MIN_LENGTH: 2,
  NAME_MAX_LENGTH: 50,
  EMAIL_REGEX: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
  SLUG_REGEX: /^[a-z0-9-]+$/,
  TAG_MAX_LENGTH: 30,
  CAMPAIGN_NAME_MAX_LENGTH: 100,
  ASSET_NAME_MAX_LENGTH: 100
} as const

// Feature Flags (default values)
export const DEFAULT_FEATURE_FLAGS = {
  aiContentGeneration: true,
  advancedAnalytics: false,
  teamCollaboration: false,
  customBranding: false
} as const

// Animation Durations (in ms)
export const ANIMATION_DURATION = {
  FAST: 150,
  NORMAL: 300,
  SLOW: 500
} as const

// Breakpoints (matches Tailwind CSS)
export const BREAKPOINTS = {
  SM: 640,
  MD: 768,
  LG: 1024,
  XL: 1280,
  "2XL": 1536
} as const