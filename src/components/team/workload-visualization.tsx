'use client'

import React, { useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Progress } from '@/components/ui/progress'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Separator } from '@/components/ui/separator'
import { Label } from '@/components/ui/label'
import {
  BarChart3,
  TrendingUp,
  TrendingDown,
  Clock,
  Calendar,
  Users,
  Target,
  AlertTriangle,
  CheckCircle,
  Activity,
  Gauge,
  PieChart,
  BarChart,
  LineChart,
  Settings,
  Download,
  RefreshCw,
  Filter,
  User,
  Zap,
  Coffee,
  Flame
} from 'lucide-react'
import { 
  ResponsiveContainer, 
  BarChart as RechartsBarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  Legend,
  PieChart as RechartsPieChart,
  Cell,
  Pie,
  LineChart as RechartsLineChart,
  Line,
  Area,
  AreaChart
} from 'recharts'

interface TeamMember {
  id: string
  name: string
  avatar?: string
  role: string
  status: 'online' | 'away' | 'busy' | 'offline'
  workload: number
  tasksCompleted: number
  tasksInProgress: number
  tasksPending: number
  capacity: number
  hoursWorked: number
  efficiency: number
  weeklyTrend: number[]
}

interface WorkloadData {
  name: string
  workload: number
  capacity: number
  efficiency: number
  tasks: number
  color: string
}

interface WorkloadVisualizationProps {
  members: TeamMember[]
}

export const WorkloadVisualization: React.FC<WorkloadVisualizationProps> = ({ members }) => {
  const [viewType, setViewType] = useState<'overview' | 'individual' | 'trends'>('overview')
  const [timeRange, setTimeRange] = useState<'week' | 'month' | 'quarter'>('week')
  const [selectedMember, setSelectedMember] = useState<string>('')

  // Transform data for charts
  const workloadData: WorkloadData[] = members.map((member, index) => {
    const colors = ['#8884d8', '#82ca9d', '#ffc658', '#ff7c7c', '#8dd1e1']
    return {
      name: member.name.split(' ')[0],
      workload: member.workload,
      capacity: 100,
      efficiency: member.efficiency || 85,
      tasks: member.tasksInProgress + member.tasksPending,
      color: colors[index % colors.length]
    }
  })

  const utilizationData = members.map(member => ({
    name: member.name.split(' ')[0],
    utilized: member.workload,
    available: 100 - member.workload
  }))

  const weeklyTrendData = [
    { day: 'Mon', team: 78, target: 80 },
    { day: 'Tue', team: 82, target: 80 },
    { day: 'Wed', team: 85, target: 80 },
    { day: 'Thu', team: 88, target: 80 },
    { day: 'Fri', team: 83, target: 80 },
    { day: 'Sat', team: 45, target: 50 },
    { day: 'Sun', team: 20, target: 30 }
  ]

  const distributionData = [
    { name: 'Under-utilized', value: members.filter(m => m.workload < 60).length, color: '#82ca9d' },
    { name: 'Optimal', value: members.filter(m => m.workload >= 60 && m.workload <= 85).length, color: '#8884d8' },
    { name: 'Over-utilized', value: members.filter(m => m.workload > 85).length, color: '#ff7c7c' }
  ]

  const getWorkloadStatus = (workload: number) => {
    if (workload < 60) return { status: 'Under-utilized', color: 'text-green-600', bg: 'bg-green-100' }
    if (workload <= 85) return { status: 'Optimal', color: 'text-blue-600', bg: 'bg-blue-100' }
    return { status: 'Over-utilized', color: 'text-red-600', bg: 'bg-red-100' }
  }

  const getStatusIcon = (workload: number) => {
    if (workload < 60) return <Coffee className="h-4 w-4" />
    if (workload <= 85) return <Zap className="h-4 w-4" />
    return <Flame className="h-4 w-4" />
  }

  const teamAverageWorkload = Math.round(members.reduce((sum, m) => sum + m.workload, 0) / members.length)
  const teamEfficiency = Math.round(members.reduce((sum, m) => sum + (m.efficiency || 85), 0) / members.length)
  const overUtilizedCount = members.filter(m => m.workload > 85).length
  const underUtilizedCount = members.filter(m => m.workload < 60).length

  return (
    <div className="space-y-6">
      {/* Header Controls */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">Workload Analysis</h2>
          <p className="text-muted-foreground">
            Monitor team capacity and optimize resource allocation
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

      {/* Quick Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Average Workload</CardTitle>
            <Gauge className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{teamAverageWorkload}%</div>
            <p className="text-xs text-muted-foreground">
              {teamAverageWorkload > 80 ? '+5% from last week' : '-2% from last week'}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Team Efficiency</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{teamEfficiency}%</div>
            <p className="text-xs text-muted-foreground">
              +3% from last week
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Over-utilized</CardTitle>
            <AlertTriangle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">{overUtilizedCount}</div>
            <p className="text-xs text-muted-foreground">
              Team members &gt; 85%
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Under-utilized</CardTitle>
            <CheckCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">{underUtilizedCount}</div>
            <p className="text-xs text-muted-foreground">
              Team members &lt; 60%
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Main Content */}
      <Tabs value={viewType} onValueChange={(value: any) => setViewType(value)}>
        <TabsList>
          <TabsTrigger value="overview">
            <BarChart3 className="h-4 w-4 mr-2" />
            Overview
          </TabsTrigger>
          <TabsTrigger value="individual">
            <User className="h-4 w-4 mr-2" />
            Individual
          </TabsTrigger>
          <TabsTrigger value="trends">
            <TrendingUp className="h-4 w-4 mr-2" />
            Trends
          </TabsTrigger>
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Workload Distribution Chart */}
            <Card>
              <CardHeader>
                <CardTitle>Workload Distribution</CardTitle>
                <CardDescription>Current workload vs capacity for each team member</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <RechartsBarChart data={workloadData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="workload" fill="#8884d8" name="Current Workload" />
                    <Bar dataKey="capacity" fill="#e0e7ff" name="Capacity" />
                  </RechartsBarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Utilization Pie Chart */}
            <Card>
              <CardHeader>
                <CardTitle>Team Utilization</CardTitle>
                <CardDescription>Distribution of workload levels across the team</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <RechartsPieChart>
                    <Pie
                      data={distributionData}
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      dataKey="value"
                      label={({ name, value }) => `${name}: ${value}`}
                    >
                      {distributionData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </RechartsPieChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Team Member Details */}
          <Card>
            <CardHeader>
              <CardTitle>Team Member Workload</CardTitle>
              <CardDescription>Detailed view of each team member's current workload</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {members.map(member => {
                  const status = getWorkloadStatus(member.workload)
                  return (
                    <div key={member.id} className="flex items-center gap-4 p-4 border rounded-lg">
                      <Avatar className="h-12 w-12">
                        <AvatarFallback>
                          {member.name.split(' ').map(n => n[0]).join('')}
                        </AvatarFallback>
                      </Avatar>
                      
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-2">
                          <h4 className="font-medium">{member.name}</h4>
                          <Badge variant="outline">{member.role}</Badge>
                          <div className={`flex items-center gap-1 px-2 py-1 rounded text-xs ${status.bg} ${status.color}`}>
                            {getStatusIcon(member.workload)}
                            {status.status}
                          </div>
                        </div>
                        
                        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                          <div>
                            <div className="text-muted-foreground">Workload</div>
                            <div className="font-medium">{member.workload}%</div>
                          </div>
                          <div>
                            <div className="text-muted-foreground">Tasks</div>
                            <div className="font-medium">
                              {member.tasksInProgress + member.tasksPending}
                            </div>
                          </div>
                          <div>
                            <div className="text-muted-foreground">Completed</div>
                            <div className="font-medium">{member.tasksCompleted}</div>
                          </div>
                          <div>
                            <div className="text-muted-foreground">Efficiency</div>
                            <div className="font-medium">{member.efficiency || 85}%</div>
                          </div>
                        </div>
                        
                        <div className="mt-3">
                          <Progress value={member.workload} className="h-2" />
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

        {/* Individual Tab */}
        <TabsContent value="individual" className="space-y-6">
          <div className="flex items-center gap-4">
            <Label className="font-medium">Select Team Member:</Label>
            <Select value={selectedMember} onValueChange={setSelectedMember}>
              <SelectTrigger className="w-[200px]">
                <SelectValue placeholder="Choose a member" />
              </SelectTrigger>
              <SelectContent>
                {members.map(member => (
                  <SelectItem key={member.id} value={member.id}>
                    {member.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {selectedMember && (() => {
            const member = members.find(m => m.id === selectedMember)!
            return (
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Member Profile */}
                <Card>
                  <CardHeader>
                    <CardTitle>Profile</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <div className="flex items-center gap-3">
                      <Avatar className="h-16 w-16">
                        <AvatarFallback className="text-lg">
                          {member.name.split(' ').map(n => n[0]).join('')}
                        </AvatarFallback>
                      </Avatar>
                      <div>
                        <h3 className="font-medium">{member.name}</h3>
                        <p className="text-sm text-muted-foreground">{member.role}</p>
                        <Badge variant="outline" className="mt-1">
                          {member.status}
                        </Badge>
                      </div>
                    </div>
                    
                    <Separator />
                    
                    <div className="space-y-3">
                      <div className="flex justify-between">
                        <span className="text-sm">Current Workload</span>
                        <span className="font-medium">{member.workload}%</span>
                      </div>
                      <Progress value={member.workload} />
                      
                      <div className="flex justify-between">
                        <span className="text-sm">Efficiency</span>
                        <span className="font-medium">{member.efficiency || 85}%</span>
                      </div>
                      <Progress value={member.efficiency || 85} />
                    </div>
                  </CardContent>
                </Card>

                {/* Task Breakdown */}
                <Card>
                  <CardHeader>
                    <CardTitle>Task Breakdown</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-4">
                      <div className="flex items-center justify-between p-3 bg-blue-50 rounded">
                        <div className="flex items-center gap-2">
                          <Clock className="h-4 w-4 text-blue-600" />
                          <span className="text-sm">In Progress</span>
                        </div>
                        <span className="font-medium">{member.tasksInProgress}</span>
                      </div>
                      
                      <div className="flex items-center justify-between p-3 bg-yellow-50 rounded">
                        <div className="flex items-center gap-2">
                          <Target className="h-4 w-4 text-yellow-600" />
                          <span className="text-sm">Pending</span>
                        </div>
                        <span className="font-medium">{member.tasksPending}</span>
                      </div>
                      
                      <div className="flex items-center justify-between p-3 bg-green-50 rounded">
                        <div className="flex items-center gap-2">
                          <CheckCircle className="h-4 w-4 text-green-600" />
                          <span className="text-sm">Completed</span>
                        </div>
                        <span className="font-medium">{member.tasksCompleted}</span>
                      </div>
                    </div>
                  </CardContent>
                </Card>

                {/* Weekly Trend */}
                <Card>
                  <CardHeader>
                    <CardTitle>Weekly Trend</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <ResponsiveContainer width="100%" height={200}>
                      <RechartsLineChart data={member.weeklyTrend?.map((value, index) => ({
                        day: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index],
                        workload: value
                      })) || []}>
                        <XAxis dataKey="day" />
                        <YAxis />
                        <Tooltip />
                        <Line 
                          type="monotone" 
                          dataKey="workload" 
                          stroke="#8884d8" 
                          strokeWidth={2}
                        />
                      </RechartsLineChart>
                    </ResponsiveContainer>
                  </CardContent>
                </Card>
              </div>
            )
          })()}
        </TabsContent>

        {/* Trends Tab */}
        <TabsContent value="trends" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Weekly Workload Trend */}
            <Card>
              <CardHeader>
                <CardTitle>Weekly Workload Trend</CardTitle>
                <CardDescription>Team workload vs target throughout the week</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={weeklyTrendData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="day" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Area 
                      type="monotone" 
                      dataKey="team" 
                      stackId="1" 
                      stroke="#8884d8" 
                      fill="#8884d8" 
                      name="Team Average"
                    />
                    <Line 
                      type="monotone" 
                      dataKey="target" 
                      stroke="#ff7300" 
                      strokeDasharray="5 5"
                      name="Target"
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Efficiency Trends */}
            <Card>
              <CardHeader>
                <CardTitle>Efficiency Comparison</CardTitle>
                <CardDescription>Team member efficiency over time</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <RechartsBarChart data={workloadData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="efficiency" fill="#82ca9d" name="Efficiency %" />
                  </RechartsBarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Insights */}
          <Card>
            <CardHeader>
              <CardTitle>Workload Insights</CardTitle>
              <CardDescription>AI-powered recommendations for workload optimization</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                  <TrendingUp className="h-5 w-5 text-blue-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-blue-900">Optimization Opportunity</h4>
                    <p className="text-sm text-blue-700">
                      Consider redistributing tasks from Sarah Wilson (90% workload) to Mike Johnson (60% workload) 
                      to improve team balance.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-yellow-50 rounded-lg">
                  <AlertTriangle className="h-5 w-5 text-yellow-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-yellow-900">Capacity Alert</h4>
                    <p className="text-sm text-yellow-700">
                      Team is approaching maximum capacity. Consider postponing non-critical tasks 
                      or bringing in additional resources.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-green-50 rounded-lg">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-green-900">Efficiency Improvement</h4>
                    <p className="text-sm text-green-700">
                      Team efficiency has improved by 5% this week. The current workflow 
                      optimizations are showing positive results.
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

export default WorkloadVisualization