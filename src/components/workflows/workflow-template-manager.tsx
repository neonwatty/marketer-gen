'use client'

import React, { useState, useEffect } from 'react'
import { WorkflowTemplate, WorkflowTemplateStage, UserRole } from '@/types'
import { validateComponentAccess } from '@/lib/permissions'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger } from '@/components/ui/alert-dialog'
import { 
  Settings, 
  Plus, 
  Edit,
  Trash2,
  Copy,
  Download,
  Upload,
  Search,
  Filter,
  Star,
  Users,
  Clock,
  CheckCircle,
  Globe,
  Lock,
  BookOpen,
  Zap,
  Workflow,
  Save,
  X
} from 'lucide-react'

export interface WorkflowTemplateManagerProps {
  currentUser: any
  onCreateWorkflow?: (template: WorkflowTemplate) => void
  onTemplateSelect?: (template: WorkflowTemplate) => void
}

interface TemplateFilters {
  category?: string
  applicableType?: string
  isPublic?: boolean
  search?: string
}

const TEMPLATE_CATEGORIES = [
  { value: 'MARKETING', label: 'Marketing', icon: '📈' },
  { value: 'CONTENT', label: 'Content', icon: '📝' },
  { value: 'BRAND', label: 'Brand', icon: '🎨' },
  { value: 'COMPLIANCE', label: 'Compliance', icon: '⚖️' },
  { value: 'GENERAL', label: 'General', icon: '📋' }
]

const APPLICABLE_TYPES = [
  { value: 'CAMPAIGN', label: 'Campaigns' },
  { value: 'JOURNEY', label: 'Journeys' },
  { value: 'CONTENT', label: 'Content' },
  { value: 'BRAND', label: 'Brand Assets' }
]

const TemplateCard: React.FC<{
  template: WorkflowTemplate
  onEdit: (template: WorkflowTemplate) => void
  onDelete: (templateId: string) => void
  onDuplicate: (template: WorkflowTemplate) => void
  onUse: (template: WorkflowTemplate) => void
  canEdit: boolean
}> = ({ template, onEdit, onDelete, onDuplicate, onUse, canEdit }) => {
  const categoryInfo = TEMPLATE_CATEGORIES.find(cat => cat.value === template.category)
  
  return (
    <Card className="hover:shadow-md transition-shadow">
      <CardHeader>
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-2">
            <span className="text-2xl">{categoryInfo?.icon || '📋'}</span>
            <div>
              <CardTitle className="text-lg">{template.name}</CardTitle>
              <CardDescription className="flex items-center gap-2 mt-1">
                <Badge variant={template.isPublic ? 'default' : 'secondary'}>
                  {template.isPublic ? (
                    <>
                      <Globe className="h-3 w-3 mr-1" />
                      Public
                    </>
                  ) : (
                    <>
                      <Lock className="h-3 w-3 mr-1" />
                      Private
                    </>
                  )}
                </Badge>
                <Badge variant="outline">{categoryInfo?.label}</Badge>
              </CardDescription>
            </div>
          </div>
          
          <div className="flex items-center gap-1">
            <Button variant="ghost" size="sm" onClick={() => onUse(template)}>
              <Zap className="h-4 w-4" />
            </Button>
            <Button variant="ghost" size="sm" onClick={() => onDuplicate(template)}>
              <Copy className="h-4 w-4" />
            </Button>
            {canEdit && (
              <>
                <Button variant="ghost" size="sm" onClick={() => onEdit(template)}>
                  <Edit className="h-4 w-4" />
                </Button>
                <AlertDialog>
                  <AlertDialogTrigger asChild>
                    <Button variant="ghost" size="sm">
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </AlertDialogTrigger>
                  <AlertDialogContent>
                    <AlertDialogHeader>
                      <AlertDialogTitle>Delete Template</AlertDialogTitle>
                      <AlertDialogDescription>
                        Are you sure you want to delete "{template.name}"? This action cannot be undone.
                      </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                      <AlertDialogCancel>Cancel</AlertDialogCancel>
                      <AlertDialogAction onClick={() => onDelete(template.id.toString())}>
                        Delete
                      </AlertDialogAction>
                    </AlertDialogFooter>
                  </AlertDialogContent>
                </AlertDialog>
              </>
            )}
          </div>
        </div>
      </CardHeader>
      
      <CardContent>
        <p className="text-sm text-muted-foreground mb-3">
          {template.description || 'No description provided'}
        </p>
        
        <div className="flex items-center justify-between text-xs text-muted-foreground">
          <div className="flex items-center gap-4">
            <span className="flex items-center gap-1">
              <Workflow className="h-3 w-3" />
              {template.stages.length} stage{template.stages.length !== 1 ? 's' : ''}
            </span>
            <span className="flex items-center gap-1">
              <Users className="h-3 w-3" />
              Used {template.usageCount} time{template.usageCount !== 1 ? 's' : ''}
            </span>
          </div>
          
          <div className="flex gap-1">
            {Array.isArray(template.applicableTypes) ? 
              template.applicableTypes.slice(0, 2).map(type => (
                <Badge key={type} variant="outline" className="text-xs">
                  {APPLICABLE_TYPES.find(t => t.value === type)?.label || type}
                </Badge>
              )) :
              <Badge variant="outline" className="text-xs">
                {JSON.parse(template.applicableTypes as string).join(', ')}
              </Badge>
            }
            {Array.isArray(template.applicableTypes) && template.applicableTypes.length > 2 && (
              <Badge variant="outline" className="text-xs">
                +{template.applicableTypes.length - 2}
              </Badge>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

export const WorkflowTemplateManager: React.FC<WorkflowTemplateManagerProps> = ({
  currentUser,
  onCreateWorkflow,
  onTemplateSelect
}) => {
  const [templates, setTemplates] = useState<WorkflowTemplate[]>([])
  const [loading, setLoading] = useState(true)
  const [filters, setFilters] = useState<TemplateFilters>({})
  const [showCreateDialog, setShowCreateDialog] = useState(false)
  const [editingTemplate, setEditingTemplate] = useState<WorkflowTemplate | null>(null)

  const canManageTemplates = validateComponentAccess(currentUser?.role, 'canManageWorkflows')

  useEffect(() => {
    fetchTemplates()
  }, [filters])

  const fetchTemplates = async () => {
    try {
      setLoading(true)
      const params = new URLSearchParams()
      
      if (filters.category) params.append('category', filters.category)
      if (filters.applicableType) params.append('applicableType', filters.applicableType)
      if (filters.isPublic !== undefined) params.append('isPublic', filters.isPublic.toString())
      if (filters.search) params.append('search', filters.search)

      const response = await fetch(`/api/workflow-templates?${params}`)
      const result = await response.json()
      
      if (result.success) {
        setTemplates(result.data)
      } else {
        console.error('Failed to fetch templates:', result.error)
      }
    } catch (error) {
      console.error('Error fetching templates:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleCreateFromTemplate = async (template: WorkflowTemplate) => {
    if (onCreateWorkflow) {
      onCreateWorkflow(template)
    }
  }

  const handleEditTemplate = (template: WorkflowTemplate) => {
    setEditingTemplate(template)
  }

  const handleDeleteTemplate = async (templateId: string) => {
    try {
      const response = await fetch(`/api/workflow-templates/${templateId}`, {
        method: 'DELETE'
      })
      
      if (response.ok) {
        setTemplates(prev => prev.filter(t => t.id.toString() !== templateId))
      }
    } catch (error) {
      console.error('Error deleting template:', error)
    }
  }

  const handleDuplicateTemplate = async (template: WorkflowTemplate) => {
    try {
      const duplicateData = {
        ...template,
        name: `${template.name} (Copy)`,
        isPublic: false,
        id: undefined,
        createdAt: undefined,
        updatedAt: undefined,
        usageCount: 0
      }
      
      const response = await fetch('/api/workflow-templates', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(duplicateData)
      })
      
      const result = await response.json()
      if (result.success) {
        setTemplates(prev => [result.data, ...prev])
      }
    } catch (error) {
      console.error('Error duplicating template:', error)
    }
  }

  const handleUseTemplate = (template: WorkflowTemplate) => {
    if (onTemplateSelect) {
      onTemplateSelect(template)
    } else {
      handleCreateFromTemplate(template)
    }
  }

  const filteredTemplates = templates.filter(template => {
    if (filters.search) {
      const searchTerm = filters.search.toLowerCase()
      return template.name.toLowerCase().includes(searchTerm) ||
             template.description?.toLowerCase().includes(searchTerm)
    }
    return true
  })

  const groupedTemplates = TEMPLATE_CATEGORIES.reduce((groups, category) => {
    groups[category.value] = filteredTemplates.filter(
      template => template.category === category.value
    )
    return groups
  }, {} as Record<string, WorkflowTemplate[]>)

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Workflow Templates</h2>
          <p className="text-muted-foreground">
            Pre-configured approval workflows for common use cases
          </p>
        </div>
        
        {canManageTemplates && (
          <div className="flex gap-2">
            <Button variant="outline">
              <Upload className="h-4 w-4 mr-2" />
              Import
            </Button>
            <Button onClick={() => setShowCreateDialog(true)}>
              <Plus className="h-4 w-4 mr-2" />
              Create Template
            </Button>
          </div>
        )}
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="pt-6">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="space-y-2">
              <Label>Search</Label>
              <div className="relative">
                <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Search templates..."
                  value={filters.search || ''}
                  onChange={(e) => setFilters(prev => ({ ...prev, search: e.target.value }))}
                  className="pl-9"
                />
              </div>
            </div>
            
            <div className="space-y-2">
              <Label>Category</Label>
              <Select
                value={filters.category || ''}
                onValueChange={(value) => setFilters(prev => ({ 
                  ...prev, 
                  category: value || undefined 
                }))}
              >
                <SelectTrigger>
                  <SelectValue placeholder="All categories" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">All categories</SelectItem>
                  {TEMPLATE_CATEGORIES.map(category => (
                    <SelectItem key={category.value} value={category.value}>
                      {category.icon} {category.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            
            <div className="space-y-2">
              <Label>Content Type</Label>
              <Select
                value={filters.applicableType || ''}
                onValueChange={(value) => setFilters(prev => ({ 
                  ...prev, 
                  applicableType: value || undefined 
                }))}
              >
                <SelectTrigger>
                  <SelectValue placeholder="All types" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">All types</SelectItem>
                  {APPLICABLE_TYPES.map(type => (
                    <SelectItem key={type.value} value={type.value}>
                      {type.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            
            <div className="space-y-2">
              <Label>Visibility</Label>
              <Select
                value={filters.isPublic === undefined ? '' : filters.isPublic.toString()}
                onValueChange={(value) => setFilters(prev => ({ 
                  ...prev, 
                  isPublic: value === '' ? undefined : value === 'true'
                }))}
              >
                <SelectTrigger>
                  <SelectValue placeholder="All templates" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">All templates</SelectItem>
                  <SelectItem value="true">Public only</SelectItem>
                  <SelectItem value="false">Private only</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          
          {Object.values(filters).some(Boolean) && (
            <div className="flex items-center justify-between mt-4 pt-4 border-t">
              <span className="text-sm text-muted-foreground">
                {filteredTemplates.length} template{filteredTemplates.length !== 1 ? 's' : ''} found
              </span>
              <Button 
                variant="ghost" 
                size="sm"
                onClick={() => setFilters({})}
              >
                Clear filters
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Template Categories */}
      <Tabs defaultValue="all" className="w-full">
        <TabsList>
          <TabsTrigger value="all">All Templates</TabsTrigger>
          {TEMPLATE_CATEGORIES.map(category => (
            <TabsTrigger key={category.value} value={category.value}>
              {category.icon} {category.label}
            </TabsTrigger>
          ))}
        </TabsList>

        <TabsContent value="all" className="space-y-4">
          {loading ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {[...Array(6)].map((_, i) => (
                <Card key={i} className="animate-pulse">
                  <CardHeader>
                    <div className="h-4 bg-muted rounded w-3/4"></div>
                    <div className="h-3 bg-muted rounded w-1/2"></div>
                  </CardHeader>
                  <CardContent>
                    <div className="h-3 bg-muted rounded w-full mb-2"></div>
                    <div className="h-3 bg-muted rounded w-2/3"></div>
                  </CardContent>
                </Card>
              ))}
            </div>
          ) : filteredTemplates.length === 0 ? (
            <Card>
              <CardContent className="pt-6">
                <div className="text-center py-8 text-muted-foreground">
                  <BookOpen className="h-12 w-12 mx-auto mb-4 opacity-50" />
                  <p>No templates found matching your criteria</p>
                  {canManageTemplates && (
                    <Button 
                      className="mt-4" 
                      onClick={() => setShowCreateDialog(true)}
                    >
                      Create Your First Template
                    </Button>
                  )}
                </div>
              </CardContent>
            </Card>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {filteredTemplates.map(template => (
                <TemplateCard
                  key={template.id}
                  template={template}
                  onEdit={handleEditTemplate}
                  onDelete={handleDeleteTemplate}
                  onDuplicate={handleDuplicateTemplate}
                  onUse={handleUseTemplate}
                  canEdit={canManageTemplates}
                />
              ))}
            </div>
          )}
        </TabsContent>

        {TEMPLATE_CATEGORIES.map(category => (
          <TabsContent key={category.value} value={category.value} className="space-y-4">
            {groupedTemplates[category.value]?.length === 0 ? (
              <Card>
                <CardContent className="pt-6">
                  <div className="text-center py-8 text-muted-foreground">
                    <span className="text-4xl mb-4 block">{category.icon}</span>
                    <p>No {category.label.toLowerCase()} templates available</p>
                  </div>
                </CardContent>
              </Card>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {groupedTemplates[category.value]?.map(template => (
                  <TemplateCard
                    key={template.id}
                    template={template}
                    onEdit={handleEditTemplate}
                    onDelete={handleDeleteTemplate}
                    onDuplicate={handleDuplicateTemplate}
                    onUse={handleUseTemplate}
                    canEdit={canManageTemplates}
                  />
                )) || []}
              </div>
            )}
          </TabsContent>
        ))}
      </Tabs>
    </div>
  )
}

export default WorkflowTemplateManager