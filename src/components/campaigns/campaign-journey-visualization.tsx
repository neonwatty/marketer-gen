"use client"

import * as React from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Progress } from "@/components/ui/progress"
import { Button } from "@/components/ui/button"
import { 
  CheckCircle, 
  Circle, 
  Clock, 
  ArrowRight, 
  Users, 
  TrendingUp,
  Mail,
  Share2,
  FileText,
  Target
} from "lucide-react"
import { cn } from "@/lib/utils"

interface JourneyStage {
  id: string
  name: string
  description: string
  status: "completed" | "active" | "pending" | "paused"
  channels: string[]
  contentCount: number
  metrics: {
    impressions: number
    engagement: number
  }
}

interface Journey {
  stages: JourneyStage[]
}

interface CampaignJourneyVisualizationProps {
  journey: Journey
}

const getChannelIcon = (channel: string) => {
  switch (channel.toLowerCase()) {
    case "email":
      return <Mail className="h-4 w-4" />
    case "social media":
    case "social":
      return <Share2 className="h-4 w-4" />
    case "blog":
      return <FileText className="h-4 w-4" />
    case "landing pages":
    case "landing page":
      return <Target className="h-4 w-4" />
    case "display ads":
    case "display":
      return <Users className="h-4 w-4" />
    default:
      return <Circle className="h-4 w-4" />
  }
}

const getStatusIcon = (status: JourneyStage['status']) => {
  switch (status) {
    case "completed":
      return <CheckCircle className="h-5 w-5 text-green-600" />
    case "active":
      return <Circle className="h-5 w-5 text-blue-600 fill-blue-600" />
    case "pending":
      return <Circle className="h-5 w-5 text-slate-400" />
    case "paused":
      return <Clock className="h-5 w-5 text-yellow-600" />
    default:
      return <Circle className="h-5 w-5 text-slate-400" />
  }
}

const getStatusColor = (status: JourneyStage['status']) => {
  switch (status) {
    case "completed":
      return "text-green-700 bg-green-50 border-green-200"
    case "active":
      return "text-blue-700 bg-blue-50 border-blue-200"
    case "pending":
      return "text-slate-700 bg-slate-50 border-slate-200"
    case "paused":
      return "text-yellow-700 bg-yellow-50 border-yellow-200"
    default:
      return "text-slate-700 bg-slate-50 border-slate-200"
  }
}

export function CampaignJourneyVisualization({ journey }: CampaignJourneyVisualizationProps) {
  const [selectedStage, setSelectedStage] = React.useState<string | null>(null)

  const totalStages = journey.stages.length
  const completedStages = journey.stages.filter(stage => stage.status === "completed").length
  const activeStages = journey.stages.filter(stage => stage.status === "active").length
  const overallProgress = (completedStages / totalStages) * 100

  const formatNumber = (num: number) => {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M'
    }
    if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K'
    }
    return num.toString()
  }

  return (
    <div className="space-y-6">
      {/* Journey Overview */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="flex items-center gap-2">
                <Target className="h-5 w-5" />
                Customer Journey Progress
              </CardTitle>
              <CardDescription>
                Track your audience through each stage of the customer journey
              </CardDescription>
            </div>
            <div className="text-right">
              <p className="text-2xl font-bold">{Math.round(overallProgress)}%</p>
              <p className="text-sm text-muted-foreground">Complete</p>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <Progress value={overallProgress} className="h-3 mb-4" />
          <div className="flex items-center justify-between text-sm text-muted-foreground">
            <span>{completedStages} of {totalStages} stages completed</span>
            <span>{activeStages} stage{activeStages !== 1 ? 's' : ''} active</span>
          </div>
        </CardContent>
      </Card>

      {/* Journey Flow Visualization */}
      <div className="relative">
        {/* Journey Flow */}
        <div className="space-y-6">
          {journey.stages.map((stage, index) => {
            const isSelected = selectedStage === stage.id
            const isLast = index === journey.stages.length - 1
            
            return (
              <div key={stage.id} className="relative">
                {/* Stage Card */}
                <Card 
                  className={cn(
                    "cursor-pointer transition-all hover:shadow-md",
                    isSelected && "ring-2 ring-primary border-primary"
                  )}
                  onClick={() => setSelectedStage(isSelected ? null : stage.id)}
                >
                  <CardContent className="p-6">
                    <div className="flex items-start gap-4">
                      {/* Status Icon */}
                      <div className="flex-shrink-0 mt-1">
                        {getStatusIcon(stage.status)}
                      </div>

                      {/* Stage Content */}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between mb-2">
                          <div className="flex items-center gap-3">
                            <h3 className="font-semibold text-lg">{stage.name}</h3>
                            <Badge variant="outline" className={getStatusColor(stage.status)}>
                              {stage.status.charAt(0).toUpperCase() + stage.status.slice(1)}
                            </Badge>
                          </div>
                          <div className="flex items-center gap-4 text-sm text-muted-foreground">
                            <div className="flex items-center gap-1">
                              <FileText className="h-4 w-4" />
                              <span>{stage.contentCount} content</span>
                            </div>
                            <div className="flex items-center gap-1">
                              <Users className="h-4 w-4" />
                              <span>{formatNumber(stage.metrics.impressions)}</span>
                            </div>
                            <div className="flex items-center gap-1">
                              <TrendingUp className="h-4 w-4" />
                              <span>{stage.metrics.engagement}%</span>
                            </div>
                          </div>
                        </div>

                        <p className="text-muted-foreground mb-3">{stage.description}</p>

                        <div className="flex items-center gap-2">
                          <span className="text-sm font-medium">Channels:</span>
                          <div className="flex items-center gap-2">
                            {stage.channels.map((channel) => (
                              <div 
                                key={channel} 
                                className="flex items-center gap-1 px-2 py-1 bg-slate-100 rounded-md text-xs"
                              >
                                {getChannelIcon(channel)}
                                <span>{channel}</span>
                              </div>
                            ))}
                          </div>
                        </div>

                        {/* Expanded Details */}
                        {isSelected && (
                          <div className="mt-4 pt-4 border-t space-y-4">
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                              <div className="bg-slate-50 rounded-lg p-3">
                                <div className="flex items-center justify-between">
                                  <span className="text-sm font-medium">Content Pieces</span>
                                  <FileText className="h-4 w-4 text-slate-600" />
                                </div>
                                <p className="text-2xl font-bold mt-1">{stage.contentCount}</p>
                              </div>
                              <div className="bg-blue-50 rounded-lg p-3">
                                <div className="flex items-center justify-between">
                                  <span className="text-sm font-medium">Impressions</span>
                                  <Users className="h-4 w-4 text-blue-600" />
                                </div>
                                <p className="text-2xl font-bold mt-1">{formatNumber(stage.metrics.impressions)}</p>
                              </div>
                              <div className="bg-green-50 rounded-lg p-3">
                                <div className="flex items-center justify-between">
                                  <span className="text-sm font-medium">Engagement</span>
                                  <TrendingUp className="h-4 w-4 text-green-600" />
                                </div>
                                <p className="text-2xl font-bold mt-1">{stage.metrics.engagement}%</p>
                              </div>
                            </div>

                            <div className="flex gap-2">
                              <Button size="sm" variant="outline">
                                View Content
                              </Button>
                              <Button size="sm" variant="outline">
                                View Analytics
                              </Button>
                              {stage.status === "pending" && (
                                <Button size="sm">
                                  Start Stage
                                </Button>
                              )}
                              {stage.status === "active" && (
                                <Button size="sm" variant="outline">
                                  Pause Stage
                                </Button>
                              )}
                            </div>
                          </div>
                        )}
                      </div>
                    </div>
                  </CardContent>
                </Card>

                {/* Arrow connector */}
                {!isLast && (
                  <div className="flex justify-center my-4">
                    <div className="flex items-center">
                      <ArrowRight className="h-6 w-6 text-muted-foreground" />
                    </div>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      </div>

      {/* Journey Insights */}
      <Card>
        <CardHeader>
          <CardTitle>Journey Insights</CardTitle>
          <CardDescription>
            Key metrics and recommendations for optimizing your customer journey
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="p-4 border rounded-lg">
              <h4 className="font-medium mb-2">Best Performing Stage</h4>
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Conversion</span>
                <span className="font-medium">6.8% engagement</span>
              </div>
            </div>
            <div className="p-4 border rounded-lg">
              <h4 className="font-medium mb-2">Optimization Opportunity</h4>
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Awareness</span>
                <span className="font-medium">Increase content variety</span>
              </div>
            </div>
          </div>
          
          <div className="p-4 bg-blue-50 border border-blue-200 rounded-lg">
            <h4 className="font-medium text-blue-900 mb-2">💡 Recommendation</h4>
            <p className="text-sm text-blue-800">
              Your consideration stage is performing well with 5.2% engagement. 
              Consider creating similar content for the awareness stage to improve overall funnel performance.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}