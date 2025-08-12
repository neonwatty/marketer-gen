import { NextRequest, NextResponse } from "next/server"
import { JourneyPersistence } from "@/lib/journey-persistence"
import { JourneyExportImport } from "@/lib/journey-export-import"

// POST /api/journeys/import - Import journey(s)
export async function POST(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const campaignId = searchParams.get("campaignId")

    if (!campaignId) {
      return NextResponse.json(
        { error: "Campaign ID is required" },
        { status: 400 }
      )
    }

    const body = await request.json()
    const { importData, changeNote, importedBy } = body

    if (!importData) {
      return NextResponse.json(
        { error: "Import data is required" },
        { status: 400 }
      )
    }

    // Detect if it's a batch import or single journey
    const isBatch = importData.journeys && Array.isArray(importData.journeys)

    if (isBatch) {
      // Handle batch import
      const batchResult = JourneyExportImport.importBatchFromJson(importData)

      if (!batchResult.success && !batchResult.partialSuccess) {
        return NextResponse.json({
          success: false,
          error: "Batch import failed",
          validation: batchResult.validation
        }, { status: 400 })
      }

      if (!batchResult.journeyDataList) {
        return NextResponse.json({
          success: false,
          error: "No valid journeys found in batch import",
          validation: batchResult.validation
        }, { status: 400 })
      }

      // Save each journey
      const saveResults = []
      const errors = []

      for (let i = 0; i < batchResult.journeyDataList.length; i++) {
        const journeyData = batchResult.journeyDataList[i]
        
        try {
          // Add import metadata
          journeyData.metadata = {
            ...journeyData.metadata,
            importedBy,
            batchImport: true,
            batchPosition: i + 1,
          }

          const saveResult = await JourneyPersistence.saveJourney(
            campaignId, 
            journeyData, 
            changeNote || `Imported from batch (${i + 1}/${batchResult.journeyDataList.length})`
          )

          if (saveResult.success && saveResult.journey) {
            saveResults.push({
              success: true,
              journeyId: saveResult.journey.id,
              journeyName: saveResult.journey.name
            })
          } else {
            errors.push({
              journeyName: journeyData.name,
              error: saveResult.error
            })
          }
        } catch (error) {
          errors.push({
            journeyName: journeyData.name,
            error: error instanceof Error ? error.message : "Unknown error"
          })
        }
      }

      return NextResponse.json({
        success: errors.length === 0,
        partialSuccess: saveResults.length > 0 && errors.length > 0,
        results: saveResults,
        errors: errors,
        totalProcessed: batchResult.journeyDataList.length,
        successCount: saveResults.length,
        errorCount: errors.length,
        validation: batchResult.validation
      }, { 
        status: errors.length === 0 ? 201 : (saveResults.length > 0 ? 207 : 400) // 207 = Multi-Status
      })
    } else {
      // Handle single journey import
      const importResult = JourneyExportImport.importFromJson(importData)

      if (!importResult.success || !importResult.journeyData) {
        return NextResponse.json({
          success: false,
          error: "Import validation failed",
          validation: importResult.validation
        }, { status: 400 })
      }

      // Add import metadata
      importResult.journeyData.metadata = {
        ...importResult.journeyData.metadata,
        importedBy,
        batchImport: false,
      }

      // Save the journey
      const saveResult = await JourneyPersistence.saveJourney(
        campaignId, 
        importResult.journeyData, 
        changeNote || "Imported journey"
      )

      if (!saveResult.success) {
        return NextResponse.json({
          success: false,
          error: saveResult.error,
          validation: importResult.validation
        }, { status: 500 })
      }

      return NextResponse.json({
        success: true,
        journey: saveResult.journey,
        validation: importResult.validation
      }, { status: 201 })
    }
  } catch (error) {
    console.error("Failed to import journey:", error)
    return NextResponse.json(
      { 
        error: "Internal server error",
        details: error instanceof Error ? error.message : "Unknown error"
      },
      { status: 500 }
    )
  }
}