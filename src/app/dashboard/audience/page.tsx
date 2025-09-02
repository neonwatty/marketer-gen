import { Metadata } from 'next'

import { Filter, Plus, Search,Users } from 'lucide-react'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'

export const metadata: Metadata = {
  title: 'Audience | Dashboard',
  description: 'Manage your audience segments and targeting',
}

/**
 * Audience management page for creating and managing customer segments
 */
export default function AudiencePage() {
  return (
    <div className="space-y-6">
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Audience</h1>
            <p className="text-muted-foreground">
              Create and manage customer segments for targeted campaigns
            </p>
          </div>
          <Button className="flex items-center gap-2">
            <Plus className="h-4 w-4" />
            Create Segment
          </Button>
        </div>

        {/* Search and Filters */}
        <div className="flex items-center gap-4">
          <div className="relative flex-1 max-w-sm">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Search audience segments..."
              className="pl-10"
            />
          </div>
          <Button variant="outline" className="flex items-center gap-2">
            <Filter className="h-4 w-4" />
            Filters
          </Button>
        </div>

        {/* Audience Segments Grid */}
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle className="text-lg">New Customers</CardTitle>
                <Badge variant="secondary">Active</Badge>
              </div>
              <CardDescription>First-time buyers and recent signups</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">Size</span>
                  <span className="font-semibold">2,847 users</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">Growth</span>
                  <span className="text-green-600 font-semibold">+12.3%</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">Last updated</span>
                  <span className="text-sm">2 hours ago</span>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle className="text-lg">High-Value Customers</CardTitle>
                <Badge variant="default">Premium</Badge>
              </div>
              <CardDescription>Top spending customers with high LTV</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">Size</span>
                  <span className="font-semibold">384 users</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">Avg. LTV</span>
                  <span className="text-green-600 font-semibold">$2,450</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">Last updated</span>
                  <span className="text-sm">1 day ago</span>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle className="text-lg">Inactive Users</CardTitle>
                <Badge variant="outline">Dormant</Badge>
              </div>
              <CardDescription>Users who haven't engaged in 90+ days</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">Size</span>
                  <span className="font-semibold">1,249 users</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">Churn risk</span>
                  <span className="text-red-600 font-semibold">High</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">Last updated</span>
                  <span className="text-sm">3 hours ago</span>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Placeholder for advanced audience tools */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Users className="h-5 w-5" />
              Advanced Audience Tools
            </CardTitle>
            <CardDescription>
              Create custom segments with advanced targeting and behavioral data
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex items-center justify-center h-32 text-muted-foreground">
              <div className="text-center space-y-2">
                <Users className="h-8 w-8 mx-auto opacity-50" />
                <p className="text-sm">Advanced segmentation tools coming soon</p>
                <p className="text-xs">Custom filters, lookalike audiences, and behavioral targeting</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}