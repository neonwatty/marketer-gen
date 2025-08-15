import type { BaseComponentProps } from '@/lib/types'

interface DashboardLayoutProps extends BaseComponentProps {
  sidebar?: React.ReactNode
  header?: React.ReactNode
}

/**
 * Layout component for dashboard pages with sidebar and header
 */
export function DashboardLayout({ children, className, sidebar, header }: DashboardLayoutProps) {
  return (
    <div className={`min-h-screen bg-background ${className || ''}`}>
      {/* Header */}
      {header && (
        <header className="border-b border-border bg-card">
          <div className="px-4 sm:px-6 lg:px-8">{header}</div>
        </header>
      )}

      <div className="flex">
        {/* Sidebar */}
        {sidebar && (
          <aside className="w-64 bg-card border-r border-border">
            <div className="h-full px-3 py-4">{sidebar}</div>
          </aside>
        )}

        {/* Main Content */}
        <main className="flex-1 p-4 sm:p-6 lg:p-8">{children}</main>
      </div>
    </div>
  )
}
