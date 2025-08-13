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
  Activity,
  AlertTriangle,
  ArrowUpRight,
  ArrowDownRight,
  BarChart3,
  CheckCircle,
  Clock,
  Download,
  Filter,
  Gauge,
  LineChart,
  RefreshCw,
  Settings,
  Target,
  TrendingDown,
  TrendingUp,
  Users,
  Zap,
  XCircle,
  PlayCircle,
  PauseCircle,
  StopCircle,
  RotateCcw,
  FastForward,
  AlertCircle,
  ThumbsUp,
  ThumbsDown,
  Eye,
  FileText,
  Calendar
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
  LineChart as RechartsLineChart,
  Line,
  AreaChart,
  Area,
  PieChart,
  Pie,
  Cell,
  Funnel,
  FunnelChart
} from 'recharts'

interface WorkflowStep {
  id: string
  name: string
  averageTime: number
  completionRate: number
  bottleneckRisk: 'low' | 'medium' | 'high'
  assigneeType: string
  automationPossible: boolean
}

interface Workflow {
  id: string
  name: string
  category: 'approval' | 'review' | 'creation' | 'distribution'
  totalRequests: number
  completedRequests: number
  averageCompletionTime: number
  successRate: number
  currentBottleneck: string
  steps: WorkflowStep[]
  trends: {
    period: string
    requests: number
    avgTime: number
    successRate: number
  }[]
}

interface WorkflowMetric {
  id: string
  name: string
  value: number
  previousValue: number
  target: number
  unit: string
  trend: 'up' | 'down' | 'stable'
  impact: 'positive' | 'negative' | 'neutral'
}

const mockWorkflows: Workflow[] = [
  {
    id: '1',
    name: 'Content Approval',
    category: 'approval',
    totalRequests: 234,
    completedRequests: 198,
    averageCompletionTime: 4.2,
    successRate: 89,
    currentBottleneck: 'Legal Review',
    steps: [
      { id: '1', name: 'Content Creation', averageTime: 0.5, completionRate: 98, bottleneckRisk: 'low', assigneeType: 'Creator', automationPossible: false },
      { id: '2', name: 'Initial Review', averageTime: 1.2, completionRate: 95, bottleneckRisk: 'medium', assigneeType: 'Manager', automationPossible: true },
      { id: '3', name: 'Legal Review', averageTime: 2.8, completionRate: 82, bottleneckRisk: 'high', assigneeType: 'Legal', automationPossible: false },
      { id: '4', name: 'Final Approval', averageTime: 0.8, completionRate: 94, bottleneckRisk: 'low', assigneeType: 'Director', automationPossible: false }
    ],
    trends: [
      { period: 'Jan', requests: 187, avgTime: 5.2, successRate: 82 },
      { period: 'Feb', requests: 201, avgTime: 4.8, successRate: 85 },
      { period: 'Mar', requests: 224, avgTime: 4.5, successRate: 87 },
      { period: 'Apr', requests: 198, avgTime: 4.3, successRate: 88 },
      { period: 'May', requests: 213, avgTime: 4.1, successRate: 89 },
      { period: 'Jun', requests: 234, avgTime: 4.2, successRate: 89 }
    ]
  },
  {
    id: '2',
    name: 'Campaign Launch',
    category: 'creation',
    totalRequests: 89,
    completedRequests: 76,
    averageCompletionTime: 12.5,
    successRate: 94,
    currentBottleneck: 'Asset Creation',
    steps: [
      { id: '1', name: 'Strategy Planning', averageTime: 2.0, completionRate: 96, bottleneckRisk: 'low', assigneeType: 'Strategist', automationPossible: false },
      { id: '2', name: 'Asset Creation', averageTime: 6.5, completionRate: 78, bottleneckRisk: 'high', assigneeType: 'Designer', automationPossible: true },
      { id: '3', name: 'Copy Writing', averageTime: 2.8, completionRate: 92, bottleneckRisk: 'medium', assigneeType: 'Copywriter', automationPossible: false },
      { id: '4', name: 'Final Review', averageTime: 1.2, completionRate: 89, bottleneckRisk: 'medium', assigneeType: 'Manager', automationPossible: false }
    ],
    trends: [
      { period: 'Jan', requests: 67, avgTime: 14.2, successRate: 89 },
      { period: 'Feb', requests: 73, avgTime: 13.5, successRate: 91 },
      { period: 'Mar', requests: 81, avgTime: 13.1, successRate: 92 },
      { period: 'Apr', requests: 76, avgTime: 12.8, successRate: 93 },
      { period: 'May', requests: 84, avgTime: 12.6, successRate: 94 },
      { period: 'Jun', requests: 89, avgTime: 12.5, successRate: 94 }
    ]
  },
  {
    id: '3',
    name: 'Budget Approval',
    category: 'approval',
    totalRequests: 156,
    completedRequests: 134,
    averageCompletionTime: 8.7,
    successRate: 76,
    currentBottleneck: 'Finance Review',
    steps: [
      { id: '1', name: 'Request Submission', averageTime: 0.3, completionRate: 99, bottleneckRisk: 'low', assigneeType: 'Requester', automationPossible: true },
      { id: '2', name: 'Manager Approval', averageTime: 1.5, completionRate: 92, bottleneckRisk: 'low', assigneeType: 'Manager', automationPossible: false },
      { id: '3', name: 'Finance Review', averageTime: 5.8, completionRate: 68, bottleneckRisk: 'high', assigneeType: 'Finance', automationPossible: false },
      { id: '4', name: 'Executive Approval', averageTime: 1.1, completionRate: 85, bottleneckRisk: 'medium', assigneeType: 'Executive', automationPossible: false }
    ],
    trends: [
      { period: 'Jan', requests: 142, avgTime: 9.8, successRate: 71 },
      { period: 'Feb', requests: 138, avgTime: 9.5, successRate: 73 },
      { period: 'Mar', requests: 151, avgTime: 9.2, successRate: 74 },
      { period: 'Apr', requests: 147, avgTime: 8.9, successRate: 75 },
      { period: 'May', requests: 149, avgTime: 8.8, successRate: 76 },
      { period: 'Jun', requests: 156, avgTime: 8.7, successRate: 76 }
    ]
  },
  {
    id: '4',
    name: 'Asset Distribution',
    category: 'distribution',
    totalRequests: 412,
    completedRequests: 389,
    averageCompletionTime: 2.1,
    successRate: 97,
    currentBottleneck: 'Quality Check',
    steps: [
      { id: '1', name: 'Asset Preparation', averageTime: 0.5, completionRate: 98, bottleneckRisk: 'low', assigneeType: 'Coordinator', automationPossible: true },
      { id: '2', name: 'Quality Check', averageTime: 1.2, completionRate: 94, bottleneckRisk: 'medium', assigneeType: 'QA', automationPossible: true },
      { id: '3', name: 'Distribution', averageTime: 0.4, completionRate: 99, bottleneckRisk: 'low', assigneeType: 'System', automationPossible: true }
    ],
    trends: [
      { period: 'Jan', requests: 376, avgTime: 2.4, successRate: 95 },
      { period: 'Feb', requests: 389, avgTime: 2.3, successRate: 96 },
      { period: 'Mar', requests: 401, avgTime: 2.2, successRate: 96 },
      { period: 'Apr', requests: 387, avgTime: 2.2, successRate: 97 },
      { period: 'May', requests: 398, avgTime: 2.1, successRate: 97 },
      { period: 'Jun', requests: 412, avgTime: 2.1, successRate: 97 }
    ]
  }
]

const mockWorkflowMetrics: WorkflowMetric[] = [
  { id: '1', name: 'Average Completion Time', value: 6.8, previousValue: 7.4, target: 6.0, unit: 'hours', trend: 'up', impact: 'positive' },
  { id: '2', name: 'Success Rate', value: 89, previousValue: 85, target: 92, unit: '%', trend: 'up', impact: 'positive' },
  { id: '3', name: 'Active Workflows', value: 147, previousValue: 132, target: 150, unit: 'workflows', trend: 'up', impact: 'positive' },
  { id: '4', name: 'Bottleneck Resolution Time', value: 4.2, previousValue: 5.1, target: 3.5, unit: 'hours', trend: 'up', impact: 'positive' },
  { id: '5', name: 'Automation Coverage', value: 34, previousValue: 28, target: 50, unit: '%', trend: 'up', impact: 'positive' },
  { id: '6', name: 'Rejection Rate', value: 11, previousValue: 15, target: 8, unit: '%', trend: 'up', impact: 'positive' }
]

const workflowEfficiencyData = mockWorkflows.map(workflow => ({
  name: workflow.name.replace(' ', '\n'),
  efficiency: Math.round((workflow.completedRequests / workflow.totalRequests) * 100),
  avgTime: workflow.averageCompletionTime,
  successRate: workflow.successRate,
  requests: workflow.totalRequests
}))

const bottleneckAnalysisData = [
  { stage: 'Legal Review', frequency: 45, avgDelay: 2.8, impact: 'High' },
  { stage: 'Finance Review', frequency: 38, avgDelay: 5.8, impact: 'High' },
  { stage: 'Asset Creation', frequency: 32, avgDelay: 6.5, impact: 'High' },
  { stage: 'Quality Check', frequency: 28, avgDelay: 1.2, impact: 'Medium' },
  { stage: 'Executive Approval', frequency: 22, avgDelay: 1.1, impact: 'Medium' },
  { stage: 'Initial Review', frequency: 18, avgDelay: 1.2, impact: 'Low' }
]

const workflowCategoryData = [
  { name: 'Approval', value: 40, color: '#3b82f6' },
  { name: 'Review', value: 25, color: '#10b981' },
  { name: 'Creation', value: 20, color: '#f59e0b' },
  { name: 'Distribution', value: 15, color: '#8b5cf6' }
]

const automationOpportunityData = mockWorkflows.flatMap(workflow => 
  workflow.steps.filter(step => step.automationPossible).map(step => ({
    workflow: workflow.name,
    step: step.name,
    currentTime: step.averageTime,
    potentialSavings: step.averageTime * 0.7,
    complexity: step.bottleneckRisk === 'high' ? 'High' : step.bottleneckRisk === 'medium' ? 'Medium' : 'Low'
  }))
)

export const WorkflowPerformance: React.FC = () => {
  const [selectedWorkflow, setSelectedWorkflow] = useState<string>('1')
  const [timeRange, setTimeRange] = useState<'week' | 'month' | 'quarter' | 'year'>('month')
  const [viewType, setViewType] = useState<'overview' | 'workflows' | 'bottlenecks' | 'optimization'>('overview')

  const getTrendIcon = (trend: string, impact: string) => {
    if (trend === 'up' && impact === 'positive') {
      return <ArrowUpRight className="h-4 w-4 text-green-600" />
    }
    if (trend === 'up' && impact === 'negative') {
      return <ArrowUpRight className="h-4 w-4 text-red-600" />
    }
    if (trend === 'down' && impact === 'positive') {
      return <ArrowDownRight className="h-4 w-4 text-green-600" />
    }
    if (trend === 'down' && impact === 'negative') {
      return <ArrowDownRight className="h-4 w-4 text-red-600" />
    }
    return <TrendingUp className="h-4 w-4 text-gray-600" />
  }

  const getTrendColor = (trend: string, impact: string) => {
    if ((trend === 'up' && impact === 'positive') || (trend === 'down' && impact === 'negative')) {
      return 'text-green-600'
    }
    if ((trend === 'up' && impact === 'negative') || (trend === 'down' && impact === 'positive')) {
      return 'text-red-600'
    }
    return 'text-gray-600'
  }

  const getBottleneckRiskBadge = (risk: string) => {
    switch (risk) {
      case 'high':
        return { variant: 'destructive' as const, label: 'High Risk', icon: <AlertTriangle className="h-3 w-3" /> }
      case 'medium':
        return { variant: 'outline' as const, label: 'Medium Risk', icon: <AlertCircle className="h-3 w-3" /> }
      case 'low':
        return { variant: 'secondary' as const, label: 'Low Risk', icon: <CheckCircle className="h-3 w-3" /> }
      default:
        return { variant: 'secondary' as const, label: 'Unknown', icon: <AlertCircle className="h-3 w-3" /> }
    }
  }

  const getSuccessRateBadge = (rate: number) => {
    if (rate >= 95) return { variant: 'default' as const, label: 'Excellent', color: 'text-green-600' }
    if (rate >= 85) return { variant: 'secondary' as const, label: 'Good', color: 'text-blue-600' }
    if (rate >= 75) return { variant: 'outline' as const, label: 'Average', color: 'text-yellow-600' }
    return { variant: 'destructive' as const, label: 'Poor', color: 'text-red-600' }
  }

  const calculateChangePercent = (current: number, previous: number) => {
    return Math.round(((current - previous) / previous) * 100)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight flex items-center gap-2">
            <Activity className="h-8 w-8" />
            Workflow Performance
          </h1>
          <p className="text-muted-foreground">
            Analyze workflow efficiency, identify bottlenecks, and optimize processes
          </p>
        </div>
        
        <div className="flex items-center gap-2">
          <Select value={timeRange} onValueChange={(value: any) => setTimeRange(value)}>
            <SelectTrigger className="w-[120px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="week">This Week</SelectItem>
              <SelectItem value="month">This Month</SelectItem>
              <SelectItem value="quarter">This Quarter</SelectItem>
              <SelectItem value="year">This Year</SelectItem>
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
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {mockWorkflowMetrics.map(metric => {
          const changePercent = calculateChangePercent(metric.value, metric.previousValue)
          return (
            <Card key={metric.id}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">{metric.name}</CardTitle>
                {getTrendIcon(metric.trend, metric.impact)}
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {metric.value}
                  <span className="text-sm font-normal text-muted-foreground ml-1">
                    {metric.unit}
                  </span>
                </div>
                <div className="flex items-center justify-between mt-2">
                  <p className={`text-xs ${getTrendColor(metric.trend, metric.impact)}`}>
                    {changePercent > 0 ? '+' : ''}{changePercent}% from last {timeRange}
                  </p>
                  <div className="text-xs text-muted-foreground">
                    Target: {metric.target}{metric.unit}
                  </div>
                </div>
                <Progress 
                  value={(metric.value / metric.target) * 100} 
                  className="h-2 mt-2"
                />
              </CardContent>
            </Card>
          )
        })}
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
          <TabsTrigger value="bottlenecks">
            <AlertTriangle className="h-4 w-4 mr-2" />
            Bottlenecks
          </TabsTrigger>
          <TabsTrigger value="optimization">
            <Zap className="h-4 w-4 mr-2" />
            Optimization
          </TabsTrigger>
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Workflow Efficiency Overview */}
            <Card>
              <CardHeader>
                <CardTitle>Workflow Efficiency</CardTitle>
                <CardDescription>Completion rates and average processing times</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={workflowEfficiencyData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="efficiency" fill="#3b82f6" name="Efficiency %" />
                    <Bar dataKey="successRate" fill="#10b981" name="Success Rate %" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Workflow Category Distribution */}
            <Card>
              <CardHeader>
                <CardTitle>Workflow Categories</CardTitle>
                <CardDescription>Distribution of workflow types</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={workflowCategoryData}
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      dataKey="value"
                      label={({ name, value }) => `${name}: ${value}%`}
                    >
                      {workflowCategoryData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Processing Time Analysis */}
          <Card>
            <CardHeader>
              <CardTitle>Processing Time Analysis</CardTitle>
              <CardDescription>Average time to complete different workflows</CardDescription>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={workflowEfficiencyData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" />
                  <YAxis />
                  <Tooltip />
                  <Bar dataKey="avgTime" fill="#f59e0b" name="Average Time (hours)" />
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Workflows Tab */}
        <TabsContent value="workflows" className="space-y-6">
          <div className="flex items-center gap-4">
            <Select value={selectedWorkflow} onValueChange={setSelectedWorkflow}>
              <SelectTrigger className="w-[200px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {mockWorkflows.map(workflow => (
                  <SelectItem key={workflow.id} value={workflow.id}>
                    {workflow.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Individual Workflow Analysis */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {mockWorkflows.map(workflow => {
              const successBadge = getSuccessRateBadge(workflow.successRate)
              return (
                <Card key={workflow.id}>
                  <CardHeader>
                    <div className="flex items-center justify-between">
                      <div>
                        <CardTitle className="text-lg">{workflow.name}</CardTitle>
                        <CardDescription className="capitalize">{workflow.category} workflow</CardDescription>
                      </div>
                      <Badge variant={successBadge.variant} className={successBadge.color}>
                        {successBadge.label}
                      </Badge>
                    </div>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    {/* Key Metrics */}
                    <div className="grid grid-cols-2 gap-4 text-sm">
                      <div>
                        <div className="text-muted-foreground">Total Requests</div>
                        <div className="font-bold text-lg">{workflow.totalRequests}</div>
                      </div>
                      <div>
                        <div className="text-muted-foreground">Completed</div>
                        <div className="font-bold text-lg text-green-600">{workflow.completedRequests}</div>
                      </div>
                      <div>
                        <div className="text-muted-foreground">Avg Time</div>
                        <div className="font-bold text-lg">{workflow.averageCompletionTime}h</div>
                      </div>
                      <div>
                        <div className="text-muted-foreground">Success Rate</div>
                        <div className={`font-bold text-lg ${successBadge.color}`}>{workflow.successRate}%</div>
                      </div>
                    </div>

                    <Separator />

                    {/* Current Bottleneck */}
                    <div className="flex items-center gap-2 p-3 bg-red-50 rounded-lg">
                      <AlertTriangle className="h-4 w-4 text-red-600" />
                      <div>
                        <div className="text-sm font-medium text-red-900">Current Bottleneck</div>
                        <div className="text-sm text-red-700">{workflow.currentBottleneck}</div>
                      </div>
                    </div>

                    {/* Workflow Steps */}
                    <div>
                      <h4 className="text-sm font-medium mb-3">Workflow Steps</h4>
                      <div className="space-y-2">
                        {workflow.steps.map((step, index) => {
                          const riskBadge = getBottleneckRiskBadge(step.bottleneckRisk)
                          return (
                            <div key={step.id} className="flex items-center gap-3 p-2 border rounded">
                              <div className="w-6 h-6 rounded-full bg-primary/10 flex items-center justify-center text-xs font-bold">
                                {index + 1}
                              </div>
                              <div className="flex-1 min-w-0">
                                <div className="flex items-center gap-2">
                                  <span className="font-medium text-sm">{step.name}</span>
                                  <Badge variant={riskBadge.variant} className="text-xs">
                                    {riskBadge.icon}
                                    {riskBadge.label}
                                  </Badge>
                                  {step.automationPossible && (
                                    <Badge variant="outline" className="text-xs bg-purple-50 text-purple-700">
                                      <Zap className="h-3 w-3 mr-1" />
                                      Automatable
                                    </Badge>
                                  )}
                                </div>
                                <div className="text-xs text-muted-foreground">
                                  {step.averageTime}h avg • {step.completionRate}% completion • {step.assigneeType}
                                </div>
                              </div>
                            </div>
                          )
                        })}
                      </div>
                    </div>

                    {/* Trend Chart */}
                    <div>
                      <h4 className="text-sm font-medium mb-3">Performance Trend</h4>
                      <ResponsiveContainer width="100%" height={150}>
                        <RechartsLineChart data={workflow.trends}>
                          <XAxis dataKey="period" />
                          <YAxis />
                          <Tooltip />
                          <Line type="monotone" dataKey="successRate" stroke="#3b82f6" strokeWidth={2} />
                        </RechartsLineChart>
                      </ResponsiveContainer>
                    </div>
                  </CardContent>
                </Card>
              )
            })}
          </div>
        </TabsContent>

        {/* Bottlenecks Tab */}
        <TabsContent value="bottlenecks" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Bottleneck Frequency Analysis */}
            <Card>
              <CardHeader>
                <CardTitle>Bottleneck Frequency</CardTitle>
                <CardDescription>Most common workflow bottlenecks and their impact</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={bottleneckAnalysisData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="stage" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="frequency" fill="#ef4444" name="Frequency" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Average Delay Analysis */}
            <Card>
              <CardHeader>
                <CardTitle>Delay Impact</CardTitle>
                <CardDescription>Average delay caused by each bottleneck</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={bottleneckAnalysisData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="stage" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="avgDelay" fill="#f59e0b" name="Avg Delay (hours)" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Detailed Bottleneck Analysis */}
          <Card>
            <CardHeader>
              <CardTitle>Bottleneck Details</CardTitle>
              <CardDescription>In-depth analysis of workflow bottlenecks and resolution strategies</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {bottleneckAnalysisData.map(bottleneck => (
                  <div key={bottleneck.stage} className="flex items-center gap-4 p-4 border rounded-lg">
                    <div className={`w-3 h-3 rounded-full ${
                      bottleneck.impact === 'High' ? 'bg-red-500' :
                      bottleneck.impact === 'Medium' ? 'bg-yellow-500' :
                      'bg-green-500'
                    }`} />
                    
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-2">
                        <h4 className="font-medium">{bottleneck.stage}</h4>
                        <Badge 
                          variant={bottleneck.impact === 'High' ? 'destructive' : bottleneck.impact === 'Medium' ? 'outline' : 'secondary'}
                          className={bottleneck.impact === 'High' ? 'bg-red-100 text-red-700' : ''}
                        >
                          {bottleneck.impact} Impact
                        </Badge>
                      </div>
                      
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                        <div>
                          <div className="text-muted-foreground">Frequency</div>
                          <div className="font-medium">{bottleneck.frequency} times/month</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Avg Delay</div>
                          <div className={`font-medium ${bottleneck.avgDelay > 4 ? 'text-red-600' : bottleneck.avgDelay > 2 ? 'text-yellow-600' : 'text-green-600'}`}>
                            {bottleneck.avgDelay} hours
                          </div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Total Impact</div>
                          <div className="font-medium">{Math.round(bottleneck.frequency * bottleneck.avgDelay)} hrs/month</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Priority</div>
                          <div className={`font-medium ${
                            bottleneck.frequency * bottleneck.avgDelay > 200 ? 'text-red-600' :
                            bottleneck.frequency * bottleneck.avgDelay > 100 ? 'text-yellow-600' :
                            'text-green-600'
                          }`}>
                            {bottleneck.frequency * bottleneck.avgDelay > 200 ? 'Critical' :
                             bottleneck.frequency * bottleneck.avgDelay > 100 ? 'High' :
                             'Medium'}
                          </div>
                        </div>
                      </div>
                    </div>
                    
                    <div className="text-right">
                      <Button 
                        variant={bottleneck.impact === 'High' ? 'destructive' : 'outline'} 
                        size="sm"
                      >
                        {bottleneck.impact === 'High' ? 'Urgent Action' : 'Optimize'}
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Optimization Tab */}
        <TabsContent value="optimization" className="space-y-6">
          {/* Automation Opportunities */}
          <Card>
            <CardHeader>
              <CardTitle>Automation Opportunities</CardTitle>
              <CardDescription>Steps that can be automated to improve efficiency</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {automationOpportunityData.map((opportunity, index) => (
                  <div key={index} className="flex items-center gap-4 p-4 border rounded-lg bg-purple-50">
                    <Zap className="h-8 w-8 text-purple-600" />
                    
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-2">
                        <h4 className="font-medium">{opportunity.workflow} - {opportunity.step}</h4>
                        <Badge variant="outline" className="bg-purple-100 text-purple-700 border-purple-300">
                          {opportunity.complexity} Complexity
                        </Badge>
                      </div>
                      
                      <div className="grid grid-cols-2 md:grid-cols-3 gap-4 text-sm">
                        <div>
                          <div className="text-muted-foreground">Current Time</div>
                          <div className="font-medium">{opportunity.currentTime}h</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Potential Savings</div>
                          <div className="font-medium text-green-600">
                            -{opportunity.potentialSavings.toFixed(1)}h ({Math.round((opportunity.potentialSavings/opportunity.currentTime) * 100)}%)
                          </div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">ROI Estimate</div>
                          <div className="font-medium text-blue-600">High</div>
                        </div>
                      </div>
                    </div>
                    
                    <div className="text-right">
                      <Button variant="outline" size="sm" className="border-purple-300 text-purple-700">
                        <Settings className="h-4 w-4 mr-2" />
                        Configure
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          {/* Optimization Recommendations */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <Card>
              <CardHeader>
                <CardTitle>Quick Wins</CardTitle>
                <CardDescription>Immediate improvements with high impact</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-start gap-3 p-3 bg-green-50 rounded-lg">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-green-900">Automate Asset Preparation</h4>
                    <p className="text-sm text-green-700">
                      Implement template-based asset preparation to reduce time by 60%
                    </p>
                    <div className="text-xs text-green-600 mt-1">
                      Estimated savings: 12h/week
                    </div>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-3 bg-blue-50 rounded-lg">
                  <Target className="h-5 w-5 text-blue-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-blue-900">Streamline Legal Review</h4>
                    <p className="text-sm text-blue-700">
                      Create pre-approved content templates to bypass routine legal reviews
                    </p>
                    <div className="text-xs text-blue-600 mt-1">
                      Estimated savings: 15h/week
                    </div>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-3 bg-yellow-50 rounded-lg">
                  <FastForward className="h-5 w-5 text-yellow-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-yellow-900">Parallel Processing</h4>
                    <p className="text-sm text-yellow-700">
                      Enable parallel review stages for non-conflicting approvals
                    </p>
                    <div className="text-xs text-yellow-600 mt-1">
                      Estimated savings: 8h/week
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Optimization Metrics</CardTitle>
                <CardDescription>Track improvement progress</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Automation Coverage</span>
                    <span className="font-medium">34% → Target: 50%</span>
                  </div>
                  <Progress value={34} className="h-2" />
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Average Processing Time</span>
                    <span className="font-medium">6.8h → Target: 5.0h</span>
                  </div>
                  <Progress value={73} className="h-2" />
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Bottleneck Resolution</span>
                    <span className="font-medium">4.2h → Target: 2.5h</span>
                  </div>
                  <Progress value={60} className="h-2" />
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Success Rate</span>
                    <span className="font-medium">89% → Target: 95%</span>
                  </div>
                  <Progress value={94} className="h-2" />
                </div>
                
                <Separator />
                
                <div className="bg-muted/50 p-3 rounded-lg">
                  <div className="text-sm font-medium mb-1">Optimization Score</div>
                  <div className="text-2xl font-bold text-blue-600">78%</div>
                  <div className="text-xs text-muted-foreground">
                    +12% improvement potential identified
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

export default WorkflowPerformance