import { NextRequest, NextResponse } from "next/server"
import { JourneyPersistence } from "@/lib/journey-persistence"
import { JourneyExportImport } from "@/lib/journey-export-import"

// POST /api/journeys/batch-export - Export multiple journeys
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { journeyIds, campaignId, format = "json", exportFormat = "full", exportedBy } = body

    if (!journeyIds || !Array.isArray(journeyIds) || journeyIds.length === 0) {
      // If no specific journey IDs provided, try to export all journeys from campaign
      if (!campaignId) {
        return NextResponse.json(
          { error: "Either journeyIds array or campaignId is required" },
          { status: 400 }
        )
      }

      // Load all journeys for the campaign
      const campaignJourneysResult = await JourneyPersistence.loadJourneysByCampaign(campaignId)
      
      if (!campaignJourneysResult.success || !campaignJourneysResult.journeys) {
        return NextResponse.json(
          { error: "Failed to load campaign journeys" },
          { status: 500 }
        )
      }

      if (campaignJourneysResult.journeys.length === 0) {
        return NextResponse.json(
          { error: "No journeys found for the specified campaign" },
          { status: 404 }
        )
      }

      const allJourneys = campaignJourneysResult.journeys
      const batchExportData = JourneyExportImport.exportBatch(allJourneys, exportFormat as any, exportedBy)
      const filename = JourneyExportImport.generateExportFilename("campaign-journeys", format, "batch")

      return new NextResponse(JSON.stringify(batchExportData, null, 2), {
        headers: {
          'Content-Type': 'application/json',
          'Content-Disposition': `attachment; filename="${filename}"`,
        },
      })
    }

    // Load specific journeys by IDs
    const journeys = []
    const errors = []

    for (const journeyId of journeyIds) {
      try {
        const result = await JourneyPersistence.loadJourney(journeyId)
        
        if (result.success && result.journey) {
          journeys.push(result.journey)
        } else {
          errors.push({
            journeyId,
            error: result.error || "Journey not found"
          })
        }
      } catch (error) {
        errors.push({
          journeyId,
          error: error instanceof Error ? error.message : "Unknown error"
        })
      }
    }

    if (journeys.length === 0) {
      return NextResponse.json({
        success: false,
        error: "No journeys could be loaded",
        errors
      }, { status: 404 })
    }

    // Handle different export formats
    switch (format) {
      case "json": {
        const batchExportData = JourneyExportImport.exportBatch(journeys, exportFormat as any, exportedBy)
        const filename = JourneyExportImport.generateExportFilename("batch-export", "json", "batch")

        const response = {
          success: true,
          totalRequested: journeyIds.length,
          totalExported: journeys.length,
          errors: errors.length > 0 ? errors : undefined,
          ...batchExportData
        }

        return new NextResponse(JSON.stringify(response, null, 2), {
          headers: {
            'Content-Type': 'application/json',
            'Content-Disposition': `attachment; filename="${filename}"`,
          },
        })
      }

      case "pdf-data": {
        // Return PDF summary data for multiple journeys
        const pdfDataList = journeys.map(journey => ({
          journeyId: journey.id,
          ...JourneyExportImport.generatePdfSummaryData(journey)
        }))

        return NextResponse.json({
          success: true,
          pdfDataList,
          totalRequested: journeyIds.length,
          totalExported: journeys.length,
          errors: errors.length > 0 ? errors : undefined,
          filename: JourneyExportImport.generateExportFilename("batch-export", "pdf", "batch")
        })
      }

      case "diagram": {
        // Return visual diagram data for multiple journeys
        const diagramDataList = journeys.map(journey => 
          JourneyExportImport.generateDiagramData(journey)
        )
        const filename = JourneyExportImport.generateExportFilename("batch-diagrams", "json", "batch")

        const response = {
          success: true,
          diagrams: diagramDataList,
          totalRequested: journeyIds.length,
          totalExported: journeys.length,
          errors: errors.length > 0 ? errors : undefined,
          metadata: {
            generatedAt: new Date().toISOString(),
            exportedBy,
            totalDiagrams: diagramDataList.length
          }
        }

        return new NextResponse(JSON.stringify(response, null, 2), {
          headers: {
            'Content-Type': 'application/json',
            'Content-Disposition': `attachment; filename="diagrams-${filename}"`,
          },
        })
      }

      case "templates": {
        // Create templates from journeys
        const templates = journeys.map(journey => 
          JourneyExportImport.createTemplateFromJourney(
            journey,
            `${journey.name} Template`,
            `Template created from journey: ${journey.name}`
          )
        )
        const filename = JourneyExportImport.generateExportFilename("batch-templates", "json", "batch")

        const response = {
          success: true,
          templates,
          totalRequested: journeyIds.length,
          totalExported: journeys.length,
          errors: errors.length > 0 ? errors : undefined,
          metadata: {
            generatedAt: new Date().toISOString(),
            exportedBy,
            totalTemplates: templates.length
          }
        }

        return new NextResponse(JSON.stringify(response, null, 2), {
          headers: {
            'Content-Type': 'application/json',
            'Content-Disposition': `attachment; filename="templates-${filename}"`,
          },
        })
      }

      default:
        return NextResponse.json(
          { error: "Unsupported export format. Supported: json, pdf-data, diagram, templates" },
          { status: 400 }
        )
    }
  } catch (error) {
    console.error("Failed to batch export journeys:", error)
    return NextResponse.json(
      { 
        error: "Internal server error",
        details: error instanceof Error ? error.message : "Unknown error"
      },
      { status: 500 }
    )
  }
}