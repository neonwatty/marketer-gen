'use client'

import React, { useState, useEffect } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { AuditLogViewer } from './audit-log-viewer'
import { AuditReportBuilder } from './audit-report-builder'
import { 
  Shield,
  Activity,
  Users,
  FileText,
  Download,
  Settings,
  AlertTriangle,
  TrendingUp,
  BarChart3,
  Database,
  Clock,
  Archive
} from 'lucide-react'

// Mock data for demonstration
const mockAuditData = [
  {
    id: '1',
    createdAt: new Date('2024-01-15T10:30:00Z'),
    eventType: 'CREATE',
    eventCategory: 'CONTENT_MANAGEMENT',
    entityType: 'CAMPAIGN',
    entityId: 'camp_123',
    action: 'created',
    description: 'Campaign "Summer Sale 2024" created',
    userId: 'user_456',
    username: 'john.doe',
    userRole: 'marketing_manager',
    sessionId: 'sess_789',
    ipAddress: '192.168.1.100',
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    severity: 'INFO',
    isPersonalData: false,
    duration: 250,
    newValues: { name: 'Summer Sale 2024', status: 'draft' }
  },
  {
    id: '2',
    createdAt: new Date('2024-01-15T10:35:00Z'),
    eventType: 'APPROVE',
    eventCategory: 'APPROVAL_WORKFLOW',
    entityType: 'CONTENT',
    entityId: 'content_456',
    action: 'approved',
    description: 'Content approved by marketing director',
    userId: 'user_789',
    username: 'jane.smith',
    userRole: 'marketing_director',
    sessionId: 'sess_890',
    ipAddress: '192.168.1.101',
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    severity: 'INFO',
    isPersonalData: false,
    duration: 150,
    metadata: { approvalStage: 'final', comment: 'Looks good!' }
  },
  {
    id: '3',
    createdAt: new Date('2024-01-15T10:40:00Z'),
    eventType: 'SECURITY_EVENT',
    eventCategory: 'SECURITY',
    entityType: 'USER',
    entityId: 'user_999',
    action: 'failed_login',
    description: 'Failed login attempt detected',
    userId: 'user_999',
    username: 'suspicious.user',
    userRole: 'guest',
    sessionId: 'sess_999',
    ipAddress: '203.0.113.45',
    userAgent: 'curl/7.68.0',
    severity: 'WARNING',
    isPersonalData: true,
    duration: 50,
    metadata: { attempts: 3, reason: 'invalid_password' }
  }
]

const mockStats = {
  totalLogs: 125834,
  todayLogs: 1247,
  securityEvents: 23,
  errorRate: 0.8,
  avgResponseTime: 180,
  topUsers: [
    { name: 'john.doe', count: 234 },
    { name: 'jane.smith', count: 189 },
    { name: 'bob.wilson', count: 156 }
  ],
  topEvents: [
    { type: 'UPDATE', count: 4521 },
    { type: 'VIEW', count: 3891 },
    { type: 'CREATE', count: 2134 }
  ]
}

export const AuditDashboard: React.FC = () => {
  const [activeTab, setActiveTab] = useState('overview')
  const [auditLogs, setAuditLogs] = useState(mockAuditData)
  const [stats, setStats] = useState(mockStats)
  const [loading, setLoading] = useState(false)

  // Simulate data refresh
  const handleRefresh = async () => {
    setLoading(true)
    // In a real implementation, this would fetch from API
    setTimeout(() => {
      setLoading(false)
    }, 1000)
    return mockAuditData
  }

  // Handle export
  const handleExport = async (filters: any) => {
    console.log('Exporting with filters:', filters)
    // In a real implementation, this would call the export API
    alert('Export started! You will receive a download link when ready.')
  }

  // Handle report save
  const handleSaveReport = async (config: any) => {
    console.log('Saving report config:', config)
    // In a real implementation, this would save to API
    alert('Report configuration saved successfully!')
  }

  // Handle report run
  const handleRunReport = async (config: any) => {
    console.log('Running report with config:', config)
    // In a real implementation, this would generate the report
    return {
      type: 'grouped',
      groupings: [
        {
          field: 'eventType',
          data: [
            { eventType: 'CREATE', _count: { id: 150 } },
            { eventType: 'UPDATE', _count: { id: 300 } },
            { eventType: 'DELETE', _count: { id: 50 } }
          ]
        }
      ],
      summary: {
        totalRecords: 500,
        timeRange: config.filters.dateRange
      }
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Audit Dashboard</h1>
          <p className="text-muted-foreground">
            Monitor and analyze all system activities and security events
          </p>
        </div>
        
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm">
            <Settings className="h-4 w-4 mr-2" />
            Settings
          </Button>
          <Button size="sm">
            <Download className="h-4 w-4 mr-2" />
            Quick Export
          </Button>
        </div>
      </div>

      {/* Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Audit Logs</CardTitle>
            <Database className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.totalLogs.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">
              +{stats.todayLogs} today
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Security Events</CardTitle>
            <Shield className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.securityEvents}</div>
            <p className="text-xs text-muted-foreground">
              Last 24 hours
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Error Rate</CardTitle>
            <AlertTriangle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.errorRate}%</div>
            <p className="text-xs text-muted-foreground">
              -0.2% from yesterday
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg Response Time</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.avgResponseTime}ms</div>
            <p className="text-xs text-muted-foreground">
              +12ms from yesterday
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Main Content Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="overview">
            <Activity className="h-4 w-4 mr-2" />
            Overview
          </TabsTrigger>
          <TabsTrigger value="logs">
            <FileText className="h-4 w-4 mr-2" />
            Audit Logs
          </TabsTrigger>
          <TabsTrigger value="reports">
            <BarChart3 className="h-4 w-4 mr-2" />
            Reports
          </TabsTrigger>
          <TabsTrigger value="retention">
            <Archive className="h-4 w-4 mr-2" />
            Retention
          </TabsTrigger>
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Recent Activity */}
            <Card>
              <CardHeader>
                <CardTitle>Recent Activity</CardTitle>
                <CardDescription>Latest audit events in the system</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {auditLogs.slice(0, 5).map((log) => (
                    <div key={log.id} className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <Badge variant="outline" className="text-xs">
                          {log.eventType}
                        </Badge>
                        <div>
                          <p className="text-sm font-medium">{log.description}</p>
                          <p className="text-xs text-muted-foreground">
                            by {log.username} • {log.createdAt.toLocaleTimeString()}
                          </p>
                        </div>
                      </div>
                      <Badge 
                        variant={log.severity === 'WARNING' ? 'destructive' : 'secondary'}
                        className="text-xs"
                      >
                        {log.severity}
                      </Badge>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>

            {/* Top Users */}
            <Card>
              <CardHeader>
                <CardTitle>Most Active Users</CardTitle>
                <CardDescription>Users with the most audit events today</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {stats.topUsers.map((user, index) => (
                    <div key={user.name} className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 bg-primary/10 rounded-full flex items-center justify-center text-sm font-medium">
                          {index + 1}
                        </div>
                        <div>
                          <p className="text-sm font-medium">{user.name}</p>
                          <p className="text-xs text-muted-foreground">
                            {user.count} events
                          </p>
                        </div>
                      </div>
                      <TrendingUp className="h-4 w-4 text-green-500" />
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>

            {/* Event Types */}
            <Card>
              <CardHeader>
                <CardTitle>Event Distribution</CardTitle>
                <CardDescription>Most common event types this week</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {stats.topEvents.map((event) => (
                    <div key={event.type} className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <Badge variant="outline">{event.type}</Badge>
                        <p className="text-sm">{event.count.toLocaleString()} events</p>
                      </div>
                      <div className="w-16 bg-secondary h-2 rounded-full">
                        <div 
                          className="bg-primary h-2 rounded-full" 
                          style={{ 
                            width: `${(event.count / Math.max(...stats.topEvents.map(e => e.count))) * 100}%` 
                          }}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>

            {/* Quick Actions */}
            <Card>
              <CardHeader>
                <CardTitle>Quick Actions</CardTitle>
                <CardDescription>Common audit management tasks</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 gap-3">
                  <Button variant="outline" size="sm" className="h-auto p-4">
                    <div className="text-center">
                      <Download className="h-5 w-5 mx-auto mb-2" />
                      <div className="text-xs">Export Logs</div>
                    </div>
                  </Button>
                  <Button variant="outline" size="sm" className="h-auto p-4">
                    <div className="text-center">
                      <BarChart3 className="h-5 w-5 mx-auto mb-2" />
                      <div className="text-xs">Generate Report</div>
                    </div>
                  </Button>
                  <Button variant="outline" size="sm" className="h-auto p-4">
                    <div className="text-center">
                      <Archive className="h-5 w-5 mx-auto mb-2" />
                      <div className="text-xs">Manage Retention</div>
                    </div>
                  </Button>
                  <Button variant="outline" size="sm" className="h-auto p-4">
                    <div className="text-center">
                      <Settings className="h-5 w-5 mx-auto mb-2" />
                      <div className="text-xs">Configure Alerts</div>
                    </div>
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Audit Logs Tab */}
        <TabsContent value="logs">
          <AuditLogViewer
            initialData={auditLogs}
            onRefresh={handleRefresh}
            onExport={handleExport}
            showExport={true}
            showAdvancedFilters={true}
          />
        </TabsContent>

        {/* Reports Tab */}
        <TabsContent value="reports">
          <AuditReportBuilder
            onSave={handleSaveReport}
            onRun={handleRunReport}
            onPreview={handleRunReport}
          />
        </TabsContent>

        {/* Retention Tab */}
        <TabsContent value="retention">
          <Card>
            <CardHeader>
              <CardTitle>Data Retention Management</CardTitle>
              <CardDescription>
                Configure automated data lifecycle policies for audit logs
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="bg-muted/50 p-4 rounded-lg">
                  <h4 className="font-medium mb-2">Retention Policies</h4>
                  <p className="text-sm text-muted-foreground mb-4">
                    Automatically manage audit log lifecycle with customizable retention rules.
                  </p>
                  
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-center">
                    <div className="bg-background p-3 rounded border">
                      <div className="text-2xl font-bold text-green-600">2.1GB</div>
                      <div className="text-xs text-muted-foreground">Storage Used</div>
                    </div>
                    <div className="bg-background p-3 rounded border">
                      <div className="text-2xl font-bold text-blue-600">45 days</div>
                      <div className="text-xs text-muted-foreground">Avg Retention</div>
                    </div>
                    <div className="bg-background p-3 rounded border">
                      <div className="text-2xl font-bold text-orange-600">12.5K</div>
                      <div className="text-xs text-muted-foreground">Ready for Cleanup</div>
                    </div>
                  </div>
                </div>

                <div className="flex gap-2">
                  <Button variant="outline">
                    <Settings className="h-4 w-4 mr-2" />
                    Configure Policies
                  </Button>
                  <Button variant="outline">
                    <Archive className="h-4 w-4 mr-2" />
                    Run Cleanup
                  </Button>
                  <Button variant="outline">
                    <FileText className="h-4 w-4 mr-2" />
                    View Report
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}

export default AuditDashboard