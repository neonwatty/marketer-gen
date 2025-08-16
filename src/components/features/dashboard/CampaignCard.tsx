'use client'

import { useState } from 'react'

import { Archive, Copy, Edit, Eye, FileText,MoreHorizontal, TrendingUp, Users } from 'lucide-react'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

export interface CampaignMetrics {
  engagementRate: number
  conversionRate: number
  contentPieces: number
  totalReach?: number
  activeUsers?: number
}

export interface Campaign {
  id: string
  title: string
  description: string
  status: 'active' | 'draft' | 'paused' | 'completed' | 'archived'
  metrics: CampaignMetrics
  progress: number
  createdAt: Date
  updatedAt: Date
}

interface CampaignCardProps {
  campaign: Campaign
  onView?: (id: string) => void
  onEdit?: (id: string) => void
  onDuplicate?: (id: string) => void
  onArchive?: (id: string) => void
}

const statusVariants = {
  active: { variant: 'default' as const, label: 'Active' },
  draft: { variant: 'secondary' as const, label: 'Draft' },
  paused: { variant: 'outline' as const, label: 'Paused' },
  completed: { variant: 'secondary' as const, label: 'Completed' },
  archived: { variant: 'outline' as const, label: 'Archived' },
}

function ProgressBar({ value, className }: { value: number; className?: string }) {
  return (
    <div className={`bg-secondary relative h-2 w-full overflow-hidden rounded-full ${className}`}>
      <div
        className="bg-primary h-full transition-all duration-300 ease-in-out"
        style={{ width: `${Math.min(100, Math.max(0, value))}%` }}
      />
    </div>
  )
}

export function CampaignCard({
  campaign,
  onView,
  onEdit,
  onDuplicate,
  onArchive,
}: CampaignCardProps) {
  const [isDropdownOpen, setIsDropdownOpen] = useState(false)
  const statusConfig = statusVariants[campaign.status]

  const handleAction = (action: () => void) => {
    setIsDropdownOpen(false)
    action()
  }

  return (
    <Card className="group relative transition-all hover:shadow-lg">
      <CardHeader>
        <div className="flex items-start justify-between">
          <div className="space-y-1">
            <CardTitle className="line-clamp-2 text-lg">{campaign.title}</CardTitle>
            <CardDescription className="line-clamp-2">{campaign.description}</CardDescription>
          </div>
          <CardAction>
            <div className="flex items-center gap-2">
              <Badge variant={statusConfig.variant}>{statusConfig.label}</Badge>
              <DropdownMenu open={isDropdownOpen} onOpenChange={setIsDropdownOpen}>
                <DropdownMenuTrigger asChild>
                  <Button variant="outline" size="sm" className="h-8 w-8 p-0">
                    <MoreHorizontal className="h-4 w-4" />
                    <span className="sr-only">Open menu</span>
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="w-[160px]">
                  <DropdownMenuItem onClick={() => handleAction(() => onView?.(campaign.id))}>
                    <Eye className="mr-2 h-4 w-4" />
                    View
                  </DropdownMenuItem>
                  <DropdownMenuItem onClick={() => handleAction(() => onEdit?.(campaign.id))}>
                    <Edit className="mr-2 h-4 w-4" />
                    Edit
                  </DropdownMenuItem>
                  <DropdownMenuItem onClick={() => handleAction(() => onDuplicate?.(campaign.id))}>
                    <Copy className="mr-2 h-4 w-4" />
                    Duplicate
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem 
                    onClick={() => handleAction(() => onArchive?.(campaign.id))}
                    variant="destructive"
                  >
                    <Archive className="mr-2 h-4 w-4" />
                    Archive
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          </CardAction>
        </div>
      </CardHeader>

      <CardContent className="space-y-4">
        {/* Key Metrics */}
        <div className="grid grid-cols-3 gap-4">
          <div className="text-center">
            <div className="text-muted-foreground mb-1 flex items-center justify-center gap-1 text-xs">
              <TrendingUp className="h-3 w-3" />
              Engagement
            </div>
            <div className="text-lg font-semibold">{campaign.metrics.engagementRate}%</div>
          </div>
          <div className="text-center">
            <div className="text-muted-foreground mb-1 flex items-center justify-center gap-1 text-xs">
              <Users className="h-3 w-3" />
              Conversion
            </div>
            <div className="text-lg font-semibold">{campaign.metrics.conversionRate}%</div>
          </div>
          <div className="text-center">
            <div className="text-muted-foreground mb-1 flex items-center justify-center gap-1 text-xs">
              <FileText className="h-3 w-3" />
              Content
            </div>
            <div className="text-lg font-semibold">{campaign.metrics.contentPieces}</div>
          </div>
        </div>

        {/* Progress Indicator */}
        <div className="space-y-2">
          <div className="flex items-center justify-between text-sm">
            <span className="text-muted-foreground">Journey Progress</span>
            <span className="font-medium">{campaign.progress}%</span>
          </div>
          <ProgressBar value={campaign.progress} />
        </div>

        {/* Additional Metrics (if available) */}
        {(campaign.metrics.totalReach || campaign.metrics.activeUsers) && (
          <div className="border-t pt-3">
            <div className="grid grid-cols-2 gap-4 text-sm">
              {campaign.metrics.totalReach && (
                <div>
                  <div className="text-muted-foreground">Total Reach</div>
                  <div className="font-medium">{campaign.metrics.totalReach.toLocaleString()}</div>
                </div>
              )}
              {campaign.metrics.activeUsers && (
                <div>
                  <div className="text-muted-foreground">Active Users</div>
                  <div className="font-medium">{campaign.metrics.activeUsers.toLocaleString()}</div>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Last Updated */}
        <div className="border-t pt-3 text-xs text-muted-foreground">
          Updated {campaign.updatedAt.toLocaleDateString()}
        </div>
      </CardContent>
    </Card>
  )
}