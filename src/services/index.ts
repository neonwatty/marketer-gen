/**
 * Service layer for API calls and external integrations
 * Export all services from this index file
 */

// Re-export API services
export { apiClient } from './api'
export { authService } from './auth'
export { userService } from './user'

// Re-export utility services
export { analyticsService } from './analytics'
export { notificationService } from './notification'
export { storageService } from './storage'
