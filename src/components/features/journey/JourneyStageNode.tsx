'use client'

import { memo } from 'react'
import { Handle, type NodeProps, Position } from 'reactflow'

import { Eye, Target, TrendingUp, Users, Clock, ChevronDown, ChevronUp } from 'lucide-react'

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
  awareness: 'bg-blue-50 border-blue-200 text-blue-950 hover:bg-blue-100',
  consideration: 'bg-amber-50 border-amber-200 text-amber-950 hover:bg-amber-100', 
  conversion: 'bg-green-50 border-green-200 text-green-950 hover:bg-green-100',
  retention: 'bg-purple-50 border-purple-200 text-purple-950 hover:bg-purple-100',
}

const stageAccentColors = {
  awareness: 'bg-blue-500',
  consideration: 'bg-amber-500',
  conversion: 'bg-green-500', 
  retention: 'bg-purple-500',
}

export const JourneyStageNode = memo<NodeProps<JourneyStage>>(function JourneyStageNode({ data, selected }) {
  const Icon = stageIcons[data.type]
  const colorClass = stageColors[data.type]
  const accentColorClass = stageAccentColors[data.type]

  return (
    <div className="relative">
      <Handle
        type="target"
        position={Position.Left}
        className={`!border-2 !border-white !w-3 !h-3 ${accentColorClass}`}
      />
      
      <Card
        className={`w-72 cursor-pointer transition-all duration-200 hover:shadow-lg transform hover:scale-[1.02] ${
          selected ? 'ring-2 ring-primary shadow-xl scale-105' : 'shadow-md'
        } ${colorClass}`}
      >
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className={`p-1.5 rounded-full ${accentColorClass}`}>
                <Icon className="h-4 w-4 text-white" />
              </div>
              <h3 className="font-semibold text-sm">{data.title}</h3>
            </div>
            <Badge variant="outline" className="text-xs capitalize px-2">
              {data.type}
            </Badge>
          </div>
        </CardHeader>
        
        <CardContent className="space-y-3">
          <p className="text-xs text-muted-foreground leading-relaxed">{data.description}</p>
          
          {data.contentTypes && data.contentTypes.length > 0 && (
            <div className="space-y-2">
              <div className="flex items-center gap-1">
                <div className={`w-2 h-2 rounded-full ${accentColorClass}`} />
                <p className="text-xs font-medium">Content Types</p>
              </div>
              <div className="flex flex-wrap gap-1">
                {data.contentTypes.slice(0, 3).map((contentType) => (
                  <Badge
                    key={contentType}
                    variant="secondary"
                    className="text-xs px-2 py-0.5 font-normal"
                  >
                    {contentType}
                  </Badge>
                ))}
                {data.contentTypes.length > 3 && (
                  <Badge variant="secondary" className="text-xs px-2 py-0.5 font-normal">
                    +{data.contentTypes.length - 3} more
                  </Badge>
                )}
              </div>
            </div>
          )}
          
          {data.messagingSuggestions && data.messagingSuggestions.length > 0 && (
            <div className="space-y-2">
              <div className="flex items-center gap-1">
                <div className={`w-2 h-2 rounded-full ${accentColorClass}`} />
                <p className="text-xs font-medium">Key Messages</p>
              </div>
              <div className="space-y-1">
                {data.messagingSuggestions.slice(0, 2).map((message, index) => (
                  <p key={index} className="text-xs text-muted-foreground pl-2 border-l-2 border-gray-200">
                    {message}
                  </p>
                ))}
                {data.messagingSuggestions.length > 2 && (
                  <p className="text-xs text-muted-foreground/70 pl-2">
                    +{data.messagingSuggestions.length - 2} more messages...
                  </p>
                )}
              </div>
            </div>
          )}
        </CardContent>
      </Card>
      
      <Handle
        type="source"
        position={Position.Right}
        className={`!border-2 !border-white !w-3 !h-3 ${accentColorClass}`}
      />
    </div>
  )
})