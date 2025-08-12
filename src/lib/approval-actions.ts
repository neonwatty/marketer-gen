import { PrismaClient, ContentStatus, ApprovalStatus } from '@prisma/client';
import { approvalWorkflow, WorkflowContext, WorkflowResult, ApprovalAction } from './approval-workflow';

const prisma = new PrismaClient();

export interface ApprovalComment {
  id: string;
  contentId: string;
  userId?: string;
  userName?: string;
  userRole?: string;
  comment: string;
  action: ApprovalAction;
  fromStatus: ContentStatus;
  toStatus: ContentStatus;
  createdAt: Date;
  metadata?: Record<string, any>;
}

export interface ContentApprovalData {
  id: string;
  title: string;
  status: ContentStatus;
  approvalStatus: ApprovalStatus;
  approvedBy?: string | null;
  approvedAt?: Date | null;
  rejectionReason?: string | null;
  comments: ApprovalComment[];
  availableActions: ApprovalAction[];
  canApprove: boolean;
  canReject: boolean;
  canPublish: boolean;
}

// Store approval comments in a simple JSON structure
// In a full implementation, you might want a separate ApprovalComment table
export class ApprovalActions {
  
  // Execute a workflow transition with database update
  async executeWorkflowAction(
    contentId: string,
    action: ApprovalAction,
    context: WorkflowContext
  ): Promise<WorkflowResult> {
    try {
      // Get current content state
      const content = await prisma.content.findUnique({
        where: { id: contentId },
        select: { 
          status: true, 
          approvalStatus: true, 
          metadata: true,
          title: true 
        }
      });

      if (!content) {
        return {
          success: false,
          error: 'Content not found'
        };
      }

      // Check if transition is valid
      const transitionResult = await approvalWorkflow.executeTransition(
        content.status,
        action,
        { ...context, contentId }
      );

      if (!transitionResult.success) {
        return transitionResult;
      }

      // Parse existing comments from metadata
      let metadata = {};
      try {
        metadata = content.metadata ? JSON.parse(content.metadata) : {};
      } catch (e) {
        metadata = {};
      }

      const comments = (metadata as any).approvalComments || [];
      
      // Add new comment if provided
      if (context.comment || action === 'approve' || action === 'reject' || action === 'request_revision') {
        const newComment: ApprovalComment = {
          id: `comment_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
          contentId,
          userId: context.userId,
          userName: context.metadata?.userName,
          userRole: context.userRole,
          comment: context.comment || this.getDefaultCommentForAction(action),
          action,
          fromStatus: content.status,
          toStatus: transitionResult.newState!,
          createdAt: new Date(),
          metadata: context.metadata
        };
        comments.push(newComment);
      }

      // Update metadata with comments
      const updatedMetadata = {
        ...metadata,
        approvalComments: comments,
        lastWorkflowAction: {
          action,
          userId: context.userId,
          timestamp: new Date(),
          fromStatus: content.status,
          toStatus: transitionResult.newState
        }
      };

      // Prepare update data
      const updateData: any = {
        status: transitionResult.newState,
        updatedAt: new Date(),
        metadata: JSON.stringify(updatedMetadata)
      };

      // Update approval-specific fields
      if (transitionResult.newApprovalStatus) {
        updateData.approvalStatus = transitionResult.newApprovalStatus;
      }

      if (action === 'approve') {
        updateData.approvedBy = context.userId;
        updateData.approvedAt = new Date();
        updateData.rejectionReason = null; // Clear any previous rejection reason
      } else if (action === 'reject' || action === 'request_revision') {
        updateData.rejectionReason = context.comment;
        updateData.approvedBy = null;
        updateData.approvedAt = null;
      } else if (action === 'publish') {
        // Keep approval data when publishing
        if (!content.approvalStatus || content.approvalStatus === 'PENDING') {
          updateData.approvedBy = context.userId;
          updateData.approvedAt = new Date();
        }
      }

      // Execute the database update
      await prisma.content.update({
        where: { id: contentId },
        data: updateData
      });

      // Log the workflow action for analytics
      await this.logWorkflowAction(contentId, action, content.status, transitionResult.newState!, context);

      return {
        success: true,
        newState: transitionResult.newState,
        newApprovalStatus: transitionResult.newApprovalStatus
      };

    } catch (error) {
      console.error('Error executing workflow action:', error);
      return {
        success: false,
        error: 'Failed to execute workflow action'
      };
    }
  }

  // Get content with approval data
  async getContentApprovalData(contentId: string, userRole?: string): Promise<ContentApprovalData | null> {
    try {
      const content = await prisma.content.findUnique({
        where: { id: contentId },
        select: {
          id: true,
          title: true,
          status: true,
          approvalStatus: true,
          approvedBy: true,
          approvedAt: true,
          rejectionReason: true,
          metadata: true
        }
      });

      if (!content) {
        return null;
      }

      // Parse comments from metadata
      let comments: ApprovalComment[] = [];
      try {
        const metadata = content.metadata ? JSON.parse(content.metadata) : {};
        comments = metadata.approvalComments || [];
      } catch (e) {
        comments = [];
      }

      // Get available actions for current user
      const availableActions = approvalWorkflow.getAvailableActions(content.status, userRole);
      
      // Check specific permissions
      const canApprove = availableActions.includes('approve');
      const canReject = availableActions.includes('reject') || availableActions.includes('request_revision');
      const canPublish = availableActions.includes('publish');

      return {
        id: content.id,
        title: content.title,
        status: content.status,
        approvalStatus: content.approvalStatus,
        approvedBy: content.approvedBy,
        approvedAt: content.approvedAt,
        rejectionReason: content.rejectionReason,
        comments: comments.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()),
        availableActions,
        canApprove,
        canReject,
        canPublish
      };
    } catch (error) {
      console.error('Error getting content approval data:', error);
      return null;
    }
  }

  // Get all content pending approval for a specific role
  async getContentPendingApproval(userRole?: string): Promise<ContentApprovalData[]> {
    try {
      const contents = await prisma.content.findMany({
        where: {
          OR: [
            { status: 'REVIEWING' },
            { status: 'APPROVED' }, // Can still be published
          ]
        },
        select: {
          id: true,
          title: true,
          status: true,
          approvalStatus: true,
          approvedBy: true,
          approvedAt: true,
          rejectionReason: true,
          metadata: true,
          createdAt: true,
          updatedAt: true
        },
        orderBy: [
          { status: 'asc' }, // REVIEWING first
          { updatedAt: 'asc' } // Oldest first
        ]
      });

      const approvalData: ContentApprovalData[] = [];

      for (const content of contents) {
        const availableActions = approvalWorkflow.getAvailableActions(content.status, userRole);
        
        // Only include if user has actions they can perform
        if (availableActions.length > 0) {
          let comments: ApprovalComment[] = [];
          try {
            const metadata = content.metadata ? JSON.parse(content.metadata) : {};
            comments = metadata.approvalComments || [];
          } catch (e) {
            comments = [];
          }

          approvalData.push({
            id: content.id,
            title: content.title,
            status: content.status,
            approvalStatus: content.approvalStatus,
            approvedBy: content.approvedBy,
            approvedAt: content.approvedAt,
            rejectionReason: content.rejectionReason,
            comments: comments.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()),
            availableActions,
            canApprove: availableActions.includes('approve'),
            canReject: availableActions.includes('reject') || availableActions.includes('request_revision'),
            canPublish: availableActions.includes('publish')
          });
        }
      }

      return approvalData;
    } catch (error) {
      console.error('Error getting content pending approval:', error);
      return [];
    }
  }

  // Bulk approve multiple content items
  async bulkApprove(contentIds: string[], context: WorkflowContext): Promise<{
    success: number;
    failed: Array<{ id: string; error: string }>;
  }> {
    const results = { success: 0, failed: [] as Array<{ id: string; error: string }> };

    for (const contentId of contentIds) {
      const result = await this.executeWorkflowAction(contentId, 'approve', context);
      if (result.success) {
        results.success++;
      } else {
        results.failed.push({ id: contentId, error: result.error || 'Unknown error' });
      }
    }

    return results;
  }

  // Log workflow action for analytics
  private async logWorkflowAction(
    contentId: string,
    action: ApprovalAction,
    fromStatus: ContentStatus,
    toStatus: ContentStatus,
    context: WorkflowContext
  ): Promise<void> {
    try {
      await prisma.analytics.create({
        data: {
          eventType: this.getAnalyticsEventType(action),
          eventName: `content_${action}`,
          contentId,
          metadata: JSON.stringify({
            action,
            fromStatus,
            toStatus,
            userId: context.userId,
            userRole: context.userRole,
            comment: context.comment,
            timestamp: new Date()
          })
        }
      });
    } catch (error) {
      // Don't fail the main operation if analytics logging fails
      console.error('Failed to log workflow action:', error);
    }
  }

  // Get default comment for actions that don't require explicit comments
  private getDefaultCommentForAction(action: ApprovalAction): string {
    const defaultComments = {
      approve: 'Content approved for publication',
      publish: 'Content published',
      submit_for_review: 'Submitted for review',
      archive: 'Content archived',
      revert_to_draft: 'Reverted to draft status'
    };

    return defaultComments[action as keyof typeof defaultComments] || `Action: ${action}`;
  }

  // Map workflow actions to analytics event types
  private getAnalyticsEventType(action: ApprovalAction): string {
    const eventTypeMap = {
      approve: 'CONTENT_APPROVE',
      reject: 'CONTENT_APPROVE', // Same event type, different outcome
      publish: 'CONTENT_PUBLISH',
      request_revision: 'CONTENT_APPROVE'
    };

    return eventTypeMap[action as keyof typeof eventTypeMap] || 'CUSTOM';
  }
}

export const approvalActions = new ApprovalActions();