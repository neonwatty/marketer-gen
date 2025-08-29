import { Metadata } from 'next'
import Link from 'next/link'

import { FileText, Filter, Plus, Search, Star, Zap } from 'lucide-react'

import { DashboardBreadcrumb } from '@/components/features/dashboard/DashboardBreadcrumb'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'

export const metadata: Metadata = {
  title: 'Templates | Dashboard',
  description: 'Browse and manage campaign and journey templates',
}

/**
 * Templates page for managing campaign templates, email templates, and journey templates
 */
export default function TemplatesPage() {
  return (
    <div className="space-y-6">
      <DashboardBreadcrumb 
        items={[
          { label: 'Dashboard', href: '/dashboard' },
          { label: 'Templates', href: '/dashboard/templates' }
        ]} 
      />
      
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Templates</h1>
            <p className="text-muted-foreground">
              Browse and manage reusable templates for campaigns and journeys
            </p>
          </div>
          <Button className="flex items-center gap-2">
            <Plus className="h-4 w-4" />
            Create Template
          </Button>
        </div>

        {/* Search and Filters */}
        <div className="flex items-center gap-4">
          <div className="relative flex-1 max-w-sm">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Search templates..."
              className="pl-10"
            />
          </div>
          <Button variant="outline" className="flex items-center gap-2">
            <Filter className="h-4 w-4" />
            Filters
          </Button>
        </div>

        {/* Template Categories */}
        <div className="grid gap-6">
          {/* Campaign Templates */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-semibold">Campaign Templates</h2>
              <Link href="#" className="text-sm text-primary hover:underline">
                View all →
              </Link>
            </div>
            
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              <Card className="cursor-pointer hover:shadow-md transition-shadow">
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="text-lg flex items-center gap-2">
                      <Zap className="h-5 w-5 text-blue-600" />
                      Product Launch
                    </CardTitle>
                    <div className="flex items-center gap-1">
                      <Star className="h-4 w-4 fill-yellow-400 text-yellow-400" />
                      <span className="text-sm">4.8</span>
                    </div>
                  </div>
                  <CardDescription>
                    Complete product launch campaign with pre-launch buzz and follow-up
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground">Duration</span>
                      <span>8-12 weeks</span>
                    </div>
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground">Used</span>
                      <span>247 times</span>
                    </div>
                    <div className="flex flex-wrap gap-1 mt-3">
                      <Badge variant="secondary" className="text-xs">E-commerce</Badge>
                      <Badge variant="secondary" className="text-xs">B2C</Badge>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card className="cursor-pointer hover:shadow-md transition-shadow">
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="text-lg flex items-center gap-2">
                      <FileText className="h-5 w-5 text-green-600" />
                      Lead Nurture
                    </CardTitle>
                    <div className="flex items-center gap-1">
                      <Star className="h-4 w-4 fill-yellow-400 text-yellow-400" />
                      <span className="text-sm">4.6</span>
                    </div>
                  </div>
                  <CardDescription>
                    Multi-touch lead nurturing sequence to convert prospects
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground">Duration</span>
                      <span>4-8 weeks</span>
                    </div>
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground">Used</span>
                      <span>189 times</span>
                    </div>
                    <div className="flex flex-wrap gap-1 mt-3">
                      <Badge variant="secondary" className="text-xs">B2B</Badge>
                      <Badge variant="secondary" className="text-xs">SaaS</Badge>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card className="cursor-pointer hover:shadow-md transition-shadow">
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="text-lg flex items-center gap-2">
                      <FileText className="h-5 w-5 text-purple-600" />
                      Re-engagement
                    </CardTitle>
                    <div className="flex items-center gap-1">
                      <Star className="h-4 w-4 fill-yellow-400 text-yellow-400" />
                      <span className="text-sm">4.4</span>
                    </div>
                  </div>
                  <CardDescription>
                    Win back inactive customers with personalized offers
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground">Duration</span>
                      <span>3-6 weeks</span>
                    </div>
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground">Used</span>
                      <span>156 times</span>
                    </div>
                    <div className="flex flex-wrap gap-1 mt-3">
                      <Badge variant="secondary" className="text-xs">Retention</Badge>
                      <Badge variant="secondary" className="text-xs">Email</Badge>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>

          {/* Email Templates */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-semibold">Email Templates</h2>
              <Link href="#" className="text-sm text-primary hover:underline">
                View all →
              </Link>
            </div>
            
            <Card>
              <CardContent className="p-6">
                <div className="flex items-center justify-center h-32 text-muted-foreground">
                  <div className="text-center space-y-2">
                    <FileText className="h-8 w-8 mx-auto opacity-50" />
                    <p className="text-sm">Email template library coming soon</p>
                    <p className="text-xs">Customizable email designs and layouts</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  )
}