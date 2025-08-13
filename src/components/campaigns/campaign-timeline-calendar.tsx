"use client"

import React, { useState } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Calendar } from "@/components/ui/calendar"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { 
  Calendar as CalendarIcon,
  Clock,
  Plus,
  Filter,
  Download,
  ChevronLeft,
  ChevronRight,
  FileText,
  Mail,
  MessageCircle,
  Globe,
  Target,
  Users,
  TrendingUp,
  Play,
  Pause,
  CheckCircle,
  AlertTriangle,
  Edit,
  MoreHorizontal
} from "lucide-react"
import { format, addDays, startOfWeek, endOfWeek, eachDayOfInterval, isSameDay, isToday } from "date-fns"

// Enhanced timeline event types
interface TimelineEvent {
  id: string
  type: "content_deadline" | "campaign_milestone" | "content_publish" | "campaign_launch" | "campaign_review" | "team_meeting" | "content_creation" | "performance_review"
  title: string
  description: string
  date: Date
  time?: string
  status: "scheduled" | "in_progress" | "completed" | "overdue"
  priority: "low" | "medium" | "high" | "critical"
  assignedTo?: {
    name: string
    avatar?: string
    initials: string
  }
  tags: string[]
  contentType?: string
  channel?: string
  estimatedHours?: number
}

// Sample timeline events for campaign planning
const mockTimelineEvents: TimelineEvent[] = [
  {
    id: "1",
    type: "campaign_launch",
    title: "Campaign Launch",
    description: "Official launch of Summer Product Launch campaign across all channels",
    date: new Date(2024, 7, 15), // August 15, 2024
    time: "09:00",
    status: "scheduled",
    priority: "critical",
    assignedTo: {
      name: "Sarah Johnson",
      initials: "SJ"
    },
    tags: ["launch", "milestone"],
    estimatedHours: 4
  },
  {
    id: "2", 
    type: "content_deadline",
    title: "Email Newsletter Content Due",
    description: "Final email newsletter content for awareness stage must be completed",
    date: new Date(2024, 7, 12), // August 12, 2024
    time: "17:00",
    status: "in_progress",
    priority: "high",
    assignedTo: {
      name: "Mike Chen",
      initials: "MC"
    },
    tags: ["content", "email", "deadline"],
    contentType: "email-newsletter",
    channel: "Email",
    estimatedHours: 8
  },
  {
    id: "3",
    type: "content_creation",
    title: "Social Media Assets Creation",
    description: "Create visual assets for social media posts in consideration stage",
    date: new Date(2024, 7, 10), // August 10, 2024
    time: "10:00",
    status: "scheduled",
    priority: "medium",
    assignedTo: {
      name: "Emma Davis",
      initials: "ED"
    },
    tags: ["content", "social", "design"],
    contentType: "social-media",
    channel: "Social Media",
    estimatedHours: 6
  },
  {
    id: "4",
    type: "campaign_review",
    title: "Mid-Campaign Performance Review",
    description: "Review campaign performance metrics and adjust strategy if needed",
    date: new Date(2024, 7, 20), // August 20, 2024
    time: "14:00",
    status: "scheduled",
    priority: "high",
    assignedTo: {
      name: "Sarah Johnson",
      initials: "SJ"
    },
    tags: ["review", "metrics", "strategy"],
    estimatedHours: 3
  },
  {
    id: "5",
    type: "content_publish",
    title: "Blog Post Publication",
    description: "Publish sustainability-focused blog post for awareness stage",
    date: new Date(2024, 7, 8), // August 8, 2024
    time: "08:00",
    status: "completed",
    priority: "medium",
    assignedTo: {
      name: "Alex Rivera",
      initials: "AR"
    },
    tags: ["content", "blog", "publish"],
    contentType: "blog-post",
    channel: "Blog",
    estimatedHours: 2
  },
  {
    id: "6",
    type: "team_meeting",
    title: "Weekly Campaign Sync",
    description: "Weekly team sync to discuss progress and upcoming deliverables",
    date: new Date(2024, 7, 14), // August 14, 2024
    time: "11:00",
    status: "scheduled",
    priority: "medium",
    tags: ["meeting", "sync", "team"],
    estimatedHours: 1
  }
]

interface CampaignTimelineCalendarProps {
  campaignId: string
  events?: TimelineEvent[]
  onEventClick?: (event: TimelineEvent) => void
  onDateSelect?: (date: Date) => void
}

function getEventIcon(type: TimelineEvent['type']) {
  const iconMap = {
    content_deadline: <AlertTriangle className="h-4 w-4" />,
    campaign_milestone: <Target className="h-4 w-4" />,
    content_publish: <FileText className="h-4 w-4" />,
    campaign_launch: <Play className="h-4 w-4" />,
    campaign_review: <TrendingUp className="h-4 w-4" />,
    team_meeting: <Users className="h-4 w-4" />,
    content_creation: <Edit className="h-4 w-4" />,
    performance_review: <TrendingUp className="h-4 w-4" />
  }
  return iconMap[type] || <CalendarIcon className="h-4 w-4" />
}

function getPriorityColor(priority: TimelineEvent['priority']) {
  const colorMap = {
    low: "bg-blue-100 text-blue-800 border-blue-200",
    medium: "bg-yellow-100 text-yellow-800 border-yellow-200", 
    high: "bg-orange-100 text-orange-800 border-orange-200",
    critical: "bg-red-100 text-red-800 border-red-200"
  }
  return colorMap[priority]
}

function getStatusColor(status: TimelineEvent['status']) {
  const colorMap = {
    scheduled: "bg-slate-100 text-slate-800 border-slate-200",
    in_progress: "bg-blue-100 text-blue-800 border-blue-200",
    completed: "bg-green-100 text-green-800 border-green-200",
    overdue: "bg-red-100 text-red-800 border-red-200"
  }
  return colorMap[status]
}

function TimelineView({ events, onEventClick }: { events: TimelineEvent[], onEventClick?: (event: TimelineEvent) => void }) {
  const sortedEvents = events.sort((a, b) => a.date.getTime() - b.date.getTime())
  
  return (
    <div className="space-y-4">
      {/* Timeline controls */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Select defaultValue="all">
            <SelectTrigger className="w-32">
              <SelectValue placeholder="Filter by..." />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Events</SelectItem>
              <SelectItem value="content">Content</SelectItem>
              <SelectItem value="meetings">Meetings</SelectItem>
              <SelectItem value="milestones">Milestones</SelectItem>
            </SelectContent>
          </Select>
          <Button variant="outline" size="sm">
            <Filter className="h-4 w-4 mr-2" />
            Filter
          </Button>
        </div>
        <Button size="sm">
          <Plus className="h-4 w-4 mr-2" />
          Add Event
        </Button>
      </div>

      {/* Timeline */}
      <div className="relative">
        <div className="absolute left-8 top-0 bottom-0 w-0.5 bg-border"></div>
        
        <div className="space-y-6">
          {sortedEvents.map((event, index) => (
            <div 
              key={event.id} 
              className="relative flex items-start gap-4 cursor-pointer hover:bg-muted/50 p-3 rounded-lg transition-colors"
              onClick={() => onEventClick?.(event)}
            >
              {/* Timeline dot */}
              <div className={`relative z-10 flex items-center justify-center w-16 h-16 rounded-full border-2 bg-background ${getPriorityColor(event.priority)}`}>
                {getEventIcon(event.type)}
              </div>
              
              {/* Event content */}
              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between mb-2">
                  <div className="flex-1">
                    <h4 className="font-semibold text-base">{event.title}</h4>
                    <p className="text-sm text-muted-foreground mt-1">
                      {event.description}
                    </p>
                  </div>
                  <div className="flex items-center gap-2 ml-4">
                    <Badge className={getStatusColor(event.status)}>
                      {event.status.replace('_', ' ')}
                    </Badge>
                    <Button variant="ghost" size="sm">
                      <MoreHorizontal className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
                
                {/* Event details */}
                <div className="flex items-center gap-4 text-sm text-muted-foreground mb-2">
                  <div className="flex items-center gap-1">
                    <CalendarIcon className="h-4 w-4" />
                    {format(event.date, 'MMM d, yyyy')}
                  </div>
                  {event.time && (
                    <div className="flex items-center gap-1">
                      <Clock className="h-4 w-4" />
                      {event.time}
                    </div>
                  )}
                  {event.estimatedHours && (
                    <div className="flex items-center gap-1">
                      <Clock className="h-4 w-4" />
                      {event.estimatedHours}h
                    </div>
                  )}
                </div>

                {/* Assignee and tags */}
                <div className="flex items-center gap-3">
                  {event.assignedTo && (
                    <div className="flex items-center gap-2">
                      <Avatar className="h-6 w-6">
                        <AvatarImage src={event.assignedTo.avatar} />
                        <AvatarFallback className="text-xs">
                          {event.assignedTo.initials}
                        </AvatarFallback>
                      </Avatar>
                      <span className="text-sm text-muted-foreground">
                        {event.assignedTo.name}
                      </span>
                    </div>
                  )}
                  
                  <div className="flex gap-1">
                    {event.tags.slice(0, 3).map((tag) => (
                      <Badge key={tag} variant="secondary" className="text-xs">
                        {tag}
                      </Badge>
                    ))}
                    {event.tags.length > 3 && (
                      <Badge variant="secondary" className="text-xs">
                        +{event.tags.length - 3}
                      </Badge>
                    )}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

function CalendarView({ events, onDateSelect }: { events: TimelineEvent[], onDateSelect?: (date: Date) => void }) {
  const [selectedDate, setSelectedDate] = useState<Date>(new Date())
  const [currentWeek, setCurrentWeek] = useState(new Date())

  const weekStart = startOfWeek(currentWeek, { weekStartsOn: 0 })
  const weekEnd = endOfWeek(currentWeek, { weekStartsOn: 0 })
  const weekDays = eachDayOfInterval({ start: weekStart, end: weekEnd })

  const getEventsForDate = (date: Date) => {
    return events.filter(event => isSameDay(event.date, date))
  }

  const navigateWeek = (direction: 'prev' | 'next') => {
    const newWeek = addDays(currentWeek, direction === 'next' ? 7 : -7)
    setCurrentWeek(newWeek)
  }

  const handleDateClick = (date: Date) => {
    setSelectedDate(date)
    onDateSelect?.(date)
  }

  const selectedDateEvents = getEventsForDate(selectedDate)

  return (
    <div className="space-y-6">
      {/* Week navigation */}
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold">
          {format(weekStart, 'MMM d')} - {format(weekEnd, 'MMM d, yyyy')}
        </h3>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={() => setCurrentWeek(new Date())}>
            Today
          </Button>
          <Button variant="outline" size="sm" onClick={() => navigateWeek('prev')}>
            <ChevronLeft className="h-4 w-4" />
          </Button>
          <Button variant="outline" size="sm" onClick={() => navigateWeek('next')}>
            <ChevronRight className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* Week view */}
      <div className="grid grid-cols-7 gap-4">
        {weekDays.map((day) => {
          const dayEvents = getEventsForDate(day)
          const isSelected = isSameDay(day, selectedDate)
          const isCurrentDay = isToday(day)
          
          return (
            <Card 
              key={day.toISOString()} 
              className={`cursor-pointer transition-colors hover:bg-muted/50 ${
                isSelected ? 'ring-2 ring-primary' : ''
              } ${isCurrentDay ? 'bg-accent/50' : ''}`}
              onClick={() => handleDateClick(day)}
            >
              <CardContent className="p-3">
                <div className="text-center mb-2">
                  <div className="text-xs text-muted-foreground uppercase">
                    {format(day, 'EEE')}
                  </div>
                  <div className={`text-lg font-medium ${isCurrentDay ? 'text-primary' : ''}`}>
                    {format(day, 'd')}
                  </div>
                </div>
                
                {dayEvents.length > 0 && (
                  <div className="space-y-1">
                    {dayEvents.slice(0, 3).map((event) => (
                      <div 
                        key={event.id} 
                        className={`text-xs p-1 rounded border ${getPriorityColor(event.priority)}`}
                      >
                        <div className="font-medium truncate">{event.title}</div>
                        {event.time && (
                          <div className="text-xs opacity-75">{event.time}</div>
                        )}
                      </div>
                    ))}
                    {dayEvents.length > 3 && (
                      <div className="text-xs text-muted-foreground text-center">
                        +{dayEvents.length - 3} more
                      </div>
                    )}
                  </div>
                )}
              </CardContent>
            </Card>
          )
        })}
      </div>

      {/* Selected date details */}
      {selectedDateEvents.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              Events for {format(selectedDate, 'MMMM d, yyyy')}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {selectedDateEvents.map((event) => (
              <div key={event.id} className="flex items-start gap-3 p-3 border rounded-lg">
                <div className={`flex items-center justify-center w-10 h-10 rounded-full ${getPriorityColor(event.priority)}`}>
                  {getEventIcon(event.type)}
                </div>
                <div className="flex-1">
                  <div className="flex items-start justify-between">
                    <div>
                      <h4 className="font-medium">{event.title}</h4>
                      <p className="text-sm text-muted-foreground">{event.description}</p>
                    </div>
                    <Badge className={getStatusColor(event.status)}>
                      {event.status.replace('_', ' ')}
                    </Badge>
                  </div>
                  <div className="flex items-center gap-2 mt-2 text-sm text-muted-foreground">
                    {event.time && (
                      <span className="flex items-center gap-1">
                        <Clock className="h-3 w-3" />
                        {event.time}
                      </span>
                    )}
                    {event.assignedTo && (
                      <span className="flex items-center gap-1">
                        <Avatar className="h-4 w-4">
                          <AvatarFallback className="text-xs">
                            {event.assignedTo.initials}
                          </AvatarFallback>
                        </Avatar>
                        {event.assignedTo.name}
                      </span>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </CardContent>
        </Card>
      )}
    </div>
  )
}

export function CampaignTimelineCalendar({ 
  campaignId, 
  events = mockTimelineEvents, 
  onEventClick, 
  onDateSelect 
}: CampaignTimelineCalendarProps) {
  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">Campaign Timeline & Schedule</h2>
          <p className="text-muted-foreground">
            Manage campaign milestones, content deadlines, and team activities
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline">
            <Download className="h-4 w-4 mr-2" />
            Export Schedule
          </Button>
          <Button>
            <Plus className="h-4 w-4 mr-2" />
            Add Event
          </Button>
        </div>
      </div>

      {/* Timeline and Calendar Tabs */}
      <Tabs defaultValue="timeline" className="space-y-4">
        <TabsList>
          <TabsTrigger value="timeline">Timeline View</TabsTrigger>
          <TabsTrigger value="calendar">Calendar View</TabsTrigger>
        </TabsList>

        <TabsContent value="timeline" className="space-y-4">
          <TimelineView events={events} onEventClick={onEventClick} />
        </TabsContent>

        <TabsContent value="calendar" className="space-y-4">
          <CalendarView events={events} onDateSelect={onDateSelect} />
        </TabsContent>
      </Tabs>
    </div>
  )
}