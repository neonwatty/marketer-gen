import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Switch } from "@/components/ui/switch"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Separator } from "@/components/ui/separator"
import { Badge } from "@/components/ui/badge"
import { Save, Key, Palette, Bell, Shield, Users, Trash2 } from "lucide-react"

export default function SettingsPage() {
  return (
    <div className="max-w-4xl mx-auto space-y-8">
      {/* Page Header */}
      <div className="space-y-4">
        <h1 className="text-3xl font-bold tracking-tight">Settings</h1>
        <p className="text-muted-foreground">
          Configure your account preferences and application settings
        </p>
      </div>

      {/* Profile Settings */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Users className="h-5 w-5" />
            Profile Settings
          </CardTitle>
          <CardDescription>
            Update your personal information and profile details
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="first-name">First Name</Label>
              <Input id="first-name" defaultValue="John" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="last-name">Last Name</Label>
              <Input id="last-name" defaultValue="Doe" />
            </div>
          </div>
          
          <div className="space-y-2">
            <Label htmlFor="email">Email Address</Label>
            <Input id="email" type="email" defaultValue="john.doe@example.com" />
          </div>

          <div className="space-y-2">
            <Label htmlFor="company">Company</Label>
            <Input id="company" defaultValue="Acme Marketing Inc." />
          </div>

          <div className="space-y-2">
            <Label htmlFor="bio">Bio</Label>
            <Textarea 
              id="bio" 
              placeholder="Tell us about yourself..."
              defaultValue="Marketing professional with 5+ years of experience in digital marketing and content creation."
            />
          </div>

          <Button>
            <Save className="h-4 w-4 mr-2" />
            Save Changes
          </Button>
        </CardContent>
      </Card>

      {/* Brand Settings */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Palette className="h-5 w-5" />
            Brand Settings
          </CardTitle>
          <CardDescription>
            Configure your brand guidelines for consistent content generation
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="space-y-2">
            <Label htmlFor="brand-name">Brand Name</Label>
            <Input id="brand-name" defaultValue="Acme Products" />
          </div>

          <div className="space-y-2">
            <Label htmlFor="brand-voice">Brand Voice</Label>
            <Select>
              <SelectTrigger>
                <SelectValue placeholder="Select brand voice" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="professional">Professional</SelectItem>
                <SelectItem value="friendly">Friendly</SelectItem>
                <SelectItem value="casual">Casual</SelectItem>
                <SelectItem value="authoritative">Authoritative</SelectItem>
                <SelectItem value="playful">Playful</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="brand-colors">Brand Colors</Label>
            <div className="flex gap-2">
              <div className="flex flex-col items-center space-y-2">
                <div className="w-12 h-12 bg-blue-600 rounded-lg border"></div>
                <Input className="w-20 text-center" defaultValue="#2563eb" />
              </div>
              <div className="flex flex-col items-center space-y-2">
                <div className="w-12 h-12 bg-green-600 rounded-lg border"></div>
                <Input className="w-20 text-center" defaultValue="#16a34a" />
              </div>
              <div className="flex flex-col items-center space-y-2">
                <div className="w-12 h-12 bg-gray-800 rounded-lg border"></div>
                <Input className="w-20 text-center" defaultValue="#1f2937" />
              </div>
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="brand-guidelines">Brand Guidelines</Label>
            <Textarea 
              id="brand-guidelines" 
              placeholder="Describe your brand personality, key messages, and content guidelines..."
              defaultValue="We focus on innovation, quality, and customer satisfaction. Our content should be informative, engaging, and solution-oriented."
            />
          </div>

          <Button>
            <Save className="h-4 w-4 mr-2" />
            Update Brand Settings
          </Button>
        </CardContent>
      </Card>

      {/* API Settings */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Key className="h-5 w-5" />
            API Configuration
          </CardTitle>
          <CardDescription>
            Configure AI model preferences and API settings
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="space-y-2">
            <Label htmlFor="ai-model">Preferred AI Model</Label>
            <Select>
              <SelectTrigger>
                <SelectValue placeholder="Select AI model" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="gpt-4">GPT-4 (Premium)</SelectItem>
                <SelectItem value="gpt-3.5">GPT-3.5 Turbo</SelectItem>
                <SelectItem value="claude">Claude-3</SelectItem>
                <SelectItem value="palm">PaLM 2</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label>Content Generation Settings</Label>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <div className="text-sm font-medium">Creative Mode</div>
                  <div className="text-xs text-muted-foreground">
                    Generate more creative and varied content
                  </div>
                </div>
                <Switch defaultChecked />
              </div>

              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <div className="text-sm font-medium">SEO Optimization</div>
                  <div className="text-xs text-muted-foreground">
                    Automatically optimize content for search engines
                  </div>
                </div>
                <Switch defaultChecked />
              </div>

              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <div className="text-sm font-medium">Brand Guidelines Integration</div>
                  <div className="text-xs text-muted-foreground">
                    Apply brand voice and guidelines to all content
                  </div>
                </div>
                <Switch defaultChecked />
              </div>
            </div>
          </div>

          <Button>
            <Save className="h-4 w-4 mr-2" />
            Save API Settings
          </Button>
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
            Control how and when you receive notifications
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <div className="text-sm font-medium">Email Notifications</div>
                <div className="text-xs text-muted-foreground">
                  Receive updates about campaigns and content generation
                </div>
              </div>
              <Switch defaultChecked />
            </div>

            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <div className="text-sm font-medium">Campaign Updates</div>
                <div className="text-xs text-muted-foreground">
                  Get notified when campaigns are completed or need attention
                </div>
              </div>
              <Switch defaultChecked />
            </div>

            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <div className="text-sm font-medium">Weekly Reports</div>
                <div className="text-xs text-muted-foreground">
                  Receive weekly performance and analytics reports
                </div>
              </div>
              <Switch />
            </div>

            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <div className="text-sm font-medium">Product Updates</div>
                <div className="text-xs text-muted-foreground">
                  Stay informed about new features and improvements
                </div>
              </div>
              <Switch />
            </div>
          </div>

          <Button>
            <Save className="h-4 w-4 mr-2" />
            Save Notification Preferences
          </Button>
        </CardContent>
      </Card>

      {/* Account Management */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Shield className="h-5 w-5" />
            Account Management
          </CardTitle>
          <CardDescription>
            Manage your account security and subscription
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="space-y-4">
            <div className="flex items-center justify-between p-4 border rounded-lg">
              <div>
                <div className="text-sm font-medium">Current Plan</div>
                <div className="text-xs text-muted-foreground">Professional Plan</div>
              </div>
              <Badge variant="default">Active</Badge>
            </div>

            <div className="flex items-center justify-between p-4 border rounded-lg">
              <div>
                <div className="text-sm font-medium">Password</div>
                <div className="text-xs text-muted-foreground">Last changed 3 months ago</div>
              </div>
              <Button variant="outline" size="sm">
                Change Password
              </Button>
            </div>

            <div className="flex items-center justify-between p-4 border rounded-lg">
              <div>
                <div className="text-sm font-medium">Two-Factor Authentication</div>
                <div className="text-xs text-muted-foreground">Add an extra layer of security</div>
              </div>
              <Button variant="outline" size="sm">
                Enable 2FA
              </Button>
            </div>
          </div>

          <Separator />

          <div className="space-y-4">
            <div className="text-sm font-medium text-destructive">Danger Zone</div>
            <div className="flex items-center justify-between p-4 border border-destructive rounded-lg">
              <div>
                <div className="text-sm font-medium">Delete Account</div>
                <div className="text-xs text-muted-foreground">
                  Permanently delete your account and all associated data
                </div>
              </div>
              <Button variant="destructive" size="sm">
                <Trash2 className="h-4 w-4 mr-2" />
                Delete Account
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}