'use client'

import { SidebarInset, SidebarProvider, SidebarTrigger } from '@/components/ui/sidebar'

import type { BaseComponentProps } from '@/lib/types'

interface DashboardLayoutProps extends BaseComponentProps {
  sidebar?: React.ReactNode
  header?: React.ReactNode
  breadcrumb?: React.ReactNode
  defaultSidebarOpen?: boolean
  cookieKey?: string
}

/**
 * Layout component for dashboard pages with sidebar and header
 * Enhanced with responsive behavior, SidebarProvider integration, and user preference persistence
 */
export function DashboardLayout({ 
  children, 
  className, 
  sidebar, 
  header, 
  breadcrumb,
  defaultSidebarOpen = true,
  cookieKey = "dashboard-sidebar"
}: DashboardLayoutProps) {
  return (
    <SidebarProvider 
      defaultOpen={defaultSidebarOpen}
    >
      <div className={`min-h-screen bg-background ${className || ''}`}>
        {/* Sidebar */}
        {sidebar}
        
        <SidebarInset>
          {/* Header with mobile trigger and breadcrumb */}
          {(header || breadcrumb) && (
            <header className="flex h-16 shrink-0 items-center gap-2 border-b bg-background px-4">
              <SidebarTrigger className="-ml-1" />
              <div className="h-4 w-px bg-border" />
              {breadcrumb}
              <div className="ml-auto">
                {header}
              </div>
            </header>
          )}

          {/* Main Content */}
          <main className="flex flex-1 flex-col gap-4 p-4 pt-0">
            <div className="flex-1">
              {children}
            </div>
          </main>
        </SidebarInset>
      </div>
    </SidebarProvider>
  )
}
