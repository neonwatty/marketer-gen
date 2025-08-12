import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Label } from "@/components/ui/label"
import { Separator } from "@/components/ui/separator"
import { Badge } from "@/components/ui/badge"
import { PenTool, Wand2, Copy, Download, RefreshCw, Zap } from "lucide-react"
import dynamic from "next/dynamic"

const LLMDemo = dynamic(() => import("@/components/examples/llm-demo"), {
  loading: () => <div className="flex items-center justify-center h-32">Loading LLM Demo...</div>
})

export default function GeneratePage() {
  return (
    <div className="max-w-6xl mx-auto space-y-8">
      {/* Page Header */}
      <div className="space-y-4">
        <h1 className="text-3xl font-bold tracking-tight">Generate Content</h1>
        <p className="text-muted-foreground text-lg">
          Create compelling marketing copy with AI assistance
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Input Form */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <PenTool className="h-5 w-5" />
              Content Details
            </CardTitle>
            <CardDescription>
              Provide information about your product or service to generate tailored marketing copy
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="space-y-2">
              <Label htmlFor="content-type">Content Type</Label>
              <Select>
                <SelectTrigger>
                  <SelectValue placeholder="Select content type" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="email">Email Campaign</SelectItem>
                  <SelectItem value="social">Social Media Post</SelectItem>
                  <SelectItem value="blog">Blog Post</SelectItem>
                  <SelectItem value="ad">Advertisement Copy</SelectItem>
                  <SelectItem value="landing">Landing Page Copy</SelectItem>
                  <SelectItem value="product">Product Description</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="product-service">Product/Service</Label>
              <Input
                id="product-service"
                placeholder="e.g., Eco-friendly water bottles, Digital marketing course..."
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="target-audience">Target Audience</Label>
              <Input
                id="target-audience"
                placeholder="e.g., Health-conscious millennials, Small business owners..."
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="tone">Tone & Style</Label>
              <Select>
                <SelectTrigger>
                  <SelectValue placeholder="Select tone" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="professional">Professional</SelectItem>
                  <SelectItem value="friendly">Friendly</SelectItem>
                  <SelectItem value="casual">Casual</SelectItem>
                  <SelectItem value="urgent">Urgent</SelectItem>
                  <SelectItem value="humorous">Humorous</SelectItem>
                  <SelectItem value="authoritative">Authoritative</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="key-points">Key Points/Benefits</Label>
              <Textarea
                id="key-points"
                placeholder="List the main benefits, features, or points you want to highlight..."
                className="min-h-[100px]"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="call-to-action">Call to Action</Label>
              <Input
                id="call-to-action"
                placeholder="e.g., Shop Now, Learn More, Get Started..."
              />
            </div>

            <Separator />

            <Button className="w-full" size="lg">
              <Wand2 className="h-4 w-4 mr-2" />
              Generate Content
            </Button>
          </CardContent>
        </Card>

        {/* Generated Content */}
        <Card>
          <CardHeader>
            <CardTitle>Generated Content</CardTitle>
            <CardDescription>
              AI-generated marketing copy based on your inputs
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            {/* Preview of generated content */}
            <div className="border rounded-lg p-4 bg-muted/30 min-h-[400px] flex items-center justify-center">
              <div className="text-center space-y-4">
                <PenTool className="h-12 w-12 text-muted-foreground mx-auto" />
                <div>
                  <p className="text-sm font-medium">Ready to generate</p>
                  <p className="text-xs text-muted-foreground">
                    Fill out the form and click "Generate Content" to create your marketing copy
                  </p>
                </div>
              </div>
            </div>

            {/* Action buttons (hidden until content is generated) */}
            <div className="hidden space-y-2">
              <div className="flex gap-2">
                <Button variant="outline" className="flex-1">
                  <RefreshCw className="h-4 w-4 mr-2" />
                  Regenerate
                </Button>
                <Button variant="outline" className="flex-1">
                  <Copy className="h-4 w-4 mr-2" />
                  Copy
                </Button>
              </div>
              <Button variant="outline" className="w-full">
                <Download className="h-4 w-4 mr-2" />
                Export
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Recent Generations */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Generations</CardTitle>
          <CardDescription>
            Your recently generated content pieces
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex items-center justify-between p-4 border rounded-lg">
              <div className="space-y-1">
                <p className="text-sm font-medium">Email Campaign - Product Launch</p>
                <p className="text-xs text-muted-foreground">Generated 2 hours ago</p>
              </div>
              <div className="flex gap-2">
                <Button variant="ghost" size="sm">
                  <Copy className="h-4 w-4" />
                </Button>
                <Button variant="ghost" size="sm">
                  <Download className="h-4 w-4" />
                </Button>
              </div>
            </div>

            <div className="flex items-center justify-between p-4 border rounded-lg">
              <div className="space-y-1">
                <p className="text-sm font-medium">Social Media Post - Holiday Sale</p>
                <p className="text-xs text-muted-foreground">Generated yesterday</p>
              </div>
              <div className="flex gap-2">
                <Button variant="ghost" size="sm">
                  <Copy className="h-4 w-4" />
                </Button>
                <Button variant="ghost" size="sm">
                  <Download className="h-4 w-4" />
                </Button>
              </div>
            </div>

            <div className="flex items-center justify-between p-4 border rounded-lg">
              <div className="space-y-1">
                <p className="text-sm font-medium">Blog Post - SEO Strategy</p>
                <p className="text-xs text-muted-foreground">Generated 3 days ago</p>
              </div>
              <div className="flex gap-2">
                <Button variant="ghost" size="sm">
                  <Copy className="h-4 w-4" />
                </Button>
                <Button variant="ghost" size="sm">
                  <Download className="h-4 w-4" />
                </Button>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* LLM API Demo Section */}
      <Card className="border-2 border-dashed border-primary/20 bg-primary/5">
        <CardHeader>
          <div className="flex items-center justify-between">
            <div className="space-y-1">
              <CardTitle className="flex items-center gap-2">
                <Zap className="h-5 w-5 text-primary" />
                LLM API Demo
                <Badge variant="secondary" className="ml-2">
                  Preview
                </Badge>
              </CardTitle>
              <CardDescription>
                Interactive demonstration of the placeholder LLM API with mock responses and realistic features
              </CardDescription>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <LLMDemo />
        </CardContent>
      </Card>
    </div>
  )
}