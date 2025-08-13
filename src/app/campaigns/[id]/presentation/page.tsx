import { StakeholderPresentation } from "@/components/campaigns/stakeholder-presentation"

// Mock campaign data - in a real app, this would come from an API
const mockCampaign = {
  id: "1",
  title: "Summer Product Launch",
  description: "Multi-channel campaign for new product line launch targeting millennials with focus on sustainability and lifestyle integration",
  status: "active" as const,
  createdAt: "2024-01-15",
  startDate: "2024-02-01",
  endDate: "2024-04-30",
  budget: {
    total: 25000,
    spent: 18750,
    currency: "USD"
  },
  objectives: ["brand-awareness", "lead-generation", "sales-conversion"],
  channels: ["Email", "Social Media", "Blog", "Display Ads"],
  targetAudience: {
    demographics: {
      ageRange: "25-34",
      gender: "all",
      location: "United States, Canada"
    },
    description: "Environmentally conscious millennials interested in sustainable living, outdoor activities, and premium lifestyle products"
  },
  contentStrategy: {
    contentTypes: ["blog-post", "social-post", "email-newsletter", "landing-page"],
    frequency: "weekly",
    tone: "friendly"
  },
  messaging: {
    primaryMessage: "Discover sustainable living with our eco-friendly product line designed for the modern lifestyle",
    callToAction: "Shop Sustainable",
    valueProposition: "Premium quality meets environmental responsibility"
  },
  metrics: {
    progress: 75,
    contentPieces: 12,
    impressions: 125000,
    engagement: 4.2,
    conversions: 850,
    clickThroughRate: 3.1,
    costPerConversion: 22.06
  },
  journey: {
    stages: [
      {
        id: "awareness",
        name: "Awareness", 
        description: "Brand introduction and problem recognition",
        status: "completed",
        channels: ["Blog", "Social Media", "Display Ads"],
        contentCount: 8,
        metrics: { impressions: 75000, engagement: 3.8 }
      },
      {
        id: "consideration",
        name: "Consideration",
        description: "Product evaluation and comparison", 
        status: "active",
        channels: ["Email", "Social Media", "Blog"],
        contentCount: 6,
        metrics: { impressions: 40000, engagement: 5.2 }
      },
      {
        id: "conversion",
        name: "Conversion",
        description: "Purchase decision and action",
        status: "active", 
        channels: ["Email", "Landing Pages"],
        contentCount: 4,
        metrics: { impressions: 10000, engagement: 6.8 }
      },
      {
        id: "retention",
        name: "Retention",
        description: "Post-purchase engagement and loyalty",
        status: "pending",
        channels: ["Email", "Social Media"],
        contentCount: 0,
        metrics: { impressions: 0, engagement: 0 }
      }
    ]
  }
}

interface CampaignPresentationPageProps {
  params: { id: string }
}

export default function CampaignPresentationPage({ params }: CampaignPresentationPageProps) {
  const campaign = mockCampaign // In real app, fetch by params.id

  return (
    <div className="min-h-screen bg-gray-50">
      <StakeholderPresentation campaign={campaign} />
    </div>
  )
}