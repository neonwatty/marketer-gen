"use client"

import * as React from "react"
import { useState } from "react"
import { cn } from "@/lib/utils"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Textarea } from "@/components/ui/textarea"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Separator } from "@/components/ui/separator"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { ContentApprovalData, ApprovalComment } from "@/lib/approval-actions"
import { ApprovalAction } from "@/lib/approval-workflow"
import { approvalWorkflow } from "@/lib/approval-workflow"
import { CheckCircle, XCircle, Clock, Edit, Eye, Globe, Archive, MessageSquare, User, Calendar } from "lucide-react"

interface ContentApprovalPanelProps {
  content: ContentApprovalData
  userRole?: string
  userName?: string
  userId?: string
  onAction?: (action: ApprovalAction, comment?: string) => void
  isLoading?: boolean
}

export function ContentApprovalPanel({
  content,
  userRole,
  userName,
  userId,
  onAction,
  isLoading = false
}: ContentApprovalPanelProps) {
  const [actionComment, setActionComment] = useState("")
  const [selectedAction, setSelectedAction] = useState<ApprovalAction | null>(null)
  const [isDialogOpen, setIsDialogOpen] = useState(false)

  const stateInfo = approvalWorkflow.getStateInfo(content.status)
  const approvalStatusInfo = approvalWorkflow.getApprovalStatusInfo(content.approvalStatus)

  const handleActionClick = (action: ApprovalAction) => {
    const requiresComment = ['reject', 'request_revision'].includes(action)
    
    if (requiresComment) {
      setSelectedAction(action)
      setIsDialogOpen(true)
    } else {
      onAction?.(action)
    }
  }

  const handleConfirmAction = () => {
    if (selectedAction) {
      onAction?.(selectedAction, actionComment)
      setActionComment("")
      setSelectedAction(null)
      setIsDialogOpen(false)
    }
  }

  const getActionIcon = (action: ApprovalAction) => {
    const iconMap = {
      approve: CheckCircle,
      reject: XCircle,
      request_revision: Edit,
      publish: Globe,
      submit_for_review: Eye,
      archive: Archive,
      revert_to_draft: Edit
    }
    return iconMap[action] || MessageSquare
  }

  const getActionColor = (action: ApprovalAction) => {
    const colorMap = {
      approve: 'bg-green-500 hover:bg-green-600',
      reject: 'bg-red-500 hover:bg-red-600',
      request_revision: 'bg-orange-500 hover:bg-orange-600',
      publish: 'bg-blue-500 hover:bg-blue-600',
      submit_for_review: 'bg-purple-500 hover:bg-purple-600',
      archive: 'bg-gray-500 hover:bg-gray-600',
      revert_to_draft: 'bg-yellow-500 hover:bg-yellow-600'
    }
    return colorMap[action] || 'bg-gray-500 hover:bg-gray-600'
  }

  const getActionLabel = (action: ApprovalAction) => {
    const labelMap = {
      approve: 'Approve',
      reject: 'Reject',
      request_revision: 'Request Revision',
      publish: 'Publish',
      submit_for_review: 'Submit for Review',
      archive: 'Archive',
      revert_to_draft: 'Revert to Draft'
    }
    return labelMap[action] || action.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }

  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map(n => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2)
  }

  return (
    <div className="space-y-6">
      {/* Status Section */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle className="flex items-center gap-2">
              <div className={cn(
                "w-3 h-3 rounded-full",
                stateInfo.color === 'green' && 'bg-green-500',
                stateInfo.color === 'yellow' && 'bg-yellow-500',
                stateInfo.color === 'red' && 'bg-red-500',
                stateInfo.color === 'blue' && 'bg-blue-500',
                stateInfo.color === 'purple' && 'bg-purple-500',
                stateInfo.color === 'gray' && 'bg-gray-500',
                stateInfo.color === 'emerald' && 'bg-emerald-500',
                stateInfo.color === 'orange' && 'bg-orange-500',
                stateInfo.color === 'slate' && 'bg-slate-500'
              )} />
              {stateInfo.label}
            </CardTitle>
            <Badge 
              variant={
                content.approvalStatus === 'APPROVED' ? 'default' :
                content.approvalStatus === 'REJECTED' ? 'destructive' :
                content.approvalStatus === 'NEEDS_REVISION' ? 'secondary' :
                'outline'
              }
            >
              {approvalStatusInfo.label}
            </Badge>
          </div>
          <p className="text-sm text-muted-foreground">{stateInfo.description}</p>
        </CardHeader>

        <CardContent>
          <div className="space-y-4">
            {/* Approval Info */}
            {content.approvedBy && (
              <div className="flex items-center gap-2 text-sm">
                <CheckCircle className="w-4 h-4 text-green-500" />
                <span>Approved by {content.approvedBy}</span>
                {content.approvedAt && (
                  <span className="text-muted-foreground">
                    on {new Date(content.approvedAt).toLocaleDateString()}
                  </span>
                )}
              </div>
            )}

            {/* Rejection Reason */}
            {content.rejectionReason && (
              <Alert>
                <XCircle className="h-4 w-4" />
                <AlertDescription>
                  <strong>Rejection Reason:</strong> {content.rejectionReason}
                </AlertDescription>
              </Alert>
            )}

            {/* Actions */}
            {content.availableActions.length > 0 && (
              <div className="space-y-3">
                <Separator />
                <div>
                  <h4 className="text-sm font-medium mb-3">Available Actions</h4>
                  <div className="flex flex-wrap gap-2">
                    {content.availableActions.map((action) => {
                      const Icon = getActionIcon(action)
                      return (
                        <Button
                          key={action}
                          onClick={() => handleActionClick(action)}
                          disabled={isLoading}
                          className={cn(
                            "text-white",
                            getActionColor(action)
                          )}
                          size="sm"
                        >
                          <Icon className="w-4 h-4 mr-2" />
                          {getActionLabel(action)}
                        </Button>
                      )
                    })}
                  </div>
                </div>
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Comments Section */}
      {content.comments.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <MessageSquare className="w-5 h-5" />
              Review History ({content.comments.length})
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {content.comments.map((comment, index) => (
                <div key={comment.id} className="space-y-3">
                  <div className="flex items-start gap-3">
                    <Avatar className="w-8 h-8">
                      <AvatarFallback>
                        {getInitials(comment.userName || comment.userId || 'User')}
                      </AvatarFallback>
                    </Avatar>
                    <div className="flex-1 space-y-2">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-medium">
                            {comment.userName || comment.userId || 'Anonymous'}
                          </span>
                          {comment.userRole && (
                            <Badge variant="outline" className="text-xs">
                              {comment.userRole}
                            </Badge>
                          )}
                          <Badge 
                            variant="secondary" 
                            className={cn(
                              "text-xs",
                              comment.action === 'approve' && 'bg-green-100 text-green-800',
                              comment.action === 'reject' && 'bg-red-100 text-red-800',
                              comment.action === 'request_revision' && 'bg-orange-100 text-orange-800'
                            )}
                          >
                            {getActionLabel(comment.action)}
                          </Badge>
                        </div>
                        <div className="flex items-center gap-1 text-xs text-muted-foreground">
                          <Calendar className="w-3 h-3" />
                          {new Date(comment.createdAt).toLocaleString()}
                        </div>
                      </div>
                      <p className="text-sm text-muted-foreground leading-relaxed">
                        {comment.comment}
                      </p>
                      {comment.fromStatus !== comment.toStatus && (
                        <div className="text-xs text-muted-foreground flex items-center gap-2">
                          <span>Status changed:</span>
                          <Badge variant="outline" className="text-xs">
                            {approvalWorkflow.getStateInfo(comment.fromStatus).label}
                          </Badge>
                          <span>→</span>
                          <Badge variant="outline" className="text-xs">
                            {approvalWorkflow.getStateInfo(comment.toStatus).label}
                          </Badge>
                        </div>
                      )}
                    </div>
                  </div>
                  {index < content.comments.length - 1 && <Separator />}
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Action Confirmation Dialog */}
      <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              Confirm {selectedAction ? getActionLabel(selectedAction) : 'Action'}
            </DialogTitle>
            <DialogDescription>
              {selectedAction === 'reject' && 'Please provide a reason for rejecting this content.'}
              {selectedAction === 'request_revision' && 'Please provide specific feedback for the revision.'}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <Textarea
              placeholder={
                selectedAction === 'reject' ? 'Enter rejection reason...' :
                selectedAction === 'request_revision' ? 'Enter revision feedback...' :
                'Enter comment...'
              }
              value={actionComment}
              onChange={(e) => setActionComment(e.target.value)}
              rows={4}
            />
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => {
                setIsDialogOpen(false)
                setActionComment("")
                setSelectedAction(null)
              }}
            >
              Cancel
            </Button>
            <Button
              onClick={handleConfirmAction}
              disabled={!actionComment.trim()}
              className={selectedAction ? getActionColor(selectedAction) : ''}
            >
              Confirm {selectedAction ? getActionLabel(selectedAction) : 'Action'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}

export { ContentApprovalPanel }
export type { ContentApprovalPanelProps }