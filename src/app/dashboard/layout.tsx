import { ProtectedRoute } from '@/components/features/auth/ProtectedRoute'
import { DashboardHeader } from '@/components/features/dashboard/DashboardHeader'
import { DashboardSidebar } from '@/components/features/dashboard/DashboardSidebar'
import { SidebarProvider } from '@/components/ui/sidebar'

interface DashboardLayoutProps {
  children: React.ReactNode
}

/**
 * Layout for all dashboard pages with sidebar navigation and header
 * Includes route protection structure (currently disabled for MVP development)
 */
export default function DashboardLayout({ children }: DashboardLayoutProps) {
  return (
    <ProtectedRoute requireAuth={false}>
      <SidebarProvider>
        <div className="min-h-screen flex w-full">
          <DashboardSidebar />
          <div className="flex-1 flex flex-col">
            <DashboardHeader />
            <main className="flex-1 p-4 md:p-6 lg:p-8 bg-muted/10">
              {children}
            </main>
          </div>
        </div>
      </SidebarProvider>
    </ProtectedRoute>
  )
}