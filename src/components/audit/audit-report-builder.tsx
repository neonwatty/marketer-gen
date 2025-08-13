'use client'

import React, { useState, useCallback, useMemo } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Badge } from '@/components/ui/badge'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Textarea } from '@/components/ui/textarea'
import { Switch } from '@/components/ui/switch'
import { ScrollArea } from '@/components/ui/scroll-area'
import { 
  BarChart3,
  PieChart,
  TrendingUp,
  Calendar,
  Filter,
  Download,
  Save,
  Play,
  Settings,
  Eye,
  Clock,
  Users,
  Activity,
  Shield,
  FileText,
  Share2
} from 'lucide-react'

export interface AuditReportConfig {
  id?: string
  name: string
  description?: string
  isPublic: boolean
  filters: {
    eventTypes?: string[]
    eventCategories?: string[]
    entityTypes?: string[]
    severities?: string[]
    userIds?: string[]
    dateRange: {
      type: 'last_7_days' | 'last_30_days' | 'last_90_days' | 'custom'
      startDate?: Date
      endDate?: Date
    }
    environment?: string
    includePersonalData: boolean
  }
  groupBy: string[]
  sortBy: {
    field: string
    direction: 'asc' | 'desc'
  }[]
  visualization: {
    chartType: 'bar' | 'pie' | 'line' | 'table' | 'timeline'
    showTrends: boolean
    showComparisons: boolean
  }
  schedule?: {
    enabled: boolean
    frequency: 'daily' | 'weekly' | 'monthly'
    recipients: string[]
    format: 'pdf' | 'csv' | 'json'
  }
}

export interface AuditReportBuilderProps {
  initialConfig?: Partial<AuditReportConfig>
  onSave?: (config: AuditReportConfig) => Promise<void>
  onRun?: (config: AuditReportConfig) => Promise<any>
  onPreview?: (config: AuditReportConfig) => Promise<any>
  availableUsers?: Array<{ id: string; name: string; email: string }>
  className?: string
}

const EVENT_TYPES = [
  'CREATE', 'UPDATE', 'DELETE', 'VIEW', 'APPROVE', 'REJECT',
  'LOGIN', 'LOGOUT', 'EXPORT', 'IMPORT', 'SECURITY_EVENT', 'API_CALL'
]

const EVENT_CATEGORIES = [
  'USER_MANAGEMENT', 'CONTENT_MANAGEMENT', 'CAMPAIGN_MANAGEMENT',
  'APPROVAL_WORKFLOW', 'BRAND_MANAGEMENT', 'TEAM_COLLABORATION',
  'SYSTEM_ADMINISTRATION', 'SECURITY', 'DATA_EXPORT', 'ANALYTICS'
]

const ENTITY_TYPES = [
  'USER', 'BRAND', 'CAMPAIGN', 'JOURNEY', 'CONTENT', 'TEMPLATE',
  'COMMENT', 'APPROVAL_WORKFLOW', 'APPROVAL_REQUEST', 'ANALYTICS'
]

const SEVERITIES = ['DEBUG', 'INFO', 'NOTICE', 'WARNING', 'ERROR', 'CRITICAL']

const GROUPBY_OPTIONS = [
  { value: 'eventType', label: 'Event Type' },
  { value: 'eventCategory', label: 'Event Category' },
  { value: 'entityType', label: 'Entity Type' },
  { value: 'severity', label: 'Severity' },
  { value: 'userId', label: 'User' },
  { value: 'environment', label: 'Environment' },
  { value: 'hourOfDay', label: 'Hour of Day' },
  { value: 'dayOfWeek', label: 'Day of Week' },
  { value: 'date', label: 'Date' }
]

const CHART_TYPES = [
  { value: 'bar', label: 'Bar Chart', icon: BarChart3 },
  { value: 'pie', label: 'Pie Chart', icon: PieChart },
  { value: 'line', label: 'Line Chart', icon: TrendingUp },
  { value: 'table', label: 'Table', icon: FileText },
  { value: 'timeline', label: 'Timeline', icon: Activity }
]

export const AuditReportBuilder: React.FC<AuditReportBuilderProps> = ({
  initialConfig,
  onSave,
  onRun,
  onPreview,
  availableUsers = [],
  className
}) => {
  const [config, setConfig] = useState<AuditReportConfig>({
    name: '',
    description: '',
    isPublic: false,
    filters: {
      dateRange: { type: 'last_30_days' },
      includePersonalData: false
    },
    groupBy: ['eventType'],
    sortBy: [{ field: 'createdAt', direction: 'desc' }],
    visualization: {
      chartType: 'bar',
      showTrends: false,
      showComparisons: false
    },
    schedule: {
      enabled: false,
      frequency: 'weekly',
      recipients: [],
      format: 'pdf'
    },
    ...initialConfig
  })

  const [isPreviewMode, setIsPreviewMode] = useState(false)
  const [previewData, setPreviewData] = useState<any>(null)
  const [loading, setLoading] = useState(false)

  // Update config helper
  const updateConfig = useCallback((updates: Partial<AuditReportConfig>) => {
    setConfig(prev => ({ ...prev, ...updates }))
  }, [])

  // Update nested config helper
  const updateNestedConfig = useCallback((path: string, updates: any) => {
    setConfig(prev => {
      const newConfig = { ...prev }
      const keys = path.split('.')
      let current: any = newConfig
      
      for (let i = 0; i < keys.length - 1; i++) {
        current = current[keys[i]]
      }
      
      current[keys[keys.length - 1]] = { ...current[keys[keys.length - 1]], ...updates }
      return newConfig
    })
  }, [])

  // Validate configuration
  const isConfigValid = useMemo(() => {
    return config.name.trim().length > 0 && config.groupBy.length > 0
  }, [config])

  // Handle save
  const handleSave = useCallback(async () => {
    if (!isConfigValid || !onSave) return
    
    setLoading(true)
    try {
      await onSave(config)
    } catch (error) {
      console.error('Failed to save report config:', error)
    } finally {
      setLoading(false)
    }
  }, [config, isConfigValid, onSave])

  // Handle run report
  const handleRun = useCallback(async () => {
    if (!isConfigValid || !onRun) return
    
    setLoading(true)
    try {
      const result = await onRun(config)
      return result
    } catch (error) {
      console.error('Failed to run report:', error)
    } finally {
      setLoading(false)
    }
  }, [config, isConfigValid, onRun])

  // Handle preview
  const handlePreview = useCallback(async () => {
    if (!isConfigValid || !onPreview) return
    
    setLoading(true)
    try {
      const result = await onPreview(config)
      setPreviewData(result)
      setIsPreviewMode(true)
    } catch (error) {
      console.error('Failed to preview report:', error)
    } finally {
      setLoading(false)
    }
  }, [config, isConfigValid, onPreview])

  // Toggle array item
  const toggleArrayItem = useCallback((array: string[], item: string) => {
    return array.includes(item) 
      ? array.filter(i => i !== item)
      : [...array, item]
  }, [])

  return (
    <div className={`space-y-6 ${className}`}>
      {/* Header */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="flex items-center gap-2">
                <BarChart3 className="h-5 w-5" />
                Audit Report Builder
              </CardTitle>
              <CardDescription>
                Create custom audit reports with advanced filtering and visualization
              </CardDescription>
            </div>
            
            <div className="flex items-center gap-2">
              {onPreview && (
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handlePreview}
                  disabled={!isConfigValid || loading}
                >
                  <Eye className="h-4 w-4 mr-2" />
                  Preview
                </Button>
              )}
              
              {onSave && (
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleSave}
                  disabled={!isConfigValid || loading}
                >
                  <Save className="h-4 w-4 mr-2" />
                  Save
                </Button>
              )}
              
              {onRun && (
                <Button
                  size="sm"
                  onClick={handleRun}
                  disabled={!isConfigValid || loading}
                >
                  <Play className="h-4 w-4 mr-2" />
                  Run Report
                </Button>
              )}
            </div>
          </div>
        </CardHeader>

        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <Label htmlFor="reportName">Report Name</Label>
              <Input
                id="reportName"
                value={config.name}
                onChange={(e) => updateConfig({ name: e.target.value })}
                placeholder="Enter report name..."
                className="mt-2"
              />
            </div>

            <div>
              <Label htmlFor="reportDescription">Description</Label>
              <Input
                id="reportDescription"
                value={config.description || ''}
                onChange={(e) => updateConfig({ description: e.target.value })}
                placeholder="Optional description..."
                className="mt-2"
              />
            </div>
          </div>

          <div className="flex items-center space-x-2 mt-4">
            <Switch
              id="isPublic"
              checked={config.isPublic}
              onCheckedChange={(checked) => updateConfig({ isPublic: checked })}
            />
            <Label htmlFor="isPublic">Make this report public</Label>
          </div>
        </CardContent>
      </Card>

      {/* Configuration Tabs */}
      <Tabs defaultValue="filters" className="w-full">
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="filters">
            <Filter className="h-4 w-4 mr-2" />
            Filters
          </TabsTrigger>
          <TabsTrigger value="grouping">
            <Activity className="h-4 w-4 mr-2" />
            Grouping
          </TabsTrigger>
          <TabsTrigger value="visualization">
            <BarChart3 className="h-4 w-4 mr-2" />
            Visualization
          </TabsTrigger>
          <TabsTrigger value="schedule">
            <Clock className="h-4 w-4 mr-2" />
            Schedule
          </TabsTrigger>
        </TabsList>

        {/* Filters Tab */}
        <TabsContent value="filters" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Data Filters</CardTitle>
              <CardDescription>Configure which audit events to include in the report</CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              {/* Date Range */}
              <div>
                <Label className="text-base font-medium">Date Range</Label>
                <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mt-3">
                  {['last_7_days', 'last_30_days', 'last_90_days', 'custom'].map(range => (
                    <Button
                      key={range}
                      variant={config.filters.dateRange.type === range ? 'default' : 'outline'}
                      size="sm"
                      onClick={() => updateNestedConfig('filters.dateRange', { type: range })}
                    >
                      {range.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}
                    </Button>
                  ))}
                </div>
                
                {config.filters.dateRange.type === 'custom' && (
                  <div className="grid grid-cols-2 gap-4 mt-4">
                    <div>
                      <Label htmlFor="startDate">Start Date</Label>
                      <Input
                        id="startDate"
                        type="date"
                        value={config.filters.dateRange.startDate?.toISOString().split('T')[0] || ''}
                        onChange={(e) => updateNestedConfig('filters.dateRange', { 
                          startDate: e.target.value ? new Date(e.target.value) : undefined 
                        })}
                        className="mt-1"
                      />
                    </div>
                    <div>
                      <Label htmlFor="endDate">End Date</Label>
                      <Input
                        id="endDate"
                        type="date"
                        value={config.filters.dateRange.endDate?.toISOString().split('T')[0] || ''}
                        onChange={(e) => updateNestedConfig('filters.dateRange', { 
                          endDate: e.target.value ? new Date(e.target.value) : undefined 
                        })}
                        className="mt-1"
                      />
                    </div>
                  </div>
                )}
              </div>

              {/* Event Types */}
              <div>
                <Label className="text-base font-medium">Event Types</Label>
                <div className="flex flex-wrap gap-2 mt-3">
                  {EVENT_TYPES.map(type => (
                    <Badge
                      key={type}
                      variant={config.filters.eventTypes?.includes(type) ? 'default' : 'outline'}
                      className="cursor-pointer"
                      onClick={() => updateNestedConfig('filters', {
                        eventTypes: toggleArrayItem(config.filters.eventTypes || [], type)
                      })}
                    >
                      {type}
                    </Badge>
                  ))}
                </div>
              </div>

              {/* Event Categories */}
              <div>
                <Label className="text-base font-medium">Event Categories</Label>
                <div className="flex flex-wrap gap-2 mt-3">
                  {EVENT_CATEGORIES.map(category => (
                    <Badge
                      key={category}
                      variant={config.filters.eventCategories?.includes(category) ? 'default' : 'outline'}
                      className="cursor-pointer"
                      onClick={() => updateNestedConfig('filters', {
                        eventCategories: toggleArrayItem(config.filters.eventCategories || [], category)
                      })}
                    >
                      {category.replace('_', ' ')}
                    </Badge>
                  ))}
                </div>
              </div>

              {/* Entity Types */}
              <div>
                <Label className="text-base font-medium">Entity Types</Label>
                <div className="flex flex-wrap gap-2 mt-3">
                  {ENTITY_TYPES.map(entity => (
                    <Badge
                      key={entity}
                      variant={config.filters.entityTypes?.includes(entity) ? 'default' : 'outline'}
                      className="cursor-pointer"
                      onClick={() => updateNestedConfig('filters', {
                        entityTypes: toggleArrayItem(config.filters.entityTypes || [], entity)
                      })}
                    >
                      {entity}
                    </Badge>
                  ))}
                </div>
              </div>

              {/* Severities */}
              <div>
                <Label className="text-base font-medium">Severities</Label>
                <div className="flex flex-wrap gap-2 mt-3">
                  {SEVERITIES.map(severity => (
                    <Badge
                      key={severity}
                      variant={config.filters.severities?.includes(severity) ? 'default' : 'outline'}
                      className="cursor-pointer"
                      onClick={() => updateNestedConfig('filters', {
                        severities: toggleArrayItem(config.filters.severities || [], severity)
                      })}
                    >
                      {severity}
                    </Badge>
                  ))}
                </div>
              </div>

              {/* Additional Options */}
              <div className="flex items-center space-x-2">
                <Switch
                  id="includePersonalData"
                  checked={config.filters.includePersonalData}
                  onCheckedChange={(checked) => updateNestedConfig('filters', { includePersonalData: checked })}
                />
                <Label htmlFor="includePersonalData">Include personal data entries</Label>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Grouping Tab */}
        <TabsContent value="grouping" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Data Grouping & Sorting</CardTitle>
              <CardDescription>Configure how to group and sort the audit data</CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              {/* Group By */}
              <div>
                <Label className="text-base font-medium">Group By</Label>
                <div className="grid grid-cols-2 md:grid-cols-3 gap-3 mt-3">
                  {GROUPBY_OPTIONS.map(option => (
                    <Button
                      key={option.value}
                      variant={config.groupBy.includes(option.value) ? 'default' : 'outline'}
                      size="sm"
                      onClick={() => updateConfig({
                        groupBy: toggleArrayItem(config.groupBy, option.value)
                      })}
                    >
                      {option.label}
                    </Button>
                  ))}
                </div>
              </div>

              {/* Sort By */}
              <div>
                <Label className="text-base font-medium">Sort By</Label>
                <div className="space-y-2 mt-3">
                  {config.sortBy.map((sort, index) => (
                    <div key={index} className="flex gap-2">
                      <Select
                        value={sort.field}
                        onValueChange={(value) => {
                          const newSortBy = [...config.sortBy]
                          newSortBy[index] = { ...sort, field: value }
                          updateConfig({ sortBy: newSortBy })
                        }}
                      >
                        <SelectTrigger className="flex-1">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {GROUPBY_OPTIONS.map(option => (
                            <SelectItem key={option.value} value={option.value}>
                              {option.label}
                            </SelectItem>
                          ))}
                          <SelectItem value="createdAt">Created Date</SelectItem>
                          <SelectItem value="count">Count</SelectItem>
                        </SelectContent>
                      </Select>
                      
                      <Select
                        value={sort.direction}
                        onValueChange={(value: 'asc' | 'desc') => {
                          const newSortBy = [...config.sortBy]
                          newSortBy[index] = { ...sort, direction: value }
                          updateConfig({ sortBy: newSortBy })
                        }}
                      >
                        <SelectTrigger className="w-32">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="asc">Ascending</SelectItem>
                          <SelectItem value="desc">Descending</SelectItem>
                        </SelectContent>
                      </Select>
                      
                      {config.sortBy.length > 1 && (
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => {
                            const newSortBy = config.sortBy.filter((_, i) => i !== index)
                            updateConfig({ sortBy: newSortBy })
                          }}
                        >
                          Remove
                        </Button>
                      )}
                    </div>
                  ))}
                  
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => updateConfig({
                      sortBy: [...config.sortBy, { field: 'createdAt', direction: 'desc' }]
                    })}
                  >
                    Add Sort Field
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Visualization Tab */}
        <TabsContent value="visualization" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Visualization Settings</CardTitle>
              <CardDescription>Configure how the report data is displayed</CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              {/* Chart Type */}
              <div>
                <Label className="text-base font-medium">Chart Type</Label>
                <div className="grid grid-cols-2 md:grid-cols-3 gap-3 mt-3">
                  {CHART_TYPES.map(chart => {
                    const IconComponent = chart.icon
                    return (
                      <Button
                        key={chart.value}
                        variant={config.visualization.chartType === chart.value ? 'default' : 'outline'}
                        size="sm"
                        onClick={() => updateNestedConfig('visualization', { chartType: chart.value })}
                        className="flex items-center gap-2"
                      >
                        <IconComponent className="h-4 w-4" />
                        {chart.label}
                      </Button>
                    )
                  })}
                </div>
              </div>

              {/* Additional Options */}
              <div className="space-y-3">
                <div className="flex items-center space-x-2">
                  <Switch
                    id="showTrends"
                    checked={config.visualization.showTrends}
                    onCheckedChange={(checked) => updateNestedConfig('visualization', { showTrends: checked })}
                  />
                  <Label htmlFor="showTrends">Show trend analysis</Label>
                </div>
                
                <div className="flex items-center space-x-2">
                  <Switch
                    id="showComparisons"
                    checked={config.visualization.showComparisons}
                    onCheckedChange={(checked) => updateNestedConfig('visualization', { showComparisons: checked })}
                  />
                  <Label htmlFor="showComparisons">Show period comparisons</Label>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Schedule Tab */}
        <TabsContent value="schedule" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Report Scheduling</CardTitle>
              <CardDescription>Set up automated report generation and delivery</CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="flex items-center space-x-2">
                <Switch
                  id="scheduleEnabled"
                  checked={config.schedule?.enabled || false}
                  onCheckedChange={(checked) => updateNestedConfig('schedule', { enabled: checked })}
                />
                <Label htmlFor="scheduleEnabled">Enable scheduled reports</Label>
              </div>

              {config.schedule?.enabled && (
                <div className="space-y-4">
                  <div>
                    <Label htmlFor="frequency">Frequency</Label>
                    <Select
                      value={config.schedule.frequency}
                      onValueChange={(value: 'daily' | 'weekly' | 'monthly') => 
                        updateNestedConfig('schedule', { frequency: value })
                      }
                    >
                      <SelectTrigger className="mt-2">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="daily">Daily</SelectItem>
                        <SelectItem value="weekly">Weekly</SelectItem>
                        <SelectItem value="monthly">Monthly</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  <div>
                    <Label htmlFor="format">Export Format</Label>
                    <Select
                      value={config.schedule.format}
                      onValueChange={(value: 'pdf' | 'csv' | 'json') => 
                        updateNestedConfig('schedule', { format: value })
                      }
                    >
                      <SelectTrigger className="mt-2">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="pdf">PDF Report</SelectItem>
                        <SelectItem value="csv">CSV Data</SelectItem>
                        <SelectItem value="json">JSON Data</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  <div>
                    <Label htmlFor="recipients">Email Recipients</Label>
                    <Textarea
                      id="recipients"
                      value={config.schedule.recipients.join('\n')}
                      onChange={(e) => updateNestedConfig('schedule', {
                        recipients: e.target.value.split('\n').filter(email => email.trim())
                      })}
                      placeholder="Enter email addresses, one per line..."
                      className="mt-2"
                      rows={4}
                    />
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* Preview */}
      {isPreviewMode && previewData && (
        <Card>
          <CardHeader>
            <CardTitle>Report Preview</CardTitle>
            <CardDescription>Preview of the report with current configuration</CardDescription>
          </CardHeader>
          <CardContent>
            <ScrollArea className="h-[400px]">
              <pre className="text-sm">{JSON.stringify(previewData, null, 2)}</pre>
            </ScrollArea>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

export default AuditReportBuilder