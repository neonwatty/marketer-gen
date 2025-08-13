import { CampaignComparison } from "@/components/campaigns/campaign-comparison"

export default function CampaignComparePage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Campaign Comparison</h1>
          <p className="text-muted-foreground text-lg">
            Analyze and compare campaign performance with statistical insights
          </p>
        </div>
      </div>
      
      <CampaignComparison />
    </div>
  )
}