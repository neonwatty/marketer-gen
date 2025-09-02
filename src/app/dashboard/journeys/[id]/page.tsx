'use client'

import { useState, useEffect } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { useSession } from 'next-auth/react'

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import { TaskCard } from '@/components/features/task/TaskCard'
import { TaskEditModal } from '@/components/features/task/TaskEditModal'
import { AddTaskButton } from '@/components/features/task/AddTaskButton'

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

function getStatusColor(status: string) {
  switch (status.toLowerCase()) {
    case 'active': return 'bg-green-100 text-green-800'
    case 'draft': return 'bg-gray-100 text-gray-800'
    case 'completed': return 'bg-blue-100 text-blue-800'
    case 'paused': return 'bg-yellow-100 text-yellow-800'
    case 'cancelled': return 'bg-red-100 text-red-800'
    default: return 'bg-gray-100 text-gray-800'
  }
}

function getTaskStatusColor(status: string) {
  switch (status.toLowerCase()) {
    case 'completed': return 'bg-green-100 text-green-800'
    case 'in_progress': return 'bg-blue-100 text-blue-800'
    case 'pending': return 'bg-gray-100 text-gray-800'
    default: return 'bg-gray-100 text-gray-800'
  }
}

export default function JourneyPage() {
  const params = useParams()
  const router = useRouter()
  const { data: session } = useSession()
  const [journey, setJourney] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [editingTask, setEditingTask] = useState<Task | null>(null)
  const [isEditModalOpen, setIsEditModalOpen] = useState(false)

  const id = params.id as string

  useEffect(() => {
    if (!session) return

    const fetchJourney = async () => {
      try {
        setLoading(true)
        const response = await fetch(`/api/journeys/${id}`)
        
        if (!response.ok) {
          throw new Error('Journey not found')
        }

        const data = await response.json()
        setJourney(data)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load journey')
      } finally {
        setLoading(false)
      }
    }

    fetchJourney()
  }, [id, session])

  const handleTaskUpdate = async (taskId: string, updates: Partial<Task>) => {
    if (!journey) return

    try {
      // Find the stage containing this task
      let stageId = ''
      for (const stage of journey.stages?.stages || []) {
        if (stage.tasks?.some((task: any) => task.id === taskId)) {
          stageId = stage.id
          break
        }
      }

      if (!stageId) {
        console.error('Stage not found for task:', taskId)
        return
      }

      const response = await fetch(`/api/journeys/${id}/tasks/${taskId}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          stageId,
          ...updates
        })
      })

      if (!response.ok) {
        throw new Error('Failed to update task')
      }

      const result = await response.json()
      if (result.success) {
        setJourney((prev: any) => ({
          ...prev,
          stages: result.journeyData
        }))
      }
    } catch (error) {
      console.error('Error updating task:', error)
    }
  }

  const handleTaskEdit = (task: Task) => {
    setEditingTask(task)
    setIsEditModalOpen(true)
  }

  const handleAddTask = async (stageId: string, taskData: Partial<Task>) => {
    try {
      const response = await fetch(`/api/journeys/${id}/tasks`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          stageId,
          ...taskData
        })
      })

      if (!response.ok) {
        throw new Error('Failed to add task')
      }

      const result = await response.json()
      if (result.success) {
        setJourney((prev: any) => ({
          ...prev,
          stages: result.journeyData
        }))
      }
    } catch (error) {
      console.error('Error adding task:', error)
      throw error
    }
  }

  const handleStatusChange = async (taskId: string, status: TaskStatus) => {
    await handleTaskUpdate(taskId, { status })
  }

  const handleTaskDelete = async (taskId: string) => {
    if (!journey) return

    try {
      // Find the stage containing this task
      let stageId = ''
      for (const stage of journey.stages?.stages || []) {
        if (stage.tasks?.some((task: any) => task.id === taskId)) {
          stageId = stage.id
          break
        }
      }

      if (!stageId) {
        console.error('Stage not found for task:', taskId)
        return
      }

      const response = await fetch(`/api/journeys/${id}/tasks/${taskId}?stageId=${stageId}`, {
        method: 'DELETE'
      })

      if (!response.ok) {
        throw new Error('Failed to delete task')
      }

      const result = await response.json()
      if (result.success) {
        setJourney((prev: any) => ({
          ...prev,
          stages: result.journeyData
        }))
      }
    } catch (error) {
      console.error('Error deleting task:', error)
    }
  }

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="flex items-center justify-center py-8">
          <div className="text-muted-foreground">Loading journey...</div>
        </div>
      </div>
    )
  }

  if (error || !journey) {
    return (
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Journey Not Found</h1>
            <p className="text-muted-foreground">
              {error || `The journey with ID ${id} could not be found or you don't have access to it.`}
            </p>
          </div>
        </div>
      </div>
    )
  }

  const stages = journey.stages?.stages || []
  const metadata = journey.stages?.metadata || {}
  const completedTasks = metadata.completedTasks || 0
  const totalTasks = metadata.totalTasks || 0
  const progressPercentage = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">
            Journey: {journey.campaign?.name || 'Unknown Campaign'}
          </h1>
          <p className="text-muted-foreground">
            {journey.campaign?.purpose || 'Customer journey workflow and task management'}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Badge className={getStatusColor(journey.status)}>
            {journey.status?.toUpperCase() || 'UNKNOWN'}
          </Badge>
          <Button variant="outline" asChild>
            <a href={`/dashboard/campaigns/${journey.campaign?.id}`}>
              Back to Campaign
            </a>
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        {/* Journey Overview */}
        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle>Journey Overview</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <p className="text-sm font-medium">Campaign</p>
              <p className="text-sm text-muted-foreground">{journey.campaign?.name || 'N/A'}</p>
            </div>
            <div>
              <p className="text-sm font-medium">Brand</p>
              <p className="text-sm text-muted-foreground">{journey.campaign?.brand?.name || 'N/A'}</p>
            </div>
            <div>
              <p className="text-sm font-medium">Progress</p>
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span>{completedTasks} of {totalTasks} tasks</span>
                  <span>{progressPercentage}%</span>
                </div>
                <Progress value={progressPercentage} className="h-2" />
              </div>
            </div>
            <div>
              <p className="text-sm font-medium">Content Pieces</p>
              <p className="text-sm text-muted-foreground">{journey.content?.length || 0}</p>
            </div>
            <div>
              <p className="text-sm font-medium">Created</p>
              <p className="text-sm text-muted-foreground">
                {journey.createdAt ? new Date(journey.createdAt).toLocaleDateString() : 'N/A'}
              </p>
            </div>
          </CardContent>
        </Card>

        {/* Journey Stages */}
        <Card className="lg:col-span-3">
          <CardHeader>
            <CardTitle>Journey Stages</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-6">
              {stages.map((stage: any, index: number) => (
                <div key={stage.id || index} className="border rounded-lg p-4">
                  <div className="flex items-center justify-between mb-4">
                    <div className="flex items-center gap-3">
                      <div className="flex items-center justify-center w-8 h-8 rounded-full bg-blue-100 text-blue-800 text-sm font-medium">
                        {stage.order || index + 1}
                      </div>
                      <div>
                        <h3 className="font-semibold">{stage.name || `Stage ${index + 1}`}</h3>
                        <p className="text-sm text-muted-foreground">{stage.description || 'No description'}</p>
                      </div>
                    </div>
                    <div className="text-sm text-muted-foreground">
                      {stage.duration ? `${stage.duration} days` : ''}
                    </div>
                  </div>

                  {/* Stage Tasks */}
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <h4 className="text-sm font-medium">Tasks</h4>
                      <AddTaskButton
                        stageId={stage.id}
                        stageName={stage.name}
                        onAddTask={handleAddTask}
                        variant="outline"
                        size="sm"
                      />
                    </div>
                    
                    {stage.tasks && stage.tasks.length > 0 ? (
                      <div className="space-y-2">
                        {stage.tasks.map((task: any) => (
                          <TaskCard
                            key={task.id}
                            task={{
                              id: task.id,
                              name: task.name,
                              description: task.description,
                              status: task.status || 'pending',
                              priority: task.priority || 'medium',
                              assigneeName: task.assigneeName,
                              dueDate: task.dueDate,
                              estimatedHours: task.estimatedHours,
                              actualHours: task.actualHours,
                              completedAt: task.completedAt,
                              notes: task.notes
                            }}
                            onEdit={handleTaskEdit}
                            onDelete={handleTaskDelete}
                            onStatusChange={handleStatusChange}
                          />
                        ))}
                      </div>
                    ) : (
                      <div className="text-center py-6 text-muted-foreground bg-gray-50 rounded-lg border-2 border-dashed">
                        <p className="text-sm">No tasks yet</p>
                        <p className="text-xs">Click "Add Task" to get started</p>
                      </div>
                    )}
                  </div>
                </div>
              ))}

              {stages.length === 0 && (
                <div className="text-center py-8 text-muted-foreground">
                  No stages defined for this journey.
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Content Pieces */}
      {journey.content && journey.content.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Associated Content</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {journey.content.map((content: any) => (
                <div key={content.id} className="border rounded-lg p-4">
                  <div className="flex items-center justify-between mb-2">
                    <Badge variant="outline" className="text-xs">
                      {content.type?.replace('_', ' ') || 'Content'}
                    </Badge>
                    <Badge variant="outline" className={`text-xs ${getStatusColor(content.status)}`}>
                      {content.status || 'unknown'}
                    </Badge>
                  </div>
                  <p className="text-sm text-muted-foreground">
                    Created: {content.createdAt ? new Date(content.createdAt).toLocaleDateString() : 'N/A'}
                  </p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Task Edit Modal */}
      <TaskEditModal
        task={editingTask}
        isOpen={isEditModalOpen}
        onClose={() => {
          setIsEditModalOpen(false)
          setEditingTask(null)
        }}
        onSave={handleTaskUpdate}
        onDelete={handleTaskDelete}
      />
    </div>
  )
}