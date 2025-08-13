'use client'

import React, { useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import {
  Trophy,
  TrendingUp,
  TrendingDown,
  Target,
  Clock,
  CheckCircle,
  BarChart3,
  Activity,
  Award,
  Star,
  Zap,
  Calendar,
  Users,
  Gauge,
  ArrowUpRight,
  ArrowDownRight,
  Download,
  RefreshCw,
  Settings,
  Filter,
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
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar
} from 'recharts'

interface PerformanceMetric {
  id: string
  name: string
  value: number
  previousValue: number
  target: number
  unit: string
  trend: 'up' | 'down' | 'stable'
  category: 'productivity' | 'quality' | 'collaboration' | 'efficiency'
}

interface TeamMemberPerformance {
  id: string
  name: string
  avatar?: string
  role: string
  metrics: {
    tasksCompleted: number
    averageTaskTime: number
    qualityScore: number
    collaborationScore: number
    efficiency: number
    onTimeDelivery: number
  }
  achievements: string[]
  totalPoints: number
}

const mockMetrics: PerformanceMetric[] = [
  {
    id: '1',
    name: 'Tasks Completed',
    value: 247,
    previousValue: 230,
    target: 250,
    unit: 'tasks',
    trend: 'up',
    category: 'productivity'
  },
  {
    id: '2',
    name: 'Average Task Time',
    value: 3.2,
    previousValue: 3.8,
    target: 3.0,
    unit: 'hours',
    trend: 'up',
    category: 'efficiency'
  },
  {
    id: '3',
    name: 'Quality Score',
    value: 92,
    previousValue: 88,
    target: 90,
    unit: '%',
    trend: 'up',
    category: 'quality'
  },
  {
    id: '4',
    name: 'On-Time Delivery',
    value: 94,
    previousValue: 91,
    target: 95,
    unit: '%',
    trend: 'up',
    category: 'efficiency'
  },
  {
    id: '5',
    name: 'Team Satisfaction',
    value: 4.6,
    previousValue: 4.4,
    target: 4.5,
    unit: '/5',
    trend: 'up',
    category: 'collaboration'
  },
  {
    id: '6',
    name: 'Rework Rate',
    value: 8,
    previousValue: 12,
    target: 10,
    unit: '%',
    trend: 'up',
    category: 'quality'
  }
]

const mockTeamPerformance: TeamMemberPerformance[] = [
  {
    id: '1',
    name: 'John Doe',
    role: 'Marketing Manager',
    metrics: {
      tasksCompleted: 52,
      averageTaskTime: 2.8,
      qualityScore: 95,
      collaborationScore: 88,
      efficiency: 92,
      onTimeDelivery: 96
    },
    achievements: ['Quality Champion', 'Team Player', 'Efficiency Expert'],
    totalPoints: 1247
  },
  {
    id: '2',
    name: 'Sarah Wilson',
    role: 'Content Creator',
    metrics: {
      tasksCompleted: 48,
      averageTaskTime: 3.1,
      qualityScore: 98,
      collaborationScore: 92,
      efficiency: 89,
      onTimeDelivery: 94
    },
    achievements: ['Content Master', 'Quality Champion', 'Innovation Award'],
    totalPoints: 1156
  },
  {
    id: '3',
    name: 'Mike Johnson',
    role: 'Designer',
    metrics: {
      tasksCompleted: 45,
      averageTaskTime: 3.5,
      qualityScore: 96,
      collaborationScore: 85,
      efficiency: 87,
      onTimeDelivery: 92
    },
    achievements: ['Design Excellence', 'Creative Thinker'],
    totalPoints: 1089
  },
  {
    id: '4',
    name: 'Lisa Brown',
    role: 'Marketing Director',
    metrics: {
      tasksCompleted: 38,
      averageTaskTime: 4.2,
      qualityScore: 94,
      collaborationScore: 96,
      efficiency: 85,
      onTimeDelivery: 98
    },
    achievements: ['Leadership Excellence', 'Mentor', 'Strategic Thinker'],
    totalPoints: 1203
  },
  {
    id: '5',
    name: 'David Lee',
    role: 'Copywriter',
    metrics: {
      tasksCompleted: 56,
      averageTaskTime: 2.5,
      qualityScore: 93,
      collaborationScore: 87,
      efficiency: 94,
      onTimeDelivery: 95
    },
    achievements: ['Speed Demon', 'Quality Champion', 'Team Player'],
    totalPoints: 1178
  }
]

const performanceData = [
  { month: 'Jan', productivity: 85, quality: 88, collaboration: 82, efficiency: 87 },
  { month: 'Feb', productivity: 87, quality: 90, collaboration: 85, efficiency: 89 },
  { month: 'Mar', productivity: 89, quality: 92, collaboration: 88, efficiency: 91 },
  { month: 'Apr', productivity: 91, quality: 94, collaboration: 90, efficiency: 93 },
  { month: 'May', productivity: 88, quality: 93, collaboration: 92, efficiency: 90 },
  { month: 'Jun', productivity: 92, quality: 95, collaboration: 94, efficiency: 94 }
]

const radarData = [
  { metric: 'Productivity', value: 92, fullMark: 100 },
  { metric: 'Quality', value: 95, fullMark: 100 },
  { metric: 'Collaboration', value: 88, fullMark: 100 },
  { metric: 'Efficiency', value: 91, fullMark: 100 },
  { metric: 'Innovation', value: 85, fullMark: 100 },
  { metric: 'Communication', value: 90, fullMark: 100 }
]

const achievementBadges = [
  { name: 'Quality Champion', icon: '🏆', description: '95%+ quality score for 3 months' },
  { name: 'Speed Demon', icon: '⚡', description: 'Top 10% in task completion speed' },
  { name: 'Team Player', icon: '🤝', description: 'High collaboration scores' },
  { name: 'Innovation Award', icon: '💡', description: 'Implemented innovative solutions' },
  { name: 'Mentor', icon: '🎓', description: 'Helped onboard team members' },
  { name: 'Efficiency Expert', icon: '⚙️', description: 'Improved team processes' },
  { name: 'Design Excellence', icon: '🎨', description: 'Outstanding design quality' },
  { name: 'Content Master', icon: '✍️', description: 'Exceptional content creation' },
  { name: 'Leadership Excellence', icon: '👑', description: 'Outstanding leadership skills' },
  { name: 'Strategic Thinker', icon: '🧠', description: 'Strategic planning excellence' },
  { name: 'Creative Thinker', icon: '🌟', description: 'Creative problem solving' }
]

export const TeamPerformanceMetrics: React.FC = () => {
  const [timeRange, setTimeRange] = useState<'week' | 'month' | 'quarter' | 'year'>('month')
  const [selectedCategory, setSelectedCategory] = useState<string>('all')
  const [viewType, setViewType] = useState<'overview' | 'individual' | 'trends'>('overview')

  const getTrendIcon = (trend: string, value: number, target: number) => {
    if (trend === 'up') {
      return value >= target ? 
        <ArrowUpRight className="h-4 w-4 text-green-600" /> : 
        <ArrowUpRight className="h-4 w-4 text-blue-600" />
    }
    if (trend === 'down') {
      return <ArrowDownRight className="h-4 w-4 text-red-600" />
    }
    return <TrendingFlat className="h-4 w-4 text-gray-600" />
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

  const getPerformanceColor = (score: number) => {
    if (score >= 95) return 'text-green-600'
    if (score >= 85) return 'text-blue-600'
    if (score >= 75) return 'text-yellow-600'
    return 'text-red-600'
  }

  const getBadgeForScore = (score: number) => {
    if (score >= 95) return { variant: 'default' as const, label: 'Excellent' }
    if (score >= 85) return { variant: 'secondary' as const, label: 'Good' }
    if (score >= 75) return { variant: 'outline' as const, label: 'Average' }
    return { variant: 'destructive' as const, label: 'Needs Improvement' }
  }

  return (
    <div className="space-y-6">
      {/* Header Controls */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">Performance Analytics</h2>
          <p className="text-muted-foreground">
            Track team performance metrics and individual achievements
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
        {mockMetrics.map(metric => {
          const changePercent = Math.round(((metric.value - metric.previousValue) / metric.previousValue) * 100)
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
        <TabsList>
          <TabsTrigger value="overview">
            <BarChart3 className="h-4 w-4 mr-2" />
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
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Performance Radar Chart */}
            <Card>
              <CardHeader>
                <CardTitle>Team Performance Radar</CardTitle>
                <CardDescription>Overall team performance across key metrics</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <RadarChart data={radarData}>
                    <PolarGrid />
                    <PolarAngleAxis dataKey="metric" />
                    <PolarRadiusAxis angle={90} domain={[0, 100]} />
                    <Radar
                      name="Performance"
                      dataKey="value"
                      stroke="#8884d8"
                      fill="#8884d8"
                      fillOpacity={0.3}
                    />
                  </RadarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Performance Trends */}
            <Card>
              <CardHeader>
                <CardTitle>Performance Trends</CardTitle>
                <CardDescription>Monthly performance across all categories</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <LineChart data={performanceData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="month" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Line type="monotone" dataKey="productivity" stroke="#8884d8" name="Productivity" />
                    <Line type="monotone" dataKey="quality" stroke="#82ca9d" name="Quality" />
                    <Line type="monotone" dataKey="collaboration" stroke="#ffc658" name="Collaboration" />
                    <Line type="monotone" dataKey="efficiency" stroke="#ff7c7c" name="Efficiency" />
                  </LineChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Achievement Gallery */}
          <Card>
            <CardHeader>
              <CardTitle>Achievement Gallery</CardTitle>
              <CardDescription>Recognition badges and achievements</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
                {achievementBadges.map(badge => (
                  <div key={badge.name} className="text-center p-3 border rounded-lg hover:bg-muted/50 transition-colors">
                    <div className="text-2xl mb-2">{badge.icon}</div>
                    <div className="font-medium text-sm">{badge.name}</div>
                    <div className="text-xs text-muted-foreground mt-1">{badge.description}</div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Individual Tab */}
        <TabsContent value="individual" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {mockTeamPerformance.map(member => (
              <Card key={member.id}>
                <CardHeader>
                  <div className="flex items-center gap-3">
                    <Avatar className="h-10 w-10">
                      <AvatarFallback>
                        {member.name.split(' ').map(n => n[0]).join('')}
                      </AvatarFallback>
                    </Avatar>
                    <div>
                      <CardTitle className="text-lg">{member.name}</CardTitle>
                      <CardDescription>{member.role}</CardDescription>
                    </div>
                    <div className="ml-auto text-right">
                      <div className="text-lg font-bold text-yellow-600">{member.totalPoints}</div>
                      <div className="text-xs text-muted-foreground">points</div>
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="space-y-4">
                  {/* Performance Metrics */}
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <div className="flex justify-between text-sm">
                        <span>Tasks Completed</span>
                        <span className="font-medium">{member.metrics.tasksCompleted}</span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span>Avg Task Time</span>
                        <span className="font-medium">{member.metrics.averageTaskTime}h</span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span>On-Time Delivery</span>
                        <span className={`font-medium ${getPerformanceColor(member.metrics.onTimeDelivery)}`}>
                          {member.metrics.onTimeDelivery}%
                        </span>
                      </div>
                    </div>
                    <div className="space-y-2">
                      <div className="flex justify-between text-sm">
                        <span>Quality Score</span>
                        <span className={`font-medium ${getPerformanceColor(member.metrics.qualityScore)}`}>
                          {member.metrics.qualityScore}%
                        </span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span>Collaboration</span>
                        <span className={`font-medium ${getPerformanceColor(member.metrics.collaborationScore)}`}>
                          {member.metrics.collaborationScore}%
                        </span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span>Efficiency</span>
                        <span className={`font-medium ${getPerformanceColor(member.metrics.efficiency)}`}>
                          {member.metrics.efficiency}%
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Overall Performance */}
                  <div>
                    <div className="flex justify-between text-sm mb-2">
                      <span>Overall Performance</span>
                      <span className="font-medium">
                        {Math.round((member.metrics.qualityScore + member.metrics.collaborationScore + member.metrics.efficiency) / 3)}%
                      </span>
                    </div>
                    <Progress 
                      value={(member.metrics.qualityScore + member.metrics.collaborationScore + member.metrics.efficiency) / 3} 
                      className="h-2"
                    />
                  </div>

                  {/* Achievements */}
                  <div>
                    <div className="text-sm font-medium mb-2">Achievements</div>
                    <div className="flex flex-wrap gap-1">
                      {member.achievements.map(achievement => {
                        const badge = achievementBadges.find(b => b.name === achievement)
                        return (
                          <Badge key={achievement} variant="outline" className="text-xs">
                            {badge?.icon} {achievement}
                          </Badge>
                        )
                      })}
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>

          {/* Leaderboard */}
          <Card>
            <CardHeader>
              <CardTitle>Performance Leaderboard</CardTitle>
              <CardDescription>Top performers this {timeRange}</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {[...mockTeamPerformance]
                  .sort((a, b) => b.totalPoints - a.totalPoints)
                  .map((member, index) => (
                    <div key={member.id} className="flex items-center gap-4 p-3 border rounded-lg">
                      <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center font-bold text-primary">
                        {index + 1}
                      </div>
                      <Avatar className="h-8 w-8">
                        <AvatarFallback className="text-sm">
                          {member.name.split(' ').map(n => n[0]).join('')}
                        </AvatarFallback>
                      </Avatar>
                      <div className="flex-1">
                        <div className="font-medium">{member.name}</div>
                        <div className="text-sm text-muted-foreground">{member.role}</div>
                      </div>
                      <div className="text-right">
                        <div className="font-bold text-yellow-600">{member.totalPoints}</div>
                        <div className="text-xs text-muted-foreground">points</div>
                      </div>
                      {index < 3 && (
                        <div className="text-2xl">
                          {index === 0 ? '🥇' : index === 1 ? '🥈' : '🥉'}
                        </div>
                      )}
                    </div>
                  ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Trends Tab */}
        <TabsContent value="trends" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Productivity Trends */}
            <Card>
              <CardHeader>
                <CardTitle>Productivity Trends</CardTitle>
                <CardDescription>Task completion and efficiency over time</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={performanceData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="month" />
                    <YAxis />
                    <Tooltip />
                    <Area 
                      type="monotone" 
                      dataKey="productivity" 
                      stackId="1" 
                      stroke="#8884d8" 
                      fill="#8884d8" 
                      fillOpacity={0.3}
                    />
                    <Area 
                      type="monotone" 
                      dataKey="efficiency" 
                      stackId="1" 
                      stroke="#82ca9d" 
                      fill="#82ca9d" 
                      fillOpacity={0.3}
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Quality & Collaboration */}
            <Card>
              <CardHeader>
                <CardTitle>Quality & Collaboration</CardTitle>
                <CardDescription>Quality scores and team collaboration metrics</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={performanceData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="month" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="quality" fill="#8884d8" name="Quality" />
                    <Bar dataKey="collaboration" fill="#82ca9d" name="Collaboration" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>

          {/* Performance Insights */}
          <Card>
            <CardHeader>
              <CardTitle>Performance Insights</CardTitle>
              <CardDescription>AI-powered insights and recommendations</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-start gap-3 p-4 bg-green-50 rounded-lg">
                  <TrendingUp className="h-5 w-5 text-green-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-green-900">Strong Performance Trend</h4>
                    <p className="text-sm text-green-700">
                      Team productivity has increased by 15% over the last quarter. Quality scores are consistently above target.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                  <Award className="h-5 w-5 text-blue-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-blue-900">Recognition Opportunity</h4>
                    <p className="text-sm text-blue-700">
                      Sarah Wilson has achieved exceptional quality scores for 3 consecutive months. Consider nominating for employee of the quarter.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-yellow-50 rounded-lg">
                  <Target className="h-5 w-5 text-yellow-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-yellow-900">Improvement Area</h4>
                    <p className="text-sm text-yellow-700">
                      Collaboration scores show room for improvement. Consider team-building activities or cross-functional projects.
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

export default TeamPerformanceMetrics