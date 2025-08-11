import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Plus, Search, Filter, Edit, Copy, Heart, Star } from "lucide-react"

export default function TemplatesPage() {
  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Templates</h1>
          <p className="text-muted-foreground">
            Customize templates for consistent branding and faster content creation
          </p>
        </div>
        <Button>
          <Plus className="h-4 w-4 mr-2" />
          Create Template
        </Button>
      </div>

      {/* Search and Filters */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search templates..."
            className="pl-8"
          />
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm">
            <Filter className="h-4 w-4 mr-2" />
            Filter
          </Button>
          <Button variant="outline" size="sm">
            Category
          </Button>
        </div>
      </div>

      {/* Template Categories */}
      <div className="flex flex-wrap gap-2">
        <Badge variant="default">All</Badge>
        <Badge variant="outline">Email</Badge>
        <Badge variant="outline">Social Media</Badge>
        <Badge variant="outline">Blog Posts</Badge>
        <Badge variant="outline">Advertisements</Badge>
        <Badge variant="outline">Landing Pages</Badge>
      </div>

      {/* Templates Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {/* Email Templates */}
        <Card className="hover:shadow-md transition-shadow">
          <CardHeader>
            <div className="flex items-start justify-between">
              <div className="space-y-1">
                <CardTitle className="text-lg">Welcome Email Series</CardTitle>
                <CardDescription>
                  3-part email sequence for new subscribers
                </CardDescription>
              </div>
              <Button variant="ghost" size="icon">
                <Heart className="h-4 w-4" />
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex flex-wrap gap-2">
                <Badge variant="secondary">Email</Badge>
                <Badge variant="outline">Professional</Badge>
              </div>
              <div className="flex items-center justify-between text-sm">
                <div className="flex items-center gap-1">
                  <Star className="h-4 w-4 text-yellow-500 fill-current" />
                  <span>4.8</span>
                  <span className="text-muted-foreground">(124)</span>
                </div>
                <span className="text-muted-foreground">Used 45 times</span>
              </div>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" className="flex-1">
                  <Edit className="h-4 w-4 mr-2" />
                  Edit
                </Button>
                <Button size="sm" className="flex-1">
                  <Copy className="h-4 w-4 mr-2" />
                  Use Template
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="hover:shadow-md transition-shadow">
          <CardHeader>
            <div className="flex items-start justify-between">
              <div className="space-y-1">
                <CardTitle className="text-lg">Product Launch Social</CardTitle>
                <CardDescription>
                  Social media posts for product announcements
                </CardDescription>
              </div>
              <Button variant="ghost" size="icon">
                <Heart className="h-4 w-4" />
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex flex-wrap gap-2">
                <Badge variant="secondary">Social Media</Badge>
                <Badge variant="outline">Casual</Badge>
              </div>
              <div className="flex items-center justify-between text-sm">
                <div className="flex items-center gap-1">
                  <Star className="h-4 w-4 text-yellow-500 fill-current" />
                  <span>4.6</span>
                  <span className="text-muted-foreground">(89)</span>
                </div>
                <span className="text-muted-foreground">Used 32 times</span>
              </div>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" className="flex-1">
                  <Edit className="h-4 w-4 mr-2" />
                  Edit
                </Button>
                <Button size="sm" className="flex-1">
                  <Copy className="h-4 w-4 mr-2" />
                  Use Template
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="hover:shadow-md transition-shadow">
          <CardHeader>
            <div className="flex items-start justify-between">
              <div className="space-y-1">
                <CardTitle className="text-lg">SEO Blog Post</CardTitle>
                <CardDescription>
                  SEO-optimized blog post structure
                </CardDescription>
              </div>
              <Button variant="ghost" size="icon">
                <Heart className="h-4 w-4 fill-current text-red-500" />
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex flex-wrap gap-2">
                <Badge variant="secondary">Blog</Badge>
                <Badge variant="outline">Professional</Badge>
              </div>
              <div className="flex items-center justify-between text-sm">
                <div className="flex items-center gap-1">
                  <Star className="h-4 w-4 text-yellow-500 fill-current" />
                  <span>4.9</span>
                  <span className="text-muted-foreground">(156)</span>
                </div>
                <span className="text-muted-foreground">Used 78 times</span>
              </div>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" className="flex-1">
                  <Edit className="h-4 w-4 mr-2" />
                  Edit
                </Button>
                <Button size="sm" className="flex-1">
                  <Copy className="h-4 w-4 mr-2" />
                  Use Template
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="hover:shadow-md transition-shadow">
          <CardHeader>
            <div className="flex items-start justify-between">
              <div className="space-y-1">
                <CardTitle className="text-lg">Holiday Sale Campaign</CardTitle>
                <CardDescription>
                  Seasonal promotional email template
                </CardDescription>
              </div>
              <Button variant="ghost" size="icon">
                <Heart className="h-4 w-4" />
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex flex-wrap gap-2">
                <Badge variant="secondary">Email</Badge>
                <Badge variant="outline">Urgent</Badge>
              </div>
              <div className="flex items-center justify-between text-sm">
                <div className="flex items-center gap-1">
                  <Star className="h-4 w-4 text-yellow-500 fill-current" />
                  <span>4.7</span>
                  <span className="text-muted-foreground">(92)</span>
                </div>
                <span className="text-muted-foreground">Used 28 times</span>
              </div>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" className="flex-1">
                  <Edit className="h-4 w-4 mr-2" />
                  Edit
                </Button>
                <Button size="sm" className="flex-1">
                  <Copy className="h-4 w-4 mr-2" />
                  Use Template
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="hover:shadow-md transition-shadow">
          <CardHeader>
            <div className="flex items-start justify-between">
              <div className="space-y-1">
                <CardTitle className="text-lg">Landing Page Copy</CardTitle>
                <CardDescription>
                  High-converting landing page template
                </CardDescription>
              </div>
              <Button variant="ghost" size="icon">
                <Heart className="h-4 w-4" />
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex flex-wrap gap-2">
                <Badge variant="secondary">Landing Page</Badge>
                <Badge variant="outline">Authoritative</Badge>
              </div>
              <div className="flex items-center justify-between text-sm">
                <div className="flex items-center gap-1">
                  <Star className="h-4 w-4 text-yellow-500 fill-current" />
                  <span>4.5</span>
                  <span className="text-muted-foreground">(67)</span>
                </div>
                <span className="text-muted-foreground">Used 19 times</span>
              </div>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" className="flex-1">
                  <Edit className="h-4 w-4 mr-2" />
                  Edit
                </Button>
                <Button size="sm" className="flex-1">
                  <Copy className="h-4 w-4 mr-2" />
                  Use Template
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="hover:shadow-md transition-shadow">
          <CardHeader>
            <div className="flex items-start justify-between">
              <div className="space-y-1">
                <CardTitle className="text-lg">Facebook Ad Copy</CardTitle>
                <CardDescription>
                  High-performing Facebook advertisement template
                </CardDescription>
              </div>
              <Button variant="ghost" size="icon">
                <Heart className="h-4 w-4" />
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex flex-wrap gap-2">
                <Badge variant="secondary">Advertisement</Badge>
                <Badge variant="outline">Friendly</Badge>
              </div>
              <div className="flex items-center justify-between text-sm">
                <div className="flex items-center gap-1">
                  <Star className="h-4 w-4 text-yellow-500 fill-current" />
                  <span>4.4</span>
                  <span className="text-muted-foreground">(51)</span>
                </div>
                <span className="text-muted-foreground">Used 15 times</span>
              </div>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" className="flex-1">
                  <Edit className="h-4 w-4 mr-2" />
                  Edit
                </Button>
                <Button size="sm" className="flex-1">
                  <Copy className="h-4 w-4 mr-2" />
                  Use Template
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}