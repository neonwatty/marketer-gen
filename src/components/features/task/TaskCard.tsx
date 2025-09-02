'use client'

import { useState } from 'react'
import { Calendar, Clock, User, MoreVertical, Edit, Trash, Play, CheckCircle, Pause, AlertTriangle } from 'lucide-react'

import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

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
  notes?: string
}

interface TaskCardProps {
  task: Task
  onEdit: (task: Task) => void
  onDelete: (taskId: string) => void
  onStatusChange: (taskId: string, status: TaskStatus) => void
}

const statusConfig = {
  pending: {
    label: 'Pending',
    color: 'bg-gray-100 text-gray-800 border-gray-200',
    icon: Clock,
    bgColor: 'bg-gray-50'
  },
  in_progress: {
    label: 'In Progress',
    color: 'bg-blue-100 text-blue-800 border-blue-200',
    icon: Play,
    bgColor: 'bg-blue-50'
  },
  completed: {
    label: 'Completed',
    color: 'bg-green-100 text-green-800 border-green-200',
    icon: CheckCircle,
    bgColor: 'bg-green-50'
  },
  blocked: {
    label: 'Blocked',
    color: 'bg-red-100 text-red-800 border-red-200',
    icon: AlertTriangle,
    bgColor: 'bg-red-50'
  }
}

const priorityConfig = {
  low: { color: 'border-l-gray-400', dot: 'bg-gray-400' },
  medium: { color: 'border-l-blue-500', dot: 'bg-blue-500' },
  high: { color: 'border-l-orange-500', dot: 'bg-orange-500' },
  urgent: { color: 'border-l-red-600', dot: 'bg-red-600' }
}

export function TaskCard({ task, onEdit, onDelete, onStatusChange }: TaskCardProps) {
  const [isLoading, setIsLoading] = useState(false)
  
  const statusInfo = statusConfig[task.status]
  const priorityInfo = priorityConfig[task.priority]
  const Icon = statusInfo.icon

  const formatDueDate = (dateString: string) => {
    const date = new Date(dateString)
    const now = new Date()
    const diffDays = Math.ceil((date.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))
    
    if (diffDays < 0) return { text: `${Math.abs(diffDays)} days overdue`, className: 'text-red-600' }
    if (diffDays === 0) return { text: 'Due today', className: 'text-orange-600' }
    if (diffDays === 1) return { text: 'Due tomorrow', className: 'text-orange-500' }
    if (diffDays <= 7) return { text: `Due in ${diffDays} days`, className: 'text-yellow-600' }
    return { text: `Due in ${diffDays} days`, className: 'text-muted-foreground' }
  }

  const handleStatusChange = async (newStatus: TaskStatus) => {
    if (newStatus === task.status) return
    
    setIsLoading(true)
    try {
      await onStatusChange(task.id, newStatus)
    } finally {
      setIsLoading(false)
    }
  }

  const getNextStatusAction = () => {
    switch (task.status) {
      case 'pending':
        return { status: 'in_progress' as TaskStatus, label: 'Start', icon: Play, color: 'bg-blue-600 hover:bg-blue-700' }
      case 'in_progress':
        return { status: 'completed' as TaskStatus, label: 'Complete', icon: CheckCircle, color: 'bg-green-600 hover:bg-green-700' }
      case 'completed':
        return { status: 'pending' as TaskStatus, label: 'Reopen', icon: Pause, color: 'bg-gray-600 hover:bg-gray-700' }
      case 'blocked':
        return { status: 'pending' as TaskStatus, label: 'Unblock', icon: Play, color: 'bg-blue-600 hover:bg-blue-700' }
      default:
        return null
    }
  }

  const nextAction = getNextStatusAction()
  const ActionIcon = nextAction?.icon
  const dueInfo = task.dueDate ? formatDueDate(task.dueDate) : null

  return (
    <Card className={`transition-all duration-200 hover:shadow-md border-l-4 ${priorityInfo.color} ${
      task.status === 'completed' ? 'opacity-75' : ''
    }`}>
      <CardContent className="p-4">
        <div className="flex items-start justify-between gap-3">
          <div className="flex-1 min-w-0">
            {/* Task Header */}
            <div className="flex items-start gap-2 mb-2">
              <div className={`w-2 h-2 rounded-full ${priorityInfo.dot} mt-2 flex-shrink-0`} />
              <div className="flex-1">
                <h4 className={`font-medium text-sm leading-5 ${
                  task.status === 'completed' ? 'line-through text-muted-foreground' : ''
                }`}>
                  {task.name}
                </h4>
                {task.description && (
                  <p className="text-xs text-muted-foreground mt-1 line-clamp-2">
                    {task.description}
                  </p>
                )}
              </div>
            </div>

            {/* Task Status and Metadata */}
            <div className="flex flex-wrap items-center gap-2 mb-3">
              <Badge variant="outline" className={`text-xs ${statusInfo.color}`}>
                <Icon className="w-3 h-3 mr-1" />
                {statusInfo.label}
              </Badge>
              
              <Badge variant="outline" className="text-xs capitalize">
                {task.priority}
              </Badge>
            </div>

            {/* Task Details */}
            <div className="space-y-1">
              {task.assigneeName && (
                <div className="flex items-center gap-1 text-xs text-muted-foreground">
                  <User className="w-3 h-3" />
                  <span>{task.assigneeName}</span>
                </div>
              )}
              
              {dueInfo && (
                <div className={`flex items-center gap-1 text-xs ${dueInfo.className}`}>
                  <Calendar className="w-3 h-3" />
                  <span>{dueInfo.text}</span>
                </div>
              )}
              
              {task.estimatedHours && (
                <div className="flex items-center gap-1 text-xs text-muted-foreground">
                  <Clock className="w-3 h-3" />
                  <span>
                    {task.actualHours 
                      ? `${task.actualHours}/${task.estimatedHours}h`
                      : `${task.estimatedHours}h est.`
                    }
                  </span>
                </div>
              )}
            </div>

            {/* Completion Date */}
            {task.completedAt && task.status === 'completed' && (
              <div className="mt-2 text-xs text-green-600">
                Completed on {new Date(task.completedAt).toLocaleDateString()}
              </div>
            )}
          </div>

          {/* Action Buttons */}
          <div className="flex items-center gap-1 flex-shrink-0">
            {/* Quick Action Button */}
            {nextAction && (
              <Button
                size="sm"
                className={`h-8 text-xs ${nextAction.color} text-white`}
                onClick={() => handleStatusChange(nextAction.status)}
                disabled={isLoading}
              >
                {ActionIcon && <ActionIcon className="w-3 h-3 mr-1" />}
                {nextAction.label}
              </Button>
            )}

            {/* More Actions Menu */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="sm" className="h-8 w-8 p-0">
                  <MoreVertical className="h-3 w-3" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-48">
                <DropdownMenuItem onClick={() => onEdit(task)}>
                  <Edit className="h-4 w-4 mr-2" />
                  Edit Task
                </DropdownMenuItem>
                
                <DropdownMenuSeparator />
                
                {/* Status Change Options */}
                {task.status !== 'pending' && (
                  <DropdownMenuItem onClick={() => handleStatusChange('pending')}>
                    <Clock className="h-4 w-4 mr-2" />
                    Mark as Pending
                  </DropdownMenuItem>
                )}
                
                {task.status !== 'in_progress' && (
                  <DropdownMenuItem onClick={() => handleStatusChange('in_progress')}>
                    <Play className="h-4 w-4 mr-2" />
                    Mark as In Progress
                  </DropdownMenuItem>
                )}
                
                {task.status !== 'completed' && (
                  <DropdownMenuItem onClick={() => handleStatusChange('completed')}>
                    <CheckCircle className="h-4 w-4 mr-2" />
                    Mark as Completed
                  </DropdownMenuItem>
                )}
                
                {task.status !== 'blocked' && (
                  <DropdownMenuItem onClick={() => handleStatusChange('blocked')}>
                    <AlertTriangle className="h-4 w-4 mr-2" />
                    Mark as Blocked
                  </DropdownMenuItem>
                )}

                <DropdownMenuSeparator />
                
                <DropdownMenuItem 
                  onClick={() => onDelete(task.id)}
                  className="text-red-600 focus:text-red-600"
                >
                  <Trash className="h-4 w-4 mr-2" />
                  Delete Task
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}