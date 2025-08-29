'use client'

import { memo, useState } from 'react'
import { Handle, type NodeProps, Position } from 'reactflow'

import { 
  Eye, 
  Target, 
  TrendingUp, 
  Users, 
  Clock, 
  ChevronDown, 
  ChevronUp, 
  GripVertical,
  Move,
  MoreVertical 
} from 'lucide-react'

import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

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

interface EnhancedJourneyStage extends JourneyStage {
  isDragging?: boolean
}

export const JourneyStageNode = memo<NodeProps<EnhancedJourneyStage>>(function JourneyStageNode({ data, selected }) {
  const [isExpanded, setIsExpanded] = useState(false)
  const [isHovered, setIsHovered] = useState(false)
  
  const Icon = stageIcons[data.type]
  const colorClass = stageColors[data.type]
  const accentColorClass = stageAccentColors[data.type]

  const isDragging = data.isDragging || false
  const dragOpacity = isDragging ? 'opacity-70' : 'opacity-100'
  const dragScale = isDragging ? 'scale-110' : selected ? 'scale-105' : 'scale-100'

  return (
    <div 
      className="relative group"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      <Handle
        type="target"
        position={Position.Left}
        className={`!border-2 !border-white !w-3 !h-3 ${accentColorClass} transition-all duration-200 ${
          isHovered ? '!w-4 !h-4' : ''
        }`}
      />
      
      <Card
        className={`w-72 cursor-pointer transition-all duration-200 hover:shadow-lg transform ${
          selected ? 'ring-2 ring-primary shadow-xl' : 'shadow-md'
        } ${colorClass} ${dragOpacity} ${dragScale}`}
      >
        <CardHeader className="pb-3 relative">
          {/* Drag handle indicator */}
          <div 
            className={`absolute -left-2 top-1/2 -translate-y-1/2 p-1 rounded bg-gray-500/20 cursor-grab active:cursor-grabbing transition-opacity duration-200 ${
              isHovered || isDragging ? 'opacity-100' : 'opacity-0'
            }`}
          >
            <GripVertical className="h-3 w-3 text-gray-600" />
          </div>
          
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className={`p-1.5 rounded-full ${accentColorClass} transition-transform duration-200 ${
                isDragging ? 'animate-pulse' : ''
              }`}>
                <Icon className="h-4 w-4 text-white" />
              </div>
              <h3 className="font-semibold text-sm">{data.title}</h3>
            </div>
            <div className="flex items-center gap-2">
              <Badge variant="outline" className="text-xs capitalize px-2">
                {data.type}
              </Badge>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button
                    variant="ghost"
                    size="sm"
                    className={`h-6 w-6 p-0 transition-opacity duration-200 ${
                      isHovered || selected ? 'opacity-100' : 'opacity-0'
                    }`}
                  >
                    <MoreVertical className="h-3 w-3" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem onClick={() => setIsExpanded(!isExpanded)}>
                    {isExpanded ? <ChevronUp className="mr-2 h-4 w-4" /> : <ChevronDown className="mr-2 h-4 w-4" />}
                    {isExpanded ? 'Collapse' : 'Expand'}
                  </DropdownMenuItem>
                  <DropdownMenuItem>
                    <Move className="mr-2 h-4 w-4" />
                    Configure
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          </div>
        </CardHeader>
        
        <CardContent className="space-y-3">
          <p className="text-xs text-muted-foreground leading-relaxed">{data.description}</p>
          
          {/* Stage progress indicator */}
          {isDragging && (
            <div className={`w-full h-1 rounded-full bg-gray-200 overflow-hidden`}>
              <div className={`h-full ${accentColorClass} animate-pulse`} style={{ width: '60%' }} />
            </div>
          )}
          
          {data.contentTypes && data.contentTypes.length > 0 && (
            <div className="space-y-2">
              <div className="flex items-center gap-1">
                <div className={`w-2 h-2 rounded-full ${accentColorClass}`} />
                <p className="text-xs font-medium">Content Types</p>
                {isExpanded && (
                  <Badge variant="secondary" className="text-xs ml-auto">
                    {data.contentTypes.length}
                  </Badge>
                )}
              </div>
              <div className="flex flex-wrap gap-1">
                {data.contentTypes.slice(0, isExpanded ? data.contentTypes.length : 3).map((contentType) => (
                  <Badge
                    key={contentType}
                    variant="secondary"
                    className="text-xs px-2 py-0.5 font-normal hover:bg-secondary/80 transition-colors"
                  >
                    {contentType}
                  </Badge>
                ))}
                {!isExpanded && data.contentTypes.length > 3 && (
                  <Badge 
                    variant="secondary" 
                    className="text-xs px-2 py-0.5 font-normal cursor-pointer hover:bg-secondary/80"
                    onClick={(e) => {
                      e.stopPropagation()
                      setIsExpanded(true)
                    }}
                  >
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
                {isExpanded && (
                  <Badge variant="secondary" className="text-xs ml-auto">
                    {data.messagingSuggestions.length}
                  </Badge>
                )}
              </div>
              <div className="space-y-1">
                {data.messagingSuggestions.slice(0, isExpanded ? data.messagingSuggestions.length : 2).map((message, index) => (
                  <p key={index} className="text-xs text-muted-foreground pl-2 border-l-2 border-gray-200 hover:border-l-4 hover:border-l-primary/50 transition-all cursor-pointer">
                    {message}
                  </p>
                ))}
                {!isExpanded && data.messagingSuggestions.length > 2 && (
                  <p 
                    className="text-xs text-muted-foreground/70 pl-2 cursor-pointer hover:text-muted-foreground transition-colors"
                    onClick={(e) => {
                      e.stopPropagation()
                      setIsExpanded(true)
                    }}
                  >
                    +{data.messagingSuggestions.length - 2} more messages...
                  </p>
                )}
              </div>
            </div>
          )}
          
          {/* Enhanced features for expanded mode */}
          {isExpanded && (
            <div className="pt-2 border-t border-gray-200 space-y-2">
              <div className="flex items-center justify-between text-xs">
                <span className="text-muted-foreground flex items-center gap-1">
                  <Clock className="h-3 w-3" />
                  Stage Duration
                </span>
                <Badge variant="outline" className="text-xs">
                  2-4 weeks
                </Badge>
              </div>
              <div className="flex items-center justify-between text-xs">
                <span className="text-muted-foreground">Conversion Rate</span>
                <span className={`font-medium text-${data.type === 'conversion' ? 'green' : 'blue'}-600`}>
                  {data.type === 'conversion' ? '12-15%' : '25-35%'}
                </span>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
      
      <Handle
        type="source"
        position={Position.Right}
        className={`!border-2 !border-white !w-3 !h-3 ${accentColorClass} transition-all duration-200 ${
          isHovered ? '!w-4 !h-4' : ''
        }`}
      />
    </div>
  )
})