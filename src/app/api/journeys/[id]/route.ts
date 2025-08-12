import { NextRequest, NextResponse } from "next/server"
import { JourneyPersistence } from "@/lib/journey-persistence"
import type { JourneyStatus } from "@prisma/client"

// GET /api/journeys/[id] - Get a specific journey
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const journeyId = params.id

    const result = await JourneyPersistence.loadJourney(journeyId)

    if (!result.success) {
      return NextResponse.json(
        { error: result.error },
        { status: result.error === "Journey not found" ? 404 : 500 }
      )
    }

    return NextResponse.json({
      success: true,
      journey: result.journey
    })
  } catch (error) {
    console.error("Failed to get journey:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}

// PUT /api/journeys/[id] - Update a journey
export async function PUT(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const journeyId = params.id
    const body = await request.json()
    const { journeyData, changeNote } = body

    if (!journeyData) {
      return NextResponse.json(
        { error: "Journey data is required" },
        { status: 400 }
      )
    }

    if (!journeyData.name || !Array.isArray(journeyData.stages)) {
      return NextResponse.json(
        { error: "Journey name and stages are required" },
        { status: 400 }
      )
    }

    // Add the ID to the journey data for update operation
    const updatedJourneyData = { ...journeyData, id: journeyId }

    const result = await JourneyPersistence.saveJourney("", updatedJourneyData, changeNote)

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
    console.error("Failed to update journey:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}

// DELETE /api/journeys/[id] - Delete a journey
export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const journeyId = params.id

    const result = await JourneyPersistence.deleteJourney(journeyId)

    if (!result.success) {
      return NextResponse.json(
        { error: result.error },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      message: "Journey deleted successfully"
    })
  } catch (error) {
    console.error("Failed to delete journey:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}