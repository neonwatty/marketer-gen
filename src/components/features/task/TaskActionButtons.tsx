'use client'

import { useState } from 'react'
import { Play, CheckCircle, Pause, RotateCcw } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip'

type TaskStatus = 'pending' | 'in_progress' | 'completed' | 'blocked'

interface TaskActionButtonsProps {
  currentStatus: TaskStatus
  onStatusChange: (status: TaskStatus) => Promise<void>
  disabled?: boolean
  compact?: boolean
}

export function TaskActionButtons({ 
  currentStatus, 
  onStatusChange, 
  disabled = false,
  compact = false 
}: TaskActionButtonsProps) {
  const [isLoading, setIsLoading] = useState(false)

  const handleStatusChange = async (newStatus: TaskStatus) => {
    if (newStatus === currentStatus || isLoading) return
    
    setIsLoading(true)
    try {
      await onStatusChange(newStatus)
    } catch (error) {
      console.error('Failed to update task status:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const getAvailableActions = () => {
    const actions = []

    switch (currentStatus) {
      case 'pending':
        actions.push({
          status: 'in_progress' as TaskStatus,
          label: 'Start Task',
          icon: Play,
          variant: 'default' as const,
          tooltip: 'Mark this task as in progress'
        })
        break

      case 'in_progress':
        actions.push(
          {
            status: 'completed' as TaskStatus,
            label: 'Complete',
            icon: CheckCircle,
            variant: 'default' as const,
            tooltip: 'Mark this task as completed'
          },
          {
            status: 'pending' as TaskStatus,
            label: 'Pause',
            icon: Pause,
            variant: 'outline' as const,
            tooltip: 'Pause this task'
          }
        )
        break

      case 'completed':
        actions.push({
          status: 'in_progress' as TaskStatus,
          label: 'Reopen',
          icon: RotateCcw,
          variant: 'outline' as const,
          tooltip: 'Reopen this completed task'
        })
        break

      case 'blocked':
        actions.push({
          status: 'pending' as TaskStatus,
          label: 'Unblock',
          icon: RotateCcw,
          variant: 'default' as const,
          tooltip: 'Unblock this task'
        })
        break
    }

    return actions
  }

  const actions = getAvailableActions()

  if (actions.length === 0) return null

  return (
    <TooltipProvider>
      <div className={`flex gap-1 ${compact ? 'flex-col' : ''}`}>
        {actions.map((action) => {
          const Icon = action.icon
          
          return (
            <Tooltip key={action.status}>
              <TooltipTrigger asChild>
                <Button
                  variant={action.variant}
                  size={compact ? 'sm' : 'sm'}
                  disabled={disabled || isLoading}
                  onClick={() => handleStatusChange(action.status)}
                  className={compact ? 'w-8 h-8 p-0' : 'px-3'}
                >
                  <Icon className="h-3 w-3" />
                  {!compact && (
                    <span className="ml-1 text-xs">{action.label}</span>
                  )}
                </Button>
              </TooltipTrigger>
              <TooltipContent>
                <p className="text-xs">{action.tooltip}</p>
              </TooltipContent>
            </Tooltip>
          )
        })}
      </div>
    </TooltipProvider>
  )
}