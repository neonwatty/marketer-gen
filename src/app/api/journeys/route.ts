import { NextRequest, NextResponse } from "next/server"
import { JourneyPersistence } from "@/lib/journey-persistence"

// GET /api/journeys - Get all journeys for a campaign
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const campaignId = searchParams.get("campaignId")

    if (!campaignId) {
      return NextResponse.json(
        { error: "Campaign ID is required" },
        { status: 400 }
      )
    }

    const result = await JourneyPersistence.loadJourneysByCampaign(campaignId)

    if (!result.success) {
      return NextResponse.json(
        { error: result.error },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      journeys: result.journeys
    })
  } catch (error) {
    console.error("Failed to get journeys:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}

// POST /api/journeys - Create a new journey
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { campaignId, journeyData, changeNote } = body

    if (!campaignId || !journeyData) {
      return NextResponse.json(
        { error: "Campaign ID and journey data are required" },
        { status: 400 }
      )
    }

    if (!journeyData.name || !Array.isArray(journeyData.stages)) {
      return NextResponse.json(
        { error: "Journey name and stages are required" },
        { status: 400 }
      )
    }

    const result = await JourneyPersistence.saveJourney(campaignId, journeyData, changeNote)

    if (!result.success) {
      return NextResponse.json(
        { error: result.error },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      journey: result.journey
    }, { status: 201 })
  } catch (error) {
    console.error("Failed to create journey:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}