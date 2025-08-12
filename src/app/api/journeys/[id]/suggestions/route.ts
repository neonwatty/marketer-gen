import { NextRequest, NextResponse } from "next/server"
import { AISuggestionService, type AISuggestionRequest } from "@/lib/ai-suggestions"
import { JourneyPersistence } from "@/lib/journey-persistence"

// GET /api/journeys/[id]/suggestions - Get AI suggestions for a journey
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { searchParams } = new URL(request.url)
    const journeyId = params.id

    // Parse query parameters
    const suggestionTypesParam = searchParams.get("types") || "optimization,content,strategy"
    const suggestionTypes = suggestionTypesParam.split(",") as AISuggestionRequest["suggestionTypes"]
    
    const maxSuggestions = searchParams.get("maxSuggestions") ? 
      parseInt(searchParams.get("maxSuggestions")!) : undefined
    const confidenceThreshold = searchParams.get("confidenceThreshold") ? 
      parseFloat(searchParams.get("confidenceThreshold")!) : undefined
    const priorityFilter = searchParams.get("priorityFilter") ? 
      searchParams.get("priorityFilter")!.split(",") as AISuggestionRequest["preferences"]["priorityFilter"] : undefined

    // Load the journey to get context
    const journeyResult = await JourneyPersistence.loadJourney(journeyId)
    
    if (!journeyResult.success || !journeyResult.journey) {
      return NextResponse.json(
        { error: journeyResult.error || "Journey not found" },
        { status: 404 }
      )
    }

    const journey = journeyResult.journey

    // Build AI suggestion request
    const suggestionRequest: AISuggestionRequest = {
      journeyId,
      suggestionTypes,
      context: {
        industry: journey.category || undefined,
        businessType: "B2B", // Could be inferred from journey data
        targetAudience: "Business Professionals", // Could be extracted from journey metadata
        goals: ["increase_conversion", "improve_engagement"], // Could be from journey settings
      },
      preferences: {
        maxSuggestions,
        confidenceThreshold,
        priorityFilter,
        includeAlternatives: true
      }
    }

    // Get AI suggestions
    const suggestionsResponse = await AISuggestionService.getSuggestions(suggestionRequest)

    if (!suggestionsResponse.success) {
      return NextResponse.json(
        { 
          error: suggestionsResponse.error || "Failed to generate suggestions",
          warnings: suggestionsResponse.warnings 
        },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      journeyId,
      journeyName: journey.name,
      suggestions: suggestionsResponse.suggestions,
      metadata: suggestionsResponse.metadata,
      warnings: suggestionsResponse.warnings
    })
  } catch (error) {
    console.error("Failed to get AI suggestions:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}

// POST /api/journeys/[id]/suggestions - Request new AI suggestions with custom parameters
export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const journeyId = params.id
    const body = await request.json()

    // Validate journey exists
    const journeyResult = await JourneyPersistence.loadJourney(journeyId)
    
    if (!journeyResult.success || !journeyResult.journey) {
      return NextResponse.json(
        { error: journeyResult.error || "Journey not found" },
        { status: 404 }
      )
    }

    // Build suggestion request from body
    const suggestionRequest: AISuggestionRequest = {
      journeyId,
      suggestionTypes: body.suggestionTypes || ["optimization", "content"],
      context: {
        industry: body.context?.industry || journeyResult.journey.category || undefined,
        businessType: body.context?.businessType || "B2B",
        targetAudience: body.context?.targetAudience || "Business Professionals",
        budget: body.context?.budget,
        goals: body.context?.goals || ["increase_conversion"],
        constraints: body.context?.constraints,
        existingAssets: body.context?.existingAssets
      },
      preferences: {
        maxSuggestions: body.preferences?.maxSuggestions || 10,
        confidenceThreshold: body.preferences?.confidenceThreshold || 70,
        priorityFilter: body.preferences?.priorityFilter,
        includeAlternatives: body.preferences?.includeAlternatives ?? true
      }
    }

    // Get AI suggestions
    const suggestionsResponse = await AISuggestionService.getSuggestions(suggestionRequest)

    if (!suggestionsResponse.success) {
      return NextResponse.json(
        { 
          error: suggestionsResponse.error || "Failed to generate suggestions",
          warnings: suggestionsResponse.warnings 
        },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      journeyId,
      journeyName: journeyResult.journey.name,
      suggestions: suggestionsResponse.suggestions,
      metadata: suggestionsResponse.metadata,
      warnings: suggestionsResponse.warnings
    }, { status: 201 })
  } catch (error) {
    console.error("Failed to generate AI suggestions:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}