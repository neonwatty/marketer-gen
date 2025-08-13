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
  BarChart3,
  TrendingUp,
  TrendingDown,
  Users,
  MessageSquare,
  Clock,
  CheckCircle,
  AlertTriangle,
  Activity,
  PieChart,
  LineChart,
  Download,
  RefreshCw,
  Filter,
  Calendar,
  Target,
  Zap,
  ArrowUpRight,
  ArrowDownRight,
  Settings,
  Share2,
  FileText,
  Globe,
  Coffee,
  Lightbulb
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
  PieChart as RechartsPieChart,
  Pie,
  Cell,
  AreaChart,
  Area,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar
} from 'recharts'

interface CollaborationMetric {
  id: string
  name: string
  value: number
  previousValue: number
  target?: number
  unit: string
  trend: 'up' | 'down' | 'stable'
  category: 'communication' | 'workflow' | 'productivity' | 'quality'
}

interface TeamCollaborationData {
  member: string
  messagesExchanged: number
  documentsShared: number
  meetingsAttended: number
  tasksCollaborated: number
  responseTime: number
  collaborationScore: number
}

interface WorkflowAnalytics {
  workflowName: string
  totalRequests: number
  averageProcessingTime: number
  approvalRate: number
  bottleneckStage: string
  efficiency: number
}

const mockCollaborationMetrics: CollaborationMetric[] = [
  {
    id: '1',
    name: 'Team Messages',
    value: 1847,
    previousValue: 1623,
    target: 1800,
    unit: 'messages',
    trend: 'up',
    category: 'communication'
  },
  {
    id: '2',
    name: 'Documents Shared',
    value: 342,
    previousValue: 298,
    target: 350,
    unit: 'documents',
    trend: 'up',
    category: 'productivity'
  },
  {
    id: '3',
    name: 'Avg Response Time',
    value: 2.3,
    previousValue: 3.1,
    target: 2.0,
    unit: 'hours',
    trend: 'up',
    category: 'communication'
  },
  {
    id: '4',
    name: 'Collaborative Tasks',
    value: 89,
    previousValue: 76,
    target: 85,
    unit: 'tasks',
    trend: 'up',
    category: 'workflow'
  },
  {
    id: '5',
    name: 'Meeting Efficiency',
    value: 87,
    previousValue: 82,
    target: 90,
    unit: '%',
    trend: 'up',
    category: 'productivity'
  },
  {
    id: '6',
    name: 'Cross-team Projects',
    value: 23,
    previousValue: 19,
    target: 25,
    unit: 'projects',
    trend: 'up',
    category: 'workflow'
  }
]

const mockTeamCollaboration: TeamCollaborationData[] = [
  {
    member: 'John Doe',
    messagesExchanged: 324,
    documentsShared: 67,
    meetingsAttended: 28,
    tasksCollaborated: 19,
    responseTime: 1.8,
    collaborationScore: 92
  },
  {
    member: 'Sarah Wilson',
    messagesExchanged: 412,
    documentsShared: 89,
    meetingsAttended: 32,
    tasksCollaborated: 24,
    responseTime: 1.2,
    collaborationScore: 96
  },
  {
    member: 'Mike Johnson',
    messagesExchanged: 278,
    documentsShared: 45,
    meetingsAttended: 24,
    tasksCollaborated: 16,
    responseTime: 2.7,
    collaborationScore: 84
  },
  {
    member: 'Lisa Brown',
    messagesExchanged: 356,
    documentsShared: 72,
    meetingsAttended: 35,
    tasksCollaborated: 21,
    responseTime: 2.1,
    collaborationScore: 88
  },
  {
    member: 'David Lee',
    messagesExchanged: 389,
    documentsShared: 69,
    meetingsAttended: 29,
    tasksCollaborated: 18,
    responseTime: 1.9,
    collaborationScore: 90
  }
]

const mockWorkflowAnalytics: WorkflowAnalytics[] = [
  {
    workflowName: 'Content Approval',
    totalRequests: 156,
    averageProcessingTime: 4.2,
    approvalRate: 87,
    bottleneckStage: 'Review',
    efficiency: 82
  },
  {
    workflowName: 'Campaign Launch',
    totalRequests: 34,
    averageProcessingTime: 12.8,
    approvalRate: 94,
    bottleneckStage: 'Legal Review',
    efficiency: 76
  },
  {
    workflowName: 'Design Assets',
    totalRequests: 89,
    averageProcessingTime: 2.9,
    approvalRate: 91,
    bottleneckStage: 'Brand Check',
    efficiency: 88
  },
  {
    workflowName: 'Budget Approval',
    totalRequests: 67,
    averageProcessingTime: 8.5,
    approvalRate: 78,
    bottleneckStage: 'Finance Review',
    efficiency: 71
  }
]

const collaborationTrendData = [
  { month: 'Jan', messages: 1456, documents: 287, meetings: 145, tasks: 67 },
  { month: 'Feb', messages: 1523, documents: 312, meetings: 158, tasks: 72 },
  { month: 'Mar', messages: 1687, documents: 298, meetings: 142, tasks: 69 },
  { month: 'Apr', messages: 1789, documents: 334, meetings: 167, tasks: 78 },
  { month: 'May', messages: 1623, documents: 298, meetings: 153, tasks: 76 },
  { month: 'Jun', messages: 1847, documents: 342, meetings: 171, tasks: 89 }
]

const communicationChannelsData = [
  { name: 'Direct Messages', value: 45, color: '#8884d8' },
  { name: 'Team Channels', value: 35, color: '#82ca9d' },
  { name: 'Video Calls', value: 15, color: '#ffc658' },
  { name: 'Email', value: 5, color: '#ff7c7c' }
]

const workflowEfficiencyData = mockWorkflowAnalytics.map(workflow => ({
  name: workflow.workflowName.replace(' ', '\n'),
  efficiency: workflow.efficiency,
  approvalRate: workflow.approvalRate,
  avgTime: workflow.averageProcessingTime
}))

const collaborationHeatmapData = [
  { day: 'Mon', hour: '9AM', interactions: 45 },
  { day: 'Mon', hour: '11AM', interactions: 62 },
  { day: 'Mon', hour: '2PM', interactions: 58 },
  { day: 'Mon', hour: '4PM', interactions: 41 },
  { day: 'Tue', hour: '9AM', interactions: 52 },
  { day: 'Tue', hour: '11AM', interactions: 71 },
  { day: 'Tue', hour: '2PM', interactions: 65 },
  { day: 'Tue', hour: '4PM', interactions: 48 },
  { day: 'Wed', hour: '9AM', interactions: 48 },
  { day: 'Wed', hour: '11AM', interactions: 67 },
  { day: 'Wed', hour: '2PM', interactions: 72 },
  { day: 'Wed', hour: '4PM', interactions: 55 },
  { day: 'Thu', hour: '9AM', interactions: 55 },
  { day: 'Thu', hour: '11AM', interactions: 74 },
  { day: 'Thu', hour: '2PM', interactions: 68 },
  { day: 'Thu', hour: '4PM', interactions: 52 },
  { day: 'Fri', hour: '9AM', interactions: 41 },
  { day: 'Fri', hour: '11AM', interactions: 58 },
  { day: 'Fri', hour: '2PM', interactions: 45 },
  { day: 'Fri', hour: '4PM', interactions: 32 }
]

export const CollaborationAnalytics: React.FC = () => {
  const [timeRange, setTimeRange] = useState<'week' | 'month' | 'quarter' | 'year'>('month')
  const [selectedMetric, setSelectedMetric] = useState<string>('all')
  const [viewType, setViewType] = useState<'overview' | 'workflows' | 'team' | 'insights'>('overview')

  const getTrendIcon = (trend: string, value: number, target?: number) => {
    if (trend === 'up') {
      return target && value >= target ? 
        <ArrowUpRight className="h-4 w-4 text-green-600" /> : 
        <ArrowUpRight className="h-4 w-4 text-blue-600" />
    }
    if (trend === 'down') {
      return <ArrowDownRight className="h-4 w-4 text-red-600" />
    }
    return <TrendingUp className="h-4 w-4 text-gray-600" />
  }

  const getTrendColor = (trend: string, value: number, target?: number) => {
    if (trend === 'up') {
      return target && value >= target ? 'text-green-600' : 'text-blue-600'
    }
    if (trend === 'down') {
      return 'text-red-600'
    }
    return 'text-gray-600'
  }

  const getCollaborationScore = (score: number) => {
    if (score >= 90) return { color: 'text-green-600', badge: 'Excellent', variant: 'default' as const }
    if (score >= 80) return { color: 'text-blue-600', badge: 'Good', variant: 'secondary' as const }
    if (score >= 70) return { color: 'text-yellow-600', badge: 'Average', variant: 'outline' as const }
    return { color: 'text-red-600', badge: 'Needs Improvement', variant: 'destructive' as const }
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
            <Share2 className="h-8 w-8" />
            Collaboration Analytics
          </h1>
          <p className="text-muted-foreground">
            Track team collaboration patterns, workflow efficiency, and communication metrics
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

      {/* Key Metrics Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {mockCollaborationMetrics.map(metric => {
          const changePercent = calculateChangePercent(metric.value, metric.previousValue)
          return (
            <Card key={metric.id}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">{metric.name}</CardTitle>
                {getTrendIcon(metric.trend, metric.value, metric.target)}
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {metric.value}
                  <span className="text-sm font-normal text-muted-foreground ml-1">
                    {metric.unit}
                  </span>
                </div>
                <div className="flex items-center justify-between mt-2">
                  <p className={`text-xs ${getTrendColor(metric.trend, metric.value, metric.target)}`}>
                    {changePercent > 0 ? '+' : ''}{changePercent}% from last {timeRange}
                  </p>
                  {metric.target && (
                    <div className="text-xs text-muted-foreground">
                      Target: {metric.target}{metric.unit}
                    </div>
                  )}
                </div>
                {metric.target && (
                  <Progress 
                    value={(metric.value / metric.target) * 100} 
                    className="h-2 mt-2"
                  />
                )}
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
          <TabsTrigger value="team">
            <Users className="h-4 w-4 mr-2" />
            Team Analysis
          </TabsTrigger>
          <TabsTrigger value="insights">
            <Lightbulb className="h-4 w-4 mr-2" />
            Insights
          </TabsTrigger>
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Collaboration Trends */}
            <Card>
              <CardHeader>
                <CardTitle>Collaboration Trends</CardTitle>
                <CardDescription>Team collaboration metrics over time</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <RechartsLineChart data={collaborationTrendData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="month" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Line type="monotone" dataKey="messages" stroke="#8884d8" name="Messages" />
                    <Line type="monotone" dataKey="documents" stroke="#82ca9d" name="Documents" />
                    <Line type="monotone" dataKey="meetings" stroke="#ffc658" name="Meetings" />
                    <Line type="monotone" dataKey="tasks" stroke="#ff7c7c" name="Collaborative Tasks" />
                  </RechartsLineChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Communication Channels */}
            <Card>
              <CardHeader>
                <CardTitle>Communication Channels</CardTitle>
                <CardDescription>Distribution of communication methods</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <RechartsPieChart>
                    <Pie
                      data={communicationChannelsData}
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      dataKey="value"
                      label={({ name, value }) => `${name}: ${value}%`}
                    >
                      {communicationChannelsData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </RechartsPieChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Team Collaboration Heatmap */}
          <Card>
            <CardHeader>
              <CardTitle>Collaboration Activity Heatmap</CardTitle>
              <CardDescription>Peak collaboration times throughout the week</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-4 gap-1 text-xs">
                <div></div>
                <div className="text-center font-medium">9AM</div>
                <div className="text-center font-medium">11AM</div>
                <div className="text-center font-medium">2PM</div>
                <div className="text-center font-medium">4PM</div>
                {['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map(day => (
                  <React.Fragment key={day}>
                    <div className="font-medium py-2">{day}</div>
                    {['9AM', '11AM', '2PM', '4PM'].map(hour => {
                      const data = collaborationHeatmapData.find(d => d.day === day && d.hour === hour)
                      const intensity = data ? Math.round((data.interactions / 75) * 100) : 0
                      return (
                        <div 
                          key={`${day}-${hour}`}
                          className={`h-8 rounded flex items-center justify-center text-xs font-medium ${
                            intensity > 80 ? 'bg-blue-600 text-white' :
                            intensity > 60 ? 'bg-blue-400 text-white' :
                            intensity > 40 ? 'bg-blue-200 text-blue-800' :
                            intensity > 20 ? 'bg-blue-100 text-blue-600' :
                            'bg-gray-100 text-gray-600'
                          }`}
                          title={`${day} ${hour}: ${data?.interactions || 0} interactions`}
                        >
                          {data?.interactions || 0}
                        </div>
                      )
                    })}
                  </React.Fragment>
                ))}
              </div>
              <div className="flex items-center justify-center gap-2 mt-4 text-xs">
                <span>Low</span>
                <div className="flex gap-1">
                  <div className="w-3 h-3 bg-gray-100 rounded"></div>
                  <div className="w-3 h-3 bg-blue-100 rounded"></div>
                  <div className="w-3 h-3 bg-blue-200 rounded"></div>
                  <div className="w-3 h-3 bg-blue-400 rounded"></div>
                  <div className="w-3 h-3 bg-blue-600 rounded"></div>
                </div>
                <span>High</span>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Workflows Tab */}
        <TabsContent value="workflows" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Workflow Efficiency */}
            <Card>
              <CardHeader>
                <CardTitle>Workflow Efficiency</CardTitle>
                <CardDescription>Performance metrics for approval workflows</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={workflowEfficiencyData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="efficiency" fill="#8884d8" name="Efficiency %" />
                    <Bar dataKey="approvalRate" fill="#82ca9d" name="Approval Rate %" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Processing Time Analysis */}
            <Card>
              <CardHeader>
                <CardTitle>Processing Time Analysis</CardTitle>
                <CardDescription>Average time to complete workflow stages</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={workflowEfficiencyData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="avgTime" fill="#ffc658" name="Avg Time (hours)" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Workflow Details */}
          <Card>
            <CardHeader>
              <CardTitle>Workflow Performance Details</CardTitle>
              <CardDescription>Detailed analysis of each approval workflow</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {mockWorkflowAnalytics.map(workflow => (
                  <div key={workflow.workflowName} className="flex items-center gap-4 p-4 border rounded-lg">
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-2">
                        <h4 className="font-medium">{workflow.workflowName}</h4>
                        <Badge variant={workflow.efficiency >= 85 ? 'default' : workflow.efficiency >= 70 ? 'secondary' : 'destructive'}>
                          {workflow.efficiency}% Efficient
                        </Badge>
                        {workflow.bottleneckStage && (
                          <Badge variant="outline" className="text-yellow-600">
                            <AlertTriangle className="h-3 w-3 mr-1" />
                            Bottleneck: {workflow.bottleneckStage}
                          </Badge>
                        )}
                      </div>
                      
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                        <div>
                          <div className="text-muted-foreground">Total Requests</div>
                          <div className="font-medium">{workflow.totalRequests}</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Avg Processing</div>
                          <div className="font-medium">{workflow.averageProcessingTime}h</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Approval Rate</div>
                          <div className="font-medium">{workflow.approvalRate}%</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Efficiency</div>
                          <div className={`font-medium ${workflow.efficiency >= 85 ? 'text-green-600' : workflow.efficiency >= 70 ? 'text-yellow-600' : 'text-red-600'}`}>
                            {workflow.efficiency}%
                          </div>
                        </div>
                      </div>
                      
                      <div className="mt-3">
                        <Progress value={workflow.efficiency} className="h-2" />
                      </div>
                    </div>
                    
                    <div className="text-right">
                      <Button variant="outline" size="sm">
                        Optimize
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Team Analysis Tab */}
        <TabsContent value="team" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Team Collaboration Scores */}
            <Card>
              <CardHeader>
                <CardTitle>Team Collaboration Scores</CardTitle>
                <CardDescription>Individual collaboration performance metrics</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={mockTeamCollaboration}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="member" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="collaborationScore" fill="#8884d8" name="Collaboration Score" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Response Time Analysis */}
            <Card>
              <CardHeader>
                <CardTitle>Response Time Analysis</CardTitle>
                <CardDescription>Average response times across team members</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={mockTeamCollaboration}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="member" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="responseTime" fill="#ff7c7c" name="Response Time (hours)" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Detailed Team Analysis */}
          <Card>
            <CardHeader>
              <CardTitle>Individual Collaboration Analysis</CardTitle>
              <CardDescription>Detailed breakdown of each team member's collaboration metrics</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {mockTeamCollaboration.map(member => {
                  const scoreData = getCollaborationScore(member.collaborationScore)
                  return (
                    <div key={member.member} className="flex items-center gap-4 p-4 border rounded-lg">
                      <Avatar className="h-12 w-12">
                        <AvatarFallback>
                          {member.member.split(' ').map(n => n[0]).join('')}
                        </AvatarFallback>
                      </Avatar>
                      
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-2">
                          <h4 className="font-medium">{member.member}</h4>
                          <Badge variant={scoreData.variant}>
                            {scoreData.badge}
                          </Badge>
                          <div className={`text-sm font-medium ${scoreData.color}`}>
                            {member.collaborationScore} Score
                          </div>
                        </div>
                        
                        <div className="grid grid-cols-2 md:grid-cols-5 gap-4 text-sm">
                          <div>
                            <div className="text-muted-foreground">Messages</div>
                            <div className="font-medium flex items-center gap-1">
                              <MessageSquare className="h-3 w-3" />
                              {member.messagesExchanged}
                            </div>
                          </div>
                          <div>
                            <div className="text-muted-foreground">Documents</div>
                            <div className="font-medium flex items-center gap-1">
                              <FileText className="h-3 w-3" />
                              {member.documentsShared}
                            </div>
                          </div>
                          <div>
                            <div className="text-muted-foreground">Meetings</div>
                            <div className="font-medium flex items-center gap-1">
                              <Calendar className="h-3 w-3" />
                              {member.meetingsAttended}
                            </div>
                          </div>
                          <div>
                            <div className="text-muted-foreground">Collab Tasks</div>
                            <div className="font-medium flex items-center gap-1">
                              <Users className="h-3 w-3" />
                              {member.tasksCollaborated}
                            </div>
                          </div>
                          <div>
                            <div className="text-muted-foreground">Response Time</div>
                            <div className={`font-medium flex items-center gap-1 ${member.responseTime <= 2 ? 'text-green-600' : member.responseTime <= 4 ? 'text-yellow-600' : 'text-red-600'}`}>
                              <Clock className="h-3 w-3" />
                              {member.responseTime}h
                            </div>
                          </div>
                        </div>
                        
                        <div className="mt-3">
                          <Progress value={member.collaborationScore} className="h-2" />
                        </div>
                      </div>
                      
                      <div className="text-right">
                        <Button variant="outline" size="sm">
                          View Details
                        </Button>
                      </div>
                    </div>
                  )
                })}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Insights Tab */}
        <TabsContent value="insights" className="space-y-6">
          {/* AI Insights */}
          <Card>
            <CardHeader>
              <CardTitle>Collaboration Insights</CardTitle>
              <CardDescription>AI-powered recommendations for improving team collaboration</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-start gap-3 p-4 bg-green-50 rounded-lg">
                  <TrendingUp className="h-5 w-5 text-green-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-green-900">Strong Collaboration Growth</h4>
                    <p className="text-sm text-green-700">
                      Team collaboration metrics have improved by 15% this month. Message exchange and document 
                      sharing are at an all-time high, indicating strong team engagement.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                  <Lightbulb className="h-5 w-5 text-blue-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-blue-900">Optimization Opportunity</h4>
                    <p className="text-sm text-blue-700">
                      Sarah Wilson has exceptional collaboration scores. Consider having her mentor team members 
                      with lower scores to share best practices and improve overall team performance.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-yellow-50 rounded-lg">
                  <AlertTriangle className="h-5 w-5 text-yellow-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-yellow-900">Workflow Bottleneck Alert</h4>
                    <p className="text-sm text-yellow-700">
                      Budget Approval workflow shows consistently low efficiency (71%). The Finance Review stage 
                      is causing delays. Consider streamlining this process or adding additional reviewers.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-purple-50 rounded-lg">
                  <Coffee className="h-5 w-5 text-purple-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-purple-900">Peak Collaboration Time</h4>
                    <p className="text-sm text-purple-700">
                      Team collaboration peaks on Wednesdays and Thursdays between 11AM-2PM. Schedule important 
                      collaborative sessions during these high-activity periods for maximum engagement.
                    </p>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Recommendations */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <Card>
              <CardHeader>
                <CardTitle>Improvement Recommendations</CardTitle>
                <CardDescription>Actionable suggestions to enhance collaboration</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex items-start gap-3">
                  <Target className="h-5 w-5 text-blue-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium">Reduce Response Times</h4>
                    <p className="text-sm text-muted-foreground">
                      Implement SLA targets for message responses (2 hours max)
                    </p>
                  </div>
                </div>
                
                <Separator />
                
                <div className="flex items-start gap-3">
                  <Zap className="h-5 w-5 text-green-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium">Streamline Workflows</h4>
                    <p className="text-sm text-muted-foreground">
                      Automate routine approvals to reduce bottlenecks
                    </p>
                  </div>
                </div>
                
                <Separator />
                
                <div className="flex items-start gap-3">
                  <Users className="h-5 w-5 text-purple-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium">Cross-Team Projects</h4>
                    <p className="text-sm text-muted-foreground">
                      Increase collaborative projects to boost team synergy
                    </p>
                  </div>
                </div>
                
                <Separator />
                
                <div className="flex items-start gap-3">
                  <Calendar className="h-5 w-5 text-orange-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium">Meeting Efficiency</h4>
                    <p className="text-sm text-muted-foreground">
                      Implement structured agendas to improve meeting outcomes
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Success Metrics</CardTitle>
                <CardDescription>Track these KPIs to measure collaboration improvement</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-sm">Average Response Time</span>
                  <Badge variant="outline">Target: &lt; 2h</Badge>
                </div>
                
                <div className="flex justify-between items-center">
                  <span className="text-sm">Workflow Efficiency</span>
                  <Badge variant="outline">Target: &gt; 85%</Badge>
                </div>
                
                <div className="flex justify-between items-center">
                  <span className="text-sm">Collaboration Score</span>
                  <Badge variant="outline">Target: &gt; 90</Badge>
                </div>
                
                <div className="flex justify-between items-center">
                  <span className="text-sm">Cross-team Projects</span>
                  <Badge variant="outline">Target: &gt; 30/month</Badge>
                </div>
                
                <Separator />
                
                <div className="bg-muted/50 p-3 rounded-lg">
                  <div className="text-sm font-medium mb-1">Overall Health Score</div>
                  <div className="text-2xl font-bold text-green-600">87%</div>
                  <div className="text-xs text-muted-foreground">
                    +5% improvement from last month
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

export default CollaborationAnalytics