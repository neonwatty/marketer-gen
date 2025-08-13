'use client'

import React, { useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Progress } from '@/components/ui/progress'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Separator } from '@/components/ui/separator'
import {
  AlertTriangle,
  Clock,
  TrendingDown,
  TrendingUp,
  Zap,
  Target,
  Users,
  BarChart3,
  Activity,
  Download,
  RefreshCw,
  Filter,
  CheckCircle,
  XCircle,
  PauseCircle,
  FastForward,
  RotateCcw,
  ArrowRight,
  ArrowDown,
  Gauge,
  Timer,
  AlertCircle,
  Settings,
  Lightbulb,
  TrendingFlat
} from 'lucide-react'
import { 
  ResponsiveContainer, 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  Legend,
  LineChart,
  Line,
  AreaChart,
  Area,
  PieChart,
  Pie,
  Cell,
  Sankey,
  FunnelChart,
  Funnel
} from 'recharts'

interface Bottleneck {
  id: string
  name: string
  type: 'process' | 'resource' | 'approval' | 'dependency' | 'system'
  severity: 'critical' | 'high' | 'medium' | 'low'
  frequency: number
  averageDelay: number
  totalImpact: number
  affectedWorkflows: string[]
  rootCause: string
  suggestedSolution: string
  estimatedResolution: number
  costOfInaction: number
  assignee?: string
  status: 'identified' | 'analyzing' | 'in-progress' | 'resolved'
}

interface WorkflowStep {
  id: string
  name: string
  sequence: number
  averageTime: number
  minTime: number
  maxTime: number
  variance: number
  throughput: number
  queueTime: number
  processingTime: number
  bottleneckScore: number
  efficiency: number
}

interface WorkflowAnalysis {
  workflowId: string
  workflowName: string
  totalSteps: number
  criticalPath: string[]
  bottleneckSteps: string[]
  averageProcessingTime: number
  maxCapacity: number
  currentUtilization: number
  steps: WorkflowStep[]
}

const mockBottlenecks: Bottleneck[] = [
  {
    id: '1',
    name: 'Legal Review Queue',
    type: 'approval',
    severity: 'critical',
    frequency: 45,
    averageDelay: 8.2,
    totalImpact: 369,
    affectedWorkflows: ['Content Approval', 'Campaign Launch', 'Partnership Agreements'],
    rootCause: 'Single point approval with limited capacity',
    suggestedSolution: 'Implement parallel review process and pre-approved templates',
    estimatedResolution: 2,
    costOfInaction: 15000,
    assignee: 'Legal Team',
    status: 'analyzing'
  },
  {
    id: '2',
    name: 'Design Asset Creation',
    type: 'process',
    severity: 'high',
    frequency: 32,
    averageDelay: 12.5,
    totalImpact: 400,
    affectedWorkflows: ['Campaign Launch', 'Social Media Content', 'Website Updates'],
    rootCause: 'Complex asset requirements with multiple revision cycles',
    suggestedSolution: 'Create template library and establish clear design specifications',
    estimatedResolution: 3,
    costOfInaction: 12000,
    assignee: 'Design Team',
    status: 'in-progress'
  },
  {
    id: '3',
    name: 'Budget Approval Chain',
    type: 'approval',
    severity: 'high',
    frequency: 28,
    averageDelay: 6.7,
    totalImpact: 188,
    affectedWorkflows: ['Campaign Launch', 'Event Planning', 'Tool Procurement'],
    rootCause: 'Sequential approval process through multiple levels',
    suggestedSolution: 'Implement threshold-based auto-approvals and concurrent reviews',
    estimatedResolution: 1,
    costOfInaction: 8000,
    assignee: 'Finance Team',
    status: 'identified'
  },
  {
    id: '4',
    name: 'Content Translation',
    type: 'resource',
    severity: 'medium',
    frequency: 22,
    averageDelay: 4.3,
    totalImpact: 95,
    affectedWorkflows: ['Global Campaigns', 'Localization', 'Product Launches'],
    rootCause: 'Limited translation resources and external dependencies',
    suggestedSolution: 'Build internal translation capabilities and AI-assisted tools',
    estimatedResolution: 4,
    costOfInaction: 5000,
    assignee: 'Content Team',
    status: 'in-progress'
  },
  {
    id: '5',
    name: 'System Integration Failures',
    type: 'system',
    severity: 'medium',
    frequency: 18,
    averageDelay: 2.8,
    totalImpact: 50,
    affectedWorkflows: ['Data Sync', 'Automated Publishing', 'Analytics Updates'],
    rootCause: 'API rate limits and system compatibility issues',
    suggestedSolution: 'Implement robust error handling and backup processes',
    estimatedResolution: 2,
    costOfInaction: 3000,
    assignee: 'IT Team',
    status: 'resolved'
  },
  {
    id: '6',
    name: 'Stakeholder Feedback Cycles',
    type: 'dependency',
    severity: 'low',
    frequency: 15,
    averageDelay: 3.1,
    totalImpact: 47,
    affectedWorkflows: ['Content Approval', 'Campaign Review', 'Strategy Planning'],
    rootCause: 'Unclear feedback requirements and scheduling conflicts',
    suggestedSolution: 'Establish structured feedback templates and deadlines',
    estimatedResolution: 1,
    costOfInaction: 2000,
    assignee: 'Project Management',
    status: 'identified'
  }
]

const mockWorkflowAnalysis: WorkflowAnalysis[] = [
  {
    workflowId: '1',
    workflowName: 'Content Approval',
    totalSteps: 6,
    criticalPath: ['Creation', 'Review', 'Legal', 'Approval'],
    bottleneckSteps: ['Legal', 'Stakeholder Review'],
    averageProcessingTime: 4.2,
    maxCapacity: 50,
    currentUtilization: 84,
    steps: [
      {
        id: '1', name: 'Content Creation', sequence: 1, averageTime: 0.5, minTime: 0.2, maxTime: 1.2,
        variance: 0.3, throughput: 48, queueTime: 0.1, processingTime: 0.4, bottleneckScore: 2, efficiency: 95
      },
      {
        id: '2', name: 'Initial Review', sequence: 2, averageTime: 1.2, minTime: 0.8, maxTime: 2.5,
        variance: 0.5, throughput: 45, queueTime: 0.3, processingTime: 0.9, bottleneckScore: 4, efficiency: 88
      },
      {
        id: '3', name: 'Legal Review', sequence: 3, averageTime: 8.2, minTime: 2.0, maxTime: 16.5,
        variance: 4.1, throughput: 25, queueTime: 6.8, processingTime: 1.4, bottleneckScore: 9, efficiency: 45
      },
      {
        id: '4', name: 'Stakeholder Review', sequence: 4, averageTime: 3.1, minTime: 1.5, maxTime: 7.2,
        variance: 1.8, throughput: 35, queueTime: 2.2, processingTime: 0.9, bottleneckScore: 7, efficiency: 68
      },
      {
        id: '5', name: 'Final Approval', sequence: 5, averageTime: 0.8, minTime: 0.3, maxTime: 2.1,
        variance: 0.4, throughput: 42, queueTime: 0.2, processingTime: 0.6, bottleneckScore: 3, efficiency: 92
      },
      {
        id: '6', name: 'Publishing', sequence: 6, averageTime: 0.3, minTime: 0.1, maxTime: 0.8,
        variance: 0.2, throughput: 50, queueTime: 0.05, processingTime: 0.25, bottleneckScore: 1, efficiency: 98
      }
    ]
  },
  {
    workflowId: '2',
    workflowName: 'Campaign Launch',
    totalSteps: 8,
    criticalPath: ['Planning', 'Asset Creation', 'Review', 'Approval', 'Launch'],
    bottleneckSteps: ['Asset Creation', 'Budget Approval'],
    averageProcessingTime: 12.5,
    maxCapacity: 20,
    currentUtilization: 76,
    steps: [
      {
        id: '1', name: 'Campaign Planning', sequence: 1, averageTime: 2.0, minTime: 1.5, maxTime: 3.5,
        variance: 0.8, throughput: 18, queueTime: 0.3, processingTime: 1.7, bottleneckScore: 3, efficiency: 89
      },
      {
        id: '2', name: 'Asset Creation', sequence: 2, averageTime: 12.5, minTime: 8.0, maxTime: 20.0,
        variance: 3.8, throughput: 12, queueTime: 8.2, processingTime: 4.3, bottleneckScore: 9, efficiency: 52
      },
      {
        id: '3', name: 'Copy Writing', sequence: 3, averageTime: 2.8, minTime: 1.8, maxTime: 4.5,
        variance: 0.9, throughput: 16, queueTime: 0.8, processingTime: 2.0, bottleneckScore: 4, efficiency: 82
      },
      {
        id: '4', name: 'Budget Approval', sequence: 4, averageTime: 6.7, minTime: 2.5, maxTime: 12.0,
        variance: 2.8, throughput: 14, queueTime: 4.2, processingTime: 2.5, bottleneckScore: 8, efficiency: 58
      },
      {
        id: '5', name: 'Campaign Review', sequence: 5, averageTime: 1.5, minTime: 0.8, maxTime: 3.2,
        variance: 0.7, throughput: 17, queueTime: 0.4, processingTime: 1.1, bottleneckScore: 3, efficiency: 86
      },
      {
        id: '6', name: 'Final Approval', sequence: 6, averageTime: 1.2, minTime: 0.5, maxTime: 2.8,
        variance: 0.6, throughput: 18, queueTime: 0.3, processingTime: 0.9, bottleneckScore: 2, efficiency: 91
      },
      {
        id: '7', name: 'Launch Preparation', sequence: 7, averageTime: 0.8, minTime: 0.4, maxTime: 1.5,
        variance: 0.3, throughput: 19, queueTime: 0.2, processingTime: 0.6, bottleneckScore: 2, efficiency: 93
      },
      {
        id: '8', name: 'Go Live', sequence: 8, averageTime: 0.2, minTime: 0.1, maxTime: 0.5,
        variance: 0.1, throughput: 20, queueTime: 0.05, processingTime: 0.15, bottleneckScore: 1, efficiency: 98
      }
    ]
  }
]

const bottleneckTrendData = [
  { month: 'Jan', critical: 3, high: 8, medium: 12, low: 5, resolved: 15 },
  { month: 'Feb', critical: 4, high: 10, medium: 11, low: 7, resolved: 18 },
  { month: 'Mar', critical: 2, high: 9, medium: 13, low: 8, resolved: 22 },
  { month: 'Apr', critical: 3, high: 11, medium: 10, low: 6, resolved: 25 },
  { month: 'May', critical: 1, high: 7, medium: 14, low: 9, resolved: 28 },
  { month: 'Jun', critical: 1, high: 6, medium: 9, low: 7, resolved: 32 }
]

const impactDistributionData = [
  { name: 'Critical', value: 35, color: '#ef4444', count: 1 },
  { name: 'High', value: 45, color: '#f97316', count: 2 },
  { name: 'Medium', value: 15, color: '#eab308', count: 2 },
  { name: 'Low', value: 5, color: '#22c55e', count: 1 }
]

const resolutionTimeData = mockBottlenecks.map(bottleneck => ({
  name: bottleneck.name.split(' ')[0],
  estimated: bottleneck.estimatedResolution,
  impact: bottleneck.totalImpact,
  cost: bottleneck.costOfInaction / 1000
}))

export const BottleneckAnalysis: React.FC = () => {
  const [selectedWorkflow, setSelectedWorkflow] = useState<string>('1')
  const [severityFilter, setSeverityFilter] = useState<string>('all')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [viewType, setViewType] = useState<'overview' | 'workflows' | 'detailed' | 'solutions'>('overview')

  const getFilteredBottlenecks = () => {
    return mockBottlenecks.filter(bottleneck => {
      const severityMatch = severityFilter === 'all' || bottleneck.severity === severityFilter
      const statusMatch = statusFilter === 'all' || bottleneck.status === statusFilter
      return severityMatch && statusMatch
    })
  }

  const getSeverityBadge = (severity: string) => {
    switch (severity) {
      case 'critical':
        return { variant: 'destructive' as const, label: 'Critical', color: 'text-red-600', bg: 'bg-red-100' }
      case 'high':
        return { variant: 'destructive' as const, label: 'High', color: 'text-orange-600', bg: 'bg-orange-100' }
      case 'medium':
        return { variant: 'outline' as const, label: 'Medium', color: 'text-yellow-600', bg: 'bg-yellow-100' }
      case 'low':
        return { variant: 'secondary' as const, label: 'Low', color: 'text-green-600', bg: 'bg-green-100' }
      default:
        return { variant: 'outline' as const, label: 'Unknown', color: 'text-gray-600', bg: 'bg-gray-100' }
    }
  }

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'resolved':
        return { variant: 'default' as const, label: 'Resolved', icon: <CheckCircle className="h-3 w-3" /> }
      case 'in-progress':
        return { variant: 'secondary' as const, label: 'In Progress', icon: <PauseCircle className="h-3 w-3" /> }
      case 'analyzing':
        return { variant: 'outline' as const, label: 'Analyzing', icon: <Activity className="h-3 w-3" /> }
      case 'identified':
        return { variant: 'outline' as const, label: 'Identified', icon: <AlertTriangle className="h-3 w-3" /> }
      default:
        return { variant: 'outline' as const, label: 'Unknown', icon: <AlertCircle className="h-3 w-3" /> }
    }
  }

  const getBottleneckIcon = (type: string) => {
    switch (type) {
      case 'process':
        return <Settings className="h-4 w-4" />
      case 'resource':
        return <Users className="h-4 w-4" />
      case 'approval':
        return <CheckCircle className="h-4 w-4" />
      case 'dependency':
        return <ArrowRight className="h-4 w-4" />
      case 'system':
        return <Activity className="h-4 w-4" />
      default:
        return <AlertTriangle className="h-4 w-4" />
    }
  }

  const getBottleneckScore = (step: WorkflowStep) => {
    return step.bottleneckScore
  }

  const getBottleneckColor = (score: number) => {
    if (score >= 8) return 'text-red-600'
    if (score >= 6) return 'text-orange-600'
    if (score >= 4) return 'text-yellow-600'
    return 'text-green-600'
  }

  const calculateTotalImpact = () => {
    return getFilteredBottlenecks().reduce((sum, bottleneck) => sum + bottleneck.totalImpact, 0)
  }

  const calculateTotalCost = () => {
    return getFilteredBottlenecks().reduce((sum, bottleneck) => sum + bottleneck.costOfInaction, 0)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight flex items-center gap-2">
            <AlertTriangle className="h-8 w-8" />
            Bottleneck Analysis
          </h1>
          <p className="text-muted-foreground">
            Identify workflow bottlenecks, analyze impact, and implement solutions
          </p>
        </div>
        
        <div className="flex items-center gap-2">
          <Select value={severityFilter} onValueChange={setSeverityFilter}>
            <SelectTrigger className="w-[120px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Severity</SelectItem>
              <SelectItem value="critical">Critical</SelectItem>
              <SelectItem value="high">High</SelectItem>
              <SelectItem value="medium">Medium</SelectItem>
              <SelectItem value="low">Low</SelectItem>
            </SelectContent>
          </Select>
          
          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-[120px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Status</SelectItem>
              <SelectItem value="identified">Identified</SelectItem>
              <SelectItem value="analyzing">Analyzing</SelectItem>
              <SelectItem value="in-progress">In Progress</SelectItem>
              <SelectItem value="resolved">Resolved</SelectItem>
            </SelectContent>
          </Select>
          
          <Button variant="outline" size="sm">
            <Filter className="h-4 w-4 mr-2" />
            Filter
          </Button>
          
          <Button variant="outline" size="sm">
            <Download className="h-4 w-4 mr-2" />
            Export
          </Button>
          
          <Button variant="outline" size="sm">
            <RefreshCw className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Bottlenecks</CardTitle>
            <AlertTriangle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{getFilteredBottlenecks().length}</div>
            <p className="text-xs text-muted-foreground">
              {mockBottlenecks.filter(b => b.severity === 'critical').length} critical
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Impact</CardTitle>
            <Timer className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{calculateTotalImpact()}h</div>
            <p className="text-xs text-red-600">
              +15% from last month
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Resolution Cost</CardTitle>
            <Target className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">${(calculateTotalCost() / 1000).toFixed(0)}k</div>
            <p className="text-xs text-muted-foreground">
              Cost of inaction
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Resolution Rate</CardTitle>
            <CheckCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">73%</div>
            <p className="text-xs text-green-600">
              +12% from last month
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Main Content Tabs */}
      <Tabs value={viewType} onValueChange={(value: any) => setViewType(value)}>
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="overview">
            <BarChart3 className="h-4 w-4 mr-2" />
            Overview
          </TabsTrigger>
          <TabsTrigger value="workflows">
            <Activity className="h-4 w-4 mr-2" />
            Workflows
          </TabsTrigger>
          <TabsTrigger value="detailed">
            <AlertTriangle className="h-4 w-4 mr-2" />
            Detailed
          </TabsTrigger>
          <TabsTrigger value="solutions">
            <Lightbulb className="h-4 w-4 mr-2" />
            Solutions
          </TabsTrigger>
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Bottleneck Trends */}
            <Card>
              <CardHeader>
                <CardTitle>Bottleneck Trends</CardTitle>
                <CardDescription>Bottleneck identification and resolution over time</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={bottleneckTrendData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="month" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Area type="monotone" dataKey="critical" stackId="1" stroke="#ef4444" fill="#ef4444" fillOpacity={0.3} name="Critical" />
                    <Area type="monotone" dataKey="high" stackId="1" stroke="#f97316" fill="#f97316" fillOpacity={0.3} name="High" />
                    <Area type="monotone" dataKey="medium" stackId="1" stroke="#eab308" fill="#eab308" fillOpacity={0.3} name="Medium" />
                    <Area type="monotone" dataKey="low" stackId="1" stroke="#22c55e" fill="#22c55e" fillOpacity={0.3} name="Low" />
                    <Line type="monotone" dataKey="resolved" stroke="#3b82f6" strokeWidth={3} name="Resolved" />
                  </AreaChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Impact Distribution */}
            <Card>
              <CardHeader>
                <CardTitle>Impact Distribution</CardTitle>
                <CardDescription>Bottleneck severity breakdown</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={impactDistributionData}
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      dataKey="value"
                      label={({ name, value }) => `${name}: ${value}%`}
                    >
                      {impactDistributionData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Resolution Time vs Impact */}
          <Card>
            <CardHeader>
              <CardTitle>Resolution Analysis</CardTitle>
              <CardDescription>Estimated resolution time vs business impact</CardDescription>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={resolutionTimeData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" />
                  <YAxis />
                  <Tooltip />
                  <Legend />
                  <Bar dataKey="estimated" fill="#3b82f6" name="Estimated Resolution (weeks)" />
                  <Bar dataKey="cost" fill="#ef4444" name="Cost of Inaction ($k)" />
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Workflows Tab */}
        <TabsContent value="workflows" className="space-y-6">
          <div className="flex items-center gap-4 mb-6">
            <Select value={selectedWorkflow} onValueChange={setSelectedWorkflow}>
              <SelectTrigger className="w-[200px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {mockWorkflowAnalysis.map(workflow => (
                  <SelectItem key={workflow.workflowId} value={workflow.workflowId}>
                    {workflow.workflowName}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {mockWorkflowAnalysis
            .filter(workflow => workflow.workflowId === selectedWorkflow)
            .map(workflow => (
              <div key={workflow.workflowId} className="space-y-6">
                {/* Workflow Summary */}
                <Card>
                  <CardHeader>
                    <div className="flex items-center justify-between">
                      <div>
                        <CardTitle>{workflow.workflowName} Analysis</CardTitle>
                        <CardDescription>{workflow.totalSteps} steps • {workflow.averageProcessingTime}h average processing time</CardDescription>
                      </div>
                      <div className="text-right">
                        <div className="text-2xl font-bold">{workflow.currentUtilization}%</div>
                        <div className="text-sm text-muted-foreground">Utilization</div>
                      </div>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                      <div>
                        <div className="text-sm text-muted-foreground">Max Capacity</div>
                        <div className="font-bold text-lg">{workflow.maxCapacity}/week</div>
                      </div>
                      <div>
                        <div className="text-sm text-muted-foreground">Bottleneck Steps</div>
                        <div className="font-bold text-lg text-red-600">{workflow.bottleneckSteps.length}</div>
                      </div>
                      <div>
                        <div className="text-sm text-muted-foreground">Critical Path</div>
                        <div className="font-bold text-lg">{workflow.criticalPath.length} steps</div>
                      </div>
                      <div>
                        <div className="text-sm text-muted-foreground">Efficiency</div>
                        <div className={`font-bold text-lg ${workflow.currentUtilization > 80 ? 'text-red-600' : workflow.currentUtilization > 60 ? 'text-yellow-600' : 'text-green-600'}`}>
                          {Math.round(100 - workflow.currentUtilization + 20)}%
                        </div>
                      </div>
                    </div>
                    
                    <div className="mt-4">
                      <Progress value={workflow.currentUtilization} className="h-3" />
                      <div className="flex justify-between text-xs text-muted-foreground mt-1">
                        <span>0% Utilization</span>
                        <span>100% Capacity</span>
                      </div>
                    </div>
                  </CardContent>
                </Card>

                {/* Workflow Steps Analysis */}
                <Card>
                  <CardHeader>
                    <CardTitle>Step-by-Step Analysis</CardTitle>
                    <CardDescription>Detailed analysis of each workflow step</CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-4">
                      {workflow.steps.map((step, index) => {
                        const bottleneckScore = getBottleneckScore(step)
                        const isBottleneck = workflow.bottleneckSteps.includes(step.name)
                        const isCriticalPath = workflow.criticalPath.includes(step.name)
                        
                        return (
                          <div key={step.id} className={`flex items-center gap-4 p-4 border rounded-lg ${isBottleneck ? 'border-red-200 bg-red-50' : 'border-gray-200'}`}>
                            <div className="flex items-center gap-3">
                              <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-sm font-bold">
                                {step.sequence}
                              </div>
                              {index < workflow.steps.length - 1 && (
                                <ArrowRight className="h-4 w-4 text-muted-foreground" />
                              )}
                            </div>
                            
                            <div className="flex-1 min-w-0">
                              <div className="flex items-center gap-2 mb-2">
                                <h4 className="font-medium">{step.name}</h4>
                                {isBottleneck && (
                                  <Badge variant="destructive" className="text-xs">
                                    <AlertTriangle className="h-3 w-3 mr-1" />
                                    Bottleneck
                                  </Badge>
                                )}
                                {isCriticalPath && (
                                  <Badge variant="outline" className="text-xs text-blue-600">
                                    <Target className="h-3 w-3 mr-1" />
                                    Critical Path
                                  </Badge>
                                )}
                              </div>
                              
                              <div className="grid grid-cols-2 md:grid-cols-6 gap-4 text-sm">
                                <div>
                                  <div className="text-muted-foreground">Avg Time</div>
                                  <div className="font-medium">{step.averageTime}h</div>
                                </div>
                                <div>
                                  <div className="text-muted-foreground">Queue Time</div>
                                  <div className={`font-medium ${step.queueTime > 2 ? 'text-red-600' : step.queueTime > 1 ? 'text-yellow-600' : 'text-green-600'}`}>
                                    {step.queueTime}h
                                  </div>
                                </div>
                                <div>
                                  <div className="text-muted-foreground">Throughput</div>
                                  <div className="font-medium">{step.throughput}/week</div>
                                </div>
                                <div>
                                  <div className="text-muted-foreground">Efficiency</div>
                                  <div className={`font-medium ${step.efficiency >= 85 ? 'text-green-600' : step.efficiency >= 70 ? 'text-yellow-600' : 'text-red-600'}`}>
                                    {step.efficiency}%
                                  </div>
                                </div>
                                <div>
                                  <div className="text-muted-foreground">Variance</div>
                                  <div className={`font-medium ${step.variance > 2 ? 'text-red-600' : step.variance > 1 ? 'text-yellow-600' : 'text-green-600'}`}>
                                    ±{step.variance}h
                                  </div>
                                </div>
                                <div>
                                  <div className="text-muted-foreground">Bottleneck Score</div>
                                  <div className={`font-bold ${getBottleneckColor(bottleneckScore)}`}>
                                    {bottleneckScore}/10
                                  </div>
                                </div>
                              </div>
                              
                              <div className="mt-3">
                                <Progress value={step.efficiency} className="h-2" />
                              </div>
                            </div>
                            
                            <div className="text-right">
                              <Button variant={isBottleneck ? 'destructive' : 'outline'} size="sm">
                                {isBottleneck ? 'Optimize' : 'Details'}
                              </Button>
                            </div>
                          </div>
                        )
                      })}
                    </div>
                  </CardContent>
                </Card>
              </div>
            ))}
        </TabsContent>

        {/* Detailed Tab */}
        <TabsContent value="detailed" className="space-y-6">
          <div className="grid grid-cols-1 gap-6">
            {getFilteredBottlenecks().map(bottleneck => {
              const severityBadge = getSeverityBadge(bottleneck.severity)
              const statusBadge = getStatusBadge(bottleneck.status)
              
              return (
                <Card key={bottleneck.id}>
                  <CardHeader>
                    <div className="flex items-start justify-between">
                      <div className="flex items-start gap-3">
                        <div className="w-12 h-12 rounded-lg bg-muted/50 flex items-center justify-center">
                          {getBottleneckIcon(bottleneck.type)}
                        </div>
                        <div>
                          <CardTitle className="text-lg">{bottleneck.name}</CardTitle>
                          <CardDescription className="capitalize">{bottleneck.type} bottleneck</CardDescription>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <Badge variant={severityBadge.variant} className={`${severityBadge.bg} ${severityBadge.color}`}>
                          {severityBadge.label}
                        </Badge>
                        <Badge variant={statusBadge.variant}>
                          {statusBadge.icon}
                          {statusBadge.label}
                        </Badge>
                      </div>
                    </div>
                  </CardHeader>
                  <CardContent className="space-y-6">
                    {/* Impact Metrics */}
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                      <div className="text-center p-3 bg-red-50 rounded-lg">
                        <div className="text-2xl font-bold text-red-600">{bottleneck.frequency}</div>
                        <div className="text-sm text-red-700">Occurrences/month</div>
                      </div>
                      <div className="text-center p-3 bg-orange-50 rounded-lg">
                        <div className="text-2xl font-bold text-orange-600">{bottleneck.averageDelay}h</div>
                        <div className="text-sm text-orange-700">Average Delay</div>
                      </div>
                      <div className="text-center p-3 bg-yellow-50 rounded-lg">
                        <div className="text-2xl font-bold text-yellow-600">{bottleneck.totalImpact}h</div>
                        <div className="text-sm text-yellow-700">Total Impact</div>
                      </div>
                      <div className="text-center p-3 bg-purple-50 rounded-lg">
                        <div className="text-2xl font-bold text-purple-600">${(bottleneck.costOfInaction / 1000).toFixed(0)}k</div>
                        <div className="text-sm text-purple-700">Cost of Inaction</div>
                      </div>
                    </div>

                    <Separator />

                    {/* Root Cause Analysis */}
                    <div>
                      <h4 className="font-medium mb-3 flex items-center gap-2">
                        <AlertTriangle className="h-4 w-4" />
                        Root Cause Analysis
                      </h4>
                      <div className="bg-muted/50 p-4 rounded-lg">
                        <p className="text-sm">{bottleneck.rootCause}</p>
                      </div>
                    </div>

                    {/* Affected Workflows */}
                    <div>
                      <h4 className="font-medium mb-3">Affected Workflows</h4>
                      <div className="flex flex-wrap gap-2">
                        {bottleneck.affectedWorkflows.map(workflow => (
                          <Badge key={workflow} variant="outline" className="text-xs">
                            <Activity className="h-3 w-3 mr-1" />
                            {workflow}
                          </Badge>
                        ))}
                      </div>
                    </div>

                    {/* Suggested Solution */}
                    <div>
                      <h4 className="font-medium mb-3 flex items-center gap-2">
                        <Lightbulb className="h-4 w-4 text-blue-600" />
                        Suggested Solution
                      </h4>
                      <div className="bg-blue-50 p-4 rounded-lg">
                        <p className="text-sm text-blue-900">{bottleneck.suggestedSolution}</p>
                        <div className="flex items-center gap-4 mt-3 text-xs text-blue-700">
                          <div className="flex items-center gap-1">
                            <Clock className="h-3 w-3" />
                            Est. {bottleneck.estimatedResolution} weeks
                          </div>
                          <div className="flex items-center gap-1">
                            <Users className="h-3 w-3" />
                            {bottleneck.assignee}
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* Action Buttons */}
                    <div className="flex items-center gap-2">
                      <Button 
                        variant={bottleneck.severity === 'critical' ? 'destructive' : 'default'} 
                        size="sm"
                      >
                        {bottleneck.status === 'identified' ? 'Start Analysis' :
                         bottleneck.status === 'analyzing' ? 'Begin Resolution' :
                         bottleneck.status === 'in-progress' ? 'Update Progress' :
                         'View Details'}
                      </Button>
                      <Button variant="outline" size="sm">
                        Assign Team
                      </Button>
                      <Button variant="outline" size="sm">
                        Track Progress
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              )
            })}
          </div>
        </TabsContent>

        {/* Solutions Tab */}
        <TabsContent value="solutions" className="space-y-6">
          {/* Solution Recommendations */}
          <Card>
            <CardHeader>
              <CardTitle>Solution Recommendations</CardTitle>
              <CardDescription>AI-powered optimization strategies based on bottleneck analysis</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-start gap-3 p-4 bg-green-50 rounded-lg">
                  <FastForward className="h-5 w-5 text-green-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-green-900">Quick Win: Parallel Processing</h4>
                    <p className="text-sm text-green-700">
                      Implement parallel review processes for Legal and Stakeholder reviews. This can reduce 
                      the Content Approval workflow time by 40% with minimal implementation cost.
                    </p>
                    <div className="text-xs text-green-600 mt-2">
                      Estimated impact: -6.5h average processing time • ROI: 300%
                    </div>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                  <Zap className="h-5 w-5 text-blue-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-blue-900">Automation Opportunity</h4>
                    <p className="text-sm text-blue-700">
                      Create template-based asset creation workflows with predefined approval paths. 
                      This addresses the Design Asset Creation bottleneck by reducing custom work by 60%.
                    </p>
                    <div className="text-xs text-blue-600 mt-2">
                      Estimated impact: -8.2h average processing time • Implementation: 3 weeks
                    </div>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-purple-50 rounded-lg">
                  <Target className="h-5 w-5 text-purple-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-purple-900">Resource Optimization</h4>
                    <p className="text-sm text-purple-700">
                      Implement threshold-based auto-approvals for budget requests under $5K. This would 
                      resolve 70% of budget approval delays automatically.
                    </p>
                    <div className="text-xs text-purple-600 mt-2">
                      Estimated impact: -4.7h average processing time • Risk: Low
                    </div>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-yellow-50 rounded-lg">
                  <Settings className="h-5 w-5 text-yellow-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-yellow-900">Process Improvement</h4>
                    <p className="text-sm text-yellow-700">
                      Establish clear SLAs and escalation procedures for stakeholder feedback. Create 
                      structured feedback templates to reduce revision cycles.
                    </p>
                    <div className="text-xs text-yellow-600 mt-2">
                      Estimated impact: -2.1h average processing time • Complexity: Medium
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Implementation Roadmap */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <Card>
              <CardHeader>
                <CardTitle>Implementation Roadmap</CardTitle>
                <CardDescription>Prioritized approach to bottleneck resolution</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-green-500 text-white flex items-center justify-center text-sm font-bold">
                    1
                  </div>
                  <div>
                    <h4 className="font-medium">Week 1-2: Quick Wins</h4>
                    <p className="text-sm text-muted-foreground">
                      Implement parallel processing and auto-approvals
                    </p>
                  </div>
                </div>
                
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-blue-500 text-white flex items-center justify-center text-sm font-bold">
                    2
                  </div>
                  <div>
                    <h4 className="font-medium">Week 3-5: Process Improvements</h4>
                    <p className="text-sm text-muted-foreground">
                      SLA establishment and feedback template creation
                    </p>
                  </div>
                </div>
                
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-purple-500 text-white flex items-center justify-center text-sm font-bold">
                    3
                  </div>
                  <div>
                    <h4 className="font-medium">Week 6-8: Automation</h4>
                    <p className="text-sm text-muted-foreground">
                      Template-based workflows and system integrations
                    </p>
                  </div>
                </div>
                
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-orange-500 text-white flex items-center justify-center text-sm font-bold">
                    4
                  </div>
                  <div>
                    <h4 className="font-medium">Week 9-12: Optimization</h4>
                    <p className="text-sm text-muted-foreground">
                      Monitor results and fine-tune processes
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Expected Outcomes</CardTitle>
                <CardDescription>Projected improvements after implementation</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Processing Time Reduction</span>
                    <span className="font-medium">-45%</span>
                  </div>
                  <Progress value={45} className="h-2" />
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Bottleneck Resolution</span>
                    <span className="font-medium">85%</span>
                  </div>
                  <Progress value={85} className="h-2" />
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Cost Savings</span>
                    <span className="font-medium">$32k/year</span>
                  </div>
                  <Progress value={78} className="h-2" />
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Team Satisfaction</span>
                    <span className="font-medium">+25%</span>
                  </div>
                  <Progress value={92} className="h-2" />
                </div>
                
                <Separator />
                
                <div className="bg-muted/50 p-3 rounded-lg">
                  <div className="text-sm font-medium mb-1">Overall Improvement</div>
                  <div className="text-2xl font-bold text-green-600">68%</div>
                  <div className="text-xs text-muted-foreground">
                    Expected workflow efficiency improvement
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  )
}

export default BottleneckAnalysis