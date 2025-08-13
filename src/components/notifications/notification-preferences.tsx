'use client'

import React, { useState, useEffect } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/switch'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Separator } from '@/components/ui/separator'
import { Badge } from '@/components/ui/badge'
import {
  Bell,
  Mail,
  Smartphone,
  Monitor,
  Clock,
  Moon,
  Volume2,
  VolumeX,
  Settings,
  Save,
  RotateCcw,
  TestTube,
  AlertTriangle,
  Shield,
  Users,
  MessageSquare,
  FileText,
  Calendar,
  TrendingUp,
  Database,
  CheckCircle
} from 'lucide-react'
import { toast } from 'sonner'

interface NotificationTypePreference {
  inApp: boolean
  email: boolean
  push: boolean
  desktop: boolean
}

interface NotificationPreferences {
  // Global toggles
  enableInApp: boolean
  enableEmail: boolean
  enablePush: boolean
  enableDesktop: boolean

  // Email settings
  emailFrequency: 'IMMEDIATE' | 'HOURLY' | 'DAILY' | 'WEEKLY' | 'NEVER'
  digestTime?: string

  // Type-specific preferences
  typePreferences: Record<string, NotificationTypePreference>

  // Quiet hours
  quietHoursEnabled: boolean
  quietHoursStart?: string
  quietHoursEnd?: string
  quietHoursTimezone?: string

  // Do not disturb
  doNotDisturb: boolean
  dndUntil?: Date

  // Localization
  language: string
  timezone: string
}

const defaultPreferences: NotificationPreferences = {
  enableInApp: true,
  enableEmail: true,
  enablePush: false,
  enableDesktop: false,
  emailFrequency: 'IMMEDIATE',
  digestTime: '09:00',
  typePreferences: {},
  quietHoursEnabled: false,
  quietHoursStart: '22:00',
  quietHoursEnd: '08:00',
  quietHoursTimezone: 'UTC',
  doNotDisturb: false,
  language: 'en',
  timezone: 'UTC'
}

const notificationTypes = [
  {
    key: 'MENTION',
    label: 'Mentions',
    description: 'When someone mentions you in a comment or discussion',
    icon: <Users className="h-4 w-4" />,
    category: 'Collaboration'
  },
  {
    key: 'COMMENT',
    label: 'Comments',
    description: 'New comments on content you\'re involved with',
    icon: <MessageSquare className="h-4 w-4" />,
    category: 'Collaboration'
  },
  {
    key: 'ASSIGNMENT',
    label: 'Assignments',
    description: 'When you\'re assigned to tasks or projects',
    icon: <FileText className="h-4 w-4" />,
    category: 'Collaboration'
  },
  {
    key: 'APPROVAL_REQUEST',
    label: 'Approval Requests',
    description: 'Content or tasks requiring your approval',
    icon: <CheckCircle className="h-4 w-4" />,
    category: 'Approval'
  },
  {
    key: 'APPROVAL_RESPONSE',
    label: 'Approval Responses',
    description: 'Updates on content you submitted for approval',
    icon: <CheckCircle className="h-4 w-4" />,
    category: 'Approval'
  },
  {
    key: 'DEADLINE_REMINDER',
    label: 'Deadline Reminders',
    description: 'Reminders about upcoming deadlines',
    icon: <Calendar className="h-4 w-4" />,
    category: 'Collaboration'
  },
  {
    key: 'CAMPAIGN_UPDATE',
    label: 'Campaign Updates',
    description: 'Changes to campaigns you\'re involved with',
    icon: <TrendingUp className="h-4 w-4" />,
    category: 'Marketing'
  },
  {
    key: 'CONTENT_UPDATE',
    label: 'Content Updates',
    description: 'Changes to content you\'re watching',
    icon: <FileText className="h-4 w-4" />,
    category: 'Content'
  },
  {
    key: 'SECURITY_ALERT',
    label: 'Security Alerts',
    description: 'Important security notifications',
    icon: <Shield className="h-4 w-4" />,
    category: 'Security'
  },
  {
    key: 'SYSTEM_ALERT',
    label: 'System Alerts',
    description: 'System maintenance and updates',
    icon: <Database className="h-4 w-4" />,
    category: 'System'
  }
]

export const NotificationPreferences: React.FC = () => {
  const [preferences, setPreferences] = useState<NotificationPreferences>(defaultPreferences)
  const [loading, setLoading] = useState(false)
  const [hasChanges, setHasChanges] = useState(false)
  const [testMode, setTestMode] = useState(false)

  // Load preferences on mount
  useEffect(() => {
    loadPreferences()
  }, [])

  const loadPreferences = async () => {
    try {
      // In a real implementation, this would load from API
      setPreferences(defaultPreferences)
    } catch (error) {
      toast.error('Failed to load notification preferences')
    }
  }

  const savePreferences = async () => {
    setLoading(true)
    try {
      // In a real implementation, this would save to API
      await new Promise(resolve => setTimeout(resolve, 1000))
      setHasChanges(false)
      toast.success('Notification preferences saved successfully')
    } catch (error) {
      toast.error('Failed to save notification preferences')
    } finally {
      setLoading(false)
    }
  }

  const resetPreferences = () => {
    setPreferences(defaultPreferences)
    setHasChanges(true)
  }

  const sendTestNotification = async (channel: string) => {
    setTestMode(true)
    try {
      // In a real implementation, this would trigger a test notification
      await new Promise(resolve => setTimeout(resolve, 500))
      toast.success(`Test ${channel} notification sent!`)
    } catch (error) {
      toast.error(`Failed to send test ${channel} notification`)
    } finally {
      setTestMode(false)
    }
  }

  const updatePreference = (path: string, value: any) => {
    setPreferences(prev => {
      const updated = { ...prev }
      const keys = path.split('.')
      let current = updated as any
      
      for (let i = 0; i < keys.length - 1; i++) {
        if (!current[keys[i]]) current[keys[i]] = {}
        current = current[keys[i]]
      }
      
      current[keys[keys.length - 1]] = value
      return updated
    })
    setHasChanges(true)
  }

  const updateTypePreference = (type: string, channel: string, enabled: boolean) => {
    setPreferences(prev => ({
      ...prev,
      typePreferences: {
        ...prev.typePreferences,
        [type]: {
          ...prev.typePreferences[type],
          [channel]: enabled
        }
      }
    }))
    setHasChanges(true)
  }

  const getTypePreference = (type: string, channel: string): boolean => {
    return preferences.typePreferences[type]?.[channel] ?? true
  }

  const categories = [...new Set(notificationTypes.map(t => t.category))]

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight flex items-center gap-2">
            <Settings className="h-8 w-8" />
            Notification Preferences
          </h1>
          <p className="text-muted-foreground">
            Customize how and when you receive notifications
          </p>
        </div>

        <div className="flex items-center gap-2">
          {hasChanges && (
            <Button variant="outline" onClick={resetPreferences}>
              <RotateCcw className="h-4 w-4 mr-2" />
              Reset
            </Button>
          )}
          <Button 
            onClick={savePreferences} 
            disabled={!hasChanges || loading}
          >
            <Save className="h-4 w-4 mr-2" />
            {loading ? 'Saving...' : 'Save Changes'}
          </Button>
        </div>
      </div>

      <Tabs defaultValue="channels" className="space-y-6">
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="channels">Channels</TabsTrigger>
          <TabsTrigger value="types">Notification Types</TabsTrigger>
          <TabsTrigger value="schedule">Schedule</TabsTrigger>
          <TabsTrigger value="advanced">Advanced</TabsTrigger>
        </TabsList>

        {/* Channels Tab */}
        <TabsContent value="channels" className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* In-App Notifications */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Bell className="h-5 w-5" />
                  In-App Notifications
                </CardTitle>
                <CardDescription>
                  Notifications shown within the application
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between">
                  <Label htmlFor="enable-inapp">Enable in-app notifications</Label>
                  <Switch
                    id="enable-inapp"
                    checked={preferences.enableInApp}
                    onCheckedChange={(checked) => updatePreference('enableInApp', checked)}
                  />
                </div>
                
                <Button 
                  variant="outline" 
                  size="sm"
                  onClick={() => sendTestNotification('in-app')}
                  disabled={!preferences.enableInApp || testMode}
                >
                  <TestTube className="h-4 w-4 mr-2" />
                  Test In-App
                </Button>
              </CardContent>
            </Card>

            {/* Email Notifications */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Mail className="h-5 w-5" />
                  Email Notifications
                </CardTitle>
                <CardDescription>
                  Notifications sent to your email address
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between">
                  <Label htmlFor="enable-email">Enable email notifications</Label>
                  <Switch
                    id="enable-email"
                    checked={preferences.enableEmail}
                    onCheckedChange={(checked) => updatePreference('enableEmail', checked)}
                  />
                </div>

                {preferences.enableEmail && (
                  <>
                    <div className="space-y-2">
                      <Label>Email frequency</Label>
                      <Select 
                        value={preferences.emailFrequency} 
                        onValueChange={(value) => updatePreference('emailFrequency', value)}
                      >
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="IMMEDIATE">Immediate</SelectItem>
                          <SelectItem value="HOURLY">Hourly digest</SelectItem>
                          <SelectItem value="DAILY">Daily digest</SelectItem>
                          <SelectItem value="WEEKLY">Weekly digest</SelectItem>
                          <SelectItem value="NEVER">Never</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>

                    {(preferences.emailFrequency === 'DAILY' || preferences.emailFrequency === 'WEEKLY') && (
                      <div className="space-y-2">
                        <Label>Digest time</Label>
                        <Input
                          type="time"
                          value={preferences.digestTime || '09:00'}
                          onChange={(e) => updatePreference('digestTime', e.target.value)}
                        />
                      </div>
                    )}
                  </>
                )}

                <Button 
                  variant="outline" 
                  size="sm"
                  onClick={() => sendTestNotification('email')}
                  disabled={!preferences.enableEmail || testMode}
                >
                  <TestTube className="h-4 w-4 mr-2" />
                  Test Email
                </Button>
              </CardContent>
            </Card>

            {/* Push Notifications */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Smartphone className="h-5 w-5" />
                  Push Notifications
                </CardTitle>
                <CardDescription>
                  Mobile push notifications
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between">
                  <Label htmlFor="enable-push">Enable push notifications</Label>
                  <Switch
                    id="enable-push"
                    checked={preferences.enablePush}
                    onCheckedChange={(checked) => updatePreference('enablePush', checked)}
                  />
                </div>

                <Button 
                  variant="outline" 
                  size="sm"
                  onClick={() => sendTestNotification('push')}
                  disabled={!preferences.enablePush || testMode}
                >
                  <TestTube className="h-4 w-4 mr-2" />
                  Test Push
                </Button>
              </CardContent>
            </Card>

            {/* Desktop Notifications */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Monitor className="h-5 w-5" />
                  Desktop Notifications
                </CardTitle>
                <CardDescription>
                  Browser desktop notifications
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between">
                  <Label htmlFor="enable-desktop">Enable desktop notifications</Label>
                  <Switch
                    id="enable-desktop"
                    checked={preferences.enableDesktop}
                    onCheckedChange={(checked) => updatePreference('enableDesktop', checked)}
                  />
                </div>

                <Button 
                  variant="outline" 
                  size="sm"
                  onClick={() => sendTestNotification('desktop')}
                  disabled={!preferences.enableDesktop || testMode}
                >
                  <TestTube className="h-4 w-4 mr-2" />
                  Test Desktop
                </Button>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Notification Types Tab */}
        <TabsContent value="types" className="space-y-6">
          {categories.map(category => (
            <Card key={category}>
              <CardHeader>
                <CardTitle>{category}</CardTitle>
                <CardDescription>
                  Configure notifications for {category.toLowerCase()} activities
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {notificationTypes
                    .filter(type => type.category === category)
                    .map(type => (
                      <div key={type.key} className="space-y-3">
                        <div className="flex items-center gap-3">
                          {type.icon}
                          <div className="flex-1">
                            <h4 className="font-medium">{type.label}</h4>
                            <p className="text-sm text-muted-foreground">{type.description}</p>
                          </div>
                        </div>
                        
                        <div className="grid grid-cols-4 gap-4 pl-7">
                          <div className="flex items-center space-x-2">
                            <Switch
                              id={`${type.key}-inapp`}
                              checked={getTypePreference(type.key, 'inApp')}
                              onCheckedChange={(checked) => updateTypePreference(type.key, 'inApp', checked)}
                              disabled={!preferences.enableInApp}
                            />
                            <Label htmlFor={`${type.key}-inapp`} className="text-sm">In-App</Label>
                          </div>
                          
                          <div className="flex items-center space-x-2">
                            <Switch
                              id={`${type.key}-email`}
                              checked={getTypePreference(type.key, 'email')}
                              onCheckedChange={(checked) => updateTypePreference(type.key, 'email', checked)}
                              disabled={!preferences.enableEmail}
                            />
                            <Label htmlFor={`${type.key}-email`} className="text-sm">Email</Label>
                          </div>
                          
                          <div className="flex items-center space-x-2">
                            <Switch
                              id={`${type.key}-push`}
                              checked={getTypePreference(type.key, 'push')}
                              onCheckedChange={(checked) => updateTypePreference(type.key, 'push', checked)}
                              disabled={!preferences.enablePush}
                            />
                            <Label htmlFor={`${type.key}-push`} className="text-sm">Push</Label>
                          </div>
                          
                          <div className="flex items-center space-x-2">
                            <Switch
                              id={`${type.key}-desktop`}
                              checked={getTypePreference(type.key, 'desktop')}
                              onCheckedChange={(checked) => updateTypePreference(type.key, 'desktop', checked)}
                              disabled={!preferences.enableDesktop}
                            />
                            <Label htmlFor={`${type.key}-desktop`} className="text-sm">Desktop</Label>
                          </div>
                        </div>
                        
                        <Separator />
                      </div>
                    ))}
                </div>
              </CardContent>
            </Card>
          ))}
        </TabsContent>

        {/* Schedule Tab */}
        <TabsContent value="schedule" className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Quiet Hours */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Moon className="h-5 w-5" />
                  Quiet Hours
                </CardTitle>
                <CardDescription>
                  Reduce notifications during specific hours
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between">
                  <Label htmlFor="quiet-hours">Enable quiet hours</Label>
                  <Switch
                    id="quiet-hours"
                    checked={preferences.quietHoursEnabled}
                    onCheckedChange={(checked) => updatePreference('quietHoursEnabled', checked)}
                  />
                </div>

                {preferences.quietHoursEnabled && (
                  <>
                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label>Start time</Label>
                        <Input
                          type="time"
                          value={preferences.quietHoursStart || '22:00'}
                          onChange={(e) => updatePreference('quietHoursStart', e.target.value)}
                        />
                      </div>
                      <div className="space-y-2">
                        <Label>End time</Label>
                        <Input
                          type="time"
                          value={preferences.quietHoursEnd || '08:00'}
                          onChange={(e) => updatePreference('quietHoursEnd', e.target.value)}
                        />
                      </div>
                    </div>

                    <div className="space-y-2">
                      <Label>Timezone</Label>
                      <Select 
                        value={preferences.quietHoursTimezone || 'UTC'} 
                        onValueChange={(value) => updatePreference('quietHoursTimezone', value)}
                      >
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="UTC">UTC</SelectItem>
                          <SelectItem value="America/New_York">Eastern Time</SelectItem>
                          <SelectItem value="America/Chicago">Central Time</SelectItem>
                          <SelectItem value="America/Denver">Mountain Time</SelectItem>
                          <SelectItem value="America/Los_Angeles">Pacific Time</SelectItem>
                          <SelectItem value="Europe/London">London</SelectItem>
                          <SelectItem value="Europe/Paris">Paris</SelectItem>
                          <SelectItem value="Asia/Tokyo">Tokyo</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                  </>
                )}
              </CardContent>
            </Card>

            {/* Do Not Disturb */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <VolumeX className="h-5 w-5" />
                  Do Not Disturb
                </CardTitle>
                <CardDescription>
                  Temporarily pause all notifications
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between">
                  <Label htmlFor="dnd">Enable do not disturb</Label>
                  <Switch
                    id="dnd"
                    checked={preferences.doNotDisturb}
                    onCheckedChange={(checked) => updatePreference('doNotDisturb', checked)}
                  />
                </div>

                {preferences.doNotDisturb && (
                  <div className="space-y-2">
                    <Label>Disable until</Label>
                    <Input
                      type="datetime-local"
                      value={preferences.dndUntil?.toISOString().slice(0, 16) || ''}
                      onChange={(e) => updatePreference('dndUntil', new Date(e.target.value))}
                    />
                    <p className="text-xs text-muted-foreground">
                      Only urgent notifications will be delivered during this period
                    </p>
                  </div>
                )}
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Advanced Tab */}
        <TabsContent value="advanced" className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Language & Locale */}
            <Card>
              <CardHeader>
                <CardTitle>Language & Locale</CardTitle>
                <CardDescription>
                  Customize notification language and formatting
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <Label>Language</Label>
                  <Select 
                    value={preferences.language} 
                    onValueChange={(value) => updatePreference('language', value)}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="en">English</SelectItem>
                      <SelectItem value="es">Spanish</SelectItem>
                      <SelectItem value="fr">French</SelectItem>
                      <SelectItem value="de">German</SelectItem>
                      <SelectItem value="ja">Japanese</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-2">
                  <Label>Timezone</Label>
                  <Select 
                    value={preferences.timezone} 
                    onValueChange={(value) => updatePreference('timezone', value)}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="UTC">UTC</SelectItem>
                      <SelectItem value="America/New_York">Eastern Time</SelectItem>
                      <SelectItem value="America/Chicago">Central Time</SelectItem>
                      <SelectItem value="America/Denver">Mountain Time</SelectItem>
                      <SelectItem value="America/Los_Angeles">Pacific Time</SelectItem>
                      <SelectItem value="Europe/London">London</SelectItem>
                      <SelectItem value="Europe/Paris">Paris</SelectItem>
                      <SelectItem value="Asia/Tokyo">Tokyo</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </CardContent>
            </Card>

            {/* Data & Privacy */}
            <Card>
              <CardHeader>
                <CardTitle>Data & Privacy</CardTitle>
                <CardDescription>
                  Manage your notification data and privacy settings
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-3">
                  <Button variant="outline" className="w-full justify-start">
                    <Database className="h-4 w-4 mr-2" />
                    Export notification data
                  </Button>
                  
                  <Button variant="outline" className="w-full justify-start">
                    <Trash2 className="h-4 w-4 mr-2" />
                    Clear notification history
                  </Button>
                  
                  <Button variant="outline" className="w-full justify-start text-destructive">
                    <AlertTriangle className="h-4 w-4 mr-2" />
                    Reset all preferences
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  )
}

export default NotificationPreferences