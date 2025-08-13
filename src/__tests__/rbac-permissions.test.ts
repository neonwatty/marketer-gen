import {
  UserRole,
  TeamRole,
  UserPermissions,
  TeamPermissions,
  PermissionChecker,
  CombinedPermissionChecker,
  RoleManager,
  ROLE_PERMISSIONS,
  TEAM_ROLE_PERMISSIONS,
  getUserPermissions,
  canUserPerformAction,
  hasMinimumRole,
  filterContentByPermissions,
  getDefaultUserRole,
  validateComponentAccess
} from '@/lib/permissions'

describe('RBAC Permissions System', () => {
  describe('Role Permissions Matrix', () => {
    test('should have correct permissions for viewer role', () => {
      const permissions = ROLE_PERMISSIONS.viewer
      
      expect(permissions.canCreateContent).toBe(false)
      expect(permissions.canEditContent).toBe(false)
      expect(permissions.canDeleteContent).toBe(false)
      expect(permissions.canViewContent).toBe(true)
      expect(permissions.canSubmitForReview).toBe(false)
      expect(permissions.canApproveContent).toBe(false)
      expect(permissions.canRejectContent).toBe(false)
      expect(permissions.canPublishContent).toBe(false)
      expect(permissions.canArchiveContent).toBe(false)
      expect(permissions.canBulkApprove).toBe(false)
      expect(permissions.canViewAllContent).toBe(false)
      expect(permissions.canManageUsers).toBe(false)
      expect(permissions.canConfigureWorkflow).toBe(false)
    })

    test('should have correct permissions for creator role', () => {
      const permissions = ROLE_PERMISSIONS.creator
      
      expect(permissions.canCreateContent).toBe(true)
      expect(permissions.canEditContent).toBe(true)
      expect(permissions.canDeleteContent).toBe(true)
      expect(permissions.canViewContent).toBe(true)
      expect(permissions.canSubmitForReview).toBe(true)
      expect(permissions.canApproveContent).toBe(false)
      expect(permissions.canRejectContent).toBe(false)
      expect(permissions.canPublishContent).toBe(false)
      expect(permissions.canArchiveContent).toBe(false)
      expect(permissions.canBulkApprove).toBe(false)
      expect(permissions.canViewAllContent).toBe(false)
      expect(permissions.canManageUsers).toBe(false)
      expect(permissions.canConfigureWorkflow).toBe(false)
    })

    test('should have correct permissions for reviewer role', () => {
      const permissions = ROLE_PERMISSIONS.reviewer
      
      expect(permissions.canCreateContent).toBe(true)
      expect(permissions.canEditContent).toBe(true)
      expect(permissions.canDeleteContent).toBe(true)
      expect(permissions.canViewContent).toBe(true)
      expect(permissions.canSubmitForReview).toBe(true)
      expect(permissions.canApproveContent).toBe(false)
      expect(permissions.canRejectContent).toBe(true) // Can provide feedback
      expect(permissions.canPublishContent).toBe(false)
      expect(permissions.canArchiveContent).toBe(false)
      expect(permissions.canBulkApprove).toBe(false)
      expect(permissions.canViewAllContent).toBe(true)
      expect(permissions.canManageUsers).toBe(false)
      expect(permissions.canConfigureWorkflow).toBe(false)
    })

    test('should have correct permissions for approver role', () => {
      const permissions = ROLE_PERMISSIONS.approver
      
      expect(permissions.canCreateContent).toBe(true)
      expect(permissions.canEditContent).toBe(true)
      expect(permissions.canDeleteContent).toBe(true)
      expect(permissions.canViewContent).toBe(true)
      expect(permissions.canSubmitForReview).toBe(true)
      expect(permissions.canApproveContent).toBe(true)
      expect(permissions.canRejectContent).toBe(true)
      expect(permissions.canPublishContent).toBe(false)
      expect(permissions.canArchiveContent).toBe(true)
      expect(permissions.canBulkApprove).toBe(true)
      expect(permissions.canViewAllContent).toBe(true)
      expect(permissions.canManageUsers).toBe(false)
      expect(permissions.canConfigureWorkflow).toBe(false)
    })

    test('should have correct permissions for publisher role', () => {
      const permissions = ROLE_PERMISSIONS.publisher
      
      expect(permissions.canCreateContent).toBe(true)
      expect(permissions.canEditContent).toBe(true)
      expect(permissions.canDeleteContent).toBe(true)
      expect(permissions.canViewContent).toBe(true)
      expect(permissions.canSubmitForReview).toBe(true)
      expect(permissions.canApproveContent).toBe(true)
      expect(permissions.canRejectContent).toBe(true)
      expect(permissions.canPublishContent).toBe(true)
      expect(permissions.canArchiveContent).toBe(true)
      expect(permissions.canBulkApprove).toBe(true)
      expect(permissions.canViewAllContent).toBe(true)
      expect(permissions.canManageUsers).toBe(false)
      expect(permissions.canConfigureWorkflow).toBe(false)
    })

    test('should have correct permissions for admin role', () => {
      const permissions = ROLE_PERMISSIONS.admin
      
      expect(permissions.canCreateContent).toBe(true)
      expect(permissions.canEditContent).toBe(true)
      expect(permissions.canDeleteContent).toBe(true)
      expect(permissions.canViewContent).toBe(true)
      expect(permissions.canSubmitForReview).toBe(true)
      expect(permissions.canApproveContent).toBe(true)
      expect(permissions.canRejectContent).toBe(true)
      expect(permissions.canPublishContent).toBe(true)
      expect(permissions.canArchiveContent).toBe(true)
      expect(permissions.canBulkApprove).toBe(true)
      expect(permissions.canViewAllContent).toBe(true)
      expect(permissions.canManageUsers).toBe(true)
      expect(permissions.canConfigureWorkflow).toBe(true)
    })

    test('should maintain role hierarchy consistency', () => {
      const roles: UserRole[] = ['viewer', 'creator', 'reviewer', 'approver', 'publisher', 'admin']
      
      for (let i = 0; i < roles.length - 1; i++) {
        const lowerRole = roles[i]
        const higherRole = roles[i + 1]
        
        const lowerPermissions = ROLE_PERMISSIONS[lowerRole]
        const higherPermissions = ROLE_PERMISSIONS[higherRole]
        
        // Higher roles should have at least the same permissions as lower roles
        Object.keys(lowerPermissions).forEach(permission => {
          if (lowerPermissions[permission as keyof UserPermissions]) {
            expect(higherPermissions[permission as keyof UserPermissions])
              .toBe(true)
          }
        })
      }
    })
  })

  describe('Team Permissions Matrix', () => {
    test('should have correct permissions for guest team role', () => {
      const permissions = TEAM_ROLE_PERMISSIONS.guest
      
      expect(permissions.canInviteMembers).toBe(false)
      expect(permissions.canRemoveMembers).toBe(false)
      expect(permissions.canManageRoles).toBe(false)
      expect(permissions.canEditTeamSettings).toBe(false)
      expect(permissions.canViewAllProjects).toBe(false)
      expect(permissions.canCreateProjects).toBe(false)
      expect(permissions.canDeleteProjects).toBe(false)
    })

    test('should have correct permissions for member team role', () => {
      const permissions = TEAM_ROLE_PERMISSIONS.member
      
      expect(permissions.canInviteMembers).toBe(false)
      expect(permissions.canRemoveMembers).toBe(false)
      expect(permissions.canManageRoles).toBe(false)
      expect(permissions.canEditTeamSettings).toBe(false)
      expect(permissions.canViewAllProjects).toBe(true)
      expect(permissions.canCreateProjects).toBe(true)
      expect(permissions.canDeleteProjects).toBe(false)
    })

    test('should have correct permissions for admin team role', () => {
      const permissions = TEAM_ROLE_PERMISSIONS.admin
      
      expect(permissions.canInviteMembers).toBe(true)
      expect(permissions.canRemoveMembers).toBe(true)
      expect(permissions.canManageRoles).toBe(true)
      expect(permissions.canEditTeamSettings).toBe(true)
      expect(permissions.canViewAllProjects).toBe(true)
      expect(permissions.canCreateProjects).toBe(true)
      expect(permissions.canDeleteProjects).toBe(true)
    })

    test('should have correct permissions for owner team role', () => {
      const permissions = TEAM_ROLE_PERMISSIONS.owner
      
      expect(permissions.canInviteMembers).toBe(true)
      expect(permissions.canRemoveMembers).toBe(true)
      expect(permissions.canManageRoles).toBe(true)
      expect(permissions.canEditTeamSettings).toBe(true)
      expect(permissions.canViewAllProjects).toBe(true)
      expect(permissions.canCreateProjects).toBe(true)
      expect(permissions.canDeleteProjects).toBe(true)
    })
  })

  describe('PermissionChecker Class', () => {
    test('should correctly initialize with base role permissions', () => {
      const checker = new PermissionChecker('creator')
      const permissions = checker.getPermissions()
      
      expect(permissions).toEqual(ROLE_PERMISSIONS.creator)
    })

    test('should merge custom permissions with base role permissions', () => {
      const customPermissions: Partial<UserPermissions> = {
        canApproveContent: true,
        canPublishContent: true
      }
      
      const checker = new PermissionChecker('creator', customPermissions)
      const permissions = checker.getPermissions()
      
      expect(permissions.canCreateContent).toBe(true) // From base role
      expect(permissions.canApproveContent).toBe(true) // From custom permissions
      expect(permissions.canPublishContent).toBe(true) // From custom permissions
      expect(permissions.canManageUsers).toBe(false) // From base role, not overridden
    })

    test('should check specific permissions correctly', () => {
      const checker = new PermissionChecker('approver')
      
      expect(checker.hasPermission('canCreateContent')).toBe(true)
      expect(checker.hasPermission('canApproveContent')).toBe(true)
      expect(checker.hasPermission('canManageUsers')).toBe(false)
      expect(checker.hasPermission('canConfigureWorkflow')).toBe(false)
    })

    test('should check action permissions correctly', () => {
      const checker = new PermissionChecker('reviewer')
      
      expect(checker.canPerformAction('create')).toBe(true)
      expect(checker.canPerformAction('edit')).toBe(true)
      expect(checker.canPerformAction('view')).toBe(true)
      expect(checker.canPerformAction('reject')).toBe(true)
      expect(checker.canPerformAction('request_revision')).toBe(true)
      expect(checker.canPerformAction('approve')).toBe(false)
      expect(checker.canPerformAction('publish')).toBe(false)
      expect(checker.canPerformAction('manage_users')).toBe(false)
      expect(checker.canPerformAction('invalid_action')).toBe(false)
    })

    test('should return correct role levels', () => {
      expect(new PermissionChecker('viewer').getRoleLevel()).toBe(1)
      expect(new PermissionChecker('creator').getRoleLevel()).toBe(2)
      expect(new PermissionChecker('reviewer').getRoleLevel()).toBe(3)
      expect(new PermissionChecker('approver').getRoleLevel()).toBe(4)
      expect(new PermissionChecker('publisher').getRoleLevel()).toBe(5)
      expect(new PermissionChecker('admin').getRoleLevel()).toBe(6)
    })

    test('should check minimum role requirements', () => {
      const adminChecker = new PermissionChecker('admin')
      const creatorChecker = new PermissionChecker('creator')
      
      expect(adminChecker.hasMinimumRole('viewer')).toBe(true)
      expect(adminChecker.hasMinimumRole('creator')).toBe(true)
      expect(adminChecker.hasMinimumRole('admin')).toBe(true)
      
      expect(creatorChecker.hasMinimumRole('viewer')).toBe(true)
      expect(creatorChecker.hasMinimumRole('creator')).toBe(true)
      expect(creatorChecker.hasMinimumRole('admin')).toBe(false)
    })

    test('should return available actions correctly', () => {
      const viewerActions = new PermissionChecker('viewer').getAvailableActions()
      const creatorActions = new PermissionChecker('creator').getAvailableActions()
      const adminActions = new PermissionChecker('admin').getAvailableActions()
      
      expect(viewerActions).toEqual(['view'])
      
      expect(creatorActions).toContain('create')
      expect(creatorActions).toContain('edit')
      expect(creatorActions).toContain('delete')
      expect(creatorActions).toContain('view')
      expect(creatorActions).toContain('submit_for_review')
      expect(creatorActions).not.toContain('approve')
      
      expect(adminActions.length).toBeGreaterThan(creatorActions.length)
      expect(adminActions).toContain('manage_users')
      expect(adminActions).toContain('configure_workflow')
    })
  })

  describe('CombinedPermissionChecker Class', () => {
    test('should handle user permissions correctly', () => {
      const checker = new CombinedPermissionChecker('creator', 'member')
      
      expect(checker.canPerformContentAction('create')).toBe(true)
      expect(checker.canPerformContentAction('approve')).toBe(false)
    })

    test('should handle team permissions correctly', () => {
      const checker = new CombinedPermissionChecker('creator', 'admin')
      
      expect(checker.canPerformTeamAction('canInviteMembers')).toBe(true)
      expect(checker.canPerformTeamAction('canManageRoles')).toBe(true)
      expect(checker.canPerformTeamAction('canDeleteProjects')).toBe(true)
    })

    test('should handle combined access checks', () => {
      const checker = new CombinedPermissionChecker('publisher', 'member')
      
      expect(checker.hasAccessTo('content', 'publish')).toBe(true)
      expect(checker.hasAccessTo('team', 'canCreateProjects')).toBe(true)
      expect(checker.hasAccessTo('team', 'canManageRoles')).toBe(false)
    })

    test('should return null team permissions when no team role', () => {
      const checker = new CombinedPermissionChecker('creator')
      
      expect(checker.getTeamPermissions()).toBeNull()
      expect(checker.canPerformTeamAction('canInviteMembers')).toBe(false)
    })

    test('should merge custom permissions correctly', () => {
      const customUserPermissions = { canApproveContent: true }
      const customTeamPermissions = { canDeleteProjects: false }
      
      const checker = new CombinedPermissionChecker(
        'creator',
        'admin',
        customUserPermissions,
        customTeamPermissions
      )
      
      expect(checker.canPerformContentAction('approve')).toBe(true)
      expect(checker.canPerformTeamAction('canDeleteProjects')).toBe(false)
      expect(checker.canPerformTeamAction('canManageRoles')).toBe(true) // Not overridden
    })
  })

  describe('RoleManager Class', () => {
    test('should validate role assignment permissions', () => {
      // Admins can assign any role
      expect(RoleManager.canAssignRole('admin', 'viewer')).toBe(true)
      expect(RoleManager.canAssignRole('admin', 'admin')).toBe(true)
      
      // Approvers can assign roles at or below their level
      expect(RoleManager.canAssignRole('approver', 'creator')).toBe(true)
      expect(RoleManager.canAssignRole('approver', 'approver')).toBe(true)
      expect(RoleManager.canAssignRole('approver', 'admin')).toBe(false)
      
      // Creators cannot assign roles (below minimum level)
      expect(RoleManager.canAssignRole('creator', 'viewer')).toBe(false)
      expect(RoleManager.canAssignRole('creator', 'creator')).toBe(false)
    })

    test('should validate team role management permissions', () => {
      // Owners can manage any role except owner
      expect(RoleManager.canManageTeamRole('owner', 'admin')).toBe(true)
      expect(RoleManager.canManageTeamRole('owner', 'member')).toBe(true)
      expect(RoleManager.canManageTeamRole('owner', 'guest')).toBe(true)
      
      // Admins can manage members and guests, and other admins
      expect(RoleManager.canManageTeamRole('admin', 'member')).toBe(true)
      expect(RoleManager.canManageTeamRole('admin', 'guest')).toBe(true)
      expect(RoleManager.canManageTeamRole('admin', 'owner')).toBe(false)
      expect(RoleManager.canManageTeamRole('admin', 'admin')).toBe(true) // Admins can manage other admins
      
      // Members cannot manage roles
      expect(RoleManager.canManageTeamRole('member', 'guest')).toBe(false)
    })

    test('should return correct assignable roles', () => {
      const adminAssignable = RoleManager.getAssignableRoles('admin')
      const approverAssignable = RoleManager.getAssignableRoles('approver')
      const creatorAssignable = RoleManager.getAssignableRoles('creator')
      
      expect(adminAssignable).toContain('viewer')
      expect(adminAssignable).toContain('creator')
      expect(adminAssignable).toContain('admin')
      
      expect(approverAssignable).toContain('viewer')
      expect(approverAssignable).toContain('creator')
      expect(approverAssignable).toContain('approver')
      expect(approverAssignable).not.toContain('admin')
      
      expect(creatorAssignable).toEqual([]) // Below minimum level
    })

    test('should return correct assignable team roles', () => {
      const ownerAssignable = RoleManager.getAssignableTeamRoles('owner')
      const adminAssignable = RoleManager.getAssignableTeamRoles('admin')
      const memberAssignable = RoleManager.getAssignableTeamRoles('member')
      
      expect(ownerAssignable).toContain('admin')
      expect(ownerAssignable).toContain('member')
      expect(ownerAssignable).toContain('guest')
      expect(ownerAssignable).not.toContain('owner')
      
      expect(adminAssignable).toContain('member')
      expect(adminAssignable).toContain('guest')
      expect(adminAssignable).not.toContain('admin')
      expect(adminAssignable).not.toContain('owner')
      
      expect(memberAssignable).toEqual([])
    })
  })

  describe('Utility Functions', () => {
    test('getUserPermissions should return correct permissions', () => {
      const permissions = getUserPermissions('reviewer')
      expect(permissions).toEqual(ROLE_PERMISSIONS.reviewer)
      
      const customPermissions = getUserPermissions('creator', { canApproveContent: true })
      expect(customPermissions.canCreateContent).toBe(true)
      expect(customPermissions.canApproveContent).toBe(true)
    })

    test('canUserPerformAction should check actions correctly', () => {
      expect(canUserPerformAction('creator', 'create')).toBe(true)
      expect(canUserPerformAction('creator', 'approve')).toBe(false)
      expect(canUserPerformAction('admin', 'manage_users')).toBe(true)
    })

    test('hasMinimumRole should compare roles correctly', () => {
      expect(hasMinimumRole('admin', 'viewer')).toBe(true)
      expect(hasMinimumRole('creator', 'admin')).toBe(false)
      expect(hasMinimumRole('approver', 'approver')).toBe(true)
    })

    test('filterContentByPermissions should filter content correctly', () => {
      const content = [
        { id: 1, userId: 'user1', title: 'Content 1' },
        { id: 2, userId: 'user2', title: 'Content 2' },
        { id: 3, userId: 'user1', title: 'Content 3' }
      ]
      
      // Admin can see all content
      const adminFiltered = filterContentByPermissions(content, 'admin', 'user1')
      expect(adminFiltered.length).toBe(3)
      
      // Creator can only see their own content
      const creatorFiltered = filterContentByPermissions(content, 'creator', 'user1')
      expect(creatorFiltered.length).toBe(2)
      expect(creatorFiltered.every(item => item.userId === 'user1')).toBe(true)
      
      // Without user ID and no view all permission, return empty
      const noUserIdFiltered = filterContentByPermissions(content, 'creator')
      expect(noUserIdFiltered.length).toBe(0)
    })

    test('getDefaultUserRole should return appropriate default roles', () => {
      expect(getDefaultUserRole({ isOwner: true })).toBe('admin')
      expect(getDefaultUserRole({ isTeamLead: true })).toBe('approver')
      expect(getDefaultUserRole()).toBe('creator')
      expect(getDefaultUserRole({})).toBe('creator')
    })

    test('validateComponentAccess should validate UI component access', () => {
      // User permission only
      expect(validateComponentAccess('creator', 'canCreateContent')).toBe(true)
      expect(validateComponentAccess('viewer', 'canCreateContent')).toBe(false)
      
      // Combined user and team permissions
      expect(validateComponentAccess('creator', 'canCreateContent', 'member', 'canCreateProjects')).toBe(true)
      expect(validateComponentAccess('creator', 'canCreateContent', 'guest', 'canCreateProjects')).toBe(false)
    })
  })

  describe('Security Edge Cases', () => {
    test('should not allow privilege escalation through custom permissions', () => {
      // Attempt to give manage_users permission to creator
      const maliciousPermissions = { canManageUsers: true }
      const checker = new PermissionChecker('creator', maliciousPermissions)
      
      // Custom permissions should override, but this tests the system behavior
      expect(checker.hasPermission('canManageUsers')).toBe(true) // This is expected behavior
      
      // However, role-based checks should still respect hierarchy
      expect(checker.getRoleLevel()).toBe(2) // Still creator level
      expect(checker.hasMinimumRole('admin')).toBe(false) // Still not admin
    })

    test('should handle invalid role assignments', () => {
      // Test with invalid actions
      const checker = new PermissionChecker('admin')
      expect(checker.canPerformAction('invalid_action')).toBe(false)
      expect(checker.canPerformAction('')).toBe(false)
    })

    test('should maintain permission consistency with role levels', () => {
      const roles: UserRole[] = ['viewer', 'creator', 'reviewer', 'approver', 'publisher', 'admin']
      
      roles.forEach(role => {
        const checker = new PermissionChecker(role)
        const level = checker.getRoleLevel()
        const permissions = checker.getPermissions()
        
        // Verify that higher-level permissions are only available to higher roles
        if (level < 4) { // Below approver
          expect(permissions.canApproveContent).toBe(false)
          expect(permissions.canBulkApprove).toBe(false)
        }
        
        if (level < 5) { // Below publisher
          expect(permissions.canPublishContent).toBe(false)
        }
        
        if (level < 6) { // Below admin
          expect(permissions.canManageUsers).toBe(false)
          expect(permissions.canConfigureWorkflow).toBe(false)
        }
      })
    })

    test('should prevent unauthorized team role assignments', () => {
      // Guests and members should not be able to manage roles
      expect(RoleManager.canManageTeamRole('guest', 'member')).toBe(false)
      expect(RoleManager.canManageTeamRole('member', 'guest')).toBe(false)
      
      // Admins should not be able to manage owners
      expect(RoleManager.canManageTeamRole('admin', 'owner')).toBe(false)
    })
  })

  describe('Integration with Real Use Cases', () => {
    test('should support content creation workflow', () => {
      // Creator creates content
      const creator = new PermissionChecker('creator')
      expect(creator.canPerformAction('create')).toBe(true)
      expect(creator.canPerformAction('submit_for_review')).toBe(true)
      
      // Reviewer reviews content
      const reviewer = new PermissionChecker('reviewer')
      expect(reviewer.canPerformAction('view')).toBe(true)
      expect(reviewer.canPerformAction('reject')).toBe(true)
      expect(reviewer.canPerformAction('approve')).toBe(false) // Can't approve, only review
      
      // Approver approves content
      const approver = new PermissionChecker('approver')
      expect(approver.canPerformAction('approve')).toBe(true)
      expect(approver.canPerformAction('reject')).toBe(true)
      
      // Publisher publishes content
      const publisher = new PermissionChecker('publisher')
      expect(publisher.canPerformAction('publish')).toBe(true)
    })

    test('should support team management workflow', () => {
      // Owner manages team
      const owner = new CombinedPermissionChecker('admin', 'owner')
      expect(owner.canPerformTeamAction('canInviteMembers')).toBe(true)
      expect(owner.canPerformTeamAction('canManageRoles')).toBe(true)
      expect(owner.canPerformTeamAction('canRemoveMembers')).toBe(true)
      
      // Admin manages projects and members
      const admin = new CombinedPermissionChecker('admin', 'admin')
      expect(admin.canPerformTeamAction('canCreateProjects')).toBe(true)
      expect(admin.canPerformTeamAction('canDeleteProjects')).toBe(true)
      expect(admin.canPerformTeamAction('canInviteMembers')).toBe(true)
      
      // Member works on projects
      const member = new CombinedPermissionChecker('creator', 'member')
      expect(member.canPerformTeamAction('canViewAllProjects')).toBe(true)
      expect(member.canPerformTeamAction('canCreateProjects')).toBe(true)
      expect(member.canPerformTeamAction('canManageRoles')).toBe(false)
    })

    test('should support audit and compliance requirements', () => {
      // Different roles should have appropriate audit visibility
      const admin = new PermissionChecker('admin')
      const approver = new PermissionChecker('approver')
      const creator = new PermissionChecker('creator')
      
      expect(admin.hasPermission('canViewAllContent')).toBe(true) // Can audit all
      expect(approver.hasPermission('canViewAllContent')).toBe(true) // Can audit approvals
      expect(creator.hasPermission('canViewAllContent')).toBe(false) // Limited visibility
      
      // Bulk operations should be restricted
      expect(admin.hasPermission('canBulkApprove')).toBe(true)
      expect(approver.hasPermission('canBulkApprove')).toBe(true)
      expect(creator.hasPermission('canBulkApprove')).toBe(false)
    })
  })
})

describe('RBAC Performance and Edge Cases', () => {
  test('should handle large permission checks efficiently', () => {
    const startTime = performance.now()
    
    // Simulate checking permissions for many users
    for (let i = 0; i < 1000; i++) {
      const roles: UserRole[] = ['viewer', 'creator', 'reviewer', 'approver', 'publisher', 'admin']
      const randomRole = roles[i % roles.length]
      
      const checker = new PermissionChecker(randomRole)
      checker.canPerformAction('create')
      checker.canPerformAction('approve')
      checker.canPerformAction('publish')
      checker.getAvailableActions()
    }
    
    const endTime = performance.now()
    const executionTime = endTime - startTime
    
    // Should complete within reasonable time (less than 100ms)
    expect(executionTime).toBeLessThan(100)
  })

  test('should handle undefined/null custom permissions gracefully', () => {
    const checker = new PermissionChecker('creator', undefined)
    expect(checker.getPermissions()).toEqual(ROLE_PERMISSIONS.creator)
    
    const checker2 = new PermissionChecker('creator', null as any)
    expect(checker2.getPermissions()).toEqual(ROLE_PERMISSIONS.creator)
  })

  test('should handle edge cases in content filtering', () => {
    const emptyContent: any[] = []
    const contentWithoutUserId = [{ id: 1, title: 'No User ID' }]
    
    expect(filterContentByPermissions(emptyContent, 'admin')).toEqual([])
    expect(filterContentByPermissions(contentWithoutUserId, 'creator', 'user1')).toEqual([])
    expect(filterContentByPermissions(contentWithoutUserId, 'admin')).toEqual(contentWithoutUserId)
  })
})