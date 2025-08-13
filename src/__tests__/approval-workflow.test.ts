import { describe, it, expect, beforeEach, vi } from 'vitest'
import { ApprovalWorkflow, approvalWorkflow, ApprovalAction } from '../lib/approval-workflow'
import { ApprovalActions } from '../lib/approval-actions'
import { PermissionChecker } from '../lib/permissions'
import { NotificationService } from '../lib/notifications'
import { ContentStatus, ApprovalStatus } from '@prisma/client'

// Mock Prisma
vi.mock('@prisma/client', () => ({
  PrismaClient: vi.fn().mockImplementation(() => ({
    content: {
      findUnique: vi.fn(),
      update: vi.fn(),
      findMany: vi.fn()
    },
    analytics: {
      create: vi.fn()
    }
  })),
  ContentStatus: {
    DRAFT: 'DRAFT',
    PENDING_REVIEW: 'PENDING_REVIEW', 
    APPROVED: 'APPROVED',
    REJECTED: 'REJECTED',
    PUBLISHED: 'PUBLISHED',
    ARCHIVED: 'ARCHIVED'
  },
  ApprovalStatus: {
    PENDING: 'PENDING',
    APPROVED: 'APPROVED', 
    REJECTED: 'REJECTED'
  }
}))

describe('Approval Workflow System', () => {
  let workflow: ApprovalWorkflow
  let mockPrisma: any

  beforeEach(() => {
    workflow = new ApprovalWorkflow()
    mockPrisma = {
      content: {
        findUnique: vi.fn(),
        update: vi.fn(),
        findMany: vi.fn()
      },
      analytics: {
        create: vi.fn()
      }
    }
  })

  describe('ApprovalWorkflow State Machine', () => {
    it('should allow valid state transitions', () => {
      // Test draft to reviewing transition
      const result = workflow.canTransition('DRAFT', 'submit_for_review', {
        contentId: 'test-id'
      })
      expect(result.success).toBe(true)
      expect(result.newState).toBe('PENDING_REVIEW')
      expect(result.newApprovalStatus).toBe('PENDING')
    })

    it('should reject invalid state transitions', () => {
      // Test invalid transition: draft directly to published
      const result = workflow.canTransition('DRAFT', 'publish', {
        contentId: 'test-id'
      })
      expect(result.success).toBe(false)
      expect(result.error).toContain('not valid for state')
    })

    it('should enforce role-based permissions', () => {
      // Test approval without proper role
      const result = workflow.canTransition('PENDING_REVIEW', 'approve', {
        contentId: 'test-id',
        userRole: 'creator'
      })
      expect(result.success).toBe(false)
      expect(result.error).toContain('does not have permission')
    })

    it('should allow approval with proper role', () => {
      // Test approval with approver role
      const result = workflow.canTransition('PENDING_REVIEW', 'approve', {
        contentId: 'test-id',
        userRole: 'approver'
      })
      expect(result.success).toBe(true)
      expect(result.newState).toBe('APPROVED')
    })

    it('should require comments for rejection', () => {
      // Test rejection without comment
      const result = workflow.canTransition('PENDING_REVIEW', 'reject', {
        contentId: 'test-id',
        userRole: 'approver'
      })
      expect(result.success).toBe(false)
      expect(result.error).toContain('requires a comment')
    })

    it('should allow rejection with comment', () => {
      // Test rejection with comment
      const result = workflow.canTransition('PENDING_REVIEW', 'reject', {
        contentId: 'test-id',
        userRole: 'approver',
        comment: 'Content needs improvement'
      })
      expect(result.success).toBe(true)
      expect(result.newState).toBe('DRAFT')
    })
  })

  describe('Available Actions', () => {
    it('should return correct actions for draft state', () => {
      const actions = workflow.getAvailableActions('DRAFT')
      expect(actions).toContain('submit_for_review')
      expect(actions).toContain('archive')
      expect(actions).not.toContain('approve')
    })

    it('should filter actions by user role', () => {
      const approverActions = workflow.getAvailableActions('PENDING_REVIEW', 'approver')
      const creatorActions = workflow.getAvailableActions('PENDING_REVIEW', 'creator')
      
      expect(approverActions).toContain('approve')
      expect(approverActions).toContain('reject')
      expect(creatorActions).not.toContain('approve')
      expect(creatorActions).not.toContain('reject')
    })

    it('should return publish action for approved content with publisher role', () => {
      const actions = workflow.getAvailableActions('APPROVED', 'publisher')
      expect(actions).toContain('publish')
    })
  })

  describe('State and Status Information', () => {
    it('should return correct state information', () => {
      const draftInfo = workflow.getStateInfo('DRAFT')
      expect(draftInfo.label).toBe('Draft')
      expect(draftInfo.color).toBe('gray')

      const approvedInfo = workflow.getStateInfo('APPROVED')
      expect(approvedInfo.label).toBe('Approved')
      expect(approvedInfo.color).toBe('green')
    })

    it('should return correct approval status information', () => {
      const pendingInfo = workflow.getApprovalStatusInfo('PENDING')
      expect(pendingInfo.label).toBe('Pending Review')
      expect(pendingInfo.color).toBe('yellow')

      const approvedInfo = workflow.getApprovalStatusInfo('APPROVED')
      expect(approvedInfo.label).toBe('Approved')
      expect(approvedInfo.color).toBe('green')
    })
  })

  describe('Workflow Diagram', () => {
    it('should generate workflow diagram data', () => {
      const diagram = workflow.getWorkflowDiagram()
      
      expect(diagram.states.length).toBeGreaterThan(0)
      expect(diagram.transitions.length).toBeGreaterThan(0)
      
      // Check for key states
      const stateIds = diagram.states.map(s => s.id)
      expect(stateIds).toContain('DRAFT')
      expect(stateIds).toContain('PENDING_REVIEW')
      expect(stateIds).toContain('APPROVED')
      expect(stateIds).toContain('PUBLISHED')
    })
  })
})

describe('Permission System', () => {
  describe('PermissionChecker', () => {
    it('should grant correct permissions for each role', () => {
      const viewer = new PermissionChecker('viewer')
      const creator = new PermissionChecker('creator')
      const approver = new PermissionChecker('approver')
      const admin = new PermissionChecker('admin')

      // Viewer permissions
      expect(viewer.hasPermission('canViewContent')).toBe(true)
      expect(viewer.hasPermission('canApproveContent')).toBe(false)

      // Creator permissions
      expect(creator.hasPermission('canCreateContent')).toBe(true)
      expect(creator.hasPermission('canApproveContent')).toBe(false)

      // Approver permissions
      expect(approver.hasPermission('canApproveContent')).toBe(true)
      expect(approver.hasPermission('canPublishContent')).toBe(false)

      // Admin permissions
      expect(admin.hasPermission('canApproveContent')).toBe(true)
      expect(admin.hasPermission('canPublishContent')).toBe(true)
      expect(admin.hasPermission('canManageUsers')).toBe(true)
    })

    it('should handle custom permissions', () => {
      const customCreator = new PermissionChecker('creator', {
        canApproveContent: true // Custom permission override
      })

      expect(customCreator.hasPermission('canCreateContent')).toBe(true)
      expect(customCreator.hasPermission('canApproveContent')).toBe(true)
    })

    it('should check minimum role requirements', () => {
      const creator = new PermissionChecker('creator')
      const approver = new PermissionChecker('approver')

      expect(creator.hasMinimumRole('viewer')).toBe(true)
      expect(creator.hasMinimumRole('creator')).toBe(true)
      expect(creator.hasMinimumRole('approver')).toBe(false)

      expect(approver.hasMinimumRole('creator')).toBe(true)
      expect(approver.hasMinimumRole('approver')).toBe(true)
      expect(approver.hasMinimumRole('admin')).toBe(false)
    })
  })
})

describe('Notification System', () => {
  let notificationService: NotificationService

  beforeEach(() => {
    notificationService = new NotificationService()
  })

  describe('Notification Creation', () => {
    it('should create notification with correct template', () => {
      const notification = notificationService.createNotification({
        type: 'content_submitted',
        contentId: 'test-content',
        contentTitle: 'Test Content',
        action: 'submit_for_review',
        fromStatus: 'DRAFT',
        toStatus: 'PENDING_REVIEW',
        fromUserName: 'John Doe'
      })

      expect(notification.type).toBe('content_submitted')
      expect(notification.title).toContain('Submitted for Review')
      expect(notification.message).toContain('Test Content')
      expect(notification.message).toContain('John Doe')
      expect(notification.priority).toBe('medium')
    })

    it('should handle different notification types', () => {
      const approvedNotification = notificationService.createNotification({
        type: 'content_approved',
        contentId: 'test-content',
        contentTitle: 'Test Content',
        action: 'approve',
        fromStatus: 'PENDING_REVIEW',
        toStatus: 'APPROVED',
        fromUserName: 'Jane Smith'
      })

      const rejectedNotification = notificationService.createNotification({
        type: 'content_rejected',
        contentId: 'test-content',
        contentTitle: 'Test Content',
        action: 'reject',
        fromStatus: 'PENDING_REVIEW',
        toStatus: 'DRAFT',
        fromUserName: 'Jane Smith',
        comment: 'Needs more work'
      })

      expect(approvedNotification.title).toContain('Approved')
      expect(approvedNotification.priority).toBe('high')

      expect(rejectedNotification.title).toContain('Rejected')
      expect(rejectedNotification.message).toContain('Needs more work')
      expect(rejectedNotification.priority).toBe('high')
    })
  })

  describe('Notification Management', () => {
    it('should add and retrieve notifications for users', () => {
      const notification = notificationService.createNotification({
        type: 'content_approved',
        contentId: 'test-content',
        contentTitle: 'Test Content',
        action: 'approve',
        fromStatus: 'PENDING_REVIEW',
        toStatus: 'APPROVED'
      })

      notificationService.addNotification('user-1', notification)
      
      const notifications = notificationService.getNotifications('user-1')
      expect(notifications).toHaveLength(1)
      expect(notifications[0].id).toBe(notification.id)
    })

    it('should track unread count', () => {
      const notification1 = notificationService.createNotification({
        type: 'content_approved',
        contentId: 'test-content-1',
        contentTitle: 'Test Content 1',
        action: 'approve',
        fromStatus: 'PENDING_REVIEW',
        toStatus: 'APPROVED'
      })

      const notification2 = notificationService.createNotification({
        type: 'content_rejected',
        contentId: 'test-content-2',
        contentTitle: 'Test Content 2',
        action: 'reject',
        fromStatus: 'PENDING_REVIEW',
        toStatus: 'DRAFT'
      })

      notificationService.addNotification('user-1', notification1)
      notificationService.addNotification('user-1', notification2)

      expect(notificationService.getUnreadCount('user-1')).toBe(2)

      notificationService.markAsRead('user-1', notification1.id)
      expect(notificationService.getUnreadCount('user-1')).toBe(1)

      notificationService.markAllAsRead('user-1')
      expect(notificationService.getUnreadCount('user-1')).toBe(0)
    })

    it('should limit notification history', () => {
      // Add more than 100 notifications
      for (let i = 0; i < 105; i++) {
        const notification = notificationService.createNotification({
          type: 'content_approved',
          contentId: `test-content-${i}`,
          contentTitle: `Test Content ${i}`,
          action: 'approve',
          fromStatus: 'PENDING_REVIEW',
          toStatus: 'APPROVED'
        })
        notificationService.addNotification('user-1', notification)
      }

      const notifications = notificationService.getNotifications('user-1')
      expect(notifications).toHaveLength(50) // Should be limited to 50
    })
  })
})

describe('Integration Tests', () => {
  let approvalActions: ApprovalActions
  let mockPrisma: any
  let workflow: ApprovalWorkflow

  beforeEach(() => {
    // Reset mocks
    vi.clearAllMocks()
    
    // Setup mockPrisma
    mockPrisma = {
      content: {
        findUnique: vi.fn(),
        update: vi.fn(),
        findMany: vi.fn()
      },
      analytics: {
        create: vi.fn()
      }
    }
    
    workflow = new ApprovalWorkflow()
  })

  describe('End-to-End Workflow', () => {
    it('should handle complete approval workflow', async () => {
      // Mock the database responses
      const mockContent = {
        id: 'test-content-1',
        status: 'DRAFT' as ContentStatus,
        approvalStatus: 'PENDING' as ApprovalStatus,
        metadata: null,
        title: 'Test Content'
      }

      mockPrisma.content.findUnique.mockResolvedValue(mockContent)
      mockPrisma.content.update.mockResolvedValue({
        ...mockContent,
        status: 'PENDING_REVIEW',
        approvalStatus: 'PENDING'
      })
      mockPrisma.analytics.create.mockResolvedValue({})

      // Test submission for review
      const result1 = await workflow.executeTransition('DRAFT', 'submit_for_review', {
        contentId: 'test-content-1',
        userId: 'user-1'
      })

      expect(result1.success).toBe(true)
      expect(result1.newState).toBe('PENDING_REVIEW')

      // Test approval
      const result2 = await workflow.executeTransition('PENDING_REVIEW', 'approve', {
        contentId: 'test-content-1',
        userId: 'approver-1',
        userRole: 'approver'
      })

      expect(result2.success).toBe(true)
      expect(result2.newState).toBe('APPROVED')

      // Test publishing
      const result3 = await workflow.executeTransition('APPROVED', 'publish', {
        contentId: 'test-content-1',
        userId: 'publisher-1',
        userRole: 'publisher'
      })

      expect(result3.success).toBe(true)
      expect(result3.newState).toBe('PUBLISHED')
    })

    it('should handle rejection and revision workflow', async () => {
      const mockContent = {
        id: 'test-content-1',
        status: 'PENDING_REVIEW' as ContentStatus,
        approvalStatus: 'PENDING' as ApprovalStatus,
        metadata: null,
        title: 'Test Content'
      }

      mockPrisma.content.findUnique.mockResolvedValue(mockContent)
      mockPrisma.content.update.mockResolvedValue({
        ...mockContent,
        status: 'DRAFT',
        approvalStatus: 'REJECTED'
      })

      // Test rejection
      const result1 = await workflow.executeTransition('PENDING_REVIEW', 'reject', {
        contentId: 'test-content-1',
        userId: 'approver-1',
        userRole: 'approver',
        comment: 'Content needs significant improvements'
      })

      expect(result1.success).toBe(true)
      expect(result1.newState).toBe('DRAFT')

      // Test resubmission after revision
      const result2 = await workflow.executeTransition('DRAFT', 'submit_for_review', {
        contentId: 'test-content-1',
        userId: 'creator-1',
        comment: 'Addressed all feedback'
      })

      expect(result2.success).toBe(true)
      expect(result2.newState).toBe('PENDING_REVIEW')
    })

    it('should enforce permission constraints', async () => {
      // Test that creator cannot approve content
      const result = await workflow.executeTransition('PENDING_REVIEW', 'approve', {
        contentId: 'test-content-1',
        userId: 'creator-1',
        userRole: 'creator'
      })

      expect(result.success).toBe(false)
      expect(result.error).toContain('permission')
    })
  })
})