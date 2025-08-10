import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Progress } from "@/components/ui/progress"
import { PenTool, Target, FileText, BarChart } from "lucide-react"

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-8 bg-gradient-to-br from-brand-50 to-accent-50">
      <div className="max-w-6xl w-full space-y-12">
        {/* Header */}
        <div className="text-center space-y-4">
          <h1 className="text-5xl font-bold text-gradient">
            Marketer Gen
          </h1>
          <p className="text-xl text-gray-600 max-w-2xl mx-auto">
            AI-powered marketing content generator that helps you create compelling copy, manage campaigns, and track performance.
          </p>
          <div className="flex gap-4 justify-center">
            <Button size="lg" className="shadow-medium">
              Get Started
            </Button>
            <Button variant="outline" size="lg">
              Learn More
            </Button>
          </div>
        </div>

        {/* Quick Demo */}
        <div className="max-w-md mx-auto">
          <Card>
            <CardHeader>
              <CardTitle>Try it out</CardTitle>
              <CardDescription>
                Generate your first marketing copy
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <Input placeholder="Enter your product or service..." />
              <Button className="w-full">Generate Copy</Button>
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span>Generation Progress</span>
                  <span>75%</span>
                </div>
                <Progress value={75} />
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Features Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <Card className="hover:shadow-medium transition-all duration-300">
            <CardHeader>
              <PenTool className="h-8 w-8 text-brand-500 mb-2" />
              <CardTitle>Generate Copy</CardTitle>
              <CardDescription>
                Create compelling marketing copy with AI assistance.
              </CardDescription>
            </CardHeader>
          </Card>

          <Card className="hover:shadow-medium transition-all duration-300">
            <CardHeader>
              <Target className="h-8 w-8 text-brand-500 mb-2" />
              <CardTitle>Campaigns</CardTitle>
              <CardDescription>
                Manage and organize your marketing campaigns.
              </CardDescription>
            </CardHeader>
          </Card>

          <Card className="hover:shadow-medium transition-all duration-300">
            <CardHeader>
              <FileText className="h-8 w-8 text-brand-500 mb-2" />
              <CardTitle>Templates</CardTitle>
              <CardDescription>
                Customize templates for consistent branding.
              </CardDescription>
            </CardHeader>
          </Card>

          <Card className="hover:shadow-medium transition-all duration-300">
            <CardHeader>
              <BarChart className="h-8 w-8 text-brand-500 mb-2" />
              <CardTitle>Analytics</CardTitle>
              <CardDescription>
                Track performance and optimize your content.
              </CardDescription>
            </CardHeader>
          </Card>
        </div>
      </div>
    </main>
  )
}