'use client'

import { useState } from 'react'
import { Calendar, Clock, User, MoreVertical, Edit, Trash } from 'lucide-react'

import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { TaskStatusDropdown } from './TaskStatusDropdown'
import { TaskActionButtons } from './TaskActionButtons'
import { TaskPriorityIndicator } from './TaskPriorityIndicator'

type TaskStatus = 'pending' | 'in_progress' | 'completed' | 'blocked'
type TaskPriority = 'low' | 'medium' | 'high' | 'urgent'

interface Task {
  id: string
  name: string
  description?: string
  status: TaskStatus
  priority: TaskPriority
  assigneeName?: string
  dueDate?: string
  estimatedHours?: number
  actualHours?: number
  completedAt?: string
}

interface InteractiveTaskCardProps {
  task: Task
  stageId: string
  journeyId: string
  onTaskUpdate: (taskId: string, updates: Partial<Task>) => Promise<void>
  onTaskDelete?: (taskId: string) => Promise<void>
  onTaskEdit?: (task: Task) => void
  compact?: boolean
}

export function InteractiveTaskCard({
  task,
  stageId,
  journeyId,
  onTaskUpdate,
  onTaskDelete,
  onTaskEdit,
  compact = false
}: InteractiveTaskCardProps) {
  const [isLoading, setIsLoading] = useState(false)

  const handleStatusChange = async (newStatus: TaskStatus) => {
    setIsLoading(true)
    try {
      await onTaskUpdate(task.id, { status: newStatus })
    } finally {
      setIsLoading(false)
    }
  }

  const handleDelete = async () => {
    if (onTaskDelete) {
      setIsLoading(true)
      try {
        await onTaskDelete(task.id)
      } finally {
        setIsLoading(false)
      }
    }
  }

  const formatDueDate = (dateString: string) => {
    const date = new Date(dateString)
    const now = new Date()
    const diffDays = Math.ceil((date.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))
    
    if (diffDays < 0) return { text: `${Math.abs(diffDays)} days overdue`, className: 'text-red-600' }
    if (diffDays === 0) return { text: 'Due today', className: 'text-orange-600' }
    if (diffDays === 1) return { text: 'Due tomorrow', className: 'text-orange-500' }
    return { text: `Due in ${diffDays} days`, className: 'text-muted-foreground' }
  }

  const dueInfo = task.dueDate ? formatDueDate(task.dueDate) : null

  return (
    <Card className={`${compact ? 'border-l-4' : ''} ${
      task.status === 'completed' ? 'border-l-green-500 bg-green-50/30' :
      task.status === 'in_progress' ? 'border-l-blue-500 bg-blue-50/30' :
      task.status === 'blocked' ? 'border-l-red-500 bg-red-50/30' :
      'border-l-gray-300'
    }`}>
      <CardContent className={`${compact ? 'p-3' : 'p-4'}`}>
        <div className="flex items-start justify-between gap-3">
          <div className="flex-1 min-w-0">
            <div className="flex items-start gap-2 mb-2">
              <div className="flex-1">
                <h4 className={`font-medium ${compact ? 'text-sm' : ''} ${
                  task.status === 'completed' ? 'line-through text-muted-foreground' : ''
                }`}>
                  {task.name}
                </h4>
                {task.description && (
                  <p className={`text-muted-foreground mt-1 ${compact ? 'text-xs' : 'text-sm'}`}>
                    {task.description}
                  </p>
                )}
              </div>
              <TaskPriorityIndicator 
                priority={task.priority} 
                showLabel={false} 
                size={compact ? 'sm' : 'default'} 
              />
            </div>

            {/* Task metadata */}
            <div className={`flex flex-wrap gap-3 ${compact ? 'text-xs' : 'text-sm'} text-muted-foreground`}>
              {task.assigneeName && (
                <div className="flex items-center gap-1">
                  <User className="h-3 w-3" />
                  <span>{task.assigneeName}</span>
                </div>
              )}
              {dueInfo && (
                <div className={`flex items-center gap-1 ${dueInfo.className}`}>
                  <Calendar className="h-3 w-3" />
                  <span>{dueInfo.text}</span>
                </div>
              )}
              {task.estimatedHours && (
                <div className="flex items-center gap-1">
                  <Clock className="h-3 w-3" />
                  <span>
                    {task.actualHours 
                      ? `${task.actualHours}/${task.estimatedHours}h`
                      : `${task.estimatedHours}h est.`
                    }
                  </span>
                </div>
              )}
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center gap-2">
            {compact ? (
              <TaskStatusDropdown
                currentStatus={task.status}
                onStatusChange={handleStatusChange}
                disabled={isLoading}
                size="sm"
              />
            ) : (
              <TaskActionButtons
                currentStatus={task.status}
                onStatusChange={handleStatusChange}
                disabled={isLoading}
                compact={compact}
              />
            )}

            {(onTaskEdit || onTaskDelete) && (
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="ghost" size="sm" className="h-8 w-8 p-0">
                    <MoreVertical className="h-3 w-3" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  {onTaskEdit && (
                    <DropdownMenuItem onClick={() => onTaskEdit(task)}>
                      <Edit className="h-3 w-3 mr-2" />
                      Edit Task
                    </DropdownMenuItem>
                  )}
                  {onTaskDelete && (
                    <DropdownMenuItem 
                      onClick={handleDelete}
                      className="text-red-600 focus:text-red-600"
                    >
                      <Trash className="h-3 w-3 mr-2" />
                      Delete Task
                    </DropdownMenuItem>
                  )}
                </DropdownMenuContent>
              </DropdownMenu>
            )}
          </div>
        </div>

        {task.completedAt && task.status === 'completed' && (
          <div className="mt-2 text-xs text-green-600">
            Completed on {new Date(task.completedAt).toLocaleDateString()}
          </div>
        )}
      </CardContent>
    </Card>
  )
}