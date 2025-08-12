import { NextRequest, NextResponse } from "next/server"
import { JourneyPersistence } from "@/lib/journey-persistence"
import type { JourneyStatus } from "@prisma/client"

// PATCH /api/journeys/[id]/status - Update journey status
export async function PATCH(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const journeyId = params.id
    const body = await request.json()
    const { status, changeNote } = body

    if (!status) {
      return NextResponse.json(
        { error: "Status is required" },
        { status: 400 }
      )
    }

    // Validate status enum
    const validStatuses = ["DRAFT", "ACTIVE", "PAUSED", "COMPLETED", "ARCHIVED"]
    if (!validStatuses.includes(status)) {
      return NextResponse.json(
        { error: "Invalid status. Must be one of: " + validStatuses.join(", ") },
        { status: 400 }
      )
    }

    const result = await JourneyPersistence.updateJourneyStatus(
      journeyId, 
      status as JourneyStatus, 
      changeNote
    )

    if (!result.success) {
      return NextResponse.json(
        { error: result.error },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      journey: result.journey
    })
  } catch (error) {
    console.error("Failed to update journey status:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}