import { NextRequest, NextResponse } from "next/server"
import { AISuggestionService } from "@/lib/ai-suggestions"

// GET /api/suggestions/[id] - Get suggestion status
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const suggestionId = params.id

    const statusResult = await AISuggestionService.getSuggestionStatus(suggestionId)

    if (!statusResult.success) {
      return NextResponse.json(
        { error: statusResult.error || "Failed to get suggestion status" },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      suggestionId,
      isImplemented: statusResult.isImplemented,
      implementedAt: statusResult.implementedAt
    })
  } catch (error) {
    console.error("Failed to get suggestion status:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}

// PATCH /api/suggestions/[id] - Mark suggestion as implemented or update status
export async function PATCH(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const suggestionId = params.id
    const body = await request.json()
    const { action } = body

    if (action === "implement") {
      const result = await AISuggestionService.implementSuggestion(suggestionId)

      if (!result.success) {
        return NextResponse.json(
          { error: result.error || "Failed to implement suggestion" },
          { status: 500 }
        )
      }

      return NextResponse.json({
        success: true,
        suggestionId,
        message: "Suggestion marked as implemented",
        implementedAt: new Date()
      })
    } else {
      return NextResponse.json(
        { error: "Invalid action. Supported actions: implement" },
        { status: 400 }
      )
    }
  } catch (error) {
    console.error("Failed to update suggestion:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}