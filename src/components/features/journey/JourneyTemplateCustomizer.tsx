'use client'

import { useCallback, useEffect, useState } from 'react'
import {
  Background,
  BackgroundVariant,
  Controls,
  type Edge,
  MiniMap,
  type Node,
  ReactFlow,
} from 'reactflow'

import { AlertCircle, Check, Edit2, Eye, Plus, Trash2, X } from 'lucide-react'

import { Alert, AlertDescription } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Separator } from '@/components/ui/separator'
import { Textarea } from '@/components/ui/textarea'
import {
  createDefaultStageConfig,
  getStageTypeDisplayName,
  JourneyStageConfig,
  JourneyStageType,
  JourneyStageTypeValue,
  JourneyTemplate,
} from '@/lib/types/journey'

interface JourneyTemplateCustomizerProps {
  template: JourneyTemplate | null
  open: boolean
  onClose: () => void
  onConfirm: (customizedTemplate: JourneyTemplate) => void
}

export function JourneyTemplateCustomizer({ template, open, onClose, onConfirm }: JourneyTemplateCustomizerProps) {
  const [customizedTemplate, setCustomizedTemplate] = useState<JourneyTemplate | null>(null)
  const [journeyName, setJourneyName] = useState('')
  const [stages, setStages] = useState<JourneyStageConfig[]>([])
  const [editingStage, setEditingStage] = useState<JourneyStageConfig | null>(null)
  const [showStageEditor, setShowStageEditor] = useState(false)
  const [showPreview, setShowPreview] = useState(false)
  const [errors, setErrors] = useState<string[]>([])

  // Convert stages to ReactFlow nodes and edges for preview
  const generatePreviewNodes = useCallback((): Node[] => {
    return stages.map((stage, index) => ({
      id: stage.id,
      type: 'default',
      position: { x: index * 200, y: 100 },
      data: {
        label: (
          <div className="text-xs">
            <div className="font-semibold">{stage.title}</div>
            <div className="text-muted-foreground mt-1">{stage.type}</div>
          </div>
        ),
      },
      className: 'bg-background border-2 border-border rounded-lg shadow-sm',
    }))
  }, [stages])

  const generatePreviewEdges = useCallback((): Edge[] => {
    const edges: Edge[] = []
    for (let i = 0; i < stages.length - 1; i++) {
      edges.push({
        id: `e${stages[i].id}-${stages[i + 1].id}`,
        source: stages[i].id,
        target: stages[i + 1].id,
        type: 'smoothstep',
        animated: true,
      })
    }
    return edges
  }, [stages])

  useEffect(() => {
    if (template && open) {
      setCustomizedTemplate({ ...template })
      setJourneyName(`${template.name} - Custom`)
      setStages([...template.stages])
      setErrors([])
    }
  }, [template, open])

  const validateCustomization = (): boolean => {
    const newErrors: string[] = []

    if (!journeyName.trim()) {
      newErrors.push('Journey name is required')
    }

    if (stages.length === 0) {
      newErrors.push('At least one stage is required')
    }

    // Validate stages
    stages.forEach((stage, index) => {
      if (!stage.title.trim()) {
        newErrors.push(`Stage ${index + 1}: Title is required`)
      }
      if (!stage.description.trim()) {
        newErrors.push(`Stage ${index + 1}: Description is required`)
      }
    })

    setErrors(newErrors)
    return newErrors.length === 0
  }

  const handleConfirm = () => {
    if (!customizedTemplate || !validateCustomization()) {
      return
    }

    const finalTemplate: JourneyTemplate = {
      ...customizedTemplate,
      name: journeyName,
      stages,
      // Reset usage stats for customized template
      usageCount: 0,
      rating: undefined,
      ratingCount: 0,
    }

    onConfirm(finalTemplate)
  }

  const handleAddStage = () => {
    const newStage = createDefaultStageConfig(
      'awareness',
      { x: (stages.length + 1) * 300, y: 100 }
    )
    setEditingStage(newStage)
    setShowStageEditor(true)
  }

  const handleEditStage = (stage: JourneyStageConfig) => {
    setEditingStage({ ...stage })
    setShowStageEditor(true)
  }

  const handleSaveStage = (updatedStage: JourneyStageConfig) => {
    const existingIndex = stages.findIndex(s => s.id === updatedStage.id)
    if (existingIndex >= 0) {
      // Update existing stage
      const updatedStages = [...stages]
      updatedStages[existingIndex] = updatedStage
      setStages(updatedStages)
    } else {
      // Add new stage
      setStages([...stages, updatedStage])
    }
    setShowStageEditor(false)
    setEditingStage(null)
  }

  const handleDeleteStage = (stageId: string) => {
    // Check if template allows stage deletion
    const canDelete = template?.customizationConfig?.allowStageDeletion !== false
    if (!canDelete && stages.length <= 1) {
      setErrors(['Cannot delete the last remaining stage'])
      return
    }

    setStages(stages.filter(s => s.id !== stageId))
    setErrors([]) // Clear errors when successfully deleting
  }

  const handleReorderStage = (stageId: string, direction: 'up' | 'down') => {
    const currentIndex = stages.findIndex(s => s.id === stageId)
    if (currentIndex === -1) return

    const newIndex = direction === 'up' ? currentIndex - 1 : currentIndex + 1
    if (newIndex < 0 || newIndex >= stages.length) return

    const reorderedStages = [...stages]
    const [movedStage] = reorderedStages.splice(currentIndex, 1)
    reorderedStages.splice(newIndex, 0, movedStage)
    
    // Update positions
    reorderedStages.forEach((stage, index) => {
      stage.position.x = (index + 1) * 300
    })

    setStages(reorderedStages)
  }

  const canAddStages = template?.customizationConfig?.allowStageAddition !== false
  const canReorderStages = template?.customizationConfig?.allowStageReordering !== false
  const canDeleteStages = template?.customizationConfig?.allowStageDeletion !== false

  if (!template) return null

  return (
    <>
      <Dialog open={open} onOpenChange={onClose}>
        <DialogContent className="max-w-6xl max-h-[90vh] overflow-hidden flex flex-col">
          <DialogHeader>
            <div className="flex items-center justify-between">
              <div>
                <DialogTitle>Customize Journey Template</DialogTitle>
                <DialogDescription>
                  Customize this template to fit your specific needs. You can modify stages, content, and messaging.
                </DialogDescription>
              </div>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setShowPreview(!showPreview)}
              >
                <Eye className="w-4 h-4 mr-2" />
                {showPreview ? 'Hide Preview' : 'Show Preview'}
              </Button>
            </div>
          </DialogHeader>

          <div className="flex-1 overflow-hidden flex gap-4">
            <div className="flex-1 overflow-y-auto space-y-6">
            {/* Errors */}
            {errors.length > 0 && (
              <Alert variant="destructive">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription>
                  <div className="space-y-1">
                    {errors.map((error, index) => (
                      <div key={index}>{error}</div>
                    ))}
                  </div>
                </AlertDescription>
              </Alert>
            )}

            {/* Journey Name */}
            <div className="space-y-2">
              <Label htmlFor="journeyName">Journey Name</Label>
              <Input
                id="journeyName"
                value={journeyName}
                onChange={(e) => setJourneyName(e.target.value)}
                placeholder="Enter journey name"
              />
            </div>

            {/* Template Info */}
            <div className="space-y-2">
              <Label>Template Information</Label>
              <div className="p-3 bg-muted rounded-lg space-y-2">
                <div className="flex items-center gap-2">
                  <Badge variant="secondary">{template.industry}</Badge>
                  <Badge variant="outline">{template.category}</Badge>
                  {template.metadata?.difficulty && (
                    <Badge variant="default">{template.metadata.difficulty}</Badge>
                  )}
                </div>
                {template.description && (
                  <p className="text-sm text-muted-foreground">{template.description}</p>
                )}
              </div>
            </div>

            <Separator />

            {/* Stages Section */}
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <Label className="text-base font-semibold">Journey Stages</Label>
                {canAddStages && (
                  <Button onClick={handleAddStage} size="sm">
                    <Plus className="w-4 h-4 mr-2" />
                    Add Stage
                  </Button>
                )}
              </div>

              <ScrollArea className="h-80">
                <div className="space-y-3 pr-4">
                  {stages.map((stage, index) => (
                    <div key={stage.id} className="border rounded-lg p-4 space-y-3">
                      <div className="flex items-start justify-between">
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-1">
                            <span className="w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-xs font-semibold">
                              {index + 1}
                            </span>
                            <h4 className="font-medium truncate">{stage.title}</h4>
                            <Badge variant="outline" className="text-xs">
                              {getStageTypeDisplayName(stage.type)}
                            </Badge>
                          </div>
                          <p className="text-sm text-muted-foreground line-clamp-2 ml-8">
                            {stage.description}
                          </p>
                        </div>
                        
                        <div className="flex items-center gap-1 ml-2">
                          {canReorderStages && index > 0 && (
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => handleReorderStage(stage.id, 'up')}
                            >
                              ↑
                            </Button>
                          )}
                          {canReorderStages && index < stages.length - 1 && (
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => handleReorderStage(stage.id, 'down')}
                            >
                              ↓
                            </Button>
                          )}
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleEditStage(stage)}
                          >
                            <Edit2 className="w-4 h-4" />
                          </Button>
                          {canDeleteStages && stages.length > 1 && (
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => handleDeleteStage(stage.id)}
                            >
                              <Trash2 className="w-4 h-4" />
                            </Button>
                          )}
                        </div>
                      </div>

                      {/* Content Types */}
                      {stage.contentTypes.length > 0 && (
                        <div className="ml-8">
                          <div className="flex flex-wrap gap-1">
                            {stage.contentTypes.map((type, i) => (
                              <Badge key={i} variant="outline" className="text-xs">
                                {type}
                              </Badge>
                            ))}
                          </div>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </ScrollArea>

              {stages.length === 0 && (
                <div className="text-center py-8 text-muted-foreground">
                  <p>No stages defined. Add at least one stage to proceed.</p>
                </div>
              )}
            </div>
            </div>

            {/* Preview Panel */}
            {showPreview && (
              <div className="w-1/2 border-l pl-4">
                <Label className="text-base font-semibold mb-2 block">Live Preview</Label>
                <Card className="h-96">
                  <CardContent className="h-full p-2">
                    <ReactFlow
                      nodes={generatePreviewNodes()}
                      edges={generatePreviewEdges()}
                      fitView
                      nodeOrigin={[0.5, 0.5]}
                      minZoom={0.1}
                      maxZoom={1}
                      nodesDraggable={false}
                      nodesConnectable={false}
                      elementsSelectable={false}
                      className="w-full h-full"
                    >
                      <Background variant={BackgroundVariant.Dots} gap={12} size={1} />
                      <Controls showInteractive={false} />
                      <MiniMap pannable={false} zoomable={false} />
                    </ReactFlow>
                  </CardContent>
                </Card>
                <p className="text-xs text-muted-foreground mt-2">
                  Preview updates automatically as you modify stages
                </p>
              </div>
            )}
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button onClick={handleConfirm} disabled={errors.length > 0}>
              <Check className="w-4 h-4 mr-2" />
              Use Customized Template
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Stage Editor Dialog */}
      <StageEditorDialog
        stage={editingStage}
        open={showStageEditor}
        onClose={() => {
          setShowStageEditor(false)
          setEditingStage(null)
        }}
        onSave={handleSaveStage}
        allowedFields={template?.customizationConfig?.editableFields || []}
      />
    </>
  )
}

interface StageEditorDialogProps {
  stage: JourneyStageConfig | null
  open: boolean
  onClose: () => void
  onSave: (stage: JourneyStageConfig) => void
  allowedFields?: string[]
}

function StageEditorDialog({ stage, open, onClose, onSave, allowedFields = [] }: StageEditorDialogProps) {
  const [editedStage, setEditedStage] = useState<JourneyStageConfig | null>(null)

  useEffect(() => {
    if (stage && open) {
      setEditedStage({ ...stage })
    }
  }, [stage, open])

  const handleSave = () => {
    if (!editedStage) return
    onSave(editedStage)
  }

  const handleContentTypeAdd = (contentType: string) => {
    if (!editedStage || !contentType.trim()) return
    
    const updatedStage = {
      ...editedStage,
      contentTypes: [...editedStage.contentTypes, contentType.trim()],
    }
    setEditedStage(updatedStage)
  }

  const handleContentTypeRemove = (index: number) => {
    if (!editedStage) return
    
    const updatedStage = {
      ...editedStage,
      contentTypes: editedStage.contentTypes.filter((_, i) => i !== index),
    }
    setEditedStage(updatedStage)
  }

  const handleMessagingSuggestionAdd = (suggestion: string) => {
    if (!editedStage || !suggestion.trim()) return
    
    const updatedStage = {
      ...editedStage,
      messagingSuggestions: [...editedStage.messagingSuggestions, suggestion.trim()],
    }
    setEditedStage(updatedStage)
  }

  const handleMessagingSuggestionRemove = (index: number) => {
    if (!editedStage) return
    
    const updatedStage = {
      ...editedStage,
      messagingSuggestions: editedStage.messagingSuggestions.filter((_, i) => i !== index),
    }
    setEditedStage(updatedStage)
  }

  const isFieldEditable = (field: string) => {
    return allowedFields.length === 0 || allowedFields.includes(field)
  }

  if (!editedStage) return null

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>
            {stage?.id.includes('stage-') && !stage?.title ? 'Add New Stage' : 'Edit Stage'}
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          {/* Stage Type */}
          <div className="space-y-2">
            <Label htmlFor="stageType">Stage Type</Label>
            <Select
              value={editedStage.type}
              onValueChange={(value: JourneyStageTypeValue) => 
                setEditedStage({ ...editedStage, type: value })
              }
              disabled={!isFieldEditable('type')}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {Object.values(JourneyStageType).map((type) => (
                  <SelectItem key={type} value={type}>
                    {getStageTypeDisplayName(type)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Stage Title */}
          <div className="space-y-2">
            <Label htmlFor="stageTitle">Title</Label>
            <Input
              id="stageTitle"
              value={editedStage.title}
              onChange={(e) => setEditedStage({ ...editedStage, title: e.target.value })}
              disabled={!isFieldEditable('title')}
            />
          </div>

          {/* Stage Description */}
          <div className="space-y-2">
            <Label htmlFor="stageDescription">Description</Label>
            <Textarea
              id="stageDescription"
              value={editedStage.description}
              onChange={(e) => setEditedStage({ ...editedStage, description: e.target.value })}
              rows={3}
              disabled={!isFieldEditable('description')}
            />
          </div>

          {/* Content Types */}
          {isFieldEditable('contentTypes') && (
            <div className="space-y-2">
              <Label>Content Types</Label>
              <div className="space-y-2">
                <div className="flex flex-wrap gap-2">
                  {editedStage.contentTypes.map((type, index) => (
                    <Badge key={index} variant="secondary" className="gap-1">
                      {type}
                      <X 
                        className="w-3 h-3 cursor-pointer hover:text-destructive" 
                        onClick={() => handleContentTypeRemove(index)}
                      />
                    </Badge>
                  ))}
                </div>
                <div className="flex gap-2">
                  <Input
                    placeholder="Add content type"
                    onKeyPress={(e) => {
                      if (e.key === 'Enter') {
                        handleContentTypeAdd(e.currentTarget.value)
                        e.currentTarget.value = ''
                      }
                    }}
                  />
                </div>
              </div>
            </div>
          )}

          {/* Messaging Suggestions */}
          {isFieldEditable('messagingSuggestions') && (
            <div className="space-y-2">
              <Label>Messaging Suggestions</Label>
              <div className="space-y-2">
                <div className="space-y-1">
                  {editedStage.messagingSuggestions.map((suggestion, index) => (
                    <div key={index} className="flex items-center justify-between p-2 bg-muted rounded">
                      <span className="text-sm flex-1">{suggestion}</span>
                      <X 
                        className="w-4 h-4 cursor-pointer hover:text-destructive ml-2" 
                        onClick={() => handleMessagingSuggestionRemove(index)}
                      />
                    </div>
                  ))}
                </div>
                <div className="flex gap-2">
                  <Input
                    placeholder="Add messaging suggestion"
                    onKeyPress={(e) => {
                      if (e.key === 'Enter') {
                        handleMessagingSuggestionAdd(e.currentTarget.value)
                        e.currentTarget.value = ''
                      }
                    }}
                  />
                </div>
              </div>
            </div>
          )}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button onClick={handleSave}>
            Save Stage
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}