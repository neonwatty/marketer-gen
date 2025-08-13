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
  TrendingUp,
  TrendingDown,
  Clock,
  CheckCircle,
  Target,
  Zap,
  BarChart3,
  LineChart,
  PieChart,
  Activity,
  Calendar,
  Users,
  ArrowUpRight,
  ArrowDownRight,
  Award,
  Gauge,
  Timer,
  Trophy,
  Flame,
  Coffee,
  AlertCircle,
  Download,
  RefreshCw,
  Filter
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
  PieChart as RechartsPieChart,
  Pie,
  Cell,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar
} from 'recharts'

interface ProductivityMetric {
  id: string
  name: string
  value: number
  previousValue: number
  target: number
  unit: string
  trend: 'up' | 'down' | 'stable'
  category: 'output' | 'efficiency' | 'quality' | 'speed'
}

interface TeamMemberProductivity {
  id: string
  name: string
  role: string
  tasksCompleted: number
  averageTaskTime: number
  productivityScore: number
  outputQuality: number
  focusTime: number
  weeklyOutput: number[]
  strengths: string[]
  improvementAreas: string[]
}

interface ProductivityTrend {
  period: string
  tasksCompleted: number
  hoursWorked: number
  productivity: number
  efficiency: number
  quality: number
  burnoutRisk: number
}

const mockProductivityMetrics: ProductivityMetric[] = [
  {
    id: '1',
    name: 'Tasks Completed',
    value: 324,
    previousValue: 289,
    target: 320,
    unit: 'tasks',
    trend: 'up',
    category: 'output'
  },
  {
    id: '2',
    name: 'Average Task Time',
    value: 2.8,
    previousValue: 3.4,
    target: 3.0,
    unit: 'hours',
    trend: 'up',
    category: 'efficiency'
  },
  {
    id: '3',
    name: 'Productivity Score',
    value: 87,
    previousValue: 82,
    target: 85,
    unit: 'points',
    trend: 'up',
    category: 'output'
  },
  {
    id: '4',
    name: 'Quality Rating',
    value: 4.6,
    previousValue: 4.3,
    target: 4.5,
    unit: '/5',
    trend: 'up',
    category: 'quality'
  },
  {
    id: '5',
    name: 'Focus Time',
    value: 6.2,
    previousValue: 5.8,
    target: 6.0,
    unit: 'hours/day',
    trend: 'up',
    category: 'efficiency'
  },
  {
    id: '6',
    name: 'Delivery Speed',
    value: 92,
    previousValue: 88,
    target: 90,
    unit: '% on-time',
    trend: 'up',
    category: 'speed'
  }
]

const mockTeamProductivity: TeamMemberProductivity[] = [
  {
    id: '1',
    name: 'John Doe',
    role: 'Marketing Manager',
    tasksCompleted: 68,
    averageTaskTime: 2.5,
    productivityScore: 92,
    outputQuality: 4.7,
    focusTime: 6.8,
    weeklyOutput: [12, 15, 14, 13, 16, 18, 10],
    strengths: ['Strategic Planning', 'Team Leadership', 'Quality Focus'],
    improvementAreas: ['Time Management', 'Task Prioritization']
  },
  {
    id: '2',
    name: 'Sarah Wilson',
    role: 'Content Creator',
    tasksCompleted: 89,
    averageTaskTime: 1.8,
    productivityScore: 96,
    outputQuality: 4.9,
    focusTime: 7.2,
    weeklyOutput: [18, 20, 17, 19, 22, 15, 8],
    strengths: ['Creative Output', 'Speed', 'Consistency'],
    improvementAreas: ['Complex Projects', 'Delegation']
  },
  {
    id: '3',
    name: 'Mike Johnson',
    role: 'Designer',
    tasksCompleted: 54,
    averageTaskTime: 4.2,
    productivityScore: 85,
    outputQuality: 4.8,
    focusTime: 5.9,
    weeklyOutput: [8, 10, 9, 11, 12, 14, 6],
    strengths: ['Design Quality', 'Innovation', 'Attention to Detail'],
    improvementAreas: ['Speed', 'Process Efficiency']
  },
  {
    id: '4',
    name: 'Lisa Brown',
    role: 'Marketing Director',
    tasksCompleted: 45,
    averageTaskTime: 3.8,
    productivityScore: 88,
    outputQuality: 4.6,
    focusTime: 6.4,
    weeklyOutput: [7, 9, 8, 10, 11, 12, 5],
    strengths: ['Strategic Thinking', 'Decision Making', 'Mentoring'],
    improvementAreas: ['Operational Efficiency', 'Delegation']
  },
  {
    id: '5',
    name: 'David Lee',
    role: 'Copywriter',
    tasksCompleted: 78,
    averageTaskTime: 2.1,
    productivityScore: 91,
    outputQuality: 4.4,
    focusTime: 6.6,
    weeklyOutput: [15, 17, 14, 16, 18, 16, 9],
    strengths: ['Speed', 'Versatility', 'Reliability'],
    improvementAreas: ['Quality Consistency', 'Complex Concepts']
  }
]

const mockProductivityTrends: ProductivityTrend[] = [
  { period: 'Jan', tasksCompleted: 267, hoursWorked: 720, productivity: 82, efficiency: 85, quality: 4.2, burnoutRisk: 15 },
  { period: 'Feb', tasksCompleted: 289, hoursWorked: 736, productivity: 84, efficiency: 87, quality: 4.3, burnoutRisk: 18 },
  { period: 'Mar', tasksCompleted: 312, hoursWorked: 742, productivity: 86, efficiency: 89, quality: 4.4, burnoutRisk: 22 },
  { period: 'Apr', tasksCompleted: 298, hoursWorked: 728, productivity: 85, efficiency: 86, quality: 4.3, burnoutRisk: 20 },
  { period: 'May', tasksCompleted: 289, hoursWorked: 715, productivity: 82, efficiency: 84, quality: 4.3, burnoutRisk: 16 },
  { period: 'Jun', tasksCompleted: 324, hoursWorked: 748, productivity: 87, efficiency: 91, quality: 4.6, burnoutRisk: 24 }
]

const productivityDistribution = [
  { name: 'High Performers', value: 2, color: '#10b981' },
  { name: 'Above Average', value: 2, color: '#3b82f6' },
  { name: 'Average', value: 1, color: '#f59e0b' },
  { name: 'Below Average', value: 0, color: '#ef4444' }
]

const taskTypeDistribution = [
  { name: 'Creative Work', value: 35, color: '#8b5cf6' },
  { name: 'Strategic Planning', value: 25, color: '#06b6d4' },
  { name: 'Administrative', value: 20, color: '#84cc16' },
  { name: 'Communication', value: 15, color: '#f97316' },
  { name: 'Analysis', value: 5, color: '#ec4899' }
]

const timeAllocationData = [
  { category: 'Deep Work', planned: 6, actual: 5.2, optimal: 6.5 },
  { category: 'Meetings', planned: 2, actual: 2.8, optimal: 2.0 },
  { category: 'Communication', planned: 1, actual: 1.5, optimal: 1.0 },
  { category: 'Planning', planned: 0.5, actual: 0.8, optimal: 1.0 },
  { category: 'Breaks', planned: 0.5, actual: 0.7, optimal: 0.5 }
]

const burnoutRiskData = mockTeamProductivity.map(member => ({
  name: member.name.split(' ')[0],
  workload: (member.tasksCompleted / 20) * 100,
  stress: Math.min(100, (member.averageTaskTime * 20) + (member.focusTime * 5)),
  satisfaction: member.outputQuality * 20,
  risk: member.focusTime > 7 ? 'High' : member.focusTime > 6 ? 'Medium' : 'Low'
}))

export const ProductivityMetrics: React.FC = () => {
  const [timeRange, setTimeRange] = useState<'week' | 'month' | 'quarter' | 'year'>('month')
  const [selectedMember, setSelectedMember] = useState<string>('')
  const [viewType, setViewType] = useState<'overview' | 'individual' | 'trends' | 'insights'>('overview')

  const getTrendIcon = (trend: string, value: number, target: number) => {
    if (trend === 'up') {
      return value >= target ? 
        <ArrowUpRight className="h-4 w-4 text-green-600" /> : 
        <ArrowUpRight className="h-4 w-4 text-blue-600" />
    }
    if (trend === 'down') {
      return <ArrowDownRight className="h-4 w-4 text-red-600" />
    }
    return <TrendingUp className="h-4 w-4 text-gray-600" />
  }

  const getTrendColor = (trend: string, value: number, target: number) => {
    if (trend === 'up') {
      return value >= target ? 'text-green-600' : 'text-blue-600'
    }
    if (trend === 'down') {
      return 'text-red-600'
    }
    return 'text-gray-600'
  }

  const getProductivityBadge = (score: number) => {
    if (score >= 95) return { variant: 'default' as const, label: 'Exceptional', icon: <Trophy className="h-3 w-3" /> }
    if (score >= 90) return { variant: 'default' as const, label: 'Excellent', icon: <Award className="h-3 w-3" /> }
    if (score >= 80) return { variant: 'secondary' as const, label: 'Good', icon: <Zap className="h-3 w-3" /> }
    if (score >= 70) return { variant: 'outline' as const, label: 'Average', icon: <Coffee className="h-3 w-3" /> }
    return { variant: 'destructive' as const, label: 'Needs Improvement', icon: <AlertCircle className="h-3 w-3" /> }
  }

  const getBurnoutRiskColor = (risk: string) => {
    switch (risk) {
      case 'High': return 'text-red-600'
      case 'Medium': return 'text-yellow-600'
      case 'Low': return 'text-green-600'
      default: return 'text-gray-600'
    }
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
            <BarChart3 className="h-8 w-8" />
            Productivity Analytics
          </h1>
          <p className="text-muted-foreground">
            Monitor team productivity, output quality, and efficiency metrics
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
        {mockProductivityMetrics.map(metric => {
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
            <Activity className="h-4 w-4 mr-2" />
            Overview
          </TabsTrigger>
          <TabsTrigger value="individual">
            <Users className="h-4 w-4 mr-2" />
            Individual
          </TabsTrigger>
          <TabsTrigger value="trends">
            <TrendingUp className="h-4 w-4 mr-2" />
            Trends
          </TabsTrigger>
          <TabsTrigger value="insights">
            <Target className="h-4 w-4 mr-2" />
            Insights
          </TabsTrigger>
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Productivity Distribution */}
            <Card>
              <CardHeader>
                <CardTitle>Team Productivity Distribution</CardTitle>
                <CardDescription>Performance levels across the team</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <RechartsPieChart>
                    <Pie
                      data={productivityDistribution}
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      dataKey="value"
                      label={({ name, value }) => `${name}: ${value}`}
                    >
                      {productivityDistribution.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </RechartsPieChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Task Type Distribution */}
            <Card>
              <CardHeader>
                <CardTitle>Task Type Distribution</CardTitle>
                <CardDescription>Time allocation across different work categories</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <RechartsPieChart>
                    <Pie
                      data={taskTypeDistribution}
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      dataKey="value"
                      label={({ name, value }) => `${name}: ${value}%`}
                    >
                      {taskTypeDistribution.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </RechartsPieChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Time Allocation Analysis */}
            <Card>
              <CardHeader>
                <CardTitle>Time Allocation Analysis</CardTitle>
                <CardDescription>Planned vs actual vs optimal time distribution</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={timeAllocationData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="category" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="planned" fill="#94a3b8" name="Planned" />
                    <Bar dataKey="actual" fill="#3b82f6" name="Actual" />
                    <Bar dataKey="optimal" fill="#10b981" name="Optimal" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Burnout Risk Assessment */}
            <Card>
              <CardHeader>
                <CardTitle>Burnout Risk Assessment</CardTitle>
                <CardDescription>Team wellbeing and workload balance indicators</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {burnoutRiskData.map(member => (
                    <div key={member.name} className="flex items-center gap-4 p-3 border rounded-lg">
                      <Avatar className="h-10 w-10">
                        <AvatarFallback>
                          {member.name.split(' ').map(n => n[0]).join('')}
                        </AvatarFallback>
                      </Avatar>
                      
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-2">
                          <span className="font-medium">{member.name}</span>
                          <Badge 
                            variant={member.risk === 'High' ? 'destructive' : member.risk === 'Medium' ? 'outline' : 'secondary'}
                            className={member.risk === 'High' ? 'bg-red-100 text-red-700' : ''}
                          >
                            {member.risk} Risk
                          </Badge>
                        </div>
                        
                        <div className="grid grid-cols-3 gap-4 text-xs">
                          <div>
                            <div className="text-muted-foreground">Workload</div>
                            <div className={`font-medium ${member.workload > 90 ? 'text-red-600' : member.workload > 75 ? 'text-yellow-600' : 'text-green-600'}`}>
                              {Math.round(member.workload)}%
                            </div>
                          </div>
                          <div>
                            <div className="text-muted-foreground">Stress Level</div>
                            <div className={`font-medium ${member.stress > 80 ? 'text-red-600' : member.stress > 60 ? 'text-yellow-600' : 'text-green-600'}`}>
                              {Math.round(member.stress)}%
                            </div>
                          </div>
                          <div>
                            <div className="text-muted-foreground">Satisfaction</div>
                            <div className={`font-medium ${member.satisfaction > 85 ? 'text-green-600' : member.satisfaction > 70 ? 'text-yellow-600' : 'text-red-600'}`}>
                              {Math.round(member.satisfaction)}%
                            </div>
                          </div>
                        </div>
                      </div>
                      
                      <div className="text-right">
                        <Button variant="outline" size="sm">
                          {member.risk === 'High' ? 'Action Needed' : 'Monitor'}
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Individual Tab */}
        <TabsContent value="individual" className="space-y-6">
          <div className="flex items-center gap-4">
            <Select value={selectedMember} onValueChange={setSelectedMember}>
              <SelectTrigger className="w-[200px]">
                <SelectValue placeholder="Select team member" />
              </SelectTrigger>
              <SelectContent>
                {mockTeamProductivity.map(member => (
                  <SelectItem key={member.id} value={member.id}>
                    {member.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Team Member Cards */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {mockTeamProductivity.map(member => {
              const badge = getProductivityBadge(member.productivityScore)
              return (
                <Card key={member.id}>
                  <CardHeader>
                    <div className="flex items-center gap-3">
                      <Avatar className="h-12 w-12">
                        <AvatarFallback className="text-lg">
                          {member.name.split(' ').map(n => n[0]).join('')}
                        </AvatarFallback>
                      </Avatar>
                      <div>
                        <CardTitle className="text-lg">{member.name}</CardTitle>
                        <CardDescription>{member.role}</CardDescription>
                      </div>
                      <div className="ml-auto text-right">
                        <Badge variant={badge.variant} className="flex items-center gap-1">
                          {badge.icon}
                          {badge.label}
                        </Badge>
                        <div className="text-sm font-bold text-blue-600 mt-1">
                          {member.productivityScore} Score
                        </div>
                      </div>
                    </div>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    {/* Key Metrics */}
                    <div className="grid grid-cols-2 gap-4 text-sm">
                      <div className="space-y-2">
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Tasks Completed</span>
                          <span className="font-medium">{member.tasksCompleted}</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Avg Task Time</span>
                          <span className="font-medium">{member.averageTaskTime}h</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Focus Time</span>
                          <span className={`font-medium ${member.focusTime > 7 ? 'text-red-600' : member.focusTime > 6 ? 'text-yellow-600' : 'text-green-600'}`}>
                            {member.focusTime}h/day
                          </span>
                        </div>
                      </div>
                      <div className="space-y-2">
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Output Quality</span>
                          <span className={`font-medium ${member.outputQuality >= 4.5 ? 'text-green-600' : member.outputQuality >= 4.0 ? 'text-yellow-600' : 'text-red-600'}`}>
                            {member.outputQuality}/5
                          </span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Weekly Average</span>
                          <span className="font-medium">
                            {Math.round(member.weeklyOutput.reduce((a, b) => a + b, 0) / 7)} tasks/day
                          </span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Efficiency</span>
                          <span className={`font-medium ${member.productivityScore >= 90 ? 'text-green-600' : member.productivityScore >= 80 ? 'text-yellow-600' : 'text-red-600'}`}>
                            {Math.round((member.tasksCompleted / member.averageTaskTime) * 10)}%
                          </span>
                        </div>
                      </div>
                    </div>

                    <Separator />

                    {/* Weekly Output Chart */}
                    <div>
                      <h4 className="text-sm font-medium mb-2">Weekly Output Pattern</h4>
                      <ResponsiveContainer width="100%" height={100}>
                        <BarChart data={member.weeklyOutput.map((value, index) => ({
                          day: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index],
                          tasks: value
                        }))}>
                          <Bar dataKey="tasks" fill="#3b82f6" />
                          <Tooltip />
                        </BarChart>
                      </ResponsiveContainer>
                    </div>

                    <Separator />

                    {/* Strengths & Improvement Areas */}
                    <div className="grid grid-cols-1 gap-3">
                      <div>
                        <h4 className="text-sm font-medium mb-2 text-green-700">Strengths</h4>
                        <div className="flex flex-wrap gap-1">
                          {member.strengths.map(strength => (
                            <Badge key={strength} variant="secondary" className="text-xs bg-green-100 text-green-800">
                              {strength}
                            </Badge>
                          ))}
                        </div>
                      </div>
                      <div>
                        <h4 className="text-sm font-medium mb-2 text-blue-700">Growth Areas</h4>
                        <div className="flex flex-wrap gap-1">
                          {member.improvementAreas.map(area => (
                            <Badge key={area} variant="outline" className="text-xs text-blue-600 border-blue-200">
                              {area}
                            </Badge>
                          ))}
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              )
            })}
          </div>
        </TabsContent>

        {/* Trends Tab */}
        <TabsContent value="trends" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Productivity Trends Over Time */}
            <Card>
              <CardHeader>
                <CardTitle>Productivity Trends</CardTitle>
                <CardDescription>Team productivity metrics over time</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <RechartsLineChart data={mockProductivityTrends}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="period" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Line type="monotone" dataKey="productivity" stroke="#3b82f6" name="Productivity" />
                    <Line type="monotone" dataKey="efficiency" stroke="#10b981" name="Efficiency" />
                    <Line type="monotone" dataKey="quality" stroke="#f59e0b" name="Quality" />
                  </RechartsLineChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Output vs Hours Correlation */}
            <Card>
              <CardHeader>
                <CardTitle>Output vs Hours Analysis</CardTitle>
                <CardDescription>Tasks completed vs hours worked correlation</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={mockProductivityTrends}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="period" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Area 
                      type="monotone" 
                      dataKey="tasksCompleted" 
                      stackId="1" 
                      stroke="#8884d8" 
                      fill="#8884d8" 
                      fillOpacity={0.3}
                      name="Tasks Completed"
                    />
                    <Area 
                      type="monotone" 
                      dataKey="hoursWorked" 
                      stackId="2" 
                      stroke="#82ca9d" 
                      fill="#82ca9d" 
                      fillOpacity={0.3}
                      name="Hours Worked"
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Burnout Risk Trend */}
          <Card>
            <CardHeader>
              <CardTitle>Burnout Risk Monitoring</CardTitle>
              <CardDescription>Track team wellbeing and identify potential burnout risks</CardDescription>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <RechartsLineChart data={mockProductivityTrends}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="period" />
                  <YAxis />
                  <Tooltip />
                  <Line 
                    type="monotone" 
                    dataKey="burnoutRisk" 
                    stroke="#ef4444" 
                    strokeWidth={3}
                    name="Burnout Risk %"
                  />
                </RechartsLineChart>
              </ResponsiveContainer>
              <div className="mt-4 p-3 bg-yellow-50 rounded-lg">
                <div className="flex items-center gap-2 text-yellow-800">
                  <AlertCircle className="h-4 w-4" />
                  <span className="text-sm font-medium">Burnout Risk Alert</span>
                </div>
                <p className="text-sm text-yellow-700 mt-1">
                  Current burnout risk is at 24% - monitor team workload and consider implementing wellness initiatives.
                </p>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Insights Tab */}
        <TabsContent value="insights" className="space-y-6">
          {/* AI-Powered Insights */}
          <Card>
            <CardHeader>
              <CardTitle>Productivity Insights</CardTitle>
              <CardDescription>AI-powered analysis and recommendations</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-start gap-3 p-4 bg-green-50 rounded-lg">
                  <TrendingUp className="h-5 w-5 text-green-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-green-900">Strong Performance Trend</h4>
                    <p className="text-sm text-green-700">
                      Team productivity has improved by 12% over the last quarter. Sarah Wilson consistently shows 
                      exceptional output with high quality ratings.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                  <Zap className="h-5 w-5 text-blue-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-blue-900">Efficiency Optimization</h4>
                    <p className="text-sm text-blue-700">
                      Mike Johnson's design work takes longer but shows exceptional quality. Consider adjusting 
                      timelines for creative projects to balance speed and quality.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-yellow-50 rounded-lg">
                  <AlertCircle className="h-5 w-5 text-yellow-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-yellow-900">Workload Balance Alert</h4>
                    <p className="text-sm text-yellow-700">
                      Team is approaching high-risk burnout levels (24%). Consider redistributing workload or 
                      implementing stress management practices.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-purple-50 rounded-lg">
                  <Timer className="h-5 w-5 text-purple-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-purple-900">Time Optimization</h4>
                    <p className="text-sm text-purple-700">
                      Team spends 40% more time in meetings than planned. Consider implementing meeting-free 
                      blocks to increase deep work time and productivity.
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
                <CardTitle>Action Recommendations</CardTitle>
                <CardDescription>Specific steps to improve team productivity</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 rounded-full bg-green-600 mt-2"></div>
                  <div>
                    <h4 className="font-medium">Implement Focus Time Blocks</h4>
                    <p className="text-sm text-muted-foreground">
                      Schedule 2-4 hour uninterrupted work blocks for deep tasks
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 rounded-full bg-blue-600 mt-2"></div>
                  <div>
                    <h4 className="font-medium">Optimize Meeting Schedule</h4>
                    <p className="text-sm text-muted-foreground">
                      Reduce meeting time by 25% and batch similar meetings
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 rounded-full bg-purple-600 mt-2"></div>
                  <div>
                    <h4 className="font-medium">Skill-Based Task Assignment</h4>
                    <p className="text-sm text-muted-foreground">
                      Match tasks to individual strengths for optimal efficiency
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 rounded-full bg-orange-600 mt-2"></div>
                  <div>
                    <h4 className="font-medium">Wellness Check-ins</h4>
                    <p className="text-sm text-muted-foreground">
                      Weekly 1:1s to monitor workload and prevent burnout
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Performance Targets</CardTitle>
                <CardDescription>Goals to track improvement progress</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Team Productivity Score</span>
                    <span className="font-medium">Target: 90+</span>
                  </div>
                  <Progress value={87} className="h-2" />
                  <div className="text-xs text-muted-foreground">Current: 87/100</div>
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Average Task Time</span>
                    <span className="font-medium">Target: < 3h</span>
                  </div>
                  <Progress value={93} className="h-2" />
                  <div className="text-xs text-muted-foreground">Current: 2.8h</div>
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Burnout Risk</span>
                    <span className="font-medium">Target: < 20%</span>
                  </div>
                  <Progress value={76} className="h-2 bg-red-100 [&>div]:bg-red-500" />
                  <div className="text-xs text-red-600">Current: 24% - Action Needed</div>
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Output Quality</span>
                    <span className="font-medium">Target: 4.5+/5</span>
                  </div>
                  <Progress value={92} className="h-2" />
                  <div className="text-xs text-muted-foreground">Current: 4.6/5</div>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  )
}

export default ProductivityMetrics