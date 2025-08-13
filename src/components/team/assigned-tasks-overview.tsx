'use client'

import React, { useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Progress } from '@/components/ui/progress'
import { Separator } from '@/components/ui/separator'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import {
  CheckCircle,
  Clock,
  Calendar,
  User,
  MoreHorizontal,
  Search,
  Filter,
  Grid3X3,
  List,
  Kanban,
  Plus,
  AlertTriangle,
  Target,
  Flag,
  ExternalLink,
  MessageSquare,
  Paperclip,
  PlayCircle,
  PauseCircle,
  CheckCircle2
} from 'lucide-react'
import { formatDistanceToNow, format } from 'date-fns'

interface Task {
  id: string
  title: string
  description: string
  assignee: string
  assigneeAvatar?: string
  assignedBy: string
  assignedAt: Date
  dueDate?: Date
  priority: 'low' | 'medium' | 'high' | 'urgent'
  status: 'not_started' | 'in_progress' | 'review' | 'completed' | 'blocked'
  progress: number
  category: string
  tags: string[]
  estimatedHours: number
  actualHours?: number
  attachments: number
  comments: number
  dependencies: string[]
  subtasks: {
    id: string
    title: string
    completed: boolean
  }[]
}

const mockTasks: Task[] = [
  {
    id: '1',
    title: 'Design Summer Campaign Landing Page',
    description: 'Create responsive landing page design for the summer product launch campaign',
    assignee: 'Mike Johnson',
    assignedBy: 'Lisa Brown',
    assignedAt: new Date('2024-01-15T09:00:00Z'),
    dueDate: new Date('2024-01-20T17:00:00Z'),
    priority: 'high',
    status: 'in_progress',
    progress: 65,
    category: 'Design',
    tags: ['landing-page', 'summer', 'responsive'],
    estimatedHours: 16,
    actualHours: 10,
    attachments: 3,
    comments: 7,
    dependencies: [],
    subtasks: [
      { id: '1-1', title: 'Wireframe creation', completed: true },
      { id: '1-2', title: 'Visual design', completed: true },
      { id: '1-3', title: 'Mobile optimization', completed: false },
      { id: '1-4', title: 'Review and adjustments', completed: false }
    ]
  },
  {
    id: '2',
    title: 'Write Email Campaign Copy',
    description: 'Create compelling email copy for the Q1 newsletter campaign',
    assignee: 'David Lee',
    assignedBy: 'Sarah Wilson',
    assignedAt: new Date('2024-01-14T14:30:00Z'),
    dueDate: new Date('2024-01-18T12:00:00Z'),
    priority: 'medium',
    status: 'review',
    progress: 90,
    category: 'Content',
    tags: ['email', 'copy', 'newsletter'],
    estimatedHours: 8,
    actualHours: 7,
    attachments: 2,
    comments: 4,
    dependencies: ['3'],
    subtasks: [
      { id: '2-1', title: 'Subject line variations', completed: true },
      { id: '2-2', title: 'Main body copy', completed: true },
      { id: '2-3', title: 'CTA optimization', completed: true },
      { id: '2-4', title: 'Final review', completed: false }
    ]
  },
  {
    id: '3',
    title: 'Social Media Content Calendar',
    description: 'Plan and create content calendar for February social media posts',
    assignee: 'Sarah Wilson',
    assignedBy: 'John Doe',
    assignedAt: new Date('2024-01-13T11:15:00Z'),
    dueDate: new Date('2024-01-25T16:00:00Z'),
    priority: 'medium',
    status: 'not_started',
    progress: 0,
    category: 'Social Media',
    tags: ['social-media', 'content-calendar', 'february'],
    estimatedHours: 12,
    attachments: 0,
    comments: 2,
    dependencies: [],
    subtasks: [
      { id: '3-1', title: 'Content themes research', completed: false },
      { id: '3-2', title: 'Post creation', completed: false },
      { id: '3-3', title: 'Schedule optimization', completed: false }
    ]
  },
  {
    id: '4',
    title: 'Video Production Planning',
    description: 'Plan and coordinate the product demo video production',
    assignee: 'John Doe',
    assignedBy: 'Lisa Brown',
    assignedAt: new Date('2024-01-12T16:45:00Z'),
    dueDate: new Date('2024-01-22T10:00:00Z'),
    priority: 'urgent',
    status: 'blocked',
    progress: 25,
    category: 'Video',
    tags: ['video', 'product-demo', 'production'],
    estimatedHours: 20,
    actualHours: 5,
    attachments: 1,
    comments: 8,
    dependencies: ['1'],
    subtasks: [
      { id: '4-1', title: 'Script writing', completed: true },
      { id: '4-2', title: 'Storyboard creation', completed: false },
      { id: '4-3', title: 'Equipment booking', completed: false },
      { id: '4-4', title: 'Location scouting', completed: false }
    ]
  },
  {
    id: '5',
    title: 'Market Research Analysis',
    description: 'Analyze competitor strategies and market trends for Q1 planning',
    assignee: 'Lisa Brown',
    assignedBy: 'John Doe',
    assignedAt: new Date('2024-01-11T13:20:00Z'),
    dueDate: new Date('2024-01-19T15:00:00Z'),
    priority: 'high',
    status: 'completed',
    progress: 100,
    category: 'Research',
    tags: ['market-research', 'analysis', 'q1'],
    estimatedHours: 14,
    actualHours: 16,
    attachments: 5,
    comments: 12,
    dependencies: [],
    subtasks: [
      { id: '5-1', title: 'Competitor analysis', completed: true },
      { id: '5-2', title: 'Market trends research', completed: true },
      { id: '5-3', title: 'Report compilation', completed: true },
      { id: '5-4', title: 'Presentation preparation', completed: true }
    ]
  }
]

const getStatusColor = (status: string) => {
  switch (status) {
    case 'not_started':
      return 'bg-gray-100 text-gray-800'
    case 'in_progress':
      return 'bg-blue-100 text-blue-800'
    case 'review':
      return 'bg-purple-100 text-purple-800'
    case 'completed':
      return 'bg-green-100 text-green-800'
    case 'blocked':
      return 'bg-red-100 text-red-800'
    default:
      return 'bg-gray-100 text-gray-800'
  }
}

const getPriorityColor = (priority: string) => {
  switch (priority) {
    case 'urgent':
      return 'destructive'
    case 'high':
      return 'default'
    case 'medium':
      return 'secondary'
    case 'low':
      return 'outline'
    default:
      return 'secondary'
  }
}

const getStatusIcon = (status: string) => {
  switch (status) {
    case 'not_started':
      return <Clock className="h-4 w-4" />
    case 'in_progress':
      return <PlayCircle className="h-4 w-4" />
    case 'review':
      return <CheckCircle className="h-4 w-4" />
    case 'completed':
      return <CheckCircle2 className="h-4 w-4" />
    case 'blocked':
      return <AlertTriangle className="h-4 w-4" />
    default:
      return <Clock className="h-4 w-4" />
  }
}

interface AssignedTasksOverviewProps {
  viewMode: 'grid' | 'list' | 'kanban'
}

export const AssignedTasksOverview: React.FC<AssignedTasksOverviewProps> = ({ viewMode }) => {
  const [tasks, setTasks] = useState<Task[]>(mockTasks)
  const [searchQuery, setSearchQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [priorityFilter, setPriorityFilter] = useState<string>('all')
  const [assigneeFilter, setAssigneeFilter] = useState<string>('all')

  const filteredTasks = tasks.filter(task => {
    const matchesSearch = searchQuery === '' || 
      task.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      task.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
      task.assignee.toLowerCase().includes(searchQuery.toLowerCase())

    const matchesStatus = statusFilter === 'all' || task.status === statusFilter
    const matchesPriority = priorityFilter === 'all' || task.priority === priorityFilter
    const matchesAssignee = assigneeFilter === 'all' || task.assignee === assigneeFilter

    return matchesSearch && matchesStatus && matchesPriority && matchesAssignee
  })

  const uniqueAssignees = [...new Set(tasks.map(task => task.assignee))]

  const handleStatusChange = async (taskId: string, newStatus: string) => {
    setTasks(prev => 
      prev.map(task => 
        task.id === taskId ? { ...task, status: newStatus as any } : task
      )
    )
  }

  const TaskCard = ({ task }: { task: Task }) => (
    <Card className="transition-shadow hover:shadow-md">
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between">
          <div className="flex-1 min-w-0">
            <CardTitle className="text-base truncate">{task.title}</CardTitle>
            <CardDescription className="line-clamp-2 mt-1">
              {task.description}
            </CardDescription>
          </div>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="sm" className="h-6 w-6 p-0 ml-2">
                <MoreHorizontal className="h-3 w-3" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem>
                <ExternalLink className="h-4 w-4 mr-2" />
                Open Task
              </DropdownMenuItem>
              <DropdownMenuItem>
                <MessageSquare className="h-4 w-4 mr-2" />
                Add Comment
              </DropdownMenuItem>
              <DropdownMenuItem>
                <PlayCircle className="h-4 w-4 mr-2" />
                Start Timer
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </CardHeader>

      <CardContent className="space-y-4">
        {/* Progress */}
        <div>
          <div className="flex items-center justify-between text-sm mb-2">
            <span>Progress</span>
            <span>{task.progress}%</span>
          </div>
          <Progress value={task.progress} className="h-2" />
        </div>

        {/* Status and Priority */}
        <div className="flex items-center gap-2">
          <Badge 
            variant="outline"
            className={`text-xs ${getStatusColor(task.status)}`}
          >
            {getStatusIcon(task.status)}
            <span className="ml-1 capitalize">{task.status.replace('_', ' ')}</span>
          </Badge>
          <Badge 
            variant={getPriorityColor(task.priority) as any}
            className="text-xs"
          >
            <Flag className="h-3 w-3 mr-1" />
            {task.priority}
          </Badge>
        </div>

        {/* Assignee and Due Date */}
        <div className="flex items-center justify-between text-xs text-muted-foreground">
          <div className="flex items-center gap-1">
            <Avatar className="h-5 w-5">
              <AvatarFallback className="text-xs">
                {task.assignee.split(' ').map(n => n[0]).join('')}
              </AvatarFallback>
            </Avatar>
            <span>{task.assignee}</span>
          </div>
          {task.dueDate && (
            <div className="flex items-center gap-1">
              <Calendar className="h-3 w-3" />
              <span>{format(task.dueDate, 'MMM d')}</span>
            </div>
          )}
        </div>

        {/* Subtasks */}
        {task.subtasks.length > 0 && (
          <div>
            <div className="text-xs font-medium mb-2">
              Subtasks ({task.subtasks.filter(st => st.completed).length}/{task.subtasks.length})
            </div>
            <div className="space-y-1">
              {task.subtasks.slice(0, 3).map(subtask => (
                <div key={subtask.id} className="flex items-center gap-2 text-xs">
                  <div className={`w-3 h-3 rounded border flex items-center justify-center ${
                    subtask.completed ? 'bg-green-500 border-green-500' : 'border-gray-300'
                  }`}>
                    {subtask.completed && <CheckCircle2 className="h-2 w-2 text-white" />}
                  </div>
                  <span className={subtask.completed ? 'line-through text-muted-foreground' : ''}>
                    {subtask.title}
                  </span>
                </div>
              ))}
              {task.subtasks.length > 3 && (
                <div className="text-xs text-muted-foreground">
                  +{task.subtasks.length - 3} more
                </div>
              )}
            </div>
          </div>
        )}

        {/* Metadata */}
        <div className="flex items-center gap-3 text-xs text-muted-foreground">
          {task.attachments > 0 && (
            <div className="flex items-center gap-1">
              <Paperclip className="h-3 w-3" />
              {task.attachments}
            </div>
          )}
          {task.comments > 0 && (
            <div className="flex items-center gap-1">
              <MessageSquare className="h-3 w-3" />
              {task.comments}
            </div>
          )}
          <div className="flex items-center gap-1">
            <Clock className="h-3 w-3" />
            {task.actualHours || 0}h / {task.estimatedHours}h
          </div>
        </div>

        {/* Tags */}
        {task.tags.length > 0 && (
          <div className="flex flex-wrap gap-1">
            {task.tags.slice(0, 3).map(tag => (
              <Badge key={tag} variant="outline" className="text-xs px-1.5 py-0.5">
                {tag}
              </Badge>
            ))}
            {task.tags.length > 3 && (
              <Badge variant="outline" className="text-xs px-1.5 py-0.5">
                +{task.tags.length - 3}
              </Badge>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  )

  const TaskListItem = ({ task }: { task: Task }) => (
    <div className="flex items-center gap-4 p-4 border rounded-lg hover:bg-muted/50 transition-colors">
      {/* Status Icon */}
      <div className={`w-8 h-8 rounded-full flex items-center justify-center ${
        task.status === 'completed' ? 'bg-green-100 text-green-600' :
        task.status === 'in_progress' ? 'bg-blue-100 text-blue-600' :
        task.status === 'blocked' ? 'bg-red-100 text-red-600' :
        'bg-gray-100 text-gray-600'
      }`}>
        {getStatusIcon(task.status)}
      </div>

      {/* Task Info */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 mb-1">
          <h4 className="font-medium truncate">{task.title}</h4>
          <Badge 
            variant={getPriorityColor(task.priority) as any}
            className="text-xs"
          >
            {task.priority}
          </Badge>
          <Badge 
            variant="outline"
            className={`text-xs ${getStatusColor(task.status)}`}
          >
            {task.status.replace('_', ' ')}
          </Badge>
        </div>
        <p className="text-sm text-muted-foreground line-clamp-1">
          {task.description}
        </p>
      </div>

      {/* Assignee */}
      <div className="flex items-center gap-2 min-w-0">
        <Avatar className="h-6 w-6">
          <AvatarFallback className="text-xs">
            {task.assignee.split(' ').map(n => n[0]).join('')}
          </AvatarFallback>
        </Avatar>
        <span className="text-sm truncate">{task.assignee}</span>
      </div>

      {/* Progress */}
      <div className="w-24">
        <div className="flex items-center justify-between text-xs mb-1">
          <span>Progress</span>
          <span>{task.progress}%</span>
        </div>
        <Progress value={task.progress} className="h-2" />
      </div>

      {/* Due Date */}
      <div className="text-sm text-muted-foreground min-w-0">
        {task.dueDate ? format(task.dueDate, 'MMM d') : 'No due date'}
      </div>

      {/* Actions */}
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="sm" className="h-6 w-6 p-0">
            <MoreHorizontal className="h-3 w-3" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem>
            <ExternalLink className="h-4 w-4 mr-2" />
            Open Task
          </DropdownMenuItem>
          <DropdownMenuItem>
            <MessageSquare className="h-4 w-4 mr-2" />
            Add Comment
          </DropdownMenuItem>
          <DropdownMenuItem>
            <PlayCircle className="h-4 w-4 mr-2" />
            Start Timer
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  )

  const KanbanColumn = ({ status, tasks }: { status: string; tasks: Task[] }) => (
    <div className="flex-1 min-w-[300px]">
      <div className="bg-muted/50 p-3 rounded-lg mb-4">
        <div className="flex items-center justify-between">
          <h3 className="font-medium capitalize">{status.replace('_', ' ')}</h3>
          <Badge variant="secondary">{tasks.length}</Badge>
        </div>
      </div>
      <div className="space-y-3">
        {tasks.map(task => (
          <TaskCard key={task.id} task={task} />
        ))}
      </div>
    </div>
  )

  return (
    <div className="space-y-6">
      {/* Filters */}
      <Card>
        <CardHeader>
          <CardTitle>Task Management</CardTitle>
          <CardDescription>
            Track and manage team task assignments and progress
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex flex-wrap gap-4">
            <div className="flex-1 min-w-[200px]">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Search tasks..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10"
                />
              </div>
            </div>

            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="w-[150px]">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Status</SelectItem>
                <SelectItem value="not_started">Not Started</SelectItem>
                <SelectItem value="in_progress">In Progress</SelectItem>
                <SelectItem value="review">Review</SelectItem>
                <SelectItem value="completed">Completed</SelectItem>
                <SelectItem value="blocked">Blocked</SelectItem>
              </SelectContent>
            </Select>

            <Select value={priorityFilter} onValueChange={setPriorityFilter}>
              <SelectTrigger className="w-[150px]">
                <SelectValue placeholder="Priority" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Priority</SelectItem>
                <SelectItem value="urgent">Urgent</SelectItem>
                <SelectItem value="high">High</SelectItem>
                <SelectItem value="medium">Medium</SelectItem>
                <SelectItem value="low">Low</SelectItem>
              </SelectContent>
            </Select>

            <Select value={assigneeFilter} onValueChange={setAssigneeFilter}>
              <SelectTrigger className="w-[150px]">
                <SelectValue placeholder="Assignee" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Assignees</SelectItem>
                {uniqueAssignees.map(assignee => (
                  <SelectItem key={assignee} value={assignee}>
                    {assignee}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>

            <Button>
              <Plus className="h-4 w-4 mr-2" />
              New Task
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Tasks Display */}
      {viewMode === 'grid' && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredTasks.map(task => (
            <TaskCard key={task.id} task={task} />
          ))}
        </div>
      )}

      {viewMode === 'list' && (
        <div className="space-y-2">
          {filteredTasks.map(task => (
            <TaskListItem key={task.id} task={task} />
          ))}
        </div>
      )}

      {viewMode === 'kanban' && (
        <div className="flex gap-6 overflow-x-auto pb-4">
          <KanbanColumn 
            status="not_started" 
            tasks={filteredTasks.filter(t => t.status === 'not_started')} 
          />
          <KanbanColumn 
            status="in_progress" 
            tasks={filteredTasks.filter(t => t.status === 'in_progress')} 
          />
          <KanbanColumn 
            status="review" 
            tasks={filteredTasks.filter(t => t.status === 'review')} 
          />
          <KanbanColumn 
            status="completed" 
            tasks={filteredTasks.filter(t => t.status === 'completed')} 
          />
          <KanbanColumn 
            status="blocked" 
            tasks={filteredTasks.filter(t => t.status === 'blocked')} 
          />
        </div>
      )}

      {filteredTasks.length === 0 && (
        <Card>
          <CardContent className="py-12 text-center">
            <Target className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
            <h3 className="text-lg font-medium mb-2">No tasks found</h3>
            <p className="text-muted-foreground">
              Try adjusting your filters or create a new task to get started.
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

export default AssignedTasksOverview