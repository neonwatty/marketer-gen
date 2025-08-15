import type { BaseComponentProps } from '@/lib/types'

interface MainLayoutProps extends BaseComponentProps {
  title?: string
  description?: string
}

/**
 * Main layout component wrapping the entire application
 * Note: For setting page title and meta, use Next.js Metadata API in app router
 */
export function MainLayout({ children, className }: MainLayoutProps) {
  return (
    <div className={`min-h-screen bg-background text-foreground ${className || ''}`}>
      <main className="container mx-auto px-4 py-8">{children}</main>
    </div>
  )
}
