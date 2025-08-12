'use client'

import React, { useState } from 'react'
import { Comment, User, CommentReactionType } from '@/types'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Textarea } from '@/components/ui/textarea'
import { 
  Heart, 
  ThumbsUp, 
  Reply, 
  MoreVertical,
  Send,
  CheckCircle
} from 'lucide-react'
import { formatDistanceToNow } from 'date-fns'

export interface CommentThreadProps {
  comments: Comment[]
  currentUser: User
  onAddReply: (parentId: string, content: string) => Promise<void>
  onReactToComment: (commentId: string, reactionType: CommentReactionType) => Promise<void>
  compact?: boolean
  maxDepth?: number
}

interface QuickReplyProps {
  parentId: string
  onSubmit: (content: string) => void
  onCancel: () => void
  placeholder?: string
}

const QuickReply: React.FC<QuickReplyProps> = ({
  parentId,
  onSubmit,
  onCancel,
  placeholder = 'Write a reply...'
}) => {
  const [content, setContent] = useState('')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (content.trim()) {
      onSubmit(content.trim())
      setContent('')
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-2">
      <Textarea
        value={content}
        onChange={(e) => setContent(e.target.value)}
        placeholder={placeholder}
        className="min-h-[60px] text-sm"
        rows={2}
      />
      <div className="flex justify-end gap-2">
        <Button type="button" variant="ghost" size="sm" onClick={onCancel}>
          Cancel
        </Button>
        <Button type="submit" size="sm" disabled={!content.trim()}>
          <Send className="h-3 w-3 mr-1" />
          Reply
        </Button>
      </div>
    </form>
  )
}

interface ThreadCommentProps {
  comment: Comment
  currentUser: User
  onReply: (parentId: string, content: string) => Promise<void>
  onReact: (commentId: string, reactionType: CommentReactionType) => Promise<void>
  depth?: number
  maxDepth?: number
  compact?: boolean
}

const ThreadComment: React.FC<ThreadCommentProps> = ({
  comment,
  currentUser,
  onReply,
  onReact,
  depth = 0,
  maxDepth = 3,
  compact = false
}) => {
  const [showReplyForm, setShowReplyForm] = useState(false)
  const [showReplies, setShowReplies] = useState(true)

  const handleReply = async (content: string) => {
    await onReply(comment.id, content)
    setShowReplyForm(false)
  }

  const reactionCounts = comment.reactions.reduce((acc, reaction) => {
    acc[reaction.type] = (acc[reaction.type] || 0) + 1
    return acc
  }, {} as Record<CommentReactionType, number>)

  const userReaction = comment.reactions.find(r => r.userId === currentUser.id)
  const hasLikes = reactionCounts['LIKE'] > 0
  const hasHearts = reactionCounts['LOVE'] > 0

  const avatarSize = compact ? 'h-6 w-6' : 'h-8 w-8'
  const marginLeft = depth > 0 ? (compact ? 'ml-4' : 'ml-6') : ''

  return (
    <div className={`space-y-2 ${marginLeft}`}>
      <div className="flex gap-2 group">
        <Avatar className={`${avatarSize} mt-1 flex-shrink-0`}>
          <AvatarImage src={comment.author.avatar} />
          <AvatarFallback className={compact ? 'text-xs' : 'text-sm'}>
            {comment.author.name?.split(' ').map(n => n[0]).join('') || 'U'}
          </AvatarFallback>
        </Avatar>
        
        <div className="flex-1 min-w-0">
          <div className="bg-muted/50 rounded-lg p-3">
            <div className="flex items-center gap-2 mb-1">
              <span className={`font-medium ${compact ? 'text-xs' : 'text-sm'}`}>
                {comment.author.name}
              </span>
              <span className="text-xs text-muted-foreground">
                {formatDistanceToNow(comment.createdAt, { addSuffix: true })}
              </span>
              {comment.isResolved && (
                <Badge variant="default" className="text-xs px-1 py-0">
                  <CheckCircle className="h-3 w-3" />
                </Badge>
              )}
            </div>
            
            <div className={`text-muted-foreground ${compact ? 'text-xs' : 'text-sm'}`}>
              {comment.content}
            </div>
          </div>
          
          {/* Quick actions */}
          <div className="flex items-center gap-1 mt-1 opacity-0 group-hover:opacity-100 transition-opacity">
            {hasLikes && (
              <Button
                variant="ghost"
                size="sm"
                className={`h-6 px-1 text-xs ${userReaction?.type === 'LIKE' ? 'text-primary' : ''}`}
                onClick={() => onReact(comment.id, 'LIKE')}
              >
                <ThumbsUp className="h-3 w-3 mr-1" />
                {reactionCounts['LIKE']}
              </Button>
            )}
            
            {hasHearts && (
              <Button
                variant="ghost"
                size="sm"
                className={`h-6 px-1 text-xs ${userReaction?.type === 'LOVE' ? 'text-red-500' : ''}`}
                onClick={() => onReact(comment.id, 'LOVE')}
              >
                <Heart className="h-3 w-3 mr-1" />
                {reactionCounts['LOVE']}
              </Button>
            )}
            
            {!hasLikes && (
              <Button
                variant="ghost"
                size="sm"
                className="h-6 px-1 text-xs"
                onClick={() => onReact(comment.id, 'LIKE')}
              >
                <ThumbsUp className="h-3 w-3" />
              </Button>
            )}
            
            {depth < maxDepth && (
              <Button
                variant="ghost"
                size="sm"
                className="h-6 px-1 text-xs"
                onClick={() => setShowReplyForm(true)}
              >
                <Reply className="h-3 w-3 mr-1" />
                Reply
              </Button>
            )}
          </div>
          
          {/* Reply form */}
          {showReplyForm && (
            <div className="mt-2">
              <QuickReply
                parentId={comment.id}
                onSubmit={handleReply}
                onCancel={() => setShowReplyForm(false)}
              />
            </div>
          )}
          
          {/* Nested replies */}
          {comment.replies && comment.replies.length > 0 && depth < maxDepth && (
            <div className="mt-3 space-y-3">
              {showReplies && comment.replies.map((reply) => (
                <ThreadComment
                  key={reply.id}
                  comment={reply}
                  currentUser={currentUser}
                  onReply={onReply}
                  onReact={onReact}
                  depth={depth + 1}
                  maxDepth={maxDepth}
                  compact={compact}
                />
              ))}
              
              {!showReplies && (
                <Button
                  variant="ghost"
                  size="sm"
                  className="text-xs"
                  onClick={() => setShowReplies(true)}
                >
                  Show {comment.replies.length} replies
                </Button>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export const CommentThread: React.FC<CommentThreadProps> = ({
  comments,
  currentUser,
  onAddReply,
  onReactToComment,
  compact = false,
  maxDepth = 3
}) => {
  // Filter to root level comments
  const rootComments = comments.filter(comment => !comment.parentCommentId)

  if (comments.length === 0) {
    return (
      <div className="text-center py-4 text-muted-foreground">
        <div className={compact ? 'text-xs' : 'text-sm'}>No comments yet</div>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {rootComments.map((comment) => (
        <ThreadComment
          key={comment.id}
          comment={comment}
          currentUser={currentUser}
          onReply={onAddReply}
          onReact={onReactToComment}
          maxDepth={maxDepth}
          compact={compact}
        />
      ))}
    </div>
  )
}

export default CommentThread