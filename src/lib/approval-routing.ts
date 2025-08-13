import { 
  ApprovalWorkflow, 
  ApprovalStage, 
  ApprovalRequest, 
  ApprovalCondition,
  UserRole,
  User
} from '@/types'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

export interface RoutingDecision {
  shouldRoute: boolean
  targetApprovers: string[]
  estimatedTime: number
  confidence: number
  reasoning: string[]
}

export interface RoutingContext {
  request: ApprovalRequest
  stage: ApprovalStage
  targetContent: any
  requester: User
  teamMembers: User[]
  currentWorkload?: Map<string, number>
  urgencyLevel: 'low' | 'medium' | 'high' | 'urgent'
}

export interface RoutingRule {
  id: string
  name: string
  description: string
  priority: number
  conditions: ApprovalCondition[]
  actions: RoutingAction[]
  isActive: boolean
}

export interface RoutingAction {
  type: 'assign_to_user' | 'assign_to_role' | 'load_balance' | 'escalate' | 'parallel_route' | 'skip_stage'
  parameters: Record<string, any>
}

export interface ApproverMetrics {
  userId: string
  averageResponseTime: number
  approvalRate: number
  currentWorkload: number
  expertiseAreas: string[]
  availability: 'available' | 'busy' | 'away' | 'offline'
  lastActiveAt: Date
}

export class ApprovalRoutingEngine {
  private routingRules: RoutingRule[] = []
  private approverMetrics: Map<string, ApproverMetrics> = new Map()

  constructor() {
    this.initializeDefaultRules()
  }

  private initializeDefaultRules() {
    this.routingRules = [
      {
        id: 'urgent_escalation',
        name: 'Urgent Request Escalation',
        description: 'Route urgent requests to senior approvers',
        priority: 1,
        conditions: [
          { type: 'custom', operator: 'equals', value: 'urgent' }
        ],
        actions: [
          { type: 'assign_to_role', parameters: { roles: ['admin', 'approver'] } }
        ],
        isActive: true
      },
      {
        id: 'workload_balancing',
        name: 'Workload Load Balancing',
        description: 'Distribute approvals based on current workload',
        priority: 2,
        conditions: [
          { type: 'custom', operator: 'greater_than', value: 5 }
        ],
        actions: [
          { type: 'load_balance', parameters: { maxWorkload: 10 } }
        ],
        isActive: true
      },
      {
        id: 'expertise_routing',
        name: 'Expertise-Based Routing',
        description: 'Route to approvers with relevant expertise',
        priority: 3,
        conditions: [
          { type: 'content_type', operator: 'equals', value: 'brand' }
        ],
        actions: [
          { type: 'assign_to_role', parameters: { roles: ['reviewer'], expertiseRequired: true } }
        ],
        isActive: true
      },
      {
        id: 'parallel_high_value',
        name: 'Parallel Approval for High Value',
        description: 'Route high-value content to multiple approvers simultaneously',
        priority: 4,
        conditions: [
          { type: 'budget_threshold', operator: 'greater_than', value: 10000 }
        ],
        actions: [
          { type: 'parallel_route', parameters: { minApprovers: 2, roles: ['admin'] } }
        ],
        isActive: true
      }
    ]
  }

  async routeApproval(context: RoutingContext): Promise<RoutingDecision> {
    try {
      // Update approver metrics
      await this.updateApproverMetrics(context.teamMembers)

      // Apply routing rules in priority order
      const applicableRules = this.getApplicableRules(context)
      
      let targetApprovers: string[] = []
      let reasoning: string[] = []

      if (applicableRules.length > 0) {
        const result = await this.applyRoutingRules(applicableRules, context)
        targetApprovers = result.approvers
        reasoning = result.reasoning
      } else {
        // Fallback to default routing
        targetApprovers = await this.getDefaultApprovers(context)
        reasoning.push('Applied default routing strategy')
      }

      // Apply intelligent routing optimizations
      const optimizedApprovers = await this.optimizeApproverSelection(
        targetApprovers,
        context
      )

      const estimatedTime = await this.estimateApprovalTime(optimizedApprovers, context)
      const confidence = this.calculateConfidence(optimizedApprovers, context)

      return {
        shouldRoute: optimizedApprovers.length > 0,
        targetApprovers: optimizedApprovers,
        estimatedTime,
        confidence,
        reasoning
      }
    } catch (error) {
      console.error('Error in approval routing:', error)
      
      // Fallback routing
      const fallbackApprovers = await this.getDefaultApprovers(context)
      return {
        shouldRoute: fallbackApprovers.length > 0,
        targetApprovers: fallbackApprovers,
        estimatedTime: 48, // Default 48 hours
        confidence: 0.5,
        reasoning: ['Used fallback routing due to error']
      }
    }
  }

  private getApplicableRules(context: RoutingContext): RoutingRule[] {
    return this.routingRules
      .filter(rule => rule.isActive)
      .filter(rule => this.evaluateRuleConditions(rule.conditions, context))
      .sort((a, b) => a.priority - b.priority)
  }

  private evaluateRuleConditions(conditions: ApprovalCondition[], context: RoutingContext): boolean {
    return conditions.every(condition => this.evaluateCondition(condition, context))
  }

  private evaluateCondition(condition: ApprovalCondition, context: RoutingContext): boolean {
    switch (condition.type) {
      case 'user_role':
        return this.evaluateUserRole(condition, context.requester)
      
      case 'content_type':
        return this.evaluateContentType(condition, context.request.targetType)
      
      case 'budget_threshold':
        return this.evaluateBudgetThreshold(condition, context.targetContent)
      
      case 'custom':
        return this.evaluateCustomCondition(condition, context)
      
      default:
        return false
    }
  }

  private evaluateUserRole(condition: ApprovalCondition, user: User): boolean {
    switch (condition.operator) {
      case 'equals':
        return user.role === condition.value
      case 'not_equals':
        return user.role !== condition.value
      default:
        return false
    }
  }

  private evaluateContentType(condition: ApprovalCondition, contentType: string): boolean {
    switch (condition.operator) {
      case 'equals':
        return contentType === condition.value
      case 'not_equals':
        return contentType !== condition.value
      case 'contains':
        return contentType.toLowerCase().includes(String(condition.value).toLowerCase())
      default:
        return false
    }
  }

  private evaluateBudgetThreshold(condition: ApprovalCondition, content: any): boolean {
    const budget = content?.budget || 0
    const threshold = Number(condition.value)

    switch (condition.operator) {
      case 'greater_than':
        return budget > threshold
      case 'less_than':
        return budget < threshold
      case 'equals':
        return budget === threshold
      default:
        return false
    }
  }

  private evaluateCustomCondition(condition: ApprovalCondition, context: RoutingContext): boolean {
    // Custom condition evaluation based on condition value
    const conditionValue = String(condition.value)

    switch (conditionValue) {
      case 'urgent':
        return context.urgencyLevel === 'urgent'
      
      case 'high_workload':
        const currentWorkload = Array.from(this.approverMetrics.values())
          .reduce((sum, metrics) => sum + metrics.currentWorkload, 0)
        return currentWorkload > Number(condition.value)
      
      default:
        return false
    }
  }

  private async applyRoutingRules(
    rules: RoutingRule[], 
    context: RoutingContext
  ): Promise<{ approvers: string[], reasoning: string[] }> {
    let approvers: string[] = []
    let reasoning: string[] = []

    for (const rule of rules) {
      const ruleResult = await this.applyRoutingActions(rule.actions, context)
      if (ruleResult.approvers.length > 0) {
        approvers = [...approvers, ...ruleResult.approvers]
        reasoning.push(`Applied rule: ${rule.name}`)
        reasoning.push(...ruleResult.reasoning)
      }
    }

    // Remove duplicates
    approvers = [...new Set(approvers)]
    
    return { approvers, reasoning }
  }

  private async applyRoutingActions(
    actions: RoutingAction[], 
    context: RoutingContext
  ): Promise<{ approvers: string[], reasoning: string[] }> {
    let approvers: string[] = []
    let reasoning: string[] = []

    for (const action of actions) {
      const actionResult = await this.executeRoutingAction(action, context)
      approvers = [...approvers, ...actionResult.approvers]
      reasoning.push(...actionResult.reasoning)
    }

    return { approvers, reasoning }
  }

  private async executeRoutingAction(
    action: RoutingAction, 
    context: RoutingContext
  ): Promise<{ approvers: string[], reasoning: string[] }> {
    switch (action.type) {
      case 'assign_to_user':
        return this.assignToUser(action.parameters, context)
      
      case 'assign_to_role':
        return this.assignToRole(action.parameters, context)
      
      case 'load_balance':
        return this.loadBalanceAssignment(action.parameters, context)
      
      case 'parallel_route':
        return this.parallelRoute(action.parameters, context)
      
      case 'escalate':
        return this.escalateAssignment(action.parameters, context)
      
      default:
        return { approvers: [], reasoning: ['Unknown routing action'] }
    }
  }

  private async assignToUser(
    parameters: any, 
    context: RoutingContext
  ): Promise<{ approvers: string[], reasoning: string[] }> {
    const userIds = parameters.userIds || []
    return {
      approvers: userIds,
      reasoning: [`Assigned to specific users: ${userIds.join(', ')}`]
    }
  }

  private async assignToRole(
    parameters: any, 
    context: RoutingContext
  ): Promise<{ approvers: string[], reasoning: string[] }> {
    const roles = parameters.roles || []
    const expertiseRequired = parameters.expertiseRequired || false

    let candidateApprovers = context.teamMembers.filter(member => 
      roles.includes(member.role)
    )

    if (expertiseRequired) {
      candidateApprovers = candidateApprovers.filter(member => {
        const metrics = this.approverMetrics.get(member.id.toString())
        return metrics && this.hasRelevantExpertise(metrics, context)
      })
    }

    const approvers = candidateApprovers.map(member => member.id.toString())
    
    return {
      approvers,
      reasoning: [
        `Assigned to roles: ${roles.join(', ')}`,
        expertiseRequired ? 'Filtered by expertise requirements' : ''
      ].filter(Boolean)
    }
  }

  private async loadBalanceAssignment(
    parameters: any, 
    context: RoutingContext
  ): Promise<{ approvers: string[], reasoning: string[] }> {
    const maxWorkload = parameters.maxWorkload || 10
    const targetRoles = parameters.roles || ['reviewer', 'approver']

    // Get approvers with lowest workload
    const availableApprovers = context.teamMembers
      .filter(member => targetRoles.includes(member.role))
      .map(member => {
        const metrics = this.approverMetrics.get(member.id.toString())
        return {
          id: member.id.toString(),
          workload: metrics?.currentWorkload || 0,
          availability: metrics?.availability || 'available'
        }
      })
      .filter(approver => 
        approver.workload < maxWorkload && 
        approver.availability === 'available'
      )
      .sort((a, b) => a.workload - b.workload)
      .slice(0, 1) // Take the one with lowest workload

    return {
      approvers: availableApprovers.map(a => a.id),
      reasoning: [
        'Applied load balancing',
        `Selected approver(s) with lowest workload (max: ${maxWorkload})`
      ]
    }
  }

  private async parallelRoute(
    parameters: any, 
    context: RoutingContext
  ): Promise<{ approvers: string[], reasoning: string[] }> {
    const minApprovers = parameters.minApprovers || 2
    const roles = parameters.roles || ['approver', 'admin']

    const candidateApprovers = context.teamMembers
      .filter(member => roles.includes(member.role))
      .filter(member => {
        const metrics = this.approverMetrics.get(member.id.toString())
        return metrics?.availability === 'available'
      })
      .slice(0, minApprovers)

    return {
      approvers: candidateApprovers.map(member => member.id.toString()),
      reasoning: [
        `Set up parallel approval routing`,
        `Selected ${candidateApprovers.length} approvers for parallel processing`
      ]
    }
  }

  private async escalateAssignment(
    parameters: any, 
    context: RoutingContext
  ): Promise<{ approvers: string[], reasoning: string[] }> {
    const targetRoles = parameters.roles || ['admin']
    
    const escalationApprovers = context.teamMembers
      .filter(member => targetRoles.includes(member.role))
      .map(member => member.id.toString())

    return {
      approvers: escalationApprovers,
      reasoning: [
        'Escalated approval to senior roles',
        `Assigned to roles: ${targetRoles.join(', ')}`
      ]
    }
  }

  private async getDefaultApprovers(context: RoutingContext): Promise<string[]> {
    // Get approvers defined in the stage
    const stageApprovers = context.stage.approvers.map(String)
    
    if (stageApprovers.length > 0) {
      return stageApprovers
    }

    // Fallback to role-based selection
    const roleApprovers = context.teamMembers
      .filter(member => 
        context.stage.approverRoles?.includes(member.role) || 
        ['reviewer', 'approver'].includes(member.role)
      )
      .map(member => member.id.toString())

    return roleApprovers
  }

  private async optimizeApproverSelection(
    approvers: string[], 
    context: RoutingContext
  ): Promise<string[]> {
    // Filter out unavailable approvers
    const availableApprovers = approvers.filter(approverId => {
      const metrics = this.approverMetrics.get(approverId)
      return !metrics || metrics.availability !== 'offline'
    })

    // Sort by performance metrics if available
    return availableApprovers.sort((a, b) => {
      const metricsA = this.approverMetrics.get(a)
      const metricsB = this.approverMetrics.get(b)
      
      if (!metricsA || !metricsB) return 0
      
      // Prioritize faster response time and higher approval rate
      const scoreA = (1 / metricsA.averageResponseTime) * metricsA.approvalRate
      const scoreB = (1 / metricsB.averageResponseTime) * metricsB.approvalRate
      
      return scoreB - scoreA
    })
  }

  private async estimateApprovalTime(
    approvers: string[], 
    context: RoutingContext
  ): Promise<number> {
    if (approvers.length === 0) return 48 // Default 48 hours

    const estimations = approvers.map(approverId => {
      const metrics = this.approverMetrics.get(approverId)
      return metrics?.averageResponseTime || 24 // Default 24 hours
    })

    // For parallel approvals, use the maximum time
    // For sequential approvals, use the sum
    const isParallel = context.stage.approversRequired === 1 || 
                      context.request.workflow.allowParallelStages

    return isParallel 
      ? Math.max(...estimations)
      : estimations.reduce((sum, time) => sum + time, 0)
  }

  private calculateConfidence(approvers: string[], context: RoutingContext): number {
    if (approvers.length === 0) return 0

    let confidence = 0.5 // Base confidence

    // Increase confidence based on approver availability
    const availableCount = approvers.filter(approverId => {
      const metrics = this.approverMetrics.get(approverId)
      return metrics?.availability === 'available'
    }).length

    confidence += (availableCount / approvers.length) * 0.3

    // Increase confidence based on expertise match
    const expertiseMatch = approvers.filter(approverId => {
      const metrics = this.approverMetrics.get(approverId)
      return metrics && this.hasRelevantExpertise(metrics, context)
    }).length

    confidence += (expertiseMatch / approvers.length) * 0.2

    return Math.min(confidence, 1.0)
  }

  private hasRelevantExpertise(metrics: ApproverMetrics, context: RoutingContext): boolean {
    const contentType = context.request.targetType
    return metrics.expertiseAreas.includes(contentType) ||
           metrics.expertiseAreas.includes('general')
  }

  private async updateApproverMetrics(teamMembers: User[]): Promise<void> {
    // In a real implementation, this would fetch metrics from the database
    // For now, we'll use mock data
    for (const member of teamMembers) {
      if (!this.approverMetrics.has(member.id.toString())) {
        this.approverMetrics.set(member.id.toString(), {
          userId: member.id.toString(),
          averageResponseTime: 12 + Math.random() * 24, // 12-36 hours
          approvalRate: 0.7 + Math.random() * 0.3, // 70-100%
          currentWorkload: Math.floor(Math.random() * 8), // 0-7 pending items
          expertiseAreas: this.getExpertiseForRole(member.role),
          availability: Math.random() > 0.2 ? 'available' : 'busy',
          lastActiveAt: new Date()
        })
      }
    }
  }

  private getExpertiseForRole(role: UserRole): string[] {
    const expertiseMap: Record<UserRole, string[]> = {
      admin: ['campaign', 'journey', 'asset', 'brand', 'general'],
      approver: ['campaign', 'journey', 'general'],
      reviewer: ['asset', 'brand', 'general'],
      publisher: ['campaign', 'journey'],
      creator: ['asset', 'brand'],
      viewer: []
    }

    return expertiseMap[role] || ['general']
  }

  // Public methods for managing routing rules
  async addRoutingRule(rule: Omit<RoutingRule, 'id'>): Promise<RoutingRule> {
    const newRule: RoutingRule = {
      ...rule,
      id: `rule_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    }
    
    this.routingRules.push(newRule)
    return newRule
  }

  async updateRoutingRule(ruleId: string, updates: Partial<RoutingRule>): Promise<RoutingRule | null> {
    const ruleIndex = this.routingRules.findIndex(rule => rule.id === ruleId)
    if (ruleIndex === -1) return null

    this.routingRules[ruleIndex] = {
      ...this.routingRules[ruleIndex],
      ...updates
    }

    return this.routingRules[ruleIndex]
  }

  async deleteRoutingRule(ruleId: string): Promise<boolean> {
    const ruleIndex = this.routingRules.findIndex(rule => rule.id === ruleId)
    if (ruleIndex === -1) return false

    this.routingRules.splice(ruleIndex, 1)
    return true
  }

  async getRoutingRules(): Promise<RoutingRule[]> {
    return [...this.routingRules]
  }

  async getApproverMetrics(userId?: string): Promise<ApproverMetrics | ApproverMetrics[]> {
    if (userId) {
      return this.approverMetrics.get(userId) || null
    }
    return Array.from(this.approverMetrics.values())
  }
}

// Singleton instance
export const approvalRoutingEngine = new ApprovalRoutingEngine()

export default approvalRoutingEngine