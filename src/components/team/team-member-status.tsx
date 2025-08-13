'use client'

import React, { useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Progress } from '@/components/ui/progress'
import { Separator } from '@/components/ui/separator'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import {
  Circle,
  Clock,
  Calendar,
  MessageSquare,
  Phone,
  Mail,
  MapPin,
  MoreHorizontal,
  Settings,
  User,
  Activity,
  Coffee,
  Zap,
  Moon,
  Wifi,
  WifiOff,
  Edit3,
  Save,
  X,
  CheckCircle,
  AlertCircle,
  Timer,
  Target,
  TrendingUp,
  Users,
  Building,
  Briefcase
} from 'lucide-react'
import { formatDistanceToNow, format } from 'date-fns'

interface TeamMember {
  id: string
  name: string
  avatar?: string
  role: string
  department: string
  status: 'online' | 'away' | 'busy' | 'offline'
  workload: number
  tasksCompleted: number
  tasksInProgress: number
  tasksPending: number
  lastSeen?: Date
  timezone: string
  location: string
  customStatus?: string
  statusEmoji?: string
  statusUntil?: Date
  skills: string[]
  currentProject?: string
  nextAvailable?: Date
  contactInfo: {
    email: string
    phone?: string
    slack?: string
  }
  workingHours: {
    start: string
    end: string
    days: string[]
  }
  schedule: {
    meetings: number
    freeTime: number
    focusTime: number
  }
}

interface TeamMemberStatusProps {
  members: TeamMember[]
}

const mockMembers: TeamMember[] = [
  {
    id: '1',
    name: 'John Doe',
    role: 'Marketing Manager',
    department: 'Marketing',
    status: 'online',
    workload: 75,
    tasksCompleted: 12,
    tasksInProgress: 5,
    tasksPending: 3,
    lastSeen: new Date(),
    timezone: 'EST',
    location: 'New York, USA',
    customStatus: 'In strategy meeting',
    statusEmoji: '📊',
    statusUntil: new Date(Date.now() + 2 * 60 * 60 * 1000), // 2 hours from now
    skills: ['Strategy', 'Analytics', 'Leadership'],
    currentProject: 'Q1 Campaign Launch',
    nextAvailable: new Date(Date.now() + 30 * 60 * 1000), // 30 minutes from now
    contactInfo: {
      email: 'john.doe@company.com',
      phone: '+1 (555) 123-4567',
      slack: '@johndoe'
    },
    workingHours: {
      start: '09:00',
      end: '17:00',
      days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
    },
    schedule: {
      meetings: 4,
      freeTime: 2,
      focusTime: 3
    }
  },
  {
    id: '2',
    name: 'Sarah Wilson',
    role: 'Content Creator',
    department: 'Marketing',
    status: 'busy',
    workload: 90,
    tasksCompleted: 8,
    tasksInProgress: 7,
    tasksPending: 2,
    lastSeen: new Date(Date.now() - 10 * 60 * 1000), // 10 minutes ago
    timezone: 'PST',
    location: 'San Francisco, USA',
    customStatus: 'Deep work - content creation',
    statusEmoji: '✍️',
    statusUntil: new Date(Date.now() + 90 * 60 * 1000), // 90 minutes from now
    skills: ['Writing', 'Content Strategy', 'SEO'],
    currentProject: 'Blog Content Calendar',
    nextAvailable: new Date(Date.now() + 90 * 60 * 1000),
    contactInfo: {
      email: 'sarah.wilson@company.com',
      slack: '@sarahw'
    },
    workingHours: {
      start: '08:00',
      end: '16:00',
      days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
    },
    schedule: {
      meetings: 2,
      freeTime: 4,
      focusTime: 3
    }
  },
  {
    id: '3',
    name: 'Mike Johnson',
    role: 'Designer',
    department: 'Creative',
    status: 'online',
    workload: 60,
    tasksCompleted: 15,
    tasksInProgress: 3,
    tasksPending: 1,
    lastSeen: new Date(),
    timezone: 'EST',
    location: 'Remote',
    customStatus: 'Available for quick questions',
    statusEmoji: '🎨',
    skills: ['UI/UX Design', 'Graphic Design', 'Prototyping'],
    currentProject: 'Website Redesign',
    nextAvailable: new Date(),
    contactInfo: {
      email: 'mike.johnson@company.com',
      phone: '+1 (555) 987-6543',
      slack: '@mikej'
    },
    workingHours: {
      start: '10:00',
      end: '18:00',
      days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
    },
    schedule: {
      meetings: 1,
      freeTime: 5,
      focusTime: 2
    }
  },
  {
    id: '4',
    name: 'Lisa Brown',
    role: 'Marketing Director',
    department: 'Marketing',
    status: 'away',
    workload: 45,
    tasksCompleted: 6,
    tasksInProgress: 2,
    tasksPending: 5,
    lastSeen: new Date(Date.now() - 30 * 60 * 1000), // 30 minutes ago
    timezone: 'EST',
    location: 'Boston, USA',
    customStatus: 'In client meeting',
    statusEmoji: '🤝',
    statusUntil: new Date(Date.now() + 60 * 60 * 1000), // 1 hour from now
    skills: ['Leadership', 'Strategy', 'Client Relations'],
    currentProject: 'Client Onboarding',
    nextAvailable: new Date(Date.now() + 60 * 60 * 1000),
    contactInfo: {
      email: 'lisa.brown@company.com',
      phone: '+1 (555) 456-7890',
      slack: '@lisab'
    },
    workingHours: {
      start: '08:30',
      end: '17:30',
      days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
    },
    schedule: {
      meetings: 6,
      freeTime: 1,
      focusTime: 1
    }
  },
  {
    id: '5',
    name: 'David Lee',
    role: 'Copywriter',
    department: 'Marketing',
    status: 'offline',
    workload: 80,
    tasksCompleted: 10,
    tasksInProgress: 4,
    tasksPending: 2,
    lastSeen: new Date(Date.now() - 2 * 60 * 60 * 1000), // 2 hours ago
    timezone: 'PST',
    location: 'Los Angeles, USA',
    customStatus: 'Off for the day',
    statusEmoji: '🌅',
    skills: ['Copywriting', 'Email Marketing', 'Social Media'],
    currentProject: 'Email Campaign Series',
    nextAvailable: new Date(Date.now() + 18 * 60 * 60 * 1000), // Tomorrow morning
    contactInfo: {
      email: 'david.lee@company.com',
      slack: '@davidl'
    },
    workingHours: {
      start: '07:00',
      end: '15:00',
      days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
    },
    schedule: {
      meetings: 3,
      freeTime: 3,
      focusTime: 2
    }
  }
]

export const TeamMemberStatus: React.FC<TeamMemberStatusProps> = ({ members = mockMembers }) => {
  const [selectedMember, setSelectedMember] = useState<TeamMember | null>(null)
  const [editingStatus, setEditingStatus] = useState<string>('')
  const [newStatus, setNewStatus] = useState('')
  const [newEmoji, setNewEmoji] = useState('')

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

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'online':
        return <Wifi className="h-3 w-3" />
      case 'busy':
        return <Circle className="h-3 w-3 fill-current" />
      case 'away':
        return <Clock className="h-3 w-3" />
      case 'offline':
        return <WifiOff className="h-3 w-3" />
      default:
        return <Circle className="h-3 w-3" />
    }
  }

  const getWorkloadColor = (workload: number) => {
    if (workload >= 90) return 'text-red-600'
    if (workload >= 75) return 'text-orange-600'
    if (workload >= 50) return 'text-yellow-600'
    return 'text-green-600'
  }

  const getWorkloadIcon = (workload: number) => {
    if (workload >= 90) return <AlertCircle className="h-4 w-4" />
    if (workload >= 75) return <Zap className="h-4 w-4" />
    if (workload >= 50) return <Activity className="h-4 w-4" />
    return <Coffee className="h-4 w-4" />
  }

  const updateMemberStatus = (memberId: string, status: string, customStatus?: string, emoji?: string) => {
    // In a real app, this would call an API
    console.log('Updating status for', memberId, { status, customStatus, emoji })
  }

  const getCurrentTime = (timezone: string) => {
    // Simplified timezone display
    const now = new Date()
    return format(now, 'HH:mm')
  }

  const isWorkingHours = (member: TeamMember) => {
    const now = new Date()
    const currentHour = now.getHours()
    const startHour = parseInt(member.workingHours.start.split(':')[0])
    const endHour = parseInt(member.workingHours.end.split(':')[0])
    const currentDay = format(now, 'EEEE')
    
    return member.workingHours.days.includes(currentDay) && 
           currentHour >= startHour && 
           currentHour < endHour
  }

  return (
    <div className="space-y-4">
      {/* Team Overview */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="text-center">
          <div className="text-2xl font-bold text-green-600">
            {members.filter(m => m.status === 'online').length}
          </div>
          <div className="text-sm text-muted-foreground">Online</div>
        </div>
        <div className="text-center">
          <div className="text-2xl font-bold text-red-600">
            {members.filter(m => m.status === 'busy').length}
          </div>
          <div className="text-sm text-muted-foreground">Busy</div>
        </div>
        <div className="text-center">
          <div className="text-2xl font-bold text-yellow-600">
            {members.filter(m => m.status === 'away').length}
          </div>
          <div className="text-sm text-muted-foreground">Away</div>
        </div>
        <div className="text-center">
          <div className="text-2xl font-bold text-gray-600">
            {members.filter(m => m.status === 'offline').length}
          </div>
          <div className="text-sm text-muted-foreground">Offline</div>
        </div>
      </div>

      <Separator />

      {/* Team Members List */}
      <div className="space-y-3">
        {members.map(member => (
          <Card key={member.id} className="transition-shadow hover:shadow-md">
            <CardContent className="p-4">
              <div className="flex items-center gap-4">
                {/* Avatar with Status */}
                <div className="relative">
                  <Avatar className="h-12 w-12">
                    <AvatarFallback className="text-lg">
                      {member.name.split(' ').map(n => n[0]).join('')}
                    </AvatarFallback>
                  </Avatar>
                  <div className={`absolute -bottom-1 -right-1 w-4 h-4 rounded-full border-2 border-background ${
                    getStatusColor(member.status)
                  } flex items-center justify-center`}>
                    {getStatusIcon(member.status)}
                  </div>
                </div>

                {/* Member Info */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <h4 className="font-medium truncate">{member.name}</h4>
                    <Badge variant="outline" className="text-xs">{member.role}</Badge>
                    {!isWorkingHours(member) && member.status !== 'offline' && (
                      <Badge variant="secondary" className="text-xs">
                        Outside work hours
                      </Badge>
                    )}
                  </div>

                  {/* Custom Status */}
                  {member.customStatus && (
                    <div className="flex items-center gap-1 text-sm text-muted-foreground mb-2">
                      {member.statusEmoji && <span>{member.statusEmoji}</span>}
                      <span>{member.customStatus}</span>
                      {member.statusUntil && (
                        <span className="text-xs">
                          until {format(member.statusUntil, 'HH:mm')}
                        </span>
                      )}
                    </div>
                  )}

                  {/* Workload & Tasks */}
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-xs">
                    <div>
                      <div className="flex items-center gap-1 text-muted-foreground">
                        {getWorkloadIcon(member.workload)}
                        <span>Workload</span>
                      </div>
                      <div className={`font-medium ${getWorkloadColor(member.workload)}`}>
                        {member.workload}%
                      </div>
                    </div>
                    <div>
                      <div className="text-muted-foreground">In Progress</div>
                      <div className="font-medium">{member.tasksInProgress}</div>
                    </div>
                    <div>
                      <div className="text-muted-foreground">Completed</div>
                      <div className="font-medium">{member.tasksCompleted}</div>
                    </div>
                    <div>
                      <div className="text-muted-foreground">Location</div>
                      <div className="font-medium truncate">{member.location}</div>
                    </div>
                  </div>

                  {/* Project & Availability */}
                  {member.currentProject && (
                    <div className="mt-2 text-xs">
                      <span className="text-muted-foreground">Current project: </span>
                      <span className="font-medium">{member.currentProject}</span>
                    </div>
                  )}
                  
                  {member.nextAvailable && member.status !== 'online' && (
                    <div className="mt-1 text-xs">
                      <span className="text-muted-foreground">Available: </span>
                      <span className="font-medium">
                        {formatDistanceToNow(member.nextAvailable, { addSuffix: true })}
                      </span>
                    </div>
                  )}
                </div>

                {/* Quick Actions */}
                <div className="flex items-center gap-2">
                  <Button variant="outline" size="sm">
                    <MessageSquare className="h-4 w-4 mr-1" />
                    Message
                  </Button>
                  
                  <Dialog>
                    <DialogTrigger asChild>
                      <Button variant="outline" size="sm">
                        <User className="h-4 w-4 mr-1" />
                        Details
                      </Button>
                    </DialogTrigger>
                    <DialogContent className="max-w-2xl">
                      <DialogHeader>
                        <DialogTitle>{member.name}</DialogTitle>
                        <DialogDescription>{member.role} • {member.department}</DialogDescription>
                      </DialogHeader>
                      
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        {/* Contact Info */}
                        <div className="space-y-4">
                          <div>
                            <h4 className="font-medium mb-2">Contact Information</h4>
                            <div className="space-y-2 text-sm">
                              <div className="flex items-center gap-2">
                                <Mail className="h-4 w-4 text-muted-foreground" />
                                <span>{member.contactInfo.email}</span>
                              </div>
                              {member.contactInfo.phone && (
                                <div className="flex items-center gap-2">
                                  <Phone className="h-4 w-4 text-muted-foreground" />
                                  <span>{member.contactInfo.phone}</span>
                                </div>
                              )}
                              {member.contactInfo.slack && (
                                <div className="flex items-center gap-2">
                                  <MessageSquare className="h-4 w-4 text-muted-foreground" />
                                  <span>{member.contactInfo.slack}</span>
                                </div>
                              )}
                              <div className="flex items-center gap-2">
                                <MapPin className="h-4 w-4 text-muted-foreground" />
                                <span>{member.location} • {member.timezone}</span>
                              </div>
                            </div>
                          </div>

                          {/* Working Hours */}
                          <div>
                            <h4 className="font-medium mb-2">Working Hours</h4>
                            <div className="text-sm">
                              <div>{member.workingHours.start} - {member.workingHours.end}</div>
                              <div className="text-muted-foreground">
                                {member.workingHours.days.join(', ')}
                              </div>
                              <div className="mt-1">
                                <span className="text-muted-foreground">Current time: </span>
                                <span className="font-medium">{getCurrentTime(member.timezone)}</span>
                              </div>
                            </div>
                          </div>

                          {/* Skills */}
                          <div>
                            <h4 className="font-medium mb-2">Skills</h4>
                            <div className="flex flex-wrap gap-1">
                              {member.skills.map(skill => (
                                <Badge key={skill} variant="outline" className="text-xs">
                                  {skill}
                                </Badge>
                              ))}
                            </div>
                          </div>
                        </div>

                        {/* Schedule & Workload */}
                        <div className="space-y-4">
                          {/* Today's Schedule */}
                          <div>
                            <h4 className="font-medium mb-2">Today's Schedule</h4>
                            <div className="space-y-2 text-sm">
                              <div className="flex items-center justify-between">
                                <span>Meetings</span>
                                <span className="font-medium">{member.schedule.meetings}h</span>
                              </div>
                              <div className="flex items-center justify-between">
                                <span>Focus Time</span>
                                <span className="font-medium">{member.schedule.focusTime}h</span>
                              </div>
                              <div className="flex items-center justify-between">
                                <span>Free Time</span>
                                <span className="font-medium">{member.schedule.freeTime}h</span>
                              </div>
                            </div>
                          </div>

                          {/* Workload Breakdown */}
                          <div>
                            <h4 className="font-medium mb-2">Workload</h4>
                            <div className="space-y-3">
                              <div>
                                <div className="flex items-center justify-between text-sm mb-1">
                                  <span>Current Workload</span>
                                  <span className={getWorkloadColor(member.workload)}>
                                    {member.workload}%
                                  </span>
                                </div>
                                <Progress value={member.workload} className="h-2" />
                              </div>

                              <div className="grid grid-cols-3 gap-2 text-center text-xs">
                                <div className="p-2 bg-blue-50 rounded">
                                  <div className="font-medium text-blue-600">
                                    {member.tasksInProgress}
                                  </div>
                                  <div className="text-blue-600">Active</div>
                                </div>
                                <div className="p-2 bg-yellow-50 rounded">
                                  <div className="font-medium text-yellow-600">
                                    {member.tasksPending}
                                  </div>
                                  <div className="text-yellow-600">Pending</div>
                                </div>
                                <div className="p-2 bg-green-50 rounded">
                                  <div className="font-medium text-green-600">
                                    {member.tasksCompleted}
                                  </div>
                                  <div className="text-green-600">Done</div>
                                </div>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </DialogContent>
                  </Dialog>

                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="ghost" size="sm" className="h-8 w-8 p-0">
                        <MoreHorizontal className="h-4 w-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem>
                        <Phone className="h-4 w-4 mr-2" />
                        Call
                      </DropdownMenuItem>
                      <DropdownMenuItem>
                        <Mail className="h-4 w-4 mr-2" />
                        Email
                      </DropdownMenuItem>
                      <DropdownMenuItem>
                        <Calendar className="h-4 w-4 mr-2" />
                        Schedule Meeting
                      </DropdownMenuItem>
                      <DropdownMenuItem>
                        <Target className="h-4 w-4 mr-2" />
                        Assign Task
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}

export default TeamMemberStatus