'use client'

import React, { useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Separator } from '@/components/ui/separator'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import {
  Activity,
  CheckCircle,
  MessageSquare,
  FileText,
  Upload,
  UserPlus,
  Settings,
  Calendar,
  Clock,
  ExternalLink,
  Heart,
  Share,
  MoreHorizontal,
  Zap,
  Target,
  Award,
  GitCommit,
  Bell,
  Flag,
  Paperclip,
  Eye,
  ThumbsUp,
  RefreshCw
} from 'lucide-react'
import { formatDistanceToNow } from 'date-fns'

interface ActivityItem {
  id: string
  type: 'task_completed' | 'task_assigned' | 'comment_added' | 'file_uploaded' | 'approval_requested' | 'approval_given' | 'team_joined' | 'milestone_reached' | 'meeting_scheduled' | 'project_updated'
  actor: string
  actorAvatar?: string
  actorRole: string
  action: string
  target?: string
  targetUrl?: string
  description?: string
  timestamp: Date
  metadata?: {
    priority?: string
    status?: string
    assignee?: string
    dueDate?: Date
    attachmentCount?: number
    commentCount?: number
    likes?: number
    [key: string]: any
  }
  isRead: boolean
}

const mockActivities: ActivityItem[] = [
  {
    id: '1',
    type: 'task_completed',
    actor: 'Mike Johnson',
    actorRole: 'Designer',
    action: 'completed',
    target: 'Landing Page Wireframes',
    targetUrl: '/tasks/landing-wireframes',
    description: 'Finished all wireframes for the summer campaign landing page',
    timestamp: new Date('2024-01-15T14:30:00Z'),
    metadata: {
      priority: 'high',
      status: 'completed'
    },
    isRead: false
  },
  {
    id: '2',
    type: 'comment_added',
    actor: 'Sarah Wilson',
    actorRole: 'Content Creator',
    action: 'commented on',
    target: 'Email Campaign Copy',
    targetUrl: '/tasks/email-copy',
    description: 'Added feedback on the subject line variations',
    timestamp: new Date('2024-01-15T13:45:00Z'),
    metadata: {
      commentCount: 1
    },
    isRead: false
  },
  {
    id: '3',
    type: 'task_assigned',
    actor: 'Lisa Brown',
    actorRole: 'Marketing Director',
    action: 'assigned',
    target: 'Q1 Strategy Review',
    targetUrl: '/tasks/q1-strategy',
    description: 'Assigned David Lee to review and update Q1 marketing strategy',
    timestamp: new Date('2024-01-15T12:20:00Z'),
    metadata: {
      assignee: 'David Lee',
      dueDate: new Date('2024-01-20T17:00:00Z'),
      priority: 'urgent'
    },
    isRead: true
  },
  {
    id: '4',
    type: 'approval_given',
    actor: 'John Doe',
    actorRole: 'Marketing Manager',
    action: 'approved',
    target: 'Social Media Assets',
    targetUrl: '/approvals/social-assets',
    description: 'Approved the Instagram post designs for February campaign',
    timestamp: new Date('2024-01-15T11:15:00Z'),
    metadata: {
      status: 'approved'
    },
    isRead: true
  },
  {
    id: '5',
    type: 'file_uploaded',
    actor: 'David Lee',
    actorRole: 'Copywriter',
    action: 'uploaded',
    target: 'Brand Guidelines v2.1',
    targetUrl: '/files/brand-guidelines',
    description: 'Updated brand guidelines with new logo variations',
    timestamp: new Date('2024-01-15T10:30:00Z'),
    metadata: {
      attachmentCount: 3
    },
    isRead: true
  },
  {
    id: '6',
    type: 'milestone_reached',
    actor: 'Team Marketing',
    actorRole: 'Team',
    action: 'reached milestone',
    target: '100 Tasks Completed',
    description: 'The team has completed 100 tasks this quarter!',
    timestamp: new Date('2024-01-15T09:45:00Z'),
    metadata: {
      likes: 12
    },
    isRead: true
  },
  {
    id: '7',
    type: 'meeting_scheduled',
    actor: 'Lisa Brown',
    actorRole: 'Marketing Director',
    action: 'scheduled',
    target: 'Campaign Review Meeting',
    targetUrl: '/calendar/campaign-review',
    description: 'Weekly campaign review meeting for January 18th',
    timestamp: new Date('2024-01-15T08:20:00Z'),
    metadata: {
      dueDate: new Date('2024-01-18T14:00:00Z')
    },
    isRead: true
  },
  {
    id: '8',
    type: 'approval_requested',
    actor: 'Sarah Wilson',
    actorRole: 'Content Creator',
    action: 'requested approval for',
    target: 'Blog Post Draft',
    targetUrl: '/approvals/blog-post',
    description: 'New blog post about summer product features ready for review',
    timestamp: new Date('2024-01-14T16:10:00Z'),
    metadata: {
      priority: 'medium',
      status: 'pending'
    },
    isRead: true
  },
  {
    id: '9',
    type: 'team_joined',
    actor: 'Alex Chen',
    actorRole: 'Junior Designer',
    action: 'joined',
    target: 'Marketing Team',
    description: 'Welcome our new team member!',
    timestamp: new Date('2024-01-14T14:30:00Z'),
    isRead: true
  },
  {
    id: '10',
    type: 'project_updated',
    actor: 'Mike Johnson',
    actorRole: 'Designer',
    action: 'updated',
    target: 'Summer Campaign Project',
    targetUrl: '/projects/summer-campaign',
    description: 'Updated project timeline and added new design milestones',
    timestamp: new Date('2024-01-14T13:45:00Z'),
    isRead: true
  }
]

const getActivityIcon = (type: string) => {
  switch (type) {
    case 'task_completed':
      return <CheckCircle className="h-4 w-4 text-green-600" />
    case 'task_assigned':
      return <Target className="h-4 w-4 text-blue-600" />
    case 'comment_added':
      return <MessageSquare className="h-4 w-4 text-purple-600" />
    case 'file_uploaded':
      return <Upload className="h-4 w-4 text-orange-600" />
    case 'approval_requested':
      return <Clock className="h-4 w-4 text-yellow-600" />
    case 'approval_given':
      return <CheckCircle className="h-4 w-4 text-green-600" />
    case 'team_joined':
      return <UserPlus className="h-4 w-4 text-blue-600" />
    case 'milestone_reached':
      return <Award className="h-4 w-4 text-yellow-600" />
    case 'meeting_scheduled':
      return <Calendar className="h-4 w-4 text-indigo-600" />
    case 'project_updated':
      return <GitCommit className="h-4 w-4 text-gray-600" />
    default:
      return <Activity className="h-4 w-4 text-gray-600" />
  }
}

const getActivityColor = (type: string) => {
  switch (type) {
    case 'task_completed':
      return 'bg-green-50 border-green-200'
    case 'task_assigned':
      return 'bg-blue-50 border-blue-200'
    case 'comment_added':
      return 'bg-purple-50 border-purple-200'
    case 'file_uploaded':
      return 'bg-orange-50 border-orange-200'
    case 'approval_requested':
      return 'bg-yellow-50 border-yellow-200'
    case 'approval_given':
      return 'bg-green-50 border-green-200'
    case 'team_joined':
      return 'bg-blue-50 border-blue-200'
    case 'milestone_reached':
      return 'bg-yellow-50 border-yellow-200'
    case 'meeting_scheduled':
      return 'bg-indigo-50 border-indigo-200'
    case 'project_updated':
      return 'bg-gray-50 border-gray-200'
    default:
      return 'bg-gray-50 border-gray-200'
  }
}

export const TeamActivityFeed: React.FC = () => {
  const [activities, setActivities] = useState<ActivityItem[]>(mockActivities)
  const [filter, setFilter] = useState<string>('all')
  const [loading, setLoading] = useState(false)

  const filteredActivities = activities.filter(activity => {
    if (filter === 'all') return true
    if (filter === 'unread') return !activity.isRead
    return activity.type === filter
  })

  const handleRefresh = async () => {
    setLoading(true)
    // Simulate refresh
    setTimeout(() => {
      setLoading(false)
    }, 1000)
  }

  const markAsRead = (activityId: string) => {
    setActivities(prev => 
      prev.map(activity => 
        activity.id === activityId 
          ? { ...activity, isRead: true }
          : activity
      )
    )
  }

  const markAllAsRead = () => {
    setActivities(prev => 
      prev.map(activity => ({ ...activity, isRead: true }))
    )
  }

  const handleLike = (activityId: string) => {
    setActivities(prev => 
      prev.map(activity => 
        activity.id === activityId 
          ? { 
              ...activity, 
              metadata: { 
                ...activity.metadata, 
                likes: (activity.metadata?.likes || 0) + 1 
              }
            }
          : activity
      )
    )
  }

  const unreadCount = activities.filter(a => !a.isRead).length

  return (
    <div className="space-y-4">
      {/* Header Controls */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <h3 className="font-medium">Team Activity</h3>
          {unreadCount > 0 && (
            <Badge variant="destructive">{unreadCount}</Badge>
          )}
        </div>
        
        <div className="flex items-center gap-2">
          <Select value={filter} onValueChange={setFilter}>
            <SelectTrigger className="w-[140px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Activity</SelectItem>
              <SelectItem value="unread">Unread</SelectItem>
              <SelectItem value="task_completed">Tasks</SelectItem>
              <SelectItem value="comment_added">Comments</SelectItem>
              <SelectItem value="approval_requested">Approvals</SelectItem>
              <SelectItem value="file_uploaded">Files</SelectItem>
              <SelectItem value="milestone_reached">Milestones</SelectItem>
            </SelectContent>
          </Select>
          
          <Button 
            variant="outline" 
            size="sm"
            onClick={handleRefresh}
            disabled={loading}
          >
            <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          </Button>
          
          {unreadCount > 0 && (
            <Button variant="outline" size="sm" onClick={markAllAsRead}>
              <Eye className="h-4 w-4 mr-1" />
              Mark All Read
            </Button>
          )}
        </div>
      </div>

      {/* Activity Feed */}
      <ScrollArea className="h-[500px]">
        <div className="space-y-3">
          {filteredActivities.length === 0 ? (
            <div className="text-center py-8">
              <Activity className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
              <h3 className="text-lg font-medium mb-2">No activity found</h3>
              <p className="text-muted-foreground">
                {filter === 'unread' ? 'All activities have been read.' : 'No activities match your filter.'}
              </p>
            </div>
          ) : (
            filteredActivities.map((activity, index) => (
              <div key={activity.id}>
                <div 
                  className={`p-4 rounded-lg border transition-colors cursor-pointer ${
                    getActivityColor(activity.type)
                  } ${
                    !activity.isRead ? 'shadow-sm' : 'opacity-75'
                  }`}
                  onClick={() => !activity.isRead && markAsRead(activity.id)}
                >
                  <div className="flex items-start gap-3">
                    {/* Actor Avatar */}
                    <Avatar className="h-8 w-8 mt-1">
                      <AvatarFallback className="text-xs">
                        {activity.actor.split(' ').map(n => n[0]).join('')}
                      </AvatarFallback>
                    </Avatar>

                    {/* Activity Content */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between">
                        <div className="flex-1 min-w-0">
                          {/* Activity Description */}
                          <div className="flex items-center gap-2 mb-1">
                            {getActivityIcon(activity.type)}
                            <span className={`text-sm ${!activity.isRead ? 'font-medium' : ''}`}>
                              <span className="font-medium">{activity.actor}</span>
                              <span className="mx-1">{activity.action}</span>
                              {activity.target && (
                                <span className="font-medium">{activity.target}</span>
                              )}
                            </span>
                          </div>

                          {/* Additional Description */}
                          {activity.description && (
                            <p className="text-sm text-muted-foreground mb-2">
                              {activity.description}
                            </p>
                          )}

                          {/* Metadata */}
                          <div className="flex items-center gap-3 text-xs text-muted-foreground">
                            <span>{formatDistanceToNow(activity.timestamp, { addSuffix: true })}</span>
                            <span>•</span>
                            <span>{activity.actorRole}</span>
                            
                            {activity.metadata?.priority && (
                              <>
                                <span>•</span>
                                <Badge 
                                  variant={
                                    activity.metadata.priority === 'urgent' ? 'destructive' :
                                    activity.metadata.priority === 'high' ? 'default' :
                                    'secondary'
                                  }
                                  className="text-xs"
                                >
                                  {activity.metadata.priority}
                                </Badge>
                              </>
                            )}
                            
                            {activity.metadata?.assignee && (
                              <>
                                <span>•</span>
                                <span>to {activity.metadata.assignee}</span>
                              </>
                            )}
                            
                            {activity.metadata?.dueDate && (
                              <>
                                <span>•</span>
                                <span>due {formatDistanceToNow(activity.metadata.dueDate, { addSuffix: true })}</span>
                              </>
                            )}
                          </div>

                          {/* Action Buttons */}
                          <div className="flex items-center gap-2 mt-3">
                            {activity.targetUrl && (
                              <Button variant="outline" size="sm" className="h-7 text-xs">
                                <ExternalLink className="h-3 w-3 mr-1" />
                                View
                              </Button>
                            )}
                            
                            {activity.type === 'milestone_reached' && (
                              <Button 
                                variant="outline" 
                                size="sm" 
                                className="h-7 text-xs"
                                onClick={(e) => {
                                  e.stopPropagation()
                                  handleLike(activity.id)
                                }}
                              >
                                <ThumbsUp className="h-3 w-3 mr-1" />
                                {activity.metadata?.likes || 0}
                              </Button>
                            )}
                            
                            {activity.metadata?.commentCount && (
                              <Button variant="outline" size="sm" className="h-7 text-xs">
                                <MessageSquare className="h-3 w-3 mr-1" />
                                {activity.metadata.commentCount}
                              </Button>
                            )}
                            
                            {activity.metadata?.attachmentCount && (
                              <Button variant="outline" size="sm" className="h-7 text-xs">
                                <Paperclip className="h-3 w-3 mr-1" />
                                {activity.metadata.attachmentCount}
                              </Button>
                            )}
                          </div>
                        </div>

                        {/* Unread Indicator */}
                        {!activity.isRead && (
                          <div className="w-2 h-2 bg-blue-500 rounded-full mt-2 ml-2" />
                        )}
                      </div>
                    </div>
                  </div>
                </div>
                
                {index < filteredActivities.length - 1 && (
                  <div className="relative">
                    <div className="absolute left-6 top-0 w-px h-3 bg-border" />
                  </div>
                )}
              </div>
            ))
          )}
        </div>
      </ScrollArea>

      {/* Load More */}
      {filteredActivities.length >= 10 && (
        <div className="text-center pt-4">
          <Button variant="outline" size="sm">
            Load More Activities
          </Button>
        </div>
      )}
    </div>
  )
}

export default TeamActivityFeed