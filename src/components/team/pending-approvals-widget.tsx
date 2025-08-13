'use client'

import React, { useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Separator } from '@/components/ui/separator'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import {
  Clock,
  CheckCircle,
  XCircle,
  AlertTriangle,
  MoreHorizontal,
  ExternalLink,
  User,
  Calendar,
  FileText,
  Image,
  Video,
  Mail,
  Eye,
  MessageSquare,
  ArrowRight
} from 'lucide-react'
import { formatDistanceToNow } from 'date-fns'

interface PendingApproval {
  id: string
  type: 'content' | 'campaign' | 'design' | 'email' | 'video'
  title: string
  description: string
  submittedBy: string
  submittedByAvatar?: string
  submittedAt: Date
  dueDate?: Date
  priority: 'low' | 'medium' | 'high' | 'urgent'
  workflowStage: string
  approvers: string[]
  currentApprover: string
  status: 'pending' | 'reviewing' | 'overdue'
  tags: string[]
  previewUrl?: string
  commentsCount: number
}

const mockApprovals: PendingApproval[] = [
  {
    id: '1',
    type: 'content',
    title: 'Summer Campaign Blog Post',
    description: 'Blog post about our summer product launch featuring new features and customer testimonials',
    submittedBy: 'Sarah Wilson',
    submittedAt: new Date('2024-01-15T10:30:00Z'),
    dueDate: new Date('2024-01-18T17:00:00Z'),
    priority: 'high',
    workflowStage: 'Content Review',
    approvers: ['Lisa Brown', 'Mike Johnson'],
    currentApprover: 'Lisa Brown',
    status: 'pending',
    tags: ['blog', 'summer', 'product-launch'],
    commentsCount: 3
  },
  {
    id: '2',
    type: 'design',
    title: 'Email Template Design',
    description: 'Responsive email template for the quarterly newsletter',
    submittedBy: 'Mike Johnson',
    submittedAt: new Date('2024-01-15T08:45:00Z'),
    dueDate: new Date('2024-01-16T12:00:00Z'),
    priority: 'medium',
    workflowStage: 'Design Review',
    approvers: ['Lisa Brown'],
    currentApprover: 'Lisa Brown',
    status: 'overdue',
    tags: ['email', 'template', 'newsletter'],
    previewUrl: '/preview/email-template-q1',
    commentsCount: 1
  },
  {
    id: '3',
    type: 'campaign',
    title: 'Q1 Social Media Campaign',
    description: 'Complete social media campaign strategy and content calendar for Q1',
    submittedBy: 'David Lee',
    submittedAt: new Date('2024-01-14T16:20:00Z'),
    dueDate: new Date('2024-01-20T10:00:00Z'),
    priority: 'urgent',
    workflowStage: 'Strategy Review',
    approvers: ['Lisa Brown', 'John Doe'],
    currentApprover: 'John Doe',
    status: 'reviewing',
    tags: ['social-media', 'q1', 'strategy'],
    commentsCount: 7
  },
  {
    id: '4',
    type: 'email',
    title: 'Welcome Email Series',
    description: 'Automated welcome email sequence for new subscribers',
    submittedBy: 'Sarah Wilson',
    submittedAt: new Date('2024-01-13T11:15:00Z'),
    dueDate: new Date('2024-01-19T15:00:00Z'),
    priority: 'medium',
    workflowStage: 'Copy Review',
    approvers: ['David Lee', 'Lisa Brown'],
    currentApprover: 'David Lee',
    status: 'pending',
    tags: ['email', 'automation', 'onboarding'],
    commentsCount: 2
  },
  {
    id: '5',
    type: 'video',
    title: 'Product Demo Video',
    description: 'Short product demonstration video for the landing page',
    submittedBy: 'John Doe',
    submittedAt: new Date('2024-01-12T14:30:00Z'),
    dueDate: new Date('2024-01-17T11:00:00Z'),
    priority: 'high',
    workflowStage: 'Final Review',
    approvers: ['Lisa Brown'],
    currentApprover: 'Lisa Brown',
    status: 'pending',
    tags: ['video', 'product', 'demo'],
    previewUrl: '/preview/product-demo',
    commentsCount: 5
  }
]

const getTypeIcon = (type: string) => {
  switch (type) {
    case 'content':
      return <FileText className="h-4 w-4" />
    case 'design':
      return <Image className="h-4 w-4" />
    case 'campaign':
      return <ArrowRight className="h-4 w-4" />
    case 'email':
      return <Mail className="h-4 w-4" />
    case 'video':
      return <Video className="h-4 w-4" />
    default:
      return <FileText className="h-4 w-4" />
  }
}

const getPriorityColor = (priority: string) => {
  switch (priority) {
    case 'urgent':
      return 'destructive'
    case 'high':
      return 'default'
    case 'medium':
      return 'secondary'
    case 'low':
      return 'outline'
    default:
      return 'secondary'
  }
}

const getStatusColor = (status: string) => {
  switch (status) {
    case 'pending':
      return 'bg-yellow-100 text-yellow-800'
    case 'reviewing':
      return 'bg-blue-100 text-blue-800'
    case 'overdue':
      return 'bg-red-100 text-red-800'
    default:
      return 'bg-gray-100 text-gray-800'
  }
}

interface PendingApprovalsWidgetProps {
  showAll?: boolean
}

export const PendingApprovalsWidget: React.FC<PendingApprovalsWidgetProps> = ({ 
  showAll = false 
}) => {
  const [approvals, setApprovals] = useState<PendingApproval[]>(mockApprovals)
  const [loading, setLoading] = useState(false)

  const displayedApprovals = showAll ? approvals : approvals.slice(0, 5)

  const handleApprove = async (approvalId: string) => {
    setLoading(true)
    try {
      // In a real implementation, this would call an API
      await new Promise(resolve => setTimeout(resolve, 1000))
      setApprovals(prev => prev.filter(a => a.id !== approvalId))
    } catch (error) {
      console.error('Error approving item:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleReject = async (approvalId: string) => {
    setLoading(true)
    try {
      // In a real implementation, this would call an API
      await new Promise(resolve => setTimeout(resolve, 1000))
      setApprovals(prev => prev.filter(a => a.id !== approvalId))
    } catch (error) {
      console.error('Error rejecting item:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleRequestChanges = async (approvalId: string) => {
    // In a real implementation, this would open a dialog to add comments
    console.log('Request changes for:', approvalId)
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <div>
            <CardTitle className="flex items-center gap-2">
              <Clock className="h-5 w-5" />
              Pending Approvals
              <Badge variant="secondary">{approvals.length}</Badge>
            </CardTitle>
            <CardDescription>
              Items waiting for your review and approval
            </CardDescription>
          </div>
          {!showAll && approvals.length > 5 && (
            <Button variant="outline" size="sm">
              View All
            </Button>
          )}
        </div>
      </CardHeader>
      <CardContent>
        {displayedApprovals.length === 0 ? (
          <div className="text-center py-8">
            <CheckCircle className="h-12 w-12 mx-auto text-green-500 mb-4" />
            <h3 className="text-lg font-medium mb-2">All caught up!</h3>
            <p className="text-muted-foreground">
              No pending approvals at the moment.
            </p>
          </div>
        ) : (
          <ScrollArea className={showAll ? "h-[600px]" : "h-[400px]"}>
            <div className="space-y-4">
              {displayedApprovals.map((approval, index) => (
                <div key={approval.id}>
                  <div className="flex items-start gap-3">
                    {/* Type Icon */}
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center ${
                      approval.type === 'urgent' ? 'bg-red-100 text-red-600' :
                      approval.type === 'high' ? 'bg-orange-100 text-orange-600' :
                      'bg-blue-100 text-blue-600'
                    }`}>
                      {getTypeIcon(approval.type)}
                    </div>

                    {/* Content */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between">
                        <div className="min-w-0 flex-1">
                          <h4 className="text-sm font-medium truncate">
                            {approval.title}
                          </h4>
                          <p className="text-xs text-muted-foreground line-clamp-2">
                            {approval.description}
                          </p>
                        </div>
                        
                        <div className="flex items-center gap-2 ml-2">
                          <Badge 
                            variant={getPriorityColor(approval.priority) as any}
                            className="text-xs"
                          >
                            {approval.priority}
                          </Badge>
                          <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                              <Button variant="ghost" size="sm" className="h-6 w-6 p-0">
                                <MoreHorizontal className="h-3 w-3" />
                              </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end">
                              <DropdownMenuItem onClick={() => handleApprove(approval.id)}>
                                <CheckCircle className="h-4 w-4 mr-2" />
                                Approve
                              </DropdownMenuItem>
                              <DropdownMenuItem onClick={() => handleRequestChanges(approval.id)}>
                                <MessageSquare className="h-4 w-4 mr-2" />
                                Request Changes
                              </DropdownMenuItem>
                              <DropdownMenuItem 
                                onClick={() => handleReject(approval.id)}
                                className="text-red-600"
                              >
                                <XCircle className="h-4 w-4 mr-2" />
                                Reject
                              </DropdownMenuItem>
                              {approval.previewUrl && (
                                <DropdownMenuItem>
                                  <Eye className="h-4 w-4 mr-2" />
                                  Preview
                                </DropdownMenuItem>
                              )}
                              <DropdownMenuItem>
                                <ExternalLink className="h-4 w-4 mr-2" />
                                Open
                              </DropdownMenuItem>
                            </DropdownMenuContent>
                          </DropdownMenu>
                        </div>
                      </div>

                      {/* Metadata */}
                      <div className="flex items-center gap-4 mt-2 text-xs text-muted-foreground">
                        <div className="flex items-center gap-1">
                          <User className="h-3 w-3" />
                          {approval.submittedBy}
                        </div>
                        <div className="flex items-center gap-1">
                          <Calendar className="h-3 w-3" />
                          {formatDistanceToNow(approval.submittedAt, { addSuffix: true })}
                        </div>
                        {approval.commentsCount > 0 && (
                          <div className="flex items-center gap-1">
                            <MessageSquare className="h-3 w-3" />
                            {approval.commentsCount}
                          </div>
                        )}
                        {approval.dueDate && (
                          <div className={`flex items-center gap-1 ${
                            approval.status === 'overdue' ? 'text-red-600' : ''
                          }`}>
                            <Clock className="h-3 w-3" />
                            Due {formatDistanceToNow(approval.dueDate, { addSuffix: true })}
                          </div>
                        )}
                      </div>

                      {/* Status and Workflow */}
                      <div className="flex items-center gap-2 mt-2">
                        <Badge 
                          variant="outline"
                          className={`text-xs ${getStatusColor(approval.status)}`}
                        >
                          {approval.status}
                        </Badge>
                        <span className="text-xs text-muted-foreground">
                          {approval.workflowStage}
                        </span>
                        {approval.status === 'overdue' && (
                          <AlertTriangle className="h-3 w-3 text-red-600" />
                        )}
                      </div>

                      {/* Tags */}
                      {approval.tags.length > 0 && (
                        <div className="flex flex-wrap gap-1 mt-2">
                          {approval.tags.map((tag) => (
                            <Badge 
                              key={tag} 
                              variant="outline" 
                              className="text-xs px-1.5 py-0.5"
                            >
                              {tag}
                            </Badge>
                          ))}
                        </div>
                      )}

                      {/* Quick Actions */}
                      <div className="flex items-center gap-2 mt-3">
                        <Button 
                          size="sm" 
                          onClick={() => handleApprove(approval.id)}
                          disabled={loading}
                        >
                          <CheckCircle className="h-3 w-3 mr-1" />
                          Approve
                        </Button>
                        <Button 
                          variant="outline" 
                          size="sm"
                          onClick={() => handleRequestChanges(approval.id)}
                        >
                          <MessageSquare className="h-3 w-3 mr-1" />
                          Comment
                        </Button>
                        {approval.previewUrl && (
                          <Button variant="outline" size="sm">
                            <Eye className="h-3 w-3 mr-1" />
                            Preview
                          </Button>
                        )}
                      </div>
                    </div>
                  </div>
                  
                  {index < displayedApprovals.length - 1 && (
                    <Separator className="my-4" />
                  )}
                </div>
              ))}
            </div>
          </ScrollArea>
        )}
      </CardContent>
    </Card>
  )
}

export default PendingApprovalsWidget