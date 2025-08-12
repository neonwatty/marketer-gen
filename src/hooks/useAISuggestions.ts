"use client"

import * as React from "react"
import type { AllAISuggestions, AISuggestion, AISuggestionRequest } from "@/lib/ai-suggestions"

interface AISuggestionsState {
  suggestions: AllAISuggestions[]
  isLoading: boolean
  error?: string
  warnings?: string[]
  lastUpdated?: Date
  metadata?: {
    modelUsed: string
    processingTime: number
    confidence: number
    requestId: string
  }
}

interface UseAISuggestionsOptions {
  journeyId: string
  autoLoad?: boolean
  defaultFilters?: {
    types?: AISuggestion["type"][]
    priorities?: AISuggestion["priority"][]
    minConfidence?: number
  }
  onSuggestionImplemented?: (suggestionId: string) => void
  onError?: (error: string) => void
  onSuccess?: (suggestions: AllAISuggestions[]) => void
}

interface UseAISuggestionsReturn {
  // State
  suggestions: AllAISuggestions[]
  filteredSuggestions: AllAISuggestions[]
  isLoading: boolean
  error?: string
  warnings?: string[]
  lastUpdated?: Date
  metadata?: AISuggestionsState["metadata"]
  
  // Filters
  filters: {
    types: AISuggestion["type"][]
    priorities: AISuggestion["priority"][]
    minConfidence: number
    showImplemented: boolean
  }
  setFilters: React.Dispatch<React.SetStateAction<UseAISuggestionsReturn["filters"]>>
  
  // Actions
  loadSuggestions: (customRequest?: Partial<AISuggestionRequest>) => Promise<void>
  refreshSuggestions: () => Promise<void>
  implementSuggestion: (suggestionId: string) => Promise<boolean>
  getSuggestionStatus: (suggestionId: string) => Promise<{ isImplemented: boolean; implementedAt?: Date } | null>
  
  // Computed values
  stats: {
    totalCount: number
    implementedCount: number
    averageConfidence: number
    priorityCounts: Record<AISuggestion["priority"], number>
    typeCounts: Record<AISuggestion["type"], number>
  }
  
  // Implementation tracking
  implementedSuggestions: Set<string>
}

export function useAISuggestions({
  journeyId,
  autoLoad = true,
  defaultFilters = {},
  onSuggestionImplemented,
  onError,
  onSuccess
}: UseAISuggestionsOptions): UseAISuggestionsReturn {
  
  const [state, setState] = React.useState<AISuggestionsState>({
    suggestions: [],
    isLoading: false
  })
  
  const [filters, setFilters] = React.useState({
    types: defaultFilters.types || ["optimization", "content", "strategy"] as AISuggestion["type"][],
    priorities: defaultFilters.priorities || ["critical", "high", "medium", "low"] as AISuggestion["priority"][],
    minConfidence: defaultFilters.minConfidence || 70,
    showImplemented: false
  })
  
  const [implementedSuggestions, setImplementedSuggestions] = React.useState<Set<string>>(new Set())

  // Load suggestions from API
  const loadSuggestions = React.useCallback(async (customRequest?: Partial<AISuggestionRequest>) => {
    setState(prev => ({ ...prev, isLoading: true, error: undefined }))
    
    try {
      // Build query parameters
      const params = new URLSearchParams({
        types: (customRequest?.suggestionTypes || filters.types).join(","),
        maxSuggestions: String(customRequest?.preferences?.maxSuggestions || 10),
        confidenceThreshold: String(customRequest?.preferences?.confidenceThreshold || filters.minConfidence)
      })
      
      if (customRequest?.preferences?.priorityFilter) {
        params.set("priorityFilter", customRequest.preferences.priorityFilter.join(","))
      }
      
      const response = await fetch(`/api/journeys/${journeyId}/suggestions?${params}`)
      const data = await response.json()
      
      if (!response.ok) {
        throw new Error(data.error || "Failed to load suggestions")
      }
      
      setState(prev => ({
        ...prev,
        suggestions: data.suggestions,
        warnings: data.warnings,
        lastUpdated: new Date(),
        metadata: data.metadata,
        isLoading: false
      }))
      
      onSuccess?.(data.suggestions)
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : "Failed to load suggestions"
      setState(prev => ({
        ...prev,
        error: errorMessage,
        isLoading: false
      }))
      onError?.(errorMessage)
    }
  }, [journeyId, filters, onSuccess, onError])

  // Refresh suggestions (alias for loadSuggestions without custom request)
  const refreshSuggestions = React.useCallback(() => {
    return loadSuggestions()
  }, [loadSuggestions])

  // Implement a suggestion
  const implementSuggestion = React.useCallback(async (suggestionId: string): Promise<boolean> => {
    try {
      const response = await fetch(`/api/suggestions/${suggestionId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "implement" })
      })
      
      if (response.ok) {
        setImplementedSuggestions(prev => new Set(prev.add(suggestionId)))
        onSuggestionImplemented?.(suggestionId)
        return true
      }
      return false
    } catch (error) {
      console.error("Failed to implement suggestion:", error)
      return false
    }
  }, [onSuggestionImplemented])

  // Get suggestion implementation status
  const getSuggestionStatus = React.useCallback(async (suggestionId: string) => {
    try {
      const response = await fetch(`/api/suggestions/${suggestionId}`)
      const data = await response.json()
      
      if (response.ok) {
        return {
          isImplemented: data.isImplemented,
          implementedAt: data.implementedAt ? new Date(data.implementedAt) : undefined
        }
      }
      return null
    } catch (error) {
      console.error("Failed to get suggestion status:", error)
      return null
    }
  }, [])

  // Auto-load suggestions on mount if enabled
  React.useEffect(() => {
    if (autoLoad && journeyId) {
      loadSuggestions()
    }
  }, [autoLoad, journeyId, loadSuggestions])

  // Filter suggestions based on current filter state
  const filteredSuggestions = React.useMemo(() => {
    return state.suggestions.filter(suggestion => {
      // Type filter
      if (!filters.types.includes(suggestion.type)) return false
      
      // Priority filter
      if (!filters.priorities.includes(suggestion.priority)) return false
      
      // Confidence filter
      if (suggestion.confidence < filters.minConfidence) return false
      
      // Implemented filter
      const isImplemented = implementedSuggestions.has(suggestion.id)
      if (!filters.showImplemented && isImplemented) return false
      
      return true
    })
  }, [state.suggestions, filters, implementedSuggestions])

  // Compute statistics
  const stats = React.useMemo(() => {
    const totalCount = state.suggestions.length
    const implementedCount = Array.from(implementedSuggestions).filter(id => 
      state.suggestions.some(s => s.id === id)
    ).length
    
    const averageConfidence = totalCount > 0 
      ? state.suggestions.reduce((sum, s) => sum + s.confidence, 0) / totalCount
      : 0

    const priorityCounts: Record<AISuggestion["priority"], number> = {
      critical: 0,
      high: 0,
      medium: 0,
      low: 0
    }

    const typeCounts: Record<AISuggestion["type"], number> = {
      optimization: 0,
      content: 0,
      strategy: 0,
      channel: 0,
      audience: 0
    }

    state.suggestions.forEach(suggestion => {
      priorityCounts[suggestion.priority]++
      typeCounts[suggestion.type]++
    })

    return {
      totalCount,
      implementedCount,
      averageConfidence,
      priorityCounts,
      typeCounts
    }
  }, [state.suggestions, implementedSuggestions])

  return {
    // State
    suggestions: state.suggestions,
    filteredSuggestions,
    isLoading: state.isLoading,
    error: state.error,
    warnings: state.warnings,
    lastUpdated: state.lastUpdated,
    metadata: state.metadata,
    
    // Filters
    filters,
    setFilters,
    
    // Actions
    loadSuggestions,
    refreshSuggestions,
    implementSuggestion,
    getSuggestionStatus,
    
    // Computed values
    stats,
    implementedSuggestions
  }
}

// Hook for suggestion type icons and colors
export function useSuggestionTypeMetadata() {
  return React.useMemo(() => {
    const typeMetadata = {
      optimization: {
        icon: "TrendingUp",
        color: "blue",
        bgColor: "bg-blue-50",
        textColor: "text-blue-600",
        description: "Performance and efficiency improvements"
      },
      content: {
        icon: "MessageSquare", 
        color: "purple",
        bgColor: "bg-purple-50",
        textColor: "text-purple-600",
        description: "Content creation and messaging recommendations"
      },
      strategy: {
        icon: "Target",
        color: "green", 
        bgColor: "bg-green-50",
        textColor: "text-green-600",
        description: "Strategic planning and approach suggestions"
      },
      channel: {
        icon: "Zap",
        color: "orange",
        bgColor: "bg-orange-50", 
        textColor: "text-orange-600",
        description: "Marketing channel and distribution recommendations"
      },
      audience: {
        icon: "Users",
        color: "pink",
        bgColor: "bg-pink-50",
        textColor: "text-pink-600", 
        description: "Audience targeting and segmentation insights"
      }
    } as const
    
    return typeMetadata
  }, [])
}

// Hook for priority metadata
export function usePriorityMetadata() {
  return React.useMemo(() => {
    const priorityMetadata = {
      critical: {
        color: "red",
        bgColor: "bg-red-100",
        textColor: "text-red-800",
        borderColor: "border-red-200",
        description: "Immediate attention required"
      },
      high: {
        color: "orange", 
        bgColor: "bg-orange-100",
        textColor: "text-orange-800",
        borderColor: "border-orange-200",
        description: "Should be addressed soon"
      },
      medium: {
        color: "blue",
        bgColor: "bg-blue-100", 
        textColor: "text-blue-800",
        borderColor: "border-blue-200",
        description: "Standard priority improvement"
      },
      low: {
        color: "gray",
        bgColor: "bg-gray-100",
        textColor: "text-gray-800", 
        borderColor: "border-gray-200",
        description: "Consider when resources allow"
      }
    } as const
    
    return priorityMetadata
  }, [])
}