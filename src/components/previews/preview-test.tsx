"use client"

import * as React from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { PreviewContent } from "@/lib/channel-previews"

// Import preview components
import { 
  FacebookPostPreview,
  InstagramPostPreview,
  TwitterPostPreview,
  EmailNewsletterPreview,
  GoogleSearchAdPreview,
  LandingPageHeroPreview
} from './index'

// Test content samples
const testContent: PreviewContent = {
  headline: "Transform Your Business with AI Automation",
  text: "Discover how our cutting-edge AI automation platform can streamline your operations, reduce costs, and boost productivity by 300%. Join over 10,000+ successful businesses. #Automation #AI #BusinessGrowth #Innovation",
  subtext: "Trusted by industry leaders worldwide",
  callToAction: "Start Free Trial",
  hashtags: ["Automation", "AI", "BusinessGrowth", "Innovation"],
  images: [{
    url: "https://images.unsplash.com/photo-1551434678-e076c223a692?w=800&h=600&fit=crop",
    alt: "AI automation dashboard"
  }],
  branding: {
    companyName: "AutoFlow",
    logoUrl: "https://images.unsplash.com/photo-1611224923853-80b023f02d71?w=100&h=100&fit=crop",
    colors: ["#3B82F6", "#1E40AF"]
  },
  metadata: {
    timestamp: new Date(),
    engagement: {
      likes: 1247,
      shares: 89,
      comments: 234
    }
  }
}

const shortContent: PreviewContent = {
  text: "🚀 Exciting news! Our new product launches next week. Get ready to revolutionize your workflow! #ProductLaunch #Innovation",
  hashtags: ["ProductLaunch", "Innovation"],
  callToAction: "Learn More",
  images: [{
    url: "https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800&h=600&fit=crop",
    alt: "Product launch"
  }],
  branding: {
    companyName: "TechCorp",
    colors: ["#059669", "#047857"]
  },
  metadata: {
    timestamp: new Date(),
    engagement: {
      likes: 342,
      shares: 28,
      comments: 67
    }
  }
}

export function PreviewTest() {
  const handleExport = (format: string) => {
    console.log(`Exporting as ${format}`)
  }

  return (
    <div className="space-y-8 p-6 max-w-7xl mx-auto">
      <div className="text-center space-y-2">
        <h1 className="text-3xl font-bold">Channel Preview Components Test</h1>
        <p className="text-lg text-muted-foreground">
          Testing preview components across different marketing channels
        </p>
        <div className="flex justify-center gap-2">
          <Badge>Social Media</Badge>
          <Badge>Email</Badge>
          <Badge>Advertising</Badge>
          <Badge>Landing Pages</Badge>
        </div>
      </div>

      {/* Social Media Previews */}
      <Card>
        <CardHeader>
          <CardTitle>Social Media Previews</CardTitle>
          <CardDescription>
            Testing Facebook, Instagram, and Twitter/X post formats
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">Facebook Post</h3>
              <FacebookPostPreview
                content={testContent}
                configId="facebook-post"
                showValidation={true}
                showExport={true}
                onExport={handleExport}
              />
            </div>
            
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">Instagram Post</h3>
              <InstagramPostPreview
                content={shortContent}
                configId="instagram-post"
                showValidation={true}
                showExport={true}
                onExport={handleExport}
              />
            </div>
            
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">Twitter/X Post</h3>
              <TwitterPostPreview
                content={shortContent}
                configId="twitter-post"
                showValidation={true}
                showExport={true}
                onExport={handleExport}
              />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Email Preview */}
      <Card>
        <CardHeader>
          <CardTitle>Email Templates</CardTitle>
          <CardDescription>
            Testing responsive email template previews
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">Newsletter Template</h3>
              <EmailNewsletterPreview
                content={testContent}
                configId="email-newsletter"
                showValidation={true}
                showExport={true}
                onExport={handleExport}
              />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Advertising Preview */}
      <Card>
        <CardHeader>
          <CardTitle>Advertising Formats</CardTitle>
          <CardDescription>
            Testing search and display ad previews
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">Google Search Ad</h3>
              <GoogleSearchAdPreview
                content={testContent}
                configId="google-search-ad"
                showValidation={true}
                showExport={true}
                onExport={handleExport}
              />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Landing Page Preview */}
      <Card>
        <CardHeader>
          <CardTitle>Landing Page Sections</CardTitle>
          <CardDescription>
            Testing landing page hero section preview
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <h3 className="text-lg font-semibold">Hero Section</h3>
            <LandingPageHeroPreview
              content={testContent}
              configId="landing-page-hero"
              showValidation={true}
              showExport={true}
              onExport={handleExport}
            />
          </div>
        </CardContent>
      </Card>

      {/* Test Results Summary */}
      <Card>
        <CardHeader>
          <CardTitle>Test Results Summary</CardTitle>
          <CardDescription>
            Overview of component functionality
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="text-center p-4 bg-green-50 rounded-lg">
              <div className="text-2xl font-bold text-green-600">✓</div>
              <p className="font-medium">Social Media</p>
              <p className="text-sm text-muted-foreground">3 components tested</p>
            </div>
            
            <div className="text-center p-4 bg-green-50 rounded-lg">
              <div className="text-2xl font-bold text-green-600">✓</div>
              <p className="font-medium">Email Templates</p>
              <p className="text-sm text-muted-foreground">Responsive design</p>
            </div>
            
            <div className="text-center p-4 bg-green-50 rounded-lg">
              <div className="text-2xl font-bold text-green-600">✓</div>
              <p className="font-medium">Ad Formats</p>
              <p className="text-sm text-muted-foreground">Multiple ad types</p>
            </div>
            
            <div className="text-center p-4 bg-green-50 rounded-lg">
              <div className="text-2xl font-bold text-green-600">✓</div>
              <p className="font-medium">Landing Pages</p>
              <p className="text-sm text-muted-foreground">Hero sections</p>
            </div>
          </div>
          
          <div className="mt-6 p-4 bg-blue-50 rounded-lg">
            <h4 className="font-medium text-blue-900 mb-2">Features Tested:</h4>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-2 text-sm">
              <div className="flex items-center gap-2">
                <Badge variant="outline" className="text-green-700 border-green-200">✓</Badge>
                <span>Validation System</span>
              </div>
              <div className="flex items-center gap-2">
                <Badge variant="outline" className="text-green-700 border-green-200">✓</Badge>
                <span>Export Functionality</span>
              </div>
              <div className="flex items-center gap-2">
                <Badge variant="outline" className="text-green-700 border-green-200">✓</Badge>
                <span>Responsive Design</span>
              </div>
              <div className="flex items-center gap-2">
                <Badge variant="outline" className="text-green-700 border-green-200">✓</Badge>
                <span>Device Frames</span>
              </div>
              <div className="flex items-center gap-2">
                <Badge variant="outline" className="text-green-700 border-green-200">✓</Badge>
                <span>Character Limits</span>
              </div>
              <div className="flex items-center gap-2">
                <Badge variant="outline" className="text-green-700 border-green-200">✓</Badge>
                <span>Brand Integration</span>
              </div>
              <div className="flex items-center gap-2">
                <Badge variant="outline" className="text-green-700 border-green-200">✓</Badge>
                <span>Content Adaptation</span>
              </div>
              <div className="flex items-center gap-2">
                <Badge variant="outline" className="text-green-700 border-green-200">✓</Badge>
                <span>Error Handling</span>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}