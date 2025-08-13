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
  ArrowUpRight,
  ArrowDownRight,
  BarChart3,
  Calendar,
  Clock,
  Download,
  Filter,
  MessageSquare,
  Phone,
  RefreshCw,
  TrendingUp,
  TrendingDown,
  Users,
  Video,
  Mail,
  FileText,
  Share2,
  Activity,
  Zap,
  Target,
  Globe,
  Coffee,
  AlertCircle,
  CheckCircle,
  Timer
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
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar,
  ScatterChart,
  Scatter
} from 'recharts'

interface CollaborationChannel {
  id: string
  name: string
  icon: React.ReactNode
  totalInteractions: number
  averageResponseTime: number
  engagementRate: number
  trend: 'up' | 'down' | 'stable'
  peakHours: string[]
}

interface TeamMemberInteraction {
  id: string
  name: string
  role: string
  totalInteractions: number
  byChannel: {
    messages: number
    calls: number
    meetings: number
    documents: number
    emails: number
  }
  responseTime: number
  initiationRate: number
  collaborationIndex: number
}

interface InteractionPattern {
  timeSlot: string
  messages: number
  calls: number
  meetings: number
  emails: number
  documents: number
  totalInteractions: number
}

interface CrossTeamCollaboration {
  teamA: string
  teamB: string
  interactions: number
  frequency: number
  primaryChannels: string[]
  projectsShared: number
  collaborationStrength: 'weak' | 'moderate' | 'strong'
}

const mockCollaborationChannels: CollaborationChannel[] = [
  {
    id: '1',
    name: 'Direct Messages',
    icon: <MessageSquare className="h-4 w-4" />,
    totalInteractions: 2847,
    averageResponseTime: 1.2,
    engagementRate: 94,
    trend: 'up',
    peakHours: ['9AM', '11AM', '2PM', '4PM']
  },
  {
    id: '2',
    name: 'Video Calls',
    icon: <Video className="h-4 w-4" />,
    totalInteractions: 456,
    averageResponseTime: 15.3,
    engagementRate: 87,
    trend: 'up',
    peakHours: ['10AM', '2PM', '3PM']
  },
  {
    id: '3',
    name: 'Voice Calls',
    icon: <Phone className="h-4 w-4" />,
    totalInteractions: 234,
    averageResponseTime: 8.7,
    engagementRate: 79,
    trend: 'down',
    peakHours: ['11AM', '3PM']
  },
  {
    id: '4',
    name: 'Email',
    icon: <Mail className="h-4 w-4" />,
    totalInteractions: 1289,
    averageResponseTime: 4.6,
    engagementRate: 68,
    trend: 'down',
    peakHours: ['9AM', '1PM']
  },
  {
    id: '5',
    name: 'Document Sharing',
    icon: <FileText className="h-4 w-4" />,
    totalInteractions: 892,
    averageResponseTime: 6.2,
    engagementRate: 82,
    trend: 'up',
    peakHours: ['10AM', '2PM', '4PM']
  },
  {
    id: '6',
    name: 'Team Meetings',
    icon: <Users className="h-4 w-4" />,
    totalInteractions: 167,
    averageResponseTime: 120.0,
    engagementRate: 91,
    trend: 'stable',
    peakHours: ['10AM', '2PM']
  }
]

const mockTeamInteractions: TeamMemberInteraction[] = [
  {
    id: '1',
    name: 'John Doe',
    role: 'Marketing Manager',
    totalInteractions: 1247,
    byChannel: {
      messages: 456,
      calls: 67,
      meetings: 89,
      documents: 234,
      emails: 401
    },
    responseTime: 2.1,
    initiationRate: 68,
    collaborationIndex: 92
  },
  {
    id: '2',
    name: 'Sarah Wilson',
    role: 'Content Creator',
    totalInteractions: 1589,
    byChannel: {
      messages: 612,
      calls: 43,
      meetings: 78,
      documents: 387,
      emails: 469
    },
    responseTime: 1.3,
    initiationRate: 74,
    collaborationIndex: 96
  },
  {
    id: '3',
    name: 'Mike Johnson',
    role: 'Designer',
    totalInteractions: 967,
    byChannel: {
      messages: 345,
      calls: 56,
      meetings: 67,
      documents: 289,
      emails: 210
    },
    responseTime: 3.2,
    initiationRate: 52,
    collaborationIndex: 84
  },
  {
    id: '4',
    name: 'Lisa Brown',
    role: 'Marketing Director',
    totalInteractions: 1834,
    byChannel: {
      messages: 523,
      calls: 124,
      meetings: 156,
      documents: 367,
      emails: 664
    },
    responseTime: 1.8,
    initiationRate: 81,
    collaborationIndex: 94
  },
  {
    id: '5',
    name: 'David Lee',
    role: 'Copywriter',
    totalInteractions: 1123,
    byChannel: {
      messages: 423,
      calls: 34,
      meetings: 89,
      documents: 345,
      emails: 232
    },
    responseTime: 2.5,
    initiationRate: 59,
    collaborationIndex: 88
  }
]

const mockInteractionPatterns: InteractionPattern[] = [
  { timeSlot: '8AM', messages: 45, calls: 2, meetings: 0, emails: 23, documents: 8, totalInteractions: 78 },
  { timeSlot: '9AM', messages: 78, calls: 8, meetings: 12, emails: 45, documents: 23, totalInteractions: 166 },
  { timeSlot: '10AM', messages: 89, calls: 15, meetings: 23, emails: 34, documents: 32, totalInteractions: 193 },
  { timeSlot: '11AM', messages: 94, calls: 18, meetings: 15, emails: 28, documents: 29, totalInteractions: 184 },
  { timeSlot: '12PM', messages: 56, calls: 6, meetings: 8, emails: 19, documents: 12, totalInteractions: 101 },
  { timeSlot: '1PM', messages: 67, calls: 9, meetings: 18, emails: 32, documents: 21, totalInteractions: 147 },
  { timeSlot: '2PM', messages: 82, calls: 12, meetings: 21, emails: 26, documents: 34, totalInteractions: 175 },
  { timeSlot: '3PM', messages: 76, calls: 14, meetings: 16, emails: 22, documents: 28, totalInteractions: 156 },
  { timeSlot: '4PM', messages: 69, calls: 11, meetings: 9, emails: 18, documents: 25, totalInteractions: 132 },
  { timeSlot: '5PM', messages: 41, calls: 5, meetings: 3, emails: 12, documents: 15, totalInteractions: 76 },
  { timeSlot: '6PM', messages: 23, calls: 2, meetings: 1, emails: 8, documents: 6, totalInteractions: 40 }
]

const mockCrossTeamCollaboration: CrossTeamCollaboration[] = [
  {
    teamA: 'Marketing',
    teamB: 'Design',
    interactions: 456,
    frequency: 8.2,
    primaryChannels: ['Messages', 'Documents', 'Meetings'],
    projectsShared: 12,
    collaborationStrength: 'strong'
  },
  {
    teamA: 'Marketing',
    teamB: 'Sales',
    interactions: 234,
    frequency: 4.1,
    primaryChannels: ['Email', 'Meetings'],
    projectsShared: 6,
    collaborationStrength: 'moderate'
  },
  {
    teamA: 'Marketing',
    teamB: 'Product',
    interactions: 189,
    frequency: 3.4,
    primaryChannels: ['Messages', 'Documents'],
    projectsShared: 4,
    collaborationStrength: 'moderate'
  },
  {
    teamA: 'Marketing',
    teamB: 'Engineering',
    interactions: 87,
    frequency: 1.6,
    primaryChannels: ['Email', 'Messages'],
    projectsShared: 2,
    collaborationStrength: 'weak'
  }
]

const collaborationFrequencyTrends = [
  { month: 'Jan', daily: 156, weekly: 189, monthly: 234 },
  { month: 'Feb', daily: 167, weekly: 201, monthly: 256 },
  { month: 'Mar', daily: 178, weekly: 213, monthly: 278 },
  { month: 'Apr', daily: 172, weekly: 198, monthly: 267 },
  { month: 'May', daily: 185, weekly: 224, monthly: 289 },
  { month: 'Jun', daily: 194, weekly: 238, monthly: 301 }
]

const channelEffectivenessData = mockCollaborationChannels.map(channel => ({
  name: channel.name.split(' ')[0],
  interactions: channel.totalInteractions,
  responseTime: channel.averageResponseTime,
  engagement: channel.engagementRate,
  efficiency: Math.round((channel.engagementRate / channel.averageResponseTime) * 10)
}))

const collaborationNetworkData = mockTeamInteractions.map(member => ({
  name: member.name.split(' ')[0],
  outgoing: member.initiationRate,
  incoming: 100 - member.initiationRate,
  totalInteractions: member.totalInteractions,
  responseTime: member.responseTime
}))

const interactionVolumeData = [
  { type: 'High Volume', count: 2, members: ['Sarah', 'Lisa'] },
  { type: 'Medium Volume', count: 2, members: ['John', 'David'] },
  { type: 'Low Volume', count: 1, members: ['Mike'] }
]

export const CollaborationFrequency: React.FC = () => {
  const [timeRange, setTimeRange] = useState<'day' | 'week' | 'month' | 'quarter'>('week')
  const [selectedChannel, setSelectedChannel] = useState<string>('all')
  const [viewType, setViewType] = useState<'patterns' | 'channels' | 'network' | 'insights'>('patterns')

  const getTrendIcon = (trend: string) => {
    switch (trend) {
      case 'up':
        return <ArrowUpRight className="h-4 w-4 text-green-600" />
      case 'down':
        return <ArrowDownRight className="h-4 w-4 text-red-600" />
      default:
        return <TrendingUp className="h-4 w-4 text-gray-600" />
    }
  }

  const getTrendColor = (trend: string) => {
    switch (trend) {
      case 'up':
        return 'text-green-600'
      case 'down':
        return 'text-red-600'
      default:
        return 'text-gray-600'
    }
  }

  const getCollaborationStrengthBadge = (strength: string) => {
    switch (strength) {
      case 'strong':
        return { variant: 'default' as const, label: 'Strong', color: 'text-green-600', bg: 'bg-green-100' }
      case 'moderate':
        return { variant: 'secondary' as const, label: 'Moderate', color: 'text-yellow-600', bg: 'bg-yellow-100' }
      case 'weak':
        return { variant: 'outline' as const, label: 'Weak', color: 'text-red-600', bg: 'bg-red-100' }
      default:
        return { variant: 'outline' as const, label: 'Unknown', color: 'text-gray-600', bg: 'bg-gray-100' }
    }
  }

  const getResponseTimeBadge = (time: number) => {
    if (time <= 2) return { color: 'text-green-600', label: 'Excellent' }
    if (time <= 4) return { color: 'text-yellow-600', label: 'Good' }
    if (time <= 8) return { color: 'text-orange-600', label: 'Average' }
    return { color: 'text-red-600', label: 'Needs Improvement' }
  }

  const totalInteractions = mockCollaborationChannels.reduce((sum, channel) => sum + channel.totalInteractions, 0)
  const averageResponseTime = mockCollaborationChannels.reduce((sum, channel) => sum + channel.averageResponseTime, 0) / mockCollaborationChannels.length
  const overallEngagement = mockCollaborationChannels.reduce((sum, channel) => sum + channel.engagementRate, 0) / mockCollaborationChannels.length

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight flex items-center gap-2">
            <Activity className="h-8 w-8" />
            Collaboration Frequency
          </h1>
          <p className="text-muted-foreground">
            Analyze communication patterns, channel usage, and interaction frequencies
          </p>
        </div>
        
        <div className="flex items-center gap-2">
          <Select value={timeRange} onValueChange={(value: any) => setTimeRange(value)}>
            <SelectTrigger className="w-[120px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="day">Today</SelectItem>
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

      {/* Overview Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Interactions</CardTitle>
            <Share2 className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{totalInteractions.toLocaleString()}</div>
            <p className="text-xs text-green-600">
              +15% from last {timeRange}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg Response Time</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{averageResponseTime.toFixed(1)}h</div>
            <p className="text-xs text-green-600">
              -8% from last {timeRange}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Engagement Rate</CardTitle>
            <Target className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{Math.round(overallEngagement)}%</div>
            <p className="text-xs text-blue-600">
              +3% from last {timeRange}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Channels</CardTitle>
            <Globe className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{mockCollaborationChannels.length}</div>
            <p className="text-xs text-muted-foreground">
              6 communication channels
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Main Content Tabs */}
      <Tabs value={viewType} onValueChange={(value: any) => setViewType(value)}>
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="patterns">
            <BarChart3 className="h-4 w-4 mr-2" />
            Patterns
          </TabsTrigger>
          <TabsTrigger value="channels">
            <MessageSquare className="h-4 w-4 mr-2" />
            Channels
          </TabsTrigger>
          <TabsTrigger value="network">
            <Users className="h-4 w-4 mr-2" />
            Network
          </TabsTrigger>
          <TabsTrigger value="insights">
            <Zap className="h-4 w-4 mr-2" />
            Insights
          </TabsTrigger>
        </TabsList>

        {/* Patterns Tab */}
        <TabsContent value="patterns" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Daily Interaction Patterns */}
            <Card>
              <CardHeader>
                <CardTitle>Daily Interaction Patterns</CardTitle>
                <CardDescription>Communication volume throughout the day</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={mockInteractionPatterns}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="timeSlot" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Area type="monotone" dataKey="messages" stackId="1" stroke="#3b82f6" fill="#3b82f6" fillOpacity={0.3} name="Messages" />
                    <Area type="monotone" dataKey="meetings" stackId="1" stroke="#10b981" fill="#10b981" fillOpacity={0.3} name="Meetings" />
                    <Area type="monotone" dataKey="calls" stackId="1" stroke="#f59e0b" fill="#f59e0b" fillOpacity={0.3} name="Calls" />
                    <Area type="monotone" dataKey="documents" stackId="1" stroke="#8b5cf6" fill="#8b5cf6" fillOpacity={0.3} name="Documents" />
                    <Area type="monotone" dataKey="emails" stackId="1" stroke="#ef4444" fill="#ef4444" fillOpacity={0.3} name="Emails" />
                  </AreaChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Collaboration Frequency Trends */}
            <Card>
              <CardHeader>
                <CardTitle>Frequency Trends</CardTitle>
                <CardDescription>Interaction frequency over time</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <LineChart data={collaborationFrequencyTrends}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="month" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Line type="monotone" dataKey="daily" stroke="#3b82f6" name="Daily Avg" />
                    <Line type="monotone" dataKey="weekly" stroke="#10b981" name="Weekly Avg" />
                    <Line type="monotone" dataKey="monthly" stroke="#f59e0b" name="Monthly Total" />
                  </LineChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Peak Activity Heatmap */}
          <Card>
            <CardHeader>
              <CardTitle>Peak Activity Analysis</CardTitle>
              <CardDescription>High-activity time slots and optimal collaboration windows</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {/* Peak Hours Summary */}
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div className="text-center p-4 bg-blue-50 rounded-lg">
                    <div className="text-lg font-bold text-blue-900">10AM - 11AM</div>
                    <div className="text-sm text-blue-700">Peak Messaging</div>
                    <div className="text-xs text-blue-600">193 interactions/hour</div>
                  </div>
                  <div className="text-center p-4 bg-green-50 rounded-lg">
                    <div className="text-lg font-bold text-green-900">2PM - 3PM</div>
                    <div className="text-sm text-green-700">Meeting Prime Time</div>
                    <div className="text-xs text-green-600">21 meetings/hour</div>
                  </div>
                  <div className="text-center p-4 bg-yellow-50 rounded-lg">
                    <div className="text-lg font-bold text-yellow-900">9AM - 10AM</div>
                    <div className="text-sm text-yellow-700">Email Rush</div>
                    <div className="text-xs text-yellow-600">45 emails/hour</div>
                  </div>
                  <div className="text-center p-4 bg-purple-50 rounded-lg">
                    <div className="text-lg font-bold text-purple-900">2PM - 4PM</div>
                    <div className="text-sm text-purple-700">Document Sharing</div>
                    <div className="text-xs text-purple-600">34 docs/hour</div>
                  </div>
                </div>

                {/* Hourly Breakdown Chart */}
                <ResponsiveContainer width="100%" height={200}>
                  <BarChart data={mockInteractionPatterns}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="timeSlot" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="totalInteractions" fill="#8884d8" name="Total Interactions" />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Channels Tab */}
        <TabsContent value="channels" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Channel Effectiveness */}
            <Card>
              <CardHeader>
                <CardTitle>Channel Effectiveness</CardTitle>
                <CardDescription>Performance metrics for each communication channel</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={channelEffectivenessData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="engagement" fill="#3b82f6" name="Engagement %" />
                    <Bar dataKey="efficiency" fill="#10b981" name="Efficiency Score" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Response Time Comparison */}
            <Card>
              <CardHeader>
                <CardTitle>Response Time Analysis</CardTitle>
                <CardDescription>Average response times across channels</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={channelEffectivenessData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="responseTime" fill="#f59e0b" name="Response Time (hours)" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Channel Details */}
          <Card>
            <CardHeader>
              <CardTitle>Channel Performance Details</CardTitle>
              <CardDescription>Comprehensive analysis of each communication channel</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {mockCollaborationChannels.map(channel => (
                  <div key={channel.id} className="flex items-center gap-4 p-4 border rounded-lg">
                    <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
                      {channel.icon}
                    </div>
                    
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-2">
                        <h4 className="font-medium">{channel.name}</h4>
                        {getTrendIcon(channel.trend)}
                        <Badge variant="outline" className={getTrendColor(channel.trend)}>
                          {channel.trend === 'up' ? 'Growing' : channel.trend === 'down' ? 'Declining' : 'Stable'}
                        </Badge>
                      </div>
                      
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                        <div>
                          <div className="text-muted-foreground">Total Interactions</div>
                          <div className="font-bold text-lg">{channel.totalInteractions.toLocaleString()}</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Avg Response Time</div>
                          <div className={`font-bold text-lg ${getResponseTimeBadge(channel.averageResponseTime).color}`}>
                            {channel.averageResponseTime < 1 ? 
                              `${(channel.averageResponseTime * 60).toFixed(0)}m` : 
                              `${channel.averageResponseTime.toFixed(1)}h`
                            }
                          </div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Engagement Rate</div>
                          <div className={`font-bold text-lg ${channel.engagementRate >= 85 ? 'text-green-600' : channel.engagementRate >= 70 ? 'text-yellow-600' : 'text-red-600'}`}>
                            {channel.engagementRate}%
                          </div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Peak Hours</div>
                          <div className="flex flex-wrap gap-1">
                            {channel.peakHours.slice(0, 2).map(hour => (
                              <Badge key={hour} variant="secondary" className="text-xs">
                                {hour}
                              </Badge>
                            ))}
                            {channel.peakHours.length > 2 && (
                              <Badge variant="outline" className="text-xs">
                                +{channel.peakHours.length - 2}
                              </Badge>
                            )}
                          </div>
                        </div>
                      </div>
                      
                      <div className="mt-3">
                        <Progress value={channel.engagementRate} className="h-2" />
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

        {/* Network Tab */}
        <TabsContent value="network" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Collaboration Network */}
            <Card>
              <CardHeader>
                <CardTitle>Team Interaction Network</CardTitle>
                <CardDescription>Individual collaboration patterns and volumes</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <ScatterChart data={collaborationNetworkData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="outgoing" name="Initiation Rate" />
                    <YAxis dataKey="totalInteractions" name="Total Interactions" />
                    <Tooltip 
                      cursor={{ strokeDasharray: '3 3' }}
                      formatter={(value, name) => [
                        name === 'totalInteractions' ? `${value} interactions` : `${value}%`,
                        name === 'totalInteractions' ? 'Total Interactions' : 'Initiation Rate'
                      ]}
                      labelFormatter={(value) => `${collaborationNetworkData.find(d => d.outgoing === value)?.name || 'Member'}`}
                    />
                    <Scatter dataKey="totalInteractions" fill="#8884d8" />
                  </ScatterChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Interaction Volume Distribution */}
            <Card>
              <CardHeader>
                <CardTitle>Interaction Volume Distribution</CardTitle>
                <CardDescription>Team member interaction frequency categories</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={interactionVolumeData}
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      dataKey="count"
                      label={({ name, count }) => `${name}: ${count}`}
                    >
                      <Cell fill="#3b82f6" />
                      <Cell fill="#10b981" />
                      <Cell fill="#f59e0b" />
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Individual Team Member Analysis */}
          <Card>
            <CardHeader>
              <CardTitle>Team Member Analysis</CardTitle>
              <CardDescription>Individual collaboration metrics and communication preferences</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {mockTeamInteractions.map(member => (
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
                        <div className={`text-sm font-medium ${member.collaborationIndex >= 90 ? 'text-green-600' : member.collaborationIndex >= 80 ? 'text-yellow-600' : 'text-red-600'}`}>
                          {member.collaborationIndex} Index
                        </div>
                      </div>
                      
                      <div className="grid grid-cols-2 md:grid-cols-5 gap-4 text-sm">
                        <div>
                          <div className="text-muted-foreground">Total</div>
                          <div className="font-medium">{member.totalInteractions}</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Messages</div>
                          <div className="font-medium flex items-center gap-1">
                            <MessageSquare className="h-3 w-3" />
                            {member.byChannel.messages}
                          </div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Meetings</div>
                          <div className="font-medium flex items-center gap-1">
                            <Users className="h-3 w-3" />
                            {member.byChannel.meetings}
                          </div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Documents</div>
                          <div className="font-medium flex items-center gap-1">
                            <FileText className="h-3 w-3" />
                            {member.byChannel.documents}
                          </div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Response Time</div>
                          <div className={`font-medium ${getResponseTimeBadge(member.responseTime).color}`}>
                            {member.responseTime.toFixed(1)}h
                          </div>
                        </div>
                      </div>
                      
                      <div className="mt-3 grid grid-cols-2 gap-4">
                        <div>
                          <div className="text-xs text-muted-foreground mb-1">Initiation Rate</div>
                          <Progress value={member.initiationRate} className="h-2" />
                          <div className="text-xs text-muted-foreground mt-1">{member.initiationRate}% self-initiated</div>
                        </div>
                        <div>
                          <div className="text-xs text-muted-foreground mb-1">Collaboration Index</div>
                          <Progress value={member.collaborationIndex} className="h-2" />
                          <div className="text-xs text-muted-foreground mt-1">{member.collaborationIndex}/100 score</div>
                        </div>
                      </div>
                    </div>
                    
                    <div className="text-right">
                      <Button variant="outline" size="sm">
                        View Profile
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          {/* Cross-Team Collaboration */}
          <Card>
            <CardHeader>
              <CardTitle>Cross-Team Collaboration</CardTitle>
              <CardDescription>Inter-department collaboration strength and patterns</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {mockCrossTeamCollaboration.map((collab, index) => {
                  const strengthBadge = getCollaborationStrengthBadge(collab.collaborationStrength)
                  return (
                    <div key={index} className="flex items-center gap-4 p-4 border rounded-lg">
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center text-xs font-bold text-blue-700">
                          {collab.teamA[0]}
                        </div>
                        <Share2 className="h-4 w-4 text-muted-foreground" />
                        <div className="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center text-xs font-bold text-green-700">
                          {collab.teamB[0]}
                        </div>
                      </div>
                      
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-2">
                          <span className="font-medium">{collab.teamA} ↔ {collab.teamB}</span>
                          <Badge variant={strengthBadge.variant} className={`${strengthBadge.bg} ${strengthBadge.color}`}>
                            {strengthBadge.label}
                          </Badge>
                        </div>
                        
                        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                          <div>
                            <div className="text-muted-foreground">Interactions</div>
                            <div className="font-medium">{collab.interactions}/month</div>
                          </div>
                          <div>
                            <div className="text-muted-foreground">Frequency</div>
                            <div className="font-medium">{collab.frequency}/week</div>
                          </div>
                          <div>
                            <div className="text-muted-foreground">Shared Projects</div>
                            <div className="font-medium">{collab.projectsShared}</div>
                          </div>
                          <div>
                            <div className="text-muted-foreground">Top Channels</div>
                            <div className="flex flex-wrap gap-1">
                              {collab.primaryChannels.slice(0, 2).map(channel => (
                                <Badge key={channel} variant="outline" className="text-xs">
                                  {channel}
                                </Badge>
                              ))}
                            </div>
                          </div>
                        </div>
                      </div>
                      
                      <div className="text-right">
                        <Button 
                          variant={collab.collaborationStrength === 'weak' ? 'destructive' : 'outline'} 
                          size="sm"
                        >
                          {collab.collaborationStrength === 'weak' ? 'Improve' : 'Maintain'}
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
              <CardTitle>Collaboration Frequency Insights</CardTitle>
              <CardDescription>AI-powered analysis of communication patterns and optimization opportunities</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-start gap-3 p-4 bg-green-50 rounded-lg">
                  <TrendingUp className="h-5 w-5 text-green-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-green-900">Peak Collaboration Identified</h4>
                    <p className="text-sm text-green-700">
                      Team collaboration peaks between 10-11 AM with 193 interactions per hour. This is the optimal 
                      time for important discussions and decision-making sessions.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                  <MessageSquare className="h-5 w-5 text-blue-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-blue-900">Channel Optimization Opportunity</h4>
                    <p className="text-sm text-blue-700">
                      Direct messages show the highest engagement (94%) and fastest response times (1.2h). Consider 
                      encouraging more direct communication for urgent matters.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-yellow-50 rounded-lg">
                  <AlertCircle className="h-5 w-5 text-yellow-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-yellow-900">Response Time Inconsistency</h4>
                    <p className="text-sm text-yellow-700">
                      Email response times average 4.6 hours with declining engagement. Consider setting clearer 
                      response time expectations or migrating to faster channels for urgent communications.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-purple-50 rounded-lg">
                  <Users className="h-5 w-5 text-purple-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-purple-900">Collaboration Leader</h4>
                    <p className="text-sm text-purple-700">
                      Sarah Wilson leads in collaboration frequency (1,589 interactions) with excellent response times. 
                      Consider leveraging her communication patterns as a team best practice.
                    </p>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Optimization Recommendations */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <Card>
              <CardHeader>
                <CardTitle>Optimization Recommendations</CardTitle>
                <CardDescription>Actionable steps to improve collaboration frequency</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 rounded-full bg-green-600 mt-2"></div>
                  <div>
                    <h4 className="font-medium">Establish Peak Hour Protocols</h4>
                    <p className="text-sm text-muted-foreground">
                      Schedule important discussions during 10-11 AM peak hours
                    </p>
                  </div>
                </div>
                
                <Separator />
                
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 rounded-full bg-blue-600 mt-2"></div>
                  <div>
                    <h4 className="font-medium">Channel Migration Strategy</h4>
                    <p className="text-sm text-muted-foreground">
                      Migrate urgent communications from email to direct messages
                    </p>
                  </div>
                </div>
                
                <Separator />
                
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 rounded-full bg-purple-600 mt-2"></div>
                  <div>
                    <h4 className="font-medium">Response Time Standards</h4>
                    <p className="text-sm text-muted-foreground">
                      Implement SLA targets: 2h for messages, 4h for emails
                    </p>
                  </div>
                </div>
                
                <Separator />
                
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 rounded-full bg-orange-600 mt-2"></div>
                  <div>
                    <h4 className="font-medium">Cross-Team Initiatives</h4>
                    <p className="text-sm text-muted-foreground">
                      Strengthen weak collaborations with structured touchpoints
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Frequency Targets</CardTitle>
                <CardDescription>Goals to track collaboration improvement</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Daily Interaction Average</span>
                    <span className="font-medium">194 → Target: 220</span>
                  </div>
                  <Progress value={88} className="h-2" />
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Average Response Time</span>
                    <span className="font-medium">25.0h → Target: 3.0h</span>
                  </div>
                  <Progress value={12} className="h-2 bg-red-100 [&>div]:bg-red-500" />
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Cross-Team Collaboration</span>
                    <span className="font-medium">3.1/week → Target: 5.0/week</span>
                  </div>
                  <Progress value={62} className="h-2" />
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Channel Engagement</span>
                    <span className="font-medium">84% → Target: 90%</span>
                  </div>
                  <Progress value={93} className="h-2" />
                </div>
                
                <Separator />
                
                <div className="bg-muted/50 p-3 rounded-lg">
                  <div className="text-sm font-medium mb-1">Collaboration Health Score</div>
                  <div className="text-2xl font-bold text-green-600">82%</div>
                  <div className="text-xs text-muted-foreground">
                    Good collaboration patterns with optimization potential
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

export default CollaborationFrequency