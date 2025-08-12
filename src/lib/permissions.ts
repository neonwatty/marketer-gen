export interface UserPermissions {
  canCreateContent: boolean
  canEditContent: boolean
  canDeleteContent: boolean
  canViewContent: boolean
  canSubmitForReview: boolean
  canApproveContent: boolean
  canRejectContent: boolean
  canPublishContent: boolean
  canArchiveContent: boolean
  canBulkApprove: boolean
  canViewAllContent: boolean
  canManageUsers: boolean
  canConfigureWorkflow: boolean
}

export type UserRole = 
  | 'viewer'
  | 'creator'
  | 'reviewer'
  | 'approver' 
  | 'publisher'
  | 'admin'

// Define role-based permissions
export const ROLE_PERMISSIONS: Record<UserRole, UserPermissions> = {
  viewer: {
    canCreateContent: false,
    canEditContent: false,
    canDeleteContent: false,
    canViewContent: true,
    canSubmitForReview: false,
    canApproveContent: false,
    canRejectContent: false,
    canPublishContent: false,
    canArchiveContent: false,
    canBulkApprove: false,
    canViewAllContent: false,
    canManageUsers: false,
    canConfigureWorkflow: false
  },
  creator: {
    canCreateContent: true,
    canEditContent: true,
    canDeleteContent: true,
    canViewContent: true,
    canSubmitForReview: true,
    canApproveContent: false,
    canRejectContent: false,
    canPublishContent: false,
    canArchiveContent: false,
    canBulkApprove: false,
    canViewAllContent: false,
    canManageUsers: false,
    canConfigureWorkflow: false
  },
  reviewer: {
    canCreateContent: true,
    canEditContent: true,
    canDeleteContent: true,
    canViewContent: true,
    canSubmitForReview: true,
    canApproveContent: false,
    canRejectContent: true, // Can provide feedback but not final approval
    canPublishContent: false,
    canArchiveContent: false,
    canBulkApprove: false,
    canViewAllContent: true,
    canManageUsers: false,
    canConfigureWorkflow: false
  },
  approver: {
    canCreateContent: true,
    canEditContent: true,
    canDeleteContent: true,
    canViewContent: true,
    canSubmitForReview: true,
    canApproveContent: true,
    canRejectContent: true,
    canPublishContent: false,
    canArchiveContent: true,
    canBulkApprove: true,
    canViewAllContent: true,
    canManageUsers: false,
    canConfigureWorkflow: false
  },
  publisher: {
    canCreateContent: true,
    canEditContent: true,
    canDeleteContent: true,
    canViewContent: true,
    canSubmitForReview: true,
    canApproveContent: true,
    canRejectContent: true,
    canPublishContent: true,
    canArchiveContent: true,
    canBulkApprove: true,
    canViewAllContent: true,
    canManageUsers: false,
    canConfigureWorkflow: false
  },
  admin: {
    canCreateContent: true,
    canEditContent: true,
    canDeleteContent: true,
    canViewContent: true,
    canSubmitForReview: true,
    canApproveContent: true,
    canRejectContent: true,
    canPublishContent: true,
    canArchiveContent: true,
    canBulkApprove: true,
    canViewAllContent: true,
    canManageUsers: true,
    canConfigureWorkflow: true
  }
}

// Permission checker class
export class PermissionChecker {
  private userRole: UserRole
  private customPermissions?: Partial<UserPermissions>

  constructor(userRole: UserRole, customPermissions?: Partial<UserPermissions>) {
    this.userRole = userRole
    this.customPermissions = customPermissions
  }

  // Get effective permissions for the user
  getPermissions(): UserPermissions {
    const basePermissions = ROLE_PERMISSIONS[this.userRole]
    
    if (this.customPermissions) {
      return { ...basePermissions, ...this.customPermissions }
    }
    
    return basePermissions
  }

  // Check if user has a specific permission
  hasPermission(permission: keyof UserPermissions): boolean {
    const permissions = this.getPermissions()
    return permissions[permission]
  }

  // Check if user can perform an action on content
  canPerformAction(action: string): boolean {
    switch (action) {
      case 'create':
        return this.hasPermission('canCreateContent')
      case 'edit':
        return this.hasPermission('canEditContent')
      case 'delete':
        return this.hasPermission('canDeleteContent')
      case 'view':
        return this.hasPermission('canViewContent')
      case 'submit_for_review':
        return this.hasPermission('canSubmitForReview')
      case 'approve':
        return this.hasPermission('canApproveContent')
      case 'reject':
      case 'request_revision':
        return this.hasPermission('canRejectContent')
      case 'publish':
        return this.hasPermission('canPublishContent')
      case 'archive':
        return this.hasPermission('canArchiveContent')
      case 'bulk_approve':
        return this.hasPermission('canBulkApprove')
      case 'view_all':
        return this.hasPermission('canViewAllContent')
      case 'manage_users':
        return this.hasPermission('canManageUsers')
      case 'configure_workflow':
        return this.hasPermission('canConfigureWorkflow')
      default:
        return false
    }
  }

  // Get user's role level (higher number = more permissions)
  getRoleLevel(): number {
    const roleLevels = {
      viewer: 1,
      creator: 2,
      reviewer: 3,
      approver: 4,
      publisher: 5,
      admin: 6
    }
    return roleLevels[this.userRole]
  }

  // Check if user has higher or equal role than required
  hasMinimumRole(requiredRole: UserRole): boolean {
    const roleLevels = {
      viewer: 1,
      creator: 2,
      reviewer: 3,
      approver: 4,
      publisher: 5,
      admin: 6
    }
    return roleLevels[this.userRole] >= roleLevels[requiredRole]
  }

  // Get list of actions user can perform
  getAvailableActions(): string[] {
    const permissions = this.getPermissions()
    const actions: string[] = []

    if (permissions.canCreateContent) actions.push('create')
    if (permissions.canEditContent) actions.push('edit')
    if (permissions.canDeleteContent) actions.push('delete')
    if (permissions.canViewContent) actions.push('view')
    if (permissions.canSubmitForReview) actions.push('submit_for_review')
    if (permissions.canApproveContent) actions.push('approve')
    if (permissions.canRejectContent) actions.push('reject', 'request_revision')
    if (permissions.canPublishContent) actions.push('publish')
    if (permissions.canArchiveContent) actions.push('archive')
    if (permissions.canBulkApprove) actions.push('bulk_approve')
    if (permissions.canViewAllContent) actions.push('view_all')
    if (permissions.canManageUsers) actions.push('manage_users')
    if (permissions.canConfigureWorkflow) actions.push('configure_workflow')

    return actions
  }
}

// Utility functions
export function getUserPermissions(userRole: UserRole, customPermissions?: Partial<UserPermissions>): UserPermissions {
  const checker = new PermissionChecker(userRole, customPermissions)
  return checker.getPermissions()
}

export function canUserPerformAction(userRole: UserRole, action: string): boolean {
  const checker = new PermissionChecker(userRole)
  return checker.canPerformAction(action)
}

export function hasMinimumRole(userRole: UserRole, requiredRole: UserRole): boolean {
  const checker = new PermissionChecker(userRole)
  return checker.hasMinimumRole(requiredRole)
}

export function filterContentByPermissions<T extends { userId?: string }>(
  content: T[],
  userRole: UserRole,
  userId?: string
): T[] {
  const permissions = getUserPermissions(userRole)
  
  if (permissions.canViewAllContent) {
    return content
  }
  
  // If user can only view their own content
  if (userId) {
    return content.filter(item => item.userId === userId)
  }
  
  // If no user ID provided and can't view all, return empty array
  return []
}

// Role hierarchy for UI display
export const ROLE_HIERARCHY: { role: UserRole; label: string; description: string }[] = [
  {
    role: 'viewer',
    label: 'Viewer',
    description: 'Can only view content'
  },
  {
    role: 'creator',
    label: 'Creator',
    description: 'Can create and edit their own content'
  },
  {
    role: 'reviewer',
    label: 'Reviewer',
    description: 'Can review and provide feedback on content'
  },
  {
    role: 'approver',
    label: 'Approver',
    description: 'Can approve or reject content for publication'
  },
  {
    role: 'publisher',
    label: 'Publisher',
    description: 'Can publish approved content'
  },
  {
    role: 'admin',
    label: 'Administrator',
    description: 'Full access to all features and content'
  }
]

// Default role assignment based on user context
export function getDefaultUserRole(context?: { isOwner?: boolean; isTeamLead?: boolean }): UserRole {
  if (context?.isOwner) return 'admin'
  if (context?.isTeamLead) return 'approver'
  return 'creator' // Default role for new users
}