"use client"

import * as React from "react"
import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { ContentApprovalPanel } from "@/components/content/content-approval-panel"
import { ApprovalDashboard } from "@/components/content/approval-dashboard"
import { RejectionFeedbackPanel } from "@/components/content/rejection-feedback-panel"
import { NotificationBell } from "@/components/notifications/notification-bell"
import { useApprovalWorkflow } from "@/hooks/useApprovalWorkflow"
import { ContentApprovalData } from "@/lib/approval-actions"
import { ApprovalAction } from "@/lib/approval-workflow"
import { UserRole } from "@/lib/permissions"
import { notificationService } from "@/lib/notifications"
import { ContentStatus, ApprovalStatus } from "@prisma/client"
import { User, Settings, Bell } from "lucide-react"

// Demo data for the approval workflow demonstration
const DEMO_CONTENT: ContentApprovalData[] = [
  {
    id: 'demo-content-1',
    title: 'Summer Campaign Email Copy',
    status: 'REVIEWING' as ContentStatus,
    approvalStatus: 'PENDING' as ApprovalStatus,
    availableActions: ['approve', 'reject', 'request_revision'],
    canApprove: true,
    canReject: true,
    canPublish: false,
    comments: [
      {
        id: 'comment-1',
        contentId: 'demo-content-1',
        userName: 'Marketing Manager',
        userRole: 'approver',
        comment: 'This looks good but we need to adjust the tone for our target audience. Consider making it more conversational and less formal.',
        action: 'request_revision' as ApprovalAction,
        fromStatus: 'REVIEWING' as ContentStatus,
        toStatus: 'DRAFT' as ContentStatus,
        createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000) // 2 hours ago
      }
    ]
  },
  {
    id: 'demo-content-2',
    title: 'Product Launch Blog Post',
    status: 'APPROVED' as ContentStatus,
    approvalStatus: 'APPROVED' as ApprovalStatus,
    availableActions: ['publish'],
    canApprove: false,
    canReject: false,
    canPublish: true,
    approvedBy: 'Content Director',
    approvedAt: new Date(Date.now() - 1 * 60 * 60 * 1000), // 1 hour ago
    comments: [
      {
        id: 'comment-2',
        contentId: 'demo-content-2',
        userName: 'Content Director',
        userRole: 'approver',
        comment: 'Excellent work! The content is well-structured and engaging. Ready for publication.',
        action: 'approve' as ApprovalAction,
        fromStatus: 'REVIEWING' as ContentStatus,
        toStatus: 'APPROVED' as ContentStatus,
        createdAt: new Date(Date.now() - 1 * 60 * 60 * 1000) // 1 hour ago
      }
    ]
  },
  {
    id: 'demo-content-3',
    title: 'Social Media Campaign Graphics',
    status: 'DRAFT' as ContentStatus,
    approvalStatus: 'NEEDS_REVISION' as ApprovalStatus,
    availableActions: ['submit_for_review'],
    canApprove: false,
    canReject: false,
    canPublish: false,
    rejectionReason: 'The graphics need to be updated to match our new brand guidelines. Please ensure colors and fonts align with the style guide.',
    comments: [
      {
        id: 'comment-3',
        contentId: 'demo-content-3',
        userName: 'Brand Manager',
        userRole: 'approver',
        comment: 'The graphics look great but need some adjustments: 1) Use primary blue (#2563EB) instead of the current blue, 2) Switch to Roboto font for consistency, 3) Add more whitespace around the logo.',
        action: 'request_revision' as ApprovalAction,
        fromStatus: 'REVIEWING' as ContentStatus,
        toStatus: 'DRAFT' as ContentStatus,
        createdAt: new Date(Date.now() - 4 * 60 * 60 * 1000) // 4 hours ago
      }
    ]
  }
]

export function ApprovalWorkflowDemo() {
  const [currentUser, setCurrentUser] = useState<{
    id: string
    name: string
    role: UserRole
  }>({
    id: 'demo_user_creator',
    name: 'Demo User',
    role: 'creator'
  })
  
  const [selectedContentId, setSelectedContentId] = useState<string>('demo-content-1')
  const [activeView, setActiveView] = useState<'individual' | 'dashboard'>('individual')
  
  // Get current content data
  const selectedContent = DEMO_CONTENT.find(c => c.id === selectedContentId) || DEMO_CONTENT[0]
  
  // Use the approval workflow hook
  const { executeAction, isLoading, error } = useApprovalWorkflow({
    userRole: currentUser.role,
    userId: currentUser.id,
    userName: currentUser.name,
    onSuccess: (contentId, action) => {
      // In a real app, this would refresh the data
      console.log(`Successfully executed ${action} on content ${contentId}`)
      
      // Add demo notification
      notificationService.notifyWorkflowAction({
        contentId,
        contentTitle: selectedContent.title,
        action,
        fromStatus: selectedContent.status,
        toStatus: 'APPROVED' as ContentStatus, // Simplified for demo
        fromUserId: currentUser.id,
        fromUserName: currentUser.name
      })
    },
    onError: (error) => {
      console.error('Workflow action failed:', error)
    }
  })

  const handleAction = async (action: ApprovalAction, comment?: string) => {
    await executeAction(selectedContentId, action, comment)
  }

  const handleRevisionSubmit = async (revisionText: string, addressedFeedback: string[]) => {
    console.log('Revision submitted:', { revisionText, addressedFeedback })
    // In a real app, this would update the content and resubmit for review
    await executeAction(selectedContentId, 'submit_for_review', revisionText)
  }

  const handleClarificationRequest = async (questionText: string) => {
    console.log('Clarification requested:', questionText)
    // In a real app, this would create a comment asking for clarification
  }

  const handleViewContent = (contentId: string) => {
    setSelectedContentId(contentId)
    setActiveView('individual')
  }

  const handleBulkAction = async (action: string, contentIds: string[], comment?: string) => {
    console.log('Bulk action:', { action, contentIds, comment })
    // In a real app, this would execute the bulk action
  }

  // Add some demo notifications on mount
  useEffect(() => {
    const demoNotifications = [
      {
        type: 'content_submitted' as const,
        contentId: 'demo-content-1',
        contentTitle: 'Summer Campaign Email Copy',
        action: 'submit_for_review' as ApprovalAction,
        fromStatus: 'DRAFT' as ContentStatus,
        toStatus: 'REVIEWING' as ContentStatus,
        fromUserName: 'Content Creator'
      },
      {
        type: 'content_approved' as const,
        contentId: 'demo-content-2',
        contentTitle: 'Product Launch Blog Post',
        action: 'approve' as ApprovalAction,
        fromStatus: 'REVIEWING' as ContentStatus,
        toStatus: 'APPROVED' as ContentStatus,
        fromUserName: 'Content Director'
      }
    ]

    demoNotifications.forEach(notif => {
      const notification = notificationService.createNotification(notif)
      notificationService.addNotification(currentUser.id, notification)
    })
  }, [currentUser.id])

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto space-y-6">
        {/* Demo Header */}
        <Card className="border-blue-200 bg-blue-50">
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Settings className="w-6 h-6" />
                Content Approval Workflow Demo
              </div>
              <div className="flex items-center gap-4">
                <NotificationBell userId={currentUser.id} />
                <div className="flex items-center gap-2">
                  <User className="w-4 h-4" />
                  <span className="text-sm font-medium">{currentUser.name}</span>
                  <Badge variant="outline">{currentUser.role}</Badge>
                </div>
                <Select 
                  value={currentUser.role} 
                  onValueChange={(role: UserRole) => 
                    setCurrentUser(prev => ({ ...prev, role }))
                  }
                >
                  <SelectTrigger className="w-32">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="viewer">Viewer</SelectItem>
                    <SelectItem value="creator">Creator</SelectItem>
                    <SelectItem value="reviewer">Reviewer</SelectItem>
                    <SelectItem value="approver">Approver</SelectItem>
                    <SelectItem value="publisher">Publisher</SelectItem>
                    <SelectItem value="admin">Admin</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-blue-800">
              This demo showcases the complete content approval workflow system. 
              Switch between different user roles to see how permissions and available actions change.
            </p>
          </CardContent>
        </Card>

        {/* View Toggle */}
        <div className="flex justify-center">
          <div className="inline-flex rounded-md shadow-sm" role="group">
            <Button
              variant={activeView === 'individual' ? 'default' : 'outline'}
              onClick={() => setActiveView('individual')}
              className="rounded-r-none"
            >
              Individual Content
            </Button>
            <Button
              variant={activeView === 'dashboard' ? 'default' : 'outline'}
              onClick={() => setActiveView('dashboard')}
              className="rounded-l-none"
            >
              Approval Dashboard
            </Button>
          </div>
        </div>

        {/* Error Display */}
        {error && (
          <Card className="border-red-200 bg-red-50">
            <CardContent className="p-4">
              <p className="text-sm text-red-800">{error}</p>
            </CardContent>
          </Card>
        )}

        {/* Main Content */}
        {activeView === 'individual' ? (
          <div className="grid gap-6 lg:grid-cols-3">
            {/* Content Selection */}
            <Card>
              <CardHeader>
                <CardTitle>Select Content</CardTitle>
              </CardHeader>
              <CardContent className="space-y-2">
                {DEMO_CONTENT.map(content => (
                  <Button
                    key={content.id}
                    variant={selectedContentId === content.id ? 'default' : 'outline'}
                    onClick={() => setSelectedContentId(content.id)}
                    className="w-full justify-start h-auto p-3"
                  >
                    <div className="text-left">
                      <div className="font-medium text-sm">{content.title}</div>
                      <div className="flex items-center gap-2 mt-1">
                        <Badge variant="outline" className="text-xs">
                          {content.status}
                        </Badge>
                        <Badge 
                          variant={
                            content.approvalStatus === 'APPROVED' ? 'default' :
                            content.approvalStatus === 'REJECTED' ? 'destructive' :
                            'secondary'
                          }
                          className="text-xs"
                        >
                          {content.approvalStatus}
                        </Badge>
                      </div>
                    </div>
                  </Button>
                ))}
              </CardContent>
            </Card>

            {/* Main Content Panel */}
            <div className="lg:col-span-2 space-y-6">
              <ContentApprovalPanel
                content={selectedContent}
                userRole={currentUser.role}
                userName={currentUser.name}
                userId={currentUser.id}
                onAction={handleAction}
                isLoading={isLoading}
              />

              {(selectedContent.approvalStatus === 'REJECTED' || 
                selectedContent.approvalStatus === 'NEEDS_REVISION') && (
                <RejectionFeedbackPanel
                  content={selectedContent}
                  userRole={currentUser.role}
                  userName={currentUser.name}
                  userId={currentUser.id}
                  onRevisionSubmit={handleRevisionSubmit}
                  onRequestClarification={handleClarificationRequest}
                  isLoading={isLoading}
                />
              )}
            </div>
          </div>
        ) : (
          /* Dashboard View */
          <ApprovalDashboard
            userRole={currentUser.role}
            userId={currentUser.id}
            userName={currentUser.name}
            onViewContent={handleViewContent}
            onBulkAction={handleBulkAction}
          />
        )}

        {/* Feature Overview */}
        <Card>
          <CardHeader>
            <CardTitle>Workflow Features Demonstrated</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              <div className="space-y-2">
                <h4 className="font-medium text-sm">State Machine</h4>
                <p className="text-xs text-muted-foreground">
                  Content flows through defined states: Draft → Review → Approved → Published
                </p>
              </div>
              <div className="space-y-2">
                <h4 className="font-medium text-sm">Role-Based Permissions</h4>
                <p className="text-xs text-muted-foreground">
                  Different user roles have different permissions and available actions
                </p>
              </div>
              <div className="space-y-2">
                <h4 className="font-medium text-sm">Review Comments</h4>
                <p className="text-xs text-muted-foreground">
                  Reviewers can provide detailed feedback with approval/rejection decisions
                </p>
              </div>
              <div className="space-y-2">
                <h4 className="font-medium text-sm">Rejection Handling</h4>
                <p className="text-xs text-muted-foreground">
                  Content creators can address feedback and track revision progress
                </p>
              </div>
              <div className="space-y-2">
                <h4 className="font-medium text-sm">Notifications</h4>
                <p className="text-xs text-muted-foreground">
                  Users receive notifications about status changes and required actions
                </p>
              </div>
              <div className="space-y-2">
                <h4 className="font-medium text-sm">Bulk Operations</h4>
                <p className="text-xs text-muted-foreground">
                  Approvers can perform bulk actions on multiple content items
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

export { ApprovalWorkflowDemo }