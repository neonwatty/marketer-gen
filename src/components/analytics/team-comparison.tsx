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
import { Checkbox } from '@/components/ui/checkbox'
import { Label } from '@/components/ui/label'
import {
  ArrowUpRight,
  ArrowDownRight,
  BarChart3,
  TrendingUp,
  TrendingDown,
  Users,
  Target,
  Award,
  Trophy,
  Zap,
  Clock,
  CheckCircle,
  Activity,
  Download,
  RefreshCw,
  Filter,
  Gauge,
  Star,
  ThumbsUp,
  AlertTriangle,
  Plus,
  Minus,
  ArrowUpDown
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
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar,
  ScatterChart,
  Scatter,
  Cell
} from 'recharts'

interface TeamMember {
  id: string
  name: string
  role: string
  department: string
  metrics: {
    productivity: number
    quality: number
    collaboration: number
    efficiency: number
    satisfaction: number
    growth: number
  }
  tasks: {
    completed: number
    inProgress: number
    overdue: number
    avgCompletionTime: number
  }
  trends: {
    period: string
    productivity: number
    quality: number
    collaboration: number
  }[]
  benchmarks: {
    vs_team_avg: number
    vs_department_avg: number
    vs_top_performer: number
  }
  strengths: string[]
  improvementAreas: string[]
}

interface ComparisonMetric {
  id: string
  name: string
  category: 'performance' | 'output' | 'collaboration' | 'growth'
  weight: number
  format: 'percentage' | 'score' | 'count' | 'time'
}

const mockTeamMembers: TeamMember[] = [
  {
    id: '1',
    name: 'John Doe',
    role: 'Marketing Manager',
    department: 'Marketing',
    metrics: {
      productivity: 87,
      quality: 92,
      collaboration: 89,
      efficiency: 85,
      satisfaction: 91,
      growth: 15
    },
    tasks: {
      completed: 68,
      inProgress: 12,
      overdue: 3,
      avgCompletionTime: 4.2
    },
    trends: [
      { period: 'Jan', productivity: 82, quality: 88, collaboration: 85 },
      { period: 'Feb', productivity: 84, quality: 90, collaboration: 87 },
      { period: 'Mar', productivity: 86, quality: 91, collaboration: 88 },
      { period: 'Apr', productivity: 87, quality: 92, collaboration: 89 }
    ],
    benchmarks: {
      vs_team_avg: 108,
      vs_department_avg: 112,
      vs_top_performer: 91
    },
    strengths: ['Strategic Planning', 'Team Leadership', 'Project Management'],
    improvementAreas: ['Technical Skills', 'Speed of Execution']
  },
  {
    id: '2',
    name: 'Sarah Wilson',
    role: 'Content Creator',
    department: 'Marketing',
    metrics: {
      productivity: 96,
      quality: 98,
      collaboration: 94,
      efficiency: 93,
      satisfaction: 95,
      growth: 22
    },
    tasks: {
      completed: 89,
      inProgress: 8,
      overdue: 1,
      avgCompletionTime: 2.8
    },
    trends: [
      { period: 'Jan', productivity: 91, quality: 93, collaboration: 90 },
      { period: 'Feb', productivity: 93, quality: 95, collaboration: 92 },
      { period: 'Mar', productivity: 95, quality: 97, collaboration: 93 },
      { period: 'Apr', productivity: 96, quality: 98, collaboration: 94 }
    ],
    benchmarks: {
      vs_team_avg: 118,
      vs_department_avg: 122,
      vs_top_performer: 100
    },
    strengths: ['Content Quality', 'Creativity', 'Consistency', 'Speed'],
    improvementAreas: ['Complex Analytics', 'Leadership Skills']
  },
  {
    id: '3',
    name: 'Mike Johnson',
    role: 'Designer',
    department: 'Design',
    metrics: {
      productivity: 79,
      quality: 94,
      collaboration: 82,
      efficiency: 76,
      satisfaction: 88,
      growth: 8
    },
    tasks: {
      completed: 54,
      inProgress: 15,
      overdue: 6,
      avgCompletionTime: 6.7
    },
    trends: [
      { period: 'Jan', productivity: 75, quality: 91, collaboration: 79 },
      { period: 'Feb', productivity: 77, quality: 92, collaboration: 80 },
      { period: 'Mar', productivity: 78, quality: 93, collaboration: 81 },
      { period: 'Apr', productivity: 79, quality: 94, collaboration: 82 }
    ],
    benchmarks: {
      vs_team_avg: 95,
      vs_department_avg: 98,
      vs_top_performer: 82
    },
    strengths: ['Design Quality', 'Attention to Detail', 'Innovation'],
    improvementAreas: ['Speed', 'Project Management', 'Communication']
  },
  {
    id: '4',
    name: 'Lisa Brown',
    role: 'Marketing Director',
    department: 'Marketing',
    metrics: {
      productivity: 84,
      quality: 91,
      collaboration: 96,
      efficiency: 82,
      satisfaction: 93,
      growth: 12
    },
    tasks: {
      completed: 45,
      inProgress: 18,
      overdue: 2,
      avgCompletionTime: 8.1
    },
    trends: [
      { period: 'Jan', productivity: 80, quality: 87, collaboration: 92 },
      { period: 'Feb', productivity: 82, quality: 89, collaboration: 94 },
      { period: 'Mar', productivity: 83, quality: 90, collaboration: 95 },
      { period: 'Apr', productivity: 84, quality: 91, collaboration: 96 }
    ],
    benchmarks: {
      vs_team_avg: 105,
      vs_department_avg: 108,
      vs_top_performer: 89
    },
    strengths: ['Leadership', 'Strategy', 'Team Building', 'Mentoring'],
    improvementAreas: ['Operational Efficiency', 'Delegation']
  },
  {
    id: '5',
    name: 'David Lee',
    role: 'Copywriter',
    department: 'Marketing',
    metrics: {
      productivity: 91,
      quality: 86,
      collaboration: 88,
      efficiency: 94,
      satisfaction: 89,
      growth: 18
    },
    tasks: {
      completed: 78,
      inProgress: 9,
      overdue: 2,
      avgCompletionTime: 3.5
    },
    trends: [
      { period: 'Jan', productivity: 87, quality: 82, collaboration: 84 },
      { period: 'Feb', productivity: 89, quality: 84, collaboration: 86 },
      { period: 'Mar', productivity: 90, quality: 85, collaboration: 87 },
      { period: 'Apr', productivity: 91, quality: 86, collaboration: 88 }
    ],
    benchmarks: {
      vs_team_avg: 112,
      vs_department_avg: 115,
      vs_top_performer: 94
    },
    strengths: ['Writing Speed', 'Adaptability', 'Reliability'],
    improvementAreas: ['Quality Consistency', 'Strategic Thinking']
  }
]

const comparisonMetrics: ComparisonMetric[] = [
  { id: 'productivity', name: 'Productivity Score', category: 'performance', weight: 25, format: 'score' },
  { id: 'quality', name: 'Quality Rating', category: 'performance', weight: 25, format: 'score' },
  { id: 'collaboration', name: 'Collaboration Score', category: 'collaboration', weight: 20, format: 'score' },
  { id: 'efficiency', name: 'Efficiency Rating', category: 'performance', weight: 15, format: 'score' },
  { id: 'completed', name: 'Tasks Completed', category: 'output', weight: 10, format: 'count' },
  { id: 'avgCompletionTime', name: 'Avg Completion Time', category: 'output', weight: 5, format: 'time' }
]

export const TeamComparison: React.FC = () => {
  const [selectedMembers, setSelectedMembers] = useState<string[]>(['1', '2'])
  const [comparisonType, setComparisonType] = useState<'side-by-side' | 'ranking' | 'benchmarks'>('side-by-side')
  const [selectedMetrics, setSelectedMetrics] = useState<string[]>(['productivity', 'quality', 'collaboration', 'efficiency'])
  const [timeRange, setTimeRange] = useState<'month' | 'quarter' | 'year'>('quarter')
  const [viewType, setViewType] = useState<'overview' | 'detailed' | 'trends' | 'insights'>('overview')

  const handleMemberToggle = (memberId: string) => {
    setSelectedMembers(prev => {
      if (prev.includes(memberId)) {
        return prev.filter(id => id !== memberId)
      } else if (prev.length < 4) { // Limit to 4 for readability
        return [...prev, memberId]
      }
      return prev
    })
  }

  const handleMetricToggle = (metricId: string) => {
    setSelectedMetrics(prev => {
      if (prev.includes(metricId)) {
        return prev.filter(id => id !== metricId)
      } else {
        return [...prev, metricId]
      }
    })
  }

  const getSelectedMemberData = () => {
    return mockTeamMembers.filter(member => selectedMembers.includes(member.id))
  }

  const getMetricValue = (member: TeamMember, metricId: string) => {
    switch (metricId) {
      case 'productivity':
        return member.metrics.productivity
      case 'quality':
        return member.metrics.quality
      case 'collaboration':
        return member.metrics.collaboration
      case 'efficiency':
        return member.metrics.efficiency
      case 'satisfaction':
        return member.metrics.satisfaction
      case 'growth':
        return member.metrics.growth
      case 'completed':
        return member.tasks.completed
      case 'avgCompletionTime':
        return member.tasks.avgCompletionTime
      default:
        return 0
    }
  }

  const formatMetricValue = (value: number, format: string) => {
    switch (format) {
      case 'percentage':
        return `${value}%`
      case 'score':
        return value.toString()
      case 'count':
        return value.toString()
      case 'time':
        return `${value}h`
      default:
        return value.toString()
    }
  }

  const getPerformanceBadge = (score: number) => {
    if (score >= 95) return { variant: 'default' as const, label: 'Exceptional', color: 'text-green-600' }
    if (score >= 85) return { variant: 'secondary' as const, label: 'Excellent', color: 'text-blue-600' }
    if (score >= 75) return { variant: 'outline' as const, label: 'Good', color: 'text-yellow-600' }
    return { variant: 'destructive' as const, label: 'Needs Improvement', color: 'text-red-600' }
  }

  const getBenchmarkColor = (benchmark: number) => {
    if (benchmark >= 115) return 'text-green-600'
    if (benchmark >= 105) return 'text-blue-600'
    if (benchmark >= 95) return 'text-yellow-600'
    return 'text-red-600'
  }

  const getOverallScore = (member: TeamMember) => {
    const scores = Object.values(member.metrics).slice(0, 5) // Exclude growth
    return Math.round(scores.reduce((sum, score) => sum + score, 0) / scores.length)
  }

  const getRankedMembers = () => {
    return [...mockTeamMembers].sort((a, b) => getOverallScore(b) - getOverallScore(a))
  }

  const getComparisonData = () => {
    const selectedMemberData = getSelectedMemberData()
    return selectedMetrics.map(metricId => {
      const metric = comparisonMetrics.find(m => m.id === metricId)
      if (!metric) return null

      const dataPoint: any = { metric: metric.name }
      selectedMemberData.forEach(member => {
        dataPoint[member.name.split(' ')[0]] = getMetricValue(member, metricId)
      })
      return dataPoint
    }).filter(Boolean)
  }

  const getRadarData = () => {
    const selectedMemberData = getSelectedMemberData()
    return selectedMetrics.map(metricId => {
      const metric = comparisonMetrics.find(m => m.id === metricId)
      if (!metric) return null

      const dataPoint: any = { metric: metric.name, fullMark: 100 }
      selectedMemberData.forEach(member => {
        dataPoint[member.name.split(' ')[0]] = getMetricValue(member, metricId)
      })
      return dataPoint
    }).filter(Boolean)
  }

  const colors = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6']

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight flex items-center gap-2">
            <ArrowUpDown className="h-8 w-8" />
            Team Comparison
          </h1>
          <p className="text-muted-foreground">
            Compare team member performance, identify strengths, and benchmark results
          </p>
        </div>
        
        <div className="flex items-center gap-2">
          <Select value={timeRange} onValueChange={(value: any) => setTimeRange(value)}>
            <SelectTrigger className="w-[120px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
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

      {/* Controls */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Member Selection */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Select Team Members</CardTitle>
            <CardDescription>Choose up to 4 members to compare</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {mockTeamMembers.map(member => {
                const overallScore = getOverallScore(member)
                const badge = getPerformanceBadge(overallScore)
                return (
                  <div key={member.id} className="flex items-center gap-3">
                    <Checkbox
                      checked={selectedMembers.includes(member.id)}
                      onCheckedChange={() => handleMemberToggle(member.id)}
                      disabled={!selectedMembers.includes(member.id) && selectedMembers.length >= 4}
                    />
                    <Avatar className="h-8 w-8">
                      <AvatarFallback className="text-xs">
                        {member.name.split(' ').map(n => n[0]).join('')}
                      </AvatarFallback>
                    </Avatar>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="font-medium text-sm">{member.name}</span>
                        <Badge variant={badge.variant} className="text-xs">
                          {overallScore}
                        </Badge>
                      </div>
                      <div className="text-xs text-muted-foreground">{member.role}</div>
                    </div>
                  </div>
                )
              })}
            </div>
            
            <div className="mt-4 text-xs text-muted-foreground">
              {selectedMembers.length}/4 members selected
            </div>
          </CardContent>
        </Card>

        {/* Metric Selection */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Comparison Metrics</CardTitle>
            <CardDescription>Choose metrics to compare</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {comparisonMetrics.map(metric => (
                <div key={metric.id} className="flex items-center gap-3">
                  <Checkbox
                    checked={selectedMetrics.includes(metric.id)}
                    onCheckedChange={() => handleMetricToggle(metric.id)}
                  />
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-medium">{metric.name}</span>
                      <Badge variant="outline" className="text-xs capitalize">
                        {metric.category}
                      </Badge>
                    </div>
                    <div className="text-xs text-muted-foreground">Weight: {metric.weight}%</div>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* Comparison Type */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Comparison Type</CardTitle>
            <CardDescription>Choose how to display the comparison</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              <div className="flex items-center gap-3">
                <Checkbox
                  checked={comparisonType === 'side-by-side'}
                  onCheckedChange={() => setComparisonType('side-by-side')}
                />
                <div>
                  <div className="font-medium text-sm">Side-by-Side</div>
                  <div className="text-xs text-muted-foreground">Direct comparison view</div>
                </div>
              </div>
              
              <div className="flex items-center gap-3">
                <Checkbox
                  checked={comparisonType === 'ranking'}
                  onCheckedChange={() => setComparisonType('ranking')}
                />
                <div>
                  <div className="font-medium text-sm">Ranking</div>
                  <div className="text-xs text-muted-foreground">Performance rankings</div>
                </div>
              </div>
              
              <div className="flex items-center gap-3">
                <Checkbox
                  checked={comparisonType === 'benchmarks'}
                  onCheckedChange={() => setComparisonType('benchmarks')}
                />
                <div>
                  <div className="font-medium text-sm">Benchmarks</div>
                  <div className="text-xs text-muted-foreground">vs team/department averages</div>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Main Content */}
      <Tabs value={viewType} onValueChange={(value: any) => setViewType(value)}>
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="overview">
            <BarChart3 className="h-4 w-4 mr-2" />
            Overview
          </TabsTrigger>
          <TabsTrigger value="detailed">
            <Target className="h-4 w-4 mr-2" />
            Detailed
          </TabsTrigger>
          <TabsTrigger value="trends">
            <TrendingUp className="h-4 w-4 mr-2" />
            Trends
          </TabsTrigger>
          <TabsTrigger value="insights">
            <Zap className="h-4 w-4 mr-2" />
            Insights
          </TabsTrigger>
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Performance Comparison Chart */}
            <Card>
              <CardHeader>
                <CardTitle>Performance Comparison</CardTitle>
                <CardDescription>Selected metrics across team members</CardDescription>
              </CardHeader>
              <CardContent>
                {selectedMembers.length > 0 ? (
                  <ResponsiveContainer width="100%" height={300}>
                    <BarChart data={getComparisonData()}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="metric" />
                      <YAxis />
                      <Tooltip />
                      <Legend />
                      {getSelectedMemberData().map((member, index) => (
                        <Bar
                          key={member.id}
                          dataKey={member.name.split(' ')[0]}
                          fill={colors[index % colors.length]}
                          name={member.name.split(' ')[0]}
                        />
                      ))}
                    </BarChart>
                  </ResponsiveContainer>
                ) : (
                  <div className="h-[300px] flex items-center justify-center text-muted-foreground">
                    Select team members to compare
                  </div>
                )}
              </CardContent>
            </Card>

            {/* Radar Chart */}
            <Card>
              <CardHeader>
                <CardTitle>Performance Radar</CardTitle>
                <CardDescription>Multi-dimensional performance comparison</CardDescription>
              </CardHeader>
              <CardContent>
                {selectedMembers.length > 0 ? (
                  <ResponsiveContainer width="100%" height={300}>
                    <RadarChart data={getRadarData()}>
                      <PolarGrid />
                      <PolarAngleAxis dataKey="metric" />
                      <PolarRadiusAxis angle={90} domain={[0, 100]} />
                      {getSelectedMemberData().map((member, index) => (
                        <Radar
                          key={member.id}
                          name={member.name.split(' ')[0]}
                          dataKey={member.name.split(' ')[0]}
                          stroke={colors[index % colors.length]}
                          fill={colors[index % colors.length]}
                          fillOpacity={0.1}
                        />
                      ))}
                      <Legend />
                    </RadarChart>
                  </ResponsiveContainer>
                ) : (
                  <div className="h-[300px] flex items-center justify-center text-muted-foreground">
                    Select team members to compare
                  </div>
                )}
              </CardContent>
            </Card>
          </div>

          {/* Team Rankings */}
          {comparisonType === 'ranking' && (
            <Card>
              <CardHeader>
                <CardTitle>Team Performance Rankings</CardTitle>
                <CardDescription>Overall performance ranking based on weighted metrics</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {getRankedMembers().map((member, index) => {
                    const overallScore = getOverallScore(member)
                    const badge = getPerformanceBadge(overallScore)
                    return (
                      <div key={member.id} className="flex items-center gap-4 p-4 border rounded-lg">
                        <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold text-white ${
                          index === 0 ? 'bg-yellow-500' : index === 1 ? 'bg-gray-400' : index === 2 ? 'bg-orange-600' : 'bg-gray-300 text-gray-600'
                        }`}>
                          {index + 1}
                        </div>
                        
                        <Avatar className="h-12 w-12">
                          <AvatarFallback>
                            {member.name.split(' ').map(n => n[0]).join('')}
                          </AvatarFallback>
                        </Avatar>
                        
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-2">
                            <h4 className="font-medium">{member.name}</h4>
                            <Badge variant="outline">{member.role}</Badge>
                            <Badge variant={badge.variant} className={badge.color}>
                              {badge.label}
                            </Badge>
                            {index < 3 && (
                              <div className="text-2xl">
                                {index === 0 ? '🏆' : index === 1 ? '🥈' : '🥉'}
                              </div>
                            )}
                          </div>
                          
                          <div className="grid grid-cols-2 md:grid-cols-5 gap-4 text-sm">
                            <div>
                              <div className="text-muted-foreground">Overall Score</div>
                              <div className={`font-bold text-lg ${badge.color}`}>{overallScore}</div>
                            </div>
                            <div>
                              <div className="text-muted-foreground">Productivity</div>
                              <div className="font-medium">{member.metrics.productivity}</div>
                            </div>
                            <div>
                              <div className="text-muted-foreground">Quality</div>
                              <div className="font-medium">{member.metrics.quality}</div>
                            </div>
                            <div>
                              <div className="text-muted-foreground">Collaboration</div>
                              <div className="font-medium">{member.metrics.collaboration}</div>
                            </div>
                            <div>
                              <div className="text-muted-foreground">Growth</div>
                              <div className="font-medium text-green-600">+{member.metrics.growth}%</div>
                            </div>
                          </div>
                        </div>
                        
                        <div className="text-right">
                          <Button 
                            variant="outline" 
                            size="sm"
                            onClick={() => {
                              if (selectedMembers.includes(member.id)) {
                                handleMemberToggle(member.id)
                              } else if (selectedMembers.length < 4) {
                                handleMemberToggle(member.id)
                              }
                            }}
                            disabled={!selectedMembers.includes(member.id) && selectedMembers.length >= 4}
                          >
                            {selectedMembers.includes(member.id) ? (
                              <>
                                <Minus className="h-4 w-4 mr-2" />
                                Remove
                              </>
                            ) : (
                              <>
                                <Plus className="h-4 w-4 mr-2" />
                                Compare
                              </>
                            )}
                          </Button>
                        </div>
                      </div>
                    )
                  })}
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        {/* Detailed Tab */}
        <TabsContent value="detailed" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {getSelectedMemberData().map(member => {
              const overallScore = getOverallScore(member)
              const badge = getPerformanceBadge(overallScore)
              
              return (
                <Card key={member.id}>
                  <CardHeader>
                    <div className="flex items-center gap-3">
                      <Avatar className="h-12 w-12">
                        <AvatarFallback>
                          {member.name.split(' ').map(n => n[0]).join('')}
                        </AvatarFallback>
                      </Avatar>
                      <div>
                        <CardTitle className="text-lg">{member.name}</CardTitle>
                        <CardDescription>{member.role} • {member.department}</CardDescription>
                      </div>
                      <div className="ml-auto text-right">
                        <Badge variant={badge.variant} className={`${badge.color} mb-1`}>
                          {badge.label}
                        </Badge>
                        <div className="text-sm font-bold">{overallScore} Score</div>
                      </div>
                    </div>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    {/* Performance Metrics */}
                    <div>
                      <h4 className="font-medium mb-3">Performance Metrics</h4>
                      <div className="space-y-3">
                        {Object.entries(member.metrics).slice(0, 5).map(([key, value]) => (
                          <div key={key} className="flex justify-between items-center">
                            <span className="text-sm capitalize">{key.replace(/([A-Z])/g, ' $1').trim()}</span>
                            <div className="flex items-center gap-2">
                              <Progress value={value} className="w-20 h-2" />
                              <span className="text-sm font-medium w-8">{value}</span>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>

                    <Separator />

                    {/* Task Statistics */}
                    <div>
                      <h4 className="font-medium mb-3">Task Statistics</h4>
                      <div className="grid grid-cols-2 gap-4 text-sm">
                        <div>
                          <div className="text-muted-foreground">Completed</div>
                          <div className="font-bold text-green-600">{member.tasks.completed}</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">In Progress</div>
                          <div className="font-bold text-blue-600">{member.tasks.inProgress}</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Overdue</div>
                          <div className={`font-bold ${member.tasks.overdue > 3 ? 'text-red-600' : 'text-yellow-600'}`}>
                            {member.tasks.overdue}
                          </div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Avg Time</div>
                          <div className="font-bold">{member.tasks.avgCompletionTime}h</div>
                        </div>
                      </div>
                    </div>

                    <Separator />

                    {/* Benchmarks */}
                    {comparisonType === 'benchmarks' && (
                      <div>
                        <h4 className="font-medium mb-3">Performance Benchmarks</h4>
                        <div className="space-y-2 text-sm">
                          <div className="flex justify-between">
                            <span>vs Team Average</span>
                            <span className={`font-medium ${getBenchmarkColor(member.benchmarks.vs_team_avg)}`}>
                              {member.benchmarks.vs_team_avg}%
                            </span>
                          </div>
                          <div className="flex justify-between">
                            <span>vs Department Average</span>
                            <span className={`font-medium ${getBenchmarkColor(member.benchmarks.vs_department_avg)}`}>
                              {member.benchmarks.vs_department_avg}%
                            </span>
                          </div>
                          <div className="flex justify-between">
                            <span>vs Top Performer</span>
                            <span className={`font-medium ${getBenchmarkColor(member.benchmarks.vs_top_performer)}`}>
                              {member.benchmarks.vs_top_performer}%
                            </span>
                          </div>
                        </div>
                      </div>
                    )}

                    <Separator />

                    {/* Strengths & Improvement Areas */}
                    <div className="grid grid-cols-1 gap-3">
                      <div>
                        <h4 className="text-sm font-medium mb-2 text-green-700">Strengths</h4>
                        <div className="flex flex-wrap gap-1">
                          {member.strengths.map(strength => (
                            <Badge key={strength} variant="secondary" className="text-xs bg-green-100 text-green-800">
                              <Star className="h-3 w-3 mr-1" />
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
                              <Target className="h-3 w-3 mr-1" />
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
          {getSelectedMemberData().length > 0 ? (
            <Card>
              <CardHeader>
                <CardTitle>Performance Trends</CardTitle>
                <CardDescription>Performance evolution over time for selected members</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={400}>
                  <LineChart data={getSelectedMemberData()[0]?.trends || []}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="period" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    {getSelectedMemberData().map((member, memberIndex) => (
                      selectedMetrics.filter(m => ['productivity', 'quality', 'collaboration'].includes(m)).map((metricId, metricIndex) => (
                        <Line
                          key={`${member.id}-${metricId}`}
                          type="monotone"
                          dataKey={metricId}
                          data={member.trends}
                          stroke={colors[memberIndex % colors.length]}
                          strokeWidth={2}
                          strokeDasharray={metricIndex === 0 ? '0' : metricIndex === 1 ? '5 5' : '10 5 5 5'}
                          name={`${member.name.split(' ')[0]} ${metricId}`}
                        />
                      ))
                    ))}
                  </LineChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          ) : (
            <Card>
              <CardContent className="h-[400px] flex items-center justify-center">
                <div className="text-center text-muted-foreground">
                  <TrendingUp className="h-12 w-12 mx-auto mb-4" />
                  <p>Select team members to view performance trends</p>
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        {/* Insights Tab */}
        <TabsContent value="insights" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Comparison Insights</CardTitle>
              <CardDescription>AI-powered analysis of team performance differences</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-start gap-3 p-4 bg-green-50 rounded-lg">
                  <Trophy className="h-5 w-5 text-green-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-green-900">Top Performer</h4>
                    <p className="text-sm text-green-700">
                      Sarah Wilson leads with 96% productivity and exceptional quality scores. Her consistent 
                      performance and growth trajectory make her an ideal mentor for other team members.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                  <Target className="h-5 w-5 text-blue-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-blue-900">Growth Opportunity</h4>
                    <p className="text-sm text-blue-700">
                      Mike Johnson shows excellent quality (94%) but lower productivity (79%). Focus on efficiency 
                      training and process optimization to maximize his design expertise.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-yellow-50 rounded-lg">
                  <Activity className="h-5 w-5 text-yellow-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-yellow-900">Team Balance</h4>
                    <p className="text-sm text-yellow-700">
                      The team shows diverse strengths: Sarah excels in execution, Lisa in leadership, and John in 
                      strategy. This complementary skill set creates strong collaborative potential.
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3 p-4 bg-purple-50 rounded-lg">
                  <Zap className="h-5 w-5 text-purple-600 mt-0.5" />
                  <div>
                    <h4 className="font-medium text-purple-900">Optimization Recommendation</h4>
                    <p className="text-sm text-purple-700">
                      Consider cross-training initiatives: pair high performers with those showing growth potential. 
                      Sarah mentoring Mike could significantly boost overall team productivity.
                    </p>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Action Items */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <Card>
              <CardHeader>
                <CardTitle>Recommended Actions</CardTitle>
                <CardDescription>Based on comparison analysis</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 rounded-full bg-green-600 mt-2"></div>
                  <div>
                    <h4 className="font-medium">Mentorship Program</h4>
                    <p className="text-sm text-muted-foreground">
                      Pair Sarah Wilson with team members showing growth potential
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 rounded-full bg-blue-600 mt-2"></div>
                  <div>
                    <h4 className="font-medium">Process Optimization</h4>
                    <p className="text-sm text-muted-foreground">
                      Focus on efficiency improvements for design workflows
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 rounded-full bg-purple-600 mt-2"></div>
                  <div>
                    <h4 className="font-medium">Skill Development</h4>
                    <p className="text-sm text-muted-foreground">
                      Targeted training programs for identified improvement areas
                    </p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 rounded-full bg-orange-600 mt-2"></div>
                  <div>
                    <h4 className="font-medium">Recognition Program</h4>
                    <p className="text-sm text-muted-foreground">
                      Acknowledge top performers and consistent improvers
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Success Metrics</CardTitle>
                <CardDescription>Track improvements over time</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Team Average Score</span>
                    <span className="font-medium">88 → Target: 92</span>
                  </div>
                  <Progress value={96} className="h-2" />
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Performance Consistency</span>
                    <span className="font-medium">78% → Target: 85%</span>
                  </div>
                  <Progress value={92} className="h-2" />
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Growth Rate</span>
                    <span className="font-medium">15% → Target: 20%</span>
                  </div>
                  <Progress value={75} className="h-2" />
                </div>
                
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Quality Standards</span>
                    <span className="font-medium">91% → Target: 95%</span>
                  </div>
                  <Progress value={96} className="h-2" />
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  )
}

export default TeamComparison