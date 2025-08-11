import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Progress } from "@/components/ui/progress"
import { 
  BarChart, 
  TrendingUp, 
  TrendingDown, 
  Eye, 
  MousePointer, 
  Mail, 
  Users, 
  Calendar,
  Download,
  Filter
} from "lucide-react"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"

export default function AnalyticsPage() {
  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Analytics</h1>
          <p className="text-muted-foreground">
            Track performance and optimize your content strategy
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline">
            <Download className="h-4 w-4 mr-2" />
            Export Report
          </Button>
          <Select>
            <SelectTrigger className="w-32">
              <SelectValue placeholder="Last 30 days" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="7d">Last 7 days</SelectItem>
              <SelectItem value="30d">Last 30 days</SelectItem>
              <SelectItem value="90d">Last 90 days</SelectItem>
              <SelectItem value="1y">Last year</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Views</CardTitle>
            <Eye className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">45,231</div>
            <p className="text-xs text-muted-foreground flex items-center">
              <TrendingUp className="h-3 w-3 mr-1 text-green-500" />
              +20.1% from last month
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Click-through Rate</CardTitle>
            <MousePointer className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">3.2%</div>
            <p className="text-xs text-muted-foreground flex items-center">
              <TrendingUp className="h-3 w-3 mr-1 text-green-500" />
              +0.5% from last month
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Email Opens</CardTitle>
            <Mail className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">12,543</div>
            <p className="text-xs text-muted-foreground flex items-center">
              <TrendingDown className="h-3 w-3 mr-1 text-red-500" />
              -2.1% from last month
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Conversions</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">573</div>
            <p className="text-xs text-muted-foreground flex items-center">
              <TrendingUp className="h-3 w-3 mr-1 text-green-500" />
              +12.5% from last month
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Campaign Performance */}
      <Card>
        <CardHeader>
          <CardTitle>Campaign Performance</CardTitle>
          <CardDescription>
            Overview of your active campaigns and their performance metrics
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-6">
            <div className="flex items-center justify-between p-4 border rounded-lg">
              <div className="space-y-1">
                <h4 className="text-sm font-medium">Summer Product Launch</h4>
                <div className="flex items-center gap-4 text-xs text-muted-foreground">
                  <span>Started: Jan 15, 2024</span>
                  <Badge variant="default">Active</Badge>
                </div>
              </div>
              <div className="text-right space-y-1">
                <div className="text-sm font-medium">24.5% CTR</div>
                <div className="text-xs text-muted-foreground">1,234 clicks</div>
              </div>
            </div>

            <div className="flex items-center justify-between p-4 border rounded-lg">
              <div className="space-y-1">
                <h4 className="text-sm font-medium">Holiday Sale Campaign</h4>
                <div className="flex items-center gap-4 text-xs text-muted-foreground">
                  <span>Started: Jan 20, 2024</span>
                  <Badge variant="secondary">Draft</Badge>
                </div>
              </div>
              <div className="text-right space-y-1">
                <div className="text-sm font-medium">--</div>
                <div className="text-xs text-muted-foreground">Not started</div>
              </div>
            </div>

            <div className="flex items-center justify-between p-4 border rounded-lg">
              <div className="space-y-1">
                <h4 className="text-sm font-medium">Email Newsletter Series</h4>
                <div className="flex items-center gap-4 text-xs text-muted-foreground">
                  <span>Started: Jan 10, 2024</span>
                  <Badge variant="outline">Completed</Badge>
                </div>
              </div>
              <div className="text-right space-y-1">
                <div className="text-sm font-medium">18.2% CTR</div>
                <div className="text-xs text-muted-foreground">892 clicks</div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Content Performance */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Top Performing Content</CardTitle>
            <CardDescription>
              Your highest performing content pieces this month
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="space-y-1">
                  <p className="text-sm font-medium">Email: Product Launch</p>
                  <p className="text-xs text-muted-foreground">Sent 2 weeks ago</p>
                </div>
                <div className="text-right space-y-1">
                  <div className="text-sm font-bold">45.2%</div>
                  <div className="text-xs text-muted-foreground">Open rate</div>
                </div>
              </div>

              <div className="flex items-center justify-between">
                <div className="space-y-1">
                  <p className="text-sm font-medium">Social: Holiday Promotion</p>
                  <p className="text-xs text-muted-foreground">Posted 1 week ago</p>
                </div>
                <div className="text-right space-y-1">
                  <div className="text-sm font-bold">8.7%</div>
                  <div className="text-xs text-muted-foreground">Engagement rate</div>
                </div>
              </div>

              <div className="flex items-center justify-between">
                <div className="space-y-1">
                  <p className="text-sm font-medium">Blog: SEO Guide</p>
                  <p className="text-xs text-muted-foreground">Published 3 days ago</p>
                </div>
                <div className="text-right space-y-1">
                  <div className="text-sm font-bold">2,341</div>
                  <div className="text-xs text-muted-foreground">Page views</div>
                </div>
              </div>

              <div className="flex items-center justify-between">
                <div className="space-y-1">
                  <p className="text-sm font-medium">Ad: Facebook Campaign</p>
                  <p className="text-xs text-muted-foreground">Running for 1 month</p>
                </div>
                <div className="text-right space-y-1">
                  <div className="text-sm font-bold">3.4%</div>
                  <div className="text-xs text-muted-foreground">CTR</div>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Channel Performance</CardTitle>
            <CardDescription>
              Performance breakdown by marketing channel
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-6">
              <div className="space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <span>Email Marketing</span>
                  <span className="font-medium">65%</span>
                </div>
                <Progress value={65} className="h-2" />
                <p className="text-xs text-muted-foreground">
                  Highest conversion rate across all channels
                </p>
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <span>Social Media</span>
                  <span className="font-medium">42%</span>
                </div>
                <Progress value={42} className="h-2" />
                <p className="text-xs text-muted-foreground">
                  Strong engagement, moderate conversions
                </p>
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <span>Blog Content</span>
                  <span className="font-medium">38%</span>
                </div>
                <Progress value={38} className="h-2" />
                <p className="text-xs text-muted-foreground">
                  Good organic traffic and lead generation
                </p>
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <span>Paid Ads</span>
                  <span className="font-medium">28%</span>
                </div>
                <Progress value={28} className="h-2" />
                <p className="text-xs text-muted-foreground">
                  Room for improvement in targeting
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}