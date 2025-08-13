'use client'

import React, { useState, useEffect } from 'react'
import { ApprovalWorkflow, ApprovalRequest, User } from '@/types'
import { validateComponentAccess } from '@/lib/permissions'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger } from '@/components/ui/alert-dialog'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { 
  Search,
  Filter,
  Plus,
  Settings,
  Eye,
  Edit,
  Trash2,
  Play,
  Pause,
  Clock,
  CheckCircle,
  XCircle,
  AlertTriangle,
  Users,
  Activity,
  TrendingUp,
  BarChart3,
  Calendar,
  FileText,
  Workflow,
  RefreshCw,
  Download,
  Upload,
  MoreVertical
} from 'lucide-react'

export interface WorkflowDashboardProps {
  workflows: ApprovalWorkflow[]
  requests: ApprovalRequest[]
  currentUser: User
  onCreateWorkflow: () => void
  onEditWorkflow: (workflow: ApprovalWorkflow) => void
  onDeleteWorkflow: (workflowId: string) => void
  onToggleWorkflow: (workflowId: string, isActive: boolean) => void
  onViewWorkflow: (workflow: ApprovalWorkflow) => void
  onRefresh: () => void
  isLoading?: boolean
}

interface WorkflowStats {
  total: number
  active: number
  pending: number
  completed: number
  avgApprovalTime: number
  successRate: number
}

interface RequestStats {
  total: number
  pending: number
  inProgress: number
  approved: number
  rejected: number
  overdue: number
}

const FILTER_OPTIONS = [
  { value: 'all', label: 'All Workflows' },
  { value: 'active', label: 'Active Only' },
  { value: 'inactive', label: 'Inactive Only' },
  { value: 'campaign', label: 'Campaign Workflows' },
  { value: 'content', label: 'Content Workflows' },
  { value: 'brand', label: 'Brand Workflows' },
  { value: 'journey', label: 'Journey Workflows' }
]

const STATUS_COLORS = {
  PENDING: 'bg-yellow-100 text-yellow-800 border-yellow-200',
  IN_PROGRESS: 'bg-blue-100 text-blue-800 border-blue-200',
  APPROVED: 'bg-green-100 text-green-800 border-green-200',
  REJECTED: 'bg-red-100 text-red-800 border-red-200',
  CANCELLED: 'bg-gray-100 text-gray-800 border-gray-200',
  EXPIRED: 'bg-orange-100 text-orange-800 border-orange-200',
  ESCALATED: 'bg-purple-100 text-purple-800 border-purple-200'
}

const PRIORITY_COLORS = {
  LOW: 'bg-gray-100 text-gray-800',
  MEDIUM: 'bg-blue-100 text-blue-800',
  HIGH: 'bg-orange-100 text-orange-800',
  URGENT: 'bg-red-100 text-red-800'
}

const WorkflowCard: React.FC<{
  workflow: ApprovalWorkflow
  onEdit: () => void
  onDelete: () => void
  onToggle: () => void
  onView: () => void
  canManage: boolean
}> = ({ workflow, onEdit, onDelete, onToggle, onView, canManage }) => {
  const applicableTypes = Array.isArray(workflow.applicableTypes) 
    ? workflow.applicableTypes 
    : JSON.parse(workflow.applicableTypes || '[]')

  const activeRequestsCount = workflow.requests?.filter(r => 
    ['PENDING', 'IN_PROGRESS'].includes(r.status)
  ).length || 0

  const completedRequestsCount = workflow.requests?.filter(r => 
    ['APPROVED', 'REJECTED'].includes(r.status)
  ).length || 0

  return (
    <Card className={`transition-all hover:shadow-md ${!workflow.isActive ? 'opacity-60' : ''}`}>
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <CardTitle className="text-lg">{workflow.name}</CardTitle>
              <Badge variant={workflow.isActive ? 'default' : 'secondary'}>
                {workflow.isActive ? 'Active' : 'Inactive'}
              </Badge>
            </div>
            <CardDescription className="line-clamp-2">
              {workflow.description || 'No description provided'}
            </CardDescription>
          </div>
          
          {canManage && (
            <div className="flex items-center gap-1">
              <Button variant="ghost" size="sm" onClick={onView}>
                <Eye className="h-4 w-4" />
              </Button>
              <Button variant="ghost" size="sm" onClick={onEdit}>
                <Edit className="h-4 w-4" />
              </Button>
              <Button variant="ghost" size="sm" onClick={onToggle}>
                {workflow.isActive ? <Pause className="h-4 w-4" /> : <Play className="h-4 w-4" />}
              </Button>
              <AlertDialog>
                <AlertDialogTrigger asChild>
                  <Button variant="ghost" size="sm">
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>Delete Workflow</AlertDialogTitle>
                    <AlertDialogDescription>
                      Are you sure you want to delete "{workflow.name}"? This action cannot be undone.
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Cancel</AlertDialogCancel>
                    <AlertDialogAction onClick={onDelete}>Delete</AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            </div>
          )}
        </div>
      </CardHeader>
      
      <CardContent className="space-y-4">
        <div className="flex items-center gap-4 text-sm text-muted-foreground">
          <div className="flex items-center gap-1">
            <Users className="h-4 w-4" />
            <span>{workflow.stages?.length || 0} stages</span>
          </div>
          <div className="flex items-center gap-1">
            <Activity className="h-4 w-4" />
            <span>{activeRequestsCount} active</span>
          </div>
          <div className="flex items-center gap-1">
            <CheckCircle className="h-4 w-4" />
            <span>{completedRequestsCount} completed</span>
          </div>
        </div>
        
        <div className="space-y-2">
          <Label className="text-xs">Applicable Types</Label>
          <div className="flex flex-wrap gap-1">
            {applicableTypes.map((type: string) => (
              <Badge key={type} variant="outline" className="text-xs">
                {type.toLowerCase()}
              </Badge>
            ))}
          </div>
        </div>
        
        <div className="grid grid-cols-2 gap-2 text-xs text-muted-foreground">
          <div>Auto-start: {workflow.autoStart ? 'Yes' : 'No'}</div>
          <div>Parallel stages: {workflow.allowParallelStages ? 'Yes' : 'No'}</div>
          <div>Timeout: {workflow.defaultTimeoutHours}h</div>
          <div>All approvers: {workflow.requireAllApprovers ? 'Yes' : 'No'}</div>
        </div>
      </CardContent>
    </Card>
  )
}

const RequestCard: React.FC<{
  request: ApprovalRequest
  onView: () => void
}> = ({ request, onView }) => {
  const isOverdue = request.dueDate && new Date(request.dueDate) < new Date()
  const daysSinceCreated = Math.floor(
    (new Date().getTime() - new Date(request.createdAt).getTime()) / (1000 * 60 * 60 * 24)
  )

  return (
    <Card className="transition-all hover:shadow-sm cursor-pointer" onClick={onView}>
      <CardContent className="p-4">
        <div className="flex items-start justify-between mb-3">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <Badge className={`text-xs ${STATUS_COLORS[request.status as keyof typeof STATUS_COLORS]}`}>
                {request.status.replace('_', ' ').toLowerCase()}
              </Badge>
              <Badge className={`text-xs ${PRIORITY_COLORS[request.priority as keyof typeof PRIORITY_COLORS]}`}>
                {request.priority.toLowerCase()}
              </Badge>
              {isOverdue && (
                <Badge variant="destructive" className="text-xs">
                  <Clock className="h-3 w-3 mr-1" />
                  Overdue
                </Badge>
              )}
            </div>
            <div className="text-sm font-medium">
              {request.targetType.toLowerCase()} approval
            </div>
          </div>
        </div>
        
        <div className="space-y-2 text-xs text-muted-foreground">
          <div>Workflow: {request.workflow?.name}</div>
          <div>Created {daysSinceCreated} days ago</div>
          {request.currentStage && (
            <div className="flex items-center gap-1">
              <Workflow className="h-3 w-3" />
              Current: {request.currentStage.name}
            </div>
          )}
          {request.dueDate && (
            <div className="flex items-center gap-1">
              <Calendar className="h-3 w-3" />
              Due: {new Date(request.dueDate).toLocaleDateString()}
            </div>
          )}
        </div>
        
        {request.notes && (
          <div className="mt-2 text-xs text-muted-foreground line-clamp-2">
            {request.notes}
          </div>
        )}
      </CardContent>
    </Card>
  )
}

export const WorkflowDashboard: React.FC<WorkflowDashboardProps> = ({
  workflows,
  requests,
  currentUser,
  onCreateWorkflow,
  onEditWorkflow,
  onDeleteWorkflow,
  onToggleWorkflow,
  onViewWorkflow,
  onRefresh,
  isLoading = false
}) => {
  const [searchTerm, setSearchTerm] = useState('')
  const [filterType, setFilterType] = useState('all')
  const [activeTab, setActiveTab] = useState('overview')

  // Check permissions
  const canManageWorkflows = validateComponentAccess(currentUser.role, 'canManageWorkflows')
  const canViewWorkflows = validateComponentAccess(currentUser.role, 'canViewWorkflows')

  // Calculate statistics
  const workflowStats: WorkflowStats = {
    total: workflows.length,
    active: workflows.filter(w => w.isActive).length,
    pending: requests.filter(r => r.status === 'PENDING').length,
    completed: requests.filter(r => ['APPROVED', 'REJECTED'].includes(r.status)).length,
    avgApprovalTime: 2.5, // Would be calculated from actual data
    successRate: 85 // Would be calculated from actual data
  }

  const requestStats: RequestStats = {
    total: requests.length,
    pending: requests.filter(r => r.status === 'PENDING').length,
    inProgress: requests.filter(r => r.status === 'IN_PROGRESS').length,
    approved: requests.filter(r => r.status === 'APPROVED').length,
    rejected: requests.filter(r => r.status === 'REJECTED').length,
    overdue: requests.filter(r => 
      r.dueDate && new Date(r.dueDate) < new Date() && 
      !['APPROVED', 'REJECTED', 'CANCELLED'].includes(r.status)
    ).length
  }

  // Filter workflows
  const filteredWorkflows = workflows.filter(workflow => {
    const matchesSearch = workflow.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         workflow.description?.toLowerCase().includes(searchTerm.toLowerCase())
    
    let matchesFilter = true
    switch (filterType) {
      case 'active':
        matchesFilter = workflow.isActive
        break
      case 'inactive':
        matchesFilter = !workflow.isActive
        break
      case 'campaign':
      case 'content':
      case 'brand':
      case 'journey':
        const applicableTypes = Array.isArray(workflow.applicableTypes) 
          ? workflow.applicableTypes 
          : JSON.parse(workflow.applicableTypes || '[]')
        matchesFilter = applicableTypes.some((type: string) => 
          type.toLowerCase() === filterType.toUpperCase()
        )
        break
    }
    
    return matchesSearch && matchesFilter
  })

  // Recent requests (last 10)
  const recentRequests = requests
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
    .slice(0, 10)

  if (!canViewWorkflows) {
    return (
      <Card>
        <CardContent className="pt-6">
          <div className="text-center text-muted-foreground">
            <Workflow className="h-12 w-12 mx-auto mb-4 opacity-50" />
            <p>You don't have permission to view workflows.</p>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Workflow Dashboard</h2>
          <p className="text-muted-foreground">
            Manage approval workflows and monitor request status
          </p>
        </div>
        
        <div className="flex gap-2">
          <Button variant="outline" onClick={onRefresh} disabled={isLoading}>
            <RefreshCw className={`h-4 w-4 mr-2 ${isLoading ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
          {canManageWorkflows && (
            <Button onClick={onCreateWorkflow}>
              <Plus className="h-4 w-4 mr-2" />
              Create Workflow
            </Button>
          )}
        </div>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Workflows</CardTitle>
            <Workflow className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{workflowStats.total}</div>
            <p className="text-xs text-muted-foreground">
              {workflowStats.active} active
            </p>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Pending Requests</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{requestStats.pending}</div>
            <p className="text-xs text-muted-foreground">
              {requestStats.overdue} overdue
            </p>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Success Rate</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{workflowStats.successRate}%</div>
            <p className="text-xs text-muted-foreground">
              {requestStats.approved} approved this month
            </p>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg. Approval Time</CardTitle>
            <BarChart3 className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{workflowStats.avgApprovalTime}d</div>
            <p className="text-xs text-muted-foreground">
              Average processing time
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Main Content */}
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList>
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="workflows">Workflows</TabsTrigger>
          <TabsTrigger value="requests">Recent Requests</TabsTrigger>
          <TabsTrigger value="analytics">Analytics</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Active Workflows */}
            <Card>
              <CardHeader>
                <CardTitle>Active Workflows</CardTitle>
                <CardDescription>
                  Currently active approval workflows
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {workflows.filter(w => w.isActive).slice(0, 5).map(workflow => (
                    <div key={workflow.id} className="flex items-center justify-between p-2 border rounded">
                      <div className="space-y-1">
                        <div className="font-medium text-sm">{workflow.name}</div>
                        <div className="text-xs text-muted-foreground">
                          {workflow.stages?.length || 0} stages • {workflow.requests?.filter(r => 
                            ['PENDING', 'IN_PROGRESS'].includes(r.status)
                          ).length || 0} active
                        </div>
                      </div>
                      <Button variant="ghost" size="sm" onClick={() => onViewWorkflow(workflow)}>
                        <Eye className="h-4 w-4" />
                      </Button>
                    </div>
                  ))}
                  {workflows.filter(w => w.isActive).length === 0 && (
                    <div className="text-center text-muted-foreground py-4">
                      No active workflows
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>

            {/* Recent Requests */}
            <Card>
              <CardHeader>
                <CardTitle>Recent Requests</CardTitle>
                <CardDescription>
                  Latest approval requests requiring attention
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {recentRequests.slice(0, 5).map(request => (
                    <div key={request.id} className="flex items-center justify-between p-2 border rounded">
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <Badge className={`text-xs ${STATUS_COLORS[request.status as keyof typeof STATUS_COLORS]}`}>
                            {request.status.replace('_', ' ').toLowerCase()}
                          </Badge>
                          <span className="text-sm font-medium">
                            {request.targetType.toLowerCase()}
                          </span>
                        </div>
                        <div className="text-xs text-muted-foreground">
                          {request.workflow?.name} • Stage: {request.currentStage?.name}
                        </div>
                      </div>
                      <Button variant="ghost" size="sm">
                        <Eye className="h-4 w-4" />
                      </Button>
                    </div>
                  ))}
                  {recentRequests.length === 0 && (
                    <div className="text-center text-muted-foreground py-4">
                      No recent requests
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="workflows" className="space-y-6">
          {/* Search and Filter */}
          <div className="flex flex-col sm:flex-row gap-4">
            <div className="flex-1">
              <div className="relative">
                <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Search workflows..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="pl-9"
                />
              </div>
            </div>
            <Select value={filterType} onValueChange={setFilterType}>
              <SelectTrigger className="w-full sm:w-48">
                <Filter className="h-4 w-4 mr-2" />
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {FILTER_OPTIONS.map(option => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Workflows Grid */}
          {filteredWorkflows.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {filteredWorkflows.map(workflow => (
                <WorkflowCard
                  key={workflow.id}
                  workflow={workflow}
                  onEdit={() => onEditWorkflow(workflow)}
                  onDelete={() => onDeleteWorkflow(workflow.id)}
                  onToggle={() => onToggleWorkflow(workflow.id, !workflow.isActive)}
                  onView={() => onViewWorkflow(workflow)}
                  canManage={canManageWorkflows}
                />
              ))}
            </div>
          ) : (
            <Card>
              <CardContent className="pt-6">
                <div className="text-center text-muted-foreground">
                  <Workflow className="h-12 w-12 mx-auto mb-4 opacity-50" />
                  <p>No workflows found matching your criteria</p>
                  {canManageWorkflows && (
                    <Button className="mt-4" onClick={onCreateWorkflow}>
                      <Plus className="h-4 w-4 mr-2" />
                      Create First Workflow
                    </Button>
                  )}
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        <TabsContent value="requests" className="space-y-6">
          {recentRequests.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {recentRequests.map(request => (
                <RequestCard
                  key={request.id}
                  request={request}
                  onView={() => {/* Handle view request */}}
                />
              ))}
            </div>
          ) : (
            <Card>
              <CardContent className="pt-6">
                <div className="text-center text-muted-foreground">
                  <FileText className="h-12 w-12 mx-auto mb-4 opacity-50" />
                  <p>No approval requests found</p>
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        <TabsContent value="analytics" className="space-y-6">
          <Card>
            <CardContent className="pt-6">
              <div className="text-center text-muted-foreground">
                <BarChart3 className="h-12 w-12 mx-auto mb-4 opacity-50" />
                <p>Analytics dashboard coming soon</p>
                <p className="text-sm">Track workflow performance, approval times, and success rates</p>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}

export default WorkflowDashboard