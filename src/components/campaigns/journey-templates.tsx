"use client"

import * as React from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import {
  Users,
  Target,
  RefreshCw,
  Megaphone,
  Eye,
  Play,
  Clock,
  ArrowRight,
  Zap,
  Heart,
  TrendingUp,
  Mail,
  Share2,
  FileText,
  ShoppingCart,
} from "lucide-react"
import { cn } from "@/lib/utils"
import { JourneyStage, JourneyTemplate } from "./journey-builder"

// Predefined journey templates
export const JOURNEY_TEMPLATES: JourneyTemplate[] = [
  {
    id: "product-launch",
    name: "Product Launch",
    description: "Complete customer journey for launching a new product from awareness to conversion",
    category: "product-launch",
    stages: [
      {
        name: "Pre-Launch Awareness",
        description: "Build anticipation and awareness before product release",
        type: "awareness",
        channels: ["Social Media", "Blog", "Email", "PR"],
        contentTypes: ["Teasers", "Behind the Scenes", "Coming Soon", "Features Preview"],
        isConfigured: true,
      },
      {
        name: "Launch Consideration",
        description: "Drive interest and consideration during the launch phase",
        type: "consideration",
        channels: ["Landing Pages", "Webinars", "Email", "Social Media"],
        contentTypes: ["Product Demos", "Feature Details", "Use Cases", "Expert Reviews"],
        isConfigured: true,
      },
      {
        name: "Purchase Conversion",
        description: "Convert interested prospects into customers",
        type: "conversion",
        channels: ["Email", "Retargeting", "Sales Pages", "Limited Offers"],
        contentTypes: ["Special Offers", "Testimonials", "Limited Time Deals", "Product Benefits"],
        isConfigured: true,
      },
      {
        name: "Post-Purchase Retention",
        description: "Onboard new customers and drive repeat purchases",
        type: "retention",
        channels: ["Email", "Support", "App Notifications", "Community"],
        contentTypes: ["Onboarding", "Tips & Tricks", "Updates", "Loyalty Programs"],
        isConfigured: true,
      },
    ],
  },
  {
    id: "lead-generation",
    name: "Lead Generation",
    description: "Attract and nurture potential customers through the sales funnel",
    category: "lead-generation",
    stages: [
      {
        name: "Content Awareness",
        description: "Attract potential leads with valuable content",
        type: "awareness",
        channels: ["Blog", "SEO", "Social Media", "Guest Posts"],
        contentTypes: ["Educational Content", "How-to Guides", "Industry Reports", "Infographics"],
        isConfigured: true,
      },
      {
        name: "Lead Magnet Consideration",
        description: "Capture leads with compelling offers",
        type: "consideration",
        channels: ["Landing Pages", "Email", "Webinars", "Whitepapers"],
        contentTypes: ["Lead Magnets", "Free Tools", "Webinars", "Case Studies"],
        isConfigured: true,
      },
      {
        name: "Nurture Conversion",
        description: "Convert leads into qualified opportunities",
        type: "conversion",
        channels: ["Email Sequences", "Sales Calls", "Demos", "Proposals"],
        contentTypes: ["Email Series", "Product Demos", "Proposals", "ROI Calculators"],
        isConfigured: true,
      },
    ],
  },
  {
    id: "re-engagement",
    name: "Customer Re-engagement",
    description: "Win back inactive customers and drive repeat purchases",
    category: "re-engagement",
    stages: [
      {
        name: "Win-Back Awareness",
        description: "Re-connect with inactive customers",
        type: "awareness",
        channels: ["Email", "Retargeting", "Social Media", "Direct Mail"],
        contentTypes: ["We Miss You", "What's New", "Special Comeback Offers", "Success Stories"],
        isConfigured: true,
      },
      {
        name: "Incentive Consideration",
        description: "Provide compelling reasons to return",
        type: "consideration",
        channels: ["Email", "Landing Pages", "SMS", "Push Notifications"],
        contentTypes: ["Exclusive Discounts", "New Features", "Loyalty Benefits", "Personalized Offers"],
        isConfigured: true,
      },
      {
        name: "Re-activation Conversion",
        description: "Convert inactive users back to active customers",
        type: "conversion",
        channels: ["Email", "Limited Time Offers", "Personal Outreach", "Retargeting"],
        contentTypes: ["Time-Limited Offers", "Personal Messages", "Easy Return Process", "Success Guarantees"],
        isConfigured: true,
      },
      {
        name: "Loyalty Retention",
        description: "Maintain engagement to prevent future churn",
        type: "retention",
        channels: ["Email", "Loyalty Programs", "Community", "Support"],
        contentTypes: ["Regular Updates", "VIP Treatment", "Community Access", "Priority Support"],
        isConfigured: true,
      },
    ],
  },
  {
    id: "brand-awareness",
    name: "Brand Awareness",
    description: "Build brand recognition and establish thought leadership",
    category: "brand-awareness",
    stages: [
      {
        name: "Content Marketing Awareness",
        description: "Establish thought leadership through valuable content",
        type: "awareness",
        channels: ["Blog", "Social Media", "PR", "Podcasts"],
        contentTypes: ["Thought Leadership", "Industry Insights", "Educational Content", "Brand Stories"],
        isConfigured: true,
      },
      {
        name: "Engagement Consideration",
        description: "Drive deeper engagement with your brand",
        type: "consideration",
        channels: ["Social Media", "Events", "Webinars", "Community"],
        contentTypes: ["Interactive Content", "Live Events", "Community Discussions", "Expert Interviews"],
        isConfigured: true,
      },
      {
        name: "Community Conversion",
        description: "Convert awareness into brand advocacy",
        type: "conversion",
        channels: ["Community", "Email", "Events", "Referrals"],
        contentTypes: ["Community Membership", "Brand Ambassador", "Exclusive Access", "Referral Programs"],
        isConfigured: true,
      },
    ],
  },
]

interface JourneyTemplatesProps {
  onSelectTemplate?: (template: JourneyTemplate) => void
  className?: string
}

interface TemplatePreviewProps {
  template: JourneyTemplate
  onSelect?: (template: JourneyTemplate) => void
}

// Template category icons
const getCategoryIcon = (category: JourneyTemplate["category"]) => {
  switch (category) {
    case "product-launch":
      return <Zap className="h-5 w-5" />
    case "lead-generation":
      return <Target className="h-5 w-5" />
    case "re-engagement":
      return <RefreshCw className="h-5 w-5" />
    case "brand-awareness":
      return <Megaphone className="h-5 w-5" />
    default:
      return <Users className="h-5 w-5" />
  }
}

const getCategoryColor = (category: JourneyTemplate["category"]) => {
  switch (category) {
    case "product-launch":
      return "text-yellow-700 bg-yellow-50 border-yellow-200"
    case "lead-generation":
      return "text-blue-700 bg-blue-50 border-blue-200"
    case "re-engagement":
      return "text-green-700 bg-green-50 border-green-200"
    case "brand-awareness":
      return "text-purple-700 bg-purple-50 border-purple-200"
    default:
      return "text-gray-700 bg-gray-50 border-gray-200"
  }
}

const getStageIcon = (type: string) => {
  switch (type) {
    case "awareness":
      return <Users className="h-4 w-4" />
    case "consideration":
      return <FileText className="h-4 w-4" />
    case "conversion":
      return <ShoppingCart className="h-4 w-4" />
    case "retention":
      return <Heart className="h-4 w-4" />
    default:
      return <Users className="h-4 w-4" />
  }
}

function TemplatePreview({ template, onSelect }: TemplatePreviewProps) {
  return (
    <Dialog>
      <DialogTrigger asChild>
        <Card className="cursor-pointer hover:shadow-md transition-all hover:border-primary">
          <CardHeader className="pb-3">
            <div className="flex items-start justify-between">
              <div className="flex items-center gap-2">
                <div className={cn(
                  "p-2 rounded-lg border",
                  getCategoryColor(template.category)
                )}>
                  {getCategoryIcon(template.category)}
                </div>
                <div>
                  <CardTitle className="text-lg">{template.name}</CardTitle>
                  <Badge variant="outline" className={cn("mt-1 text-xs", getCategoryColor(template.category))}>
                    {template.category.replace("-", " ").replace(/\b\w/g, l => l.toUpperCase())}
                  </Badge>
                </div>
              </div>
              <Button size="sm" variant="ghost">
                <Eye className="h-4 w-4" />
              </Button>
            </div>
          </CardHeader>
          <CardContent className="pt-0">
            <CardDescription className="mb-4">
              {template.description}
            </CardDescription>
            
            <div className="space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span className="text-muted-foreground">Stages:</span>
                <span className="font-medium">{template.stages.length}</span>
              </div>
              
              <div className="flex items-center gap-1 flex-wrap">
                {template.stages.map((stage, index) => (
                  <div key={index} className="flex items-center">
                    <div className={cn(
                      "flex items-center gap-1 px-2 py-1 rounded text-xs",
                      stage.type === "awareness" && "bg-blue-100 text-blue-700",
                      stage.type === "consideration" && "bg-green-100 text-green-700",
                      stage.type === "conversion" && "bg-orange-100 text-orange-700",
                      stage.type === "retention" && "bg-purple-100 text-purple-700"
                    )}>
                      {getStageIcon(stage.type)}
                      <span>{stage.type}</span>
                    </div>
                    {index < template.stages.length - 1 && (
                      <ArrowRight className="h-3 w-3 text-gray-400 mx-1" />
                    )}
                  </div>
                ))}
              </div>
            </div>
          </CardContent>
        </Card>
      </DialogTrigger>
      
      <DialogContent className="max-w-3xl max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <div className="flex items-center gap-3">
            <div className={cn(
              "p-2 rounded-lg border",
              getCategoryColor(template.category)
            )}>
              {getCategoryIcon(template.category)}
            </div>
            <div>
              <DialogTitle className="text-xl">{template.name}</DialogTitle>
              <DialogDescription className="mt-1">
                {template.description}
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>
        
        <div className="mt-6 space-y-4">
          <h3 className="text-lg font-semibold">Journey Stages</h3>
          
          {template.stages.map((stage, index) => (
            <div key={index}>
              <Card>
                <CardContent className="p-4">
                  <div className="flex items-start gap-3">
                    <div className={cn(
                      "p-2 rounded-lg border flex-shrink-0",
                      stage.type === "awareness" && "bg-blue-50 border-blue-200 text-blue-700",
                      stage.type === "consideration" && "bg-green-50 border-green-200 text-green-700",
                      stage.type === "conversion" && "bg-orange-50 border-orange-200 text-orange-700",
                      stage.type === "retention" && "bg-purple-50 border-purple-200 text-purple-700"
                    )}>
                      {getStageIcon(stage.type)}
                    </div>
                    
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-2">
                        <h4 className="font-semibold">{stage.name}</h4>
                        <Badge variant="outline" className={cn(
                          "text-xs",
                          stage.type === "awareness" && "bg-blue-50 border-blue-200 text-blue-700",
                          stage.type === "consideration" && "bg-green-50 border-green-200 text-green-700",
                          stage.type === "conversion" && "bg-orange-50 border-orange-200 text-orange-700",
                          stage.type === "retention" && "bg-purple-50 border-purple-200 text-purple-700"
                        )}>
                          {stage.type}
                        </Badge>
                      </div>
                      
                      <p className="text-sm text-muted-foreground mb-3">
                        {stage.description}
                      </p>
                      
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                        <div>
                          <div className="font-medium mb-1">Channels:</div>
                          <div className="flex flex-wrap gap-1">
                            {stage.channels.map((channel) => (
                              <Badge key={channel} variant="secondary" className="text-xs">
                                {channel}
                              </Badge>
                            ))}
                          </div>
                        </div>
                        
                        <div>
                          <div className="font-medium mb-1">Content Types:</div>
                          <div className="flex flex-wrap gap-1">
                            {stage.contentTypes.map((type) => (
                              <Badge key={type} variant="outline" className="text-xs">
                                {type}
                              </Badge>
                            ))}
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>
              
              {index < template.stages.length - 1 && (
                <div className="flex justify-center my-2">
                  <ArrowRight className="h-5 w-5 text-muted-foreground" />
                </div>
              )}
            </div>
          ))}
        </div>
        
        <div className="flex justify-end gap-2 mt-6 pt-4 border-t">
          <Button variant="outline">
            Customize Template
          </Button>
          <Button onClick={() => onSelect?.(template)}>
            <Play className="h-4 w-4 mr-2" />
            Use This Template
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}

export function JourneyTemplates({ onSelectTemplate, className }: JourneyTemplatesProps) {
  const [selectedCategory, setSelectedCategory] = React.useState<string | null>(null)

  const filteredTemplates = selectedCategory
    ? JOURNEY_TEMPLATES.filter(template => template.category === selectedCategory)
    : JOURNEY_TEMPLATES

  const categories = Array.from(new Set(JOURNEY_TEMPLATES.map(t => t.category)))

  return (
    <div className={cn("space-y-6", className)}>
      {/* Header */}
      <div>
        <h2 className="text-2xl font-bold mb-2">Journey Templates</h2>
        <p className="text-muted-foreground">
          Start with proven customer journey templates and customize them for your needs
        </p>
      </div>

      {/* Category Filter */}
      <div className="flex flex-wrap gap-2">
        <Button
          variant={selectedCategory === null ? "default" : "outline"}
          size="sm"
          onClick={() => setSelectedCategory(null)}
        >
          All Templates
        </Button>
        {categories.map((category) => (
          <Button
            key={category}
            variant={selectedCategory === category ? "default" : "outline"}
            size="sm"
            onClick={() => setSelectedCategory(category)}
            className="gap-2"
          >
            {getCategoryIcon(category)}
            {category.replace("-", " ").replace(/\b\w/g, l => l.toUpperCase())}
          </Button>
        ))}
      </div>

      {/* Templates Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredTemplates.map((template) => (
          <TemplatePreview
            key={template.id}
            template={template}
            onSelect={onSelectTemplate}
          />
        ))}
      </div>

      {/* Quick Stats */}
      <Card className="bg-gradient-to-r from-slate-50 to-gray-50">
        <CardContent className="p-6">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-center">
            <div>
              <div className="text-2xl font-bold text-blue-600">{JOURNEY_TEMPLATES.length}</div>
              <div className="text-sm text-muted-foreground">Templates Available</div>
            </div>
            <div>
              <div className="text-2xl font-bold text-green-600">
                {JOURNEY_TEMPLATES.reduce((acc, t) => acc + t.stages.length, 0)}
              </div>
              <div className="text-sm text-muted-foreground">Total Stages</div>
            </div>
            <div>
              <div className="text-2xl font-bold text-orange-600">{categories.length}</div>
              <div className="text-sm text-muted-foreground">Categories</div>
            </div>
            <div>
              <div className="text-2xl font-bold text-purple-600">
                {Math.round(JOURNEY_TEMPLATES.reduce((acc, t) => acc + t.stages.length, 0) / JOURNEY_TEMPLATES.length)}
              </div>
              <div className="text-sm text-muted-foreground">Avg Stages</div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}