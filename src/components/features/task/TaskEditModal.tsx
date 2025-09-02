'use client'

import { useState, useEffect } from 'react'
import { Calendar, Clock, User, AlertTriangle } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Label } from '@/components/ui/label'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'

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
  notes?: string
}

interface TaskEditModalProps {
  task: Task | null
  isOpen: boolean
  onClose: () => void
  onSave: (taskId: string, updates: Partial<Task>) => Promise<void>
  onDelete?: (taskId: string) => Promise<void>
  isNewTask?: boolean
}

const statusOptions = [
  { value: 'pending', label: 'Pending', icon: Clock },
  { value: 'in_progress', label: 'In Progress', icon: AlertTriangle },
  { value: 'completed', label: 'Completed', icon: Calendar },
  { value: 'blocked', label: 'Blocked', icon: AlertTriangle },
]

const priorityOptions = [
  { value: 'low', label: 'Low', color: 'text-gray-600' },
  { value: 'medium', label: 'Medium', color: 'text-blue-600' },
  { value: 'high', label: 'High', color: 'text-orange-600' },
  { value: 'urgent', label: 'Urgent', color: 'text-red-600' },
]

export function TaskEditModal({
  task,
  isOpen,
  onClose,
  onSave,
  onDelete,
  isNewTask = false
}: TaskEditModalProps) {
  const [formData, setFormData] = useState<Partial<Task>>({})
  const [isLoading, setIsLoading] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})

  // Initialize form data when task changes
  useEffect(() => {
    if (task) {
      setFormData({
        name: task.name || '',
        description: task.description || '',
        status: task.status || 'pending',
        priority: task.priority || 'medium',
        assigneeName: task.assigneeName || '',
        dueDate: task.dueDate || '',
        estimatedHours: task.estimatedHours || 0,
        actualHours: task.actualHours || 0,
        notes: task.notes || ''
      })
    } else if (isNewTask) {
      setFormData({
        name: '',
        description: '',
        status: 'pending',
        priority: 'medium',
        assigneeName: '',
        dueDate: '',
        estimatedHours: 0,
        actualHours: 0,
        notes: ''
      })
    }
    setErrors({})
  }, [task, isNewTask])

  const validateForm = (): boolean => {
    const newErrors: Record<string, string> = {}

    if (!formData.name?.trim()) {
      newErrors.name = 'Task name is required'
    }

    if (formData.estimatedHours && formData.estimatedHours < 0) {
      newErrors.estimatedHours = 'Estimated hours must be positive'
    }

    if (formData.actualHours && formData.actualHours < 0) {
      newErrors.actualHours = 'Actual hours must be positive'
    }

    if (formData.dueDate) {
      const dueDate = new Date(formData.dueDate)
      const today = new Date()
      today.setHours(0, 0, 0, 0)
      
      if (dueDate < today) {
        newErrors.dueDate = 'Due date cannot be in the past'
      }
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSave = async () => {
    if (!validateForm()) return

    setIsLoading(true)
    try {
      if (task?.id) {
        await onSave(task.id, formData)
      }
      onClose()
    } catch (error) {
      console.error('Error saving task:', error)
      setErrors({ submit: 'Failed to save task. Please try again.' })
    } finally {
      setIsLoading(false)
    }
  }

  const handleDelete = async () => {
    if (!task?.id || !onDelete) return

    if (window.confirm('Are you sure you want to delete this task? This action cannot be undone.')) {
      setIsLoading(true)
      try {
        await onDelete(task.id)
        onClose()
      } catch (error) {
        console.error('Error deleting task:', error)
        setErrors({ submit: 'Failed to delete task. Please try again.' })
      } finally {
        setIsLoading(false)
      }
    }
  }

  const updateField = (field: keyof Task, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }))
    // Clear error when user starts typing
    if (errors[field]) {
      setErrors(prev => ({ ...prev, [field]: '' }))
    }
  }

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="max-w-4xl w-[90vw] max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>
            {isNewTask ? 'Create New Task' : 'Edit Task'}
          </DialogTitle>
          <DialogDescription>
            {isNewTask 
              ? 'Add a new task to this journey stage' 
              : 'Update task details and track progress'
            }
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-6">
          {/* Task Name */}
          <div className="space-y-2">
            <Label htmlFor="name" className="text-sm font-medium">
              Task Name *
            </Label>
            <Input
              id="name"
              value={formData.name || ''}
              onChange={(e) => updateField('name', e.target.value)}
              placeholder="Enter task name"
              className={errors.name ? 'border-red-500' : ''}
            />
            {errors.name && (
              <p className="text-sm text-red-600">{errors.name}</p>
            )}
          </div>

          {/* Description */}
          <div className="space-y-2">
            <Label htmlFor="description" className="text-sm font-medium">
              Description
            </Label>
            <Textarea
              id="description"
              value={formData.description || ''}
              onChange={(e) => updateField('description', e.target.value)}
              placeholder="Describe the task in detail"
              rows={3}
            />
          </div>

          {/* Status and Priority Row */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            <div className="space-y-2">
              <Label htmlFor="status" className="text-sm font-medium">
                Status
              </Label>
              <Select
                value={formData.status || 'pending'}
                onValueChange={(value) => updateField('status', value as TaskStatus)}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {statusOptions.map((option) => {
                    const Icon = option.icon
                    return (
                      <SelectItem key={option.value} value={option.value}>
                        <div className="flex items-center gap-2">
                          <Icon className="h-4 w-4" />
                          {option.label}
                        </div>
                      </SelectItem>
                    )
                  })}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="priority" className="text-sm font-medium">
                Priority
              </Label>
              <Select
                value={formData.priority || 'medium'}
                onValueChange={(value) => updateField('priority', value as TaskPriority)}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {priorityOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      <span className={option.color}>{option.label}</span>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="estimatedHours" className="text-sm font-medium">
                <Clock className="h-4 w-4 inline mr-1" />
                Est. Hours
              </Label>
              <Input
                id="estimatedHours"
                type="number"
                min="0"
                step="0.5"
                value={formData.estimatedHours || ''}
                onChange={(e) => updateField('estimatedHours', parseFloat(e.target.value) || 0)}
                placeholder="0"
                className={errors.estimatedHours ? 'border-red-500' : ''}
              />
              {errors.estimatedHours && (
                <p className="text-sm text-red-600">{errors.estimatedHours}</p>
              )}
            </div>

            <div className="space-y-2">
              <Label htmlFor="actualHours" className="text-sm font-medium">
                <Clock className="h-4 w-4 inline mr-1" />
                Actual Hours
              </Label>
              <Input
                id="actualHours"
                type="number"
                min="0"
                step="0.5"
                value={formData.actualHours || ''}
                onChange={(e) => updateField('actualHours', parseFloat(e.target.value) || 0)}
                placeholder="0"
                className={errors.actualHours ? 'border-red-500' : ''}
              />
              {errors.actualHours && (
                <p className="text-sm text-red-600">{errors.actualHours}</p>
              )}
            </div>
          </div>

          {/* Assignee and Due Date Row */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <Label htmlFor="assignee" className="text-sm font-medium">
                <User className="h-4 w-4 inline mr-1" />
                Assignee
              </Label>
              <Input
                id="assignee"
                value={formData.assigneeName || ''}
                onChange={(e) => updateField('assigneeName', e.target.value)}
                placeholder="Enter assignee name"
                className="w-full"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="dueDate" className="text-sm font-medium">
                <Calendar className="h-4 w-4 inline mr-1" />
                Due Date
              </Label>
              <Input
                id="dueDate"
                type="date"
                value={formData.dueDate || ''}
                onChange={(e) => updateField('dueDate', e.target.value)}
                className={`w-full ${errors.dueDate ? 'border-red-500' : ''}`}
              />
              {errors.dueDate && (
                <p className="text-sm text-red-600">{errors.dueDate}</p>
              )}
            </div>
          </div>

          {/* Notes */}
          <div className="space-y-2">
            <Label htmlFor="notes" className="text-sm font-medium">
              Notes
            </Label>
            <Textarea
              id="notes"
              value={formData.notes || ''}
              onChange={(e) => updateField('notes', e.target.value)}
              placeholder="Add any additional notes or updates"
              rows={3}
            />
          </div>

          {/* Error Messages */}
          {errors.submit && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-md">
              <p className="text-sm text-red-800">{errors.submit}</p>
            </div>
          )}
        </div>

        <DialogFooter className="flex justify-between">
          <div>
            {!isNewTask && onDelete && (
              <Button 
                variant="destructive" 
                onClick={handleDelete}
                disabled={isLoading}
              >
                Delete Task
              </Button>
            )}
          </div>
          <div className="flex gap-2">
            <Button variant="outline" onClick={onClose} disabled={isLoading}>
              Cancel
            </Button>
            <Button onClick={handleSave} disabled={isLoading}>
              {isLoading ? 'Saving...' : (isNewTask ? 'Create Task' : 'Save Changes')}
            </Button>
          </div>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}