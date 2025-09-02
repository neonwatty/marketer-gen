'use client'

import { AlertTriangle, Circle, ArrowUp, Zap } from 'lucide-react'

import { Badge } from '@/components/ui/badge'

type TaskPriority = 'low' | 'medium' | 'high' | 'urgent'

interface TaskPriorityIndicatorProps {
  priority: TaskPriority
  showLabel?: boolean
  size?: 'sm' | 'default'
}

const priorityConfig = {
  low: {
    label: 'Low',
    color: 'bg-gray-100 text-gray-600 border-gray-200',
    icon: Circle,
    textColor: 'text-gray-600'
  },
  medium: {
    label: 'Medium', 
    color: 'bg-blue-100 text-blue-700 border-blue-200',
    icon: Circle,
    textColor: 'text-blue-700'
  },
  high: {
    label: 'High',
    color: 'bg-orange-100 text-orange-700 border-orange-200',
    icon: ArrowUp,
    textColor: 'text-orange-700'
  },
  urgent: {
    label: 'Urgent',
    color: 'bg-red-100 text-red-700 border-red-200',
    icon: Zap,
    textColor: 'text-red-700'
  }
}

export function TaskPriorityIndicator({ 
  priority, 
  showLabel = true, 
  size = 'default' 
}: TaskPriorityIndicatorProps) {
  const config = priorityConfig[priority]
  const Icon = config.icon
  
  if (!showLabel) {
    return (
      <div className={`inline-flex items-center ${config.textColor}`} title={`Priority: ${config.label}`}>
        <Icon className={`${size === 'sm' ? 'h-3 w-3' : 'h-4 w-4'}`} />
      </div>
    )
  }
  
  return (
    <Badge 
      variant="outline" 
      className={`${config.color} ${size === 'sm' ? 'text-xs py-0 px-1' : 'text-xs'}`}
    >
      <Icon className={`${size === 'sm' ? 'h-2 w-2' : 'h-3 w-3'} mr-1`} />
      {config.label}
    </Badge>
  )
}

export function TaskPriorityDot({ priority }: { priority: TaskPriority }) {
  const config = priorityConfig[priority]
  
  return (
    <div 
      className={`w-2 h-2 rounded-full ${
        priority === 'low' ? 'bg-gray-400' :
        priority === 'medium' ? 'bg-blue-500' :
        priority === 'high' ? 'bg-orange-500' :
        'bg-red-500'
      }`}
      title={`Priority: ${config.label}`}
    />
  )
}