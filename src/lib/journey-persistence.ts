import { prisma } from "@/lib/db"
import type { Journey, JourneyHistory, JourneyStatus } from "@prisma/client"
import type { JourneyStage, JourneyTemplate } from "@/components/campaigns/journey-builder"
import { JourneyValidator, type JourneyValidationResult } from "@/components/campaigns/journey-validation"

// Types for journey persistence
export interface JourneyData {
  id?: string
  name: string
  description?: string
  category?: JourneyTemplate["category"]
  stages: JourneyStage[]
  settings?: Record<string, any>
  metadata?: Record<string, any>
}

export interface JourneyPersistenceResult {
  success: boolean
  journey?: Journey & { validation?: JourneyValidationResult }
  error?: string
}

export interface JourneyHistoryEntry {
  id: string
  version: number
  createdAt: Date
  changeType: string
  changeNote?: string
  changedBy?: string
  validation: {
    isValid: boolean
    completeness: number
    readiness: string
  }
}

// Journey serialization utilities
export class JourneySerializer {
  
  /**
   * Serialize journey stages to JSON string for database storage
   */
  static serializeStages(stages: JourneyStage[]): string {
    try {
      return JSON.stringify(stages, null, 2)
    } catch (error) {
      console.error("Failed to serialize journey stages:", error)
      return "[]"
    }
  }

  /**
   * Deserialize journey stages from JSON string
   */
  static deserializeStages(stagesJson: string): JourneyStage[] {
    try {
      const parsed = JSON.parse(stagesJson)
      return Array.isArray(parsed) ? parsed : []
    } catch (error) {
      console.error("Failed to deserialize journey stages:", error)
      return []
    }
  }

  /**
   * Serialize settings object to JSON string
   */
  static serializeSettings(settings: Record<string, any>): string {
    try {
      return JSON.stringify(settings, null, 2)
    } catch (error) {
      console.error("Failed to serialize journey settings:", error)
      return "{}"
    }
  }

  /**
   * Deserialize settings from JSON string
   */
  static deserializeSettings(settingsJson: string): Record<string, any> {
    try {
      return JSON.parse(settingsJson) || {}
    } catch (error) {
      console.error("Failed to deserialize journey settings:", error)
      return {}
    }
  }

  /**
   * Serialize validation errors to JSON string
   */
  static serializeValidationErrors(validation: JourneyValidationResult): string {
    try {
      return JSON.stringify({
        errors: validation.errors,
        warnings: validation.warnings,
        suggestions: validation.suggestions,
      }, null, 2)
    } catch (error) {
      console.error("Failed to serialize validation errors:", error)
      return "{}"
    }
  }

  /**
   * Calculate journey statistics
   */
  static calculateStats(stages: JourneyStage[]): {
    stageCount: number
    channelCount: number
    contentTypeCount: number
  } {
    const allChannels = new Set<string>()
    const allContentTypes = new Set<string>()
    
    stages.forEach(stage => {
      stage.channels.forEach(channel => allChannels.add(channel))
      stage.contentTypes.forEach(contentType => allContentTypes.add(contentType))
    })

    return {
      stageCount: stages.length,
      channelCount: allChannels.size,
      contentTypeCount: allContentTypes.size,
    }
  }
}

// Journey persistence operations
export class JourneyPersistence {

  /**
   * Save a journey to the database
   */
  static async saveJourney(
    campaignId: string, 
    journeyData: JourneyData,
    changeNote?: string
  ): Promise<JourneyPersistenceResult> {
    try {
      // Validate the journey
      const validation = JourneyValidator.validateJourney(journeyData.stages, journeyData.category)
      const stats = JourneySerializer.calculateStats(journeyData.stages)

      // Prepare journey data
      const stagesJson = JourneySerializer.serializeStages(journeyData.stages)
      const settingsJson = JourneySerializer.serializeSettings(journeyData.settings || {})
      const metadataJson = JourneySerializer.serializeSettings(journeyData.metadata || {})
      const validationErrorsJson = JourneySerializer.serializeValidationErrors(validation)

      let journey: Journey
      let changeType: string

      if (journeyData.id) {
        // Update existing journey
        const existingJourney = await prisma.journey.findUnique({
          where: { id: journeyData.id }
        })

        if (!existingJourney) {
          return { success: false, error: "Journey not found" }
        }

        journey = await prisma.journey.update({
          where: { id: journeyData.id },
          data: {
            name: journeyData.name,
            description: journeyData.description,
            category: journeyData.category,
            stages: stagesJson,
            settings: settingsJson,
            metadata: metadataJson,
            version: existingJourney.version + 1,
            isValid: validation.isValid,
            completeness: validation.completeness,
            readiness: validation.readiness,
            validationErrors: validationErrorsJson,
            stageCount: stats.stageCount,
            channelCount: stats.channelCount,
          }
        })

        changeType = "updated"
      } else {
        // Create new journey
        journey = await prisma.journey.create({
          data: {
            campaignId,
            name: journeyData.name,
            description: journeyData.description,
            category: journeyData.category,
            stages: stagesJson,
            settings: settingsJson,
            metadata: metadataJson,
            version: 1,
            isValid: validation.isValid,
            completeness: validation.completeness,
            readiness: validation.readiness,
            validationErrors: validationErrorsJson,
            stageCount: stats.stageCount,
            channelCount: stats.channelCount,
          }
        })

        changeType = "created"
      }

      // Create history entry
      await this.createHistoryEntry(journey, changeType, changeNote)

      return { 
        success: true, 
        journey: { ...journey, validation } 
      }
    } catch (error) {
      console.error("Failed to save journey:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : "Unknown error" 
      }
    }
  }

  /**
   * Load a journey from the database
   */
  static async loadJourney(journeyId: string): Promise<JourneyPersistenceResult> {
    try {
      const journey = await prisma.journey.findUnique({
        where: { id: journeyId },
        include: {
          campaign: true,
        }
      })

      if (!journey) {
        return { success: false, error: "Journey not found" }
      }

      // Deserialize and validate the journey
      const stages = JourneySerializer.deserializeStages(journey.stages)
      const validation = JourneyValidator.validateJourney(stages, journey.category as JourneyTemplate["category"] | undefined)

      return { 
        success: true, 
        journey: { ...journey, validation } 
      }
    } catch (error) {
      console.error("Failed to load journey:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : "Unknown error" 
      }
    }
  }

  /**
   * Load all journeys for a campaign
   */
  static async loadJourneysByCampaign(campaignId: string): Promise<{
    success: boolean
    journeys?: Journey[]
    error?: string
  }> {
    try {
      const journeys = await prisma.journey.findMany({
        where: { campaignId },
        orderBy: { updatedAt: "desc" }
      })

      return { success: true, journeys }
    } catch (error) {
      console.error("Failed to load journeys:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : "Unknown error" 
      }
    }
  }

  /**
   * Delete a journey
   */
  static async deleteJourney(journeyId: string): Promise<{ success: boolean; error?: string }> {
    try {
      await prisma.journey.delete({
        where: { id: journeyId }
      })

      return { success: true }
    } catch (error) {
      console.error("Failed to delete journey:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : "Unknown error" 
      }
    }
  }

  /**
   * Update journey status
   */
  static async updateJourneyStatus(
    journeyId: string, 
    status: JourneyStatus,
    changeNote?: string
  ): Promise<JourneyPersistenceResult> {
    try {
      const journey = await prisma.journey.update({
        where: { id: journeyId },
        data: { 
          status,
          version: { increment: 1 }
        }
      })

      // Create history entry
      await this.createHistoryEntry(journey, "status_changed", changeNote || `Status changed to ${status}`)

      return { success: true, journey }
    } catch (error) {
      console.error("Failed to update journey status:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : "Unknown error" 
      }
    }
  }

  /**
   * Get journey history
   */
  static async getJourneyHistory(journeyId: string): Promise<{
    success: boolean
    history?: JourneyHistoryEntry[]
    error?: string
  }> {
    try {
      const historyRecords = await prisma.journeyHistory.findMany({
        where: { journeyId },
        orderBy: { createdAt: "desc" },
        take: 50 // Limit to last 50 changes
      })

      const history: JourneyHistoryEntry[] = historyRecords.map(record => ({
        id: record.id,
        version: record.version,
        createdAt: record.createdAt,
        changeType: record.changeType,
        changeNote: record.changeNote || undefined,
        changedBy: record.changedBy || undefined,
        validation: {
          isValid: record.isValid,
          completeness: record.completeness,
          readiness: record.readiness,
        }
      }))

      return { success: true, history }
    } catch (error) {
      console.error("Failed to get journey history:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : "Unknown error" 
      }
    }
  }

  /**
   * Create a history entry for journey changes
   */
  private static async createHistoryEntry(
    journey: Journey, 
    changeType: string, 
    changeNote?: string
  ): Promise<void> {
    try {
      await prisma.journeyHistory.create({
        data: {
          journeyId: journey.id,
          version: journey.version,
          name: journey.name,
          description: journey.description,
          status: journey.status,
          category: journey.category,
          stages: journey.stages,
          settings: journey.settings,
          metadata: journey.metadata,
          changeType,
          changeNote,
          isValid: journey.isValid,
          completeness: journey.completeness,
          readiness: journey.readiness,
          validationErrors: journey.validationErrors,
        }
      })
    } catch (error) {
      console.error("Failed to create history entry:", error)
      // Don't throw - history is nice to have but shouldn't break the main operation
    }
  }

  /**
   * Duplicate a journey
   */
  static async duplicateJourney(
    journeyId: string, 
    newName: string,
    campaignId?: string
  ): Promise<JourneyPersistenceResult> {
    try {
      const originalJourney = await prisma.journey.findUnique({
        where: { id: journeyId }
      })

      if (!originalJourney) {
        return { success: false, error: "Original journey not found" }
      }

      const duplicatedJourney = await prisma.journey.create({
        data: {
          campaignId: campaignId || originalJourney.campaignId,
          name: newName,
          description: originalJourney.description,
          category: originalJourney.category,
          stages: originalJourney.stages,
          settings: originalJourney.settings,
          metadata: originalJourney.metadata,
          version: 1,
          isValid: originalJourney.isValid,
          completeness: originalJourney.completeness,
          readiness: originalJourney.readiness,
          validationErrors: originalJourney.validationErrors,
          stageCount: originalJourney.stageCount,
          channelCount: originalJourney.channelCount,
        }
      })

      // Create history entry
      await this.createHistoryEntry(
        duplicatedJourney, 
        "created", 
        `Duplicated from journey: ${originalJourney.name}`
      )

      return { success: true, journey: duplicatedJourney }
    } catch (error) {
      console.error("Failed to duplicate journey:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : "Unknown error" 
      }
    }
  }
}