'use client'

import { memo } from 'react'
import { Handle, type NodeProps,Position } from 'reactflow'

import { Eye, Target, TrendingUp, Users } from 'lucide-react'

import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader } from '@/components/ui/card'

import type { JourneyStage } from './JourneyBuilder'

const stageIcons = {
  awareness: Eye,
  consideration: TrendingUp,
  conversion: Target,
  retention: Users,
}

const stageColors = {
  awareness: 'bg-blue-100 border-blue-300 text-blue-900',
  consideration: 'bg-yellow-100 border-yellow-300 text-yellow-900',
  conversion: 'bg-green-100 border-green-300 text-green-900',
  retention: 'bg-purple-100 border-purple-300 text-purple-900',
}

export const JourneyStageNode = memo<NodeProps<JourneyStage>>(function JourneyStageNode({ data, selected }) {
  const Icon = stageIcons[data.type]
  const colorClass = stageColors[data.type]

  return (
    <div className="relative">
      <Handle
        type="target"
        position={Position.Left}
        className="!bg-gray-400 !border-2 !border-white !w-3 !h-3"
      />
      
      <Card
        className={`w-64 cursor-pointer transition-all hover:shadow-lg ${
          selected ? 'ring-2 ring-primary shadow-lg' : ''
        } ${colorClass}`}
      >
        <CardHeader className="pb-2">
          <div className="flex items-center gap-2">
            <Icon className="h-5 w-5" />
            <h3 className="font-semibold text-sm">{data.title}</h3>
          </div>
        </CardHeader>
        
        <CardContent className="space-y-3">
          <p className="text-xs opacity-90">{data.description}</p>
          
          {data.contentTypes && data.contentTypes.length > 0 && (
            <div>
              <p className="text-xs font-medium mb-1">Content Types:</p>
              <div className="flex flex-wrap gap-1">
                {data.contentTypes.slice(0, 3).map((contentType) => (
                  <Badge
                    key={contentType}
                    variant="secondary"
                    className="text-xs px-1 py-0"
                  >
                    {contentType}
                  </Badge>
                ))}
                {data.contentTypes.length > 3 && (
                  <Badge variant="secondary" className="text-xs px-1 py-0">
                    +{data.contentTypes.length - 3}
                  </Badge>
                )}
              </div>
            </div>
          )}
          
          {data.messagingSuggestions && data.messagingSuggestions.length > 0 && (
            <div>
              <p className="text-xs font-medium mb-1">Key Messages:</p>
              <ul className="text-xs space-y-1">
                {data.messagingSuggestions.slice(0, 2).map((message, index) => (
                  <li key={index} className="opacity-90">
                    • {message}
                  </li>
                ))}
                {data.messagingSuggestions.length > 2 && (
                  <li className="opacity-70">
                    • +{data.messagingSuggestions.length - 2} more...
                  </li>
                )}
              </ul>
            </div>
          )}
        </CardContent>
      </Card>
      
      <Handle
        type="source"
        position={Position.Right}
        className="!bg-gray-400 !border-2 !border-white !w-3 !h-3"
      />
    </div>
  )
})