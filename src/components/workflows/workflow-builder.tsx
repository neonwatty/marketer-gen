'use client'

import React, { useState, useEffect } from 'react'
import { ApprovalWorkflow, ApprovalStage, ApprovalCondition, User, UserRole } from '@/types'
import { validateComponentAccess } from '@/lib/permissions'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Switch } from '@/components/ui/switch'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger } from '@/components/ui/alert-dialog'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { 
  Settings, 
  Plus, 
  Minus, 
  ArrowRight, 
  ArrowDown,
  Users, 
  Clock, 
  CheckCircle, 
  XCircle,
  Play,
  Pause,
  RotateCcw,
  Workflow,
  UserCheck,
  Timer,
  Zap,
  Shield,
  GitBranch,
  Save,
  Eye,
  Edit
} from 'lucide-react'

export interface WorkflowBuilderProps {
  workflow?: ApprovalWorkflow
  teamUsers: User[]
  currentUser: User
  onSave: (workflow: Partial<ApprovalWorkflow>) => Promise<void>
  onPreview: (workflow: Partial<ApprovalWorkflow>) => void
  isEditing?: boolean
  isLoading?: boolean
}

interface WorkflowForm {
  name: string
  description: string
  applicableTypes: string[]
  autoStart: boolean
  allowParallelStages: boolean
  requireAllApprovers: boolean
  defaultTimeoutHours: number
  isActive: boolean
  stages: StageForm[]
}

interface StageForm {
  id: string
  name: string
  description: string
  order: number
  approversRequired: number
  approvers: string[]
  approverRoles: UserRole[]
  autoApprove: boolean
  timeoutHours?: number
  skipConditions: ApprovalCondition[]
}

const CONTENT_TYPES = [
  { value: 'campaign', label: 'Campaigns' },
  { value: 'journey', label: 'Journeys' },
  { value: 'content', label: 'Content' },
  { value: 'brand', label: 'Brand Assets' }
]

const USER_ROLES: { value: UserRole; label: string }[] = [
  { value: 'viewer', label: 'Viewer' },
  { value: 'creator', label: 'Creator' },
  { value: 'reviewer', label: 'Reviewer' },
  { value: 'approver', label: 'Approver' },
  { value: 'publisher', label: 'Publisher' },
  { value: 'admin', label: 'Admin' }
]

const CONDITION_TYPES = [
  { value: 'user_role', label: 'User Role' },
  { value: 'content_type', label: 'Content Type' },
  { value: 'budget_threshold', label: 'Budget Threshold' },
  { value: 'custom', label: 'Custom Rule' }
]

const CONDITION_OPERATORS = [
  { value: 'equals', label: 'Equals' },
  { value: 'not_equals', label: 'Not Equals' },
  { value: 'greater_than', label: 'Greater Than' },
  { value: 'less_than', label: 'Less Than' },
  { value: 'contains', label: 'Contains' }
]

interface StageBuilderProps {
  stage: StageForm
  index: number
  teamUsers: User[]
  onUpdate: (index: number, stage: StageForm) => void
  onRemove: (index: number) => void
  onMoveUp: (index: number) => void
  onMoveDown: (index: number) => void
  canMoveUp: boolean
  canMoveDown: boolean
}

const StageBuilder: React.FC<StageBuilderProps> = ({
  stage,
  index,
  teamUsers,
  onUpdate,
  onRemove,
  onMoveUp,
  onMoveDown,
  canMoveUp,
  canMoveDown
}) => {
  const [showConditions, setShowConditions] = useState(false)

  const updateStage = (updates: Partial<StageForm>) => {
    onUpdate(index, { ...stage, ...updates })
  }

  const addCondition = () => {
    const newCondition: ApprovalCondition = {
      type: 'user_role',
      operator: 'equals',
      value: ''
    }
    updateStage({
      skipConditions: [...stage.skipConditions, newCondition]
    })
  }

  const updateCondition = (conditionIndex: number, condition: ApprovalCondition) => {
    const newConditions = [...stage.skipConditions]
    newConditions[conditionIndex] = condition
    updateStage({ skipConditions: newConditions })
  }

  const removeCondition = (conditionIndex: number) => {
    const newConditions = stage.skipConditions.filter((_, i) => i !== conditionIndex)
    updateStage({ skipConditions: newConditions })
  }

  const toggleApprover = (userId: string) => {
    const isSelected = stage.approvers.includes(userId)
    const newApprovers = isSelected
      ? stage.approvers.filter(id => id !== userId)
      : [...stage.approvers, userId]
    
    updateStage({ approvers: newApprovers })
  }

  const toggleRole = (role: UserRole) => {
    const isSelected = stage.approverRoles.includes(role)
    const newRoles = isSelected
      ? stage.approverRoles.filter(r => r !== role)
      : [...stage.approverRoles, role]
    
    updateStage({ approverRoles: newRoles })
  }

  return (
    <Card className="border-l-4 border-l-primary">
      <CardHeader>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex items-center justify-center w-8 h-8 bg-primary text-primary-foreground rounded-full text-sm font-bold">
              {index + 1}
            </div>
            <div>
              <CardTitle className="text-lg">{stage.name || `Stage ${index + 1}`}</CardTitle>
              <CardDescription>{stage.description || 'Approval stage'}</CardDescription>
            </div>
          </div>
          
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => onMoveUp(index)}
              disabled={!canMoveUp}
            >
              ↑
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => onMoveDown(index)}
              disabled={!canMoveDown}
            >
              ↓
            </Button>
            <AlertDialog>
              <AlertDialogTrigger asChild>
                <Button variant="outline" size="sm">
                  <Minus className="h-4 w-4" />
                </Button>
              </AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Remove Stage</AlertDialogTitle>
                  <AlertDialogDescription>
                    Are you sure you want to remove this approval stage?
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Cancel</AlertDialogCancel>
                  <AlertDialogAction onClick={() => onRemove(index)}>
                    Remove
                  </AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          </div>
        </div>
      </CardHeader>
      
      <CardContent className="space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="space-y-2">
            <Label htmlFor={`stage-name-${index}`}>Stage Name</Label>
            <Input
              id={`stage-name-${index}`}
              value={stage.name}
              onChange={(e) => updateStage({ name: e.target.value })}
              placeholder="e.g., Content Review"
            />
          </div>
          
          <div className="space-y-2">
            <Label htmlFor={`approvers-required-${index}`}>Approvers Required</Label>
            <Input
              id={`approvers-required-${index}`}
              type="number"
              min="1"
              value={stage.approversRequired}
              onChange={(e) => updateStage({ approversRequired: parseInt(e.target.value) || 1 })}
            />
          </div>
        </div>
        
        <div className="space-y-2">
          <Label htmlFor={`stage-description-${index}`}>Description</Label>
          <Textarea
            id={`stage-description-${index}`}
            value={stage.description}
            onChange={(e) => updateStage({ description: e.target.value })}
            placeholder="Describe what happens in this stage..."
            rows={2}
          />
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="space-y-2">
            <Label htmlFor={`timeout-${index}`}>Timeout (hours)</Label>
            <Input
              id={`timeout-${index}`}
              type="number"
              min="1"
              value={stage.timeoutHours || ''}
              onChange={(e) => updateStage({ timeoutHours: e.target.value ? parseInt(e.target.value) : undefined })}
              placeholder="Use workflow default"
            />
          </div>
          
          <div className="flex items-center space-x-2">
            <Switch
              id={`auto-approve-${index}`}
              checked={stage.autoApprove}
              onCheckedChange={(checked) => updateStage({ autoApprove: checked })}
            />
            <Label htmlFor={`auto-approve-${index}`}>Auto-approve</Label>
          </div>
        </div>
        
        <Tabs defaultValue="users" className="w-full">
          <TabsList>
            <TabsTrigger value="users">Specific Users</TabsTrigger>
            <TabsTrigger value="roles">User Roles</TabsTrigger>
          </TabsList>
          
          <TabsContent value="users" className="space-y-3">
            <Label>Select Approvers</Label>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-2 max-h-48 overflow-y-auto">
              {teamUsers.map((user) => (
                <div
                  key={user.id}
                  className={`flex items-center gap-3 p-2 rounded border cursor-pointer transition-colors ${
                    stage.approvers.includes(user.id.toString())
                      ? 'bg-primary/10 border-primary'
                      : 'hover:bg-muted'
                  }`}
                  onClick={() => toggleApprover(user.id.toString())}
                >
                  <Avatar className="h-6 w-6">
                    <AvatarImage src={user.avatar} />
                    <AvatarFallback className="text-xs">
                      {user.name?.split(' ').map(n => n[0]).join('') || 'U'}
                    </AvatarFallback>
                  </Avatar>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium truncate">{user.name}</div>
                    <div className="text-xs text-muted-foreground truncate">{user.email}</div>
                  </div>
                  {stage.approvers.includes(user.id.toString()) && (
                    <CheckCircle className="h-4 w-4 text-primary" />
                  )}
                </div>
              ))}
            </div>
          </TabsContent>
          
          <TabsContent value="roles" className="space-y-3">
            <Label>Select User Roles</Label>
            <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
              {USER_ROLES.map((role) => (
                <div
                  key={role.value}
                  className={`flex items-center gap-2 p-2 rounded border cursor-pointer transition-colors ${
                    stage.approverRoles.includes(role.value)
                      ? 'bg-primary/10 border-primary'
                      : 'hover:bg-muted'
                  }`}
                  onClick={() => toggleRole(role.value)}
                >
                  <Shield className="h-4 w-4" />
                  <span className="text-sm">{role.label}</span>
                  {stage.approverRoles.includes(role.value) && (
                    <CheckCircle className="h-4 w-4 text-primary ml-auto" />
                  )}
                </div>
              ))}
            </div>
          </TabsContent>
        </Tabs>
        
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <Label>Skip Conditions</Label>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setShowConditions(!showConditions)}
            >
              {showConditions ? 'Hide' : 'Show'} Conditions
            </Button>
          </div>
          
          {showConditions && (
            <div className="space-y-3 p-3 border rounded">
              {stage.skipConditions.map((condition, conditionIndex) => (
                <div key={conditionIndex} className="grid grid-cols-1 md:grid-cols-4 gap-2 items-end">
                  <div className="space-y-1">
                    <Label className="text-xs">Type</Label>
                    <Select
                      value={condition.type}
                      onValueChange={(value: any) => 
                        updateCondition(conditionIndex, { ...condition, type: value })
                      }
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {CONDITION_TYPES.map((type) => (
                          <SelectItem key={type.value} value={type.value}>
                            {type.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  
                  <div className="space-y-1">
                    <Label className="text-xs">Operator</Label>
                    <Select
                      value={condition.operator}
                      onValueChange={(value: any) => 
                        updateCondition(conditionIndex, { ...condition, operator: value })
                      }
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {CONDITION_OPERATORS.map((op) => (
                          <SelectItem key={op.value} value={op.value}>
                            {op.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  
                  <div className="space-y-1">
                    <Label className="text-xs">Value</Label>
                    <Input
                      value={condition.value.toString()}
                      onChange={(e) => 
                        updateCondition(conditionIndex, { ...condition, value: e.target.value })
                      }
                      placeholder="Condition value"
                    />
                  </div>
                  
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => removeCondition(conditionIndex)}
                  >
                    <Minus className="h-4 w-4" />
                  </Button>
                </div>
              ))}
              
              <Button
                variant="outline"
                size="sm"
                onClick={addCondition}
                className="w-full"
              >
                <Plus className="h-4 w-4 mr-2" />
                Add Condition
              </Button>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  )
}

export const WorkflowBuilder: React.FC<WorkflowBuilderProps> = ({
  workflow,
  teamUsers,
  currentUser,
  onSave,
  onPreview,
  isEditing = false,
  isLoading = false
}) => {
  const [form, setForm] = useState<WorkflowForm>({
    name: workflow?.name || '',
    description: workflow?.description || '',
    applicableTypes: [],
    autoStart: workflow?.autoStart || false,
    allowParallelStages: workflow?.allowParallelStages || false,
    requireAllApprovers: workflow?.requireAllApprovers || true,
    defaultTimeoutHours: workflow?.defaultTimeoutHours || 72,
    isActive: workflow?.isActive !== false,
    stages: []
  })

  const [activeTab, setActiveTab] = useState('basic')

  // Check if user can configure workflows
  const canConfigureWorkflow = validateComponentAccess(currentUser.role, 'canConfigureWorkflow')

  useEffect(() => {
    if (workflow) {
      // Parse applicable types from JSON string
      let applicableTypes: string[] = []
      try {
        applicableTypes = typeof workflow.applicableTypes === 'string' 
          ? JSON.parse(workflow.applicableTypes)
          : workflow.applicableTypes || []
      } catch (e) {
        applicableTypes = []
      }

      setForm({
        name: workflow.name,
        description: workflow.description || '',
        applicableTypes,
        autoStart: workflow.autoStart || false,
        allowParallelStages: workflow.allowParallelStages || false,
        requireAllApprovers: workflow.requireAllApprovers !== false,
        defaultTimeoutHours: workflow.defaultTimeoutHours || 72,
        isActive: workflow.isActive !== false,
        stages: workflow.stages?.map((stage, index) => ({
          id: stage.id.toString(),
          name: stage.name,
          description: stage.description || '',
          order: index,
          approversRequired: stage.approversRequired,
          approvers: Array.isArray(stage.approvers) ? stage.approvers.map(String) : [],
          approverRoles: [],
          autoApprove: stage.autoApprove,
          timeoutHours: stage.timeoutHours,
          skipConditions: stage.skipConditions || []
        })) || []
      })
    }
  }, [workflow])

  const updateForm = (updates: Partial<WorkflowForm>) => {
    setForm(prev => ({ ...prev, ...updates }))
  }

  const addStage = () => {
    const newStage: StageForm = {
      id: `stage-${Date.now()}`,
      name: `Stage ${form.stages.length + 1}`,
      description: '',
      order: form.stages.length,
      approversRequired: 1,
      approvers: [],
      approverRoles: [],
      autoApprove: false,
      skipConditions: []
    }
    
    updateForm({
      stages: [...form.stages, newStage]
    })
  }

  const updateStage = (index: number, stage: StageForm) => {
    const newStages = [...form.stages]
    newStages[index] = { ...stage, order: index }
    updateForm({ stages: newStages })
  }

  const removeStage = (index: number) => {
    const newStages = form.stages.filter((_, i) => i !== index)
    // Update order for remaining stages
    const reorderedStages = newStages.map((stage, i) => ({
      ...stage,
      order: i
    }))
    updateForm({ stages: reorderedStages })
  }

  const moveStage = (index: number, direction: 'up' | 'down') => {
    if (
      (direction === 'up' && index === 0) ||
      (direction === 'down' && index === form.stages.length - 1)
    ) {
      return
    }

    const newStages = [...form.stages]
    const targetIndex = direction === 'up' ? index - 1 : index + 1
    
    // Swap stages
    ;[newStages[index], newStages[targetIndex]] = [newStages[targetIndex], newStages[index]]
    
    // Update orders
    newStages[index].order = index
    newStages[targetIndex].order = targetIndex
    
    updateForm({ stages: newStages })
  }

  const handleSave = async () => {
    if (!canConfigureWorkflow) return

    const workflowData: Partial<ApprovalWorkflow> = {
      name: form.name,
      description: form.description,
      applicableTypes: form.applicableTypes,
      autoStart: form.autoStart,
      allowParallelStages: form.allowParallelStages,
      requireAllApprovers: form.requireAllApprovers,
      defaultTimeoutHours: form.defaultTimeoutHours,
      isActive: form.isActive,
      stages: form.stages.map((stage, index) => ({
        id: stage.id,
        name: stage.name,
        description: stage.description,
        order: index,
        approversRequired: stage.approversRequired,
        approvers: stage.approvers,
        autoApprove: stage.autoApprove,
        timeoutHours: stage.timeoutHours,
        skipConditions: stage.skipConditions
      }))
    }

    await onSave(workflowData)
  }

  const handlePreview = () => {
    const workflowData: Partial<ApprovalWorkflow> = {
      name: form.name,
      description: form.description,
      applicableTypes: form.applicableTypes,
      stages: form.stages
    }
    onPreview(workflowData)
  }

  if (!canConfigureWorkflow) {
    return (
      <Card>
        <CardContent className="pt-6">
          <div className="text-center text-muted-foreground">
            <Workflow className="h-12 w-12 mx-auto mb-4 opacity-50" />
            <p>You don't have permission to configure workflows.</p>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">
            {isEditing ? 'Edit' : 'Create'} Approval Workflow
          </h2>
          <p className="text-muted-foreground">
            Configure approval stages and routing rules for your team
          </p>
        </div>
        
        <div className="flex gap-2">
          <Button variant="outline" onClick={handlePreview}>
            <Eye className="h-4 w-4 mr-2" />
            Preview
          </Button>
          <Button onClick={handleSave} disabled={isLoading}>
            <Save className="h-4 w-4 mr-2" />
            {isLoading ? 'Saving...' : 'Save Workflow'}
          </Button>
        </div>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList>
          <TabsTrigger value="basic">Basic Settings</TabsTrigger>
          <TabsTrigger value="stages">Approval Stages</TabsTrigger>
          <TabsTrigger value="advanced">Advanced Settings</TabsTrigger>
        </TabsList>

        <TabsContent value="basic" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Workflow Details</CardTitle>
              <CardDescription>
                Basic information and content types for this workflow
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="workflow-name">Workflow Name</Label>
                  <Input
                    id="workflow-name"
                    value={form.name}
                    onChange={(e) => updateForm({ name: e.target.value })}
                    placeholder="e.g., Marketing Content Review"
                  />
                </div>
                
                <div className="space-y-2">
                  <Label>Status</Label>
                  <div className="flex items-center space-x-2">
                    <Switch
                      checked={form.isActive}
                      onCheckedChange={(checked) => updateForm({ isActive: checked })}
                    />
                    <Label>{form.isActive ? 'Active' : 'Inactive'}</Label>
                  </div>
                </div>
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="workflow-description">Description</Label>
                <Textarea
                  id="workflow-description"
                  value={form.description}
                  onChange={(e) => updateForm({ description: e.target.value })}
                  placeholder="Describe when and how this workflow should be used..."
                  rows={3}
                />
              </div>
              
              <div className="space-y-2">
                <Label>Applicable Content Types</Label>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                  {CONTENT_TYPES.map((type) => (
                    <div
                      key={type.value}
                      className={`flex items-center gap-2 p-2 rounded border cursor-pointer transition-colors ${
                        form.applicableTypes.includes(type.value)
                          ? 'bg-primary/10 border-primary'
                          : 'hover:bg-muted'
                      }`}
                      onClick={() => {
                        const isSelected = form.applicableTypes.includes(type.value)
                        const newTypes = isSelected
                          ? form.applicableTypes.filter(t => t !== type.value)
                          : [...form.applicableTypes, type.value]
                        updateForm({ applicableTypes: newTypes })
                      }}
                    >
                      <span className="text-sm">{type.label}</span>
                      {form.applicableTypes.includes(type.value) && (
                        <CheckCircle className="h-4 w-4 text-primary ml-auto" />
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="stages" className="space-y-6">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-lg font-semibold">Approval Stages</h3>
              <p className="text-sm text-muted-foreground">
                Configure the approval process with multiple stages
              </p>
            </div>
            
            <Button onClick={addStage}>
              <Plus className="h-4 w-4 mr-2" />
              Add Stage
            </Button>
          </div>

          {form.stages.length === 0 ? (
            <Card>
              <CardContent className="pt-6">
                <div className="text-center py-8 text-muted-foreground">
                  <GitBranch className="h-12 w-12 mx-auto mb-4 opacity-50" />
                  <p>No approval stages configured</p>
                  <p className="text-sm">Add stages to define your approval process</p>
                </div>
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-4">
              {form.stages.map((stage, index) => (
                <div key={stage.id} className="relative">
                  <StageBuilder
                    stage={stage}
                    index={index}
                    teamUsers={teamUsers}
                    onUpdate={updateStage}
                    onRemove={removeStage}
                    onMoveUp={(i) => moveStage(i, 'up')}
                    onMoveDown={(i) => moveStage(i, 'down')}
                    canMoveUp={index > 0}
                    canMoveDown={index < form.stages.length - 1}
                  />
                  
                  {index < form.stages.length - 1 && (
                    <div className="flex justify-center py-2">
                      <ArrowDown className="h-6 w-6 text-muted-foreground" />
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </TabsContent>

        <TabsContent value="advanced" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Advanced Settings</CardTitle>
              <CardDescription>
                Fine-tune workflow behavior and automation
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <Label>Auto-start Workflow</Label>
                      <p className="text-xs text-muted-foreground">
                        Automatically start approval when content is created
                      </p>
                    </div>
                    <Switch
                      checked={form.autoStart}
                      onCheckedChange={(checked) => updateForm({ autoStart: checked })}
                    />
                  </div>
                  
                  <div className="flex items-center justify-between">
                    <div>
                      <Label>Allow Parallel Stages</Label>
                      <p className="text-xs text-muted-foreground">
                        Multiple stages can run simultaneously
                      </p>
                    </div>
                    <Switch
                      checked={form.allowParallelStages}
                      onCheckedChange={(checked) => updateForm({ allowParallelStages: checked })}
                    />
                  </div>
                  
                  <div className="flex items-center justify-between">
                    <div>
                      <Label>Require All Approvers</Label>
                      <p className="text-xs text-muted-foreground">
                        All specified approvers must approve in each stage
                      </p>
                    </div>
                    <Switch
                      checked={form.requireAllApprovers}
                      onCheckedChange={(checked) => updateForm({ requireAllApprovers: checked })}
                    />
                  </div>
                </div>
                
                <div className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="default-timeout">Default Timeout (hours)</Label>
                    <Input
                      id="default-timeout"
                      type="number"
                      min="1"
                      value={form.defaultTimeoutHours}
                      onChange={(e) => updateForm({ defaultTimeoutHours: parseInt(e.target.value) || 72 })}
                    />
                    <p className="text-xs text-muted-foreground">
                      Default time limit for each approval stage
                    </p>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}

export default WorkflowBuilder