"use client"

import { Button } from "@/components/ui/button"
import { ArrowLeft, Calendar as CalendarIcon } from "lucide-react"
import Link from "next/link"
import { CampaignTimelineCalendar } from "@/components/campaigns/campaign-timeline-calendar"

interface CampaignTimelinePageProps {
  params: { id: string }
}

export default function CampaignTimelinePage({ params }: CampaignTimelinePageProps) {
  const handleEventClick = (event: any) => {
    console.log("Event clicked:", event)
    // In real implementation, this would open an event detail modal
  }

  const handleDateSelect = (date: Date) => {
    console.log("Date selected:", date)
    // In real implementation, this would show events for that date
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="container mx-auto px-4">
          <div className="flex h-14 items-center justify-between">
            <div className="flex items-center gap-4">
              <Link href={`/campaigns/${params.id}`}>
                <Button variant="ghost" size="sm">
                  <ArrowLeft className="h-4 w-4 mr-2" />
                  Back to Campaign
                </Button>
              </Link>
              <div className="flex items-center gap-3">
                <CalendarIcon className="h-5 w-5 text-muted-foreground" />
                <h1 className="text-lg font-semibold">Timeline & Schedule</h1>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="container mx-auto px-4 py-8">
        <CampaignTimelineCalendar 
          campaignId={params.id}
          onEventClick={handleEventClick}
          onDateSelect={handleDateSelect}
        />
      </div>
    </div>
  )
}