"use client"

import * as React from "react"
import { ColumnDef } from "@tanstack/react-table"
import { MoreHorizontal, Eye, Edit, Copy, Trash2 } from "lucide-react"

import { DataTable } from "@/components/ui/data-table"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Progress } from "@/components/ui/progress"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { type CampaignStatus } from "@/components/ui/campaign-card"

export interface CampaignTableData {
  id: string
  title: string
  description: string
  status: CampaignStatus
  createdAt: string
  progress: number
  channels: string[]
  contentPieces: number
  budget?: number
  impressions?: number
  engagement?: number
  conversions?: number
}

interface CampaignDataTableProps {
  data: CampaignTableData[]
  onView?: (campaign: CampaignTableData) => void
  onEdit?: (campaign: CampaignTableData) => void
  onCopy?: (campaign: CampaignTableData) => void
  onDelete?: (campaign: CampaignTableData) => void
  onExport?: () => void
}

const statusConfig: Record<CampaignStatus, {
  label: string
  variant: "default" | "secondary" | "destructive" | "outline"
  className: string
}> = {
  draft: {
    label: "Draft",
    variant: "secondary",
    className: "bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300"
  },
  active: {
    label: "Active",
    variant: "default", 
    className: "bg-green-100 text-green-700 dark:bg-green-900/20 dark:text-green-300"
  },
  paused: {
    label: "Paused",
    variant: "outline",
    className: "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/20 dark:text-yellow-300"
  },
  completed: {
    label: "Completed",
    variant: "secondary",
    className: "bg-blue-100 text-blue-700 dark:bg-blue-900/20 dark:text-blue-300"
  },
  cancelled: {
    label: "Cancelled",
    variant: "destructive",
    className: "bg-red-100 text-red-700 dark:bg-red-900/20 dark:text-red-300"
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

export function CampaignDataTable({ 
  data, 
  onView,
  onEdit, 
  onCopy, 
  onDelete,
  onExport 
}: CampaignDataTableProps) {
  
  const columns: ColumnDef<CampaignTableData>[] = [
    {
      accessorKey: "title",
      header: "Campaign",
      cell: ({ row }) => (
        <div className="min-w-0 max-w-[300px]">
          <div className="font-medium truncate">{row.getValue("title")}</div>
          <div className="text-sm text-muted-foreground truncate">
            {row.original.description}
          </div>
        </div>
      ),
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => {
        const status = row.getValue("status") as CampaignStatus
        const config = statusConfig[status]
        return (
          <Badge 
            variant={config.variant}
            className={config.className}
          >
            {config.label}
          </Badge>
        )
      },
      filterFn: "equals",
    },
    {
      accessorKey: "progress",
      header: "Progress",
      cell: ({ row }) => {
        const progress = row.getValue("progress") as number
        return (
          <div className="w-[60px]">
            <div className="flex items-center space-x-2">
              <Progress value={progress} className="flex-1 h-2" />
              <span className="text-xs text-muted-foreground min-w-[30px] text-right">
                {progress}%
              </span>
            </div>
          </div>
        )
      },
    },
    {
      accessorKey: "channels",
      header: "Channels",
      cell: ({ row }) => {
        const channels = row.getValue("channels") as string[]
        return (
          <div className="flex flex-wrap gap-1">
            {channels.slice(0, 2).map((channel) => (
              <Badge key={channel} variant="outline" className="text-xs">
                {channel}
              </Badge>
            ))}
            {channels.length > 2 && (
              <Badge variant="outline" className="text-xs">
                +{channels.length - 2}
              </Badge>
            )}
          </div>
        )
      },
    },
    {
      accessorKey: "contentPieces",
      header: "Content",
      cell: ({ row }) => {
        const count = row.getValue("contentPieces") as number
        return (
          <div className="text-center">
            <span className="font-medium">{count}</span>
            <span className="text-xs text-muted-foreground ml-1">pieces</span>
          </div>
        )
      },
    },
    {
      accessorKey: "budget",
      header: "Budget",
      cell: ({ row }) => {
        const budget = row.original.budget
        return budget ? formatCurrency(budget) : "-"
      },
    },
    {
      accessorKey: "impressions",
      header: "Impressions",
      cell: ({ row }) => {
        const impressions = row.original.impressions
        return impressions ? formatNumber(impressions) : "-"
      },
    },
    {
      accessorKey: "engagement",
      header: "Engagement",
      cell: ({ row }) => {
        const engagement = row.original.engagement
        return engagement ? `${engagement}%` : "-"
      },
    },
    {
      accessorKey: "createdAt",
      header: "Created",
      cell: ({ row }) => {
        return (
          <div className="text-sm">
            {row.getValue("createdAt")}
          </div>
        )
      },
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => {
        const campaign = row.original

        return (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" className="h-8 w-8 p-0">
                <span className="sr-only">Open menu</span>
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {onView && (
                <DropdownMenuItem onClick={() => onView(campaign)}>
                  <Eye className="mr-2 h-4 w-4" />
                  View details
                </DropdownMenuItem>
              )}
              {onEdit && (
                <DropdownMenuItem onClick={() => onEdit(campaign)}>
                  <Edit className="mr-2 h-4 w-4" />
                  Edit campaign
                </DropdownMenuItem>
              )}
              {onCopy && (
                <DropdownMenuItem onClick={() => onCopy(campaign)}>
                  <Copy className="mr-2 h-4 w-4" />
                  Duplicate
                </DropdownMenuItem>
              )}
              {onDelete && (
                <>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem 
                    onClick={() => onDelete(campaign)}
                    variant="destructive"
                  >
                    <Trash2 className="mr-2 h-4 w-4" />
                    Delete
                  </DropdownMenuItem>
                </>
              )}
            </DropdownMenuContent>
          </DropdownMenu>
        )
      },
    },
  ]

  const filterable = [
    {
      key: "status",
      title: "Status",
      options: [
        { label: "Draft", value: "draft" },
        { label: "Active", value: "active" },
        { label: "Paused", value: "paused" },
        { label: "Completed", value: "completed" },
        { label: "Cancelled", value: "cancelled" },
      ],
    },
  ]

  return (
    <DataTable
      columns={columns}
      data={data}
      searchKey="title"
      searchPlaceholder="Search campaigns..."
      filterable={filterable}
      onRowClick={(row) => onView?.(row)}
      onExport={onExport}
    />
  )
}

export type { CampaignTableData }