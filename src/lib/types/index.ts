/**
 * Global TypeScript type definitions for the Marketer Gen Next.js application
 */

// Common utility types
export type Nullable<T> = T | null
export type Optional<T> = T | undefined
export type ID = string | number

// API response types
export interface ApiResponse<T = any> {
  success: boolean
  data?: T
  error?: string
  message?: string
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
  pagination: {
    page: number
    limit: number
    total: number
    totalPages: number
  }
}

// Common component props
export interface BaseComponentProps {
  className?: string
  children?: React.ReactNode
}

// Form types
export interface FormField {
  id: string
  name: string
  type: 'text' | 'email' | 'password' | 'textarea' | 'select' | 'checkbox' | 'radio'
  label: string
  placeholder?: string
  required?: boolean
  validation?: {
    pattern?: string
    minLength?: number
    maxLength?: number
    min?: number
    max?: number
  }
}

export interface FormData {
  [key: string]: any
}

// User and authentication types
export interface User {
  id: ID
  email: string
  name: string
  avatar?: string
  role: 'admin' | 'user' | 'moderator'
  createdAt: string
  updatedAt: string
}

export interface AuthState {
  user: User | null
  isAuthenticated: boolean
  isLoading: boolean
  error: string | null
}

// Marketing-specific types (placeholder for future expansion)
export interface Campaign {
  id: ID
  name: string
  description: string
  status: 'draft' | 'active' | 'paused' | 'completed'
  budget: number
  startDate: string
  endDate: string
  metrics: {
    impressions: number
    clicks: number
    conversions: number
    cost: number
  }
}

export interface MarketingMetrics {
  totalCampaigns: number
  activeCampaigns: number
  totalSpend: number
  totalConversions: number
  averageCTR: number
  averageCPC: number
}

// Component-specific types
export interface NavigationItem {
  id: string
  label: string
  href: string
  icon?: React.ComponentType
  children?: NavigationItem[]
}

export interface TableColumn<T = any> {
  key: keyof T
  header: string
  sortable?: boolean
  render?: (value: any, row: T) => React.ReactNode
}

export interface SelectOption {
  value: string | number
  label: string
  disabled?: boolean
}

// Theme and styling types
export type ThemeMode = 'light' | 'dark' | 'system'

export interface ThemeConfig {
  mode: ThemeMode
  colors: {
    primary: string
    secondary: string
    accent: string
    background: string
    foreground: string
    muted: string
  }
}
