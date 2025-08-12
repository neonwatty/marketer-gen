"use client"

import * as React from "react"
import {
  DndContext,
  DragOverlay,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragStartEvent,
  DragEndEvent,
  DragOverEvent,
  UniqueIdentifier,
} from "@dnd-kit/core"
import {
  SortableContext,
  sortableKeyboardCoordinates,
  verticalListSortingStrategy,
  useSortable,
} from "@dnd-kit/sortable"
import { CSS } from "@dnd-kit/utilities"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  Users,
  Mail,
  Share2,
  FileText,
  Target,
  Plus,
  GripVertical,
  Settings,
  Trash2,
  ArrowDown,
  ChevronDown,
  LayoutTemplate,
} from "lucide-react"
import { cn } from "@/lib/utils"
import { StageConfigPanel } from "./stage-config-panel"
import { JourneyValidator } from "./journey-validation"
import { JourneyValidationDisplay } from "./journey-validation-display"
import { JourneyExportImport } from "./journey-export-import"
import { AISuggestions } from "./ai-suggestions"

// Types for journey builder
export interface JourneyStage {
  id: string
  name: string
  description: string
  type: "awareness" | "consideration" | "conversion" | "retention"
  channels: string[]
  contentTypes: string[]
  position: number
  isConfigured: boolean
}

export interface JourneyTemplate {
  id: string
  name: string
  description: string
  stages: Omit<JourneyStage, "id" | "position">[]
  category: "product-launch" | "lead-generation" | "re-engagement" | "brand-awareness"
}

interface JourneyBuilderProps {
  initialStages?: JourneyStage[]
  onStagesChange?: (stages: JourneyStage[]) => void
  onShowTemplates?: () => void
  journeyCategory?: JourneyTemplate["category"]
  campaignId?: string
  journeyId?: string
  className?: string
}

// Default stage types with their common channels and content types
const STAGE_DEFAULTS = {
  awareness: {
    channels: ["Social Media", "Blog", "Display Ads", "SEO"],
    contentTypes: ["Blog Posts", "Social Posts", "Infographics", "Videos"]
  },
  consideration: {
    channels: ["Email", "Landing Pages", "Webinars", "Whitepapers"],
    contentTypes: ["Email Series", "Case Studies", "Product Demos", "Comparisons"]
  },
  conversion: {
    channels: ["Email", "Landing Pages", "Retargeting", "Sales"],
    contentTypes: ["Product Pages", "Testimonials", "Offers", "CTAs"]
  },
  retention: {
    channels: ["Email", "Support", "Community", "Upsell"],
    contentTypes: ["Onboarding", "Tutorials", "Updates", "Loyalty Programs"]
  }
}

// Flow connector component to visualize stage connections
function FlowConnector({ 
  isLast = false, 
  fromStage, 
  toStage 
}: { 
  isLast?: boolean
  fromStage?: JourneyStage 
  toStage?: JourneyStage 
}) {
  if (isLast) return null

  const getConnectionStrength = (from?: JourneyStage, to?: JourneyStage) => {
    if (!from || !to) return "normal"
    
    // Logic for connection strength based on stage types
    const typeFlow = {
      awareness: ["consideration"],
      consideration: ["conversion", "awareness"], // can loop back
      conversion: ["retention"],
      retention: ["consideration", "conversion"] // can trigger repeat purchases
    }
    
    return typeFlow[from.type]?.includes(to.type) ? "strong" : "normal"
  }

  const connectionStrength = getConnectionStrength(fromStage, toStage)
  
  return (
    <div className="flex justify-center my-6">
      <div className="flex flex-col items-center">
        {/* Connection line */}
        <div className={cn(
          "w-1 h-8 rounded-full",
          connectionStrength === "strong" ? "bg-blue-500" : "bg-gray-300"
        )} />
        
        {/* Arrow */}
        <div className={cn(
          "flex items-center justify-center w-8 h-8 rounded-full",
          connectionStrength === "strong" 
            ? "bg-blue-500 text-white" 
            : "bg-gray-200 text-gray-600"
        )}>
          <ArrowDown className="h-4 w-4" />
        </div>
        
        {/* Connection indicator */}
        <div className="mt-2 text-xs text-center text-gray-500 max-w-24">
          {connectionStrength === "strong" ? "Strong flow" : "Normal flow"}
        </div>
      </div>
    </div>
  )
}

// Enhanced canvas component with better stage layout
function JourneyCanvas({ 
  stages, 
  onConfigure, 
  onDelete,
  activeId 
}: {
  stages: JourneyStage[]
  onConfigure: (stageId: string) => void
  onDelete: (stageId: string) => void
  activeId: UniqueIdentifier | null
}) {
  if (stages.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <div className="w-20 h-20 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-full flex items-center justify-center mb-6">
          <Target className="h-10 w-10 text-blue-600" />
        </div>
        <h3 className="text-xl font-semibold text-gray-900 mb-2">Start Building Your Journey</h3>
        <p className="text-sm text-gray-500 mb-6 max-w-md">
          Create a customer journey by adding stages above. Each stage represents a phase in your customer&apos;s experience.
        </p>
        <div className="flex items-center gap-2 text-xs text-gray-400">
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 bg-blue-500 rounded-full"></div>
            <span>Awareness</span>
          </div>
          <ArrowDown className="h-3 w-3" />
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 bg-green-500 rounded-full"></div>
            <span>Consideration</span>
          </div>
          <ArrowDown className="h-3 w-3" />
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 bg-orange-500 rounded-full"></div>
            <span>Conversion</span>
          </div>
          <ArrowDown className="h-3 w-3" />
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 bg-purple-500 rounded-full"></div>
            <span>Retention</span>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="relative">
      {/* Canvas background with subtle grid */}
      <div className="absolute inset-0 opacity-30 pointer-events-none">
        <div className="w-full h-full" style={{
          backgroundImage: `
            radial-gradient(circle at 1px 1px, rgba(0,0,0,0.1) 1px, transparent 0)
          `,
          backgroundSize: '24px 24px'
        }} />
      </div>
      
      {/* Stage flow */}
      <div className="relative space-y-0">
        {stages.map((stage, index) => {
          const isLast = index === stages.length - 1
          const nextStage = isLast ? undefined : stages[index + 1]
          
          return (
            <div key={stage.id}>
              <DraggableStage
                stage={stage}
                onConfigure={onConfigure}
                onDelete={onDelete}
              />
              
              <FlowConnector
                isLast={isLast}
                fromStage={stage}
                toStage={nextStage}
              />
            </div>
          )
        })}
      </div>
    </div>
  )
}

// Draggable stage component
function DraggableStage({ stage, onConfigure, onDelete }: {
  stage: JourneyStage
  onConfigure: (stageId: string) => void
  onDelete: (stageId: string) => void
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: stage.id })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  }

  const getStageTypeColor = (type: JourneyStage["type"]) => {
    switch (type) {
      case "awareness":
        return "bg-blue-50 border-blue-200 text-blue-800"
      case "consideration":
        return "bg-green-50 border-green-200 text-green-800"
      case "conversion":
        return "bg-orange-50 border-orange-200 text-orange-800"
      case "retention":
        return "bg-purple-50 border-purple-200 text-purple-800"
      default:
        return "bg-gray-50 border-gray-200 text-gray-800"
    }
  }

  const getStageTypeIcon = (type: JourneyStage["type"]) => {
    switch (type) {
      case "awareness":
        return <Users className="h-4 w-4" />
      case "consideration":
        return <FileText className="h-4 w-4" />
      case "conversion":
        return <Target className="h-4 w-4" />
      case "retention":
        return <Mail className="h-4 w-4" />
      default:
        return <Users className="h-4 w-4" />
    }
  }

  return (
    <Card
      ref={setNodeRef}
      style={style}
      className={cn(
        "cursor-pointer transition-all hover:shadow-md",
        isDragging && "opacity-50 shadow-lg rotate-3",
        !stage.isConfigured && "border-dashed border-2"
      )}
    >
      <CardContent className="p-4">
        <div className="flex items-start gap-3">
          {/* Drag Handle */}
          <button
            className="mt-1 p-1 hover:bg-gray-100 rounded cursor-grab active:cursor-grabbing"
            {...attributes}
            {...listeners}
          >
            <GripVertical className="h-4 w-4 text-gray-500" />
          </button>

          {/* Stage Content */}
          <div className="flex-1">
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <div className={cn("p-1 rounded", getStageTypeColor(stage.type))}>
                  {getStageTypeIcon(stage.type)}
                </div>
                <h3 className="font-semibold">{stage.name}</h3>
                <Badge
                  variant="outline"
                  className={cn("text-xs", getStageTypeColor(stage.type))}
                >
                  {stage.type.charAt(0).toUpperCase() + stage.type.slice(1)}
                </Badge>
              </div>
              
              <div className="flex items-center gap-1">
                {!stage.isConfigured && (
                  <Badge variant="secondary" className="text-xs">
                    Configure
                  </Badge>
                )}
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => onConfigure(stage.id)}
                  className="h-8 w-8 p-0"
                >
                  <Settings className="h-4 w-4" />
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => onDelete(stage.id)}
                  className="h-8 w-8 p-0 text-red-600 hover:text-red-700"
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            </div>

            <p className="text-sm text-gray-600 mb-3">{stage.description}</p>

            {stage.channels.length > 0 && (
              <div className="flex flex-wrap gap-1 mb-2">
                {stage.channels.slice(0, 3).map((channel) => (
                  <Badge key={channel} variant="secondary" className="text-xs">
                    {channel}
                  </Badge>
                ))}
                {stage.channels.length > 3 && (
                  <Badge variant="secondary" className="text-xs">
                    +{stage.channels.length - 3} more
                  </Badge>
                )}
              </div>
            )}

            {stage.contentTypes.length > 0 && (
              <div className="text-xs text-gray-500">
                Content: {stage.contentTypes.slice(0, 2).join(", ")}
                {stage.contentTypes.length > 2 && `, +${stage.contentTypes.length - 2} more`}
              </div>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

// Main journey builder component
export function JourneyBuilder({ initialStages = [], onStagesChange, onShowTemplates, journeyCategory, campaignId, journeyId, className }: JourneyBuilderProps) {
  const [stages, setStages] = React.useState<JourneyStage[]>(initialStages)
  const [activeId, setActiveId] = React.useState<UniqueIdentifier | null>(null)
  const [configStage, setConfigStage] = React.useState<JourneyStage | null>(null)
  const [isConfigPanelOpen, setIsConfigPanelOpen] = React.useState(false)

  // Real-time validation
  const validation = React.useMemo(() => 
    JourneyValidator.validateJourney(stages, journeyCategory),
    [stages, journeyCategory]
  )

  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  )

  const handleDragStart = (event: DragStartEvent) => {
    setActiveId(event.active.id)
  }

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event
    
    if (active.id !== over?.id) {
      const oldIndex = stages.findIndex((stage) => stage.id === active.id)
      const newIndex = stages.findIndex((stage) => stage.id === over?.id)
      
      if (oldIndex !== -1 && newIndex !== -1) {
        const newStages = [...stages]
        const [reorderedItem] = newStages.splice(oldIndex, 1)
        newStages.splice(newIndex, 0, reorderedItem)
        
        // Update positions
        const updatedStages = newStages.map((stage, index) => ({
          ...stage,
          position: index
        }))
        
        setStages(updatedStages)
        onStagesChange?.(updatedStages)
      }
    }
    
    setActiveId(null)
  }

  const addNewStage = (type: JourneyStage["type"]) => {
    const newStage: JourneyStage = {
      id: `stage-${Date.now()}`,
      name: `${type.charAt(0).toUpperCase() + type.slice(1)} Stage`,
      description: `Configure your ${type} stage to engage customers at this phase.`,
      type,
      channels: STAGE_DEFAULTS[type].channels,
      contentTypes: STAGE_DEFAULTS[type].contentTypes,
      position: stages.length,
      isConfigured: false,
    }
    
    const updatedStages = [...stages, newStage]
    setStages(updatedStages)
    onStagesChange?.(updatedStages)
  }

  const configureStage = (stageId: string) => {
    const stage = stages.find(s => s.id === stageId)
    if (stage) {
      setConfigStage(stage)
      setIsConfigPanelOpen(true)
    }
  }

  const handleStageConfigSave = (stageId: string, config: Partial<JourneyStage>) => {
    const updatedStages = stages.map(stage =>
      stage.id === stageId ? { ...stage, ...config } : stage
    )
    setStages(updatedStages)
    onStagesChange?.(updatedStages)
    setIsConfigPanelOpen(false)
    setConfigStage(null)
  }

  const handleConfigPanelClose = () => {
    setIsConfigPanelOpen(false)
    setConfigStage(null)
  }

  const handleFixValidationError = (errorId: string, stageId?: string) => {
    if (stageId) {
      // Open stage configuration for stage-specific errors
      configureStage(stageId)
    } else {
      // Handle journey-level fixes
      if (errorId === "no-stages") {
        // Suggest adding an awareness stage
        addNewStage("awareness")
      } else if (errorId === "missing-conversion") {
        addNewStage("conversion")
      }
      // Add more specific error fixes as needed
    }
  }

  const deleteStage = (stageId: string) => {
    const updatedStages = stages
      .filter((stage) => stage.id !== stageId)
      .map((stage, index) => ({ ...stage, position: index }))
    
    setStages(updatedStages)
    onStagesChange?.(updatedStages)
  }

  const loadTemplate = (template: JourneyTemplate) => {
    const templateStages: JourneyStage[] = template.stages.map((stage, index) => ({
      ...stage,
      id: `stage-${Date.now()}-${index}`,
      position: index,
    }))
    
    setStages(templateStages)
    onStagesChange?.(templateStages)
  }

  const clearJourney = () => {
    setStages([])
    onStagesChange?.([])
  }

  const activeStage = stages.find((stage) => stage.id === activeId)

  return (
    <div className={cn("space-y-6", className)}>
      {/* Header */}
      <Card>
        <CardHeader>
          <CardTitle>Customer Journey Builder</CardTitle>
          <CardDescription>
            Design your customer journey by adding stages and configuring channels and content for each phase.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col sm:flex-row gap-4">
            {/* Template and Clear Actions */}
            <div className="flex gap-2">
              <Button
                size="sm"
                variant="default"
                onClick={onShowTemplates}
                className="flex items-center gap-1"
              >
                <LayoutTemplate className="h-4 w-4" />
                Load Template
              </Button>
              {stages.length > 0 && (
                <Button
                  size="sm"
                  variant="outline"
                  onClick={clearJourney}
                  className="flex items-center gap-1"
                >
                  Clear Journey
                </Button>
              )}
            </div>
            
            {/* Manual Stage Addition */}
            <div className="flex flex-wrap gap-2">
              <Button
                size="sm"
                variant="outline"
                onClick={() => addNewStage("awareness")}
                className="flex items-center gap-1"
              >
                <Plus className="h-4 w-4" />
                Add Awareness
              </Button>
              <Button
                size="sm"
                variant="outline"
                onClick={() => addNewStage("consideration")}
                className="flex items-center gap-1"
              >
                <Plus className="h-4 w-4" />
                Add Consideration
              </Button>
              <Button
                size="sm"
                variant="outline"
                onClick={() => addNewStage("conversion")}
                className="flex items-center gap-1"
              >
                <Plus className="h-4 w-4" />
                Add Conversion
              </Button>
              <Button
                size="sm"
                variant="outline"
                onClick={() => addNewStage("retention")}
                className="flex items-center gap-1"
              >
                <Plus className="h-4 w-4" />
                Add Retention
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Journey Canvas */}
      <Card>
        <CardHeader>
          <CardTitle>Journey Flow</CardTitle>
          <CardDescription>
            Drag and drop to reorder stages. Click the settings icon to configure each stage.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <DndContext
            sensors={sensors}
            collisionDetection={closestCenter}
            onDragStart={handleDragStart}
            onDragEnd={handleDragEnd}
          >
            <SortableContext
              items={stages.map((stage) => stage.id)}
              strategy={verticalListSortingStrategy}
            >
              <JourneyCanvas
                stages={stages}
                onConfigure={configureStage}
                onDelete={deleteStage}
                activeId={activeId}
              />
            </SortableContext>

            <DragOverlay>
              {activeStage ? (
                <Card className="shadow-lg rotate-3">
                  <CardContent className="p-4">
                    <div className="flex items-center gap-2">
                      <GripVertical className="h-4 w-4 text-gray-500" />
                      <h3 className="font-semibold">{activeStage.name}</h3>
                    </div>
                  </CardContent>
                </Card>
              ) : null}
            </DragOverlay>
          </DndContext>
        </CardContent>
      </Card>

      {/* Journey Summary */}
      {stages.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Journey Summary</CardTitle>
            <CardDescription>
              Overview of your customer journey configuration
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-center">
              <div>
                <div className="text-2xl font-bold text-blue-600">
                  {stages.filter(s => s.type === "awareness").length}
                </div>
                <div className="text-sm text-gray-500">Awareness</div>
              </div>
              <div>
                <div className="text-2xl font-bold text-green-600">
                  {stages.filter(s => s.type === "consideration").length}
                </div>
                <div className="text-sm text-gray-500">Consideration</div>
              </div>
              <div>
                <div className="text-2xl font-bold text-orange-600">
                  {stages.filter(s => s.type === "conversion").length}
                </div>
                <div className="text-sm text-gray-500">Conversion</div>
              </div>
              <div>
                <div className="text-2xl font-bold text-purple-600">
                  {stages.filter(s => s.type === "retention").length}
                </div>
                <div className="text-sm text-gray-500">Retention</div>
              </div>
            </div>
            
            <div className="flex items-center justify-between pt-4 border-t">
              <div className="text-sm text-gray-500">
                {stages.filter(s => s.isConfigured).length} of {stages.length} stages configured
              </div>
              <div className="flex gap-2">
                <Button variant="outline" size="sm">
                  Save as Template
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Journey Validation */}
      {stages.length > 0 && (
        <JourneyValidationDisplay
          validation={validation}
          onFixError={handleFixValidationError}
          onConfigureStage={configureStage}
        />
      )}

      {/* Export/Import */}
      {stages.length > 0 && journeyId && (
        <JourneyExportImport
          journeys={[{
            id: journeyId,
            name: "Current Journey",
            description: "Journey being edited",
            status: "draft" as any,
            stages: JSON.stringify(stages),
            version: 1,
            isValid: validation.isValid,
            completeness: validation.completeness,
            readiness: validation.readiness,
            createdAt: new Date(),
            updatedAt: new Date(),
            campaignId: campaignId || "",
            category: journeyCategory || null,
            settings: "{}",
            metadata: "{}",
            validationErrors: "{}",
            stageCount: stages.length,
            channelCount: 0,
          }]}
          campaignId={campaignId}
          onJourneyImported={(journey) => {
            // Handle imported journey - could update stages or show notification
            console.log("Journey imported:", journey)
          }}
          onJourneysImported={(journeys) => {
            // Handle batch imported journeys
            console.log("Journeys imported:", journeys)
          }}
        />
      )}

      {/* AI Suggestions */}
      {stages.length > 0 && journeyId && (
        <AISuggestions
          journeyId={journeyId}
          journeyName="Current Journey"
          onSuggestionImplemented={(suggestionId) => {
            // Handle suggestion implementation - could update stages or show notification
            console.log("Suggestion implemented:", suggestionId)
          }}
          onRefreshSuggestions={() => {
            // Handle suggestion refresh - could show notification
            console.log("Refreshing AI suggestions")
          }}
        />
      )}

      {/* Stage Configuration Panel */}
      <StageConfigPanel
        stage={configStage}
        isOpen={isConfigPanelOpen}
        onClose={handleConfigPanelClose}
        onSave={handleStageConfigSave}
      />
    </div>
  )
}