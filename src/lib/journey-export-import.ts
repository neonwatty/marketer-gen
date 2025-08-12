import { JourneyStage, JourneyTemplate } from "@/components/campaigns/journey-builder"
import { JourneyData, JourneySerializer } from "@/lib/journey-persistence"
import type { Journey } from "@prisma/client"

// Export format types
export interface JourneyExportData {
  journey: JourneyData
  exportMeta: {
    version: string
    exportDate: string
    exportedBy?: string
    format: 'full' | 'template' | 'stages-only'
  }
}

export interface BatchExportData {
  journeys: JourneyExportData[]
  batchMeta: {
    version: string
    exportDate: string
    exportedBy?: string
    totalCount: number
  }
}

export interface ExportValidationResult {
  isValid: boolean
  errors: string[]
  warnings: string[]
}

// Export/Import utility class
export class JourneyExportImport {
  
  /**
   * Export journey to JSON format
   */
  static exportToJson(
    journey: Journey, 
    format: 'full' | 'template' | 'stages-only' = 'full',
    exportedBy?: string
  ): JourneyExportData {
    const stages = JourneySerializer.deserializeStages(journey.stages)
    const settings = JourneySerializer.deserializeSettings(journey.settings || "{}")
    const metadata = JourneySerializer.deserializeSettings(journey.metadata || "{}")

    const journeyData: JourneyData = {
      id: format === 'template' ? undefined : journey.id,
      name: journey.name,
      description: journey.description || undefined,
      category: journey.category as JourneyTemplate["category"] | undefined,
      stages,
      settings: format === 'stages-only' ? undefined : settings,
      metadata: format === 'stages-only' ? undefined : metadata,
    }

    return {
      journey: journeyData,
      exportMeta: {
        version: "1.0.0",
        exportDate: new Date().toISOString(),
        exportedBy,
        format,
      }
    }
  }

  /**
   * Export multiple journeys to JSON format (batch export)
   */
  static exportBatch(
    journeys: Journey[],
    format: 'full' | 'template' | 'stages-only' = 'full',
    exportedBy?: string
  ): BatchExportData {
    const exportedJourneys = journeys.map(journey => 
      this.exportToJson(journey, format, exportedBy)
    )

    return {
      journeys: exportedJourneys,
      batchMeta: {
        version: "1.0.0",
        exportDate: new Date().toISOString(),
        exportedBy,
        totalCount: journeys.length,
      }
    }
  }

  /**
   * Generate PDF summary data structure
   */
  static generatePdfSummaryData(journey: Journey) {
    const stages = JourneySerializer.deserializeStages(journey.stages)
    const settings = JourneySerializer.deserializeSettings(journey.settings || "{}")
    const stats = JourneySerializer.calculateStats(stages)

    return {
      title: journey.name,
      description: journey.description || "No description provided",
      category: journey.category || "Uncategorized",
      createdAt: journey.createdAt.toISOString(),
      updatedAt: journey.updatedAt.toISOString(),
      status: journey.status,
      version: journey.version,
      validation: {
        isValid: journey.isValid,
        completeness: journey.completeness,
        readiness: journey.readiness,
      },
      statistics: stats,
      stages: stages.map((stage, index) => ({
        position: index + 1,
        name: stage.name,
        type: stage.type,
        description: stage.description,
        channels: stage.channels,
        contentTypes: stage.contentTypes,
        isConfigured: stage.isConfigured,
      })),
      settings: settings,
      summary: {
        totalStages: stages.length,
        configuredStages: stages.filter(s => s.isConfigured).length,
        stageBreakdown: {
          awareness: stages.filter(s => s.type === 'awareness').length,
          consideration: stages.filter(s => s.type === 'consideration').length,
          conversion: stages.filter(s => s.type === 'conversion').length,
          retention: stages.filter(s => s.type === 'retention').length,
        }
      }
    }
  }

  /**
   * Generate visual diagram data structure
   */
  static generateDiagramData(journey: Journey) {
    const stages = JourneySerializer.deserializeStages(journey.stages)
    
    // Generate nodes for diagram
    const nodes = stages.map((stage, index) => ({
      id: stage.id,
      type: 'journeyStage',
      position: { x: 200, y: 100 + (index * 150) },
      data: {
        label: stage.name,
        type: stage.type,
        description: stage.description,
        channels: stage.channels,
        contentTypes: stage.contentTypes,
        isConfigured: stage.isConfigured,
      }
    }))

    // Generate edges (connections between stages)
    const edges = stages.slice(0, -1).map((stage, index) => ({
      id: `${stage.id}-${stages[index + 1].id}`,
      source: stage.id,
      target: stages[index + 1].id,
      type: 'smoothstep',
      animated: true,
      label: `Flow ${index + 1}→${index + 2}`,
    }))

    return {
      journeyId: journey.id,
      journeyName: journey.name,
      nodes,
      edges,
      viewport: { x: 0, y: 0, zoom: 1 },
      metadata: {
        nodeCount: nodes.length,
        edgeCount: edges.length,
        generatedAt: new Date().toISOString(),
      }
    }
  }

  /**
   * Validate import data
   */
  static validateImportData(data: any): ExportValidationResult {
    const errors: string[] = []
    const warnings: string[] = []

    // Check if it's a single journey or batch
    const isBatch = data.journeys && Array.isArray(data.journeys)
    const journeys = isBatch ? data.journeys : [data]

    // Validate structure
    if (!isBatch && !data.journey) {
      errors.push("Invalid format: missing 'journey' field")
      return { isValid: false, errors, warnings }
    }

    for (let i = 0; i < journeys.length; i++) {
      const journeyData = isBatch ? journeys[i].journey : journeys[i].journey
      const prefix = isBatch ? `Journey ${i + 1}: ` : ""

      if (!journeyData) {
        errors.push(`${prefix}Missing journey data`)
        continue
      }

      // Validate required fields
      if (!journeyData.name || typeof journeyData.name !== 'string') {
        errors.push(`${prefix}Journey name is required and must be a string`)
      }

      if (!Array.isArray(journeyData.stages)) {
        errors.push(`${prefix}Journey stages must be an array`)
        continue
      }

      if (journeyData.stages.length === 0) {
        warnings.push(`${prefix}Journey has no stages`)
      }

      // Validate stages
      for (let j = 0; j < journeyData.stages.length; j++) {
        const stage = journeyData.stages[j]
        const stagePrefix = `${prefix}Stage ${j + 1}: `

        if (!stage.id || typeof stage.id !== 'string') {
          errors.push(`${stagePrefix}Stage ID is required and must be a string`)
        }

        if (!stage.name || typeof stage.name !== 'string') {
          errors.push(`${stagePrefix}Stage name is required and must be a string`)
        }

        if (!stage.type || !['awareness', 'consideration', 'conversion', 'retention'].includes(stage.type)) {
          errors.push(`${stagePrefix}Stage type must be one of: awareness, consideration, conversion, retention`)
        }

        if (!Array.isArray(stage.channels)) {
          errors.push(`${stagePrefix}Stage channels must be an array`)
        }

        if (!Array.isArray(stage.contentTypes)) {
          errors.push(`${stagePrefix}Stage contentTypes must be an array`)
        }

        if (typeof stage.position !== 'number') {
          warnings.push(`${stagePrefix}Stage position should be a number`)
        }
      }

      // Check for duplicate stage IDs
      const stageIds = journeyData.stages.map((s: any) => s.id).filter(Boolean)
      const duplicateIds = stageIds.filter((id: string, index: number) => stageIds.indexOf(id) !== index)
      if (duplicateIds.length > 0) {
        errors.push(`${prefix}Duplicate stage IDs found: ${duplicateIds.join(', ')}`)
      }
    }

    // Validate version compatibility
    const exportMeta = isBatch ? data.batchMeta : data.exportMeta
    if (exportMeta?.version && exportMeta.version !== "1.0.0") {
      warnings.push("Import data version may not be compatible with current system")
    }

    return {
      isValid: errors.length === 0,
      errors,
      warnings
    }
  }

  /**
   * Import journey data and convert to JourneyData format
   */
  static importFromJson(importData: JourneyExportData | any): {
    success: boolean
    journeyData?: JourneyData
    validation: ExportValidationResult
  } {
    const validation = this.validateImportData(importData)

    if (!validation.isValid) {
      return { success: false, validation }
    }

    try {
      const journeyData = importData.journey || importData

      // Clean and normalize the journey data
      const normalizedJourneyData: JourneyData = {
        name: journeyData.name,
        description: journeyData.description,
        category: journeyData.category,
        stages: journeyData.stages.map((stage: any, index: number) => ({
          ...stage,
          position: stage.position ?? index,
          isConfigured: stage.isConfigured ?? false,
          channels: Array.isArray(stage.channels) ? stage.channels : [],
          contentTypes: Array.isArray(stage.contentTypes) ? stage.contentTypes : [],
        })),
        settings: journeyData.settings || {},
        metadata: {
          ...journeyData.metadata,
          importedAt: new Date().toISOString(),
          originalExportDate: importData.exportMeta?.exportDate,
        }
      }

      return {
        success: true,
        journeyData: normalizedJourneyData,
        validation
      }
    } catch (error) {
      return {
        success: false,
        validation: {
          ...validation,
          errors: [...validation.errors, `Import processing failed: ${error instanceof Error ? error.message : 'Unknown error'}`]
        }
      }
    }
  }

  /**
   * Import batch data
   */
  static importBatchFromJson(batchData: BatchExportData | any): {
    success: boolean
    journeyDataList?: JourneyData[]
    validation: ExportValidationResult
    partialSuccess?: boolean
    successCount?: number
  } {
    const validation = this.validateImportData(batchData)
    
    if (!validation.isValid) {
      return { success: false, validation }
    }

    const journeyDataList: JourneyData[] = []
    const errors: string[] = []
    let successCount = 0

    const journeys = batchData.journeys || []

    for (let i = 0; i < journeys.length; i++) {
      try {
        const importResult = this.importFromJson(journeys[i])
        if (importResult.success && importResult.journeyData) {
          journeyDataList.push(importResult.journeyData)
          successCount++
        } else {
          errors.push(`Journey ${i + 1}: ${importResult.validation.errors.join(', ')}`)
        }
      } catch (error) {
        errors.push(`Journey ${i + 1}: ${error instanceof Error ? error.message : 'Unknown error'}`)
      }
    }

    const finalValidation: ExportValidationResult = {
      isValid: successCount > 0,
      errors: [...validation.errors, ...errors],
      warnings: validation.warnings
    }

    return {
      success: successCount === journeys.length,
      partialSuccess: successCount > 0 && successCount < journeys.length,
      successCount,
      journeyDataList: journeyDataList.length > 0 ? journeyDataList : undefined,
      validation: finalValidation
    }
  }

  /**
   * Create journey template from existing journey
   */
  static createTemplateFromJourney(
    journey: Journey, 
    templateName: string,
    templateDescription?: string
  ): JourneyTemplate {
    const stages = JourneySerializer.deserializeStages(journey.stages)

    const templateStages = stages.map(stage => ({
      name: stage.name,
      description: stage.description,
      type: stage.type,
      channels: [...stage.channels],
      contentTypes: [...stage.contentTypes],
      isConfigured: false, // Templates start unconfigured
    }))

    return {
      id: `template-${Date.now()}`,
      name: templateName,
      description: templateDescription || `Template created from: ${journey.name}`,
      stages: templateStages,
      category: (journey.category as JourneyTemplate["category"]) || "product-launch",
    }
  }

  /**
   * Generate filename for export
   */
  static generateExportFilename(
    journeyName: string, 
    format: string, 
    type: 'single' | 'batch' = 'single'
  ): string {
    const timestamp = new Date().toISOString().slice(0, 19).replace(/[:.]/g, '-')
    const sanitizedName = journeyName.replace(/[^a-zA-Z0-9-_]/g, '_').substring(0, 50)
    
    if (type === 'batch') {
      return `journey-batch-export_${timestamp}.${format}`
    }
    
    return `journey-${sanitizedName}_${timestamp}.${format}`
  }
}