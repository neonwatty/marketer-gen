"use client"

import * as React from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import {
  Brain,
  Sparkles,
  Lightbulb,
  TrendingUp,
  MessageSquare,
  Target,
  Users,
  Zap,
  Settings,
  RefreshCw,
  Info,
  Star,
  Clock,
  AlertTriangle
} from "lucide-react"
import { cn } from "@/lib/utils"

// Loading skeleton for individual suggestion cards
export function SuggestionCardSkeleton({ className }: { className?: string }) {
  return (
    <Card className={cn("", className)}>
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between">
          <div className="flex items-start gap-3 flex-1">
            <Skeleton className="w-10 h-10 rounded-lg" />
            <div className="flex-1 space-y-2">
              <div className="flex items-center gap-2">
                <Skeleton className="h-5 w-48" />
                <Skeleton className="h-5 w-16" />
              </div>
              <Skeleton className="h-4 w-full" />
              <Skeleton className="h-4 w-3/4" />
              <div className="flex items-center gap-4 mt-3">
                <Skeleton className="h-5 w-16" />
                <Skeleton className="h-4 w-24" />
                <Skeleton className="h-4 w-20" />
                <Skeleton className="h-4 w-18" />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Skeleton className="h-8 w-24" />
            <Skeleton className="h-8 w-8" />
          </div>
        </div>
      </CardHeader>
    </Card>
  )
}

// Loading state for the entire AI suggestions section
export function AISuggestionsLoadingState({ 
  count = 3,
  className 
}: { 
  count?: number
  className?: string 
}) {
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
                  Generating AI-powered journey optimization recommendations...
                </CardDescription>
              </div>
            </div>
            <Skeleton className="h-9 w-20" />
          </div>
        </CardHeader>
        
        <CardContent className="pt-0">
          <Alert>
            <Info className="h-4 w-4" />
            <AlertTitle>AI Analysis in Progress</AlertTitle>
            <AlertDescription>
              Our AI is analyzing your journey structure and generating personalized recommendations. This usually takes 10-30 seconds.
            </AlertDescription>
          </Alert>
        </CardContent>
      </Card>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        {/* Filters skeleton */}
        <div className="lg:col-span-1">
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <Settings className="h-4 w-4" />
                <Skeleton className="h-5 w-32" />
              </div>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Skeleton className="h-4 w-24" />
                <div className="grid grid-cols-2 gap-2">
                  {Array.from({ length: 4 }, (_, i) => (
                    <div key={i} className="flex items-center space-x-2">
                      <Skeleton className="h-4 w-4" />
                      <Skeleton className="h-4 w-16" />
                    </div>
                  ))}
                </div>
              </div>
              <div className="space-y-2">
                <Skeleton className="h-4 w-20" />
                <Skeleton className="h-2 w-full" />
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Suggestions list skeleton */}
        <div className="lg:col-span-3 space-y-4">
          {Array.from({ length: count }, (_, i) => (
            <SuggestionCardSkeleton key={i} />
          ))}
        </div>
      </div>
    </div>
  )
}

// Empty state when no suggestions are available
export function AISuggestionsEmptyState({ 
  onRefresh,
  className 
}: { 
  onRefresh?: () => void
  className?: string 
}) {
  return (
    <div className={cn("", className)}>
      <Card>
        <CardContent className="flex flex-col items-center justify-center py-12">
          <div className="w-20 h-20 bg-purple-50 rounded-full flex items-center justify-center mb-4">
            <Lightbulb className="h-10 w-10 text-purple-400" />
          </div>
          <h3 className="text-lg font-semibold text-gray-900 mb-2">No AI Suggestions Available</h3>
          <p className="text-sm text-gray-500 text-center mb-4 max-w-md">
            Our AI needs more journey data to generate meaningful suggestions. Try adding more stages or configuring existing ones, then refresh.
          </p>
          {onRefresh && (
            <Button onClick={onRefresh} variant="outline">
              <RefreshCw className="h-4 w-4 mr-2" />
              Generate Suggestions
            </Button>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

// Error state for AI suggestions
export function AISuggestionsErrorState({ 
  error,
  onRetry,
  className 
}: { 
  error: string
  onRetry?: () => void
  className?: string 
}) {
  return (
    <div className={cn("", className)}>
      <Alert variant="destructive">
        <AlertTriangle className="h-4 w-4" />
        <AlertTitle>AI Suggestions Unavailable</AlertTitle>
        <AlertDescription className="mb-3">
          {error}
        </AlertDescription>
        {onRetry && (
          <Button 
            onClick={onRetry} 
            variant="outline" 
            size="sm"
            className="mt-2"
          >
            <RefreshCw className="h-4 w-4 mr-2" />
            Try Again
          </Button>
        )}
      </Alert>
    </div>
  )
}

// Mini suggestion preview for dashboards or compact views
export function AISuggestionPreview({ 
  suggestionCount,
  highPriorityCount,
  onViewAll,
  className 
}: { 
  suggestionCount: number
  highPriorityCount: number
  onViewAll?: () => void
  className?: string 
}) {
  return (
    <Card className={cn("", className)}>
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Brain className="h-5 w-5 text-purple-600" />
            <CardTitle className="text-sm">AI Suggestions</CardTitle>
          </div>
          <Sparkles className="h-4 w-4 text-yellow-500" />
        </div>
      </CardHeader>
      <CardContent>
        <div className="space-y-3">
          <div className="flex items-center justify-between text-sm">
            <span className="text-gray-600">Total suggestions</span>
            <Badge variant="secondary">{suggestionCount}</Badge>
          </div>
          {highPriorityCount > 0 && (
            <div className="flex items-center justify-between text-sm">
              <span className="text-gray-600">High priority</span>
              <Badge className="bg-orange-100 text-orange-800 border-orange-200">
                {highPriorityCount}
              </Badge>
            </div>
          )}
          {onViewAll && (
            <Button 
              size="sm" 
              className="w-full mt-3" 
              onClick={onViewAll}
              variant="outline"
            >
              View All Suggestions
            </Button>
          )}
        </div>
      </CardContent>
    </Card>
  )
}

// Suggestion type indicators for quick filtering
export function SuggestionTypeIndicators({ 
  types,
  onTypeSelect,
  selectedTypes = [],
  className 
}: { 
  types: Array<{ type: string; count: number; icon: React.ComponentType<any> }>
  onTypeSelect?: (type: string) => void
  selectedTypes?: string[]
  className?: string 
}) {
  return (
    <div className={cn("flex flex-wrap gap-2", className)}>
      {types.map(({ type, count, icon: Icon }) => {
        const isSelected = selectedTypes.includes(type)
        return (
          <Button
            key={type}
            variant={isSelected ? "default" : "outline"}
            size="sm"
            onClick={() => onTypeSelect?.(type)}
            className={cn(
              "flex items-center gap-2",
              isSelected && "bg-purple-600 hover:bg-purple-700"
            )}
          >
            <Icon className="h-4 w-4" />
            <span className="capitalize">{type}</span>
            <Badge 
              variant="secondary" 
              className={cn(
                "ml-1 text-xs",
                isSelected && "bg-purple-500 text-white"
              )}
            >
              {count}
            </Badge>
          </Button>
        )
      })}
    </div>
  )
}

// Quick suggestion stats component
export function AISuggestionStats({ 
  totalSuggestions,
  implementedCount,
  avgConfidence,
  topPriority,
  className 
}: { 
  totalSuggestions: number
  implementedCount: number
  avgConfidence: number
  topPriority: "low" | "medium" | "high" | "critical"
  className?: string 
}) {
  const implementationRate = totalSuggestions > 0 ? (implementedCount / totalSuggestions) * 100 : 0
  
  return (
    <div className={cn("grid grid-cols-2 md:grid-cols-4 gap-4", className)}>
      <Card>
        <CardContent className="p-4">
          <div className="text-center">
            <div className="text-2xl font-bold text-purple-600">{totalSuggestions}</div>
            <div className="text-sm text-gray-500">Total Suggestions</div>
          </div>
        </CardContent>
      </Card>
      
      <Card>
        <CardContent className="p-4">
          <div className="text-center">
            <div className="text-2xl font-bold text-green-600">{implementedCount}</div>
            <div className="text-sm text-gray-500">Implemented</div>
            <div className="text-xs text-gray-400 mt-1">
              {Math.round(implementationRate)}% rate
            </div>
          </div>
        </CardContent>
      </Card>
      
      <Card>
        <CardContent className="p-4">
          <div className="text-center">
            <div className="flex items-center justify-center gap-1">
              <Star className="h-4 w-4 text-yellow-500" />
              <span className="text-2xl font-bold text-blue-600">{Math.round(avgConfidence)}%</span>
            </div>
            <div className="text-sm text-gray-500">Avg Confidence</div>
          </div>
        </CardContent>
      </Card>
      
      <Card>
        <CardContent className="p-4">
          <div className="text-center">
            <Badge className={cn(
              "text-sm font-medium",
              topPriority === "critical" && "bg-red-100 text-red-800",
              topPriority === "high" && "bg-orange-100 text-orange-800",
              topPriority === "medium" && "bg-blue-100 text-blue-800",
              topPriority === "low" && "bg-gray-100 text-gray-800"
            )}>
              {topPriority}
            </Badge>
            <div className="text-sm text-gray-500 mt-1">Top Priority</div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}