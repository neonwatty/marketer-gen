"use client"

import * as React from "react"
import { useState, useEffect } from "react"
import { cn } from "@/lib/utils"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Checkbox } from "@/components/ui/checkbox"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { ContentApprovalData } from "@/lib/approval-actions"
import { ContentStatus } from "@prisma/client"
import { approvalWorkflow } from "@/lib/approval-workflow"
import { 
  CheckCircle, 
  XCircle, 
  Clock, 
  Edit, 
  Eye, 
  Globe, 
  Archive, 
  Search, 
  Filter,
  ChevronRight,
  Calendar,
  User,
  MoreVertical
} from "lucide-react"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"

interface ApprovalDashboardProps {
  userRole?: string
  userId?: string
  userName?: string
  onViewContent?: (contentId: string) => void
  onBulkAction?: (action: string, contentIds: string[], comment?: string) => void
}

interface ApprovalStats {
  total: number
  byStatus: Record<string, number>
}

export function ApprovalDashboard({
  userRole,
  userId,
  userName,
  onViewContent,
  onBulkAction
}: ApprovalDashboardProps) {
  const [content, setContent] = useState<ContentApprovalData[]>([])
  const [filteredContent, setFilteredContent] = useState<ContentApprovalData[]>([])
  const [selectedContent, setSelectedContent] = useState<string[]>([])
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState<ContentStatus | "all">("all")
  const [isLoading, setIsLoading] = useState(true)
  const [stats, setStats] = useState<ApprovalStats>({ total: 0, byStatus: {} })
  const [activeTab, setActiveTab] = useState("pending")
  const [isBulkDialogOpen, setIsBulkDialogOpen] = useState(false)
  const [bulkAction, setBulkAction] = useState<string>("")

  // Load content data
  useEffect(() => {
    loadApprovalContent()
  }, [userRole])

  // Filter content based on search and status
  useEffect(() => {
    let filtered = content

    // Filter by search term
    if (searchTerm) {
      filtered = filtered.filter(item =>
        item.title.toLowerCase().includes(searchTerm.toLowerCase())
      )
    }

    // Filter by status
    if (statusFilter !== "all") {
      filtered = filtered.filter(item => item.status === statusFilter)
    }

    // Filter by tab
    if (activeTab === "pending") {
      filtered = filtered.filter(item => 
        item.status === 'REVIEWING' || 
        (item.status === 'APPROVED' && item.availableActions.includes('publish'))
      )
    } else if (activeTab === "reviewing") {
      filtered = filtered.filter(item => item.status === 'REVIEWING')
    } else if (activeTab === "approved") {
      filtered = filtered.filter(item => item.status === 'APPROVED')
    } else if (activeTab === "published") {
      filtered = filtered.filter(item => item.status === 'PUBLISHED')
    }

    setFilteredContent(filtered)
  }, [content, searchTerm, statusFilter, activeTab])

  const loadApprovalContent = async () => {
    try {
      setIsLoading(true)
      const params = new URLSearchParams()
      if (userRole) params.set('userRole', userRole)

      const response = await fetch(`/api/content/approvals?${params}`)
      const data = await response.json()

      if (response.ok) {
        setContent(data.content)
        setStats({ total: data.total, byStatus: data.byStatus })
      } else {
        console.error('Failed to load approval content:', data.error)
      }
    } catch (error) {
      console.error('Error loading approval content:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const handleContentSelection = (contentId: string, checked: boolean) => {
    if (checked) {
      setSelectedContent(prev => [...prev, contentId])
    } else {
      setSelectedContent(prev => prev.filter(id => id !== contentId))
    }
  }

  const handleSelectAll = (checked: boolean) => {
    if (checked) {
      setSelectedContent(filteredContent.map(item => item.id))
    } else {
      setSelectedContent([])
    }
  }

  const handleBulkAction = (action: string) => {
    if (selectedContent.length === 0) return
    setBulkAction(action)
    setIsBulkDialogOpen(true)
  }

  const confirmBulkAction = () => {
    onBulkAction?.(bulkAction, selectedContent)
    setSelectedContent([])
    setIsBulkDialogOpen(false)
    setBulkAction("")
    loadApprovalContent() // Refresh data
  }

  const getStatusIcon = (status: ContentStatus) => {
    const iconMap = {
      DRAFT: Edit,
      GENERATING: Clock,
      GENERATED: Eye,
      REVIEWING: Clock,
      APPROVED: CheckCircle,
      PUBLISHED: Globe,
      ARCHIVED: Archive
    }
    return iconMap[status] || Clock
  }

  const getStatusColor = (status: ContentStatus) => {
    const stateInfo = approvalWorkflow.getStateInfo(status)
    return stateInfo.color
  }

  const formatDate = (date: string | Date) => {
    return new Date(date).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  if (isLoading) {
    return (
      <div className="space-y-4">
        <div className="grid gap-4 md:grid-cols-4">
          {[...Array(4)].map((_, i) => (
            <Card key={i} className="animate-pulse">
              <CardHeader className="pb-2">
                <div className="h-4 bg-muted rounded w-1/2" />
              </CardHeader>
              <CardContent>
                <div className="h-8 bg-muted rounded w-1/4" />
              </CardContent>
            </Card>
          ))}
        </div>
        <Card className="animate-pulse">
          <CardContent className="p-6">
            <div className="space-y-4">
              {[...Array(5)].map((_, i) => (
                <div key={i} className="h-16 bg-muted rounded" />
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Stats Cards */}
      <div className="grid gap-4 md:grid-cols-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Total Content</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.total}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Under Review</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.byStatus.REVIEWING || 0}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Approved</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.byStatus.APPROVED || 0}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Published</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.byStatus.PUBLISHED || 0}</div>
          </CardContent>
        </Card>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-6">
          <div className="flex items-center justify-between gap-4">
            <div className="flex items-center gap-4">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground w-4 h-4" />
                <Input
                  placeholder="Search content..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="pl-9 w-64"
                />
              </div>
              <Select value={statusFilter} onValueChange={(value: ContentStatus | "all") => setStatusFilter(value)}>
                <SelectTrigger className="w-40">
                  <SelectValue placeholder="Filter by status" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Status</SelectItem>
                  <SelectItem value="REVIEWING">Under Review</SelectItem>
                  <SelectItem value="APPROVED">Approved</SelectItem>
                  <SelectItem value="PUBLISHED">Published</SelectItem>
                </SelectContent>
              </Select>
            </div>
            
            {selectedContent.length > 0 && (
              <div className="flex items-center gap-2">
                <span className="text-sm text-muted-foreground">
                  {selectedContent.length} selected
                </span>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleBulkAction('bulk_approve')}
                  disabled={!selectedContent.some(id => {
                    const item = content.find(c => c.id === id)
                    return item?.canApprove
                  })}
                >
                  <CheckCircle className="w-4 h-4 mr-2" />
                  Bulk Approve
                </Button>
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Content Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList>
          <TabsTrigger value="pending">
            Pending ({filteredContent.filter(c => 
              c.status === 'REVIEWING' || 
              (c.status === 'APPROVED' && c.availableActions.includes('publish'))
            ).length})
          </TabsTrigger>
          <TabsTrigger value="reviewing">
            Under Review ({stats.byStatus.REVIEWING || 0})
          </TabsTrigger>
          <TabsTrigger value="approved">
            Approved ({stats.byStatus.APPROVED || 0})
          </TabsTrigger>
          <TabsTrigger value="published">
            Published ({stats.byStatus.PUBLISHED || 0})
          </TabsTrigger>
        </TabsList>

        <TabsContent value={activeTab} className="space-y-4">
          <Card>
            <CardContent className="p-6">
              {filteredContent.length === 0 ? (
                <div className="text-center py-12">
                  <Eye className="mx-auto h-12 w-12 text-muted-foreground mb-4" />
                  <h3 className="text-lg font-medium">No content found</h3>
                  <p className="text-muted-foreground">
                    {searchTerm || statusFilter !== "all" 
                      ? "Try adjusting your search or filters." 
                      : "No content items match the current tab filter."}
                  </p>
                </div>
              ) : (
                <div className="space-y-4">
                  {/* Header with select all */}
                  <div className="flex items-center gap-4 border-b pb-4">
                    <Checkbox
                      checked={selectedContent.length === filteredContent.length}
                      onCheckedChange={handleSelectAll}
                    />
                    <span className="text-sm font-medium">Select All</span>
                  </div>

                  {/* Content List */}
                  <div className="space-y-3">
                    {filteredContent.map((item) => {
                      const StatusIcon = getStatusIcon(item.status)
                      const stateInfo = approvalWorkflow.getStateInfo(item.status)
                      const approvalInfo = approvalWorkflow.getApprovalStatusInfo(item.approvalStatus)

                      return (
                        <div
                          key={item.id}
                          className="flex items-center gap-4 p-4 border rounded-lg hover:bg-muted/50 transition-colors"
                        >
                          <Checkbox
                            checked={selectedContent.includes(item.id)}
                            onCheckedChange={(checked) => handleContentSelection(item.id, checked as boolean)}
                          />

                          <div className="flex-1 min-w-0">
                            <div className="flex items-center justify-between">
                              <div className="flex items-center gap-3">
                                <StatusIcon className={cn(
                                  "w-5 h-5",
                                  stateInfo.color === 'green' && 'text-green-500',
                                  stateInfo.color === 'yellow' && 'text-yellow-500',
                                  stateInfo.color === 'blue' && 'text-blue-500',
                                  stateInfo.color === 'purple' && 'text-purple-500',
                                  stateInfo.color === 'gray' && 'text-gray-500'
                                )} />
                                <div>
                                  <h4 className="font-medium truncate">{item.title}</h4>
                                  <div className="flex items-center gap-2 mt-1">
                                    <Badge variant="outline" className="text-xs">
                                      {stateInfo.label}
                                    </Badge>
                                    <Badge 
                                      variant={
                                        item.approvalStatus === 'APPROVED' ? 'default' :
                                        item.approvalStatus === 'REJECTED' ? 'destructive' :
                                        'secondary'
                                      }
                                      className="text-xs"
                                    >
                                      {approvalInfo.label}
                                    </Badge>
                                  </div>
                                </div>
                              </div>

                              <div className="flex items-center gap-3">
                                {/* Action Buttons */}
                                {item.canApprove && (
                                  <Button size="sm" variant="outline">
                                    <CheckCircle className="w-4 h-4 mr-2" />
                                    Approve
                                  </Button>
                                )}
                                {item.canPublish && (
                                  <Button size="sm" variant="outline">
                                    <Globe className="w-4 h-4 mr-2" />
                                    Publish
                                  </Button>
                                )}

                                {/* View Content Button */}
                                <Button
                                  size="sm"
                                  variant="ghost"
                                  onClick={() => onViewContent?.(item.id)}
                                >
                                  <Eye className="w-4 h-4 mr-2" />
                                  View
                                </Button>

                                {/* More Actions */}
                                <DropdownMenu>
                                  <DropdownMenuTrigger asChild>
                                    <Button variant="ghost" size="sm">
                                      <MoreVertical className="w-4 h-4" />
                                    </Button>
                                  </DropdownMenuTrigger>
                                  <DropdownMenuContent>
                                    {item.availableActions.map(action => (
                                      <DropdownMenuItem key={action}>
                                        {action.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}
                                      </DropdownMenuItem>
                                    ))}
                                  </DropdownMenuContent>
                                </DropdownMenu>
                              </div>
                            </div>

                            {/* Comments Preview */}
                            {item.comments.length > 0 && (
                              <div className="mt-3 text-sm text-muted-foreground">
                                <div className="flex items-center gap-2">
                                  <User className="w-4 h-4" />
                                  <span>Last comment by {item.comments[0].userName || 'Anonymous'}</span>
                                  <Calendar className="w-4 h-4 ml-2" />
                                  <span>{formatDate(item.comments[0].createdAt)}</span>
                                </div>
                              </div>
                            )}
                          </div>
                        </div>
                      )
                    })}
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* Bulk Action Confirmation Dialog */}
      <Dialog open={isBulkDialogOpen} onOpenChange={setIsBulkDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Confirm Bulk Action</DialogTitle>
            <DialogDescription>
              Are you sure you want to {bulkAction.replace('bulk_', '').replace('_', ' ')} {selectedContent.length} content items?
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsBulkDialogOpen(false)}>
              Cancel
            </Button>
            <Button onClick={confirmBulkAction}>
              Confirm {bulkAction.replace('bulk_', '').replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}

export { ApprovalDashboard }
export type { ApprovalDashboardProps }