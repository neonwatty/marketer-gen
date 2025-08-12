"use client"

import * as React from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Progress } from "@/components/ui/progress"
import { Separator } from "@/components/ui/separator"
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Checkbox } from "@/components/ui/checkbox"
import {
  Lightbulb,
  TrendingUp,
  Target,
  Users,
  MessageSquare,
  Zap,
  Clock,
  DollarSign,
  ChevronDown,
  ChevronUp,
  CheckCircle,
  XCircle,
  RefreshCw,
  Loader2,
  AlertTriangle,
  Info,
  Star,
  ThumbsUp,
  ThumbsDown,
  ArrowRight,
  Brain,
  Sparkles,
  Settings
} from "lucide-react"
import { cn } from "@/lib/utils"
import type { 
  AllAISuggestions, 
  AISuggestion, 
  StageOptimizationSuggestion,
  ContentRecommendation,
  StrategyRecommendation,
  AISuggestionRequest
} from "@/lib/ai-suggestions"

interface AISuggestionsProps {
  journeyId: string
  journeyName?: string
  className?: string
  onSuggestionImplemented?: (suggestionId: string) => void
  onRefreshSuggestions?: () => void
}

interface SuggestionState {
  suggestions: AllAISuggestions[]
  isLoading: boolean
  error?: string
  warnings?: string[]
  lastUpdated?: Date
  filters: {
    types: AISuggestion["type"][]
    priorities: AISuggestion["priority"][]
    minConfidence: number
    showImplemented: boolean
  }
}

// Priority color mapping
const getPriorityColor = (priority: AISuggestion["priority"]) => {
  switch (priority) {
    case "critical": return "bg-red-100 text-red-800 border-red-200"
    case "high": return "bg-orange-100 text-orange-800 border-orange-200"
    case "medium": return "bg-blue-100 text-blue-800 border-blue-200"
    case "low": return "bg-gray-100 text-gray-800 border-gray-200"
    default: return "bg-gray-100 text-gray-800 border-gray-200"
  }
}

// Impact color mapping
const getImpactColor = (impact: AISuggestion["impact"]) => {
  switch (impact) {
    case "high": return "text-green-600"
    case "medium": return "text-yellow-600"
    case "low": return "text-gray-600"
    default: return "text-gray-600"
  }
}

// Type icon mapping
const getTypeIcon = (type: AISuggestion["type"]) => {
  switch (type) {
    case "optimization": return TrendingUp
    case "content": return MessageSquare
    case "strategy": return Target
    case "channel": return Zap
    case "audience": return Users
    default: return Lightbulb
  }
}

// Individual suggestion card component
function SuggestionCard({ 
  suggestion, 
  onImplement, 
  onToggleDetails,
  isExpanded,
  isImplemented 
}: { 
  suggestion: AllAISuggestions
  onImplement: (id: string) => void
  onToggleDetails: (id: string) => void
  isExpanded: boolean
  isImplemented?: boolean
}) {
  const Icon = getTypeIcon(suggestion.type)
  
  return (
    <Card className={cn(
      "transition-all duration-200 hover:shadow-md",
      isImplemented && "opacity-75 bg-green-50"
    )}>
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between">
          <div className="flex items-start gap-3 flex-1">
            <div className={cn(
              "p-2 rounded-lg",
              suggestion.type === "optimization" && "bg-blue-50 text-blue-600",
              suggestion.type === "content" && "bg-purple-50 text-purple-600",
              suggestion.type === "strategy" && "bg-green-50 text-green-600",
              suggestion.type === "channel" && "bg-orange-50 text-orange-600",
              suggestion.type === "audience" && "bg-pink-50 text-pink-600"
            )}>
              <Icon className="h-5 w-5" />
            </div>
            
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-2">
                <CardTitle className="text-lg">{suggestion.title}</CardTitle>
                {isImplemented && (
                  <Badge variant="outline" className="bg-green-100 text-green-800 border-green-200">
                    <CheckCircle className="h-3 w-3 mr-1" />
                    Implemented
                  </Badge>
                )}
              </div>
              
              <CardDescription className="text-sm">
                {suggestion.description}
              </CardDescription>
              
              <div className="flex items-center gap-4 mt-3">
                <Badge className={getPriorityColor(suggestion.priority)}>
                  {suggestion.priority}
                </Badge>
                
                <div className="flex items-center gap-1 text-sm text-gray-500">
                  <Star className="h-4 w-4" />
                  <span>{Math.round(suggestion.confidence)}% confidence</span>
                </div>
                
                <div className={cn("flex items-center gap-1 text-sm", getImpactColor(suggestion.impact))}>
                  <TrendingUp className="h-4 w-4" />
                  <span>{suggestion.impact} impact</span>
                </div>
                
                <div className="flex items-center gap-1 text-sm text-gray-500">
                  <Clock className="h-4 w-4" />
                  <span>{suggestion.effort} effort</span>
                </div>
              </div>
            </div>
          </div>
          
          <div className="flex items-center gap-2">
            {!isImplemented && (
              <Button
                size="sm"
                onClick={() => onImplement(suggestion.id)}
                className="bg-green-600 hover:bg-green-700"
              >
                <CheckCircle className="h-4 w-4 mr-1" />
                Implement
              </Button>
            )}
            
            <Button
              variant="ghost"
              size="sm"
              onClick={() => onToggleDetails(suggestion.id)}
            >
              {isExpanded ? (
                <ChevronUp className="h-4 w-4" />
              ) : (
                <ChevronDown className="h-4 w-4" />
              )}
            </Button>
          </div>
        </div>
      </CardHeader>
      
      <Collapsible open={isExpanded}>
        <CollapsibleContent>
          <CardContent className="pt-0">
            <Separator className="mb-4" />
            
            {/* Reasoning */}
            <div className="mb-4">
              <h4 className="font-medium text-sm text-gray-700 mb-2">AI Reasoning</h4>
              <p className="text-sm text-gray-600">{suggestion.reasoning}</p>
            </div>
            
            {/* Type-specific details */}
            {suggestion.type === "optimization" && (
              <OptimizationDetails suggestion={suggestion as StageOptimizationSuggestion} />
            )}
            
            {suggestion.type === "content" && (
              <ContentDetails suggestion={suggestion as ContentRecommendation} />
            )}
            
            {suggestion.type === "strategy" && (
              <StrategyDetails suggestion={suggestion as StrategyRecommendation} />
            )}
            
            {/* Tags */}
            {suggestion.tags.length > 0 && (
              <div className="mt-4">
                <h4 className="font-medium text-sm text-gray-700 mb-2">Tags</h4>
                <div className="flex flex-wrap gap-1">
                  {suggestion.tags.map(tag => (
                    <Badge key={tag} variant="secondary" className="text-xs">
                      {tag}
                    </Badge>
                  ))}
                </div>
              </div>
            )}
            
            {/* Actions */}
            <div className="flex items-center justify-between mt-4 pt-4 border-t">
              <div className="flex items-center gap-2">
                <Button variant="ghost" size="sm">
                  <ThumbsUp className="h-4 w-4 mr-1" />
                  Helpful
                </Button>
                <Button variant="ghost" size="sm">
                  <ThumbsDown className="h-4 w-4 mr-1" />
                  Not Relevant
                </Button>
              </div>
              
              <div className="text-xs text-gray-500">
                Generated {suggestion.createdAt.toLocaleDateString()}
              </div>
            </div>
          </CardContent>
        </CollapsibleContent>
      </Collapsible>
    </Card>
  )
}

// Optimization suggestion details
function OptimizationDetails({ suggestion }: { suggestion: StageOptimizationSuggestion }) {
  return (
    <div className="space-y-4">
      <div>
        <h4 className="font-medium text-sm text-gray-700 mb-2">Stage: {suggestion.stageName}</h4>
        <Badge variant="outline">{suggestion.targetStageType}</Badge>
      </div>
      
      {suggestion.optimizations.channels && (
        <div>
          <h4 className="font-medium text-sm text-gray-700 mb-2">Channel Optimizations</h4>
          <div className="space-y-2 text-sm">
            {suggestion.optimizations.channels.add.length > 0 && (
              <div>
                <span className="font-medium text-green-600">Add: </span>
                {suggestion.optimizations.channels.add.join(", ")}
              </div>
            )}
            {suggestion.optimizations.channels.remove.length > 0 && (
              <div>
                <span className="font-medium text-red-600">Remove: </span>
                {suggestion.optimizations.channels.remove.join(", ")}
              </div>
            )}
            {suggestion.optimizations.channels.modify.map((mod, index) => (
              <div key={index}>
                <span className="font-medium text-blue-600">Modify: </span>
                {mod.from} → {mod.to} ({mod.reason})
              </div>
            ))}
          </div>
        </div>
      )}
      
      {suggestion.expectedOutcomes && (
        <div>
          <h4 className="font-medium text-sm text-gray-700 mb-2">Expected Outcomes</h4>
          <div className="grid grid-cols-2 gap-4 text-sm">
            {suggestion.expectedOutcomes.engagementIncrease && (
              <div className="flex items-center gap-2">
                <TrendingUp className="h-4 w-4 text-green-600" />
                <span>+{suggestion.expectedOutcomes.engagementIncrease}% engagement</span>
              </div>
            )}
            {suggestion.expectedOutcomes.conversionIncrease && (
              <div className="flex items-center gap-2">
                <Target className="h-4 w-4 text-blue-600" />
                <span>+{suggestion.expectedOutcomes.conversionIncrease}% conversion</span>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

// Content recommendation details
function ContentDetails({ suggestion }: { suggestion: ContentRecommendation }) {
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-4 text-sm">
        <div>
          <span className="font-medium">Content Type:</span> {suggestion.contentType}
        </div>
        <div>
          <span className="font-medium">Channel:</span> {suggestion.channel}
        </div>
      </div>
      
      {suggestion.content.headline && (
        <div>
          <h4 className="font-medium text-sm text-gray-700 mb-2">Suggested Content</h4>
          <div className="bg-gray-50 p-3 rounded-lg space-y-2">
            <div>
              <span className="font-medium">Headline:</span> {suggestion.content.headline}
            </div>
            {suggestion.content.body && (
              <div>
                <span className="font-medium">Body:</span> {suggestion.content.body}
              </div>
            )}
            {suggestion.content.cta && (
              <div>
                <span className="font-medium">CTA:</span> {suggestion.content.cta}
              </div>
            )}
          </div>
        </div>
      )}
      
      <div>
        <h4 className="font-medium text-sm text-gray-700 mb-2">Target Audience</h4>
        <div className="text-sm">
          <span className="font-medium">Segment:</span> {suggestion.audience.segment} ({suggestion.audience.persona})
        </div>
      </div>
      
      <div>
        <h4 className="font-medium text-sm text-gray-700 mb-2">Expected Performance</h4>
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div className="flex items-center gap-2">
            <TrendingUp className="h-4 w-4 text-green-600" />
            <span>{Math.round(suggestion.performance.expectedEngagement)}% engagement</span>
          </div>
          <div className="flex items-center gap-2">
            <Target className="h-4 w-4 text-blue-600" />
            <span>{Math.round(suggestion.performance.expectedConversion)}% conversion</span>
          </div>
        </div>
      </div>
    </div>
  )
}

// Strategy recommendation details
function StrategyDetails({ suggestion }: { suggestion: StrategyRecommendation }) {
  return (
    <div className="space-y-4">
      <div>
        <h4 className="font-medium text-sm text-gray-700 mb-2">Objective</h4>
        <p className="text-sm">{suggestion.strategy.objective}</p>
      </div>
      
      <div>
        <h4 className="font-medium text-sm text-gray-700 mb-2">Approach</h4>
        <p className="text-sm">{suggestion.strategy.approach}</p>
      </div>
      
      <div>
        <h4 className="font-medium text-sm text-gray-700 mb-2">Key Tactics</h4>
        <ul className="text-sm space-y-1">
          {suggestion.strategy.tactics.map((tactic, index) => (
            <li key={index} className="flex items-start gap-2">
              <ArrowRight className="h-4 w-4 text-blue-600 mt-0.5 flex-shrink-0" />
              {tactic}
            </li>
          ))}
        </ul>
      </div>
      
      <div className="grid grid-cols-2 gap-4 text-sm">
        <div>
          <span className="font-medium">Timeline:</span> {suggestion.strategy.timeline}
        </div>
        {suggestion.strategy.budget && (
          <div className="flex items-center gap-1">
            <DollarSign className="h-4 w-4" />
            <span>
              ${suggestion.strategy.budget.min.toLocaleString()} - ${suggestion.strategy.budget.max.toLocaleString()}
            </span>
          </div>
        )}
      </div>
    </div>
  )
}

// Filter controls component
function SuggestionFilters({ 
  filters, 
  onFiltersChange,
  suggestionCount 
}: { 
  filters: SuggestionState["filters"]
  onFiltersChange: (filters: SuggestionState["filters"]) => void
  suggestionCount: number
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm flex items-center gap-2">
          <Settings className="h-4 w-4" />
          Filters ({suggestionCount} suggestions)
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div>
          <label className="text-sm font-medium mb-2 block">Suggestion Types</label>
          <div className="grid grid-cols-2 gap-2">
            {["optimization", "content", "strategy", "channel", "audience"].map(type => (
              <div key={type} className="flex items-center space-x-2">
                <Checkbox
                  id={`type-${type}`}
                  checked={filters.types.includes(type as any)}
                  onCheckedChange={(checked) => {
                    const newTypes = checked
                      ? [...filters.types, type as AISuggestion["type"]]
                      : filters.types.filter(t => t !== type)
                    onFiltersChange({ ...filters, types: newTypes })
                  }}
                />
                <label htmlFor={`type-${type}`} className="text-sm capitalize">
                  {type}
                </label>
              </div>
            ))}
          </div>
        </div>
        
        <div>
          <label className="text-sm font-medium mb-2 block">Priority Levels</label>
          <div className="grid grid-cols-2 gap-2">
            {["critical", "high", "medium", "low"].map(priority => (
              <div key={priority} className="flex items-center space-x-2">
                <Checkbox
                  id={`priority-${priority}`}
                  checked={filters.priorities.includes(priority as any)}
                  onCheckedChange={(checked) => {
                    const newPriorities = checked
                      ? [...filters.priorities, priority as AISuggestion["priority"]]
                      : filters.priorities.filter(p => p !== priority)
                    onFiltersChange({ ...filters, priorities: newPriorities })
                  }}
                />
                <label htmlFor={`priority-${priority}`} className="text-sm capitalize">
                  {priority}
                </label>
              </div>
            ))}
          </div>
        </div>
        
        <div>
          <label className="text-sm font-medium mb-2 block">
            Min Confidence: {filters.minConfidence}%
          </label>
          <input
            type="range"
            min="0"
            max="100"
            step="5"
            value={filters.minConfidence}
            onChange={(e) => onFiltersChange({ 
              ...filters, 
              minConfidence: parseInt(e.target.value) 
            })}
            className="w-full"
          />
        </div>
        
        <div className="flex items-center space-x-2">
          <Checkbox
            id="show-implemented"
            checked={filters.showImplemented}
            onCheckedChange={(checked) => 
              onFiltersChange({ ...filters, showImplemented: !!checked })
            }
          />
          <label htmlFor="show-implemented" className="text-sm">
            Show implemented suggestions
          </label>
        </div>
      </CardContent>
    </Card>
  )
}

// Main AI Suggestions component
export function AISuggestions({ 
  journeyId, 
  journeyName, 
  className,
  onSuggestionImplemented,
  onRefreshSuggestions
}: AISuggestionsProps) {
  const [state, setState] = React.useState<SuggestionState>({
    suggestions: [],
    isLoading: false,
    filters: {
      types: ["optimization", "content", "strategy"],
      priorities: ["critical", "high", "medium", "low"],
      minConfidence: 70,
      showImplemented: false
    }
  })
  
  const [expandedSuggestions, setExpandedSuggestions] = React.useState<Set<string>>(new Set())
  const [implementedSuggestions, setImplementedSuggestions] = React.useState<Set<string>>(new Set())

  // Load suggestions
  const loadSuggestions = React.useCallback(async () => {
    setState(prev => ({ ...prev, isLoading: true, error: undefined }))
    
    try {
      const params = new URLSearchParams({
        types: state.filters.types.join(","),
        maxSuggestions: "10",
        confidenceThreshold: state.filters.minConfidence.toString()
      })
      
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
        isLoading: false
      }))
    } catch (error) {
      setState(prev => ({
        ...prev,
        error: error instanceof Error ? error.message : "Failed to load suggestions",
        isLoading: false
      }))
    }
  }, [journeyId, state.filters])

  // Load suggestions on mount and filter changes
  React.useEffect(() => {
    loadSuggestions()
  }, [loadSuggestions])

  // Handle suggestion implementation
  const handleImplementSuggestion = async (suggestionId: string) => {
    try {
      const response = await fetch(`/api/suggestions/${suggestionId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "implement" })
      })
      
      if (response.ok) {
        setImplementedSuggestions(prev => new Set(prev.add(suggestionId)))
        onSuggestionImplemented?.(suggestionId)
      }
    } catch (error) {
      console.error("Failed to implement suggestion:", error)
    }
  }

  // Toggle suggestion details
  const toggleSuggestionDetails = (suggestionId: string) => {
    setExpandedSuggestions(prev => {
      const newSet = new Set(prev)
      if (newSet.has(suggestionId)) {
        newSet.delete(suggestionId)
      } else {
        newSet.add(suggestionId)
      }
      return newSet
    })
  }

  // Filter suggestions
  const filteredSuggestions = React.useMemo(() => {
    return state.suggestions.filter(suggestion => {
      // Type filter
      if (!state.filters.types.includes(suggestion.type)) return false
      
      // Priority filter
      if (!state.filters.priorities.includes(suggestion.priority)) return false
      
      // Confidence filter
      if (suggestion.confidence < state.filters.minConfidence) return false
      
      // Implemented filter
      const isImplemented = implementedSuggestions.has(suggestion.id)
      if (!state.filters.showImplemented && isImplemented) return false
      
      return true
    })
  }, [state.suggestions, state.filters, implementedSuggestions])

  return (
    <div className={cn("space-y-6", className)}>
      {/* Header */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-purple-50 text-purple-600">
                <Brain className="h-5 w-5" />
              </div>
              <div>
                <CardTitle className="flex items-center gap-2">
                  AI Suggestions
                  <Sparkles className="h-4 w-4 text-yellow-500" />
                </CardTitle>
                <CardDescription>
                  {journeyName ? `Recommendations for ${journeyName}` : "AI-powered journey optimization recommendations"}
                </CardDescription>
              </div>
            </div>
            
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => { loadSuggestions(); onRefreshSuggestions?.() }}
                disabled={state.isLoading}
              >
                {state.isLoading ? (
                  <Loader2 className="h-4 w-4 animate-spin mr-1" />
                ) : (
                  <RefreshCw className="h-4 w-4 mr-1" />
                )}
                Refresh
              </Button>
            </div>
          </div>
        </CardHeader>
        
        {state.warnings && state.warnings.length > 0 && (
          <CardContent className="pt-0">
            <Alert>
              <Info className="h-4 w-4" />
              <AlertTitle>Notice</AlertTitle>
              <AlertDescription>
                <ul className="list-disc list-inside space-y-1">
                  {state.warnings.map((warning, index) => (
                    <li key={index}>{warning}</li>
                  ))}
                </ul>
              </AlertDescription>
            </Alert>
          </CardContent>
        )}
      </Card>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        {/* Filters */}
        <div className="lg:col-span-1">
          <SuggestionFilters
            filters={state.filters}
            onFiltersChange={(filters) => setState(prev => ({ ...prev, filters }))}
            suggestionCount={filteredSuggestions.length}
          />
        </div>

        {/* Suggestions List */}
        <div className="lg:col-span-3 space-y-4">
          {state.isLoading && (
            <div className="flex items-center justify-center py-12">
              <div className="flex items-center gap-2">
                <Loader2 className="h-5 w-5 animate-spin" />
                <span>Generating AI suggestions...</span>
              </div>
            </div>
          )}

          {state.error && (
            <Alert variant="destructive">
              <XCircle className="h-4 w-4" />
              <AlertTitle>Error</AlertTitle>
              <AlertDescription>{state.error}</AlertDescription>
            </Alert>
          )}

          {!state.isLoading && !state.error && filteredSuggestions.length === 0 && (
            <div className="text-center py-12">
              <div className="w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <Lightbulb className="h-10 w-10 text-gray-400" />
              </div>
              <h3 className="text-lg font-semibold text-gray-900 mb-2">No Suggestions Available</h3>
              <p className="text-sm text-gray-500 mb-4">
                Try adjusting your filters or refresh to get new AI suggestions.
              </p>
              <Button onClick={loadSuggestions} variant="outline">
                <RefreshCw className="h-4 w-4 mr-2" />
                Refresh Suggestions
              </Button>
            </div>
          )}

          {filteredSuggestions.map(suggestion => (
            <SuggestionCard
              key={suggestion.id}
              suggestion={suggestion}
              onImplement={handleImplementSuggestion}
              onToggleDetails={toggleSuggestionDetails}
              isExpanded={expandedSuggestions.has(suggestion.id)}
              isImplemented={implementedSuggestions.has(suggestion.id)}
            />
          ))}

          {state.lastUpdated && !state.isLoading && (
            <div className="text-center text-xs text-gray-500 mt-6">
              Last updated: {state.lastUpdated.toLocaleString()}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}