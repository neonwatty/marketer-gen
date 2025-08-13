'use client'

import React, { useState, useEffect, useCallback, useMemo } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible'
import { 
  Search,
  Filter,
  Download,
  RefreshCw,
  ChevronDown,
  ChevronRight,
  Calendar,
  User,
  Activity,
  Shield,
  AlertTriangle,
  Info,
  Clock,
  MapPin,
  Database,
  Eye,
  EyeOff,
  MoreHorizontal
} from 'lucide-react'
import { format } from 'date-fns'

// Types for audit log data
export interface AuditLogEntry {
  id: string
  createdAt: Date
  eventType: string
  eventCategory: string
  entityType: string
  entityId: string
  action: string
  description: string
  userId?: string
  username?: string
  userRole?: string
  sessionId?: string
  ipAddress?: string
  userAgent?: string
  referrer?: string
  requestId?: string
  oldValues?: Record<string, any>
  newValues?: Record<string, any>
  changedFields?: string[]
  hostname?: string
  environment?: string
  applicationVersion?: string
  metadata?: Record<string, any>
  tags?: string[]
  severity: string
  isPersonalData: boolean
  retentionDays?: number
  anonymizedAt?: Date
  duration?: number
}

export interface AuditFilters {
  search?: string
  eventType?: string
  eventCategory?: string
  entityType?: string
  severity?: string
  userId?: string
  dateFrom?: Date
  dateTo?: Date
  environment?: string
  hasChanges?: boolean
  isPersonalData?: boolean
}

export interface AuditLogViewerProps {
  initialData?: AuditLogEntry[]
  onRefresh?: () => Promise<AuditLogEntry[]>
  onExport?: (filters: AuditFilters) => Promise<void>
  onViewDetails?: (entry: AuditLogEntry) => void
  showExport?: boolean
  showAdvancedFilters?: boolean
  maxEntries?: number
}

const SEVERITY_COLORS = {
  DEBUG: 'bg-gray-100 text-gray-800',
  INFO: 'bg-blue-100 text-blue-800',
  NOTICE: 'bg-green-100 text-green-800',
  WARNING: 'bg-yellow-100 text-yellow-800',
  ERROR: 'bg-red-100 text-red-800',
  CRITICAL: 'bg-red-100 text-red-900',
  ALERT: 'bg-purple-100 text-purple-800',
  EMERGENCY: 'bg-red-200 text-red-900'
}

const EVENT_TYPE_ICONS = {
  CREATE: '✨',
  UPDATE: '📝',
  DELETE: '🗑️',
  VIEW: '👁️',
  APPROVE: '✅',
  REJECT: '❌',
  LOGIN: '🔑',
  LOGOUT: '🚪',
  EXPORT: '📤',
  IMPORT: '📥',
  SECURITY_EVENT: '🛡️',
  API_CALL: '🔌',
  SYSTEM_EVENT: '⚙️'
}

export const AuditLogViewer: React.FC<AuditLogViewerProps> = ({
  initialData = [],
  onRefresh,
  onExport,
  onViewDetails,
  showExport = true,
  showAdvancedFilters = true,
  maxEntries = 1000
}) => {
  const [auditLogs, setAuditLogs] = useState<AuditLogEntry[]>(initialData)
  const [loading, setLoading] = useState(false)
  const [expandedEntries, setExpandedEntries] = useState<Set<string>>(new Set())
  const [showPersonalData, setShowPersonalData] = useState(false)
  
  // Filter state
  const [filters, setFilters] = useState<AuditFilters>({})
  const [showAdvanced, setShowAdvanced] = useState(false)

  // Filtered and sorted data
  const filteredLogs = useMemo(() => {
    let filtered = auditLogs

    // Basic text search
    if (filters.search) {
      const searchLower = filters.search.toLowerCase()
      filtered = filtered.filter(log =>
        log.description.toLowerCase().includes(searchLower) ||
        log.action.toLowerCase().includes(searchLower) ||
        log.username?.toLowerCase().includes(searchLower) ||
        log.entityId.toLowerCase().includes(searchLower)
      )
    }

    // Filter by event type
    if (filters.eventType) {
      filtered = filtered.filter(log => log.eventType === filters.eventType)
    }

    // Filter by event category
    if (filters.eventCategory) {
      filtered = filtered.filter(log => log.eventCategory === filters.eventCategory)
    }

    // Filter by entity type
    if (filters.entityType) {
      filtered = filtered.filter(log => log.entityType === filters.entityType)
    }

    // Filter by severity
    if (filters.severity) {
      filtered = filtered.filter(log => log.severity === filters.severity)
    }

    // Filter by user
    if (filters.userId) {
      filtered = filtered.filter(log => log.userId === filters.userId)
    }

    // Filter by date range
    if (filters.dateFrom) {
      filtered = filtered.filter(log => new Date(log.createdAt) >= filters.dateFrom!)
    }
    if (filters.dateTo) {
      filtered = filtered.filter(log => new Date(log.createdAt) <= filters.dateTo!)
    }

    // Filter by environment
    if (filters.environment) {
      filtered = filtered.filter(log => log.environment === filters.environment)
    }

    // Filter by changes presence
    if (filters.hasChanges !== undefined) {
      filtered = filtered.filter(log => 
        filters.hasChanges ? (log.changedFields && log.changedFields.length > 0) : true
      )
    }

    // Filter by personal data
    if (filters.isPersonalData !== undefined) {
      filtered = filtered.filter(log => log.isPersonalData === filters.isPersonalData)
    }

    // Hide personal data entries if not explicitly shown
    if (!showPersonalData) {
      filtered = filtered.filter(log => !log.isPersonalData || log.anonymizedAt)
    }

    // Sort by creation date (newest first)
    return filtered
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, maxEntries)
  }, [auditLogs, filters, showPersonalData, maxEntries])

  // Refresh data
  const handleRefresh = useCallback(async () => {
    if (!onRefresh) return
    
    setLoading(true)
    try {
      const newData = await onRefresh()
      setAuditLogs(newData)
    } catch (error) {
      console.error('Failed to refresh audit logs:', error)
    } finally {
      setLoading(false)
    }
  }, [onRefresh])

  // Toggle entry expansion
  const toggleExpanded = useCallback((entryId: string) => {
    setExpandedEntries(prev => {
      const newSet = new Set(prev)
      if (newSet.has(entryId)) {
        newSet.delete(entryId)
      } else {
        newSet.add(entryId)
      }
      return newSet
    })
  }, [])

  // Format JSON data for display
  const formatJsonValue = (value: any): string => {
    if (typeof value === 'object' && value !== null) {
      return JSON.stringify(value, null, 2)
    }
    return String(value)
  }

  // Get unique values for filter dropdowns
  const uniqueValues = useMemo(() => {
    return {
      eventTypes: [...new Set(auditLogs.map(log => log.eventType))].sort(),
      eventCategories: [...new Set(auditLogs.map(log => log.eventCategory))].sort(),
      entityTypes: [...new Set(auditLogs.map(log => log.entityType))].sort(),
      severities: [...new Set(auditLogs.map(log => log.severity))].sort(),
      environments: [...new Set(auditLogs.map(log => log.environment).filter(Boolean))].sort(),
      users: [...new Set(auditLogs.map(log => log.username).filter(Boolean))].sort()
    }
  }, [auditLogs])

  // Clear all filters
  const clearFilters = () => {
    setFilters({})
    setShowAdvanced(false)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="flex items-center gap-2">
                <Shield className="h-5 w-5" />
                Audit Trail
              </CardTitle>
              <CardDescription>
                Comprehensive activity log with {filteredLogs.length} of {auditLogs.length} entries shown
              </CardDescription>
            </div>
            
            <div className="flex items-center gap-2">
              {showExport && (
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => onExport?.(filters)}
                  disabled={loading}
                >
                  <Download className="h-4 w-4 mr-2" />
                  Export
                </Button>
              )}
              
              <Button
                variant="outline"
                size="sm"
                onClick={handleRefresh}
                disabled={loading}
              >
                <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
                Refresh
              </Button>
            </div>
          </div>
        </CardHeader>

        <CardContent>
          {/* Search and Quick Filters */}
          <div className="space-y-4">
            <div className="flex gap-4">
              <div className="flex-1 relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Search logs by description, action, user, or entity ID..."
                  value={filters.search || ''}
                  onChange={(e) => setFilters(prev => ({ ...prev, search: e.target.value }))}
                  className="pl-10"
                />
              </div>
              
              <Select
                value={filters.eventType || ''}
                onValueChange={(value) => setFilters(prev => ({ ...prev, eventType: value || undefined }))}
              >
                <SelectTrigger className="w-48">
                  <SelectValue placeholder="Event Type" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">All Events</SelectItem>
                  {uniqueValues.eventTypes.map(type => (
                    <SelectItem key={type} value={type}>
                      {EVENT_TYPE_ICONS[type as keyof typeof EVENT_TYPE_ICONS]} {type}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              <Select
                value={filters.severity || ''}
                onValueChange={(value) => setFilters(prev => ({ ...prev, severity: value || undefined }))}
              >
                <SelectTrigger className="w-32">
                  <SelectValue placeholder="Severity" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">All</SelectItem>
                  {uniqueValues.severities.map(severity => (
                    <SelectItem key={severity} value={severity}>{severity}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Advanced Filters */}
            {showAdvancedFilters && (
              <Collapsible open={showAdvanced} onOpenChange={setShowAdvanced}>
                <CollapsibleTrigger asChild>
                  <Button variant="ghost" size="sm">
                    <Filter className="h-4 w-4 mr-2" />
                    Advanced Filters
                    {showAdvanced ? <ChevronDown className="h-4 w-4 ml-2" /> : <ChevronRight className="h-4 w-4 ml-2" />}
                  </Button>
                </CollapsibleTrigger>

                <CollapsibleContent className="space-y-4 mt-4 p-4 border rounded-lg">
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                      <label className="text-sm font-medium mb-2 block">Event Category</label>
                      <Select
                        value={filters.eventCategory || ''}
                        onValueChange={(value) => setFilters(prev => ({ ...prev, eventCategory: value || undefined }))}
                      >
                        <SelectTrigger>
                          <SelectValue placeholder="All Categories" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="">All Categories</SelectItem>
                          {uniqueValues.eventCategories.map(category => (
                            <SelectItem key={category} value={category}>{category}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>

                    <div>
                      <label className="text-sm font-medium mb-2 block">Entity Type</label>
                      <Select
                        value={filters.entityType || ''}
                        onValueChange={(value) => setFilters(prev => ({ ...prev, entityType: value || undefined }))}
                      >
                        <SelectTrigger>
                          <SelectValue placeholder="All Entities" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="">All Entities</SelectItem>
                          {uniqueValues.entityTypes.map(entity => (
                            <SelectItem key={entity} value={entity}>{entity}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>

                    <div>
                      <label className="text-sm font-medium mb-2 block">User</label>
                      <Select
                        value={filters.userId || ''}
                        onValueChange={(value) => setFilters(prev => ({ ...prev, userId: value || undefined }))}
                      >
                        <SelectTrigger>
                          <SelectValue placeholder="All Users" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="">All Users</SelectItem>
                          {uniqueValues.users.map(user => (
                            <SelectItem key={user} value={user}>{user}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  </div>

                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4">
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => setShowPersonalData(!showPersonalData)}
                      >
                        {showPersonalData ? <Eye className="h-4 w-4 mr-2" /> : <EyeOff className="h-4 w-4 mr-2" />}
                        {showPersonalData ? 'Hide' : 'Show'} Personal Data
                      </Button>
                    </div>

                    <Button variant="ghost" size="sm" onClick={clearFilters}>
                      Clear Filters
                    </Button>
                  </div>
                </CollapsibleContent>
              </Collapsible>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Audit Log Entries */}
      <Card>
        <CardContent className="p-0">
          <ScrollArea className="h-[600px]">
            <div className="divide-y">
              {filteredLogs.map((entry) => {
                const isExpanded = expandedEntries.has(entry.id)
                const hasChanges = entry.changedFields && entry.changedFields.length > 0
                
                return (
                  <div key={entry.id} className="p-4 hover:bg-muted/50">
                    <div className="flex items-start gap-4">
                      {/* Event Icon and Type */}
                      <div className="flex flex-col items-center gap-1 min-w-[60px]">
                        <div className="text-2xl">
                          {EVENT_TYPE_ICONS[entry.eventType as keyof typeof EVENT_TYPE_ICONS] || '📋'}
                        </div>
                        <Badge variant="outline" className="text-xs">
                          {entry.eventType}
                        </Badge>
                      </div>

                      {/* Main Content */}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between mb-2">
                          <div className="flex items-center gap-2">
                            <h4 className="font-medium">{entry.description}</h4>
                            <Badge className={`text-xs ${SEVERITY_COLORS[entry.severity as keyof typeof SEVERITY_COLORS] || 'bg-gray-100 text-gray-800'}`}>
                              {entry.severity}
                            </Badge>
                            {entry.isPersonalData && !entry.anonymizedAt && (
                              <Badge variant="destructive" className="text-xs">
                                Personal Data
                              </Badge>
                            )}
                          </div>

                          <div className="flex items-center gap-2">
                            {hasChanges && (
                              <Badge variant="secondary" className="text-xs">
                                {entry.changedFields?.length} changes
                              </Badge>
                            )}
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => toggleExpanded(entry.id)}
                            >
                              {isExpanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
                            </Button>
                          </div>
                        </div>

                        {/* Meta information */}
                        <div className="flex items-center gap-4 text-sm text-muted-foreground mb-2">
                          <div className="flex items-center gap-1">
                            <Clock className="h-3 w-3" />
                            {format(new Date(entry.createdAt), 'MMM dd, yyyy HH:mm:ss')}
                          </div>
                          
                          {entry.username && (
                            <div className="flex items-center gap-1">
                              <User className="h-3 w-3" />
                              {entry.username}
                            </div>
                          )}
                          
                          <div className="flex items-center gap-1">
                            <Database className="h-3 w-3" />
                            {entry.entityType}:{entry.entityId}
                          </div>
                          
                          {entry.ipAddress && (
                            <div className="flex items-center gap-1">
                              <MapPin className="h-3 w-3" />
                              {entry.ipAddress}
                            </div>
                          )}
                          
                          {entry.duration && (
                            <div className="flex items-center gap-1">
                              <Activity className="h-3 w-3" />
                              {entry.duration}ms
                            </div>
                          )}
                        </div>

                        {/* Expanded Details */}
                        {isExpanded && (
                          <div className="mt-4 space-y-4 bg-muted/20 p-4 rounded-lg">
                            <Tabs defaultValue="details" className="w-full">
                              <TabsList>
                                <TabsTrigger value="details">Details</TabsTrigger>
                                {hasChanges && <TabsTrigger value="changes">Changes</TabsTrigger>}
                                {entry.metadata && <TabsTrigger value="metadata">Metadata</TabsTrigger>}
                                <TabsTrigger value="context">Context</TabsTrigger>
                              </TabsList>

                              <TabsContent value="details" className="space-y-2">
                                <div className="grid grid-cols-2 gap-4 text-sm">
                                  <div>
                                    <strong>Event Category:</strong> {entry.eventCategory}
                                  </div>
                                  <div>
                                    <strong>Action:</strong> {entry.action}
                                  </div>
                                  <div>
                                    <strong>Session ID:</strong> {entry.sessionId || 'N/A'}
                                  </div>
                                  <div>
                                    <strong>Request ID:</strong> {entry.requestId || 'N/A'}
                                  </div>
                                  <div>
                                    <strong>Environment:</strong> {entry.environment || 'N/A'}
                                  </div>
                                  <div>
                                    <strong>Version:</strong> {entry.applicationVersion || 'N/A'}
                                  </div>
                                </div>
                              </TabsContent>

                              {hasChanges && (
                                <TabsContent value="changes" className="space-y-2">
                                  <div>
                                    <strong>Changed Fields:</strong> {entry.changedFields?.join(', ')}
                                  </div>
                                  
                                  {entry.oldValues && Object.keys(entry.oldValues).length > 0 && (
                                    <div>
                                      <strong>Old Values:</strong>
                                      <pre className="mt-2 p-2 bg-red-50 rounded text-xs overflow-auto">
                                        {formatJsonValue(entry.oldValues)}
                                      </pre>
                                    </div>
                                  )}
                                  
                                  {entry.newValues && Object.keys(entry.newValues).length > 0 && (
                                    <div>
                                      <strong>New Values:</strong>
                                      <pre className="mt-2 p-2 bg-green-50 rounded text-xs overflow-auto">
                                        {formatJsonValue(entry.newValues)}
                                      </pre>
                                    </div>
                                  )}
                                </TabsContent>
                              )}

                              {entry.metadata && (
                                <TabsContent value="metadata">
                                  <pre className="p-2 bg-muted rounded text-xs overflow-auto">
                                    {formatJsonValue(entry.metadata)}
                                  </pre>
                                </TabsContent>
                              )}

                              <TabsContent value="context" className="space-y-2">
                                <div className="grid grid-cols-1 gap-2 text-sm">
                                  <div>
                                    <strong>User Agent:</strong>
                                    <div className="text-xs text-muted-foreground mt-1 break-all">
                                      {entry.userAgent || 'N/A'}
                                    </div>
                                  </div>
                                  <div>
                                    <strong>Referrer:</strong> {entry.referrer || 'N/A'}
                                  </div>
                                  <div>
                                    <strong>Hostname:</strong> {entry.hostname || 'N/A'}
                                  </div>
                                  {entry.tags && entry.tags.length > 0 && (
                                    <div>
                                      <strong>Tags:</strong>
                                      <div className="flex gap-1 mt-1">
                                        {entry.tags.map((tag, index) => (
                                          <Badge key={index} variant="outline" className="text-xs">
                                            {tag}
                                          </Badge>
                                        ))}
                                      </div>
                                    </div>
                                  )}
                                </div>
                              </TabsContent>
                            </Tabs>

                            {onViewDetails && (
                              <div className="flex justify-end">
                                <Button
                                  variant="outline"
                                  size="sm"
                                  onClick={() => onViewDetails(entry)}
                                >
                                  <MoreHorizontal className="h-4 w-4 mr-2" />
                                  View Full Details
                                </Button>
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                )
              })}

              {filteredLogs.length === 0 && (
                <div className="p-8 text-center text-muted-foreground">
                  <Shield className="h-12 w-12 mx-auto mb-4 opacity-50" />
                  <h3 className="text-lg font-medium mb-2">No audit logs found</h3>
                  <p>Try adjusting your filters or refresh to see audit entries.</p>
                </div>
              )}
            </div>
          </ScrollArea>
        </CardContent>
      </Card>
    </div>
  )
}

export default AuditLogViewer