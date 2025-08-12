"use client"

import React, { useState, useCallback } from "react"
import type { JourneyStage, JourneyTemplate } from "@/components/campaigns/journey-builder"
import type { Journey } from "@prisma/client"

// Hook for journey persistence operations
export interface UseJourneyPersistenceOptions {
  campaignId: string
  onSaveSuccess?: (journey: Journey) => void
  onSaveError?: (error: string) => void
  onLoadSuccess?: (journey: Journey) => void
  onLoadError?: (error: string) => void
}

export interface JourneyPersistenceHook {
  // State
  isSaving: boolean
  isLoading: boolean
  lastSaved: Date | null
  currentJourneyId: string | null
  
  // Operations
  saveJourney: (
    name: string,
    description: string | undefined,
    stages: JourneyStage[],
    category?: JourneyTemplate["category"],
    changeNote?: string
  ) => Promise<Journey | null>
  
  loadJourney: (journeyId: string) => Promise<Journey | null>
  updateJourneyStatus: (journeyId: string, status: string, changeNote?: string) => Promise<Journey | null>
  deleteJourney: (journeyId: string) => Promise<boolean>
  duplicateJourney: (journeyId: string, newName: string) => Promise<Journey | null>
  
  // Auto-save functionality
  enableAutoSave: (
    name: string,
    description: string | undefined,
    stages: JourneyStage[],
    category?: JourneyTemplate["category"],
    intervalMs?: number
  ) => void
  disableAutoSave: () => void
}

export function useJourneyPersistence({
  campaignId,
  onSaveSuccess,
  onSaveError,
  onLoadSuccess,
  onLoadError,
}: UseJourneyPersistenceOptions): JourneyPersistenceHook {
  
  const [isSaving, setIsSaving] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [lastSaved, setLastSaved] = useState<Date | null>(null)
  const [currentJourneyId, setCurrentJourneyId] = useState<string | null>(null)
  const [autoSaveInterval, setAutoSaveInterval] = useState<NodeJS.Timeout | null>(null)

  const saveJourney = useCallback(async (
    name: string,
    description: string | undefined,
    stages: JourneyStage[],
    category?: JourneyTemplate["category"],
    changeNote?: string
  ): Promise<Journey | null> => {
    setIsSaving(true)
    
    try {
      const journeyData = {
        id: currentJourneyId || undefined,
        name,
        description,
        category,
        stages,
        settings: {},
        metadata: {}
      }

      const url = currentJourneyId 
        ? `/api/journeys/${currentJourneyId}`
        : '/api/journeys'
      
      const method = currentJourneyId ? 'PUT' : 'POST'

      const response = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          campaignId,
          journeyData,
          changeNote
        }),
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to save journey')
      }

      const result = await response.json()
      
      if (result.success && result.journey) {
        setCurrentJourneyId(result.journey.id)
        setLastSaved(new Date())
        onSaveSuccess?.(result.journey)
        return result.journey
      } else {
        throw new Error('Invalid response from server')
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred'
      onSaveError?.(errorMessage)
      return null
    } finally {
      setIsSaving(false)
    }
  }, [campaignId, currentJourneyId, onSaveSuccess, onSaveError])

  const loadJourney = useCallback(async (journeyId: string): Promise<Journey | null> => {
    setIsLoading(true)
    
    try {
      const response = await fetch(`/api/journeys/${journeyId}`)
      
      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to load journey')
      }

      const result = await response.json()
      
      if (result.success && result.journey) {
        setCurrentJourneyId(result.journey.id)
        onLoadSuccess?.(result.journey)
        return result.journey
      } else {
        throw new Error('Invalid response from server')
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred'
      onLoadError?.(errorMessage)
      return null
    } finally {
      setIsLoading(false)
    }
  }, [onLoadSuccess, onLoadError])

  const updateJourneyStatus = useCallback(async (
    journeyId: string, 
    status: string, 
    changeNote?: string
  ): Promise<Journey | null> => {
    try {
      const response = await fetch(`/api/journeys/${journeyId}/status`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ status, changeNote }),
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to update journey status')
      }

      const result = await response.json()
      return result.success ? result.journey : null
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred'
      onSaveError?.(errorMessage)
      return null
    }
  }, [onSaveError])

  const deleteJourney = useCallback(async (journeyId: string): Promise<boolean> => {
    try {
      const response = await fetch(`/api/journeys/${journeyId}`, {
        method: 'DELETE',
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to delete journey')
      }

      const result = await response.json()
      
      if (result.success) {
        // Clear current journey if we deleted it
        if (currentJourneyId === journeyId) {
          setCurrentJourneyId(null)
          setLastSaved(null)
        }
        return true
      }
      
      return false
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred'
      onSaveError?.(errorMessage)
      return false
    }
  }, [currentJourneyId, onSaveError])

  const duplicateJourney = useCallback(async (
    journeyId: string, 
    newName: string
  ): Promise<Journey | null> => {
    try {
      const response = await fetch(`/api/journeys/${journeyId}/duplicate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ 
          name: newName,
          campaignId 
        }),
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to duplicate journey')
      }

      const result = await response.json()
      return result.success ? result.journey : null
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred'
      onSaveError?.(errorMessage)
      return null
    }
  }, [campaignId, onSaveError])

  const enableAutoSave = useCallback((
    name: string,
    description: string | undefined,
    stages: JourneyStage[],
    category?: JourneyTemplate["category"],
    intervalMs: number = 30000 // Default 30 seconds
  ) => {
    // Clear any existing auto-save
    if (autoSaveInterval) {
      clearInterval(autoSaveInterval)
    }

    const interval = setInterval(() => {
      // Only auto-save if we have content and we're not currently saving
      if (name.trim() && stages.length > 0 && !isSaving) {
        saveJourney(name, description, stages, category, "Auto-saved")
      }
    }, intervalMs)

    setAutoSaveInterval(interval)
  }, [autoSaveInterval, isSaving, saveJourney])

  const disableAutoSave = useCallback(() => {
    if (autoSaveInterval) {
      clearInterval(autoSaveInterval)
      setAutoSaveInterval(null)
    }
  }, [autoSaveInterval])

  // Cleanup on unmount
  React.useEffect(() => {
    return () => {
      if (autoSaveInterval) {
        clearInterval(autoSaveInterval)
      }
    }
  }, [autoSaveInterval])

  return {
    // State
    isSaving,
    isLoading,
    lastSaved,
    currentJourneyId,
    
    // Operations
    saveJourney,
    loadJourney,
    updateJourneyStatus,
    deleteJourney,
    duplicateJourney,
    
    // Auto-save
    enableAutoSave,
    disableAutoSave,
  }
}