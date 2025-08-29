import { Metadata } from 'next'

import { User, Bell, Shield, CreditCard, Users, Settings } from 'lucide-react'

import { DashboardBreadcrumb } from '@/components/features/dashboard/DashboardBreadcrumb'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Separator } from '@/components/ui/separator'
import { Checkbox } from '@/components/ui/checkbox'

export const metadata: Metadata = {
  title: 'Settings | Dashboard',
  description: 'Manage your account settings and preferences',
}

/**
 * Settings page for managing account, billing, team, and notification preferences
 */
export default function SettingsPage() {
  return (
    <div className="space-y-6">
      <DashboardBreadcrumb 
        items={[
          { label: 'Dashboard', href: '/dashboard' },
          { label: 'Settings', href: '/dashboard/settings' }
        ]} 
      />
      
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Settings</h1>
          <p className="text-muted-foreground">
            Manage your account settings and preferences
          </p>
        </div>

        <div className="grid gap-6 md:grid-cols-2">
          {/* Profile Settings */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <User className="h-5 w-5" />
                Profile Settings
              </CardTitle>
              <CardDescription>
                Update your personal information and preferences
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="name">Display Name</Label>
                <Input id="name" defaultValue="Demo User" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="email">Email Address</Label>
                <Input id="email" type="email" defaultValue="demo@example.com" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="company">Company</Label>
                <Input id="company" placeholder="Your company name" />
              </div>
              <Button className="w-full">Save Changes</Button>
            </CardContent>
          </Card>

          {/* Notification Settings */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Bell className="h-5 w-5" />
                Notifications
              </CardTitle>
              <CardDescription>
                Configure how and when you want to be notified
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label>Email Notifications</Label>
                  <p className="text-sm text-muted-foreground">
                    Receive campaign updates via email
                  </p>
                </div>
                <Checkbox defaultChecked />
              </div>
              <Separator />
              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label>Campaign Alerts</Label>
                  <p className="text-sm text-muted-foreground">
                    Get alerts for campaign milestones
                  </p>
                </div>
                <Checkbox defaultChecked />
              </div>
              <Separator />
              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label>Weekly Reports</Label>
                  <p className="text-sm text-muted-foreground">
                    Receive weekly performance summaries
                  </p>
                </div>
                <Checkbox />
              </div>
            </CardContent>
          </Card>

          {/* Security Settings */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Shield className="h-5 w-5" />
                Security
              </CardTitle>
              <CardDescription>
                Manage your account security settings
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label>Password</Label>
                <div className="flex gap-2">
                  <Input type="password" placeholder="••••••••" className="flex-1" />
                  <Button variant="outline">Change</Button>
                </div>
              </div>
              <Separator />
              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label>Two-Factor Authentication</Label>
                  <p className="text-sm text-muted-foreground">
                    Add an extra layer of security
                  </p>
                </div>
                <Button variant="outline" size="sm">
                  Enable
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Billing Settings */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <CreditCard className="h-5 w-5" />
                Billing
              </CardTitle>
              <CardDescription>
                Manage your subscription and billing information
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="font-medium">Pro Plan</p>
                  <p className="text-sm text-muted-foreground">$29/month</p>
                </div>
                <Button variant="outline" size="sm">
                  Manage
                </Button>
              </div>
              <Separator />
              <div className="space-y-2">
                <Label>Payment Method</Label>
                <div className="flex items-center justify-between p-3 border rounded-md">
                  <div className="flex items-center gap-3">
                    <CreditCard className="h-4 w-4" />
                    <span className="text-sm">•••• •••• •••• 4242</span>
                  </div>
                  <Button variant="ghost" size="sm">
                    Update
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Team Settings (Full width) */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Users className="h-5 w-5" />
              Team Management
            </CardTitle>
            <CardDescription>
              Invite team members and manage permissions
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex items-center justify-center h-32 text-muted-foreground">
              <div className="text-center space-y-2">
                <Users className="h-8 w-8 mx-auto opacity-50" />
                <p className="text-sm">Team management features coming soon</p>
                <p className="text-xs">Invite members, assign roles, and manage permissions</p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Advanced Settings */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Settings className="h-5 w-5" />
              Advanced Settings
            </CardTitle>
            <CardDescription>
              Advanced configuration options and integrations
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex items-center justify-center h-32 text-muted-foreground">
              <div className="text-center space-y-2">
                <Settings className="h-8 w-8 mx-auto opacity-50" />
                <p className="text-sm">Advanced settings and integrations coming soon</p>
                <p className="text-xs">API keys, webhooks, and third-party connections</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}