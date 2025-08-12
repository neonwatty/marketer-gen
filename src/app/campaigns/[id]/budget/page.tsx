import { BudgetAllocationDashboard } from "@/components/campaigns/budget-allocation-dashboard"

// Mock campaign budget data - in a real app, this would come from an API
const mockCampaignBudget = {
  id: "1",
  totalBudget: 25000,
  currency: "USD",
  startDate: "2024-02-01",
  endDate: "2024-04-30",
  allocations: [
    {
      id: 'content',
      name: 'Content Creation',
      allocated: 8000,
      percentage: 32,
      spent: 5200,
      remaining: 2800,
      category: 'content' as const,
      channels: ['Blog', 'Social Media', 'Email'],
      color: 'bg-blue-500'
    },
    {
      id: 'advertising',
      name: 'Paid Advertising',
      allocated: 12000,
      percentage: 48,
      spent: 8500,
      remaining: 3500,
      category: 'advertising' as const,
      channels: ['Google Ads', 'Facebook Ads', 'Display Ads'],
      color: 'bg-green-500'
    },
    {
      id: 'tools',
      name: 'Marketing Tools',
      allocated: 2000,
      percentage: 8,
      spent: 1800,
      remaining: 200,
      category: 'tools' as const,
      channels: ['All'],
      color: 'bg-purple-500'
    },
    {
      id: 'personnel',
      name: 'Personnel Costs',
      allocated: 2500,
      percentage: 10,
      spent: 1250,
      remaining: 1250,
      category: 'personnel' as const,
      channels: ['All'],
      color: 'bg-orange-500'
    },
    {
      id: 'other',
      name: 'Other Expenses',
      allocated: 500,
      percentage: 2,
      spent: 150,
      remaining: 350,
      category: 'other' as const,
      channels: ['All'],
      color: 'bg-gray-500'
    }
  ]
}

interface BudgetPageProps {
  params: { id: string }
}

export default function BudgetPage({ params }: BudgetPageProps) {
  const campaignBudget = mockCampaignBudget // In real app, fetch by params.id

  const handleSaveAllocations = (allocations: any[]) => {
    console.log("Saving budget allocations:", allocations)
    // In a real app, save to API
  }

  const handleOptimizeAllocations = (optimizations: any[]) => {
    console.log("Applying budget optimizations:", optimizations)
    // In a real app, apply optimizations
  }

  return (
    <div className="container mx-auto py-6">
      <BudgetAllocationDashboard
        campaignId={params.id}
        totalBudget={campaignBudget.totalBudget}
        currentAllocations={campaignBudget.allocations}
        onSaveAllocations={handleSaveAllocations}
        onOptimizeAllocations={handleOptimizeAllocations}
      />
    </div>
  )
}