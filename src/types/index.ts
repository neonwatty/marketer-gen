// Common base types
export type ID = string | number

export interface BaseEntity {
  id: ID
  createdAt: Date
  updatedAt: Date
}

// User and Authentication Types
export interface User extends BaseEntity {
  email: string
  name: string
  avatar?: string
  role: UserRole
  preferences: UserPreferences
}

export type UserRole = 
  | 'viewer'
  | 'creator'
  | 'reviewer'
  | 'approver' 
  | 'publisher'
  | 'admin'

export interface UserPreferences {
  theme: "light" | "dark" | "auto"
  notifications: boolean
  language: string
}

// Team and Collaboration Types
export interface Team extends BaseEntity {
  name: string
  description?: string
  ownerId: ID
  members: TeamMember[]
  settings: TeamSettings
}

export interface TeamMember {
  userId: ID
  user: User
  role: TeamRole
  permissions: TeamPermissions
  joinedAt: Date
  invitedBy?: ID
}

export type TeamRole = 'owner' | 'admin' | 'member' | 'guest'

export interface TeamPermissions {
  canInviteMembers: boolean
  canRemoveMembers: boolean
  canManageRoles: boolean
  canEditTeamSettings: boolean
  canViewAllProjects: boolean
  canCreateProjects: boolean
  canDeleteProjects: boolean
}

export interface TeamSettings {
  visibility: 'private' | 'internal' | 'public'
  defaultMemberRole: TeamRole
  requireApprovalForJoining: boolean
  allowGuestAccess: boolean
}

export interface TeamInvitation extends BaseEntity {
  teamId: ID
  email: string
  role: TeamRole
  invitedBy: ID
  expiresAt: Date
  status: 'pending' | 'accepted' | 'declined' | 'expired'
  token: string
}

// Campaign Types
export interface Campaign extends BaseEntity {
  name: string
  description?: string
  status: CampaignStatus
  type: CampaignType
  startDate?: Date
  endDate?: Date
  budget?: number
  tags: string[]
  userId: ID
  assets: Asset[]
  journeys: Journey[]
}

export type CampaignStatus = "draft" | "active" | "paused" | "completed" | "archived"
export type CampaignType = "email" | "social" | "web" | "print" | "video" | "mixed"

// Content and Asset Types
export interface Asset extends BaseEntity {
  name: string
  type: AssetType
  url?: string
  content?: string
  metadata: AssetMetadata
  campaignId?: ID
  tags: string[]
}

export type AssetType = "text" | "image" | "video" | "audio" | "template" | "other"

export interface AssetMetadata {
  size?: number
  dimensions?: { width: number; height: number }
  duration?: number
  format?: string
  [key: string]: unknown
}

// Journey and Template Types
export interface Journey extends BaseEntity {
  name: string
  description?: string
  campaignId: ID
  steps: JourneyStep[]
  status: "draft" | "active" | "inactive"
}

export interface JourneyStep {
  id: ID
  name: string
  type: "email" | "wait" | "condition" | "action"
  config: Record<string, unknown>
  order: number
}

// AI and Content Generation Types
export interface ContentRequest {
  prompt: string
  type: "copy" | "subject_line" | "headline" | "description"
  tone: "professional" | "casual" | "friendly" | "urgent" | "creative"
  length: "short" | "medium" | "long"
  context?: string
}

export interface ContentResponse {
  content: string[]
  confidence: number
  metadata: {
    model: string
    timestamp: Date
    tokens: number
  }
}

// LLM API Types
export interface LLMRequest {
  prompt: string
  model?: string
  maxTokens?: number
  temperature?: number
  systemPrompt?: string
  context?: string[]
}

export interface LLMResponse {
  id: string
  content: string
  model: string
  usage: {
    promptTokens: number
    completionTokens: number
    totalTokens: number
  }
  finishReason: "stop" | "length" | "content_filter" | "error"
  metadata: {
    requestId: string
    timestamp: Date
    processingTime: number
  }
}

export interface LLMError {
  code: string
  message: string
  type: "rate_limit" | "invalid_request" | "server_error" | "auth_error"
  retryAfter?: number
}

export interface LLMStreamChunk {
  id: string
  delta: string
  isComplete: boolean
  metadata?: {
    tokenCount: number
    model: string
  }
}

// Form and UI Types
export interface FormState<T = Record<string, unknown>> {
  data: T
  errors: Record<string, string>
  isSubmitting: boolean
  isDirty: boolean
}

export interface SelectOption<T = string> {
  label: string
  value: T
  disabled?: boolean
}

// API Response Types
export interface ApiResponse<T = unknown> {
  data?: T
  error?: string
  message?: string
  success: boolean
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
  pagination: {
    page: number
    limit: number
    total: number
    totalPages: number
  }
}

// Error Types
export interface AppError {
  code: string
  message: string
  details?: Record<string, unknown>
}

// Feature Flag Types
export interface FeatureFlags {
  aiContentGeneration: boolean
  advancedAnalytics: boolean
  teamCollaboration: boolean
  customBranding: boolean
}

// Collaboration and Workflow Types
export interface Comment extends BaseEntity {
  content: string
  authorId: ID
  author: User
  targetType: 'campaign' | 'asset' | 'journey'
  targetId: ID
  parentCommentId?: ID
  replies?: Comment[]
  reactions: CommentReaction[]
  mentions: ID[]
  isResolved: boolean
  resolvedBy?: ID
  resolvedAt?: Date
}

export interface CommentReaction {
  userId: ID
  user: User
  type: 'like' | 'dislike' | 'love' | 'laugh' | 'angry' | 'sad'
  createdAt: Date
}

export interface ApprovalWorkflow extends BaseEntity {
  name: string
  description?: string
  teamId: ID
  stages: ApprovalStage[]
  isActive: boolean
  applicableTypes: ('campaign' | 'asset' | 'journey')[]
  autoStart?: boolean
  allowParallelStages?: boolean
  requireAllApprovers?: boolean
  defaultTimeoutHours?: number
  createdBy: ID
  conditionRules?: string
  metadata?: Record<string, unknown>
}

export interface ApprovalStage {
  id: ID
  name: string
  description?: string
  order: number
  approversRequired: number
  approvers: ID[]
  approverRoles?: UserRole[]
  autoApprove: boolean
  timeoutHours?: number
  skipConditions?: ApprovalCondition[]
  escalationRules?: string
}

export interface ApprovalCondition {
  type: 'user_role' | 'content_type' | 'budget_threshold' | 'custom'
  operator: 'equals' | 'not_equals' | 'greater_than' | 'less_than' | 'contains'
  value: string | number
}

export interface ApprovalRequest extends BaseEntity {
  workflowId: ID
  workflow: ApprovalWorkflow
  targetType: 'campaign' | 'asset' | 'journey'
  targetId: ID
  requesterId: ID
  requester: User
  currentStageId?: ID
  currentStage?: ApprovalStage
  status: 'pending' | 'in_progress' | 'approved' | 'rejected' | 'cancelled' | 'expired' | 'escalated'
  priority?: 'low' | 'medium' | 'high' | 'urgent'
  approvals: ApprovalAction[]
  dueDate?: Date
  notes?: string
  completedAt?: Date
  escalatedAt?: Date
  escalationLevel?: number
  metadata?: Record<string, unknown>
}

export interface ApprovalAction extends BaseEntity {
  requestId: ID
  stageId: ID
  approverId: ID
  approver: User
  action: 'approve' | 'reject' | 'request_changes' | 'delegate' | 'escalate' | 'cancel'
  comment?: string
  attachments?: string[]
  ipAddress?: string
  userAgent?: string
  metadata?: Record<string, unknown>
}

export interface Notification extends BaseEntity {
  userId: ID
  user: User
  type: 'approval_request' | 'comment_mention' | 'workflow_update' | 'team_invitation' | 'system'
  title: string
  message: string
  isRead: boolean
  readAt?: Date
  actionUrl?: string
  metadata?: Record<string, unknown>
  priority: 'low' | 'medium' | 'high' | 'urgent'
}

export interface AuditLog extends BaseEntity {
  userId: ID
  user: User
  action: string
  targetType: string
  targetId: ID
  oldValues?: Record<string, unknown>
  newValues?: Record<string, unknown>
  metadata?: Record<string, unknown>
  ipAddress?: string
  userAgent?: string
}

// Workflow Template types
export interface WorkflowTemplate extends BaseEntity {
  name: string
  description?: string
  category: 'MARKETING' | 'CONTENT' | 'BRAND' | 'COMPLIANCE' | 'GENERAL'
  applicableTypes: string[]
  isPublic: boolean
  usageCount: number
  createdBy: ID
  tags?: string[]
  metadata?: Record<string, unknown>
  stages: WorkflowTemplateStage[]
}

export interface WorkflowTemplateStage {
  id: ID
  name: string
  description?: string
  order: number
  approversRequired: number
  approverRoles?: UserRole[]
  autoApprove: boolean
  timeoutHours?: number
  skipConditions?: string[]
}

// Workflow Engine types
export type WorkflowEventType = 
  | 'workflow_started'
  | 'stage_entered'
  | 'stage_completed'
  | 'stage_timeout'
  | 'workflow_completed'
  | 'workflow_rejected'
  | 'workflow_cancelled'
  | 'escalation_triggered'

export interface WorkflowEvent {
  type: WorkflowEventType
  requestId: string
  stageId?: string
  userId?: string
  timestamp: Date
  metadata?: Record<string, unknown>
}

export interface WorkflowExecutionContext {
  request: ApprovalRequest
  workflow: ApprovalWorkflow
  targetContent: any
  currentUser?: User
}

export interface StageValidationResult {
  canProceed: boolean
  shouldSkip: boolean
  reason?: string
  nextStageId?: string
}

export interface WorkflowNotification {
  type: 'approval_request' | 'approval_reminder' | 'approval_completed' | 'approval_timeout'
  recipientId: string
  title: string
  message: string
  actionUrl?: string
  priority: 'low' | 'medium' | 'high' | 'urgent'
  metadata?: Record<string, unknown>
}

export interface WorkflowMetrics {
  workflowId: ID
  totalRequests: number
  completedRequests: number
  averageCompletionTime: number
  approvalRate: number
  escalationRate: number
  timeoutRate: number
  bottleneckStages: Array<{
    stageId: ID
    stageName: string
    averageTime: number
    timeoutCount: number
  }>
}