'use client'

import { Eye, Plus, Target, TrendingUp, Users } from 'lucide-react'

import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

import type { JourneyStage } from './JourneyBuilder'

interface JourneyToolbarProps {
  onAddStage: (stageType: JourneyStage['type']) => void
}

const stageOptions = [
  {
    type: 'awareness' as const,
    label: 'Awareness',
    icon: Eye,
    description: 'Build brand awareness',
  },
  {
    type: 'consideration' as const,
    label: 'Consideration', 
    icon: TrendingUp,
    description: 'Educate prospects',
  },
  {
    type: 'conversion' as const,
    label: 'Conversion',
    icon: Target,
    description: 'Convert to customers',
  },
  {
    type: 'retention' as const,
    label: 'Retention',
    icon: Users,
    description: 'Keep customers engaged',
  },
]

export function JourneyToolbar({ onAddStage }: JourneyToolbarProps) {
  return (
    <div className="absolute top-4 left-4 z-10 flex gap-2">
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button size="sm" className="shadow-lg">
            <Plus className="h-4 w-4 mr-2" />
            Add Stage
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start" className="w-64">
          {stageOptions.map((option) => {
            const Icon = option.icon
            return (
              <DropdownMenuItem
                key={option.type}
                onClick={() => onAddStage(option.type)}
                className="flex items-start gap-3 p-3"
              >
                <Icon className="h-5 w-5 mt-0.5 text-muted-foreground" />
                <div>
                  <div className="font-medium">{option.label}</div>
                  <div className="text-sm text-muted-foreground">
                    {option.description}
                  </div>
                </div>
              </DropdownMenuItem>
            )
          })}
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  )
}