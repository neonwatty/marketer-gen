import { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Dashboard | Marketer Gen',
  description: 'Marketing campaign dashboard overview',
}

/**
 * Main dashboard page with overview of all campaigns and key metrics
 */
export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Dashboard</h1>
          <p className="text-muted-foreground">
            Overview of your marketing campaigns and performance metrics
          </p>
        </div>

        {/* Placeholder for dashboard content - will be implemented in subsequent tasks */}
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          <div className="col-span-full">
            <div className="rounded-lg border bg-card text-card-foreground shadow-sm p-6">
              <div className="flex items-center space-x-2">
                <div className="h-2 w-2 bg-blue-500 rounded-full animate-pulse" />
                <p className="text-sm text-muted-foreground">
                  Dashboard components will be added in the next tasks
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}