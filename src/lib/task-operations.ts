import { prisma } from './db'

export interface Task {
  id: string
  name: string
  description?: string
  status: 'pending' | 'in_progress' | 'completed' | 'blocked'
  priority: 'low' | 'medium' | 'high' | 'urgent'
  assigneeId?: string
  assigneeName?: string
  createdBy?: string
  createdAt: string
  updatedAt: string
  dueDate?: string
  estimatedHours?: number
  actualHours?: number
  tags?: string[]
  dependencies?: string[]
  completedAt?: string
  notes?: string
}

export interface JourneyStage {
  id: string
  name: string
  description?: string
  order: number
  duration?: number
  tasks: Task[]
}

export interface JourneyData {
  stages: JourneyStage[]
  metadata: {
    totalTasks: number
    completedTasks: number
    inProgressTasks: number
    pendingTasks: number
    blockedTasks: number
    lastUpdated: string
  }
}

export async function updateTaskStatus(
  journeyId: string,
  stageId: string,
  taskId: string,
  status: Task['status'],
  userId?: string
): Promise<{ success: boolean; journeyData?: JourneyData; error?: string }> {
  try {
    const journey = await prisma.journey.findUnique({
      where: { id: journeyId },
      select: { stages: true }
    })

    if (!journey) {
      return { success: false, error: 'Journey not found' }
    }

    const journeyData = journey.stages as JourneyData
    const stage = journeyData.stages.find(s => s.id === stageId)
    
    if (!stage) {
      return { success: false, error: 'Stage not found' }
    }

    const task = stage.tasks.find(t => t.id === taskId)
    
    if (!task) {
      return { success: false, error: 'Task not found' }
    }

    // Update task status
    const now = new Date().toISOString()
    task.status = status
    task.updatedAt = now
    
    if (status === 'completed' && !task.completedAt) {
      task.completedAt = now
    } else if (status !== 'completed') {
      task.completedAt = undefined
    }

    // Recalculate metadata
    const updatedJourneyData = calculateJourneyProgress(journeyData)

    // Save to database
    await prisma.journey.update({
      where: { id: journeyId },
      data: { 
        stages: updatedJourneyData,
        updatedBy: userId
      }
    })

    return { success: true, journeyData: updatedJourneyData }
  } catch (error) {
    console.error('Error updating task status:', error)
    return { success: false, error: 'Failed to update task status' }
  }
}

export async function assignTask(
  journeyId: string,
  stageId: string,
  taskId: string,
  assigneeId: string,
  assigneeName: string,
  userId?: string
): Promise<{ success: boolean; journeyData?: JourneyData; error?: string }> {
  try {
    const journey = await prisma.journey.findUnique({
      where: { id: journeyId },
      select: { stages: true }
    })

    if (!journey) {
      return { success: false, error: 'Journey not found' }
    }

    const journeyData = journey.stages as JourneyData
    const stage = journeyData.stages.find(s => s.id === stageId)
    const task = stage?.tasks.find(t => t.id === taskId)
    
    if (!task) {
      return { success: false, error: 'Task not found' }
    }

    // Update task assignment
    task.assigneeId = assigneeId
    task.assigneeName = assigneeName
    task.updatedAt = new Date().toISOString()

    // Save to database
    await prisma.journey.update({
      where: { id: journeyId },
      data: { 
        stages: journeyData,
        updatedBy: userId
      }
    })

    return { success: true, journeyData }
  } catch (error) {
    console.error('Error assigning task:', error)
    return { success: false, error: 'Failed to assign task' }
  }
}

export async function updateTaskDetails(
  journeyId: string,
  stageId: string,
  taskId: string,
  updates: Partial<Task>,
  userId?: string
): Promise<{ success: boolean; journeyData?: JourneyData; error?: string }> {
  try {
    const journey = await prisma.journey.findUnique({
      where: { id: journeyId },
      select: { stages: true }
    })

    if (!journey) {
      return { success: false, error: 'Journey not found' }
    }

    const journeyData = journey.stages as JourneyData
    const stage = journeyData.stages.find(s => s.id === stageId)
    const task = stage?.tasks.find(t => t.id === taskId)
    
    if (!task) {
      return { success: false, error: 'Task not found' }
    }

    // Update task with provided fields
    Object.assign(task, {
      ...updates,
      id: task.id, // Preserve ID
      updatedAt: new Date().toISOString()
    })

    // Recalculate metadata if status changed
    const updatedJourneyData = updates.status ? calculateJourneyProgress(journeyData) : journeyData

    // Save to database
    await prisma.journey.update({
      where: { id: journeyId },
      data: { 
        stages: updatedJourneyData,
        updatedBy: userId
      }
    })

    return { success: true, journeyData: updatedJourneyData }
  } catch (error) {
    console.error('Error updating task details:', error)
    return { success: false, error: 'Failed to update task details' }
  }
}

export async function addTask(
  journeyId: string,
  stageId: string,
  taskData: Omit<Task, 'id' | 'createdAt' | 'updatedAt'>,
  userId?: string
): Promise<{ success: boolean; journeyData?: JourneyData; task?: Task; error?: string }> {
  try {
    const journey = await prisma.journey.findUnique({
      where: { id: journeyId },
      select: { stages: true }
    })

    if (!journey) {
      return { success: false, error: 'Journey not found' }
    }

    const journeyData = journey.stages as JourneyData
    const stage = journeyData.stages.find(s => s.id === stageId)
    
    if (!stage) {
      return { success: false, error: 'Stage not found' }
    }

    // Create new task
    const now = new Date().toISOString()
    const newTask: Task = {
      id: `task-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      createdAt: now,
      updatedAt: now,
      status: 'pending',
      priority: 'medium',
      ...taskData
    }

    // Add task to stage
    stage.tasks.push(newTask)

    // Recalculate metadata
    const updatedJourneyData = calculateJourneyProgress(journeyData)

    // Save to database
    await prisma.journey.update({
      where: { id: journeyId },
      data: { 
        stages: updatedJourneyData,
        updatedBy: userId
      }
    })

    return { success: true, journeyData: updatedJourneyData, task: newTask }
  } catch (error) {
    console.error('Error adding task:', error)
    return { success: false, error: 'Failed to add task' }
  }
}

export async function deleteTask(
  journeyId: string,
  stageId: string,
  taskId: string,
  userId?: string
): Promise<{ success: boolean; journeyData?: JourneyData; error?: string }> {
  try {
    const journey = await prisma.journey.findUnique({
      where: { id: journeyId },
      select: { stages: true }
    })

    if (!journey) {
      return { success: false, error: 'Journey not found' }
    }

    const journeyData = journey.stages as JourneyData
    const stage = journeyData.stages.find(s => s.id === stageId)
    
    if (!stage) {
      return { success: false, error: 'Stage not found' }
    }

    // Remove task from stage
    const taskIndex = stage.tasks.findIndex(t => t.id === taskId)
    if (taskIndex === -1) {
      return { success: false, error: 'Task not found' }
    }

    stage.tasks.splice(taskIndex, 1)

    // Recalculate metadata
    const updatedJourneyData = calculateJourneyProgress(journeyData)

    // Save to database
    await prisma.journey.update({
      where: { id: journeyId },
      data: { 
        stages: updatedJourneyData,
        updatedBy: userId
      }
    })

    return { success: true, journeyData: updatedJourneyData }
  } catch (error) {
    console.error('Error deleting task:', error)
    return { success: false, error: 'Failed to delete task' }
  }
}

export function calculateJourneyProgress(journeyData: JourneyData): JourneyData {
  let totalTasks = 0
  let completedTasks = 0
  let inProgressTasks = 0
  let pendingTasks = 0
  let blockedTasks = 0

  journeyData.stages.forEach(stage => {
    stage.tasks.forEach(task => {
      totalTasks++
      switch (task.status) {
        case 'completed':
          completedTasks++
          break
        case 'in_progress':
          inProgressTasks++
          break
        case 'pending':
          pendingTasks++
          break
        case 'blocked':
          blockedTasks++
          break
      }
    })
  })

  return {
    ...journeyData,
    metadata: {
      ...journeyData.metadata,
      totalTasks,
      completedTasks,
      inProgressTasks,
      pendingTasks,
      blockedTasks,
      lastUpdated: new Date().toISOString()
    }
  }
}

export function validateTaskDependencies(journeyData: JourneyData, taskId: string): boolean {
  // Find all tasks across stages
  const allTasks = journeyData.stages.flatMap(stage => stage.tasks)
  const task = allTasks.find(t => t.id === taskId)
  
  if (!task || !task.dependencies || task.dependencies.length === 0) {
    return true
  }

  // Check if all dependencies are completed
  return task.dependencies.every(depId => {
    const depTask = allTasks.find(t => t.id === depId)
    return depTask?.status === 'completed'
  })
}

export async function bulkUpdateTasks(
  journeyId: string,
  updates: Array<{
    stageId: string
    taskId: string
    updates: Partial<Task>
  }>,
  userId?: string
): Promise<{ success: boolean; journeyData?: JourneyData; error?: string }> {
  try {
    const journey = await prisma.journey.findUnique({
      where: { id: journeyId },
      select: { stages: true }
    })

    if (!journey) {
      return { success: false, error: 'Journey not found' }
    }

    let journeyData = journey.stages as JourneyData
    const now = new Date().toISOString()

    // Apply all updates
    updates.forEach(({ stageId, taskId, updates: taskUpdates }) => {
      const stage = journeyData.stages.find(s => s.id === stageId)
      const task = stage?.tasks.find(t => t.id === taskId)
      
      if (task) {
        Object.assign(task, {
          ...taskUpdates,
          id: task.id, // Preserve ID
          updatedAt: now
        })

        // Handle completion timestamp
        if (taskUpdates.status === 'completed' && !task.completedAt) {
          task.completedAt = now
        } else if (taskUpdates.status && taskUpdates.status !== 'completed') {
          task.completedAt = undefined
        }
      }
    })

    // Recalculate metadata
    journeyData = calculateJourneyProgress(journeyData)

    // Save to database
    await prisma.journey.update({
      where: { id: journeyId },
      data: { 
        stages: journeyData,
        updatedBy: userId
      }
    })

    return { success: true, journeyData }
  } catch (error) {
    console.error('Error bulk updating tasks:', error)
    return { success: false, error: 'Failed to bulk update tasks' }
  }
}