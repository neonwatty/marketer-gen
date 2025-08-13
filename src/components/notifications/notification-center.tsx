'use client'

import React, { useState, useEffect } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Checkbox } from '@/components/ui/checkbox'
import { Separator } from '@/components/ui/separator'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import {
  Bell,
  BellOff,
  Check,
  CheckCheck,
  Filter,
  MoreHorizontal,
  Search,
  Settings,
  Trash2,
  Archive,
  Eye,
  EyeOff,
  ExternalLink,
  Clock,
  User,
  MessageSquare,
  FileText,
  AlertTriangle,
  Shield,
  Download,
  Mail,
  Smartphone,
  Monitor,
  X
} from 'lucide-react'
import { formatDistanceToNow } from 'date-fns'

export interface Notification {
  id: string
  type: string
  category: string
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT'
  title: string
  message: string
  actionText?: string
  actionUrl?: string
  senderId?: string
  senderName?: string
  status: 'PENDING' | 'DELIVERED' | 'READ' | 'FAILED'
  readAt?: Date
  createdAt: Date
  entityType?: string
  entityId?: string
  metadata?: any
  expiresAt?: Date
}

const mockNotifications: Notification[] = [
  {
    id: '1',
    type: 'MENTION',
    category: 'COLLABORATION',
    priority: 'HIGH',
    title: 'John mentioned you',
    message: 'John mentioned you in Summer Campaign: "What do you think about this approach?"',
    actionText: 'View',
    actionUrl: '/campaigns/summer-2024',
    senderId: 'user_123',
    senderName: 'John Doe',
    status: 'DELIVERED',
    createdAt: new Date('2024-01-15T10:30:00Z'),
    entityType: 'campaign',
    entityId: 'camp_123'
  },
  {
    id: '2',
    type: 'APPROVAL_REQUEST',
    category: 'APPROVAL',
    priority: 'HIGH',
    title: 'Approval needed: Email Template',
    message: 'Sarah submitted "Welcome Email Template" for approval in Content Review (Final Review)',
    actionText: 'Review',
    actionUrl: '/content/email-123/review',
    senderId: 'user_456',
    senderName: 'Sarah Smith',
    status: 'DELIVERED',
    createdAt: new Date('2024-01-15T09:45:00Z'),
    entityType: 'content',
    entityId: 'content_123'
  },
  {
    id: '3',
    type: 'ASSIGNMENT',
    category: 'COLLABORATION',
    priority: 'HIGH',
    title: 'New assignment: Q1 Campaign Strategy',
    message: 'Mike assigned you to Q1 Campaign Strategy (due January 25, 2024)',
    actionText: 'View Task',
    actionUrl: '/tasks/task-456',
    senderId: 'user_789',
    senderName: 'Mike Wilson',
    status: 'READ',
    readAt: new Date('2024-01-15T08:30:00Z'),
    createdAt: new Date('2024-01-15T08:15:00Z'),
    entityType: 'task',
    entityId: 'task_456'
  },
  {
    id: '4',
    type: 'COMMENT',
    category: 'COLLABORATION',
    priority: 'MEDIUM',
    title: 'New comment on Summer Campaign',
    message: 'Lisa commented: "I have some feedback on the color scheme"',
    actionText: 'View',
    actionUrl: '/campaigns/summer-2024#comments',
    senderId: 'user_101',
    senderName: 'Lisa Brown',
    status: 'DELIVERED',
    createdAt: new Date('2024-01-15T07:30:00Z'),
    entityType: 'campaign',
    entityId: 'camp_123'
  },
  {
    id: '5',
    type: 'SECURITY_ALERT',
    category: 'SECURITY',
    priority: 'URGENT',
    title: 'Unusual login activity',
    message: 'New login from unrecognized device (Chrome on Windows)',
    actionText: 'Review',
    actionUrl: '/security/sessions',
    status: 'DELIVERED',
    createdAt: new Date('2024-01-14T22:15:00Z')
  }
]

const getNotificationIcon = (type: string, category: string) => {
  switch (type) {
    case 'MENTION':
      return <User className="h-4 w-4" />
    case 'COMMENT':
      return <MessageSquare className="h-4 w-4" />
    case 'ASSIGNMENT':
      return <FileText className="h-4 w-4" />
    case 'APPROVAL_REQUEST':
    case 'APPROVAL_RESPONSE':
      return <Check className="h-4 w-4" />
    case 'SECURITY_ALERT':
      return <Shield className="h-4 w-4" />
    case 'SYSTEM_ALERT':
      return <AlertTriangle className="h-4 w-4" />
    default:
      return <Bell className="h-4 w-4" />
  }
}

const getPriorityColor = (priority: string) => {
  switch (priority) {
    case 'URGENT':
      return 'destructive'
    case 'HIGH':
      return 'default'
    case 'MEDIUM':
      return 'secondary'
    case 'LOW':
      return 'outline'
    default:
      return 'secondary'
  }
}

export const NotificationCenter: React.FC = () => {
  const [notifications, setNotifications] = useState<Notification[]>(mockNotifications)
  const [selectedNotifications, setSelectedNotifications] = useState<string[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [filterType, setFilterType] = useState<string>('all')
  const [filterStatus, setFilterStatus] = useState<string>('all')
  const [filterPriority, setFilterPriority] = useState<string>('all')
  const [showFilters, setShowFilters] = useState(false)
  const [activeTab, setActiveTab] = useState('all')

  const filteredNotifications = notifications.filter(notification => {
    const matchesSearch = searchQuery === '' || 
      notification.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      notification.message.toLowerCase().includes(searchQuery.toLowerCase()) ||
      notification.senderName?.toLowerCase().includes(searchQuery.toLowerCase())

    const matchesType = filterType === 'all' || notification.type === filterType
    const matchesStatus = filterStatus === 'all' || notification.status === filterStatus
    const matchesPriority = filterPriority === 'all' || notification.priority === filterPriority

    const matchesTab = activeTab === 'all' || 
      (activeTab === 'unread' && !notification.readAt) ||
      (activeTab === 'mentions' && notification.type === 'MENTION') ||
      (activeTab === 'assignments' && notification.type === 'ASSIGNMENT')

    return matchesSearch && matchesType && matchesStatus && matchesPriority && matchesTab
  })

  const unreadCount = notifications.filter(n => !n.readAt).length

  const handleNotificationClick = async (notification: Notification) => {
    if (!notification.readAt) {
      await markAsRead(notification.id)
    }
    
    if (notification.actionUrl) {
      window.open(notification.actionUrl, '_blank')
    }
  }

  const markAsRead = async (notificationId: string) => {
    setNotifications(prev => 
      prev.map(n => 
        n.id === notificationId 
          ? { ...n, status: 'READ' as const, readAt: new Date() }
          : n
      )
    )
  }

  const markAllAsRead = async () => {
    setNotifications(prev => 
      prev.map(n => ({ ...n, status: 'read' as const, readAt: new Date() }))
    )
  }

  const deleteNotification = async (notificationId: string) => {
    setNotifications(prev => prev.filter(n => n.id !== notificationId))
  }

  const deleteSelected = async () => {
    setNotifications(prev => prev.filter(n => !selectedNotifications.includes(n.id)))
    setSelectedNotifications([])
  }

  const markSelectedAsRead = async () => {
    setNotifications(prev => 
      prev.map(n => 
        selectedNotifications.includes(n.id)
          ? { ...n, status: 'read' as const, readAt: new Date() }
          : n
      )
    )
    setSelectedNotifications([])
  }

  const toggleSelection = (notificationId: string) => {
    setSelectedNotifications(prev => 
      prev.includes(notificationId)
        ? prev.filter(id => id !== notificationId)
        : [...prev, notificationId]
    )
  }

  const selectAll = () => {
    setSelectedNotifications(filteredNotifications.map(n => n.id))
  }

  const clearSelection = () => {
    setSelectedNotifications([])
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight flex items-center gap-2">
            <Bell className="h-8 w-8" />
            Notifications
            {unreadCount > 0 && (
              <Badge variant="destructive" className="ml-2">
                {unreadCount}
              </Badge>
            )}
          </h1>
          <p className="text-muted-foreground">
            Stay updated with all your notifications and activities
          </p>
        </div>

        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => setShowFilters(!showFilters)}
          >
            <Filter className="h-4 w-4 mr-2" />
            Filters
          </Button>
          <Button variant="outline" size="sm">
            <Settings className="h-4 w-4 mr-2" />
            Settings
          </Button>
          {unreadCount > 0 && (
            <Button size="sm" onClick={markAllAsRead}>
              <CheckCheck className="h-4 w-4 mr-2" />
              Mark All Read
            </Button>
          )}
        </div>
      </div>

      {/* Filters */}
      {showFilters && (
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Filter Notifications</CardTitle>
            <CardDescription>Refine your notification view</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div className="space-y-2">
                <Label>Search</Label>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <Input
                    placeholder="Search notifications..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="pl-10"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <Label>Type</Label>
                <Select value={filterType} onValueChange={setFilterType}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Types</SelectItem>
                    <SelectItem value="MENTION">Mentions</SelectItem>
                    <SelectItem value="COMMENT">Comments</SelectItem>
                    <SelectItem value="ASSIGNMENT">Assignments</SelectItem>
                    <SelectItem value="APPROVAL_REQUEST">Approval Requests</SelectItem>
                    <SelectItem value="SECURITY_ALERT">Security Alerts</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label>Status</Label>
                <Select value={filterStatus} onValueChange={setFilterStatus}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Status</SelectItem>
                    <SelectItem value="DELIVERED">Unread</SelectItem>
                    <SelectItem value="READ">Read</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label>Priority</Label>
                <Select value={filterPriority} onValueChange={setFilterPriority}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Priorities</SelectItem>
                    <SelectItem value="URGENT">Urgent</SelectItem>
                    <SelectItem value="HIGH">High</SelectItem>
                    <SelectItem value="MEDIUM">Medium</SelectItem>
                    <SelectItem value="LOW">Low</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="all">
            All ({notifications.length})
          </TabsTrigger>
          <TabsTrigger value="unread">
            Unread ({unreadCount})
          </TabsTrigger>
          <TabsTrigger value="mentions">
            Mentions ({notifications.filter(n => n.type === 'MENTION').length})
          </TabsTrigger>
          <TabsTrigger value="assignments">
            Assignments ({notifications.filter(n => n.type === 'ASSIGNMENT').length})
          </TabsTrigger>
        </TabsList>

        <TabsContent value={activeTab} className="space-y-4">
          {/* Bulk Actions */}
          {selectedNotifications.length > 0 && (
            <Card>
              <CardContent className="pt-6">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium">
                      {selectedNotifications.length} selected
                    </span>
                    <Button variant="outline" size="sm" onClick={clearSelection}>
                      <X className="h-4 w-4 mr-2" />
                      Clear
                    </Button>
                  </div>
                  <div className="flex items-center gap-2">
                    <Button size="sm" onClick={markSelectedAsRead}>
                      <Check className="h-4 w-4 mr-2" />
                      Mark Read
                    </Button>
                    <Button variant="outline" size="sm" onClick={deleteSelected}>
                      <Trash2 className="h-4 w-4 mr-2" />
                      Delete
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}

          {/* Select All */}
          {filteredNotifications.length > 0 && (
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Checkbox
                  checked={selectedNotifications.length === filteredNotifications.length}
                  onCheckedChange={(checked) => {
                    if (checked) {
                      selectAll()
                    } else {
                      clearSelection()
                    }
                  }}
                />
                <Label className="text-sm">Select all</Label>
              </div>
              <div className="text-sm text-muted-foreground">
                {filteredNotifications.length} notifications
              </div>
            </div>
          )}

          {/* Notifications List */}
          <ScrollArea className="h-[600px]">
            <div className="space-y-2">
              {filteredNotifications.length === 0 ? (
                <Card>
                  <CardContent className="py-12 text-center">
                    <BellOff className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
                    <h3 className="text-lg font-medium mb-2">No notifications found</h3>
                    <p className="text-muted-foreground">
                      {searchQuery || filterType !== 'all' || filterStatus !== 'all' || filterPriority !== 'all'
                        ? 'Try adjusting your filters to see more notifications.'
                        : 'You\'re all caught up! New notifications will appear here.'}
                    </p>
                  </CardContent>
                </Card>
              ) : (
                filteredNotifications.map((notification) => (
                  <Card 
                    key={notification.id}
                    className={`cursor-pointer transition-colors hover:bg-muted/50 ${
                      !notification.readAt ? 'border-l-4 border-l-primary' : ''
                    } ${
                      selectedNotifications.includes(notification.id) ? 'bg-muted/50' : ''
                    }`}
                  >
                    <CardContent className="p-4">
                      <div className="flex items-start gap-3">
                        <Checkbox
                          checked={selectedNotifications.includes(notification.id)}
                          onCheckedChange={() => toggleSelection(notification.id)}
                          onClick={(e) => e.stopPropagation()}
                        />

                        <div className="flex-shrink-0 mt-1">
                          <div className={`w-8 h-8 rounded-full flex items-center justify-center ${
                            notification.priority === 'URGENT' ? 'bg-destructive/10 text-destructive' :
                            notification.priority === 'HIGH' ? 'bg-orange-100 text-orange-600' :
                            'bg-muted text-muted-foreground'
                          }`}>
                            {getNotificationIcon(notification.type, notification.category)}
                          </div>
                        </div>

                        <div 
                          className="flex-1 min-w-0 cursor-pointer"
                          onClick={() => handleNotificationClick(notification)}
                        >
                          <div className="flex items-start justify-between mb-1">
                            <div className="flex items-center gap-2">
                              <h4 className={`text-sm font-medium ${!notification.readAt ? 'font-semibold' : ''}`}>
                                {notification.title}
                              </h4>
                              <Badge 
                                variant={getPriorityColor(notification.priority) as any}
                                className="text-xs"
                              >
                                {notification.priority}
                              </Badge>
                            </div>
                            <div className="flex items-center gap-1">
                              <span className="text-xs text-muted-foreground">
                                {formatDistanceToNow(notification.createdAt, { addSuffix: true })}
                              </span>
                              {!notification.readAt && (
                                <div className="w-2 h-2 bg-primary rounded-full" />
                              )}
                            </div>
                          </div>

                          <p className="text-sm text-muted-foreground mb-2 line-clamp-2">
                            {notification.message}
                          </p>

                          <div className="flex items-center justify-between">
                            <div className="flex items-center gap-4 text-xs text-muted-foreground">
                              {notification.senderName && (
                                <span>from {notification.senderName}</span>
                              )}
                              <Badge variant="outline" className="text-xs">
                                {notification.type.replace('_', ' ')}
                              </Badge>
                            </div>

                            <div className="flex items-center gap-1">
                              {notification.actionUrl && (
                                <Button size="sm" variant="ghost" className="h-6 px-2">
                                  <ExternalLink className="h-3 w-3 mr-1" />
                                  {notification.actionText || 'View'}
                                </Button>
                              )}
                              
                              <DropdownMenu>
                                <DropdownMenuTrigger asChild>
                                  <Button 
                                    size="sm" 
                                    variant="ghost" 
                                    className="h-6 w-6 p-0"
                                    onClick={(e) => e.stopPropagation()}
                                  >
                                    <MoreHorizontal className="h-3 w-3" />
                                  </Button>
                                </DropdownMenuTrigger>
                                <DropdownMenuContent align="end">
                                  {!notification.readAt ? (
                                    <DropdownMenuItem onClick={() => markAsRead(notification.id)}>
                                      <Eye className="h-4 w-4 mr-2" />
                                      Mark as read
                                    </DropdownMenuItem>
                                  ) : (
                                    <DropdownMenuItem>
                                      <EyeOff className="h-4 w-4 mr-2" />
                                      Mark as unread
                                    </DropdownMenuItem>
                                  )}
                                  <DropdownMenuItem>
                                    <Archive className="h-4 w-4 mr-2" />
                                    Archive
                                  </DropdownMenuItem>
                                  <DropdownMenuItem 
                                    onClick={() => deleteNotification(notification.id)}
                                    className="text-destructive"
                                  >
                                    <Trash2 className="h-4 w-4 mr-2" />
                                    Delete
                                  </DropdownMenuItem>
                                </DropdownMenuContent>
                              </DropdownMenu>
                            </div>
                          </div>
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                ))
              )}
            </div>
          </ScrollArea>
        </TabsContent>
      </Tabs>
    </div>
  )
}

export default NotificationCenter