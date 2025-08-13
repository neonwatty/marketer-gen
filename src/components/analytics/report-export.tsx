'use client'

import React, { useState, useCallback } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Checkbox } from '@/components/ui/checkbox'
import { Separator } from '@/components/ui/separator'
import { DateRangeFilter, type DateRange } from './date-range-filter'
import {
  Download,
  FileText,
  Image,
  BarChart3,
  Calendar,
  Users,
  Settings,
  Mail,
  Clock,
  CheckCircle,
  AlertCircle,
  Loader2,
  Share2,
  Eye,
  Copy,
  ExternalLink,
  Archive,
  Trash2,
  Edit,
  Bookmark
} from 'lucide-react'

interface ReportTemplate {
  id: string
  name: string
  description: string
  category: 'analytics' | 'productivity' | 'collaboration' | 'custom'
  sections: ReportSection[]
  schedule?: ReportSchedule
  recipients?: string[]
  format: ReportFormat[]
  lastGenerated?: Date
  status: 'active' | 'draft' | 'archived'
}

interface ReportSection {
  id: string
  name: string
  type: 'chart' | 'table' | 'kpi' | 'text' | 'image'
  config: Record<string, any>
  include: boolean
}

interface ReportSchedule {
  frequency: 'manual' | 'daily' | 'weekly' | 'monthly' | 'quarterly'
  dayOfWeek?: number
  dayOfMonth?: number
  time?: string
  timezone?: string
  enabled: boolean
}

interface ReportFormat {
  type: 'pdf' | 'excel' | 'csv' | 'powerpoint' | 'json' | 'html'
  options: Record<string, any>
}

interface ExportJob {
  id: string
  templateId: string
  templateName: string
  format: string
  dateRange: DateRange
  status: 'pending' | 'processing' | 'completed' | 'failed'
  progress: number
  createdAt: Date
  completedAt?: Date
  downloadUrl?: string
  error?: string
}

const mockReportTemplates: ReportTemplate[] = [
  {
    id: '1',
    name: 'Weekly Team Performance',
    description: 'Comprehensive weekly overview of team productivity and collaboration metrics',
    category: 'productivity',
    sections: [
      { id: '1', name: 'Executive Summary', type: 'text', config: {}, include: true },
      { id: '2', name: 'Team Productivity Chart', type: 'chart', config: { chartType: 'bar', metric: 'productivity' }, include: true },
      { id: '3', name: 'Task Completion Metrics', type: 'kpi', config: { metrics: ['completed', 'inProgress', 'overdue'] }, include: true },
      { id: '4', name: 'Collaboration Frequency', type: 'chart', config: { chartType: 'line', metric: 'collaboration' }, include: true },
      { id: '5', name: 'Individual Performance', type: 'table', config: { columns: ['name', 'productivity', 'quality'] }, include: false }
    ],
    schedule: {
      frequency: 'weekly',
      dayOfWeek: 1,
      time: '09:00',
      timezone: 'UTC',
      enabled: true
    },
    recipients: ['manager@company.com', 'team-lead@company.com'],
    format: [{ type: 'pdf', options: { orientation: 'portrait', includeCharts: true } }],
    lastGenerated: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
    status: 'active'
  },
  {
    id: '2',
    name: 'Monthly Collaboration Analysis',
    description: 'Deep dive into team collaboration patterns and communication effectiveness',
    category: 'collaboration',
    sections: [
      { id: '1', name: 'Collaboration Overview', type: 'kpi', config: { metrics: ['totalInteractions', 'responseTime', 'engagement'] }, include: true },
      { id: '2', name: 'Channel Effectiveness', type: 'chart', config: { chartType: 'pie', metric: 'channels' }, include: true },
      { id: '3', name: 'Team Network Analysis', type: 'chart', config: { chartType: 'network', metric: 'interactions' }, include: true },
      { id: '4', name: 'Bottleneck Identification', type: 'table', config: { columns: ['bottleneck', 'impact', 'solution'] }, include: true },
      { id: '5', name: 'Recommendations', type: 'text', config: { aiGenerated: true }, include: true }
    ],
    format: [
      { type: 'pdf', options: { orientation: 'landscape', includeCharts: true } },
      { type: 'powerpoint', options: { template: 'corporate', includeNotes: true } }
    ],
    lastGenerated: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
    status: 'active'
  },
  {
    id: '3',
    name: 'Quarterly Executive Dashboard',
    description: 'High-level quarterly metrics for executive review and strategic planning',
    category: 'analytics',
    sections: [
      { id: '1', name: 'Key Performance Indicators', type: 'kpi', config: { metrics: ['productivity', 'quality', 'efficiency', 'satisfaction'] }, include: true },
      { id: '2', name: 'Trend Analysis', type: 'chart', config: { chartType: 'line', metric: 'trends', period: 'quarterly' }, include: true },
      { id: '3', name: 'Team Comparison', type: 'chart', config: { chartType: 'radar', metric: 'comparison' }, include: true },
      { id: '4', name: 'ROI Analysis', type: 'table', config: { columns: ['initiative', 'investment', 'return', 'roi'] }, include: true },
      { id: '5', name: 'Strategic Recommendations', type: 'text', config: { executiveSummary: true }, include: true }
    ],
    schedule: {
      frequency: 'quarterly',
      dayOfMonth: 1,
      time: '08:00',
      timezone: 'UTC',
      enabled: true
    },
    recipients: ['ceo@company.com', 'cto@company.com', 'coo@company.com'],
    format: [{ type: 'powerpoint', options: { template: 'executive', includeNotes: false } }],
    lastGenerated: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000),
    status: 'active'
  },
  {
    id: '4',
    name: 'Custom Workflow Analysis',
    description: 'Customizable workflow performance analysis with bottleneck identification',
    category: 'custom',
    sections: [
      { id: '1', name: 'Workflow Overview', type: 'kpi', config: { metrics: ['totalWorkflows', 'averageTime', 'successRate'] }, include: true },
      { id: '2', name: 'Bottleneck Analysis', type: 'chart', config: { chartType: 'funnel', metric: 'bottlenecks' }, include: true },
      { id: '3', name: 'Performance Trends', type: 'chart', config: { chartType: 'area', metric: 'performance' }, include: false },
      { id: '4', name: 'Optimization Opportunities', type: 'table', config: { columns: ['opportunity', 'impact', 'effort', 'priority'] }, include: true }
    ],
    format: [
      { type: 'pdf', options: { orientation: 'portrait', includeCharts: true } },
      { type: 'excel', options: { includeRawData: true, multipleSheets: true } }
    ],
    status: 'draft'
  }
]

const mockExportJobs: ExportJob[] = [
  {
    id: '1',
    templateId: '1',
    templateName: 'Weekly Team Performance',
    format: 'PDF',
    dateRange: {
      from: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
      to: new Date(),
      label: 'Last 7 days'
    },
    status: 'completed',
    progress: 100,
    createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
    completedAt: new Date(Date.now() - 1 * 60 * 60 * 1000),
    downloadUrl: '/reports/weekly-performance-2024-06.pdf'
  },
  {
    id: '2',
    templateId: '2',
    templateName: 'Monthly Collaboration Analysis',
    format: 'PowerPoint',
    dateRange: {
      from: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
      to: new Date(),
      label: 'Last 30 days'
    },
    status: 'processing',
    progress: 65,
    createdAt: new Date(Date.now() - 15 * 60 * 1000)
  },
  {
    id: '3',
    templateId: '1',
    templateName: 'Weekly Team Performance',
    format: 'Excel',
    dateRange: {
      from: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000),
      to: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
      label: 'Last week'
    },
    status: 'failed',
    progress: 0,
    createdAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000),
    error: 'Data source temporarily unavailable'
  }
]

export const ReportExport: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'templates' | 'generate' | 'jobs' | 'schedule'>('templates')
  const [selectedTemplate, setSelectedTemplate] = useState<string>('')
  const [customDateRange, setCustomDateRange] = useState<DateRange>()
  const [exportFormat, setExportFormat] = useState<string>('pdf')
  const [includeCharts, setIncludeCharts] = useState(true)
  const [includeRawData, setIncludeRawData] = useState(false)
  const [reportTitle, setReportTitle] = useState('')
  const [reportDescription, setReportDescription] = useState('')
  const [selectedSections, setSelectedSections] = useState<string[]>([])
  const [isGenerating, setIsGenerating] = useState(false)
  const [exportJobs, setExportJobs] = useState<ExportJob[]>(mockExportJobs)

  const handleGenerateReport = useCallback(async () => {
    if (!selectedTemplate || !customDateRange) return

    setIsGenerating(true)
    const template = mockReportTemplates.find(t => t.id === selectedTemplate)
    if (!template) return

    const newJob: ExportJob = {
      id: Date.now().toString(),
      templateId: selectedTemplate,
      templateName: template.name,
      format: exportFormat.toUpperCase(),
      dateRange: customDateRange,
      status: 'processing',
      progress: 0,
      createdAt: new Date()
    }

    setExportJobs(prev => [newJob, ...prev])

    // Simulate report generation
    const progressInterval = setInterval(() => {
      setExportJobs(prev => prev.map(job => 
        job.id === newJob.id 
          ? { ...job, progress: Math.min(job.progress + Math.random() * 30, 100) }
          : job
      ))
    }, 500)

    setTimeout(() => {
      clearInterval(progressInterval)
      setExportJobs(prev => prev.map(job => 
        job.id === newJob.id 
          ? { 
              ...job, 
              status: 'completed',
              progress: 100,
              completedAt: new Date(),
              downloadUrl: `/reports/${template.name.toLowerCase().replace(/\s+/g, '-')}-${Date.now()}.${exportFormat}`
            }
          : job
      ))
      setIsGenerating(false)
    }, 3000)
  }, [selectedTemplate, customDateRange, exportFormat])

  const handleSectionToggle = (sectionId: string) => {
    setSelectedSections(prev => 
      prev.includes(sectionId) 
        ? prev.filter(id => id !== sectionId)
        : [...prev, sectionId]
    )
  }

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'completed':
        return { variant: 'default' as const, label: 'Completed', icon: <CheckCircle className="h-3 w-3" />, color: 'text-green-600' }
      case 'processing':
        return { variant: 'secondary' as const, label: 'Processing', icon: <Loader2 className="h-3 w-3 animate-spin" />, color: 'text-blue-600' }
      case 'pending':
        return { variant: 'outline' as const, label: 'Pending', icon: <Clock className="h-3 w-3" />, color: 'text-yellow-600' }
      case 'failed':
        return { variant: 'destructive' as const, label: 'Failed', icon: <AlertCircle className="h-3 w-3" />, color: 'text-red-600' }
      default:
        return { variant: 'outline' as const, label: 'Unknown', icon: <AlertCircle className="h-3 w-3" />, color: 'text-gray-600' }
    }
  }

  const getCategoryIcon = (category: string) => {
    switch (category) {
      case 'analytics':
        return <BarChart3 className="h-4 w-4" />
      case 'productivity':
        return <CheckCircle className="h-4 w-4" />
      case 'collaboration':
        return <Users className="h-4 w-4" />
      case 'custom':
        return <Settings className="h-4 w-4" />
      default:
        return <FileText className="h-4 w-4" />
    }
  }

  const getCategoryColor = (category: string) => {
    switch (category) {
      case 'analytics':
        return 'bg-blue-100 text-blue-700'
      case 'productivity':
        return 'bg-green-100 text-green-700'
      case 'collaboration':
        return 'bg-purple-100 text-purple-700'
      case 'custom':
        return 'bg-orange-100 text-orange-700'
      default:
        return 'bg-gray-100 text-gray-700'
    }
  }

  const getFormatIcon = (format: string) => {
    switch (format.toLowerCase()) {
      case 'pdf':
        return <FileText className="h-4 w-4" />
      case 'excel':
      case 'csv':
        return <BarChart3 className="h-4 w-4" />
      case 'powerpoint':
        return <Image className="h-4 w-4" />
      case 'html':
        return <ExternalLink className="h-4 w-4" />
      default:
        return <Download className="h-4 w-4" />
    }
  }

  const formatFileSize = (sizeInMB: number) => {
    if (sizeInMB < 1) return `${(sizeInMB * 1000).toFixed(0)} KB`
    return `${sizeInMB.toFixed(1)} MB`
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight flex items-center gap-2">
            <Download className="h-8 w-8" />
            Report Export
          </h1>
          <p className="text-muted-foreground">
            Generate, schedule, and export team analytics reports in various formats
          </p>
        </div>
        
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm">
            <Settings className="h-4 w-4 mr-2" />
            Settings
          </Button>
          
          <Button variant="outline" size="sm">
            <Archive className="h-4 w-4 mr-2" />
            Archive
          </Button>
          
          <Button size="sm">
            <FileText className="h-4 w-4 mr-2" />
            New Template
          </Button>
        </div>
      </div>

      {/* Main Content Tabs */}
      <Tabs value={activeTab} onValueChange={(value: any) => setActiveTab(value)}>
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="templates">
            <FileText className="h-4 w-4 mr-2" />
            Templates
          </TabsTrigger>
          <TabsTrigger value="generate">
            <Download className="h-4 w-4 mr-2" />
            Generate
          </TabsTrigger>
          <TabsTrigger value="jobs">
            <Activity className="h-4 w-4 mr-2" />
            Export Jobs
          </TabsTrigger>
          <TabsTrigger value="schedule">
            <Calendar className="h-4 w-4 mr-2" />
            Scheduled
          </TabsTrigger>
        </TabsList>

        {/* Templates Tab */}
        <TabsContent value="templates" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {mockReportTemplates.map(template => (
              <Card key={template.id}>
                <CardHeader>
                  <div className="flex items-start justify-between">
                    <div className="flex items-start gap-3">
                      <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${getCategoryColor(template.category)}`}>
                        {getCategoryIcon(template.category)}
                      </div>
                      <div>
                        <CardTitle className="text-lg">{template.name}</CardTitle>
                        <CardDescription>{template.description}</CardDescription>
                      </div>
                    </div>
                    <Badge 
                      variant={template.status === 'active' ? 'default' : template.status === 'draft' ? 'outline' : 'secondary'}
                      className="capitalize"
                    >
                      {template.status}
                    </Badge>
                  </div>
                </CardHeader>
                <CardContent className="space-y-4">
                  {/* Template Stats */}
                  <div className="grid grid-cols-3 gap-4 text-sm">
                    <div>
                      <div className="text-muted-foreground">Sections</div>
                      <div className="font-medium">{template.sections.length}</div>
                    </div>
                    <div>
                      <div className="text-muted-foreground">Formats</div>
                      <div className="font-medium">{template.format.length}</div>
                    </div>
                    <div>
                      <div className="text-muted-foreground">Recipients</div>
                      <div className="font-medium">{template.recipients?.length || 0}</div>
                    </div>
                  </div>

                  <Separator />

                  {/* Sections Preview */}
                  <div>
                    <Label className="text-sm font-medium">Included Sections</Label>
                    <div className="mt-2 space-y-1">
                      {template.sections.filter(section => section.include).map(section => (
                        <div key={section.id} className="flex items-center gap-2 text-sm">
                          <CheckCircle className="h-3 w-3 text-green-600" />
                          <span>{section.name}</span>
                          <Badge variant="outline" className="text-xs capitalize">
                            {section.type}
                          </Badge>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Last Generated */}
                  {template.lastGenerated && (
                    <div className="text-xs text-muted-foreground">
                      Last generated: {template.lastGenerated.toLocaleDateString()}
                    </div>
                  )}

                  {/* Actions */}
                  <div className="flex items-center gap-2 pt-2">
                    <Button 
                      size="sm"
                      onClick={() => {
                        setSelectedTemplate(template.id)
                        setActiveTab('generate')
                      }}
                    >
                      <Download className="h-4 w-4 mr-2" />
                      Generate
                    </Button>
                    <Button variant="outline" size="sm">
                      <Edit className="h-4 w-4 mr-2" />
                      Edit
                    </Button>
                    <Button variant="outline" size="sm">
                      <Copy className="h-4 w-4 mr-2" />
                      Duplicate
                    </Button>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </TabsContent>

        {/* Generate Tab */}
        <TabsContent value="generate" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Report Configuration */}
            <Card>
              <CardHeader>
                <CardTitle>Report Configuration</CardTitle>
                <CardDescription>Configure your report parameters and settings</CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                {/* Template Selection */}
                <div className="space-y-2">
                  <Label>Report Template</Label>
                  <Select value={selectedTemplate} onValueChange={setSelectedTemplate}>
                    <SelectTrigger>
                      <SelectValue placeholder="Select a report template" />
                    </SelectTrigger>
                    <SelectContent>
                      {mockReportTemplates.map(template => (
                        <SelectItem key={template.id} value={template.id}>
                          <div className="flex items-center gap-2">
                            {getCategoryIcon(template.category)}
                            {template.name}
                          </div>
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {/* Date Range */}
                <div className="space-y-2">
                  <Label>Date Range</Label>
                  <DateRangeFilter
                    value={customDateRange}
                    onChange={setCustomDateRange}
                  />
                </div>

                {/* Export Format */}
                <div className="space-y-2">
                  <Label>Export Format</Label>
                  <Select value={exportFormat} onValueChange={setExportFormat}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="pdf">
                        <div className="flex items-center gap-2">
                          <FileText className="h-4 w-4" />
                          PDF Document
                        </div>
                      </SelectItem>
                      <SelectItem value="excel">
                        <div className="flex items-center gap-2">
                          <BarChart3 className="h-4 w-4" />
                          Excel Workbook
                        </div>
                      </SelectItem>
                      <SelectItem value="powerpoint">
                        <div className="flex items-center gap-2">
                          <Image className="h-4 w-4" />
                          PowerPoint Presentation
                        </div>
                      </SelectItem>
                      <SelectItem value="csv">
                        <div className="flex items-center gap-2">
                          <BarChart3 className="h-4 w-4" />
                          CSV Data
                        </div>
                      </SelectItem>
                      <SelectItem value="html">
                        <div className="flex items-center gap-2">
                          <ExternalLink className="h-4 w-4" />
                          HTML Report
                        </div>
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                {/* Custom Title */}
                <div className="space-y-2">
                  <Label>Custom Title (optional)</Label>
                  <Input
                    value={reportTitle}
                    onChange={(e) => setReportTitle(e.target.value)}
                    placeholder="Enter custom report title"
                  />
                </div>

                {/* Export Options */}
                <div className="space-y-3">
                  <Label>Export Options</Label>
                  <div className="space-y-2">
                    <div className="flex items-center space-x-2">
                      <Checkbox 
                        id="include-charts" 
                        checked={includeCharts}
                        onCheckedChange={setIncludeCharts}
                      />
                      <Label htmlFor="include-charts" className="text-sm">
                        Include charts and visualizations
                      </Label>
                    </div>
                    <div className="flex items-center space-x-2">
                      <Checkbox 
                        id="include-raw-data" 
                        checked={includeRawData}
                        onCheckedChange={setIncludeRawData}
                      />
                      <Label htmlFor="include-raw-data" className="text-sm">
                        Include raw data tables
                      </Label>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Section Selection */}
            {selectedTemplate && (
              <Card>
                <CardHeader>
                  <CardTitle>Report Sections</CardTitle>
                  <CardDescription>Choose which sections to include in your report</CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-3">
                    {mockReportTemplates
                      .find(t => t.id === selectedTemplate)
                      ?.sections.map(section => (
                        <div key={section.id} className="flex items-center space-x-3 p-3 border rounded-lg">
                          <Checkbox
                            id={`section-${section.id}`}
                            checked={selectedSections.includes(section.id) || section.include}
                            onCheckedChange={() => handleSectionToggle(section.id)}
                          />
                          <div className="flex-1">
                            <Label htmlFor={`section-${section.id}`} className="font-medium">
                              {section.name}
                            </Label>
                            <div className="flex items-center gap-2 mt-1">
                              <Badge variant="outline" className="text-xs capitalize">
                                {section.type}
                              </Badge>
                              {section.include && (
                                <Badge variant="secondary" className="text-xs">
                                  Default
                                </Badge>
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                  </div>
                </CardContent>
              </Card>
            )}
          </div>

          {/* Generate Button */}
          <div className="flex justify-center">
            <Button
              size="lg"
              onClick={handleGenerateReport}
              disabled={!selectedTemplate || !customDateRange || isGenerating}
              className="min-w-[200px]"
            >
              {isGenerating ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Generating Report...
                </>
              ) : (
                <>
                  <Download className="h-4 w-4 mr-2" />
                  Generate Report
                </>
              )}
            </Button>
          </div>
        </TabsContent>

        {/* Export Jobs Tab */}
        <TabsContent value="jobs" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Export Jobs</CardTitle>
              <CardDescription>Track the status of your report generation jobs</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {exportJobs.map(job => {
                  const statusBadge = getStatusBadge(job.status)
                  return (
                    <div key={job.id} className="flex items-center gap-4 p-4 border rounded-lg">
                      <div className="w-12 h-12 rounded-lg bg-muted/50 flex items-center justify-center">
                        {getFormatIcon(job.format)}
                      </div>
                      
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-2">
                          <h4 className="font-medium">{job.templateName}</h4>
                          <Badge variant={statusBadge.variant} className="text-xs">
                            {statusBadge.icon}
                            {statusBadge.label}
                          </Badge>
                          <Badge variant="outline" className="text-xs">
                            {job.format}
                          </Badge>
                        </div>
                        
                        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm text-muted-foreground">
                          <div>
                            <div>Date Range</div>
                            <div className="font-medium text-foreground">
                              {job.dateRange.label || `${job.dateRange.from.toLocaleDateString()} - ${job.dateRange.to.toLocaleDateString()}`}
                            </div>
                          </div>
                          <div>
                            <div>Created</div>
                            <div className="font-medium text-foreground">
                              {job.createdAt.toLocaleString()}
                            </div>
                          </div>
                          <div>
                            <div>Progress</div>
                            <div className="font-medium text-foreground">{job.progress}%</div>
                          </div>
                          {job.completedAt && (
                            <div>
                              <div>Completed</div>
                              <div className="font-medium text-foreground">
                                {job.completedAt.toLocaleString()}
                              </div>
                            </div>
                          )}
                        </div>
                        
                        {job.status === 'processing' && (
                          <div className="mt-3">
                            <div className="flex justify-between text-xs text-muted-foreground mb-1">
                              <span>Processing...</span>
                              <span>{job.progress}%</span>
                            </div>
                            <div className="w-full bg-gray-200 rounded-full h-2">
                              <div 
                                className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                                style={{ width: `${job.progress}%` }}
                              />
                            </div>
                          </div>
                        )}
                        
                        {job.error && (
                          <div className="mt-2 text-xs text-red-600 bg-red-50 p-2 rounded">
                            Error: {job.error}
                          </div>
                        )}
                      </div>
                      
                      <div className="flex items-center gap-2">
                        {job.status === 'completed' && job.downloadUrl && (
                          <>
                            <Button variant="outline" size="sm">
                              <Eye className="h-4 w-4 mr-2" />
                              Preview
                            </Button>
                            <Button size="sm">
                              <Download className="h-4 w-4 mr-2" />
                              Download
                            </Button>
                          </>
                        )}
                        {job.status === 'processing' && (
                          <Button variant="outline" size="sm">
                            Cancel
                          </Button>
                        )}
                        {job.status === 'failed' && (
                          <Button variant="outline" size="sm">
                            Retry
                          </Button>
                        )}
                        <Button variant="ghost" size="sm">
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </div>
                  )
                })}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Scheduled Tab */}
        <TabsContent value="schedule" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {mockReportTemplates
              .filter(template => template.schedule)
              .map(template => (
                <Card key={template.id}>
                  <CardHeader>
                    <div className="flex items-start justify-between">
                      <div className="flex items-start gap-3">
                        <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${getCategoryColor(template.category)}`}>
                          {getCategoryIcon(template.category)}
                        </div>
                        <div>
                          <CardTitle className="text-lg">{template.name}</CardTitle>
                          <CardDescription>{template.description}</CardDescription>
                        </div>
                      </div>
                      <Badge 
                        variant={template.schedule?.enabled ? 'default' : 'outline'}
                        className="capitalize"
                      >
                        {template.schedule?.enabled ? 'Active' : 'Disabled'}
                      </Badge>
                    </div>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    {/* Schedule Details */}
                    <div className="grid grid-cols-2 gap-4 text-sm">
                      <div>
                        <div className="text-muted-foreground">Frequency</div>
                        <div className="font-medium capitalize">{template.schedule?.frequency}</div>
                      </div>
                      <div>
                        <div className="text-muted-foreground">Time</div>
                        <div className="font-medium">{template.schedule?.time || 'Not set'}</div>
                      </div>
                      {template.schedule?.dayOfWeek && (
                        <div>
                          <div className="text-muted-foreground">Day of Week</div>
                          <div className="font-medium">
                            {['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][template.schedule.dayOfWeek]}
                          </div>
                        </div>
                      )}
                      {template.schedule?.dayOfMonth && (
                        <div>
                          <div className="text-muted-foreground">Day of Month</div>
                          <div className="font-medium">{template.schedule.dayOfMonth}</div>
                        </div>
                      )}
                    </div>

                    <Separator />

                    {/* Recipients */}
                    <div>
                      <Label className="text-sm font-medium">Recipients</Label>
                      <div className="mt-2 space-y-1">
                        {template.recipients?.map(recipient => (
                          <div key={recipient} className="flex items-center gap-2 text-sm">
                            <Mail className="h-3 w-3 text-muted-foreground" />
                            <span>{recipient}</span>
                          </div>
                        )) || <div className="text-sm text-muted-foreground">No recipients configured</div>}
                      </div>
                    </div>

                    {/* Next Run */}
                    <div className="text-xs text-muted-foreground">
                      Next scheduled run: {template.lastGenerated ? 
                        new Date(template.lastGenerated.getTime() + 7 * 24 * 60 * 60 * 1000).toLocaleString() : 
                        'Not scheduled'
                      }
                    </div>

                    {/* Actions */}
                    <div className="flex items-center gap-2 pt-2">
                      <Button size="sm">
                        <Settings className="h-4 w-4 mr-2" />
                        Configure
                      </Button>
                      <Button variant="outline" size="sm">
                        <Calendar className="h-4 w-4 mr-2" />
                        Run Now
                      </Button>
                      <Button 
                        variant={template.schedule?.enabled ? 'outline' : 'default'} 
                        size="sm"
                      >
                        {template.schedule?.enabled ? 'Disable' : 'Enable'}
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              ))}
          </div>
        </TabsContent>
      </Tabs>
    </div>
  )
}

export default ReportExport