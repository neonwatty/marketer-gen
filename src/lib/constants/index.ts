/**
 * Application constants and configuration values
 */

// Application metadata
export const APP_CONFIG = {
  name: 'Marketer Gen',
  description: 'Next.js marketing application with modern tooling',
  version: '1.0.0',
  author: 'Marketer Gen Team',
  url: process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000',
} as const

// API configuration
export const API_CONFIG = {
  baseUrl: process.env.NEXT_PUBLIC_API_URL || '/api',
  timeout: 10000,
  retryAttempts: 3,
} as const

// Database constants
export const DB_CONFIG = {
  maxConnections: 10,
  connectionTimeout: 30000,
  queryTimeout: 5000,
} as const

// Authentication constants
export const AUTH_CONFIG = {
  tokenKey: 'auth_token',
  refreshTokenKey: 'refresh_token',
  sessionDuration: 24 * 60 * 60 * 1000, // 24 hours in milliseconds
  refreshThreshold: 5 * 60 * 1000, // 5 minutes before expiry
} as const

// UI/UX constants
export const UI_CONFIG = {
  defaultPageSize: 20,
  maxPageSize: 100,
  debounceDelay: 300,
  animationDuration: 200,
  breakpoints: {
    sm: 640,
    md: 768,
    lg: 1024,
    xl: 1280,
    '2xl': 1536,
  },
} as const

// Form validation constants
export const VALIDATION = {
  email: {
    pattern: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
    message: 'Please enter a valid email address',
  },
  password: {
    minLength: 8,
    pattern: /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
    message: 'Password must be at least 8 characters with uppercase, lowercase, and number',
  },
  phone: {
    pattern: /^\+?[\d\s\-\(\)]+$/,
    message: 'Please enter a valid phone number',
  },
  url: {
    pattern: /^https?:\/\/.+/,
    message: 'Please enter a valid URL starting with http:// or https://',
  },
} as const

// Marketing-specific constants
export const MARKETING = {
  campaignStatuses: ['draft', 'active', 'paused', 'completed'] as const,
  adTypes: ['banner', 'video', 'text', 'native'] as const,
  targetingOptions: ['age', 'location', 'interests', 'behavior'] as const,
  budgetTypes: ['daily', 'lifetime'] as const,
  currencies: ['USD', 'EUR', 'GBP', 'CAD', 'AUD'] as const,
} as const

// File upload constants
export const FILE_UPLOAD = {
  maxSize: 10 * 1024 * 1024, // 10MB
  allowedTypes: {
    images: ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
    documents: ['application/pdf', 'text/plain', 'application/msword'],
    videos: ['video/mp4', 'video/webm', 'video/quicktime'],
  },
  maxFiles: 5,
} as const

// Date and time constants
export const DATE_FORMATS = {
  display: 'MMM dd, yyyy',
  input: 'yyyy-MM-dd',
  time: 'HH:mm',
  datetime: 'MMM dd, yyyy HH:mm',
  iso: "yyyy-MM-dd'T'HH:mm:ss.SSSxxx",
} as const

// Error messages
export const ERROR_MESSAGES = {
  generic: 'Something went wrong. Please try again.',
  network: 'Network error. Please check your connection.',
  unauthorized: 'You are not authorized to perform this action.',
  notFound: 'The requested resource was not found.',
  validation: 'Please check your input and try again.',
  fileUpload: 'Failed to upload file. Please try again.',
  timeout: 'Request timed out. Please try again.',
} as const

// Success messages
export const SUCCESS_MESSAGES = {
  saved: 'Changes saved successfully!',
  created: 'Item created successfully!',
  updated: 'Item updated successfully!',
  deleted: 'Item deleted successfully!',
  uploaded: 'File uploaded successfully!',
  copied: 'Copied to clipboard!',
} as const

// Local storage keys
export const STORAGE_KEYS = {
  theme: 'theme_preference',
  language: 'language_preference',
  sidebarCollapsed: 'sidebar_collapsed',
  userPreferences: 'user_preferences',
  recentSearches: 'recent_searches',
} as const

// Regular expressions
export const REGEX = {
  slug: /^[a-z0-9]+(?:-[a-z0-9]+)*$/,
  hexColor: /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/,
  username: /^[a-zA-Z0-9_]{3,20}$/,
  numeric: /^\d+$/,
  alphanumeric: /^[a-zA-Z0-9]+$/,
} as const
