'use client'

import { useState } from 'react'
import { Plus } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { TaskEditModal } from './TaskEditModal'

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

interface AddTaskButtonProps {
  stageId: string
  stageName: string
  onAddTask: (stageId: string, taskData: Partial<Task>) => Promise<void>
  variant?: 'default' | 'outline' | 'ghost'
  size?: 'sm' | 'default' | 'lg'
  className?: string
}

export function AddTaskButton({ 
  stageId, 
  stageName, 
  onAddTask, 
  variant = 'outline',
  size = 'sm',
  className = ''
}: AddTaskButtonProps) {
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [isLoading, setIsLoading] = useState(false)

  // Create a dummy task for the new task modal
  const newTask: Task = {
    id: 'new',
    name: '',
    description: '',
    status: 'pending',
    priority: 'medium',
    assigneeName: '',
    dueDate: '',
    estimatedHours: 0,
    actualHours: 0,
    notes: ''
  }

  const handleSaveNewTask = async (taskId: string, taskData: Partial<Task>) => {
    setIsLoading(true)
    try {
      await onAddTask(stageId, taskData)
      setIsModalOpen(false)
    } catch (error) {
      console.error('Error creating task:', error)
      throw error // Re-throw so the modal can show the error
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <>
      <Button 
        variant={variant}
        size={size}
        onClick={() => setIsModalOpen(true)}
        className={`flex items-center gap-2 ${className}`}
        disabled={isLoading}
      >
        <Plus className="h-4 w-4" />
        Add Task
      </Button>

      <TaskEditModal
        task={newTask}
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onSave={handleSaveNewTask}
        isNewTask={true}
      />
    </>
  )
}