'use client'

import { useState } from 'react'

import { Calendar, Download, FileText, Target, TrendingUp, Users } from 'lucide-react'

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
import { Separator } from '@/components/ui/separator'
import { campaignSummaryService } from '@/lib/services/campaign-summary-service'

import { type Campaign } from '../dashboard/CampaignCard'

export interface CampaignSummaryData {
  executiveSummary: string
  strategicRationale: string
  contentOverview: {
    totalPieces: number
    byType: { [key: string]: number }
    channels: string[]
  }
  timeline: {
    phase: string
    description: string
    duration: string
    deliverables: string[]
  }[]
  performanceProjections: {
    estimatedReach: number
    expectedEngagement: number
    targetConversions: number
    projectedROI: string
  }
  stakeholderBrief: {
    keyMessages: string[]
    successMetrics: string[]
    risksAndMitigation: string[]
  }
  isGenerating?: boolean
}

interface CampaignSummaryProps {
  campaign: Campaign
  onExport?: (format: 'pdf' | 'docx' | 'json') => void
}

export function CampaignSummary({ campaign, onExport }: CampaignSummaryProps) {
  const [summaryData, setSummaryData] = useState<CampaignSummaryData | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleGenerateSummary = async () => {
    setIsLoading(true)
    setError(null)
    
    try {
      const generated = await campaignSummaryService.generateCampaignSummary({
        campaign,
        includeProjections: true,
        includeStakeholderBrief: true
      })
      setSummaryData(generated)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to generate summary')
    } finally {
      setIsLoading(false)
    }
  }

  const handleExport = (format: 'pdf' | 'docx' | 'json') => {
    onExport?.(format)
  }

  if (!summaryData && !isLoading && !error) {
    return (
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Campaign Summary & Plan</CardTitle>
              <CardDescription>
                Generate comprehensive campaign overview with strategic insights
              </CardDescription>
            </div>
            <Button onClick={handleGenerateSummary}>
              <FileText className="mr-2 h-4 w-4" />
              Generate Summary
            </Button>
          </div>
        </CardHeader>
      </Card>
    )
  }

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Generating Campaign Summary...</CardTitle>
          <CardDescription>
            Creating strategic overview and performance projections
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="space-y-2">
              <div className="h-4 bg-muted animate-pulse rounded" />
              <div className="h-4 bg-muted animate-pulse rounded w-3/4" />
              <div className="h-4 bg-muted animate-pulse rounded w-1/2" />
            </div>
            <Separator />
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <div className="h-4 bg-muted animate-pulse rounded" />
                <div className="h-4 bg-muted animate-pulse rounded w-2/3" />
              </div>
              <div className="space-y-2">
                <div className="h-4 bg-muted animate-pulse rounded" />
                <div className="h-4 bg-muted animate-pulse rounded w-2/3" />
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    )
  }

  if (error) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="text-destructive">Generation Failed</CardTitle>
          <CardDescription>{error}</CardDescription>
        </CardHeader>
        <CardContent>
          <Button onClick={handleGenerateSummary} variant="outline">
            <FileText className="mr-2 h-4 w-4" />
            Retry Generation
          </Button>
        </CardContent>
      </Card>
    )
  }

  if (!summaryData) {
    return null
  }

  return (
    <div className="space-y-6">
      {/* Header with Export Actions */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>{campaign.title} - Campaign Summary</CardTitle>
              <CardDescription>
                Comprehensive strategic overview and performance plan
              </CardDescription>
            </div>
            <CardAction>
              <div className="flex items-center gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleExport('pdf')}
                >
                  <Download className="mr-2 h-4 w-4" />
                  PDF
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleExport('docx')}
                >
                  <Download className="mr-2 h-4 w-4" />
                  Word
                </Button>
                <Button onClick={handleGenerateSummary} size="sm">
                  <FileText className="mr-2 h-4 w-4" />
                  Regenerate
                </Button>
              </div>
            </CardAction>
          </div>
        </CardHeader>
      </Card>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Executive Summary */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <FileText className="h-5 w-5" />
              Executive Summary
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm leading-relaxed">{summaryData.executiveSummary}</p>
          </CardContent>
        </Card>

        {/* Strategic Rationale */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Target className="h-5 w-5" />
              Strategic Rationale
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm leading-relaxed">{summaryData.strategicRationale}</p>
          </CardContent>
        </Card>
      </div>

      {/* Content Overview */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <FileText className="h-5 w-5" />
            Content Overview
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div>
              <div className="text-2xl font-bold">{summaryData.contentOverview.totalPieces}</div>
              <div className="text-sm text-muted-foreground">Total Content Pieces</div>
            </div>
            <div>
              <div className="space-y-2">
                <div className="text-sm font-medium">Content by Type</div>
                {Object.entries(summaryData.contentOverview.byType).map(([type, count]) => (
                  <div key={type} className="flex justify-between text-sm">
                    <span className="capitalize">{type}</span>
                    <span className="font-medium">{count}</span>
                  </div>
                ))}
              </div>
            </div>
            <div>
              <div className="text-sm font-medium mb-2">Distribution Channels</div>
              <div className="flex flex-wrap gap-2">
                {summaryData.contentOverview.channels.map((channel) => (
                  <Badge key={channel} variant="secondary">
                    {channel}
                  </Badge>
                ))}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Timeline */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Calendar className="h-5 w-5" />
            Campaign Timeline
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {summaryData.timeline.map((phase, index) => (
              <div key={index} className="flex gap-4">
                <div className="flex-shrink-0 w-2 h-2 mt-2 bg-primary rounded-full" />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <h4 className="font-medium">{phase.phase}</h4>
                    <Badge variant="outline" className="text-xs">
                      {phase.duration}
                    </Badge>
                  </div>
                  <p className="text-sm text-muted-foreground mb-2">{phase.description}</p>
                  <div className="text-xs">
                    <span className="font-medium">Deliverables: </span>
                    {phase.deliverables.join(', ')}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Performance Projections */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <TrendingUp className="h-5 w-5" />
            Performance Projections
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="text-center">
              <div className="text-2xl font-bold">
                {summaryData.performanceProjections.estimatedReach.toLocaleString()}
              </div>
              <div className="text-sm text-muted-foreground">Est. Reach</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold">
                {summaryData.performanceProjections.expectedEngagement}%
              </div>
              <div className="text-sm text-muted-foreground">Engagement Rate</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold">
                {summaryData.performanceProjections.targetConversions.toLocaleString()}
              </div>
              <div className="text-sm text-muted-foreground">Target Conversions</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold">
                {summaryData.performanceProjections.projectedROI}
              </div>
              <div className="text-sm text-muted-foreground">Projected ROI</div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Stakeholder Brief */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Users className="h-5 w-5" />
            Stakeholder Brief
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div>
              <h4 className="font-medium mb-3">Key Messages</h4>
              <ul className="space-y-1">
                {summaryData.stakeholderBrief.keyMessages.map((message, index) => (
                  <li key={index} className="text-sm text-muted-foreground">
                    • {message}
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <h4 className="font-medium mb-3">Success Metrics</h4>
              <ul className="space-y-1">
                {summaryData.stakeholderBrief.successMetrics.map((metric, index) => (
                  <li key={index} className="text-sm text-muted-foreground">
                    • {metric}
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <h4 className="font-medium mb-3">Risks & Mitigation</h4>
              <ul className="space-y-1">
                {summaryData.stakeholderBrief.risksAndMitigation.map((risk, index) => (
                  <li key={index} className="text-sm text-muted-foreground">
                    • {risk}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}