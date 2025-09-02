'use client'

import { useState } from 'react'
import { ChevronDown, Clock, Play, CheckCircle, AlertCircle } from 'lucide-react'

import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Badge } from '@/components/ui/badge'

type TaskStatus = 'pending' | 'in_progress' | 'completed' | 'blocked'

interface TaskStatusDropdownProps {
  currentStatus: TaskStatus
  onStatusChange: (status: TaskStatus) => Promise<void>
  disabled?: boolean
  size?: 'sm' | 'default'
}

const statusConfig = {
  pending: {
    label: 'Pending',
    color: 'bg-gray-100 text-gray-800',
    icon: Clock
  },
  in_progress: {
    label: 'In Progress',
    color: 'bg-blue-100 text-blue-800',
    icon: Play
  },
  completed: {
    label: 'Completed',
    color: 'bg-green-100 text-green-800',
    icon: CheckCircle
  },
  blocked: {
    label: 'Blocked',
    color: 'bg-red-100 text-red-800',
    icon: AlertCircle
  }
}

export function TaskStatusDropdown({ 
  currentStatus, 
  onStatusChange, 
  disabled = false,
  size = 'default'
}: TaskStatusDropdownProps) {
  const [isLoading, setIsLoading] = useState(false)
  const currentConfig = statusConfig[currentStatus]
  const CurrentIcon = currentConfig.icon

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

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="outline"
          size={size}
          disabled={disabled || isLoading}
          className="h-auto py-1 px-2 justify-between min-w-[100px]"
        >
          <div className="flex items-center gap-1">
            <CurrentIcon className="h-3 w-3" />
            <span className={`text-xs ${size === 'sm' ? 'hidden sm:inline' : ''}`}>
              {currentConfig.label}
            </span>
          </div>
          <ChevronDown className="h-3 w-3 opacity-50" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-[140px]">
        {Object.entries(statusConfig).map(([status, config]) => {
          const Icon = config.icon
          const isActive = status === currentStatus
          
          return (
            <DropdownMenuItem
              key={status}
              onClick={() => handleStatusChange(status as TaskStatus)}
              disabled={isActive}
              className="flex items-center gap-2 cursor-pointer"
            >
              <Icon className="h-3 w-3" />
              <span className="text-xs">{config.label}</span>
              {isActive && (
                <div className="ml-auto w-1 h-1 rounded-full bg-current" />
              )}
            </DropdownMenuItem>
          )
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

export function TaskStatusBadge({ status, size = 'default' }: { 
  status: TaskStatus
  size?: 'sm' | 'default' 
}) {
  const config = statusConfig[status]
  const Icon = config.icon
  
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