'use client'

import React, { useState, useEffect } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Progress } from '@/components/ui/progress'
import { Separator } from '@/components/ui/separator'
import { PendingApprovalsWidget } from './pending-approvals-widget'
import { AssignedTasksOverview } from './assigned-tasks-overview'
import { TeamActivityFeed } from './team-activity-feed'
import { WorkloadVisualization } from './workload-visualization'
import { TeamMemberStatus } from './team-member-status'
import { TeamPerformanceMetrics } from './team-performance-metrics'
import { TaskAssignmentInterface } from './task-assignment-interface'
import {
  Users,
  Calendar,
  CheckCircle,
  Clock,
  TrendingUp,
  BarChart3,
  Settings,
  Plus,
  Filter,
  Download,
  RefreshCw,
  Bell,
  Grid3X3,
  List,
  Kanban,
  Target,
  Trophy,
  AlertCircle,
  ArrowUpRight,
  ArrowDownRight,
  Activity,
  Trash2
} from 'lucide-react'

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
}

interface TeamStats {
  totalMembers: number
  activeMembers: number
  totalTasks: number
  completedTasks: number
  pendingApprovals: number
  overdueItems: number
  averageWorkload: number
  teamEfficiency: number
}

const mockTeamMembers: TeamMember[] = [
  {
    id: '1',
    name: 'John Doe',
    role: 'Marketing Manager',
    status: 'online',
    workload: 85,
    tasksCompleted: 12,
    tasksInProgress: 5,
    tasksPending: 3
  },
  {
    id: '2',
    name: 'Sarah Wilson',
    role: 'Content Creator',
    status: 'busy',
    workload: 92,
    tasksCompleted: 8,
    tasksInProgress: 7,
    tasksPending: 2
  },
  {
    id: '3',
    name: 'Mike Johnson',
    role: 'Designer',
    status: 'online',
    workload: 68,
    tasksCompleted: 15,
    tasksInProgress: 3,
    tasksPending: 1
  },
  {
    id: '4',
    name: 'Lisa Brown',
    role: 'Marketing Director',
    status: 'away',
    workload: 45,
    tasksCompleted: 6,
    tasksInProgress: 2,
    tasksPending: 5
  },
  {
    id: '5',
    name: 'David Lee',
    role: 'Copywriter',
    status: 'online',
    workload: 75,
    tasksCompleted: 10,
    tasksInProgress: 4,
    tasksPending: 2
  }
]

const mockTeamStats: TeamStats = {
  totalMembers: 5,
  activeMembers: 3,
  totalTasks: 45,
  completedTasks: 32,
  pendingApprovals: 8,
  overdueItems: 3,
  averageWorkload: 73,
  teamEfficiency: 87
}

export const TeamDashboard: React.FC = () => {
  const [activeTab, setActiveTab] = useState('overview')
  const [viewMode, setViewMode] = useState<'grid' | 'list' | 'kanban'>('grid')
  const [teamMembers, setTeamMembers] = useState<TeamMember[]>(mockTeamMembers)
  const [teamStats, setTeamStats] = useState<TeamStats>(mockTeamStats)
  const [loading, setLoading] = useState(false)
  const [showAssignmentDialog, setShowAssignmentDialog] = useState(false)

  const handleRefresh = async () => {
    setLoading(true)
    // Simulate data refresh
    setTimeout(() => {
      setLoading(false)
    }, 1000)
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'online':
        return 'bg-green-500'
      case 'busy':
        return 'bg-red-500'
      case 'away':
        return 'bg-yellow-500'
      case 'offline':
        return 'bg-gray-400'
      default:
        return 'bg-gray-400'
    }
  }

  const getWorkloadColor = (workload: number) => {
    if (workload >= 90) return 'text-red-600'
    if (workload >= 75) return 'text-orange-600'
    if (workload >= 50) return 'text-yellow-600'
    return 'text-green-600'
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight flex items-center gap-2">
            <Users className="h-8 w-8" />
            Team Dashboard
          </h1>
          <p className="text-muted-foreground">
            Manage your team, track progress, and collaborate effectively
          </p>
        </div>

        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1 bg-muted rounded-lg p-1">
            <Button
              variant={viewMode === 'grid' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setViewMode('grid')}
            >
              <Grid3X3 className="h-4 w-4" />
            </Button>
            <Button
              variant={viewMode === 'list' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setViewMode('list')}
            >
              <List className="h-4 w-4" />
            </Button>
            <Button
              variant={viewMode === 'kanban' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setViewMode('kanban')}
            >
              <Kanban className="h-4 w-4" />
            </Button>
          </div>
          
          <Button variant="outline" size="sm">
            <Filter className="h-4 w-4 mr-2" />
            Filter
          </Button>
          
          <Button
            variant="outline"
            size="sm"
            onClick={handleRefresh}
            disabled={loading}
          >
            <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
          
          <Button size="sm" onClick={() => setShowAssignmentDialog(true)}>
            <Plus className="h-4 w-4 mr-2" />
            Assign Task
          </Button>
          
          <Button variant="outline" size="sm">
            <Settings className="h-4 w-4 mr-2" />
            Settings
          </Button>
        </div>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Team Members</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{teamStats.totalMembers}</div>
            <p className="text-xs text-muted-foreground">
              {teamStats.activeMembers} active now
            </p>
            <div className="flex items-center mt-2">
              <div className="flex -space-x-2">
                {teamMembers.slice(0, 4).map((member) => (
                  <Avatar key={member.id} className="h-6 w-6 border-2 border-background">
                    <AvatarFallback className="text-xs">
                      {member.name.split(' ').map(n => n[0]).join('')}
                    </AvatarFallback>
                  </Avatar>
                ))}
              </div>
              {teamMembers.length > 4 && (
                <span className="text-xs text-muted-foreground ml-2">
                  +{teamMembers.length - 4} more
                </span>
              )}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Tasks</CardTitle>
            <CheckCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{teamStats.totalTasks}</div>
            <p className="text-xs text-muted-foreground">
              {teamStats.completedTasks} completed this week
            </p>
            <Progress 
              value={(teamStats.completedTasks / teamStats.totalTasks) * 100} 
              className="mt-2 h-2"
            />
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Pending Approvals</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{teamStats.pendingApprovals}</div>
            <p className="text-xs text-muted-foreground">
              {teamStats.overdueItems} overdue items
            </p>
            {teamStats.overdueItems > 0 && (
              <div className="flex items-center mt-2 text-xs text-red-600">
                <AlertCircle className="h-3 w-3 mr-1" />
                Attention needed
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Team Efficiency</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{teamStats.teamEfficiency}%</div>
            <p className="text-xs text-muted-foreground">
              Average workload: {teamStats.averageWorkload}%
            </p>
            <div className="flex items-center mt-2 text-xs text-green-600">
              <ArrowUpRight className="h-3 w-3 mr-1" />
              +5% from last week
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Main Content */}
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList className="grid w-full grid-cols-5">
          <TabsTrigger value="overview">
            <Activity className="h-4 w-4 mr-2" />
            Overview
          </TabsTrigger>
          <TabsTrigger value="tasks">
            <CheckCircle className="h-4 w-4 mr-2" />
            Tasks
          </TabsTrigger>
          <TabsTrigger value="approvals">
            <Clock className="h-4 w-4 mr-2" />
            Approvals
          </TabsTrigger>
          <TabsTrigger value="workload">
            <BarChart3 className="h-4 w-4 mr-2" />
            Workload
          </TabsTrigger>
          <TabsTrigger value="analytics">
            <Trophy className="h-4 w-4 mr-2" />
            Analytics
          </TabsTrigger>
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Team Status */}
            <div className="lg:col-span-2 space-y-6">
              <Card>
                <CardHeader>
                  <CardTitle>Team Status</CardTitle>
                  <CardDescription>Current availability and workload of team members</CardDescription>
                </CardHeader>
                <CardContent>
                  <TeamMemberStatus members={teamMembers} />
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>Recent Activity</CardTitle>
                  <CardDescription>Latest team activities and updates</CardDescription>
                </CardHeader>
                <CardContent>
                  <TeamActivityFeed />
                </CardContent>
              </Card>
            </div>

            {/* Sidebar */}
            <div className="space-y-6">
              <Card>
                <CardHeader>
                  <CardTitle>Quick Actions</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3">
                  <Button className="w-full justify-start" onClick={() => setShowAssignmentDialog(true)}>
                    <Plus className="h-4 w-4 mr-2" />
                    Assign New Task
                  </Button>
                  <Button variant="outline" className="w-full justify-start">
                    <Calendar className="h-4 w-4 mr-2" />
                    Schedule Meeting
                  </Button>
                  <Button variant="outline" className="w-full justify-start">
                    <Download className="h-4 w-4 mr-2" />
                    Export Report
                  </Button>
                  <Button variant="outline" className="w-full justify-start">
                    <Bell className="h-4 w-4 mr-2" />
                    Send Announcement
                  </Button>
                </CardContent>
              </Card>

              <PendingApprovalsWidget />

              <Card>
                <CardHeader>
                  <CardTitle>Performance Snapshot</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <span className="text-sm">Completion Rate</span>
                      <span className="text-sm font-medium">87%</span>
                    </div>
                    <Progress value={87} className="h-2" />
                    
                    <div className="flex items-center justify-between">
                      <span className="text-sm">Team Satisfaction</span>
                      <span className="text-sm font-medium">92%</span>
                    </div>
                    <Progress value={92} className="h-2" />
                    
                    <div className="flex items-center justify-between">
                      <span className="text-sm">On-time Delivery</span>
                      <span className="text-sm font-medium">94%</span>
                    </div>
                    <Progress value={94} className="h-2" />
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        </TabsContent>

        {/* Tasks Tab */}
        <TabsContent value="tasks" className="space-y-6">
          <AssignedTasksOverview viewMode={viewMode} />
        </TabsContent>

        {/* Approvals Tab */}
        <TabsContent value="approvals" className="space-y-6">
          <PendingApprovalsWidget showAll={true} />
        </TabsContent>

        {/* Workload Tab */}
        <TabsContent value="workload" className="space-y-6">
          <WorkloadVisualization members={teamMembers} />
        </TabsContent>

        {/* Analytics Tab */}
        <TabsContent value="analytics" className="space-y-6">
          <TeamPerformanceMetrics />
        </TabsContent>
      </Tabs>

      {/* Task Assignment Dialog */}
      {showAssignmentDialog && (
        <TaskAssignmentInterface 
          open={showAssignmentDialog}
          onClose={() => setShowAssignmentDialog(false)}
          teamMembers={teamMembers}
        />
      )}
    </div>
  )
}

export default TeamDashboard