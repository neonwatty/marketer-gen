import { DashboardHeader } from '@/components/features/dashboard/DashboardHeader'
import { DashboardSidebar } from '@/components/features/dashboard/DashboardSidebar'
import { SidebarInset, SidebarProvider, SidebarTrigger } from '@/components/ui/sidebar'

interface DashboardLayoutProps {
  children: React.ReactNode
}

/**
 * Layout for all dashboard pages with sidebar navigation and header
 * Responsive mobile design with collapsible sidebar
 */
export default function DashboardLayout({ children }: DashboardLayoutProps) {
  return (
    <SidebarProvider defaultOpen={true}>
      <div className="min-h-screen bg-background">
        <DashboardSidebar />
        
        <SidebarInset>
          {/* Header with mobile trigger */}
          <header className="flex h-16 shrink-0 items-center gap-2 border-b bg-background px-4">
            <SidebarTrigger className="-ml-1" />
            <div className="h-4 w-px bg-border" />
            <div className="ml-auto">
              <DashboardHeader />
            </div>
          </header>

          {/* Main Content */}
          <main className="flex-1 p-4 md:p-6 lg:p-8 bg-muted/10">
            {children}
          </main>
        </SidebarInset>
      </div>
    </SidebarProvider>
  )
}