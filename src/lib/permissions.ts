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

// Team-based permission interfaces
export interface TeamPermissions {
  canInviteMembers: boolean
  canRemoveMembers: boolean
  canManageRoles: boolean
  canEditTeamSettings: boolean
  canViewAllProjects: boolean
  canCreateProjects: boolean
  canDeleteProjects: boolean
}

export type TeamRole = 'owner' | 'admin' | 'member' | 'guest'

// Team role permissions matrix
export const TEAM_ROLE_PERMISSIONS: Record<TeamRole, TeamPermissions> = {
  guest: {
    canInviteMembers: false,
    canRemoveMembers: false,
    canManageRoles: false,
    canEditTeamSettings: false,
    canViewAllProjects: false,
    canCreateProjects: false,
    canDeleteProjects: false
  },
  member: {
    canInviteMembers: false,
    canRemoveMembers: false,
    canManageRoles: false,
    canEditTeamSettings: false,
    canViewAllProjects: true,
    canCreateProjects: true,
    canDeleteProjects: false
  },
  admin: {
    canInviteMembers: true,
    canRemoveMembers: true,
    canManageRoles: true,
    canEditTeamSettings: true,
    canViewAllProjects: true,
    canCreateProjects: true,
    canDeleteProjects: true
  },
  owner: {
    canInviteMembers: true,
    canRemoveMembers: true,
    canManageRoles: true,
    canEditTeamSettings: true,
    canViewAllProjects: true,
    canCreateProjects: true,
    canDeleteProjects: true
  }
}

// Combined permission checker for user and team contexts
export class CombinedPermissionChecker {
  private userRole: UserRole
  private teamRole?: TeamRole
  private customPermissions?: Partial<UserPermissions>
  private customTeamPermissions?: Partial<TeamPermissions>

  constructor(
    userRole: UserRole,
    teamRole?: TeamRole,
    customPermissions?: Partial<UserPermissions>,
    customTeamPermissions?: Partial<TeamPermissions>
  ) {
    this.userRole = userRole
    this.teamRole = teamRole
    this.customPermissions = customPermissions
    this.customTeamPermissions = customTeamPermissions
  }

  // Get effective user permissions
  getUserPermissions(): UserPermissions {
    const basePermissions = ROLE_PERMISSIONS[this.userRole]
    
    if (this.customPermissions) {
      return { ...basePermissions, ...this.customPermissions }
    }
    
    return basePermissions
  }

  // Get effective team permissions
  getTeamPermissions(): TeamPermissions | null {
    if (!this.teamRole) return null
    
    const basePermissions = TEAM_ROLE_PERMISSIONS[this.teamRole]
    
    if (this.customTeamPermissions) {
      return { ...basePermissions, ...this.customTeamPermissions }
    }
    
    return basePermissions
  }

  // Check if user can perform content action
  canPerformContentAction(action: string): boolean {
    const userChecker = new PermissionChecker(this.userRole, this.customPermissions)
    return userChecker.canPerformAction(action)
  }

  // Check if user can perform team action
  canPerformTeamAction(action: keyof TeamPermissions): boolean {
    const teamPermissions = this.getTeamPermissions()
    if (!teamPermissions) return false
    
    return teamPermissions[action]
  }

  // Check if user has sufficient role for action (considers both user and team context)
  hasAccessTo(resource: 'content' | 'team', action: string): boolean {
    if (resource === 'content') {
      return this.canPerformContentAction(action)
    }
    
    if (resource === 'team') {
      return this.canPerformTeamAction(action as keyof TeamPermissions)
    }
    
    return false
  }
}

// Role management utilities
export class RoleManager {
  // Check if a role can assign another role
  static canAssignRole(assignerRole: UserRole, targetRole: UserRole): boolean {
    const assignerLevel = new PermissionChecker(assignerRole).getRoleLevel()
    const targetLevel = new PermissionChecker(targetRole).getRoleLevel()
    
    // Can only assign roles at or below their level
    return assignerLevel >= targetLevel && assignerLevel >= 4 // minimum approver level
  }

  // Check if a team role can manage another team role
  static canManageTeamRole(managerRole: TeamRole, targetRole: TeamRole): boolean {
    const roleLevels = { guest: 1, member: 2, admin: 3, owner: 4 }
    const managerLevel = roleLevels[managerRole]
    const targetLevel = roleLevels[targetRole]
    
    // Owners can manage anyone, admins can manage members and guests
    if (managerRole === 'owner') return true
    if (managerRole === 'admin' && targetRole !== 'owner') return true
    
    return false
  }

  // Get roles that a user can assign
  static getAssignableRoles(assignerRole: UserRole): UserRole[] {
    const assignerLevel = new PermissionChecker(assignerRole).getRoleLevel()
    
    return Object.entries(ROLE_PERMISSIONS)
      .filter(([_, permissions]) => {
        const roleLevel = new PermissionChecker(_ as UserRole).getRoleLevel()
        return assignerLevel >= roleLevel && assignerLevel >= 4
      })
      .map(([role, _]) => role as UserRole)
  }

  // Get team roles that a user can assign
  static getAssignableTeamRoles(managerRole: TeamRole): TeamRole[] {
    const roleLevels = { guest: 1, member: 2, admin: 3, owner: 4 }
    const managerLevel = roleLevels[managerRole]
    
    return Object.keys(roleLevels)
      .filter(role => {
        const roleLevel = roleLevels[role as TeamRole]
        if (managerRole === 'owner') return role !== 'owner' // Owners can assign all except owner
        if (managerRole === 'admin') return roleLevel <= 2 // Admins can assign member and guest
        return false
      }) as TeamRole[]
  }
}

// Permission validation for UI components
export function validateComponentAccess(
  userRole: UserRole,
  requiredPermission: keyof UserPermissions,
  teamRole?: TeamRole,
  requiredTeamPermission?: keyof TeamPermissions
): boolean {
  const checker = new CombinedPermissionChecker(userRole, teamRole)
  
  const hasUserPermission = checker.canPerformContentAction(
    getActionFromPermission(requiredPermission)
  )
  
  if (requiredTeamPermission) {
    const hasTeamPermission = checker.canPerformTeamAction(requiredTeamPermission)
    return hasUserPermission && hasTeamPermission
  }
  
  return hasUserPermission
}

// Helper to convert permission to action
function getActionFromPermission(permission: keyof UserPermissions): string {
  const permissionToAction: Record<keyof UserPermissions, string> = {
    canCreateContent: 'create',
    canEditContent: 'edit',
    canDeleteContent: 'delete',
    canViewContent: 'view',
    canSubmitForReview: 'submit_for_review',
    canApproveContent: 'approve',
    canRejectContent: 'reject',
    canPublishContent: 'publish',
    canArchiveContent: 'archive',
    canBulkApprove: 'bulk_approve',
    canViewAllContent: 'view_all',
    canManageUsers: 'manage_users',
    canConfigureWorkflow: 'configure_workflow'
  }
  
  return permissionToAction[permission] || 'view'
}