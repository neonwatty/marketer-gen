"use client"

import * as React from "react"
import { useState } from "react"
import { cn } from "@/lib/utils"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Textarea } from "@/components/ui/textarea"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Separator } from "@/components/ui/separator"
import { Progress } from "@/components/ui/progress"
import { ContentApprovalData, ApprovalComment } from "@/lib/approval-actions"
import { approvalWorkflow } from "@/lib/approval-workflow"
import { 
  AlertTriangle, 
  ArrowRight, 
  CheckCircle, 
  Clock, 
  Edit, 
  MessageSquare, 
  RefreshCw, 
  User,
  Calendar,
  Target,
  TrendingUp
} from "lucide-react"

interface RejectionFeedbackPanelProps {
  content: ContentApprovalData
  userRole?: string
  userName?: string
  userId?: string
  onRevisionSubmit?: (revisionText: string, addressedFeedback: string[]) => void
  onRequestClarification?: (questionText: string) => void
  isLoading?: boolean
}

interface FeedbackItem {
  id: string
  comment: ApprovalComment
  isAddressed: boolean
  revisionNote?: string
}

export function RejectionFeedbackPanel({
  content,
  userRole,
  userName,
  userId,
  onRevisionSubmit,
  onRequestClarification,
  isLoading = false
}: RejectionFeedbackPanelProps) {
  const [revisionText, setRevisionText] = useState("")
  const [clarificationQuestion, setClarificationQuestion] = useState("")
  const [feedbackItems, setFeedbackItems] = useState<FeedbackItem[]>([])
  const [showRevisionDialog, setShowRevisionDialog] = useState(false)
  const [showClarificationDialog, setShowClarificationDialog] = useState(false)

  // Initialize feedback items from rejection/revision comments
  React.useEffect(() => {
    const rejectionComments = content.comments.filter(
      comment => comment.action === 'reject' || comment.action === 'request_revision'
    )
    
    const items: FeedbackItem[] = rejectionComments.map(comment => ({
      id: comment.id,
      comment,
      isAddressed: false
    }))
    
    setFeedbackItems(items)
  }, [content.comments])

  const handleToggleFeedbackAddressed = (itemId: string, isAddressed: boolean, note?: string) => {
    setFeedbackItems(prev => 
      prev.map(item => 
        item.id === itemId 
          ? { ...item, isAddressed, revisionNote: note }
          : item
      )
    )
  }

  const handleSubmitRevision = () => {
    const addressedFeedbackIds = feedbackItems
      .filter(item => item.isAddressed)
      .map(item => item.id)
    
    onRevisionSubmit?.(revisionText, addressedFeedbackIds)
    setRevisionText("")
    setShowRevisionDialog(false)
  }

  const handleRequestClarification = () => {
    onRequestClarification?.(clarificationQuestion)
    setClarificationQuestion("")
    setShowClarificationDialog(false)
  }

  const getRevisionProgress = () => {
    if (feedbackItems.length === 0) return 0
    const addressedCount = feedbackItems.filter(item => item.isAddressed).length
    return (addressedCount / feedbackItems.length) * 100
  }

  const getStatusInfo = () => {
    if (content.approvalStatus === 'REJECTED') {
      return {
        icon: AlertTriangle,
        color: 'text-red-500',
        bgColor: 'bg-red-100',
        title: 'Content Rejected',
        description: 'This content has been rejected and requires significant changes before resubmission.'
      }
    } else if (content.approvalStatus === 'NEEDS_REVISION') {
      return {
        icon: Edit,
        color: 'text-orange-500',
        bgColor: 'bg-orange-100',
        title: 'Revision Requested',
        description: 'Reviewers have provided feedback that needs to be addressed before approval.'
      }
    }
    
    return {
      icon: MessageSquare,
      color: 'text-blue-500',
      bgColor: 'bg-blue-100',
      title: 'Feedback Available',
      description: 'Review the feedback and make necessary changes.'
    }
  }

  const statusInfo = getStatusInfo()
  const StatusIcon = statusInfo.icon
  const revisionProgress = getRevisionProgress()

  if (!content.rejectionReason && feedbackItems.length === 0) {
    return null // No rejection feedback to show
  }

  return (
    <div className="space-y-6">
      {/* Status Alert */}
      <Alert className={statusInfo.bgColor}>
        <StatusIcon className={cn("h-5 w-5", statusInfo.color)} />
        <div className="space-y-2">
          <div className="font-medium">{statusInfo.title}</div>
          <AlertDescription>
            {statusInfo.description}
          </AlertDescription>
        </div>
      </Alert>

      {/* Main Rejection Reason */}
      {content.rejectionReason && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <MessageSquare className="w-5 h-5" />
              Primary Rejection Reason
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="prose prose-sm max-w-none">
              <p className="text-sm leading-relaxed">{content.rejectionReason}</p>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Feedback Items */}
      {feedbackItems.length > 0 && (
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="flex items-center gap-2">
                <Target className="w-5 h-5" />
                Feedback Items ({feedbackItems.length})
              </CardTitle>
              <div className="flex items-center gap-2">
                <span className="text-sm text-muted-foreground">Progress:</span>
                <div className="w-24">
                  <Progress value={revisionProgress} className="h-2" />
                </div>
                <span className="text-sm font-medium">{Math.round(revisionProgress)}%</span>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {feedbackItems.map((item, index) => (
                <div key={item.id} className="space-y-3">
                  <div className="flex items-start gap-3">
                    <div className="flex-shrink-0">
                      <div className={cn(
                        "w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium",
                        item.isAddressed 
                          ? "bg-green-100 text-green-800"
                          : "bg-gray-100 text-gray-600"
                      )}>
                        {item.isAddressed ? <CheckCircle className="w-4 h-4" /> : index + 1}
                      </div>
                    </div>
                    
                    <div className="flex-1 space-y-2">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-medium">
                            {item.comment.userName || 'Reviewer'}
                          </span>
                          <Badge 
                            variant={item.comment.action === 'reject' ? 'destructive' : 'secondary'}
                            className="text-xs"
                          >
                            {item.comment.action === 'reject' ? 'Rejected' : 'Revision Requested'}
                          </Badge>
                        </div>
                        <div className="flex items-center gap-1 text-xs text-muted-foreground">
                          <Calendar className="w-3 h-3" />
                          {new Date(item.comment.createdAt).toLocaleDateString()}
                        </div>
                      </div>
                      
                      <div className="text-sm text-muted-foreground leading-relaxed">
                        {item.comment.comment}
                      </div>
                      
                      <div className="flex items-center gap-2 pt-2">
                        <Button
                          variant={item.isAddressed ? "default" : "outline"}
                          size="sm"
                          onClick={() => handleToggleFeedbackAddressed(
                            item.id, 
                            !item.isAddressed,
                            item.isAddressed ? undefined : "Addressed in revision"
                          )}
                        >
                          {item.isAddressed ? (
                            <>
                              <CheckCircle className="w-4 h-4 mr-2" />
                              Addressed
                            </>
                          ) : (
                            <>
                              <Edit className="w-4 h-4 mr-2" />
                              Mark as Addressed
                            </>
                          )}
                        </Button>
                        
                        {item.isAddressed && item.revisionNote && (
                          <span className="text-xs text-muted-foreground">
                            {item.revisionNote}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                  {index < feedbackItems.length - 1 && <Separator />}
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Revision Progress Summary */}
      {feedbackItems.length > 0 && (
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div className="space-y-1">
                <h4 className="text-sm font-medium">Revision Status</h4>
                <p className="text-xs text-muted-foreground">
                  {feedbackItems.filter(item => item.isAddressed).length} of {feedbackItems.length} items addressed
                </p>
              </div>
              <div className="flex items-center gap-2">
                <TrendingUp className="w-4 h-4 text-muted-foreground" />
                <span className="text-2xl font-bold">{Math.round(revisionProgress)}%</span>
              </div>
            </div>
            <Progress value={revisionProgress} className="mt-3" />
          </CardContent>
        </Card>
      )}

      {/* Action Buttons */}
      <Card>
        <CardContent className="p-6">
          <div className="space-y-4">
            <h4 className="text-sm font-medium">What would you like to do?</h4>
            
            <div className="grid gap-3 md:grid-cols-2">
              <Button
                onClick={() => setShowRevisionDialog(true)}
                disabled={isLoading || revisionProgress === 0}
                className="h-auto p-4 flex flex-col items-start gap-2"
              >
                <div className="flex items-center gap-2">
                  <RefreshCw className="w-4 h-4" />
                  <span className="font-medium">Submit Revised Content</span>
                </div>
                <span className="text-xs opacity-90">
                  Address feedback and resubmit for review
                </span>
              </Button>
              
              <Button
                variant="outline"
                onClick={() => setShowClarificationDialog(true)}
                disabled={isLoading}
                className="h-auto p-4 flex flex-col items-start gap-2"
              >
                <div className="flex items-center gap-2">
                  <MessageSquare className="w-4 h-4" />
                  <span className="font-medium">Request Clarification</span>
                </div>
                <span className="text-xs opacity-70">
                  Ask questions about the feedback
                </span>
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Revision Dialog */}
      {showRevisionDialog && (
        <Card className="border-2 border-blue-200">
          <CardHeader>
            <CardTitle>Submit Revised Content</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <label className="text-sm font-medium">Describe your changes:</label>
              <Textarea
                placeholder="Explain how you've addressed the feedback..."
                value={revisionText}
                onChange={(e) => setRevisionText(e.target.value)}
                rows={4}
                className="mt-2"
              />
            </div>
            
            <div className="flex justify-end gap-2">
              <Button
                variant="outline"
                onClick={() => setShowRevisionDialog(false)}
              >
                Cancel
              </Button>
              <Button
                onClick={handleSubmitRevision}
                disabled={!revisionText.trim() || revisionProgress < 100}
              >
                Submit Revision
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Clarification Dialog */}
      {showClarificationDialog && (
        <Card className="border-2 border-orange-200">
          <CardHeader>
            <CardTitle>Request Clarification</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <label className="text-sm font-medium">Your question:</label>
              <Textarea
                placeholder="What specific aspect of the feedback needs clarification?"
                value={clarificationQuestion}
                onChange={(e) => setClarificationQuestion(e.target.value)}
                rows={3}
                className="mt-2"
              />
            </div>
            
            <div className="flex justify-end gap-2">
              <Button
                variant="outline"
                onClick={() => setShowClarificationDialog(false)}
              >
                Cancel
              </Button>
              <Button
                onClick={handleRequestClarification}
                disabled={!clarificationQuestion.trim()}
              >
                Send Question
              </Button>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

export { RejectionFeedbackPanel }
export type { RejectionFeedbackPanelProps }