"use client"

import { use } from "react"
import { useRouter } from "next/navigation"
import { CampaignCloning } from "@/components/campaigns/campaign-cloning"

interface Campaign {
  id: string
  title: string
  description: string
  status: string
  startDate: string
  endDate: string
  budget: {
    total: number
    spent: number
    currency: string
  }
  objectives: string[]
  channels: string[]
  targetAudience: {
    demographics: {
      ageRange: string
      gender: string
      location: string
    }
    description: string
    interests: string[]
  }
  messaging: {
    primaryMessage: string
    callToAction: string
    valueProposition: string
  }
  contentStrategy: {
    contentTypes: string[]
    frequency: string
    tone: string
  }
  metrics: {
    impressions: number
    engagement: number
    conversions: number
    clickThroughRate: number
    conversionRate: number
    costPerConversion: number
  }
}

interface CloneOptions {
  name: string
  description: string
  selectedElements: string[]
  adjustments: {
    budget?: number
    startDate?: string
    endDate?: string
    channels?: string[]
  }
  saveAsTemplate: boolean
  templateName?: string
  templateDescription?: string
  templateCategory?: string
}

// Mock campaign data - in a real app, this would come from an API
const mockCampaign: Campaign = {
  id: "1",
  title: "Summer Product Launch",
  description: "Multi-channel campaign for new product line launch targeting sustainability-conscious consumers",
  status: "active",
  startDate: "2024-02-01",
  endDate: "2024-04-30",
  budget: { total: 25000, spent: 18750, currency: "USD" },
  objectives: [
    "Increase brand awareness by 40%",
    "Generate 1000+ qualified leads",
    "Achieve 3.5x ROAS",
    "Build email list to 5000 subscribers"
  ],
  channels: ["Email", "Social Media", "Blog", "Display Ads"],
  targetAudience: {
    demographics: {
      ageRange: "25-34",
      gender: "All",
      location: "United States, Canada"
    },
    description: "Environmentally conscious professionals with disposable income",
    interests: ["sustainability", "lifestyle", "premium products", "eco-friendly"]
  },
  messaging: {
    primaryMessage: "Transform your lifestyle with sustainable premium products",
    callToAction: "Shop the Collection",
    valueProposition: "Premium quality meets environmental responsibility"
  },
  contentStrategy: {
    contentTypes: ["Blog Posts", "Social Posts", "Email Sequences", "Video Content"],
    frequency: "Daily social posts, 2x weekly emails, weekly blog posts",
    tone: "Professional yet approachable, inspiring, educational"
  },
  metrics: {
    impressions: 125000,
    engagement: 4.2,
    conversions: 850,
    clickThroughRate: 3.1,
    conversionRate: 21.9,
    costPerConversion: 22.06
  }
}

interface CampaignClonePageProps {
  params: Promise<{ id: string }>
}

export default function CampaignClonePage({ params }: CampaignClonePageProps) {
  const resolvedParams = use(params)
  const router = useRouter()
  
  // In a real app, you would fetch the campaign data based on the ID
  const campaign = mockCampaign
  
  const handleClone = async (options: CloneOptions) => {
    try {
      // TODO: Implement actual cloning logic
      console.log("Cloning campaign with options:", options)
      
      // Create the new campaign
      const newCampaign = {
        ...campaign,
        id: `${campaign.id}-clone-${Date.now()}`,
        title: options.name,
        description: options.description,
        status: "draft",
        ...options.adjustments
      }
      
      // If saving as template, also create the template
      if (options.saveAsTemplate) {
        const template = {
          id: `template-${Date.now()}`,
          name: options.templateName,
          description: options.templateDescription,
          category: options.templateCategory,
          elements: options.selectedElements,
          sourceConfiguration: newCampaign
        }
        console.log("Creating template:", template)
      }
      
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1000))
      
      // Navigate to the new campaign
      router.push(`/campaigns/${newCampaign.id}?cloned=true`)
      
    } catch (error) {
      console.error("Failed to clone campaign:", error)
      // TODO: Show error toast/notification
    }
  }
  
  const handleCancel = () => {
    router.back()
  }
  
  if (!campaign) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-4">Campaign Not Found</h1>
          <p className="text-gray-600 mb-6">
            The campaign you're trying to clone could not be found.
          </p>
          <button
            onClick={() => router.push('/campaigns')}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
          >
            Back to Campaigns
          </button>
        </div>
      </div>
    )
  }
  
  return (
    <div className="container mx-auto px-4 py-8">
      <CampaignCloning
        campaign={campaign}
        onClone={handleClone}
        onCancel={handleCancel}
      />
    </div>
  )
}