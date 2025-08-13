'use client'

import React, { useState } from 'react'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Separator } from '@/components/ui/separator'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Calendar } from '@/components/ui/calendar'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { Checkbox } from '@/components/ui/checkbox'
import { Progress } from '@/components/ui/progress'
import {
  CalendarIcon,
  Clock,
  User,
  Users,
  Flag,
  Target,
  Plus,
  X,
  Search,
  FileText,
  Paperclip,
  CheckCircle,
  AlertTriangle,
  Zap,
  Tag,
  MessageSquare,
  Bell,
  ArrowRight,
  Copy,
  Save,
  Send
} from 'lucide-react'
import { format } from 'date-fns'
import { toast } from 'sonner'

interface TeamMember {
  id: string
  name: string
  avatar?: string
  role: string
  status: 'online' | 'away' | 'busy' | 'offline'
  workload: number
  skills: string[]
  currentTasks: number
  capacity: number
}

interface TaskTemplate {
  id: string
  name: string
  description: string
  category: string
  estimatedHours: number
  priority: 'low' | 'medium' | 'high' | 'urgent'
  requiredSkills: string[]
  subtasks: string[]
}

interface SubTask {
  id: string
  title: string
  description?: string
  assignee?: string
  estimatedHours?: number
  dueDate?: Date
}

interface TaskFormData {
  title: string
  description: string
  assignee: string
  priority: 'low' | 'medium' | 'high' | 'urgent'
  category: string
  dueDate?: Date
  estimatedHours: number
  tags: string[]
  attachments: File[]
  subtasks: SubTask[]
  dependencies: string[]
  notifyOnCompletion: boolean
  requireApproval: boolean
  approver?: string
}

const mockTeamMembers: TeamMember[] = [
  {
    id: '1',
    name: 'John Doe',
    role: 'Marketing Manager',
    status: 'online',
    workload: 75,
    skills: ['Strategy', 'Campaign Management', 'Analytics'],
    currentTasks: 5,
    capacity: 8
  },
  {
    id: '2',
    name: 'Sarah Wilson',
    role: 'Content Creator',
    status: 'busy',
    workload: 90,
    skills: ['Writing', 'Content Strategy', 'SEO'],
    currentTasks: 7,
    capacity: 8
  },
  {
    id: '3',
    name: 'Mike Johnson',
    role: 'Designer',
    status: 'online',
    workload: 60,
    skills: ['UI/UX Design', 'Graphic Design', 'Prototyping'],
    currentTasks: 4,
    capacity: 8
  },
  {
    id: '4',
    name: 'Lisa Brown',
    role: 'Marketing Director',
    status: 'away',
    workload: 45,
    skills: ['Leadership', 'Strategy', 'Budget Management'],
    currentTasks: 3,
    capacity: 6
  },
  {
    id: '5',
    name: 'David Lee',
    role: 'Copywriter',
    status: 'online',
    workload: 80,
    skills: ['Copywriting', 'Email Marketing', 'Social Media'],
    currentTasks: 6,
    capacity: 8
  }
]

const mockTaskTemplates: TaskTemplate[] = [
  {
    id: '1',
    name: 'Blog Post Creation',
    description: 'Research, write, and optimize a blog post',
    category: 'Content',
    estimatedHours: 6,
    priority: 'medium',
    requiredSkills: ['Writing', 'SEO'],
    subtasks: ['Research topic', 'Create outline', 'Write draft', 'Edit and optimize', 'Add images']
  },
  {
    id: '2',
    name: 'Landing Page Design',
    description: 'Design and prototype a new landing page',
    category: 'Design',
    estimatedHours: 12,
    priority: 'high',
    requiredSkills: ['UI/UX Design', 'Prototyping'],
    subtasks: ['Requirements gathering', 'Wireframing', 'Visual design', 'Prototyping', 'Design review']
  },
  {
    id: '3',
    name: 'Email Campaign',
    description: 'Create and send an email marketing campaign',
    category: 'Email Marketing',
    estimatedHours: 8,
    priority: 'medium',
    requiredSkills: ['Email Marketing', 'Copywriting'],
    subtasks: ['Audience segmentation', 'Email design', 'Copy writing', 'Testing', 'Campaign launch']
  }
]

interface TaskAssignmentInterfaceProps {
  open: boolean
  onClose: () => void
  teamMembers: TeamMember[]
}

export const TaskAssignmentInterface: React.FC<TaskAssignmentInterfaceProps> = ({
  open,
  onClose,
  teamMembers
}) => {
  const [activeTab, setActiveTab] = useState('details')
  const [formData, setFormData] = useState<TaskFormData>({
    title: '',
    description: '',
    assignee: '',
    priority: 'medium',
    category: '',
    estimatedHours: 4,
    tags: [],
    attachments: [],
    subtasks: [],
    dependencies: [],
    notifyOnCompletion: true,
    requireApproval: false
  })
  const [selectedTemplate, setSelectedTemplate] = useState<string>('')
  const [showCalendar, setShowCalendar] = useState(false)
  const [newTag, setNewTag] = useState('')
  const [newSubtask, setNewSubtask] = useState('')
  const [loading, setLoading] = useState(false)

  const handleTemplateSelect = (templateId: string) => {
    const template = mockTaskTemplates.find(t => t.id === templateId)
    if (template) {
      setFormData(prev => ({
        ...prev,
        title: template.name,
        description: template.description,
        category: template.category,
        estimatedHours: template.estimatedHours,
        priority: template.priority,
        subtasks: template.subtasks.map((title, index) => ({
          id: `${Date.now()}-${index}`,
          title,
          estimatedHours: Math.ceil(template.estimatedHours / template.subtasks.length)
        }))
      }))
      setSelectedTemplate(templateId)
    }
  }

  const getRecommendedAssignees = () => {
    const selectedTemplate = mockTaskTemplates.find(t => t.id === selectedTemplate)
    if (!selectedTemplate) return mockTeamMembers

    return mockTeamMembers
      .filter(member => 
        selectedTemplate.requiredSkills.some(skill => 
          member.skills.includes(skill)
        )
      )
      .sort((a, b) => a.workload - b.workload)
  }

  const addTag = () => {
    if (newTag && !formData.tags.includes(newTag)) {
      setFormData(prev => ({
        ...prev,
        tags: [...prev.tags, newTag]
      }))
      setNewTag('')
    }
  }

  const removeTag = (tag: string) => {
    setFormData(prev => ({
      ...prev,
      tags: prev.tags.filter(t => t !== tag)
    }))
  }

  const addSubtask = () => {
    if (newSubtask) {
      setFormData(prev => ({
        ...prev,
        subtasks: [
          ...prev.subtasks,
          {
            id: Date.now().toString(),
            title: newSubtask,
            estimatedHours: 2
          }
        ]
      }))
      setNewSubtask('')
    }
  }

  const removeSubtask = (subtaskId: string) => {
    setFormData(prev => ({
      ...prev,
      subtasks: prev.subtasks.filter(st => st.id !== subtaskId)
    }))
  }

  const handleSubmit = async () => {
    if (!formData.title || !formData.assignee) {
      toast.error('Please fill in all required fields')
      return
    }

    setLoading(true)
    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 2000))
      toast.success('Task assigned successfully!')
      onClose()
      // Reset form
      setFormData({
        title: '',
        description: '',
        assignee: '',
        priority: 'medium',
        category: '',
        estimatedHours: 4,
        tags: [],
        attachments: [],
        subtasks: [],
        dependencies: [],
        notifyOnCompletion: true,
        requireApproval: false
      })
    } catch (error) {
      toast.error('Failed to assign task')
    } finally {
      setLoading(false)
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'online':
        return 'bg-green-500'
      case 'busy':
        return 'bg-red-500'
      case 'away':
        return 'bg-yellow-500'
      case 'offline':
        return 'bg-gray-400'
      default:
        return 'bg-gray-400'
    }
  }

  const getWorkloadColor = (workload: number) => {
    if (workload >= 90) return 'text-red-600'
    if (workload >= 75) return 'text-orange-600'
    if (workload >= 50) return 'text-yellow-600'
    return 'text-green-600'
  }

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-4xl max-h-[90vh] overflow-auto">
        <DialogHeader>
          <DialogTitle>Assign New Task</DialogTitle>
          <DialogDescription>
            Create and assign a task to team members
          </DialogDescription>
        </DialogHeader>

        <Tabs value={activeTab} onValueChange={setActiveTab}>
          <TabsList className="grid w-full grid-cols-4">
            <TabsTrigger value="templates">Templates</TabsTrigger>
            <TabsTrigger value="details">Task Details</TabsTrigger>
            <TabsTrigger value="assignee">Assignee</TabsTrigger>
            <TabsTrigger value="advanced">Advanced</TabsTrigger>
          </TabsList>

          {/* Templates Tab */}
          <TabsContent value="templates" className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {mockTaskTemplates.map(template => (
                <Card 
                  key={template.id}
                  className={`cursor-pointer transition-colors ${
                    selectedTemplate === template.id ? 'ring-2 ring-primary' : ''
                  }`}
                  onClick={() => handleTemplateSelect(template.id)}
                >
                  <CardHeader>
                    <div className="flex items-center justify-between">
                      <CardTitle className="text-base">{template.name}</CardTitle>
                      <Badge 
                        variant={
                          template.priority === 'urgent' ? 'destructive' :
                          template.priority === 'high' ? 'default' :
                          'secondary'
                        }
                      >
                        {template.priority}
                      </Badge>
                    </div>
                    <CardDescription>{template.description}</CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-3">
                      <div className="flex items-center gap-4 text-sm text-muted-foreground">
                        <div className="flex items-center gap-1">
                          <Clock className="h-3 w-3" />
                          {template.estimatedHours}h
                        </div>
                        <div className="flex items-center gap-1">
                          <Tag className="h-3 w-3" />
                          {template.category}
                        </div>
                      </div>
                      
                      <div>
                        <div className="text-xs font-medium mb-1">Required Skills:</div>
                        <div className="flex flex-wrap gap-1">
                          {template.requiredSkills.map(skill => (
                            <Badge key={skill} variant="outline" className="text-xs">
                              {skill}
                            </Badge>
                          ))}
                        </div>
                      </div>
                      
                      <div>
                        <div className="text-xs font-medium mb-1">Subtasks ({template.subtasks.length}):</div>
                        <div className="text-xs text-muted-foreground">
                          {template.subtasks.slice(0, 2).join(', ')}
                          {template.subtasks.length > 2 && ` +${template.subtasks.length - 2} more`}
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
            
            <div className="flex justify-between">
              <Button variant="outline" onClick={() => setActiveTab('details')}>
                Skip Templates
              </Button>
              <Button 
                onClick={() => setActiveTab('details')}
                disabled={!selectedTemplate}
              >
                Use Template
                <ArrowRight className="h-4 w-4 ml-2" />
              </Button>
            </div>
          </TabsContent>

          {/* Task Details Tab */}
          <TabsContent value="details" className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-4">
                <div>
                  <Label htmlFor="title">Task Title *</Label>
                  <Input
                    id="title"
                    value={formData.title}
                    onChange={(e) => setFormData(prev => ({ ...prev, title: e.target.value }))}
                    placeholder="Enter task title..."
                  />
                </div>

                <div>
                  <Label htmlFor="category">Category</Label>
                  <Select 
                    value={formData.category} 
                    onValueChange={(value) => setFormData(prev => ({ ...prev, category: value }))}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select category" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="content">Content</SelectItem>
                      <SelectItem value="design">Design</SelectItem>
                      <SelectItem value="marketing">Marketing</SelectItem>
                      <SelectItem value="development">Development</SelectItem>
                      <SelectItem value="research">Research</SelectItem>
                      <SelectItem value="strategy">Strategy</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <Label htmlFor="priority">Priority</Label>
                    <Select 
                      value={formData.priority} 
                      onValueChange={(value) => setFormData(prev => ({ ...prev, priority: value as any }))}
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="low">Low</SelectItem>
                        <SelectItem value="medium">Medium</SelectItem>
                        <SelectItem value="high">High</SelectItem>
                        <SelectItem value="urgent">Urgent</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  <div>
                    <Label htmlFor="hours">Estimated Hours</Label>
                    <Input
                      id="hours"
                      type="number"
                      value={formData.estimatedHours}
                      onChange={(e) => setFormData(prev => ({ ...prev, estimatedHours: parseInt(e.target.value) || 0 }))}
                      min="1"
                      max="100"
                    />
                  </div>
                </div>

                <div>
                  <Label htmlFor="dueDate">Due Date</Label>
                  <Popover open={showCalendar} onOpenChange={setShowCalendar}>
                    <PopoverTrigger asChild>
                      <Button
                        variant="outline"
                        className="w-full justify-start text-left font-normal"
                      >
                        <CalendarIcon className="mr-2 h-4 w-4" />
                        {formData.dueDate ? format(formData.dueDate, 'PPP') : 'Pick a date'}
                      </Button>
                    </PopoverTrigger>
                    <PopoverContent className="w-auto p-0">
                      <Calendar
                        mode="single"
                        selected={formData.dueDate}
                        onSelect={(date) => {
                          setFormData(prev => ({ ...prev, dueDate: date }))
                          setShowCalendar(false)
                        }}
                        initialFocus
                      />
                    </PopoverContent>
                  </Popover>
                </div>
              </div>

              <div className="space-y-4">
                <div>
                  <Label htmlFor="description">Description</Label>
                  <Textarea
                    id="description"
                    value={formData.description}
                    onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
                    placeholder="Describe the task..."
                    rows={4}
                  />
                </div>

                <div>
                  <Label>Tags</Label>
                  <div className="flex gap-2 mb-2">
                    <Input
                      value={newTag}
                      onChange={(e) => setNewTag(e.target.value)}
                      placeholder="Add tag..."
                      onKeyPress={(e) => e.key === 'Enter' && addTag()}
                    />
                    <Button onClick={addTag} size="sm">
                      <Plus className="h-4 w-4" />
                    </Button>
                  </div>
                  <div className="flex flex-wrap gap-1">
                    {formData.tags.map(tag => (
                      <Badge key={tag} variant="secondary" className="text-xs">
                        {tag}
                        <X 
                          className="h-3 w-3 ml-1 cursor-pointer" 
                          onClick={() => removeTag(tag)}
                        />
                      </Badge>
                    ))}
                  </div>
                </div>

                <div>
                  <Label>Subtasks</Label>
                  <div className="flex gap-2 mb-2">
                    <Input
                      value={newSubtask}
                      onChange={(e) => setNewSubtask(e.target.value)}
                      placeholder="Add subtask..."
                      onKeyPress={(e) => e.key === 'Enter' && addSubtask()}
                    />
                    <Button onClick={addSubtask} size="sm">
                      <Plus className="h-4 w-4" />
                    </Button>
                  </div>
                  <div className="space-y-1">
                    {formData.subtasks.map(subtask => (
                      <div key={subtask.id} className="flex items-center justify-between text-sm p-2 bg-muted rounded">
                        <span>{subtask.title}</span>
                        <X 
                          className="h-3 w-3 cursor-pointer" 
                          onClick={() => removeSubtask(subtask.id)}
                        />
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>

            <div className="flex justify-between">
              <Button variant="outline" onClick={() => setActiveTab('templates')}>
                Back
              </Button>
              <Button onClick={() => setActiveTab('assignee')}>
                Next: Choose Assignee
                <ArrowRight className="h-4 w-4 ml-2" />
              </Button>
            </div>
          </TabsContent>

          {/* Assignee Tab */}
          <TabsContent value="assignee" className="space-y-4">
            <div className="space-y-4">
              <div>
                <h3 className="font-medium mb-2">Recommended Assignees</h3>
                <p className="text-sm text-muted-foreground mb-4">
                  Based on skills and current workload
                </p>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {getRecommendedAssignees().map(member => (
                  <Card 
                    key={member.id}
                    className={`cursor-pointer transition-colors ${
                      formData.assignee === member.id ? 'ring-2 ring-primary' : ''
                    }`}
                    onClick={() => setFormData(prev => ({ ...prev, assignee: member.id }))}
                  >
                    <CardContent className="p-4">
                      <div className="flex items-start gap-3">
                        <div className="relative">
                          <Avatar className="h-10 w-10">
                            <AvatarFallback>
                              {member.name.split(' ').map(n => n[0]).join('')}
                            </AvatarFallback>
                          </Avatar>
                          <div className={`absolute -bottom-1 -right-1 w-3 h-3 rounded-full border-2 border-background ${
                            getStatusColor(member.status)
                          }`} />
                        </div>

                        <div className="flex-1 min-w-0">
                          <div className="flex items-center justify-between">
                            <h4 className="font-medium">{member.name}</h4>
                            <Badge variant="outline" className="text-xs">
                              {member.status}
                            </Badge>
                          </div>
                          <p className="text-sm text-muted-foreground">{member.role}</p>
                          
                          <div className="mt-2">
                            <div className="flex items-center justify-between text-xs mb-1">
                              <span>Workload</span>
                              <span className={getWorkloadColor(member.workload)}>
                                {member.workload}%
                              </span>
                            </div>
                            <Progress value={member.workload} className="h-2" />
                          </div>

                          <div className="mt-2">
                            <div className="text-xs text-muted-foreground mb-1">
                              Tasks: {member.currentTasks}/{member.capacity}
                            </div>
                            <div className="flex flex-wrap gap-1">
                              {member.skills.slice(0, 3).map(skill => (
                                <Badge key={skill} variant="outline" className="text-xs">
                                  {skill}
                                </Badge>
                              ))}
                              {member.skills.length > 3 && (
                                <Badge variant="outline" className="text-xs">
                                  +{member.skills.length - 3}
                                </Badge>
                              )}
                            </div>
                          </div>
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                ))}
              </div>
            </div>

            <div className="flex justify-between">
              <Button variant="outline" onClick={() => setActiveTab('details')}>
                Back
              </Button>
              <Button 
                onClick={() => setActiveTab('advanced')}
                disabled={!formData.assignee}
              >
                Next: Advanced Settings
                <ArrowRight className="h-4 w-4 ml-2" />
              </Button>
            </div>
          </TabsContent>

          {/* Advanced Tab */}
          <TabsContent value="advanced" className="space-y-4">
            <div className="space-y-4">
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="notify"
                  checked={formData.notifyOnCompletion}
                  onCheckedChange={(checked) => setFormData(prev => ({ 
                    ...prev, 
                    notifyOnCompletion: checked as boolean 
                  }))}
                />
                <Label htmlFor="notify">Notify me when task is completed</Label>
              </div>

              <div className="flex items-center space-x-2">
                <Checkbox
                  id="approval"
                  checked={formData.requireApproval}
                  onCheckedChange={(checked) => setFormData(prev => ({ 
                    ...prev, 
                    requireApproval: checked as boolean 
                  }))}
                />
                <Label htmlFor="approval">Require approval before completion</Label>
              </div>

              {formData.requireApproval && (
                <div>
                  <Label>Approver</Label>
                  <Select 
                    value={formData.approver} 
                    onValueChange={(value) => setFormData(prev => ({ ...prev, approver: value }))}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select approver" />
                    </SelectTrigger>
                    <SelectContent>
                      {teamMembers
                        .filter(member => member.id !== formData.assignee)
                        .map(member => (
                          <SelectItem key={member.id} value={member.id}>
                            {member.name} - {member.role}
                          </SelectItem>
                        ))}
                    </SelectContent>
                  </Select>
                </div>
              )}
            </div>

            <Separator />

            <div className="flex justify-between">
              <Button variant="outline" onClick={() => setActiveTab('assignee')}>
                Back
              </Button>
              <div className="flex gap-2">
                <Button variant="outline" onClick={onClose}>
                  Cancel
                </Button>
                <Button onClick={handleSubmit} disabled={loading}>
                  {loading ? (
                    <>
                      <div className="animate-spin h-4 w-4 mr-2 rounded-full border-2 border-current border-t-transparent" />
                      Assigning...
                    </>
                  ) : (
                    <>
                      <Send className="h-4 w-4 mr-2" />
                      Assign Task
                    </>
                  )}
                </Button>
              </div>
            </div>
          </TabsContent>
        </Tabs>
      </DialogContent>
    </Dialog>
  )
}

export default TaskAssignmentInterface