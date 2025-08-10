"use client"

import * as React from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { 
  Activity,
  FileText,
  Mail,
  Share2,
  Play,
  Pause,
  Edit,
  TrendingUp,
  Users,
  CheckCircle,
  AlertCircle,
  Calendar
} from "lucide-react"

interface TimelineEvent {
  id: string
  type: "content_published" | "campaign_started" | "campaign_paused" | "campaign_resumed" | "content_created" | "milestone_reached" | "performance_alert"
  title: string
  description: string
  timestamp: string
  user?: {
    name: string
    avatar?: string
    initials: string
  }
  metadata?: {
    contentType?: string
    metricValue?: number
    metricType?: string
    status?: string
  }
}

interface CampaignTimelineActivityProps {
  campaignId: string
}

// Mock timeline data
const mockTimelineEvents: TimelineEvent[] = [
  {
    id: "1",
    type: "performance_alert",
    title: "High engagement detected",
    description: "Email newsletter achieved 12.3% engagement rate, 45% above target",
    timestamp: "2024-03-22T14:30:00Z",
    metadata: {
      metricValue: 12.3,
      metricType: "engagement"
    }
  },
  {
    id: "2",
    type: "content_created",
    title: "New content created",
    description: "Behind the Scenes video script added to consideration stage",
    timestamp: "2024-03-22T10:15:00Z",
    user: {
      name: "Sarah Johnson",
      initials: "SJ"
    },
    metadata: {
      contentType: "video-script"
    }
  },
  {
    id: "3",
    type: "milestone_reached",
    title: "Conversion milestone reached",
    description: "Campaign surpassed 800 conversions target with 850 total conversions",
    timestamp: "2024-03-21T16:45:00Z",
    metadata: {
      metricValue: 850,
      metricType: "conversions"
    }
  },
  {
    id: "4",
    type: "content_published",
    title: "Content published",
    description: "Shop Sustainable landing page went live and is driving traffic",
    timestamp: "2024-03-20T09:00:00Z",
    user: {
      name: "Mike Chen",
      initials: "MC"
    },
    metadata: {
      contentType: "landing-page"
    }
  },
  {
    id: "5",
    type: "campaign_resumed",
    title: "Campaign resumed",
    description: "Campaign activity resumed after brief pause for content updates",
    timestamp: "2024-03-18T11:20:00Z",
    user: {
      name: "Sarah Johnson",
      initials: "SJ"
    }
  },
  {
    id: "6",
    type: "campaign_paused",
    title: "Campaign paused",
    description: "Campaign temporarily paused for content review and optimization",
    timestamp: "2024-03-17T15:30:00Z",
    user: {
      name: "Sarah Johnson",
      initials: "SJ"
    }
  },
  {
    id: "7",
    type: "content_published",
    title: "Content published",
    description: "Social media post about sustainable products generated strong engagement",
    timestamp: "2024-03-15T08:30:00Z",
    user: {
      name: "Emma Davis",
      initials: "ED"
    },
    metadata: {
      contentType: "social-post"
    }
  },
  {
    id: "8",
    type: "milestone_reached",
    title: "Impressions milestone",
    description: "Campaign reached 100K impressions across all channels",
    timestamp: "2024-03-10T12:00:00Z",
    metadata: {
      metricValue: 100000,
      metricType: "impressions"
    }
  }
]

const getEventIcon = (type: TimelineEvent['type']) => {
  switch (type) {
    case "content_published":
      return <FileText className="h-4 w-4 text-blue-600" />
    case "content_created":
      return <Edit className="h-4 w-4 text-green-600" />
    case "campaign_started":
      return <Play className="h-4 w-4 text-green-600" />
    case "campaign_paused":
      return <Pause className="h-4 w-4 text-yellow-600" />
    case "campaign_resumed":
      return <Play className="h-4 w-4 text-green-600" />
    case "milestone_reached":
      return <CheckCircle className="h-4 w-4 text-purple-600" />
    case "performance_alert":
      return <TrendingUp className="h-4 w-4 text-orange-600" />
    default:
      return <Activity className="h-4 w-4 text-slate-600" />
  }
}

const getEventColor = (type: TimelineEvent['type']) => {
  switch (type) {
    case "content_published":
      return "border-blue-200 bg-blue-50"
    case "content_created":
      return "border-green-200 bg-green-50"
    case "campaign_started":
    case "campaign_resumed":
      return "border-green-200 bg-green-50"
    case "campaign_paused":
      return "border-yellow-200 bg-yellow-50"
    case "milestone_reached":
      return "border-purple-200 bg-purple-50"
    case "performance_alert":
      return "border-orange-200 bg-orange-50"
    default:
      return "border-slate-200 bg-slate-50"
  }
}

const formatTimestamp = (timestamp: string) => {
  const date = new Date(timestamp)
  const now = new Date()
  const diffInHours = Math.floor((now.getTime() - date.getTime()) / (1000 * 60 * 60))
  const diffInDays = Math.floor(diffInHours / 24)

  if (diffInHours < 1) {
    return "Just now"
  } else if (diffInHours < 24) {
    return `${diffInHours} hour${diffInHours > 1 ? 's' : ''} ago`
  } else if (diffInDays < 7) {
    return `${diffInDays} day${diffInDays > 1 ? 's' : ''} ago`
  } else {
    return date.toLocaleDateString()
  }
}

const formatMetricValue = (value: number, type: string) => {
  if (type === "impressions" && value >= 1000) {
    return (value / 1000).toFixed(0) + 'K'
  }
  if (type === "engagement") {
    return value + '%'
  }
  return value.toLocaleString()
}

export function CampaignTimelineActivity({ campaignId }: CampaignTimelineActivityProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Activity className="h-5 w-5" />
          Recent Activity
        </CardTitle>
        <CardDescription>
          Latest updates and milestones for this campaign
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="relative">
          {/* Timeline line */}
          <div className="absolute left-4 top-0 bottom-0 w-0.5 bg-border"></div>
          
          <div className="space-y-4">
            {mockTimelineEvents.map((event, index) => (
              <div key={event.id} className="relative flex items-start gap-4">
                {/* Timeline dot */}
                <div className={`relative z-10 flex items-center justify-center w-8 h-8 rounded-full border-2 bg-background ${getEventColor(event.type)}`}>
                  {getEventIcon(event.type)}
                </div>
                
                {/* Event content */}
                <div className="flex-1 min-w-0 pb-4">
                  <div className="flex items-start justify-between mb-1">
                    <div className="flex-1">
                      <h4 className="font-medium text-sm">{event.title}</h4>
                      <p className="text-sm text-muted-foreground mt-1">
                        {event.description}
                      </p>
                    </div>
                    <span className="text-xs text-muted-foreground whitespace-nowrap ml-2">
                      {formatTimestamp(event.timestamp)}
                    </span>
                  </div>
                  
                  <div className="flex items-center gap-3 mt-2">
                    {event.user && (
                      <div className="flex items-center gap-2">
                        <Avatar className="h-5 w-5">
                          <AvatarImage src={event.user.avatar} />
                          <AvatarFallback className="text-xs">
                            {event.user.initials}
                          </AvatarFallback>
                        </Avatar>
                        <span className="text-xs text-muted-foreground">
                          {event.user.name}
                        </span>
                      </div>
                    )}
                    
                    {event.metadata && (
                      <div className="flex items-center gap-2">
                        {event.metadata.contentType && (
                          <Badge variant="secondary" className="text-xs">
                            {event.metadata.contentType.replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase())}
                          </Badge>
                        )}
                        {event.metadata.metricValue && event.metadata.metricType && (
                          <Badge variant="outline" className="text-xs">
                            {formatMetricValue(event.metadata.metricValue, event.metadata.metricType)} {event.metadata.metricType}
                          </Badge>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* View more activities */}
        <div className="text-center pt-4 border-t">
          <button className="text-sm text-muted-foreground hover:text-foreground transition-colors">
            View all activity
          </button>
        </div>
      </CardContent>
    </Card>
  )
}