'use client'

import React, { useState } from 'react'
import { Comment, User, UserRole } from '@/types'
import { validateComponentAccess } from '@/lib/permissions'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger } from '@/components/ui/alert-dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { 
  Shield, 
  Flag, 
  Eye, 
  EyeOff, 
  Trash2, 
  CheckCircle, 
  XCircle,
  MessageCircle,
  UserCheck,
  Users,
  Filter,
  Search,
  MoreVertical
} from 'lucide-react'
import { formatDistanceToNow } from 'date-fns'

export interface CommentModerationProps {
  comments: Comment[]
  currentUser: User
  onApproveComment: (commentId: string) => Promise<void>
  onRejectComment: (commentId: string, reason: string) => Promise<void>
  onHideComment: (commentId: string) => Promise<void>
  onShowComment: (commentId: string) => Promise<void>
  onDeleteComment: (commentId: string) => Promise<void>
  onResolveComment: (commentId: string) => Promise<void>
  onFlagComment: (commentId: string, reason: string) => Promise<void>
  isLoading?: boolean
}

interface ModerationAction {
  type: 'approve' | 'reject' | 'hide' | 'show' | 'delete' | 'resolve' | 'flag'
  label: string
  description: string
  variant: 'default' | 'destructive' | 'secondary'
  icon: React.ReactNode
}

const ModerationActions: ModerationAction[] = [
  {
    type: 'approve',
    label: 'Approve',
    description: 'Mark comment as approved and visible',
    variant: 'default',
    icon: <CheckCircle className="h-4 w-4" />
  },
  {
    type: 'reject',
    label: 'Reject',
    description: 'Reject comment with reason',
    variant: 'destructive',
    icon: <XCircle className="h-4 w-4" />
  },
  {
    type: 'hide',
    label: 'Hide',
    description: 'Hide comment from public view',
    variant: 'secondary',
    icon: <EyeOff className="h-4 w-4" />
  },
  {
    type: 'show',
    label: 'Show',
    description: 'Make hidden comment visible',
    variant: 'default',
    icon: <Eye className="h-4 w-4" />
  },
  {
    type: 'resolve',
    label: 'Resolve',
    description: 'Mark discussion as resolved',
    variant: 'default',
    icon: <CheckCircle className="h-4 w-4" />
  },
  {
    type: 'delete',
    label: 'Delete',
    description: 'Permanently delete comment',
    variant: 'destructive',
    icon: <Trash2 className="h-4 w-4" />
  },
  {
    type: 'flag',
    label: 'Flag',
    description: 'Flag comment for review',
    variant: 'destructive',
    icon: <Flag className="h-4 w-4" />
  }
]

interface CommentFilters {
  status: 'all' | 'pending' | 'approved' | 'rejected' | 'flagged' | 'resolved'
  author: string
  dateRange: 'all' | 'today' | 'week' | 'month'
  search: string
}

interface ModerationItemProps {
  comment: Comment
  currentUser: User
  onAction: (commentId: string, action: string, data?: any) => void
}

const ModerationItem: React.FC<ModerationItemProps> = ({
  comment,
  currentUser,
  onAction
}) => {
  const [actionReason, setActionReason] = useState('')
  const [selectedAction, setSelectedAction] = useState<string | null>(null)

  const getStatusBadge = (comment: Comment) => {
    if (comment.isDeleted) return <Badge variant="destructive">Deleted</Badge>
    if (comment.isResolved) return <Badge variant="default">Resolved</Badge>
    // Add more status checks based on your approval system
    return <Badge variant="secondary">Active</Badge>
  }

  const handleAction = (actionType: string) => {
    setSelectedAction(actionType)
  }

  const confirmAction = () => {
    if (!selectedAction) return

    const actionData = ['reject', 'flag'].includes(selectedAction) 
      ? { reason: actionReason }
      : undefined

    onAction(comment.id, selectedAction, actionData)
    setSelectedAction(null)
    setActionReason('')
  }

  const needsReason = selectedAction && ['reject', 'flag'].includes(selectedAction)

  return (
    <Card className="mb-4">
      <CardContent className="pt-4">
        <div className="flex gap-4">
          <Avatar className="h-10 w-10">
            <AvatarImage src={comment.author.avatar} />
            <AvatarFallback>
              {comment.author.name?.split(' ').map(n => n[0]).join('') || 'U'}
            </AvatarFallback>
          </Avatar>
          
          <div className="flex-1 space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="font-medium">{comment.author.name}</span>
                <span className="text-sm text-muted-foreground">
                  {formatDistanceToNow(comment.createdAt, { addSuffix: true })}
                </span>
                {getStatusBadge(comment)}
              </div>
              
              <div className="flex items-center gap-2">
                <Badge variant="outline" className="text-xs">
                  {comment.targetType.toLowerCase()}
                </Badge>
                <Select onValueChange={handleAction}>
                  <SelectTrigger className="w-32 h-8">
                    <SelectValue placeholder="Actions" />
                  </SelectTrigger>
                  <SelectContent>
                    {ModerationActions.map((action) => (
                      <SelectItem key={action.type} value={action.type}>
                        <div className="flex items-center gap-2">
                          {action.icon}
                          {action.label}
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
            
            <div className="bg-muted/50 rounded-lg p-3">
              <p className="text-sm">{comment.content}</p>
            </div>
            
            {comment.reactions.length > 0 && (
              <div className="flex items-center gap-2">
                <MessageCircle className="h-4 w-4 text-muted-foreground" />
                <span className="text-sm text-muted-foreground">
                  {comment.reactions.length} reactions
                </span>
              </div>
            )}
          </div>
        </div>
        
        {/* Action Confirmation Dialog */}
        <AlertDialog open={!!selectedAction} onOpenChange={() => setSelectedAction(null)}>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>
                Confirm {ModerationActions.find(a => a.type === selectedAction)?.label}
              </AlertDialogTitle>
              <AlertDialogDescription>
                {ModerationActions.find(a => a.type === selectedAction)?.description}
              </AlertDialogDescription>
            </AlertDialogHeader>
            
            {needsReason && (
              <div className="space-y-2">
                <label className="text-sm font-medium">Reason (required)</label>
                <Textarea
                  value={actionReason}
                  onChange={(e) => setActionReason(e.target.value)}
                  placeholder="Provide a reason for this action..."
                  className="min-h-[80px]"
                />
              </div>
            )}
            
            <AlertDialogFooter>
              <AlertDialogCancel onClick={() => setSelectedAction(null)}>
                Cancel
              </AlertDialogCancel>
              <AlertDialogAction 
                onClick={confirmAction}
                disabled={needsReason && !actionReason.trim()}
              >
                Confirm
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </CardContent>
    </Card>
  )
}

export const CommentModeration: React.FC<CommentModerationProps> = ({
  comments,
  currentUser,
  onApproveComment,
  onRejectComment,
  onHideComment,
  onShowComment,
  onDeleteComment,
  onResolveComment,
  onFlagComment,
  isLoading = false
}) => {
  const [filters, setFilters] = useState<CommentFilters>({
    status: 'all',
    author: '',
    dateRange: 'all',
    search: ''
  })

  // Check if user can moderate
  const canModerate = validateComponentAccess(currentUser.role, 'canConfigureWorkflow')

  if (!canModerate) {
    return (
      <Card>
        <CardContent className="pt-6">
          <div className="text-center text-muted-foreground">
            <Shield className="h-12 w-12 mx-auto mb-4 opacity-50" />
            <p>You don't have permission to moderate comments.</p>
          </div>
        </CardContent>
      </Card>
    )
  }

  const handleModerationAction = async (commentId: string, action: string, data?: any) => {
    try {
      switch (action) {
        case 'approve':
          await onApproveComment(commentId)
          break
        case 'reject':
          await onRejectComment(commentId, data?.reason || '')
          break
        case 'hide':
          await onHideComment(commentId)
          break
        case 'show':
          await onShowComment(commentId)
          break
        case 'delete':
          await onDeleteComment(commentId)
          break
        case 'resolve':
          await onResolveComment(commentId)
          break
        case 'flag':
          await onFlagComment(commentId, data?.reason || '')
          break
      }
    } catch (error) {
      console.error('Moderation action failed:', error)
    }
  }

  // Filter comments based on current filters
  const filteredComments = comments.filter(comment => {
    // Status filter
    if (filters.status !== 'all') {
      switch (filters.status) {
        case 'resolved':
          if (!comment.isResolved) return false
          break
        case 'flagged':
          // Add logic for flagged comments
          break
        // Add more status filters as needed
      }
    }

    // Author filter
    if (filters.author && !comment.author.name?.toLowerCase().includes(filters.author.toLowerCase())) {
      return false
    }

    // Search filter
    if (filters.search && !comment.content.toLowerCase().includes(filters.search.toLowerCase())) {
      return false
    }

    // Date range filter
    if (filters.dateRange !== 'all') {
      const now = new Date()
      const commentDate = new Date(comment.createdAt)
      
      switch (filters.dateRange) {
        case 'today':
          if (commentDate.toDateString() !== now.toDateString()) return false
          break
        case 'week':
          const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
          if (commentDate < weekAgo) return false
          break
        case 'month':
          const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
          if (commentDate < monthAgo) return false
          break
      }
    }

    return true
  })

  const stats = {
    total: comments.length,
    resolved: comments.filter(c => c.isResolved).length,
    deleted: comments.filter(c => c.isDeleted).length,
    thisWeek: comments.filter(c => {
      const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
      return new Date(c.createdAt) > weekAgo
    }).length
  }

  if (isLoading) {
    return (
      <Card>
        <CardContent className="pt-6">
          <div className="animate-pulse space-y-4">
            <div className="h-8 bg-muted rounded w-1/3"></div>
            <div className="h-32 bg-muted rounded"></div>
            <div className="h-32 bg-muted rounded"></div>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Shield className="h-5 w-5" />
            Comment Moderation
          </CardTitle>
          <CardDescription>
            Manage and moderate user comments across your platform
          </CardDescription>
        </CardHeader>
        
        <CardContent>
          {/* Statistics */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
            <div className="text-center">
              <div className="text-2xl font-bold">{stats.total}</div>
              <div className="text-sm text-muted-foreground">Total Comments</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold">{stats.thisWeek}</div>
              <div className="text-sm text-muted-foreground">This Week</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold">{stats.resolved}</div>
              <div className="text-sm text-muted-foreground">Resolved</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold">{stats.deleted}</div>
              <div className="text-sm text-muted-foreground">Deleted</div>
            </div>
          </div>
          
          {/* Filters */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 h-4 w-4 transform -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search comments..."
                value={filters.search}
                onChange={(e) => setFilters({...filters, search: e.target.value})}
                className="pl-10"
              />
            </div>
            
            <Select
              value={filters.status}
              onValueChange={(value: any) => setFilters({...filters, status: value})}
            >
              <SelectTrigger>
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Status</SelectItem>
                <SelectItem value="pending">Pending</SelectItem>
                <SelectItem value="approved">Approved</SelectItem>
                <SelectItem value="rejected">Rejected</SelectItem>
                <SelectItem value="flagged">Flagged</SelectItem>
                <SelectItem value="resolved">Resolved</SelectItem>
              </SelectContent>
            </Select>
            
            <Select
              value={filters.dateRange}
              onValueChange={(value: any) => setFilters({...filters, dateRange: value})}
            >
              <SelectTrigger>
                <SelectValue placeholder="Date Range" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Time</SelectItem>
                <SelectItem value="today">Today</SelectItem>
                <SelectItem value="week">This Week</SelectItem>
                <SelectItem value="month">This Month</SelectItem>
              </SelectContent>
            </Select>
            
            <Input
              placeholder="Filter by author..."
              value={filters.author}
              onChange={(e) => setFilters({...filters, author: e.target.value})}
            />
          </div>
        </CardContent>
      </Card>
      
      {/* Comments List */}
      <div>
        {filteredComments.length === 0 ? (
          <Card>
            <CardContent className="pt-6">
              <div className="text-center py-8 text-muted-foreground">
                <MessageCircle className="h-12 w-12 mx-auto mb-4 opacity-50" />
                <p>No comments match your filters</p>
              </div>
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-4">
            {filteredComments.map((comment) => (
              <ModerationItem
                key={comment.id}
                comment={comment}
                currentUser={currentUser}
                onAction={handleModerationAction}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

export default CommentModeration