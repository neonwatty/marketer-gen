"use client"

import * as React from "react"
import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { 
  Select, 
  SelectContent, 
  SelectItem, 
  SelectTrigger, 
  SelectValue 
} from "@/components/ui/select"
import { PreviewContent, CHANNEL_CONFIGS } from "@/lib/channel-previews"

// Import all preview components
import {
  FacebookPostPreview,
  InstagramPostPreview,
  InstagramStoryPreview,
  TwitterPostPreview,
  EmailNewsletterPreview,
  EmailPromotionalPreview,
  GoogleSearchAdPreview,
  FacebookAdPreview,
  DisplayBannerAdPreview,
  ShoppingAdPreview,
  VideoAdPreview,
  LandingPageHeroPreview,
  LandingPageFeaturesPreview,
  LandingPageTestimonialsPreview,
  LandingPageContactPreview
} from './index'

// Sample content for testing different types
const sampleContent: Record<string, PreviewContent> = {
  'short-social': {
    text: "🚀 Exciting news! We're launching our revolutionary new product next week. Get ready to transform your business! #Innovation #BusinessGrowth",
    hashtags: ["Innovation", "BusinessGrowth", "ProductLaunch"],
    callToAction: "Learn More",
    images: [{
      url: "https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800&h=600&fit=crop",
      alt: "Product launch visual"
    }],
    branding: {
      companyName: "TechCorp",
      logoUrl: "https://images.unsplash.com/photo-1611224923853-80b023f02d71?w=100&h=100&fit=crop",
      colors: ["#3B82F6", "#1E40AF"]
    },
    metadata: {
      timestamp: new Date(),
      engagement: {
        likes: 245,
        shares: 32,
        comments: 18
      }
    }
  },
  
  'long-form': {
    headline: "Revolutionize Your Business Operations with AI-Powered Automation",
    text: "In today's competitive landscape, businesses need every advantage they can get. Our cutting-edge AI automation platform has helped over 10,000 companies streamline their operations, reduce costs by up to 40%, and increase productivity by 3x.\n\nDon't let manual processes hold your business back. Join the automation revolution and see immediate results in your workflow efficiency, customer satisfaction, and bottom line.\n\nOur comprehensive solution includes advanced analytics, seamless integrations, 24/7 support, and enterprise-grade security that keeps your data safe.",
    subtext: "Transform your business operations with intelligent automation solutions",
    callToAction: "Start Free Trial",
    images: [
      {
        url: "https://images.unsplash.com/photo-1551434678-e076c223a692?w=800&h=600&fit=crop",
        alt: "Business automation dashboard"
      },
      {
        url: "https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=800&h=600&fit=crop",
        alt: "Analytics and reporting"
      }
    ],
    branding: {
      companyName: "AutomateFlow",
      logoUrl: "https://images.unsplash.com/photo-1611224923853-80b023f02d71?w=100&h=100&fit=crop",
      colors: ["#059669", "#047857"]
    },
    metadata: {
      timestamp: new Date(),
      engagement: {
        likes: 1240,
        shares: 89,
        comments: 156
      }
    }
  },

  'promotional': {
    headline: "🔥 FLASH SALE - 50% OFF EVERYTHING!",
    text: "Limited time only! Get 50% off our entire collection. Premium quality, unbeatable prices. Sale ends in 48 hours!",
    callToAction: "Shop Now",
    images: [{
      url: "https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=800&h=600&fit=crop",
      alt: "Sale products"
    }],
    branding: {
      companyName: "StyleHub",
      colors: ["#DC2626", "#991B1B"]
    },
    hashtags: ["Sale", "Fashion", "LimitedTime"],
    metadata: {
      timestamp: new Date()
    }
  },

  'professional': {
    headline: "Industry-Leading Security Solutions for Enterprise",
    text: "Protect your organization with our comprehensive cybersecurity platform. Trusted by Fortune 500 companies worldwide for advanced threat detection, compliance management, and data protection.",
    callToAction: "Request Demo",
    images: [{
      url: "https://images.unsplash.com/photo-1563013544-824ae1b704d3?w=800&h=600&fit=crop",
      alt: "Cybersecurity dashboard"
    }],
    branding: {
      companyName: "SecureShield Corp",
      colors: ["#1E40AF", "#1E3A8A"]
    },
    metadata: {
      timestamp: new Date(),
      engagement: {
        likes: 89,
        shares: 45,
        comments: 23
      }
    }
  }
}

// Preview component mapping
const previewComponents = {
  // Social Media
  'facebook-post': FacebookPostPreview,
  'instagram-post': InstagramPostPreview,
  'instagram-story': InstagramStoryPreview,
  'twitter-post': TwitterPostPreview,
  
  // Email
  'email-newsletter': EmailNewsletterPreview,
  'email-promotional': EmailPromotionalPreview,
  
  // Ads
  'google-search-ad': GoogleSearchAdPreview,
  'facebook-ad': FacebookAdPreview,
  'display-banner-ad': DisplayBannerAdPreview,
  'shopping-ad': ShoppingAdPreview,
  'video-ad': VideoAdPreview,
  
  // Landing Pages
  'landing-page-hero': LandingPageHeroPreview,
  'landing-page-features': LandingPageFeaturesPreview,
  'landing-page-testimonials': LandingPageTestimonialsPreview,
  'landing-page-contact': LandingPageContactPreview
}

export function PreviewDemo() {
  const [selectedContent, setSelectedContent] = useState<string>('short-social')
  const [selectedConfig, setSelectedConfig] = useState<string>('facebook-post')

  const handleExport = (format: string) => {
    console.log(`Exporting ${selectedConfig} as ${format}`)
  }

  const PreviewComponent = previewComponents[selectedConfig as keyof typeof previewComponents]
  const content = sampleContent[selectedContent]
  const config = CHANNEL_CONFIGS[selectedConfig]

  // Group configs by category
  const configsByCategory = Object.entries(CHANNEL_CONFIGS).reduce((acc, [key, config]) => {
    const category = config.channel
    if (!acc[category]) acc[category] = []
    acc[category].push({ key, config })
    return acc
  }, {} as Record<string, Array<{ key: string, config: any }>>)

  return (
    <div className="space-y-8 p-6">
      <div className="text-center space-y-2">
        <h1 className="text-3xl font-bold">Channel Preview Components Demo</h1>
        <p className="text-lg text-muted-foreground">
          Test all preview components across different content types and marketing channels
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Content Selection */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Content Type</CardTitle>
            <CardDescription>
              Choose a sample content to preview
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Select value={selectedContent} onValueChange={setSelectedContent}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="short-social">Short Social Media Post</SelectItem>
                <SelectItem value="long-form">Long-form Content</SelectItem>
                <SelectItem value="promotional">Promotional Content</SelectItem>
                <SelectItem value="professional">Professional Content</SelectItem>
              </SelectContent>
            </Select>
            
            <div className="mt-4 p-3 bg-muted rounded-lg">
              <p className="text-sm font-medium mb-2">Content Preview:</p>
              <p className="text-xs text-muted-foreground">
                {content.text?.substring(0, 100)}...
              </p>
              {content.hashtags && content.hashtags.length > 0 && (
                <div className="flex flex-wrap gap-1 mt-2">
                  {content.hashtags.slice(0, 3).map((tag, index) => (
                    <Badge key={index} variant="secondary" className="text-xs">
                      #{tag}
                    </Badge>
                  ))}
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Channel Selection */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Preview Channel</CardTitle>
            <CardDescription>
              Select the marketing channel to preview
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Select value={selectedConfig} onValueChange={setSelectedConfig}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {Object.entries(configsByCategory).map(([category, configs]) => (
                  <div key={category}>
                    <div className="px-2 py-1 text-sm font-medium text-muted-foreground capitalize">
                      {category.replace('-', ' ')}
                    </div>
                    {configs.map(({ key, config }) => (
                      <SelectItem key={key} value={key}>
                        {config.name}
                      </SelectItem>
                    ))}
                    <Separator className="my-1" />
                  </div>
                ))}
              </SelectContent>
            </Select>

            {config && (
              <div className="mt-4 p-3 bg-muted rounded-lg">
                <p className="text-sm font-medium mb-2">Channel Info:</p>
                <div className="space-y-1 text-xs">
                  <p><span className="font-medium">Format:</span> {config.format}</p>
                  <p><span className="font-medium">Dimensions:</span> {config.dimensions.width}×{config.dimensions.height}</p>
                  <p><span className="font-medium">Device Frame:</span> {config.deviceFrame || 'none'}</p>
                  {config.limits.maxTextLength && (
                    <p><span className="font-medium">Text Limit:</span> {config.limits.maxTextLength} chars</p>
                  )}
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Statistics */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Demo Statistics</CardTitle>
            <CardDescription>
              Overview of available components
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              <div className="flex justify-between">
                <span className="text-sm">Total Channels:</span>
                <Badge variant="secondary">
                  {Object.keys(CHANNEL_CONFIGS).length}
                </Badge>
              </div>
              <div className="flex justify-between">
                <span className="text-sm">Preview Components:</span>
                <Badge variant="secondary">
                  {Object.keys(previewComponents).length}
                </Badge>
              </div>
              <div className="flex justify-between">
                <span className="text-sm">Content Types:</span>
                <Badge variant="secondary">
                  {Object.keys(sampleContent).length}
                </Badge>
              </div>
              <Separator />
              <div className="space-y-2">
                <p className="text-sm font-medium">Supported Features:</p>
                <div className="flex flex-wrap gap-1">
                  <Badge variant="outline" className="text-xs">Validation</Badge>
                  <Badge variant="outline" className="text-xs">Export</Badge>
                  <Badge variant="outline" className="text-xs">Responsive</Badge>
                  <Badge variant="outline" className="text-xs">Device Frames</Badge>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Preview Section */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Preview: {config?.name}</CardTitle>
              <CardDescription>
                {config?.description}
              </CardDescription>
            </div>
            <div className="flex gap-2">
              <Button 
                variant="outline" 
                size="sm"
                onClick={() => handleExport('json')}
              >
                Export JSON
              </Button>
              <Button 
                variant="outline" 
                size="sm"
                onClick={() => handleExport('html')}
              >
                Export HTML
              </Button>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          {PreviewComponent && content ? (
            <PreviewComponent
              content={content}
              configId={selectedConfig}
              showValidation={true}
              showExport={true}
              onExport={handleExport}
            />
          ) : (
            <div className="text-center py-12 text-muted-foreground">
              <p>Select a content type and channel to see the preview</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Channel Overview */}
      <Card>
        <CardHeader>
          <CardTitle>All Available Channels</CardTitle>
          <CardDescription>
            Complete overview of supported marketing channels and formats
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Tabs defaultValue="social" className="w-full">
            <TabsList className="grid grid-cols-4 w-full">
              <TabsTrigger value="social">Social Media</TabsTrigger>
              <TabsTrigger value="email">Email</TabsTrigger>
              <TabsTrigger value="ads">Advertising</TabsTrigger>
              <TabsTrigger value="web">Web Content</TabsTrigger>
            </TabsList>
            
            <TabsContent value="social" className="mt-6">
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {Object.entries(CHANNEL_CONFIGS)
                  .filter(([_, config]) => ['facebook', 'instagram', 'twitter', 'linkedin'].includes(config.channel))
                  .map(([key, config]) => (
                    <Card key={key} className="cursor-pointer hover:shadow-md transition-shadow"
                          onClick={() => setSelectedConfig(key)}>
                      <CardContent className="p-4">
                        <h4 className="font-medium mb-2">{config.name}</h4>
                        <p className="text-sm text-muted-foreground mb-2">{config.description}</p>
                        <div className="flex justify-between text-xs">
                          <span>{config.dimensions.aspectRatio}</span>
                          <Badge variant="outline" className="text-xs">
                            {config.channel}
                          </Badge>
                        </div>
                      </CardContent>
                    </Card>
                  ))}
              </div>
            </TabsContent>
            
            <TabsContent value="email" className="mt-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {Object.entries(CHANNEL_CONFIGS)
                  .filter(([_, config]) => config.channel === 'email')
                  .map(([key, config]) => (
                    <Card key={key} className="cursor-pointer hover:shadow-md transition-shadow"
                          onClick={() => setSelectedConfig(key)}>
                      <CardContent className="p-4">
                        <h4 className="font-medium mb-2">{config.name}</h4>
                        <p className="text-sm text-muted-foreground mb-2">{config.description}</p>
                        <div className="flex justify-between text-xs">
                          <span>{config.dimensions.aspectRatio}</span>
                          <Badge variant="outline" className="text-xs">
                            {config.format}
                          </Badge>
                        </div>
                      </CardContent>
                    </Card>
                  ))}
              </div>
            </TabsContent>
            
            <TabsContent value="ads" className="mt-6">
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {Object.entries(CHANNEL_CONFIGS)
                  .filter(([_, config]) => config.channel.includes('ads') || config.channel.includes('ad'))
                  .map(([key, config]) => (
                    <Card key={key} className="cursor-pointer hover:shadow-md transition-shadow"
                          onClick={() => setSelectedConfig(key)}>
                      <CardContent className="p-4">
                        <h4 className="font-medium mb-2">{config.name}</h4>
                        <p className="text-sm text-muted-foreground mb-2">{config.description}</p>
                        <div className="flex justify-between text-xs">
                          <span>{config.dimensions.aspectRatio}</span>
                          <Badge variant="outline" className="text-xs">
                            {config.channel}
                          </Badge>
                        </div>
                      </CardContent>
                    </Card>
                  ))}
              </div>
            </TabsContent>
            
            <TabsContent value="web" className="mt-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {Object.entries(CHANNEL_CONFIGS)
                  .filter(([_, config]) => ['landing-page', 'blog'].includes(config.channel))
                  .map(([key, config]) => (
                    <Card key={key} className="cursor-pointer hover:shadow-md transition-shadow"
                          onClick={() => setSelectedConfig(key)}>
                      <CardContent className="p-4">
                        <h4 className="font-medium mb-2">{config.name}</h4>
                        <p className="text-sm text-muted-foreground mb-2">{config.description}</p>
                        <div className="flex justify-between text-xs">
                          <span>{config.dimensions.aspectRatio}</span>
                          <Badge variant="outline" className="text-xs">
                            {config.channel}
                          </Badge>
                        </div>
                      </CardContent>
                    </Card>
                  ))}
              </div>
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>
    </div>
  )
}