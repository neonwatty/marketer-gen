import { ContentStatus, ApprovalStatus } from '@prisma/client';

export type WorkflowState = ContentStatus;
export type ApprovalAction = 
  | 'submit_for_review' 
  | 'approve' 
  | 'reject' 
  | 'request_revision' 
  | 'publish' 
  | 'archive'
  | 'revert_to_draft';

export interface WorkflowTransition {
  from: WorkflowState;
  to: WorkflowState;
  action: ApprovalAction;
  approvalStatus?: ApprovalStatus;
  requiresRole?: string[];
  requiresComment?: boolean;
}

export interface WorkflowContext {
  contentId: string;
  userId?: string;
  userRole?: string;
  comment?: string;
  metadata?: Record<string, any>;
}

export interface WorkflowResult {
  success: boolean;
  newState?: WorkflowState;
  newApprovalStatus?: ApprovalStatus;
  error?: string;
  requiresPermission?: string[];
}

// Define the workflow state machine transitions
export const WORKFLOW_TRANSITIONS: WorkflowTransition[] = [
  // From DRAFT
  {
    from: 'DRAFT',
    to: 'REVIEWING',
    action: 'submit_for_review',
    approvalStatus: 'PENDING',
  },
  {
    from: 'DRAFT',
    to: 'ARCHIVED',
    action: 'archive',
    approvalStatus: 'REJECTED',
  },

  // From GENERATED (after AI generation)
  {
    from: 'GENERATED',
    to: 'REVIEWING',
    action: 'submit_for_review',
    approvalStatus: 'PENDING',
  },
  {
    from: 'GENERATED',
    to: 'DRAFT',
    action: 'revert_to_draft',
    approvalStatus: 'PENDING',
  },
  {
    from: 'GENERATED',
    to: 'ARCHIVED',
    action: 'archive',
    approvalStatus: 'REJECTED',
  },

  // From REVIEWING
  {
    from: 'REVIEWING',
    to: 'APPROVED',
    action: 'approve',
    approvalStatus: 'APPROVED',
    requiresRole: ['approver', 'admin'],
  },
  {
    from: 'REVIEWING',
    to: 'DRAFT',
    action: 'reject',
    approvalStatus: 'REJECTED',
    requiresRole: ['approver', 'admin'],
    requiresComment: true,
  },
  {
    from: 'REVIEWING',
    to: 'DRAFT',
    action: 'request_revision',
    approvalStatus: 'NEEDS_REVISION',
    requiresRole: ['approver', 'admin'],
    requiresComment: true,
  },

  // From APPROVED
  {
    from: 'APPROVED',
    to: 'PUBLISHED',
    action: 'publish',
    approvalStatus: 'APPROVED',
    requiresRole: ['publisher', 'admin'],
  },
  {
    from: 'APPROVED',
    to: 'REVIEWING',
    action: 'revert_to_draft',
    approvalStatus: 'PENDING',
    requiresRole: ['admin'],
  },
  {
    from: 'APPROVED',
    to: 'ARCHIVED',
    action: 'archive',
    approvalStatus: 'APPROVED',
    requiresRole: ['admin'],
  },

  // From PUBLISHED
  {
    from: 'PUBLISHED',
    to: 'ARCHIVED',
    action: 'archive',
    approvalStatus: 'APPROVED',
    requiresRole: ['admin'],
  },

  // From ARCHIVED (limited recovery options)
  {
    from: 'ARCHIVED',
    to: 'DRAFT',
    action: 'revert_to_draft',
    approvalStatus: 'PENDING',
    requiresRole: ['admin'],
  },
];

// Workflow state machine class
export class ApprovalWorkflow {
  private transitions: Map<string, WorkflowTransition[]>;

  constructor() {
    this.transitions = new Map();
    
    // Group transitions by 'from' state for efficient lookup
    WORKFLOW_TRANSITIONS.forEach(transition => {
      const key = transition.from;
      if (!this.transitions.has(key)) {
        this.transitions.set(key, []);
      }
      this.transitions.get(key)!.push(transition);
    });
  }

  // Get available actions for a given state
  getAvailableActions(state: WorkflowState, userRole?: string): ApprovalAction[] {
    const stateTransitions = this.transitions.get(state) || [];
    
    return stateTransitions
      .filter(transition => {
        // Check role requirements
        if (transition.requiresRole && userRole) {
          return transition.requiresRole.includes(userRole);
        }
        // If no role required or no user role provided, allow the action
        return !transition.requiresRole;
      })
      .map(transition => transition.action);
  }

  // Check if a transition is valid
  canTransition(
    fromState: WorkflowState,
    action: ApprovalAction,
    context: WorkflowContext
  ): WorkflowResult {
    const stateTransitions = this.transitions.get(fromState) || [];
    const transition = stateTransitions.find(t => t.action === action);

    if (!transition) {
      return {
        success: false,
        error: `Action '${action}' is not valid for state '${fromState}'`
      };
    }

    // Check role requirements
    if (transition.requiresRole && context.userRole) {
      if (!transition.requiresRole.includes(context.userRole)) {
        return {
          success: false,
          error: `User role '${context.userRole}' does not have permission for action '${action}'`,
          requiresPermission: transition.requiresRole
        };
      }
    } else if (transition.requiresRole && !context.userRole) {
      return {
        success: false,
        error: `Action '${action}' requires one of the following roles: ${transition.requiresRole.join(', ')}`,
        requiresPermission: transition.requiresRole
      };
    }

    // Check comment requirements
    if (transition.requiresComment && !context.comment) {
      return {
        success: false,
        error: `Action '${action}' requires a comment`
      };
    }

    return {
      success: true,
      newState: transition.to,
      newApprovalStatus: transition.approvalStatus
    };
  }

  // Execute a workflow transition
  async executeTransition(
    fromState: WorkflowState,
    action: ApprovalAction,
    context: WorkflowContext
  ): Promise<WorkflowResult> {
    const validationResult = this.canTransition(fromState, action, context);
    
    if (!validationResult.success) {
      return validationResult;
    }

    // Here you would typically update the database
    // For now, we return the successful transition result
    return validationResult;
  }

  // Get workflow state display information
  getStateInfo(state: WorkflowState): {
    label: string;
    description: string;
    color: string;
    icon?: string;
  } {
    const stateInfo = {
      DRAFT: {
        label: 'Draft',
        description: 'Content is being created or edited',
        color: 'gray',
        icon: 'file-edit'
      },
      GENERATING: {
        label: 'Generating',
        description: 'AI is generating content',
        color: 'blue',
        icon: 'loader'
      },
      GENERATED: {
        label: 'Generated',
        description: 'Content has been generated and is ready for review',
        color: 'purple',
        icon: 'sparkles'
      },
      REVIEWING: {
        label: 'Under Review',
        description: 'Content is being reviewed for approval',
        color: 'yellow',
        icon: 'eye'
      },
      APPROVED: {
        label: 'Approved',
        description: 'Content has been approved and is ready to publish',
        color: 'green',
        icon: 'check-circle'
      },
      PUBLISHED: {
        label: 'Published',
        description: 'Content has been published and is live',
        color: 'emerald',
        icon: 'globe'
      },
      ARCHIVED: {
        label: 'Archived',
        description: 'Content has been archived',
        color: 'slate',
        icon: 'archive'
      }
    };

    return stateInfo[state] || stateInfo.DRAFT;
  }

  // Get approval status display information
  getApprovalStatusInfo(status: ApprovalStatus): {
    label: string;
    description: string;
    color: string;
    icon?: string;
  } {
    const statusInfo = {
      PENDING: {
        label: 'Pending Review',
        description: 'Waiting for approval',
        color: 'yellow',
        icon: 'clock'
      },
      APPROVED: {
        label: 'Approved',
        description: 'Content has been approved',
        color: 'green',
        icon: 'check-circle'
      },
      REJECTED: {
        label: 'Rejected',
        description: 'Content has been rejected',
        color: 'red',
        icon: 'x-circle'
      },
      NEEDS_REVISION: {
        label: 'Needs Revision',
        description: 'Content needs to be revised based on feedback',
        color: 'orange',
        icon: 'edit'
      }
    };

    return statusInfo[status] || statusInfo.PENDING;
  }

  // Get the workflow diagram/flow for visualization
  getWorkflowDiagram(): {
    states: { id: string; label: string; color: string }[];
    transitions: { from: string; to: string; label: string; requiresRole?: string[] }[];
  } {
    const states = Object.values(ContentStatus).map(state => {
      const info = this.getStateInfo(state);
      return {
        id: state,
        label: info.label,
        color: info.color
      };
    });

    const transitions = WORKFLOW_TRANSITIONS.map(transition => ({
      from: transition.from,
      to: transition.to,
      label: transition.action.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase()),
      requiresRole: transition.requiresRole
    }));

    return { states, transitions };
  }
}

// Export a singleton instance
export const approvalWorkflow = new ApprovalWorkflow();

// Helper functions for common workflow operations
export const getNextStates = (currentState: WorkflowState, userRole?: string): WorkflowState[] => {
  const actions = approvalWorkflow.getAvailableActions(currentState, userRole);
  const nextStates: WorkflowState[] = [];
  
  actions.forEach(action => {
    const result = approvalWorkflow.canTransition(currentState, action, { 
      contentId: '', 
      userRole 
    });
    if (result.success && result.newState) {
      nextStates.push(result.newState);
    }
  });
  
  return Array.from(new Set(nextStates)); // Remove duplicates
};

export const canUserPerformAction = (
  currentState: WorkflowState,
  action: ApprovalAction,
  userRole?: string
): boolean => {
  const result = approvalWorkflow.canTransition(currentState, action, {
    contentId: '',
    userRole
  });
  return result.success;
};

export const getRequiredRolesForAction = (
  currentState: WorkflowState,
  action: ApprovalAction
): string[] => {
  const stateTransitions = approvalWorkflow['transitions'].get(currentState) || [];
  const transition = stateTransitions.find(t => t.action === action);
  return transition?.requiresRole || [];
};