import { NextRequest, NextResponse } from "next/server"
import { JourneyPersistence } from "@/lib/journey-persistence"

// POST /api/journeys/[id]/duplicate - Duplicate a journey
export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const journeyId = params.id
    const body = await request.json()
    const { name, campaignId } = body

    if (!name) {
      return NextResponse.json(
        { error: "New journey name is required" },
        { status: 400 }
      )
    }

    const result = await JourneyPersistence.duplicateJourney(journeyId, name, campaignId)

    if (!result.success) {
      return NextResponse.json(
        { error: result.error },
        { status: result.error === "Original journey not found" ? 404 : 500 }
      )
    }

    return NextResponse.json({
      success: true,
      journey: result.journey
    }, { status: 201 })
  } catch (error) {
    console.error("Failed to duplicate journey:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}