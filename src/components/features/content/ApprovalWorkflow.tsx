'use client'

import * as React from 'react'
import {useState } from 'react'

import { AlertCircle, CheckCircle, Clock, FileText, Plus, Settings,Users } from 'lucide-react'

import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Progress } from '@/components/ui/progress'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { ContentType } from '@/generated/prisma'

export interface ApprovalStep {
  id: string
  name: string
  description?: string
  requiredApprovals: number
  assignedUsers: string[]
  approvals: ApprovalAction[]
  isParallel?: boolean // Whether approvals can happen in parallel
  order: number
  status: 'pending' | 'in_progress' | 'completed' | 'skipped'
}

export interface ApprovalAction {
  id: string
  userId: string
  userName: string
  userAvatar?: string
  action: 'approved' | 'rejected' | 'requested_changes'
  comment?: string
  timestamp: Date
}

export interface ApprovalWorkflowTemplate {
  id: string
  name: string
  description?: string
  contentTypes: ContentType[]
  steps: Omit<ApprovalStep, 'approvals' | 'status'>[]
  isDefault?: boolean
  createdBy: string
  createdAt: Date
}

export interface ContentApprovalWorkflow {
  id: string
  contentId: string
  contentTitle: string
  contentType: ContentType
  templateId?: string
  steps: ApprovalStep[]
  currentStepIndex: number
  status: 'pending' | 'in_progress' | 'approved' | 'rejected'
  submittedBy: string
  submittedByName: string
  submittedAt: Date
  completedAt?: Date
  dueDate?: Date
}

interface ApprovalWorkflowProps {
  workflows: ContentApprovalWorkflow[]
  templates: ApprovalWorkflowTemplate[]
  currentUserId: string
  onApprove: (workflowId: string, stepId: string, comment?: string) => void
  onReject: (workflowId: string, stepId: string, comment: string) => void
  onRequestChanges: (workflowId: string, stepId: string, comment: string) => void
  onCreateTemplate: (template: Omit<ApprovalWorkflowTemplate, 'id' | 'createdBy' | 'createdAt'>) => void
  onCreateWorkflow: (contentId: string, templateId: string, dueDate?: Date) => void
  availableUsers: { id: string; name: string; avatar?: string }[]
  isLoading?: boolean
}

const workflowStatusConfig = {
  pending: { label: 'Pending', color: 'bg-gray-500', textColor: 'text-gray-600' },
  in_progress: { label: 'In Progress', color: 'bg-blue-500', textColor: 'text-blue-600' },
  approved: { label: 'Approved', color: 'bg-green-500', textColor: 'text-green-600' },
  rejected: { label: 'Rejected', color: 'bg-red-500', textColor: 'text-red-600' }
}

const stepStatusConfig = {
  pending: { label: 'Pending', color: 'bg-gray-100', textColor: 'text-gray-600' },
  in_progress: { label: 'In Progress', color: 'bg-blue-100', textColor: 'text-blue-600' },
  completed: { label: 'Completed', color: 'bg-green-100', textColor: 'text-green-600' },
  skipped: { label: 'Skipped', color: 'bg-gray-100', textColor: 'text-gray-400' }
}

export function ApprovalWorkflow({
  workflows,
  templates,
  currentUserId,
  onApprove,
  onReject,
  onRequestChanges,
  onCreateTemplate,
  onCreateWorkflow,
  availableUsers,
  isLoading = false
}: ApprovalWorkflowProps) {
  const [selectedWorkflow, setSelectedWorkflow] = useState<ContentApprovalWorkflow | null>(null)
  const [actionComment, setActionComment] = useState('')
  const [actionDialog, setActionDialog] = useState<{
    isOpen: boolean
    workflowId: string
    stepId: string
    action: 'approve' | 'reject' | 'request_changes'
  }>({ isOpen: false, workflowId: '', stepId: '', action: 'approve' })

  const [templateDialog, setTemplateDialog] = useState(false)
  const [newTemplate, setNewTemplate] = useState<Omit<ApprovalWorkflowTemplate, 'id' | 'createdBy' | 'createdAt'>>({
    name: '',
    description: '',
    contentTypes: [],
    steps: [],
    isDefault: false
  })

  const [workflowDialog, setWorkflowDialog] = useState(false)
  const [newWorkflowData, setNewWorkflowData] = useState<{
    contentId: string
    contentTitle: string
    contentType: ContentType | null
    templateId: string
    dueDate: string
  }>({
    contentId: '',
    contentTitle: '',
    contentType: null,
    templateId: '',
    dueDate: ''
  })

  // Filter workflows where current user is involved
  const myWorkflows = workflows.filter(workflow => {
    const currentStep = workflow.steps[workflow.currentStepIndex]
    return currentStep?.assignedUsers.includes(currentUserId) || workflow.submittedBy === currentUserId
  })

  const getWorkflowProgress = (workflow: ContentApprovalWorkflow) => {
    const totalSteps = workflow.steps.length
    const completedSteps = workflow.steps.filter(step => step.status === 'completed').length
    return totalSteps > 0 ? (completedSteps / totalSteps) * 100 : 0
  }

  const getCurrentStepRequiresAction = (workflow: ContentApprovalWorkflow) => {
    const currentStep = workflow.steps[workflow.currentStepIndex]
    if (!currentStep || currentStep.status === 'completed') return false
    
    return currentStep.assignedUsers.includes(currentUserId) &&
           !currentStep.approvals.some(approval => approval.userId === currentUserId)
  }

  const getStepProgress = (step: ApprovalStep) => {
    const approvals = step.approvals.filter(a => a.action === 'approved').length
    return step.requiredApprovals > 0 ? (approvals / step.requiredApprovals) * 100 : 0
  }

  const handleAction = () => {
    const { workflowId, stepId, action } = actionDialog
    const comment = actionComment.trim()

    switch (action) {
      case 'approve':
        onApprove(workflowId, stepId, comment || undefined)
        break
      case 'reject':
        onReject(workflowId, stepId, comment || 'Content rejected')
        break
      case 'request_changes':
        onRequestChanges(workflowId, stepId, comment || 'Changes requested')
        break
    }

    setActionDialog({ isOpen: false, workflowId: '', stepId: '', action: 'approve' })
    setActionComment('')
  }

  const handleCreateTemplate = () => {
    onCreateTemplate(newTemplate)
    setTemplateDialog(false)
    setNewTemplate({
      name: '',
      description: '',
      contentTypes: [],
      steps: [],
      isDefault: false
    })
  }

  const handleCreateWorkflow = () => {
    if (newWorkflowData.contentId && newWorkflowData.templateId) {
      onCreateWorkflow(
        newWorkflowData.contentId,
        newWorkflowData.templateId,
        newWorkflowData.dueDate ? new Date(newWorkflowData.dueDate) : undefined
      )
      setWorkflowDialog(false)
      setNewWorkflowData({
        contentId: '',
        contentTitle: '',
        contentType: null,
        templateId: '',
        dueDate: ''
      })
    }
  }

  const formatDate = (date: Date) => {
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    }).format(date)
  }

  const getDaysUntilDue = (dueDate: Date) => {
    return Math.ceil((dueDate.getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24))
  }

  if (isLoading) {
    return (
      <Card>
        <CardContent className="p-6">
          <div className="flex items-center justify-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <span className="ml-2 text-muted-foreground">Loading approval workflows...</span>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      {/* Actions Bar */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">Approval Workflows</h2>
          <p className="text-muted-foreground">
            Manage content approval processes and collaboration workflows
          </p>
        </div>
        <div className="flex gap-2">
          <Dialog open={templateDialog} onOpenChange={setTemplateDialog}>
            <DialogTrigger asChild>
              <Button variant="outline">
                <Settings className="h-4 w-4 mr-2" />
                Create Template
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create Approval Template</DialogTitle>
                <DialogDescription>
                  Define a reusable approval workflow template
                </DialogDescription>
              </DialogHeader>
              <div className="space-y-4 py-4">
                <div>
                  <Label htmlFor="template-name">Template Name</Label>
                  <Input
                    id="template-name"
                    value={newTemplate.name}
                    onChange={(e) => setNewTemplate(prev => ({ ...prev, name: e.target.value }))}
                    placeholder="e.g., Marketing Content Review"
                  />
                </div>
                <div>
                  <Label htmlFor="template-description">Description</Label>
                  <Textarea
                    id="template-description"
                    value={newTemplate.description}
                    onChange={(e) => setNewTemplate(prev => ({ ...prev, description: e.target.value }))}
                    placeholder="Describe this approval workflow..."
                  />
                </div>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setTemplateDialog(false)}>
                  Cancel
                </Button>
                <Button onClick={handleCreateTemplate} disabled={!newTemplate.name.trim()}>
                  Create Template
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>

          <Dialog open={workflowDialog} onOpenChange={setWorkflowDialog}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="h-4 w-4 mr-2" />
                Start Workflow
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Start Approval Workflow</DialogTitle>
                <DialogDescription>
                  Create a new approval workflow for content
                </DialogDescription>
              </DialogHeader>
              <div className="space-y-4 py-4">
                <div>
                  <Label htmlFor="content-title">Content Title</Label>
                  <Input
                    id="content-title"
                    value={newWorkflowData.contentTitle}
                    onChange={(e) => setNewWorkflowData(prev => ({ ...prev, contentTitle: e.target.value }))}
                    placeholder="Enter content title..."
                  />
                </div>
                <div>
                  <Label htmlFor="template-select">Approval Template</Label>
                  <Select value={newWorkflowData.templateId} onValueChange={(value) => setNewWorkflowData(prev => ({ ...prev, templateId: value }))}>
                    <SelectTrigger>
                      <SelectValue placeholder="Choose a template" />
                    </SelectTrigger>
                    <SelectContent>
                      {templates.map(template => (
                        <SelectItem key={template.id} value={template.id}>
                          {template.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label htmlFor="due-date">Due Date (Optional)</Label>
                  <Input
                    id="due-date"
                    type="datetime-local"
                    value={newWorkflowData.dueDate}
                    onChange={(e) => setNewWorkflowData(prev => ({ ...prev, dueDate: e.target.value }))}
                  />
                </div>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setWorkflowDialog(false)}>
                  Cancel
                </Button>
                <Button 
                  onClick={handleCreateWorkflow} 
                  disabled={!newWorkflowData.contentTitle.trim() || !newWorkflowData.templateId}
                >
                  Start Workflow
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* Urgent Actions Alert */}
      {myWorkflows.some(w => w.dueDate && getDaysUntilDue(w.dueDate) <= 2 && getCurrentStepRequiresAction(w)) && (
        <Alert>
          <AlertCircle className="h-4 w-4" />
          <AlertTitle>Urgent Approvals Required</AlertTitle>
          <AlertDescription>
            You have content awaiting your approval with due dates approaching within 2 days.
          </AlertDescription>
        </Alert>
      )}

      {/* Active Workflows */}
      <Card>
        <CardHeader>
          <CardTitle>Active Workflows</CardTitle>
          <CardDescription>
            Content currently in approval processes
          </CardDescription>
        </CardHeader>
        <CardContent>
          {myWorkflows.length === 0 ? (
            <div className="text-center py-8">
              <FileText className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <p className="text-muted-foreground mb-2">No active workflows</p>
              <p className="text-sm text-muted-foreground">
                Start a new approval workflow to get content reviewed and approved
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {myWorkflows.map((workflow) => {
                const workflowStatus = workflowStatusConfig[workflow.status]
                const progress = getWorkflowProgress(workflow)
                const currentStep = workflow.steps[workflow.currentStepIndex]
                const requiresAction = getCurrentStepRequiresAction(workflow)
                const isUrgent = workflow.dueDate && getDaysUntilDue(workflow.dueDate) <= 2

                return (
                  <Card key={workflow.id} className={`${isUrgent ? 'border-orange-200 bg-orange-50/50' : ''} ${requiresAction ? 'border-blue-200 bg-blue-50/30' : ''}`}>
                    <CardContent className="p-4">
                      <div className="flex items-start justify-between mb-4">
                        <div className="flex-1">
                          <div className="flex items-center gap-2 mb-2">
                            <h3 className="font-semibold text-lg">{workflow.contentTitle}</h3>
                            <Badge variant="outline" className={`${workflowStatus.color} text-white`}>
                              {workflowStatus.label}
                            </Badge>
                            {requiresAction && (
                              <Badge className="bg-blue-500">
                                <AlertCircle className="h-3 w-3 mr-1" />
                                Action Required
                              </Badge>
                            )}
                            {isUrgent && (
                              <Badge variant="destructive" className="bg-orange-500">
                                <Clock className="h-3 w-3 mr-1" />
                                Urgent
                              </Badge>
                            )}
                          </div>

                          <div className="flex items-center gap-4 text-sm text-muted-foreground mb-3">
                            <span>Submitted by {workflow.submittedByName}</span>
                            <span>{formatDate(workflow.submittedAt)}</span>
                            {workflow.dueDate && (
                              <span className={isUrgent ? 'text-orange-600 font-medium' : ''}>
                                Due {formatDate(workflow.dueDate)}
                              </span>
                            )}
                          </div>

                          <div className="mb-3">
                            <div className="flex items-center justify-between text-sm mb-1">
                              <span className="text-muted-foreground">Overall Progress</span>
                              <span className={workflowStatus.textColor}>{Math.round(progress)}%</span>
                            </div>
                            <Progress value={progress} className="h-2" aria-label={`Workflow progress: ${Math.round(progress)}%`} />
                          </div>

                          {/* Current Step Info */}
                          {currentStep && (
                            <div className="bg-gray-50 rounded-lg p-3 mb-3">
                              <div className="flex items-center justify-between mb-2">
                                <div className="font-medium text-sm">Current Step: {currentStep.name}</div>
                                <Badge variant="outline" className={stepStatusConfig[currentStep.status].color}>
                                  {stepStatusConfig[currentStep.status].label}
                                </Badge>
                              </div>
                              <p className="text-xs text-muted-foreground mb-2">{currentStep.description}</p>
                              <div className="flex items-center gap-4 text-xs">
                                <div className="flex items-center gap-1">
                                  <Users className="h-3 w-3" />
                                  {currentStep.approvals.filter(a => a.action === 'approved').length}/{currentStep.requiredApprovals} approvals
                                </div>
                                <div className="flex items-center gap-1">
                                  <CheckCircle className="h-3 w-3" />
                                  {getStepProgress(currentStep).toFixed(0)}% complete
                                </div>
                              </div>
                            </div>
                          )}
                        </div>

                        <div className="flex items-center gap-2 ml-4">
                          <Dialog>
                            <DialogTrigger asChild>
                              <Button 
                                variant="outline" 
                                size="sm"
                                onClick={() => setSelectedWorkflow(workflow)}
                              >
                                View Details
                              </Button>
                            </DialogTrigger>
                            <DialogContent className="max-w-4xl max-h-[80vh]">
                              <DialogHeader>
                                <DialogTitle className="flex items-center gap-2">
                                  {workflow.contentTitle}
                                  <Badge variant="outline" className={`${workflowStatus.color} text-white`}>
                                    {workflowStatus.label}
                                  </Badge>
                                </DialogTitle>
                                <DialogDescription>
                                  Approval workflow progress and details
                                </DialogDescription>
                              </DialogHeader>

                              <div className="py-4">
                                <div className="space-y-4">
                                  {workflow.steps.map((step, index) => {
                                    const stepStatus = stepStatusConfig[step.status]
                                    const isCurrentStep = index === workflow.currentStepIndex
                                    const stepProgress = getStepProgress(step)

                                    return (
                                      <div key={step.id} className={`border rounded-lg p-4 ${isCurrentStep ? 'border-blue-200 bg-blue-50/30' : ''}`}>
                                        <div className="flex items-start justify-between mb-3">
                                          <div className="flex-1">
                                            <div className="flex items-center gap-2 mb-1">
                                              <div className="font-medium">{step.name}</div>
                                              <Badge variant="outline" className={stepStatus.color}>
                                                {stepStatus.label}
                                              </Badge>
                                              {isCurrentStep && (
                                                <Badge className="bg-blue-500">Current</Badge>
                                              )}
                                            </div>
                                            <p className="text-sm text-muted-foreground mb-2">{step.description}</p>
                                            <div className="text-xs text-muted-foreground mb-2">
                                              Requires {step.requiredApprovals} approval{step.requiredApprovals !== 1 ? 's' : ''}
                                            </div>
                                            <Progress value={stepProgress} className="h-1 mb-3" aria-label={`Step progress: ${stepProgress.toFixed(0)}%`} />
                                          </div>
                                        </div>

                                        {/* Assigned Users */}
                                        <div className="flex items-center gap-2 mb-3">
                                          <span className="text-xs font-medium text-muted-foreground">Assigned:</span>
                                          <div className="flex items-center gap-1">
                                            {step.assignedUsers.map(userId => {
                                              const user = availableUsers.find(u => u.id === userId)
                                              const hasApproved = step.approvals.some(a => a.userId === userId)
                                              return (
                                                <div key={userId} className="flex items-center gap-1">
                                                  <Avatar className="h-6 w-6">
                                                    {user?.avatar && <AvatarImage src={user.avatar} alt={user.name} />}
                                                    <AvatarFallback className="bg-blue-500 text-white text-xs">
                                                      {user?.name.charAt(0).toUpperCase() || '?'}
                                                    </AvatarFallback>
                                                  </Avatar>
                                                  {hasApproved && (
                                                    <CheckCircle className="h-3 w-3 text-green-500" />
                                                  )}
                                                </div>
                                              )
                                            })}
                                          </div>
                                        </div>

                                        {/* Approval Actions */}
                                        <div className="space-y-2">
                                          {step.approvals.map(approval => (
                                            <div key={approval.id} className="flex items-center justify-between text-sm p-2 bg-gray-50 rounded">
                                              <div className="flex items-center gap-2">
                                                <Avatar className="h-5 w-5">
                                                  {approval.userAvatar && <AvatarImage src={approval.userAvatar} alt={approval.userName} />}
                                                  <AvatarFallback className="bg-blue-500 text-white text-xs">
                                                    {approval.userName.charAt(0).toUpperCase()}
                                                  </AvatarFallback>
                                                </Avatar>
                                                <span className="font-medium">{approval.userName}</span>
                                                <Badge variant="outline" className={
                                                  approval.action === 'approved' ? 'bg-green-100 text-green-700' :
                                                  approval.action === 'rejected' ? 'bg-red-100 text-red-700' :
                                                  'bg-yellow-100 text-yellow-700'
                                                }>
                                                  {approval.action.replace('_', ' ')}
                                                </Badge>
                                              </div>
                                              <span className="text-xs text-muted-foreground">
                                                {formatDate(approval.timestamp)}
                                              </span>
                                            </div>
                                          ))}
                                        </div>

                                        {/* Action Buttons for Current Step */}
                                        {isCurrentStep && step.assignedUsers.includes(currentUserId) && 
                                         !step.approvals.some(a => a.userId === currentUserId) && (
                                          <div className="flex gap-2 mt-3 pt-3 border-t">
                                            <Button
                                              size="sm"
                                              className="bg-green-600 hover:bg-green-700"
                                              onClick={() => setActionDialog({
                                                isOpen: true,
                                                workflowId: workflow.id,
                                                stepId: step.id,
                                                action: 'approve'
                                              })}
                                            >
                                              Approve
                                            </Button>
                                            <Button
                                              size="sm"
                                              variant="outline"
                                              className="text-yellow-600 border-yellow-600"
                                              onClick={() => setActionDialog({
                                                isOpen: true,
                                                workflowId: workflow.id,
                                                stepId: step.id,
                                                action: 'request_changes'
                                              })}
                                            >
                                              Request Changes
                                            </Button>
                                            <Button
                                              size="sm"
                                              variant="outline"
                                              className="text-red-600 border-red-600"
                                              onClick={() => setActionDialog({
                                                isOpen: true,
                                                workflowId: workflow.id,
                                                stepId: step.id,
                                                action: 'reject'
                                              })}
                                            >
                                              Reject
                                            </Button>
                                          </div>
                                        )}
                                      </div>
                                    )
                                  })}
                                </div>
                              </div>
                            </DialogContent>
                          </Dialog>

                          {requiresAction && currentStep && (
                            <>
                              <Button
                                size="sm"
                                className="bg-green-600 hover:bg-green-700"
                                onClick={() => setActionDialog({
                                  isOpen: true,
                                  workflowId: workflow.id,
                                  stepId: currentStep.id,
                                  action: 'approve'
                                })}
                              >
                                Approve
                              </Button>
                              <Button
                                size="sm"
                                variant="outline"
                                className="text-yellow-600 border-yellow-600"
                                onClick={() => setActionDialog({
                                  isOpen: true,
                                  workflowId: workflow.id,
                                  stepId: currentStep.id,
                                  action: 'request_changes'
                                })}
                              >
                                Request Changes
                              </Button>
                              <Button
                                size="sm"
                                variant="outline"
                                className="text-red-600 border-red-600"
                                onClick={() => setActionDialog({
                                  isOpen: true,
                                  workflowId: workflow.id,
                                  stepId: currentStep.id,
                                  action: 'reject'
                                })}
                              >
                                Reject
                              </Button>
                            </>
                          )}
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                )
              })}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Action Confirmation Dialog */}
      <Dialog open={actionDialog.isOpen} onOpenChange={(open) => {
        if (!open) {
          setActionDialog({ isOpen: false, workflowId: '', stepId: '', action: 'approve' })
          setActionComment('')
        }
      }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {actionDialog.action === 'approve' ? 'Approve Content' :
               actionDialog.action === 'reject' ? 'Reject Content' : 'Request Changes'}
            </DialogTitle>
            <DialogDescription>
              {actionDialog.action === 'approve' ? 'Provide feedback for this approval (optional)' :
               actionDialog.action === 'reject' ? 'Please explain why you are rejecting this content' :
               'Describe what changes are needed'}
            </DialogDescription>
          </DialogHeader>
          <div className="py-4">
            <Textarea
              placeholder={
                actionDialog.action === 'approve' ? 'Add comments about the approval...' :
                actionDialog.action === 'reject' ? 'Explain the reasons for rejection...' :
                'Describe the required changes...'
              }
              value={actionComment}
              onChange={(e) => setActionComment(e.target.value)}
              required={actionDialog.action !== 'approve'}
            />
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => {
                setActionDialog({ isOpen: false, workflowId: '', stepId: '', action: 'approve' })
                setActionComment('')
              }}
            >
              Cancel
            </Button>
            <Button
              onClick={handleAction}
              disabled={actionDialog.action !== 'approve' && !actionComment.trim()}
              className={
                actionDialog.action === 'approve' ? 'bg-green-600 hover:bg-green-700' :
                actionDialog.action === 'reject' ? 'bg-red-600 hover:bg-red-700' :
                'bg-yellow-600 hover:bg-yellow-700'
              }
            >
              {actionDialog.action === 'approve' ? 'Approve' :
               actionDialog.action === 'reject' ? 'Reject' : 'Request Changes'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}