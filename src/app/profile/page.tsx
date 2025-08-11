import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Progress } from "@/components/ui/progress"
import { 
  User, 
  Mail, 
  MapPin, 
  Calendar, 
  Award, 
  TrendingUp,
  PenTool,
  Target,
  BarChart,
  Edit
} from "lucide-react"

export default function ProfilePage() {
  return (
    <div className="max-w-4xl mx-auto space-y-8">
      {/* Page Header */}
      <div className="space-y-4">
        <h1 className="text-3xl font-bold tracking-tight">Profile</h1>
        <p className="text-muted-foreground">
          View and manage your profile information and achievements
        </p>
      </div>

      {/* Profile Overview */}
      <Card>
        <CardContent className="pt-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center gap-6">
            <Avatar className="h-24 w-24">
              <AvatarImage src="/placeholder-avatar.jpg" alt="Profile picture" />
              <AvatarFallback className="text-2xl">JD</AvatarFallback>
            </Avatar>
            
            <div className="flex-1 space-y-4">
              <div>
                <h2 className="text-2xl font-bold">John Doe</h2>
                <p className="text-muted-foreground">Marketing Manager at Acme Corp</p>
              </div>
              
              <div className="flex flex-wrap gap-4 text-sm text-muted-foreground">
                <div className="flex items-center gap-2">
                  <Mail className="h-4 w-4" />
                  <span>john.doe@example.com</span>
                </div>
                <div className="flex items-center gap-2">
                  <MapPin className="h-4 w-4" />
                  <span>San Francisco, CA</span>
                </div>
                <div className="flex items-center gap-2">
                  <Calendar className="h-4 w-4" />
                  <span>Joined January 2024</span>
                </div>
              </div>

              <div className="flex gap-2">
                <Button>
                  <Edit className="h-4 w-4 mr-2" />
                  Edit Profile
                </Button>
                <Button variant="outline">Change Avatar</Button>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Content Generated</CardTitle>
            <PenTool className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">1,234</div>
            <p className="text-xs text-muted-foreground">
              +89 this month
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Campaigns Created</CardTitle>
            <Target className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">47</div>
            <p className="text-xs text-muted-foreground">
              +3 this month
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg. Performance</CardTitle>
            <BarChart className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">87%</div>
            <p className="text-xs text-muted-foreground">
              Above industry average
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Achievements */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Award className="h-5 w-5" />
            Achievements
          </CardTitle>
          <CardDescription>
            Your milestones and accomplishments on the platform
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-4">
              <div className="flex items-center gap-3 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
                <div className="bg-yellow-500 text-white p-2 rounded-full">
                  <Award className="h-4 w-4" />
                </div>
                <div>
                  <p className="text-sm font-medium">Content Creator</p>
                  <p className="text-xs text-muted-foreground">Generated 1,000+ pieces of content</p>
                </div>
              </div>

              <div className="flex items-center gap-3 p-3 bg-green-50 border border-green-200 rounded-lg">
                <div className="bg-green-500 text-white p-2 rounded-full">
                  <TrendingUp className="h-4 w-4" />
                </div>
                <div>
                  <p className="text-sm font-medium">High Performer</p>
                  <p className="text-xs text-muted-foreground">Achieved 80%+ campaign success rate</p>
                </div>
              </div>

              <div className="flex items-center gap-3 p-3 bg-blue-50 border border-blue-200 rounded-lg">
                <div className="bg-blue-500 text-white p-2 rounded-full">
                  <Target className="h-4 w-4" />
                </div>
                <div>
                  <p className="text-sm font-medium">Campaign Master</p>
                  <p className="text-xs text-muted-foreground">Created 25+ successful campaigns</p>
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <div className="flex items-center gap-3 p-3 bg-gray-50 border border-gray-200 rounded-lg opacity-50">
                <div className="bg-gray-400 text-white p-2 rounded-full">
                  <Award className="h-4 w-4" />
                </div>
                <div>
                  <p className="text-sm font-medium">Template Expert</p>
                  <p className="text-xs text-muted-foreground">Create 50+ templates (12/50)</p>
                </div>
              </div>

              <div className="flex items-center gap-3 p-3 bg-gray-50 border border-gray-200 rounded-lg opacity-50">
                <div className="bg-gray-400 text-white p-2 rounded-full">
                  <BarChart className="h-4 w-4" />
                </div>
                <div>
                  <p className="text-sm font-medium">Analytics Pro</p>
                  <p className="text-xs text-muted-foreground">Export 100+ reports (34/100)</p>
                </div>
              </div>

              <div className="flex items-center gap-3 p-3 bg-gray-50 border border-gray-200 rounded-lg opacity-50">
                <div className="bg-gray-400 text-white p-2 rounded-full">
                  <PenTool className="h-4 w-4" />
                </div>
                <div>
                  <p className="text-sm font-medium">Content Guru</p>
                  <p className="text-xs text-muted-foreground">Generate 5,000+ pieces (1,234/5,000)</p>
                </div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Progress Tracking */}
      <Card>
        <CardHeader>
          <CardTitle>Progress Tracking</CardTitle>
          <CardDescription>
            Track your progress towards the next achievements
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-6">
            <div className="space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span>Template Expert</span>
                <span className="text-muted-foreground">12/50 templates created</span>
              </div>
              <Progress value={24} className="h-2" />
            </div>

            <div className="space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span>Analytics Pro</span>
                <span className="text-muted-foreground">34/100 reports exported</span>
              </div>
              <Progress value={34} className="h-2" />
            </div>

            <div className="space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span>Content Guru</span>
                <span className="text-muted-foreground">1,234/5,000 pieces generated</span>
              </div>
              <Progress value={25} className="h-2" />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Recent Activity */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Activity</CardTitle>
          <CardDescription>
            Your latest actions and content creation
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <div className="bg-primary/10 p-2 rounded-lg">
                <PenTool className="h-4 w-4 text-primary" />
              </div>
              <div className="flex-1">
                <p className="text-sm font-medium">Generated email campaign copy</p>
                <p className="text-xs text-muted-foreground">2 hours ago</p>
              </div>
            </div>

            <div className="flex items-center gap-3">
              <div className="bg-green-100 p-2 rounded-lg">
                <Target className="h-4 w-4 text-green-600" />
              </div>
              <div className="flex-1">
                <p className="text-sm font-medium">Launched "Summer Sale" campaign</p>
                <p className="text-xs text-muted-foreground">Yesterday</p>
              </div>
            </div>

            <div className="flex items-center gap-3">
              <div className="bg-blue-100 p-2 rounded-lg">
                <BarChart className="h-4 w-4 text-blue-600" />
              </div>
              <div className="flex-1">
                <p className="text-sm font-medium">Exported analytics report</p>
                <p className="text-xs text-muted-foreground">2 days ago</p>
              </div>
            </div>

            <div className="flex items-center gap-3">
              <div className="bg-purple-100 p-2 rounded-lg">
                <Award className="h-4 w-4 text-purple-600" />
              </div>
              <div className="flex-1">
                <p className="text-sm font-medium">Earned "Campaign Master" achievement</p>
                <p className="text-xs text-muted-foreground">1 week ago</p>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}