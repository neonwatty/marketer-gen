'use client'

import React, { useState, useEffect, useRef } from 'react'
import { Comment, CommentReaction, User, CommentTargetType, CommentReactionType } from '@/types'
import { validateComponentAccess } from '@/lib/permissions'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip'
import { 
  MessageCircle, 
  Reply, 
  Heart, 
  ThumbsUp, 
  ThumbsDown, 
  Laugh, 
  Angry, 
  Frown,
  MoreVertical,
  Edit,
  Trash2,
  Flag,
  CheckCircle,
  Clock,
  AtSign,
  Send,
  X
} from 'lucide-react'
import { formatDistanceToNow } from 'date-fns'

export interface CommentSystemProps {
  targetType: CommentTargetType
  targetId: string
  currentUser: User
  comments: Comment[]
  onAddComment: (content: string, parentId?: string, mentions?: string[]) => Promise<void>
  onEditComment: (commentId: string, content: string) => Promise<void>
  onDeleteComment: (commentId: string) => Promise<void>
  onReactToComment: (commentId: string, reactionType: CommentReactionType) => Promise<void>
  onResolveComment: (commentId: string) => Promise<void>
  onUnresolveComment: (commentId: string) => Promise<void>
  onModerationAction: (commentId: string, action: 'flag' | 'hide' | 'approve') => Promise<void>
  isLoading?: boolean
  canModerate?: boolean
}

interface CommentFormProps {
  onSubmit: (content: string, mentions: string[]) => void
  onCancel?: () => void
  initialContent?: string
  placeholder?: string
  isEditing?: boolean
  isReply?: boolean
}

const CommentForm: React.FC<CommentFormProps> = ({
  onSubmit,
  onCancel,
  initialContent = '',
  placeholder = 'Write a comment...',
  isEditing = false,
  isReply = false
}) => {
  const [content, setContent] = useState(initialContent)
  const [mentions, setMentions] = useState<string[]>([])
  const [showMentions, setShowMentions] = useState(false)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (content.trim()) {
      onSubmit(content.trim(), mentions)
      if (!isEditing) {
        setContent('')
        setMentions([])
      }
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
      handleSubmit(e)
    }
    if (e.key === 'Escape' && onCancel) {
      onCancel()
    }
  }

  const detectMentions = (text: string) => {
    const mentionMatches = text.match(/@\w+/g) || []
    setMentions(mentionMatches.map(match => match.slice(1)))
  }

  const handleContentChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const newContent = e.target.value
    setContent(newContent)
    detectMentions(newContent)
    
    // Show mention dropdown if typing @
    const lastChar = newContent[newContent.length - 1]
    if (lastChar === '@') {
      setShowMentions(true)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-3">
      <div className="relative">
        <Textarea
          ref={textareaRef}
          value={content}
          onChange={handleContentChange}
          onKeyDown={handleKeyDown}
          placeholder={placeholder}
          className="min-h-[80px] resize-none"
          rows={isReply ? 2 : 3}
        />
        
        {mentions.length > 0 && (
          <div className="flex flex-wrap gap-1 mt-2">
            {mentions.map((mention, index) => (
              <Badge key={index} variant="secondary" className="text-xs">
                <AtSign className="h-3 w-3 mr-1" />
                {mention}
              </Badge>
            ))}
          </div>
        )}
      </div>
      
      <div className="flex items-center justify-between">
        <div className="text-xs text-muted-foreground">
          {isReply ? 'Press Ctrl+Enter to reply' : 'Press Ctrl+Enter to post'}
        </div>
        
        <div className="flex gap-2">
          {onCancel && (
            <Button type="button" variant="outline" size="sm" onClick={onCancel}>
              Cancel
            </Button>
          )}
          <Button 
            type="submit" 
            size="sm"
            disabled={!content.trim()}
          >
            <Send className="h-4 w-4 mr-2" />
            {isEditing ? 'Update' : isReply ? 'Reply' : 'Post'}
          </Button>
        </div>
      </div>
    </form>
  )
}

interface CommentItemProps {
  comment: Comment
  currentUser: User
  canModerate: boolean
  onReply: (parentId: string) => void
  onEdit: (comment: Comment) => void
  onDelete: (commentId: string) => void
  onReact: (commentId: string, reactionType: CommentReactionType) => void
  onResolve: (commentId: string) => void
  onUnresolve: (commentId: string) => void
  onFlag: (commentId: string) => void
  level?: number
}

const CommentItem: React.FC<CommentItemProps> = ({
  comment,
  currentUser,
  canModerate,
  onReply,
  onEdit,
  onDelete,
  onReact,
  onResolve,
  onUnresolve,
  onFlag,
  level = 0
}) => {
  const [showReplies, setShowReplies] = useState(true)
  const isAuthor = comment.authorId === currentUser.id
  const canEdit = isAuthor || canModerate
  const canDelete = isAuthor || canModerate

  const reactionCounts = comment.reactions.reduce((acc, reaction) => {
    acc[reaction.type] = (acc[reaction.type] || 0) + 1
    return acc
  }, {} as Record<CommentReactionType, number>)

  const userReaction = comment.reactions.find(r => r.userId === currentUser.id)

  const formatTimeAgo = (date: Date) => {
    return formatDistanceToNow(date, { addSuffix: true })
  }

  const getReactionIcon = (type: CommentReactionType, isActive: boolean = false) => {
    const iconProps = { 
      className: `h-4 w-4 ${isActive ? 'text-primary' : 'text-muted-foreground'}` 
    }
    
    switch (type) {
      case 'LIKE':
      case 'THUMBS_UP':
        return <ThumbsUp {...iconProps} />
      case 'DISLIKE':
      case 'THUMBS_DOWN':
        return <ThumbsDown {...iconProps} />
      case 'LOVE':
        return <Heart {...iconProps} />
      case 'LAUGH':
        return <Laugh {...iconProps} />
      case 'ANGRY':
        return <Angry {...iconProps} />
      case 'SAD':
        return <Frown {...iconProps} />
      default:
        return <ThumbsUp {...iconProps} />
    }
  }

  return (
    <div className={`flex gap-3 ${level > 0 ? 'ml-8 pt-4' : ''}`}>
      <Avatar className="h-8 w-8 mt-1">
        <AvatarImage src={comment.author.avatar} />
        <AvatarFallback className="text-xs">
          {comment.author.name?.split(' ').map(n => n[0]).join('') || 'U'}
        </AvatarFallback>
      </Avatar>
      
      <div className="flex-1 space-y-2">
        <div className="bg-muted/50 rounded-lg p-3">
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-2">
              <span className="font-medium text-sm">{comment.author.name}</span>
              <span className="text-xs text-muted-foreground">
                {formatTimeAgo(comment.createdAt)}
              </span>
              {comment.isEdited && (
                <Badge variant="outline" className="text-xs">
                  Edited
                </Badge>
              )}
              {comment.isResolved && (
                <Badge variant="default" className="text-xs">
                  <CheckCircle className="h-3 w-3 mr-1" />
                  Resolved
                </Badge>
              )}
            </div>
            
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="sm" className="h-8 w-8 p-0">
                  <MoreVertical className="h-4 w-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={() => onReply(comment.id)}>
                  <Reply className="h-4 w-4 mr-2" />
                  Reply
                </DropdownMenuItem>
                
                {canEdit && (
                  <DropdownMenuItem onClick={() => onEdit(comment)}>
                    <Edit className="h-4 w-4 mr-2" />
                    Edit
                  </DropdownMenuItem>
                )}
                
                {canDelete && (
                  <DropdownMenuItem 
                    onClick={() => onDelete(comment.id)}
                    className="text-destructive"
                  >
                    <Trash2 className="h-4 w-4 mr-2" />
                    Delete
                  </DropdownMenuItem>
                )}
                
                {!comment.isResolved && canModerate && (
                  <DropdownMenuItem onClick={() => onResolve(comment.id)}>
                    <CheckCircle className="h-4 w-4 mr-2" />
                    Mark Resolved
                  </DropdownMenuItem>
                )}
                
                {comment.isResolved && canModerate && (
                  <DropdownMenuItem onClick={() => onUnresolve(comment.id)}>
                    <Clock className="h-4 w-4 mr-2" />
                    Mark Unresolved
                  </DropdownMenuItem>
                )}
                
                {!isAuthor && (
                  <DropdownMenuItem 
                    onClick={() => onFlag(comment.id)}
                    className="text-destructive"
                  >
                    <Flag className="h-4 w-4 mr-2" />
                    Report
                  </DropdownMenuItem>
                )}
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
          
          <div className="text-sm">
            {comment.content}
          </div>
        </div>
        
        {/* Reactions */}
        <div className="flex items-center gap-2">
          <TooltipProvider>
            {(['LIKE', 'LOVE', 'LAUGH', 'ANGRY', 'SAD'] as CommentReactionType[]).map((reactionType) => {
              const count = reactionCounts[reactionType] || 0
              const isActive = userReaction?.type === reactionType
              
              if (count === 0 && !isActive) return null
              
              return (
                <Tooltip key={reactionType}>
                  <TooltipTrigger asChild>
                    <Button
                      variant="ghost"
                      size="sm"
                      className={`h-8 px-2 ${isActive ? 'bg-muted' : ''}`}
                      onClick={() => onReact(comment.id, reactionType)}
                    >
                      {getReactionIcon(reactionType, isActive)}
                      {count > 0 && <span className="ml-1 text-xs">{count}</span>}
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>
                    <p className="capitalize">{reactionType.toLowerCase()}</p>
                  </TooltipContent>
                </Tooltip>
              )
            })}
          </TooltipProvider>
          
          <Button
            variant="ghost"
            size="sm"
            className="h-8"
            onClick={() => onReply(comment.id)}
          >
            <Reply className="h-4 w-4 mr-2" />
            Reply
          </Button>
        </div>
        
        {/* Nested replies */}
        {comment.replies && comment.replies.length > 0 && (
          <div className="space-y-4">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setShowReplies(!showReplies)}
              className="text-xs"
            >
              {showReplies ? 'Hide' : 'Show'} {comment.replies.length} replies
            </Button>
            
            {showReplies && (
              <div className="space-y-4">
                {comment.replies.map((reply) => (
                  <CommentItem
                    key={reply.id}
                    comment={reply}
                    currentUser={currentUser}
                    canModerate={canModerate}
                    onReply={onReply}
                    onEdit={onEdit}
                    onDelete={onDelete}
                    onReact={onReact}
                    onResolve={onResolve}
                    onUnresolve={onUnresolve}
                    onFlag={onFlag}
                    level={level + 1}
                  />
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

export const CommentSystem: React.FC<CommentSystemProps> = ({
  targetType,
  targetId,
  currentUser,
  comments,
  onAddComment,
  onEditComment,
  onDeleteComment,
  onReactToComment,
  onResolveComment,
  onUnresolveComment,
  onModerationAction,
  isLoading = false,
  canModerate = false
}) => {
  const [replyingTo, setReplyingTo] = useState<string | null>(null)
  const [editingComment, setEditingComment] = useState<Comment | null>(null)
  const [showComments, setShowComments] = useState(true)

  // Check if user can comment
  const canComment = validateComponentAccess(currentUser.role, 'canCreateContent')

  // Filter to root level comments (no parent)
  const rootComments = comments.filter(comment => !comment.parentCommentId)
  const resolvedComments = comments.filter(comment => comment.isResolved)
  const unresolvedComments = comments.filter(comment => !comment.isResolved)

  const handleAddComment = async (content: string, mentions: string[] = []) => {
    await onAddComment(content, undefined, mentions)
  }

  const handleReplyToComment = async (content: string, mentions: string[] = []) => {
    if (replyingTo) {
      await onAddComment(content, replyingTo, mentions)
      setReplyingTo(null)
    }
  }

  const handleEditComment = async (content: string, mentions: string[] = []) => {
    if (editingComment) {
      await onEditComment(editingComment.id, content)
      setEditingComment(null)
    }
  }

  const handleDeleteComment = async (commentId: string) => {
    if (window.confirm('Are you sure you want to delete this comment?')) {
      await onDeleteComment(commentId)
    }
  }

  const handleFlagComment = async (commentId: string) => {
    if (window.confirm('Are you sure you want to report this comment?')) {
      await onModerationAction(commentId, 'flag')
    }
  }

  if (isLoading) {
    return (
      <Card>
        <CardContent className="pt-6">
          <div className="animate-pulse space-y-4">
            <div className="h-4 bg-muted rounded w-1/4"></div>
            <div className="h-20 bg-muted rounded"></div>
            <div className="h-10 bg-muted rounded w-1/3"></div>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle className="flex items-center gap-2">
            <MessageCircle className="h-5 w-5" />
            Comments ({comments.length})
          </CardTitle>
          
          <div className="flex items-center gap-2">
            {resolvedComments.length > 0 && (
              <Badge variant="secondary">
                {resolvedComments.length} resolved
              </Badge>
            )}
            
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setShowComments(!showComments)}
            >
              {showComments ? 'Hide' : 'Show'}
            </Button>
          </div>
        </div>
      </CardHeader>
      
      {showComments && (
        <CardContent className="space-y-6">
          {/* Add new comment form */}
          {canComment && (
            <div className="border-b pb-4">
              <div className="flex gap-3">
                <Avatar className="h-8 w-8">
                  <AvatarImage src={currentUser.avatar} />
                  <AvatarFallback className="text-xs">
                    {currentUser.name?.split(' ').map(n => n[0]).join('') || 'U'}
                  </AvatarFallback>
                </Avatar>
                
                <div className="flex-1">
                  <CommentForm onSubmit={handleAddComment} />
                </div>
              </div>
            </div>
          )}
          
          {/* Comments list */}
          {comments.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              <MessageCircle className="h-12 w-12 mx-auto mb-4 opacity-50" />
              <p>No comments yet</p>
              {canComment && <p className="text-sm">Be the first to start the discussion!</p>}
            </div>
          ) : (
            <div className="space-y-6">
              {rootComments.map((comment) => (
                <div key={comment.id} className="space-y-4">
                  <CommentItem
                    comment={comment}
                    currentUser={currentUser}
                    canModerate={canModerate}
                    onReply={(parentId) => setReplyingTo(parentId)}
                    onEdit={(comment) => setEditingComment(comment)}
                    onDelete={handleDeleteComment}
                    onReact={onReactToComment}
                    onResolve={onResolveComment}
                    onUnresolve={onUnresolveComment}
                    onFlag={handleFlagComment}
                  />
                  
                  {/* Reply form */}
                  {replyingTo === comment.id && canComment && (
                    <div className="ml-11 border-l-2 border-muted pl-4">
                      <CommentForm
                        onSubmit={handleReplyToComment}
                        onCancel={() => setReplyingTo(null)}
                        placeholder="Write a reply..."
                        isReply
                      />
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
          
          {/* Edit comment dialog */}
          {editingComment && (
            <Dialog open={!!editingComment} onOpenChange={() => setEditingComment(null)}>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Edit Comment</DialogTitle>
                  <DialogDescription>
                    Make changes to your comment below.
                  </DialogDescription>
                </DialogHeader>
                
                <CommentForm
                  onSubmit={handleEditComment}
                  onCancel={() => setEditingComment(null)}
                  initialContent={editingComment.content}
                  isEditing
                />
              </DialogContent>
            </Dialog>
          )}
        </CardContent>
      )}
    </Card>
  )
}

export default CommentSystem