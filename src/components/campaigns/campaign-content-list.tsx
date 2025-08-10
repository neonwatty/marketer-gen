"use client"

import * as React from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { 
  FileText, 
  Mail, 
  Share2, 
  Image, 
  Video, 
  Plus, 
  Search, 
  Filter,
  Eye,
  Edit,
  Copy,
  Trash2,
  MoreHorizontal,
  Calendar,
  TrendingUp,
  Users
} from "lucide-react"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"

interface ContentItem {
  id: string
  title: string
  type: "blog-post" | "social-post" | "email-newsletter" | "landing-page" | "video-script" | "ad-copy" | "infographic"
  status: "draft" | "review" | "published" | "scheduled" | "archived"
  channel: string
  journeyStage: string
  createdAt: string
  publishedAt?: string
  metrics?: {
    views: number
    engagement: number
    conversions: number
  }
}

interface CampaignContentListProps {
  campaignId: string
}

// Mock content data
const mockContent: ContentItem[] = [
  {
    id: "1",
    title: "Sustainable Living: 10 Easy Ways to Start Today",
    type: "blog-post",
    status: "published",
    channel: "Blog",
    journeyStage: "Awareness",
    createdAt: "2024-02-01",
    publishedAt: "2024-02-05",
    metrics: {
      views: 12500,
      engagement: 6.2,
      conversions: 45
    }
  },
  {
    id: "2",
    title: "Welcome to Our Eco-Friendly Product Line",
    type: "email-newsletter",
    status: "published",
    channel: "Email",
    journeyStage: "Awareness",
    createdAt: "2024-02-08",
    publishedAt: "2024-02-10",
    metrics: {
      views: 8500,
      engagement: 12.3,
      conversions: 78
    }
  },
  {
    id: "3",
    title: "🌱 Transform Your Home with Sustainable Products",
    type: "social-post",
    status: "published",
    channel: "Social Media",
    journeyStage: "Consideration",
    createdAt: "2024-02-12",
    publishedAt: "2024-02-15",
    metrics: {
      views: 25000,
      engagement: 4.8,
      conversions: 32
    }
  },
  {
    id: "4",
    title: "Shop Sustainable - Landing Page",
    type: "landing-page",
    status: "published",
    channel: "Website",
    journeyStage: "Conversion",
    createdAt: "2024-02-18",
    publishedAt: "2024-02-20",
    metrics: {
      views: 5500,
      engagement: 15.6,
      conversions: 156
    }
  },
  {
    id: "5",
    title: "Product Comparison: Why Choose Eco?",
    type: "infographic",
    status: "review",
    channel: "Social Media",
    journeyStage: "Consideration",
    createdAt: "2024-03-10"
  },
  {
    id: "6",
    title: "Customer Success Stories Email Series",
    type: "email-newsletter",
    status: "scheduled",
    channel: "Email",
    journeyStage: "Retention",
    createdAt: "2024-03-15",
    publishedAt: "2024-03-25"
  },
  {
    id: "7",
    title: "Limited Time: 20% Off Sustainable Collection",
    type: "ad-copy",
    status: "draft",
    channel: "Display Ads",
    journeyStage: "Conversion",
    createdAt: "2024-03-20"
  },
  {
    id: "8",
    title: "How Our Products Are Made - Behind the Scenes",
    type: "video-script",
    status: "draft",
    channel: "Social Media",
    journeyStage: "Consideration",
    createdAt: "2024-03-22"
  }
]

const getContentIcon = (type: ContentItem['type']) => {
  switch (type) {
    case "blog-post":
      return <FileText className="h-4 w-4" />
    case "email-newsletter":
      return <Mail className="h-4 w-4" />
    case "social-post":
      return <Share2 className="h-4 w-4" />
    case "landing-page":
      return <FileText className="h-4 w-4" />
    case "video-script":
      return <Video className="h-4 w-4" />
    case "ad-copy":
      return <Image className="h-4 w-4" />
    case "infographic":
      return <Image className="h-4 w-4" />
    default:
      return <FileText className="h-4 w-4" />
  }
}

const getStatusColor = (status: ContentItem['status']) => {
  switch (status) {
    case "published":
      return "bg-green-100 text-green-800 border-green-200"
    case "scheduled":
      return "bg-blue-100 text-blue-800 border-blue-200"
    case "review":
      return "bg-yellow-100 text-yellow-800 border-yellow-200"
    case "draft":
      return "bg-slate-100 text-slate-800 border-slate-200"
    case "archived":
      return "bg-red-100 text-red-800 border-red-200"
    default:
      return "bg-slate-100 text-slate-800 border-slate-200"
  }
}

const formatNumber = (num: number) => {
  if (num >= 1000000) {
    return (num / 1000000).toFixed(1) + 'M'
  }
  if (num >= 1000) {
    return (num / 1000).toFixed(1) + 'K'
  }
  return num.toString()
}

export function CampaignContentList({ campaignId }: CampaignContentListProps) {
  const [searchTerm, setSearchTerm] = React.useState("")
  const [selectedStatus, setSelectedStatus] = React.useState<string>("all")
  const [selectedType, setSelectedType] = React.useState<string>("all")

  const filteredContent = mockContent.filter(item => {
    const matchesSearch = item.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         item.channel.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesStatus = selectedStatus === "all" || item.status === selectedStatus
    const matchesType = selectedType === "all" || item.type === selectedType
    
    return matchesSearch && matchesStatus && matchesType
  })

  const contentByStatus = {
    draft: mockContent.filter(item => item.status === "draft").length,
    review: mockContent.filter(item => item.status === "review").length,
    published: mockContent.filter(item => item.status === "published").length,
    scheduled: mockContent.filter(item => item.status === "scheduled").length,
  }

  const totalMetrics = mockContent.reduce((acc, item) => {
    if (item.metrics) {
      acc.views += item.metrics.views
      acc.conversions += item.metrics.conversions
    }
    return acc
  }, { views: 0, conversions: 0 })

  const handleContentAction = (action: string, contentId: string) => {
    console.log(`${action} content:`, contentId)
  }

  return (
    <div className="space-y-6">
      {/* Content Overview */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Total Content</p>
                <p className="text-2xl font-bold">{mockContent.length}</p>
              </div>
              <FileText className="h-8 w-8 text-blue-600" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Published</p>
                <p className="text-2xl font-bold">{contentByStatus.published}</p>
              </div>
              <Eye className="h-8 w-8 text-green-600" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Total Views</p>
                <p className="text-2xl font-bold">{formatNumber(totalMetrics.views)}</p>
              </div>
              <Users className="h-8 w-8 text-purple-600" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Conversions</p>
                <p className="text-2xl font-bold">{totalMetrics.conversions}</p>
              </div>
              <TrendingUp className="h-8 w-8 text-orange-600" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Content Management */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Campaign Content</CardTitle>
              <CardDescription>
                Manage and track all content pieces for this campaign
              </CardDescription>
            </div>
            <Button>
              <Plus className="h-4 w-4 mr-2" />
              Create Content
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          {/* Filters and Search */}
          <div className="flex flex-col sm:flex-row gap-4 mb-6">
            <div className="relative flex-1 max-w-sm">
              <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Search content..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-8"
              />
            </div>
            <div className="flex gap-2">
              <select
                value={selectedStatus}
                onChange={(e) => setSelectedStatus(e.target.value)}
                className="px-3 py-2 border border-input rounded-md text-sm"
              >
                <option value="all">All Status</option>
                <option value="draft">Draft</option>
                <option value="review">Review</option>
                <option value="published">Published</option>
                <option value="scheduled">Scheduled</option>
              </select>
              <select
                value={selectedType}
                onChange={(e) => setSelectedType(e.target.value)}
                className="px-3 py-2 border border-input rounded-md text-sm"
              >
                <option value="all">All Types</option>
                <option value="blog-post">Blog Posts</option>
                <option value="email-newsletter">Email</option>
                <option value="social-post">Social</option>
                <option value="landing-page">Landing Page</option>
                <option value="video-script">Video</option>
                <option value="ad-copy">Ad Copy</option>
                <option value="infographic">Infographic</option>
              </select>
            </div>
          </div>

          {/* Content Status Tabs */}
          <Tabs defaultValue="all" className="space-y-4">
            <TabsList>
              <TabsTrigger value="all">All ({filteredContent.length})</TabsTrigger>
              <TabsTrigger value="draft">Draft ({contentByStatus.draft})</TabsTrigger>
              <TabsTrigger value="review">Review ({contentByStatus.review})</TabsTrigger>
              <TabsTrigger value="published">Published ({contentByStatus.published})</TabsTrigger>
              <TabsTrigger value="scheduled">Scheduled ({contentByStatus.scheduled})</TabsTrigger>
            </TabsList>

            <TabsContent value="all" className="space-y-4">
              {filteredContent.map((item) => (
                <div key={item.id} className="border rounded-lg p-4 hover:shadow-md transition-shadow">
                  <div className="flex items-start justify-between">
                    <div className="flex items-start gap-3 flex-1">
                      <div className="flex-shrink-0 mt-1">
                        {getContentIcon(item.type)}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1">
                          <h3 className="font-medium truncate">{item.title}</h3>
                          <Badge className={getStatusColor(item.status)} variant="outline">
                            {item.status.charAt(0).toUpperCase() + item.status.slice(1)}
                          </Badge>
                        </div>
                        
                        <div className="flex items-center gap-4 text-sm text-muted-foreground mb-2">
                          <span>{item.type.replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase())}</span>
                          <span>•</span>
                          <span>{item.channel}</span>
                          <span>•</span>
                          <span>{item.journeyStage} Stage</span>
                          <span>•</span>
                          <span>Created {new Date(item.createdAt).toLocaleDateString()}</span>
                        </div>

                        {item.metrics && (
                          <div className="flex items-center gap-6 text-sm">
                            <div className="flex items-center gap-1">
                              <Eye className="h-3 w-3" />
                              <span>{formatNumber(item.metrics.views)} views</span>
                            </div>
                            <div className="flex items-center gap-1">
                              <TrendingUp className="h-3 w-3" />
                              <span>{item.metrics.engagement}% engagement</span>
                            </div>
                            <div className="flex items-center gap-1">
                              <Users className="h-3 w-3" />
                              <span>{item.metrics.conversions} conversions</span>
                            </div>
                          </div>
                        )}
                      </div>
                    </div>

                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="ghost" size="sm">
                          <MoreHorizontal className="h-4 w-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem onClick={() => handleContentAction("view", item.id)}>
                          <Eye className="h-4 w-4 mr-2" />
                          View Content
                        </DropdownMenuItem>
                        <DropdownMenuItem onClick={() => handleContentAction("edit", item.id)}>
                          <Edit className="h-4 w-4 mr-2" />
                          Edit
                        </DropdownMenuItem>
                        <DropdownMenuItem onClick={() => handleContentAction("copy", item.id)}>
                          <Copy className="h-4 w-4 mr-2" />
                          Duplicate
                        </DropdownMenuItem>
                        {item.status === "draft" && (
                          <>
                            <DropdownMenuSeparator />
                            <DropdownMenuItem onClick={() => handleContentAction("publish", item.id)}>
                              <Calendar className="h-4 w-4 mr-2" />
                              Schedule
                            </DropdownMenuItem>
                          </>
                        )}
                        <DropdownMenuSeparator />
                        <DropdownMenuItem 
                          onClick={() => handleContentAction("delete", item.id)}
                          className="text-red-600 focus:text-red-600"
                        >
                          <Trash2 className="h-4 w-4 mr-2" />
                          Delete
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>
                </div>
              ))}

              {filteredContent.length === 0 && (
                <div className="text-center py-8">
                  <FileText className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
                  <h3 className="text-lg font-semibold mb-2">No content found</h3>
                  <p className="text-muted-foreground mb-4">
                    {searchTerm || selectedStatus !== "all" || selectedType !== "all"
                      ? "Try adjusting your filters to see more content."
                      : "Get started by creating your first piece of content for this campaign."
                    }
                  </p>
                  <Button>
                    <Plus className="h-4 w-4 mr-2" />
                    Create Content
                  </Button>
                </div>
              )}
            </TabsContent>

            {/* Other tab contents would filter by status */}
            {["draft", "review", "published", "scheduled"].map((status) => (
              <TabsContent key={status} value={status} className="space-y-4">
                {mockContent
                  .filter(item => item.status === status)
                  .filter(item => 
                    item.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    item.channel.toLowerCase().includes(searchTerm.toLowerCase())
                  )
                  .map((item) => (
                    <div key={item.id} className="border rounded-lg p-4 hover:shadow-md transition-shadow">
                      {/* Same content structure as above */}
                      <div className="flex items-start justify-between">
                        <div className="flex items-start gap-3 flex-1">
                          <div className="flex-shrink-0 mt-1">
                            {getContentIcon(item.type)}
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 mb-1">
                              <h3 className="font-medium truncate">{item.title}</h3>
                              <Badge className={getStatusColor(item.status)} variant="outline">
                                {item.status.charAt(0).toUpperCase() + item.status.slice(1)}
                              </Badge>
                            </div>
                            <div className="flex items-center gap-4 text-sm text-muted-foreground mb-2">
                              <span>{item.type.replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase())}</span>
                              <span>•</span>
                              <span>{item.channel}</span>
                              <span>•</span>
                              <span>{item.journeyStage} Stage</span>
                              <span>•</span>
                              <span>Created {new Date(item.createdAt).toLocaleDateString()}</span>
                            </div>
                            {item.metrics && (
                              <div className="flex items-center gap-6 text-sm">
                                <div className="flex items-center gap-1">
                                  <Eye className="h-3 w-3" />
                                  <span>{formatNumber(item.metrics.views)} views</span>
                                </div>
                                <div className="flex items-center gap-1">
                                  <TrendingUp className="h-3 w-3" />
                                  <span>{item.metrics.engagement}% engagement</span>
                                </div>
                                <div className="flex items-center gap-1">
                                  <Users className="h-3 w-3" />
                                  <span>{item.metrics.conversions} conversions</span>
                                </div>
                              </div>
                            )}
                          </div>
                        </div>
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="sm">
                              <MoreHorizontal className="h-4 w-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuItem onClick={() => handleContentAction("view", item.id)}>
                              <Eye className="h-4 w-4 mr-2" />
                              View Content
                            </DropdownMenuItem>
                            <DropdownMenuItem onClick={() => handleContentAction("edit", item.id)}>
                              <Edit className="h-4 w-4 mr-2" />
                              Edit
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </div>
                    </div>
                  ))}
              </TabsContent>
            ))}
          </Tabs>
        </CardContent>
      </Card>
    </div>
  )
}