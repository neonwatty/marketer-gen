'use client'

import * as React from 'react'
import {useState } from 'react'

import { AlertTriangle, Calendar, CheckCircle, Clock, FileText,MessageSquare, User, XCircle } from 'lucide-react'

import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Avatar } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Textarea } from '@/components/ui/textarea'
import { ContentStatus, ContentType } from '@/generated/prisma'

export interface ContentReviewComment {
  id: string
  authorId: string
  authorName: string
  authorAvatar?: string
  content: string
  createdAt: Date
  isResolved?: boolean
  parentId?: string // For thread replies
}

export interface ContentReviewItem {
  id: string
  title: string
  content: string
  type: ContentType
  status: ContentStatus
  assignedReviewers: string[]
  comments: ContentReviewComment[]
  createdAt: Date
  updatedAt: Date
  submittedBy: string
  submittedByName: string
  dueDate?: Date
}

interface ContentReviewProps {
  items: ContentReviewItem[]
  currentUserId: string
  onStatusChange: (itemId: string, newStatus: ContentStatus, comment?: string) => void
  onAddComment: (itemId: string, comment: string, parentId?: string) => void
  onResolveComment: (itemId: string, commentId: string) => void
  isLoading?: boolean
}

const statusConfig = {
  [ContentStatus.DRAFT]: { 
    label: 'Draft', 
    color: 'bg-gray-500', 
    icon: FileText 
  },
  [ContentStatus.REVIEW]: { 
    label: 'In Review', 
    color: 'bg-blue-500', 
    icon: Clock 
  },
  [ContentStatus.APPROVED]: { 
    label: 'Approved', 
    color: 'bg-green-500', 
    icon: CheckCircle 
  },
  [ContentStatus.PUBLISHED]: { 
    label: 'Published', 
    color: 'bg-purple-500', 
    icon: CheckCircle 
  },
  [ContentStatus.ARCHIVED]: { 
    label: 'Archived', 
    color: 'bg-gray-400', 
    icon: XCircle 
  }
}

const typeDisplayNames = {
  [ContentType.EMAIL]: 'Email',
  [ContentType.SOCIAL_POST]: 'Social Post',
  [ContentType.SOCIAL_AD]: 'Social Ad',
  [ContentType.SEARCH_AD]: 'Search Ad',
  [ContentType.BLOG_POST]: 'Blog Post',
  [ContentType.LANDING_PAGE]: 'Landing Page',
  [ContentType.VIDEO_SCRIPT]: 'Video Script',
  [ContentType.INFOGRAPHIC]: 'Infographic',
  [ContentType.NEWSLETTER]: 'Newsletter',
  [ContentType.PRESS_RELEASE]: 'Press Release'
}

export function ContentReview({
  items,
  currentUserId,
  onStatusChange,
  onAddComment,
  onResolveComment,
  isLoading = false
}: ContentReviewProps) {
  const [selectedItem, setSelectedItem] = useState<ContentReviewItem | null>(null)
  const [newComment, setNewComment] = useState('')
  const [replyingTo, setReplyingTo] = useState<string | null>(null)
  const [replyContent, setReplyContent] = useState('')
  const [statusChangeComment, setStatusChangeComment] = useState('')
  const [statusChangeDialog, setStatusChangeDialog] = useState<{
    isOpen: boolean
    itemId: string
    newStatus: ContentStatus
  }>({ isOpen: false, itemId: '', newStatus: ContentStatus.DRAFT })

  const filteredItems = items.filter(item => 
    item.assignedReviewers.includes(currentUserId) || item.submittedBy === currentUserId
  )

  const getUrgentItems = () => {
    return filteredItems.filter(item => {
      if (!item.dueDate) return false
      const daysUntilDue = Math.ceil((item.dueDate.getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24))
      return daysUntilDue <= 2 && item.status === ContentStatus.REVIEW
    })
  }

  const urgentItems = getUrgentItems()

  const handleStatusChange = (itemId: string, newStatus: ContentStatus) => {
    if (newStatus === ContentStatus.APPROVED || newStatus === ContentStatus.ARCHIVED) {
      setStatusChangeDialog({ isOpen: true, itemId, newStatus })
    } else {
      onStatusChange(itemId, newStatus)
    }
  }

  const confirmStatusChange = () => {
    onStatusChange(
      statusChangeDialog.itemId, 
      statusChangeDialog.newStatus, 
      statusChangeComment.trim() || undefined
    )
    setStatusChangeDialog({ isOpen: false, itemId: '', newStatus: ContentStatus.DRAFT })
    setStatusChangeComment('')
  }

  const handleAddComment = () => {
    if (selectedItem && newComment.trim()) {
      onAddComment(selectedItem.id, newComment.trim())
      setNewComment('')
    }
  }

  const handleReply = (commentId: string) => {
    if (selectedItem && replyContent.trim()) {
      onAddComment(selectedItem.id, replyContent.trim(), commentId)
      setReplyContent('')
      setReplyingTo(null)
    }
  }

  const getStatusActions = (item: ContentReviewItem) => {
    const actions = []
    
    if (item.status === ContentStatus.REVIEW) {
      actions.push(
        <Button
          key="approve"
          size="sm"
          className="bg-green-600 hover:bg-green-700"
          onClick={() => handleStatusChange(item.id, ContentStatus.APPROVED)}
        >
          Approve
        </Button>
      )
    }
    
    if (item.status !== ContentStatus.ARCHIVED) {
      actions.push(
        <Button
          key="archive"
          size="sm"
          variant="outline"
          className="text-red-600 border-red-600 hover:bg-red-50"
          onClick={() => handleStatusChange(item.id, ContentStatus.ARCHIVED)}
        >
          Archive
        </Button>
      )
    }
    
    return actions
  }

  const formatDate = (date: Date) => {
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    }).format(date)
  }

  if (isLoading) {
    return (
      <Card>
        <CardContent className="p-6">
          <div className="flex items-center justify-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <span className="ml-2 text-muted-foreground">Loading content reviews...</span>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      {/* Urgent Items Alert */}
      {urgentItems.length > 0 && (
        <Alert>
          <AlertTriangle className="h-4 w-4" />
          <AlertTitle>Urgent Reviews Required</AlertTitle>
          <AlertDescription>
            {urgentItems.length} content item{urgentItems.length !== 1 ? 's' : ''} require{urgentItems.length === 1 ? 's' : ''} immediate review. 
            Due dates are approaching within 2 days.
          </AlertDescription>
        </Alert>
      )}

      {/* Content Review List */}
      <Card>
        <CardHeader>
          <CardTitle>Content Review Dashboard</CardTitle>
          <CardDescription>
            Manage content reviews, approvals, and collaboration workflows
          </CardDescription>
        </CardHeader>
        <CardContent>
          {filteredItems.length === 0 ? (
            <div className="text-center py-8">
              <FileText className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <p className="text-muted-foreground mb-2">No content items to review</p>
              <p className="text-sm text-muted-foreground">
                Content assigned to you for review will appear here
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {filteredItems.map((item) => {
                const statusInfo = statusConfig[item.status]
                const StatusIcon = statusInfo.icon
                const isUrgent = urgentItems.some(urgent => urgent.id === item.id)
                const unresolvedComments = item.comments.filter(c => !c.isResolved).length

                return (
                  <Card key={item.id} className={`${isUrgent ? 'border-orange-200 bg-orange-50/50' : ''}`}>
                    <CardContent className="p-4">
                      <div className="flex items-start justify-between">
                        <div className="flex-1">
                          <div className="flex items-center gap-2 mb-2">
                            <h3 className="font-semibold text-lg">{item.title}</h3>
                            <Badge variant="outline" className={`${statusInfo.color} text-white`}>
                              <StatusIcon className="h-3 w-3 mr-1" />
                              {statusInfo.label}
                            </Badge>
                            <Badge variant="secondary">
                              {typeDisplayNames[item.type]}
                            </Badge>
                            {isUrgent && (
                              <Badge variant="destructive" className="bg-orange-500">
                                <Clock className="h-3 w-3 mr-1" />
                                Urgent
                              </Badge>
                            )}
                          </div>

                          <div className="flex items-center gap-4 text-sm text-muted-foreground mb-3">
                            <div className="flex items-center gap-1">
                              <User className="h-4 w-4" />
                              Submitted by {item.submittedByName}
                            </div>
                            <div className="flex items-center gap-1">
                              <Calendar className="h-4 w-4" />
                              {formatDate(item.updatedAt)}
                            </div>
                            {item.dueDate && (
                              <div className="flex items-center gap-1">
                                <Clock className="h-4 w-4" />
                                Due {formatDate(item.dueDate)}
                              </div>
                            )}
                            {unresolvedComments > 0 && (
                              <div className="flex items-center gap-1 text-blue-600">
                                <MessageSquare className="h-4 w-4" />
                                {unresolvedComments} comment{unresolvedComments !== 1 ? 's' : ''}
                              </div>
                            )}
                          </div>

                          <p className="text-sm text-muted-foreground line-clamp-2 mb-3">
                            {item.content.substring(0, 150)}...
                          </p>
                        </div>

                        <div className="flex items-center gap-2 ml-4">
                          <Dialog>
                            <DialogTrigger asChild>
                              <Button 
                                variant="outline" 
                                size="sm"
                                onClick={() => setSelectedItem(item)}
                              >
                                Review
                              </Button>
                            </DialogTrigger>
                            <DialogContent className="max-w-4xl max-h-[80vh]">
                              <DialogHeader>
                                <DialogTitle className="flex items-center gap-2">
                                  {item.title}
                                  <Badge variant="outline" className={`${statusInfo.color} text-white`}>
                                    <StatusIcon className="h-3 w-3 mr-1" />
                                    {statusInfo.label}
                                  </Badge>
                                </DialogTitle>
                                <DialogDescription>
                                  {typeDisplayNames[item.type]} • Submitted by {item.submittedByName}
                                </DialogDescription>
                              </DialogHeader>

                              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 py-4">
                                {/* Content Preview */}
                                <div>
                                  <h4 className="font-medium mb-2">Content</h4>
                                  <ScrollArea className="h-64 w-full border rounded-md p-4">
                                    <div className="whitespace-pre-wrap text-sm">
                                      {item.content}
                                    </div>
                                  </ScrollArea>
                                </div>

                                {/* Comments Thread */}
                                <div>
                                  <h4 className="font-medium mb-2">Comments & Discussion</h4>
                                  <ScrollArea className="h-64 w-full border rounded-md p-4">
                                    <div className="space-y-4">
                                      {item.comments.map((comment) => (
                                        <div key={comment.id} className={`${comment.parentId ? 'ml-6 border-l-2 border-gray-200 pl-3' : ''}`}>
                                          <div className="flex items-start gap-2">
                                            <Avatar className="h-6 w-6">
                                              <div className="h-6 w-6 bg-blue-500 rounded-full flex items-center justify-center text-xs text-white">
                                                {comment.authorName.charAt(0).toUpperCase()}
                                              </div>
                                            </Avatar>
                                            <div className="flex-1 text-sm">
                                              <div className="flex items-center gap-2 mb-1">
                                                <span className="font-medium">{comment.authorName}</span>
                                                <span className="text-muted-foreground text-xs">
                                                  {formatDate(comment.createdAt)}
                                                </span>
                                                {comment.isResolved && (
                                                  <Badge variant="secondary" className="text-xs">Resolved</Badge>
                                                )}
                                              </div>
                                              <p className="text-gray-700">{comment.content}</p>
                                              <div className="flex gap-2 mt-2">
                                                <Button
                                                  variant="ghost"
                                                  size="sm"
                                                  className="text-xs"
                                                  onClick={() => setReplyingTo(comment.id)}
                                                >
                                                  Reply
                                                </Button>
                                                {!comment.isResolved && (
                                                  <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    className="text-xs"
                                                    onClick={() => onResolveComment(item.id, comment.id)}
                                                  >
                                                    Resolve
                                                  </Button>
                                                )}
                                              </div>
                                              {replyingTo === comment.id && (
                                                <div className="mt-2 space-y-2">
                                                  <Textarea
                                                    placeholder="Write a reply..."
                                                    value={replyContent}
                                                    onChange={(e) => setReplyContent(e.target.value)}
                                                    className="text-sm"
                                                  />
                                                  <div className="flex gap-2">
                                                    <Button
                                                      size="sm"
                                                      onClick={() => handleReply(comment.id)}
                                                      disabled={!replyContent.trim()}
                                                    >
                                                      Reply
                                                    </Button>
                                                    <Button
                                                      variant="outline"
                                                      size="sm"
                                                      onClick={() => {
                                                        setReplyingTo(null)
                                                        setReplyContent('')
                                                      }}
                                                    >
                                                      Cancel
                                                    </Button>
                                                  </div>
                                                </div>
                                              )}
                                            </div>
                                          </div>
                                        </div>
                                      ))}
                                    </div>
                                  </ScrollArea>

                                  {/* Add Comment */}
                                  <div className="mt-4 space-y-2">
                                    <Textarea
                                      placeholder="Add a comment..."
                                      value={newComment}
                                      onChange={(e) => setNewComment(e.target.value)}
                                    />
                                    <Button
                                      size="sm"
                                      onClick={handleAddComment}
                                      disabled={!newComment.trim()}
                                    >
                                      Add Comment
                                    </Button>
                                  </div>
                                </div>
                              </div>

                              <DialogFooter>
                                <div className="flex gap-2">
                                  {getStatusActions(item)}
                                </div>
                              </DialogFooter>
                            </DialogContent>
                          </Dialog>

                          {getStatusActions(item)}
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                )
              })}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Status Change Confirmation Dialog */}
      <Dialog open={statusChangeDialog.isOpen} onOpenChange={(open) => {
        if (!open) {
          setStatusChangeDialog({ isOpen: false, itemId: '', newStatus: ContentStatus.DRAFT })
          setStatusChangeComment('')
        }
      }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Confirm Status Change</DialogTitle>
            <DialogDescription>
              Are you sure you want to {statusChangeDialog.newStatus === ContentStatus.APPROVED ? 'approve' : 'archive'} this content?
            </DialogDescription>
          </DialogHeader>
          <div className="py-4">
            <Textarea
              placeholder={`Add a comment about this ${statusChangeDialog.newStatus === ContentStatus.APPROVED ? 'approval' : 'archival'} (optional)`}
              value={statusChangeComment}
              onChange={(e) => setStatusChangeComment(e.target.value)}
            />
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => {
                setStatusChangeDialog({ isOpen: false, itemId: '', newStatus: ContentStatus.DRAFT })
                setStatusChangeComment('')
              }}
            >
              Cancel
            </Button>
            <Button
              onClick={confirmStatusChange}
              className={statusChangeDialog.newStatus === ContentStatus.APPROVED ? 'bg-green-600 hover:bg-green-700' : undefined}
            >
              {statusChangeDialog.newStatus === ContentStatus.APPROVED ? 'Approve' : 'Archive'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}