import { NextRequest, NextResponse } from "next/server"
import { JourneyPersistence } from "@/lib/journey-persistence"
import { JourneyExportImport } from "@/lib/journey-export-import"

// GET /api/journeys/[id]/export - Export a journey
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { searchParams } = new URL(request.url)
    const format = searchParams.get("format") || "json"
    const exportFormat = searchParams.get("exportFormat") as 'full' | 'template' | 'stages-only' || 'full'
    const exportedBy = searchParams.get("exportedBy") || undefined

    const journeyId = params.id

    // Load the journey
    const result = await JourneyPersistence.loadJourney(journeyId)

    if (!result.success || !result.journey) {
      return NextResponse.json(
        { error: result.error || "Journey not found" },
        { status: result.error === "Journey not found" ? 404 : 500 }
      )
    }

    const journey = result.journey

    // Handle different export formats
    switch (format) {
      case "json": {
        const exportData = JourneyExportImport.exportToJson(journey, exportFormat, exportedBy)
        const filename = JourneyExportImport.generateExportFilename(journey.name, "json")
        
        return new NextResponse(JSON.stringify(exportData, null, 2), {
          headers: {
            'Content-Type': 'application/json',
            'Content-Disposition': `attachment; filename="${filename}"`,
          },
        })
      }

      case "pdf-data": {
        // Return PDF summary data structure (PDF generation would be client-side)
        const pdfData = JourneyExportImport.generatePdfSummaryData(journey)
        
        return NextResponse.json({
          success: true,
          pdfData,
          filename: JourneyExportImport.generateExportFilename(journey.name, "pdf")
        })
      }

      case "diagram": {
        // Return visual diagram data structure
        const diagramData = JourneyExportImport.generateDiagramData(journey)
        const filename = JourneyExportImport.generateExportFilename(journey.name, "json")
        
        return new NextResponse(JSON.stringify(diagramData, null, 2), {
          headers: {
            'Content-Type': 'application/json',
            'Content-Disposition': `attachment; filename="diagram-${filename}"`,
          },
        })
      }

      case "template": {
        // Create and export as template
        const template = JourneyExportImport.createTemplateFromJourney(
          journey,
          `${journey.name} Template`,
          `Template created from journey: ${journey.name}`
        )
        const filename = JourneyExportImport.generateExportFilename(`${journey.name}_template`, "json")
        
        return new NextResponse(JSON.stringify(template, null, 2), {
          headers: {
            'Content-Type': 'application/json',
            'Content-Disposition': `attachment; filename="${filename}"`,
          },
        })
      }

      default:
        return NextResponse.json(
          { error: "Unsupported export format. Supported: json, pdf-data, diagram, template" },
          { status: 400 }
        )
    }
  } catch (error) {
    console.error("Failed to export journey:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}