import React, { useState } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Progress } from "@/components/ui/progress"
import { 
  MoreHorizontal, 
  Edit, 
  Play, 
  Pause, 
  Stop, 
  Copy,
  Calendar,
  Target,
  Users,
  DollarSign,
  Activity,
  Loader2
} from "lucide-react"

export type CampaignStatus = "draft" | "active" | "paused" | "completed" | "cancelled"

export interface CampaignMetrics {
  progress: number
  contentPieces: number
  channels: string[]
  budget?: number
  impressions?: number
  engagement?: number
  conversions?: number
}

export interface CampaignCardProps {
  id: string
  title: string
  description: string
  status: CampaignStatus
  createdAt: string
  metrics: CampaignMetrics
  onEdit?: (id: string) => void
  onStatusChange?: (id: string, newStatus: CampaignStatus) => Promise<void> | void
  onCopy?: (id: string) => void
  onDelete?: (id: string) => void
  isLoading?: boolean
  loadingActions?: string[]
}

const statusConfig: Record<CampaignStatus, {
  label: string
  variant: "default" | "secondary" | "destructive" | "outline"
  bgColor: string
  textColor: string
}> = {
  draft: {
    label: "Draft",
    variant: "secondary",
    bgColor: "bg-slate-100 dark:bg-slate-800",
    textColor: "text-slate-700 dark:text-slate-300"
  },
  active: {
    label: "Active",
    variant: "default",
    bgColor: "bg-green-100 dark:bg-green-900/20",
    textColor: "text-green-700 dark:text-green-300"
  },
  paused: {
    label: "Paused",
    variant: "outline",
    bgColor: "bg-yellow-100 dark:bg-yellow-900/20",
    textColor: "text-yellow-700 dark:text-yellow-300"
  },
  completed: {
    label: "Completed",
    variant: "secondary",
    bgColor: "bg-blue-100 dark:bg-blue-900/20",
    textColor: "text-blue-700 dark:text-blue-300"
  },
  cancelled: {
    label: "Cancelled",
    variant: "destructive",
    bgColor: "bg-red-100 dark:bg-red-900/20",
    textColor: "text-red-700 dark:text-red-300"
  }
}

function formatNumber(num: number): string {
  if (num >= 1000000) {
    return `${(num / 1000000).toFixed(1)}M`
  }
  if (num >= 1000) {
    return `${(num / 1000).toFixed(1)}K`
  }
  return num.toString()
}

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount)
}

export function CampaignCard({
  id,
  title,
  description,
  status,
  createdAt,
  metrics,
  onEdit,
  onStatusChange,
  onCopy,
  onDelete,
  isLoading = false,
  loadingActions = []
}: CampaignCardProps) {
  const config = statusConfig[status]
  const [optimisticStatus, setOptimisticStatus] = useState(status)
  const [loadingOperation, setLoadingOperation] = useState<string | null>(null)

  const handleStatusChange = async (newStatus: CampaignStatus) => {
    if (!onStatusChange) return
    
    setOptimisticStatus(newStatus)
    setLoadingOperation(`status-${newStatus}`)
    
    try {
      await onStatusChange(id, newStatus)
    } catch (error) {
      setOptimisticStatus(status)
    } finally {
      setLoadingOperation(null)
    }
  }

  const isActionLoading = (actionType: string) => {
    return isLoading || loadingActions.includes(actionType) || loadingOperation === actionType
  }

  const getActionButton = () => {
    switch (status) {
      case "draft":
        const launchLoading = isActionLoading("status-active")
        return (
          <Button 
            variant="outline" 
            size="sm"
            onClick={() => handleStatusChange("active")}
            disabled={launchLoading}
          >
            {launchLoading ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : (
              <Play className="h-4 w-4 mr-2" />
            )}
            Launch
          </Button>
        )
      case "active":
        const pauseLoading = isActionLoading("status-paused")
        return (
          <Button 
            variant="outline" 
            size="sm"
            onClick={() => handleStatusChange("paused")}
            disabled={pauseLoading}
          >
            {pauseLoading ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : (
              <Pause className="h-4 w-4 mr-2" />
            )}
            Pause
          </Button>
        )
      case "paused":
        const resumeLoading = isActionLoading("status-active")
        return (
          <Button 
            variant="outline" 
            size="sm"
            onClick={() => handleStatusChange("active")}
            disabled={resumeLoading}
          >
            {resumeLoading ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : (
              <Play className="h-4 w-4 mr-2" />
            )}
            Resume
          </Button>
        )
      case "completed":
        const copyLoading = isActionLoading("copy")
        return (
          <Button 
            variant="outline" 
            size="sm"
            onClick={() => onCopy?.(id)}
            disabled={copyLoading}
          >
            {copyLoading ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : (
              <Copy className="h-4 w-4 mr-2" />
            )}
            Copy
          </Button>
        )
      default:
        return null
    }
  }

  const displayConfig = statusConfig[optimisticStatus] || config

  return (
    <Card className={`relative hover:shadow-md transition-all duration-300 ${isLoading || loadingOperation ? "opacity-95" : ""}`}>
      {/* Status indicator bar */}
      <div className={`absolute top-0 left-0 right-0 h-1 transition-colors duration-300 ${displayConfig.bgColor}`} />
      
      <CardHeader>
        <div className="flex items-start justify-between">
          <div className="space-y-1 flex-1">
            <CardTitle className="text-xl">{title}</CardTitle>
            <CardDescription>{description}</CardDescription>
          </div>
          <div className="flex items-center gap-2">
            <Badge variant={displayConfig.variant} className={`transition-colors duration-300 ${displayConfig.bgColor}`}>
              <div className={`w-2 h-2 rounded-full transition-colors duration-300 ${displayConfig.bgColor} mr-1.5`} />
              {displayConfig.label}
            </Badge>
            <Button variant="ghost" size="icon">
              <MoreHorizontal className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </CardHeader>

      <CardContent>
        <div className="space-y-4">
          {/* Progress Section */}
          <div className="space-y-2">
            <div className="flex items-center justify-between text-sm">
              <span className="text-muted-foreground">Progress</span>
              <span className="font-medium">{metrics.progress}% complete</span>
            </div>
            <Progress value={metrics.progress} className="h-2" />
          </div>

          {/* Metrics Grid */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <div className="flex items-center gap-2">
              <Calendar className="h-4 w-4 text-muted-foreground" />
              <div>
                <div className="text-muted-foreground">Created</div>
                <div className="font-medium">{createdAt}</div>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <Target className="h-4 w-4 text-muted-foreground" />
              <div>
                <div className="text-muted-foreground">Channels</div>
                <div className="font-medium">{metrics.channels.join(", ")}</div>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <Activity className="h-4 w-4 text-muted-foreground" />
              <div>
                <div className="text-muted-foreground">Content</div>
                <div className="font-medium">{metrics.contentPieces} pieces</div>
              </div>
            </div>
            {metrics.budget && (
              <div className="flex items-center gap-2">
                <DollarSign className="h-4 w-4 text-muted-foreground" />
                <div>
                  <div className="text-muted-foreground">Budget</div>
                  <div className="font-medium">{formatCurrency(metrics.budget)}</div>
                </div>
              </div>
            )}
          </div>

          {/* Performance Metrics (if available) */}
          {(metrics.impressions || metrics.engagement || metrics.conversions) && (
            <div className="grid grid-cols-3 gap-4 pt-4 border-t">
              {metrics.impressions && (
                <div className="text-center">
                  <div className="text-2xl font-bold">{formatNumber(metrics.impressions)}</div>
                  <div className="text-xs text-muted-foreground">Impressions</div>
                </div>
              )}
              {metrics.engagement && (
                <div className="text-center">
                  <div className="text-2xl font-bold">{metrics.engagement}%</div>
                  <div className="text-xs text-muted-foreground">Engagement</div>
                </div>
              )}
              {metrics.conversions && (
                <div className="text-center">
                  <div className="text-2xl font-bold">{formatNumber(metrics.conversions)}</div>
                  <div className="text-xs text-muted-foreground">Conversions</div>
                </div>
              )}
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex gap-2 pt-2">
            <Button 
              variant="outline" 
              size="sm"
              onClick={() => onEdit?.(id)}
              disabled={isActionLoading("edit")}
            >
              {isActionLoading("edit") ? (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <Edit className="h-4 w-4 mr-2" />
              )}
              Edit
            </Button>
            {getActionButton()}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}