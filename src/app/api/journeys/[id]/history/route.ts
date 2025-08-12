import { NextRequest, NextResponse } from "next/server"
import { JourneyPersistence } from "@/lib/journey-persistence"

// GET /api/journeys/[id]/history - Get journey history
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const journeyId = params.id

    const result = await JourneyPersistence.getJourneyHistory(journeyId)

    if (!result.success) {
      return NextResponse.json(
        { error: result.error },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      history: result.history
    })
  } catch (error) {
    console.error("Failed to get journey history:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}