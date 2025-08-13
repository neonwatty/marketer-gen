import { 
  ApprovalWorkflow, 
  ApprovalStage, 
  ApprovalRequest, 
  ApprovalAction, 
  ApprovalCondition,
  UserRole,
  User,
  WorkflowEventType,
  WorkflowEvent,
  WorkflowExecutionContext,
  StageValidationResult,
  WorkflowNotification
} from '@/types'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

export class WorkflowEngine {
  private eventHandlers: Map<WorkflowEventType, ((event: WorkflowEvent) => void)[]> = new Map()
  
  constructor() {
    // Initialize event handlers
    this.initializeEventHandlers()
  }

  private initializeEventHandlers() {
    // Set up default event handlers
    this.on('workflow_started', this.handleWorkflowStarted.bind(this))
    this.on('stage_entered', this.handleStageEntered.bind(this))
    this.on('stage_completed', this.handleStageCompleted.bind(this))
    this.on('stage_timeout', this.handleStageTimeout.bind(this))
    this.on('workflow_completed', this.handleWorkflowCompleted.bind(this))
  }

  // Event system
  on(eventType: WorkflowEventType, handler: (event: WorkflowEvent) => void) {
    if (!this.eventHandlers.has(eventType)) {
      this.eventHandlers.set(eventType, [])
    }
    this.eventHandlers.get(eventType)!.push(handler)
  }

  private emit(event: WorkflowEvent) {
    const handlers = this.eventHandlers.get(event.type) || []
    handlers.forEach(handler => {
      try {
        handler(event)
      } catch (error) {
        console.error(`Error handling workflow event ${event.type}:`, error)
      }
    })
  }

  // Main workflow operations
  async startWorkflow(
    workflowId: string,
    targetType: string,
    targetId: string,
    requesterId: string,
    notes?: string,
    dueDate?: Date,
    priority: 'low' | 'medium' | 'high' | 'urgent' = 'medium'
  ): Promise<ApprovalRequest> {
    // Fetch workflow from database
    const workflow = await this.getWorkflowById(workflowId)
    if (!workflow) {
      throw new Error('Workflow not found')
    }

    // Validate workflow
    if (!workflow.isActive) {
      throw new Error('Workflow is not active')
    }

    if (workflow.stages.length === 0) {
      throw new Error('Workflow has no stages defined')
    }

    // Sort stages by order
    const sortedStages = [...workflow.stages].sort((a, b) => a.order - b.order)
    const firstStage = sortedStages[0]

    // Create approval request
    const request: ApprovalRequest = {
      id: `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      workflowId: workflow.id,
      workflow,
      targetType: targetType as any,
      targetId,
      requesterId,
      requester: { id: requesterId } as User, // Would be properly populated
      currentStageId: firstStage.id,
      currentStage: firstStage,
      status: 'pending',
      priority,
      approvals: [],
      notes,
      dueDate,
      createdAt: new Date(),
      updatedAt: new Date()
    }

    // Save to database
    const savedRequest = await this.saveApprovalRequest(request)

    // Emit workflow started event
    this.emit({
      type: 'workflow_started',
      requestId: savedRequest.id.toString(),
      stageId: firstStage.id.toString(),
      userId: requesterId,
      timestamp: new Date(),
      metadata: { workflowId: workflow.id, targetType, targetId }
    })

    // Generate notifications for first stage approvers
    const notifications = await this.generateStageEntryNotifications(savedRequest, firstStage)
    
    // TODO: Send notifications through notification system
    console.log(`Generated ${notifications.length} notifications for workflow start`)

    return savedRequest
  }

  async processApprovalAction(
    requestId: string,
    stageId: string,
    approverId: string,
    action: 'approve' | 'reject' | 'request_changes' | 'delegate' | 'escalate',
    comment?: string,
    metadata?: Record<string, unknown>
  ): Promise<{ request: ApprovalRequest; notifications: WorkflowNotification[] }> {
    
    // Fetch current request from database
    const request = await this.getApprovalRequest(requestId)
    if (!request) {
      throw new Error('Approval request not found')
    }

    const stage = request.workflow.stages.find(s => s.id.toString() === stageId)
    if (!stage) {
      throw new Error('Stage not found')
    }

    if (request.currentStageId?.toString() !== stageId) {
      throw new Error('Cannot approve non-current stage')
    }

    // Validate approver has permission
    await this.validateApproverPermission(stage, approverId)

    // Create approval action
    const approvalAction: ApprovalAction = {
      id: `action_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      requestId: request.id,
      stageId,
      approverId,
      approver: { id: approverId } as User, // Would be populated from DB
      action,
      comment,
      attachments: [],
      metadata,
      createdAt: new Date(),
      updatedAt: new Date()
    }

    // Save action to database
    await this.saveApprovalAction(approvalAction)

    // Add action to request
    const updatedRequest = {
      ...request,
      approvals: [...request.approvals, approvalAction],
      updatedAt: new Date()
    }

    let notifications: WorkflowNotification[] = []

    switch (action) {
      case 'approve':
        const approveResult = await this.handleApprove(updatedRequest, stage, approvalAction)
        updatedRequest.status = approveResult.status
        if (approveResult.nextStageId) {
          updatedRequest.currentStageId = approveResult.nextStageId
          const nextStage = updatedRequest.workflow.stages.find(s => s.id.toString() === approveResult.nextStageId)
          updatedRequest.currentStage = nextStage
        } else {
          updatedRequest.currentStageId = undefined
          updatedRequest.currentStage = undefined
          updatedRequest.completedAt = new Date()
        }
        notifications = approveResult.notifications
        break

      case 'reject':
        updatedRequest.status = 'rejected'
        updatedRequest.completedAt = new Date()
        notifications = await this.generateRejectionNotifications(updatedRequest, approvalAction)
        break

      case 'request_changes':
        // Keep status as pending but notify requester
        notifications = await this.generateChangeRequestNotifications(updatedRequest, approvalAction)
        break

      case 'delegate':
        // Handle delegation logic
        notifications = await this.handleDelegation(updatedRequest, stage, approvalAction, metadata)
        break

      case 'escalate':
        updatedRequest.status = 'escalated'
        updatedRequest.escalatedAt = new Date()
        updatedRequest.escalationLevel = (updatedRequest.escalationLevel || 0) + 1
        notifications = await this.generateEscalationNotifications(updatedRequest, approvalAction)
        break
    }

    // Save updated request to database
    const finalRequest = await this.saveApprovalRequest(updatedRequest)

    // TODO: Send notifications through notification system
    console.log(`Generated ${notifications.length} notifications for action: ${action}`)

    return { request: finalRequest, notifications }
  }

  private async handleApprove(
    request: ApprovalRequest,
    currentStage: ApprovalStage,
    action: ApprovalAction
  ): Promise<{ status: any; nextStageId?: string; notifications: WorkflowNotification[] }> {
    
    // Count approvals for current stage
    const stageApprovals = request.approvals.filter(
      a => a.stageId === currentStage.id && a.action === 'approve'
    )

    const approvalsNeeded = currentStage.approversRequired
    const approvalsReceived = stageApprovals.length

    // Check if stage is complete
    if (approvalsReceived >= approvalsNeeded) {
      // Stage is complete, move to next stage or complete workflow
      const sortedStages = [...request.workflow.stages].sort((a, b) => a.order - b.order)
      const currentIndex = sortedStages.findIndex(s => s.id === currentStage.id)
      
      // Emit stage completed event
      this.emit({
        type: 'stage_completed',
        requestId: request.id,
        stageId: currentStage.id,
        timestamp: new Date()
      })

      if (currentIndex < sortedStages.length - 1) {
        // Move to next stage
        const nextStage = sortedStages[currentIndex + 1]
        
        // Check if next stage should be skipped
        const skipCheck = await this.shouldSkipStage(nextStage, request)
        if (skipCheck.shouldSkip && skipCheck.nextStageId) {
          // Recursively check next stages
          return this.handleApprove(request, nextStage, action)
        }

        // Emit stage entered event
        this.emit({
          type: 'stage_entered',
          requestId: request.id,
          stageId: nextStage.id,
          timestamp: new Date()
        })

        return {
          status: 'in_progress',
          nextStageId: nextStage.id,
          notifications: await this.generateStageEntryNotifications(request, nextStage)
        }
      } else {
        // Workflow complete
        this.emit({
          type: 'workflow_completed',
          requestId: request.id,
          timestamp: new Date()
        })

        return {
          status: 'approved',
          notifications: await this.generateCompletionNotifications(request)
        }
      }
    }

    // Stage not complete yet, generate notifications for remaining approvers
    return {
      status: 'in_progress',
      nextStageId: currentStage.id,
      notifications: await this.generatePendingApprovalNotifications(request, currentStage)
    }
  }

  private async shouldSkipStage(
    stage: ApprovalStage,
    request: ApprovalRequest
  ): Promise<{ shouldSkip: boolean; nextStageId?: string }> {
    
    if (!stage.skipConditions || stage.skipConditions.length === 0) {
      return { shouldSkip: false }
    }

    // Evaluate skip conditions
    for (const condition of stage.skipConditions) {
      const conditionMet = await this.evaluateCondition(condition, request)
      if (conditionMet) {
        // Find next stage
        const sortedStages = [...request.workflow.stages].sort((a, b) => a.order - b.order)
        const currentIndex = sortedStages.findIndex(s => s.id === stage.id)
        
        if (currentIndex < sortedStages.length - 1) {
          return { shouldSkip: true, nextStageId: sortedStages[currentIndex + 1].id }
        } else {
          // No more stages, workflow complete
          return { shouldSkip: true }
        }
      }
    }

    return { shouldSkip: false }
  }

  private async evaluateCondition(
    condition: ApprovalCondition,
    request: ApprovalRequest
  ): Promise<boolean> {
    
    switch (condition.type) {
      case 'user_role':
        // Check requester role
        // In real implementation, fetch user role from database
        return this.compareValues(
          'creator', // Would be fetched from DB
          condition.operator,
          condition.value
        )

      case 'content_type':
        return this.compareValues(
          request.targetType,
          condition.operator,
          condition.value
        )

      case 'budget_threshold':
        // Would need to fetch budget from target content
        const budget = 0 // Placeholder
        return this.compareValues(
          budget,
          condition.operator,
          condition.value
        )

      case 'custom':
        // Custom condition evaluation
        return this.evaluateCustomCondition(condition, request)

      default:
        return false
    }
  }

  private compareValues(
    actual: string | number,
    operator: string,
    expected: string | number
  ): boolean {
    
    switch (operator) {
      case 'equals':
        return actual === expected
      case 'not_equals':
        return actual !== expected
      case 'greater_than':
        return Number(actual) > Number(expected)
      case 'less_than':
        return Number(actual) < Number(expected)
      case 'contains':
        return String(actual).toLowerCase().includes(String(expected).toLowerCase())
      default:
        return false
    }
  }

  private async evaluateCustomCondition(
    condition: ApprovalCondition,
    request: ApprovalRequest
  ): Promise<boolean> {
    // Implement custom condition logic
    // This could involve complex business rules
    return false
  }

  private async validateApproverPermission(
    stage: ApprovalStage,
    approverId: string
  ): Promise<void> {
    
    // Check if user is in stage approvers list
    const approverIds = Array.isArray(stage.approvers) 
      ? stage.approvers.map(String)
      : JSON.parse(stage.approvers || '[]')
    
    if (approverIds.includes(approverId)) {
      return // User is explicitly allowed
    }

    // Check if user has required role
    const approverRoles = stage.approverRoles || []
    if (approverRoles.length > 0) {
      // In real implementation, fetch user role from database
      const userRole: UserRole = 'creator' // Placeholder
      if (approverRoles.includes(userRole)) {
        return // User has required role
      }
    }

    throw new Error('User does not have permission to approve this stage')
  }

  // Notification generators
  private async generateStageEntryNotifications(
    request: ApprovalRequest,
    stage: ApprovalStage
  ): Promise<WorkflowNotification[]> {
    
    const notifications: WorkflowNotification[] = []
    
    // Get approvers for this stage
    const approverIds = Array.isArray(stage.approvers) 
      ? stage.approvers.map(String)
      : JSON.parse(stage.approvers || '[]')

    // Create notifications for each approver
    for (const approverId of approverIds) {
      notifications.push({
        type: 'approval_request',
        recipientId: approverId,
        title: `Approval Required: ${stage.name}`,
        message: `A ${request.targetType} requires your approval in the "${stage.name}" stage.`,
        actionUrl: `/approvals/${request.id}`,
        priority: 'medium',
        metadata: {
          requestId: request.id,
          stageId: stage.id,
          workflowId: request.workflowId
        }
      })
    }

    return notifications
  }

  private async generateCompletionNotifications(
    request: ApprovalRequest
  ): Promise<WorkflowNotification[]> {
    
    return [{
      type: 'approval_completed',
      recipientId: request.requesterId,
      title: 'Approval Complete',
      message: `Your ${request.targetType} has been fully approved and is ready for publication.`,
      actionUrl: `/content/${request.targetId}`,
      priority: 'high',
      metadata: {
        requestId: request.id,
        workflowId: request.workflowId
      }
    }]
  }

  private async generateRejectionNotifications(
    request: ApprovalRequest,
    action: ApprovalAction
  ): Promise<WorkflowNotification[]> {
    
    return [{
      type: 'approval_completed',
      recipientId: request.requesterId,
      title: 'Approval Rejected',
      message: `Your ${request.targetType} has been rejected. ${action.comment || ''}`,
      actionUrl: `/content/${request.targetId}`,
      priority: 'high',
      metadata: {
        requestId: request.id,
        rejectedBy: action.approverId,
        comment: action.comment
      }
    }]
  }

  private async generateChangeRequestNotifications(
    request: ApprovalRequest,
    action: ApprovalAction
  ): Promise<WorkflowNotification[]> {
    
    return [{
      type: 'approval_request',
      recipientId: request.requesterId,
      title: 'Changes Requested',
      message: `Changes have been requested for your ${request.targetType}. ${action.comment || ''}`,
      actionUrl: `/content/${request.targetId}`,
      priority: 'medium',
      metadata: {
        requestId: request.id,
        requestedBy: action.approverId,
        comment: action.comment
      }
    }]
  }

  private async generateEscalationNotifications(
    request: ApprovalRequest,
    action: ApprovalAction
  ): Promise<WorkflowNotification[]> {
    
    // Notify team leads or admins about escalation
    return [{
      type: 'approval_request',
      recipientId: 'admin', // Would be determined by escalation rules
      title: 'Approval Escalated',
      message: `An approval for ${request.targetType} has been escalated and requires immediate attention.`,
      actionUrl: `/approvals/${request.id}`,
      priority: 'urgent',
      metadata: {
        requestId: request.id,
        escalatedBy: action.approverId,
        escalationLevel: request.escalationLevel
      }
    }]
  }

  private async generatePendingApprovalNotifications(
    request: ApprovalRequest,
    stage: ApprovalStage
  ): Promise<WorkflowNotification[]> {
    
    // Generate reminder notifications for remaining approvers
    const approverIds = Array.isArray(stage.approvers) 
      ? stage.approvers.map(String)
      : JSON.parse(stage.approvers || '[]')

    const completedApprovers = request.approvals
      .filter(a => a.stageId === stage.id && a.action === 'approve')
      .map(a => a.approverId)

    const pendingApprovers = approverIds.filter(id => !completedApprovers.includes(id))

    return pendingApprovers.map(approverId => ({
      type: 'approval_reminder' as const,
      recipientId: approverId,
      title: 'Approval Reminder',
      message: `Your approval is still needed for a ${request.targetType} in the "${stage.name}" stage.`,
      actionUrl: `/approvals/${request.id}`,
      priority: 'medium' as const,
      metadata: {
        requestId: request.id,
        stageId: stage.id
      }
    }))
  }

  private async handleDelegation(
    request: ApprovalRequest,
    stage: ApprovalStage,
    action: ApprovalAction,
    metadata?: Record<string, unknown>
  ): Promise<WorkflowNotification[]> {
    
    const delegateToId = metadata?.delegateToId as string
    if (!delegateToId) {
      throw new Error('Delegation target not specified')
    }

    // Create notification for delegate
    return [{
      type: 'approval_request',
      recipientId: delegateToId,
      title: 'Approval Delegated to You',
      message: `An approval for ${request.targetType} has been delegated to you by another team member.`,
      actionUrl: `/approvals/${request.id}`,
      priority: 'medium',
      metadata: {
        requestId: request.id,
        stageId: stage.id,
        delegatedBy: action.approverId
      }
    }]
  }

  // Event handlers
  private handleWorkflowStarted(event: WorkflowEvent) {
    console.log(`Workflow started: ${event.requestId}`)
  }

  private handleStageEntered(event: WorkflowEvent) {
    console.log(`Stage entered: ${event.stageId} for request ${event.requestId}`)
  }

  private handleStageCompleted(event: WorkflowEvent) {
    console.log(`Stage completed: ${event.stageId} for request ${event.requestId}`)
  }

  private handleStageTimeout(event: WorkflowEvent) {
    console.log(`Stage timeout: ${event.stageId} for request ${event.requestId}`)
    // Handle timeout logic - escalation, auto-approval, etc.
  }

  private handleWorkflowCompleted(event: WorkflowEvent) {
    console.log(`Workflow completed: ${event.requestId}`)
  }

  // Database integration methods
  async saveApprovalRequest(request: ApprovalRequest): Promise<ApprovalRequest> {
    try {
      const savedRequest = await prisma.approvalRequest.upsert({
        where: { id: request.id.toString() },
        update: {
          status: request.status as any,
          priority: request.priority as any,
          currentStageId: request.currentStageId?.toString(),
          notes: request.notes,
          dueDate: request.dueDate,
          completedAt: request.completedAt,
          escalatedAt: request.escalatedAt,
          escalationLevel: request.escalationLevel || 0,
          metadata: request.metadata ? JSON.stringify(request.metadata) : null,
          updatedAt: new Date(),
        },
        create: {
          id: request.id.toString(),
          workflowId: request.workflowId.toString(),
          targetType: request.targetType as any,
          targetId: request.targetId.toString(),
          requesterId: request.requesterId.toString(),
          status: request.status as any,
          priority: request.priority as any,
          currentStageId: request.currentStageId?.toString(),
          notes: request.notes,
          dueDate: request.dueDate,
          completedAt: request.completedAt,
          escalatedAt: request.escalatedAt,
          escalationLevel: request.escalationLevel || 0,
          metadata: request.metadata ? JSON.stringify(request.metadata) : null,
        },
        include: {
          workflow: {
            include: {
              stages: {
                orderBy: { order: 'asc' }
              }
            }
          },
          actions: {
            orderBy: { createdAt: 'asc' }
          }
        }
      })

      return this.transformPrismaRequest(savedRequest)
    } catch (error) {
      console.error('Error saving approval request:', error)
      throw new Error('Failed to save approval request')
    }
  }

  async saveApprovalAction(action: ApprovalAction): Promise<ApprovalAction> {
    try {
      const savedAction = await prisma.approvalAction.create({
        data: {
          id: action.id.toString(),
          requestId: action.requestId.toString(),
          stageId: action.stageId.toString(),
          approverId: action.approverId.toString(),
          action: action.action as any,
          comment: action.comment,
          attachments: action.attachments ? JSON.stringify(action.attachments) : null,
          ipAddress: action.ipAddress,
          userAgent: action.userAgent,
          metadata: action.metadata ? JSON.stringify(action.metadata) : null,
        }
      })

      return {
        ...action,
        id: savedAction.id,
        createdAt: savedAction.createdAt,
        updatedAt: savedAction.updatedAt,
      }
    } catch (error) {
      console.error('Error saving approval action:', error)
      throw new Error('Failed to save approval action')
    }
  }

  async getApprovalRequest(requestId: string): Promise<ApprovalRequest | null> {
    try {
      const request = await prisma.approvalRequest.findUnique({
        where: { id: requestId },
        include: {
          workflow: {
            include: {
              stages: {
                orderBy: { order: 'asc' }
              }
            }
          },
          actions: {
            orderBy: { createdAt: 'asc' }
          }
        }
      })

      return request ? this.transformPrismaRequest(request) : null
    } catch (error) {
      console.error('Error fetching approval request:', error)
      throw new Error('Failed to fetch approval request')
    }
  }

  async getWorkflowById(workflowId: string): Promise<ApprovalWorkflow | null> {
    try {
      const workflow = await prisma.approvalWorkflow.findUnique({
        where: { id: workflowId },
        include: {
          stages: {
            orderBy: { order: 'asc' }
          }
        }
      })

      return workflow ? this.transformPrismaWorkflow(workflow) : null
    } catch (error) {
      console.error('Error fetching workflow:', error)
      throw new Error('Failed to fetch workflow')
    }
  }

  // Transform Prisma results to our types
  private transformPrismaRequest(prismaRequest: any): ApprovalRequest {
    return {
      id: prismaRequest.id,
      workflowId: prismaRequest.workflowId,
      workflow: this.transformPrismaWorkflow(prismaRequest.workflow),
      targetType: prismaRequest.targetType,
      targetId: prismaRequest.targetId,
      requesterId: prismaRequest.requesterId,
      requester: { id: prismaRequest.requesterId } as User, // Would be populated properly
      currentStageId: prismaRequest.currentStageId,
      currentStage: prismaRequest.currentStageId 
        ? prismaRequest.workflow.stages.find((s: any) => s.id === prismaRequest.currentStageId)
        : undefined,
      status: prismaRequest.status,
      priority: prismaRequest.priority,
      approvals: prismaRequest.actions?.map(this.transformPrismaAction) || [],
      dueDate: prismaRequest.dueDate,
      notes: prismaRequest.notes,
      createdAt: prismaRequest.createdAt,
      updatedAt: prismaRequest.updatedAt,
      completedAt: prismaRequest.completedAt,
      escalatedAt: prismaRequest.escalatedAt,
      escalationLevel: prismaRequest.escalationLevel,
      metadata: prismaRequest.metadata ? JSON.parse(prismaRequest.metadata) : undefined,
    }
  }

  private transformPrismaWorkflow(prismaWorkflow: any): ApprovalWorkflow {
    return {
      id: prismaWorkflow.id,
      name: prismaWorkflow.name,
      description: prismaWorkflow.description,
      teamId: prismaWorkflow.teamId,
      isActive: prismaWorkflow.isActive,
      applicableTypes: JSON.parse(prismaWorkflow.applicableTypes),
      autoStart: prismaWorkflow.autoStart,
      allowParallelStages: prismaWorkflow.allowParallelStages,
      requireAllApprovers: prismaWorkflow.requireAllApprovers,
      defaultTimeoutHours: prismaWorkflow.defaultTimeoutHours,
      createdBy: prismaWorkflow.createdBy,
      conditionRules: prismaWorkflow.conditionRules,
      metadata: prismaWorkflow.metadata ? JSON.parse(prismaWorkflow.metadata) : undefined,
      stages: prismaWorkflow.stages?.map(this.transformPrismaStage) || [],
      createdAt: prismaWorkflow.createdAt,
      updatedAt: prismaWorkflow.updatedAt,
    }
  }

  private transformPrismaStage(prismaStage: any): ApprovalStage {
    return {
      id: prismaStage.id,
      name: prismaStage.name,
      description: prismaStage.description,
      order: prismaStage.order,
      approversRequired: prismaStage.approversRequired,
      approvers: JSON.parse(prismaStage.approvers),
      approverRoles: prismaStage.approverRoles ? JSON.parse(prismaStage.approverRoles) : [],
      autoApprove: prismaStage.autoApprove,
      timeoutHours: prismaStage.timeoutHours,
      skipConditions: prismaStage.skipConditions ? JSON.parse(prismaStage.skipConditions) : [],
      escalationRules: prismaStage.escalationRules,
    }
  }

  private transformPrismaAction(prismaAction: any): ApprovalAction {
    return {
      id: prismaAction.id,
      requestId: prismaAction.requestId,
      stageId: prismaAction.stageId,
      approverId: prismaAction.approverId,
      approver: { id: prismaAction.approverId } as User, // Would be populated properly
      action: prismaAction.action,
      comment: prismaAction.comment,
      attachments: prismaAction.attachments ? JSON.parse(prismaAction.attachments) : [],
      ipAddress: prismaAction.ipAddress,
      userAgent: prismaAction.userAgent,
      metadata: prismaAction.metadata ? JSON.parse(prismaAction.metadata) : undefined,
      createdAt: prismaAction.createdAt,
      updatedAt: prismaAction.updatedAt,
    }
  }

  // Utility methods with database integration
  async getWorkflowStatus(requestId: string): Promise<{
    status: string
    currentStage?: ApprovalStage
    completedStages: ApprovalStage[]
    pendingStages: ApprovalStage[]
    progress: number
  }> {
    const request = await this.getApprovalRequest(requestId)
    if (!request) {
      throw new Error('Approval request not found')
    }

    const allStages = request.workflow.stages.sort((a, b) => a.order - b.order)
    const currentStageIndex = request.currentStage 
      ? allStages.findIndex(s => s.id === request.currentStage!.id)
      : -1

    const completedStages = currentStageIndex >= 0 
      ? allStages.slice(0, currentStageIndex)
      : []

    const pendingStages = currentStageIndex >= 0 
      ? allStages.slice(currentStageIndex + 1)
      : allStages

    const progress = allStages.length > 0 
      ? Math.round((completedStages.length / allStages.length) * 100)
      : 0

    return {
      status: request.status,
      currentStage: request.currentStage,
      completedStages,
      pendingStages,
      progress
    }
  }

  async cancelWorkflow(
    requestId: string,
    userId: string,
    reason?: string
  ): Promise<ApprovalRequest> {
    const request = await this.getApprovalRequest(requestId)
    if (!request) {
      throw new Error('Approval request not found')
    }

    if (request.status === 'approved' || request.status === 'completed') {
      throw new Error('Cannot cancel completed workflow')
    }

    // Create cancellation action
    const cancelAction: ApprovalAction = {
      id: `action_${Date.now()}`,
      requestId: request.id,
      stageId: request.currentStageId || '',
      approverId: userId,
      approver: { id: userId } as User,
      action: 'cancel',
      comment: reason,
      attachments: [],
      createdAt: new Date(),
      updatedAt: new Date()
    }

    await this.saveApprovalAction(cancelAction)

    // Update request status
    const updatedRequest = {
      ...request,
      status: 'cancelled' as const,
      completedAt: new Date(),
      approvals: [...request.approvals, cancelAction]
    }

    await this.saveApprovalRequest(updatedRequest)

    // Emit cancellation event
    this.emit({
      type: 'workflow_cancelled',
      requestId: request.id.toString(),
      userId,
      timestamp: new Date(),
      metadata: { reason }
    })

    return updatedRequest
  }

  async getWorkflowMetrics(workflowId: string, timeRange?: { start: Date; end: Date }) {
    try {
      const whereClause: any = { workflowId }
      if (timeRange) {
        whereClause.createdAt = {
          gte: timeRange.start,
          lte: timeRange.end
        }
      }

      const requests = await prisma.approvalRequest.findMany({
        where: whereClause,
        include: {
          actions: true
        }
      })

      const totalRequests = requests.length
      const completedRequests = requests.filter(r => r.status === 'approved').length
      const escalatedRequests = requests.filter(r => r.escalationLevel > 0).length
      const expiredRequests = requests.filter(r => r.status === 'expired').length

      // Calculate average completion time
      const completedWithTimes = requests.filter(r => r.completedAt && r.createdAt)
      const averageCompletionTime = completedWithTimes.length > 0
        ? completedWithTimes.reduce((sum, r) => {
            const duration = new Date(r.completedAt!).getTime() - new Date(r.createdAt).getTime()
            return sum + duration
          }, 0) / completedWithTimes.length
        : 0

      return {
        workflowId,
        totalRequests,
        completedRequests,
        averageCompletionTime: Math.round(averageCompletionTime / (1000 * 60 * 60)), // Convert to hours
        approvalRate: totalRequests > 0 ? (completedRequests / totalRequests) * 100 : 0,
        escalationRate: totalRequests > 0 ? (escalatedRequests / totalRequests) * 100 : 0,
        timeoutRate: totalRequests > 0 ? (expiredRequests / totalRequests) * 100 : 0,
        bottleneckStages: [] // Would require more complex analysis
      }
    } catch (error) {
      console.error('Error fetching workflow metrics:', error)
      throw new Error('Failed to fetch workflow metrics')
    }
  }
}

// Singleton instance
export const workflowEngine = new WorkflowEngine()

export default workflowEngine