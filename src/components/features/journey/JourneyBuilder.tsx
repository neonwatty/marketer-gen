'use client'

import 'reactflow/dist/style.css'

import { useCallback, useEffect,useState } from 'react'
import {
  addEdge,
  Background,
  BackgroundVariant,
  type Connection,
  Controls,
  type Edge,
  MiniMap,
  type Node,
  ReactFlow,
  useEdgesState,
  useNodesState,
} from 'reactflow'

import { Sparkles } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { JourneyStageConfig,JourneyTemplate } from '@/lib/types/journey'

import { JourneyStageNode } from './JourneyStageNode'
import { JourneyTemplateCustomizer } from './JourneyTemplateCustomizer'
import { JourneyTemplateGallery } from './JourneyTemplateGallery'
import { JourneyToolbar } from './JourneyToolbar'
import { EnhancedJourneyStage,StageConfigurationPanel } from './StageConfigurationPanel'

export interface JourneyStage {
  id: string
  type: 'awareness' | 'consideration' | 'conversion' | 'retention'
  title: string
  description: string
  contentTypes: string[]
  messagingSuggestions: string[]
  position: { x: number; y: number }
}

const nodeTypes = {
  journeyStage: JourneyStageNode,
}

const initialNodes: Node[] = [
  {
    id: '1',
    type: 'journeyStage',
    position: { x: 100, y: 100 },
    data: {
      type: 'awareness',
      title: 'Awareness',
      description: 'Build brand awareness and attract potential customers',
      contentTypes: ['Blog Posts', 'Social Media', 'Video Content'],
      messagingSuggestions: [
        'Introduce your brand values',
        'Share educational content',
        'Tell your brand story',
      ],
    },
  },
  {
    id: '2',
    type: 'journeyStage',
    position: { x: 400, y: 100 },
    data: {
      type: 'consideration',
      title: 'Consideration',
      description: 'Educate prospects and build trust',
      contentTypes: ['Whitepapers', 'Webinars', 'Case Studies'],
      messagingSuggestions: [
        'Demonstrate expertise',
        'Show social proof',
        'Address pain points',
      ],
    },
  },
  {
    id: '3',
    type: 'journeyStage',
    position: { x: 700, y: 100 },
    data: {
      type: 'conversion',
      title: 'Conversion',
      description: 'Convert prospects into customers',
      contentTypes: ['Product Demos', 'Free Trials', 'Pricing Pages'],
      messagingSuggestions: [
        'Create urgency',
        'Highlight unique value',
        'Reduce friction',
      ],
    },
  },
  {
    id: '4',
    type: 'journeyStage',
    position: { x: 1000, y: 100 },
    data: {
      type: 'retention',
      title: 'Retention',
      description: 'Keep customers engaged and satisfied',
      contentTypes: ['Email Newsletters', 'Support Content', 'Community'],
      messagingSuggestions: [
        'Provide ongoing value',
        'Build community',
        'Gather feedback',
      ],
    },
  },
]

const initialEdges: Edge[] = [
  {
    id: 'e1-2',
    source: '1',
    target: '2',
    type: 'smoothstep',
    animated: true,
    label: 'Nurture',
  },
  {
    id: 'e2-3',
    source: '2',
    target: '3',
    type: 'smoothstep',
    animated: true,
    label: 'Convert',
  },
  {
    id: 'e3-4',
    source: '3',
    target: '4',
    type: 'smoothstep',
    animated: true,
    label: 'Retain',
  },
]

export function JourneyBuilder() {
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes)
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges)
  const [selectedNode, setSelectedNode] = useState<Node | null>(null)
  const [isConfigPanelOpen, setIsConfigPanelOpen] = useState(false)
  const [isDragging, setIsDragging] = useState(false)
  const [draggedNode, setDraggedNode] = useState<Node | null>(null)
  
  // Template functionality state
  const [showTemplateGallery, setShowTemplateGallery] = useState(false)
  const [showTemplateCustomizer, setShowTemplateCustomizer] = useState(false)
  const [selectedTemplate, setSelectedTemplate] = useState<JourneyTemplate | null>(null)

  // Move node with keyboard arrows
  const moveNodeWithKeyboard = useCallback((nodeId: string, direction: string) => {
    setNodes((nds) =>
      nds.map((node) => {
        if (node.id === nodeId) {
          let newX = node.position.x
          let newY = node.position.y
          const step = 20 // Grid snap size

          switch (direction) {
            case 'ArrowLeft':
              newX -= step
              break
            case 'ArrowRight':
              newX += step
              break
            case 'ArrowUp':
              newY -= step
              break
            case 'ArrowDown':
              newY += step
              break
          }

          return {
            ...node,
            position: { x: newX, y: newY },
          }
        }
        return node
      })
    )
  }, [setNodes])

  const onDeleteStage = useCallback(
    (nodeId: string) => {
      setNodes((nds) => nds.filter((node) => node.id !== nodeId))
      setEdges((eds) =>
        eds.filter((edge) => edge.source !== nodeId && edge.target !== nodeId)
      )
      if (selectedNode?.id === nodeId) {
        setSelectedNode(null)
        setIsConfigPanelOpen(false)
      }
    },
    [setNodes, setEdges, selectedNode]
  )

  // Keyboard shortcuts and accessibility
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      // Only handle shortcuts when not in an input field
      if (event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement) {
        return
      }

      switch (event.key) {
        case 'Delete':
        case 'Backspace':
          if (selectedNode) {
            event.preventDefault()
            onDeleteStage(selectedNode.id)
          }
          break
        case 'Escape':
          event.preventDefault()
          setSelectedNode(null)
          setIsConfigPanelOpen(false)
          break
        case 'c':
          if (event.ctrlKey || event.metaKey) {
            event.preventDefault()
            // TODO: Copy selected node
          }
          break
        case 'v':
          if (event.ctrlKey || event.metaKey) {
            event.preventDefault()
            // TODO: Paste node
          }
          break
        case 'z':
          if (event.ctrlKey || event.metaKey) {
            event.preventDefault()
            // TODO: Undo/Redo functionality
          }
          break
        case 'ArrowLeft':
        case 'ArrowRight':
        case 'ArrowUp':
        case 'ArrowDown':
          if (selectedNode) {
            event.preventDefault()
            moveNodeWithKeyboard(selectedNode.id, event.key)
          }
          break
        case 'Enter':
        case ' ':
          if (selectedNode) {
            event.preventDefault()
            setIsConfigPanelOpen(true)
          }
          break
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [selectedNode, onDeleteStage, moveNodeWithKeyboard])

  const onConnect = useCallback(
    (params: Edge | Connection) => setEdges((eds) => addEdge(params, eds)),
    [setEdges]
  )

  const onNodeClick = useCallback((_event: React.MouseEvent, node: Node) => {
    setSelectedNode(node)
    setIsConfigPanelOpen(true)
  }, [])

  // Enhanced drag handlers with visual feedback
  const onNodeDragStart = useCallback((_event: React.MouseEvent, node: Node) => {
    setIsDragging(true)
    setDraggedNode(node)
  }, [])

  const onNodeDrag = useCallback((_event: React.MouseEvent, node: Node) => {
    // Real-time position updates during drag
    setNodes((nds) =>
      nds.map((n) => {
        if (n.id === node.id) {
          return {
            ...n,
            data: {
              ...n.data,
              isDragging: true,
            },
          }
        }
        return {
          ...n,
          data: {
            ...n.data,
            isDragging: false,
          },
        }
      })
    )
  }, [setNodes])

  const onNodeDragStop = useCallback((_event: React.MouseEvent, node: Node) => {
    setIsDragging(false)
    setDraggedNode(null)
    
    // Enhanced auto-arrangement with collision detection
    setNodes((nds) => {
      const updatedNodes = nds.map((n) => {
        if (n.id === node.id) {
          const snappedX = Math.round(node.position.x / 20) * 20
          const snappedY = Math.round(node.position.y / 20) * 20
          
          // Check for collisions with other nodes
          const hasCollision = nds.some((otherNode) => {
            if (otherNode.id === n.id) return false
            const distance = Math.sqrt(
              Math.pow(snappedX - otherNode.position.x, 2) + 
              Math.pow(snappedY - otherNode.position.y, 2)
            )
            return distance < 300 // Minimum distance between nodes
          })
          
          // If collision detected, find alternative position
          let finalX = snappedX
          let finalY = snappedY
          
          if (hasCollision) {
            // Try positions in a spiral pattern to avoid overlaps
            const spiralPositions = [
              { x: 0, y: -320 }, { x: 320, y: 0 }, { x: 0, y: 320 }, { x: -320, y: 0 },
              { x: 320, y: -320 }, { x: 320, y: 320 }, { x: -320, y: 320 }, { x: -320, y: -320 }
            ]
            
            for (const offset of spiralPositions) {
              const testX = snappedX + offset.x
              const testY = snappedY + offset.y
              const testCollision = nds.some((otherNode) => {
                if (otherNode.id === n.id) return false
                const distance = Math.sqrt(
                  Math.pow(testX - otherNode.position.x, 2) + 
                  Math.pow(testY - otherNode.position.y, 2)
                )
                return distance < 300
              })
              
              if (!testCollision) {
                finalX = testX
                finalY = testY
                break
              }
            }
          }
          
          return {
            ...n,
            position: { x: finalX, y: finalY },
            data: {
              ...n.data,
              isDragging: false,
            },
          }
        }
        return {
          ...n,
          data: {
            ...n.data,
            isDragging: false,
          },
        }
      })
      
      // Auto-arrange edges after node movement
      autoArrangeConnections(updatedNodes)
      
      return updatedNodes
    })
  }, [setNodes])

  // Helper function to auto-arrange connections based on node positions
  const autoArrangeConnections = useCallback((nodeList: Node[]) => {
    setEdges((currentEdges) => {
      return currentEdges.map((edge) => {
        const sourceNode = nodeList.find(n => n.id === edge.source)
        const targetNode = nodeList.find(n => n.id === edge.target)
        
        if (sourceNode && targetNode) {
          // Update edge styling based on connection distance
          const distance = Math.sqrt(
            Math.pow(targetNode.position.x - sourceNode.position.x, 2) + 
            Math.pow(targetNode.position.y - sourceNode.position.y, 2)
          )
          
          return {
            ...edge,
            animated: distance > 400, // Only animate longer connections
            style: {
              stroke: distance > 600 ? '#ef4444' : '#22c55e', // Red for long, green for short
              strokeWidth: Math.max(1, Math.min(3, 600 / distance)), // Thicker for shorter connections
            },
          }
        }
        return edge
      })
    })
  }, [setEdges])

  const onAddStage = useCallback(
    (stageType: JourneyStage['type']) => {
      const newNodeId = `${nodes.length + 1}`
      const newNode: Node = {
        id: newNodeId,
        type: 'journeyStage',
        position: {
          x: Math.random() * 400 + 200,
          y: Math.random() * 300 + 150,
        },
        data: {
          type: stageType,
          title: stageType.charAt(0).toUpperCase() + stageType.slice(1),
          description: `New ${stageType} stage`,
          contentTypes: [],
          messagingSuggestions: [],
        },
      }
      setNodes((nds) => [...nds, newNode])
    },
    [nodes.length, setNodes]
  )

  const onUpdateStage = useCallback(
    (nodeId: string, updatedData: Partial<EnhancedJourneyStage>) => {
      setNodes((nds) =>
        nds.map((node) =>
          node.id === nodeId
            ? { ...node, data: { ...node.data, ...updatedData } }
            : node
        )
      )
    },
    [setNodes]
  )

  // Template handling functions
  const handleSelectTemplate = useCallback((template: JourneyTemplate) => {
    setSelectedTemplate(template)
    setShowTemplateGallery(false)
    setShowTemplateCustomizer(true)
  }, [])

  const handleUseTemplate = useCallback((template: JourneyTemplate) => {
    // Convert template stages to ReactFlow nodes
    const templateNodes: Node[] = template.stages.map((stage: JourneyStageConfig, index: number) => ({
      id: stage.id,
      type: 'journeyStage',
      position: stage.position,
      data: {
        type: stage.type,
        title: stage.title,
        description: stage.description,
        contentTypes: stage.contentTypes,
        messagingSuggestions: stage.messagingSuggestions,
      },
    }))

    // Create edges to connect stages in sequence
    const templateEdges: Edge[] = []
    for (let i = 0; i < templateNodes.length - 1; i++) {
      templateEdges.push({
        id: `e${templateNodes[i].id}-${templateNodes[i + 1].id}`,
        source: templateNodes[i].id,
        target: templateNodes[i + 1].id,
        type: 'smoothstep',
        animated: true,
        label: getTransitionLabel(templateNodes[i].data.type, templateNodes[i + 1].data.type),
      })
    }

    // Replace current journey with template
    setNodes(templateNodes)
    setEdges(templateEdges)
    setShowTemplateCustomizer(false)
    setSelectedTemplate(null)
  }, [setNodes, setEdges])

  const getTransitionLabel = (fromType: string, toType: string): string => {
    const transitions: Record<string, string> = {
      'awareness-consideration': 'Nurture',
      'consideration-conversion': 'Convert',
      'conversion-retention': 'Retain',
      'retention-advocacy': 'Advocate',
      'awareness-conversion': 'Fast-track',
      'consideration-advocacy': 'Promote',
    }
    return transitions[`${fromType}-${toType}`] || 'Next'
  }

  const handleStartFromTemplate = useCallback(() => {
    setShowTemplateGallery(true)
  }, [])

  return (
    <>
      <Card className="h-[800px] w-full">
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Journey Builder</CardTitle>
            <div className="flex gap-2">
              <Button
                onClick={handleStartFromTemplate}
                variant="outline"
                size="sm"
              >
                <Sparkles className="w-4 h-4 mr-2" />
                Use Template
              </Button>
            </div>
          </div>
        </CardHeader>
        <CardContent className="h-full p-0">
          <div 
            className="relative h-full"
            role="application"
            aria-label="Journey Builder Canvas"
            aria-describedby="journey-instructions"
          >
            {/* Screen reader instructions */}
            <div id="journey-instructions" className="sr-only">
              Use arrow keys to move selected nodes. Press Enter or Space to configure a node. 
              Press Delete to remove selected node. Press Escape to deselect.
            </div>
            
            {/* Keyboard shortcuts help */}
            <div 
              className={`absolute top-4 right-4 z-10 bg-white/90 backdrop-blur-sm border rounded-lg p-3 text-xs transition-opacity duration-200 ${
                selectedNode ? 'opacity-100' : 'opacity-0 pointer-events-none'
              }`}
              role="tooltip"
              aria-live="polite"
            >
              <h4 className="font-semibold mb-1">Keyboard Shortcuts</h4>
              <ul className="space-y-0.5 text-muted-foreground">
                <li>↑↓←→ Move node</li>
                <li>Enter/Space Configure</li>
                <li>Delete Remove node</li>
                <li>Escape Deselect</li>
              </ul>
            </div>

            <JourneyToolbar onAddStage={onAddStage} />
            
            <ReactFlow
              nodes={nodes}
              edges={edges}
              onNodesChange={onNodesChange}
              onEdgesChange={onEdgesChange}
              onConnect={onConnect}
              onNodeClick={onNodeClick}
              onNodeDragStart={onNodeDragStart}
              onNodeDrag={onNodeDrag}
              onNodeDragStop={onNodeDragStop}
              nodeTypes={nodeTypes}
              fitView
              snapToGrid={true}
              snapGrid={[20, 20]}
              className={`h-full transition-all duration-200 ${
                isDragging ? 'cursor-grabbing' : 'cursor-default'
              }`}
              nodeOrigin={[0.5, 0.5]}
              minZoom={0.2}
              maxZoom={2}
              proOptions={{ hideAttribution: true }}
              aria-label="Interactive journey building canvas"
              tabIndex={0}
            >
              <Controls />
              <MiniMap />
              <Background variant={BackgroundVariant.Dots} gap={12} size={1} />
            </ReactFlow>

            <StageConfigurationPanel
              isOpen={isConfigPanelOpen}
              onClose={() => {
                setIsConfigPanelOpen(false)
                setSelectedNode(null)
              }}
              stage={selectedNode}
              onUpdate={onUpdateStage}
              onDelete={onDeleteStage}
            />
          </div>
        </CardContent>
      </Card>

      {/* Template Gallery Modal */}
      {showTemplateGallery && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg max-w-7xl max-h-[90vh] overflow-hidden w-full">
            <div className="p-6 border-b">
              <div className="flex items-center justify-between">
                <h2 className="text-xl font-semibold">Choose a Journey Template</h2>
                <Button
                  variant="ghost"
                  onClick={() => setShowTemplateGallery(false)}
                >
                  ×
                </Button>
              </div>
            </div>
            <div className="p-6 max-h-[calc(90vh-120px)] overflow-y-auto">
              <JourneyTemplateGallery
                onSelectTemplate={handleSelectTemplate}
              />
            </div>
          </div>
        </div>
      )}

      {/* Template Customizer Modal */}
      <JourneyTemplateCustomizer
        template={selectedTemplate}
        open={showTemplateCustomizer}
        onClose={() => {
          setShowTemplateCustomizer(false)
          setSelectedTemplate(null)
        }}
        onConfirm={handleUseTemplate}
      />
    </>
  )
}