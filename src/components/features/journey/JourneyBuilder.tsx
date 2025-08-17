'use client'

import 'reactflow/dist/style.css'

import { useCallback, useState } from 'react'
import {
  addEdge,
  Background,
  type Connection,
  Controls,
  type Edge,
  MiniMap,
  type Node,
  ReactFlow,
  useEdgesState,
  useNodesState,
} from 'reactflow'

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

import { JourneyStageNode } from './JourneyStageNode'
import { JourneyToolbar } from './JourneyToolbar'
import { StageConfigurationPanel } from './StageConfigurationPanel'

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

  const onConnect = useCallback(
    (params: Edge | Connection) => setEdges((eds) => addEdge(params, eds)),
    [setEdges]
  )

  const onNodeClick = useCallback((_event: React.MouseEvent, node: Node) => {
    setSelectedNode(node)
    setIsConfigPanelOpen(true)
  }, [])

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
    (nodeId: string, updatedData: Partial<JourneyStage>) => {
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

  return (
    <Card className="h-[800px] w-full">
      <CardHeader>
        <CardTitle>Journey Builder</CardTitle>
      </CardHeader>
      <CardContent className="h-full p-0">
        <div className="relative h-full">
          <JourneyToolbar onAddStage={onAddStage} />
          
          <ReactFlow
            nodes={nodes}
            edges={edges}
            onNodesChange={onNodesChange}
            onEdgesChange={onEdgesChange}
            onConnect={onConnect}
            onNodeClick={onNodeClick}
            nodeTypes={nodeTypes}
            fitView
            className="h-full"
          >
            <Controls />
            <MiniMap />
            <Background variant={'dots' as any} gap={12} size={1} />
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
  )
}