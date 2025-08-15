import Link from 'next/link'

import type { BaseComponentProps } from '@/lib/types'

interface PublicLayoutProps extends BaseComponentProps {
  showHeader?: boolean
  showFooter?: boolean
}

/**
 * Layout component for public pages (landing, about, etc.)
 */
export function PublicLayout({
  children,
  className,
  showHeader = true,
  showFooter = true,
}: PublicLayoutProps) {
  return (
    <div className={`min-h-screen bg-background flex flex-col ${className || ''}`}>
      {/* Header */}
      {showHeader && (
        <header className="border-b border-border bg-card">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between items-center py-4">
              <div className="flex items-center">
                <h1 className="text-xl font-bold text-foreground">Marketer Gen</h1>
              </div>
              <nav className="space-x-4">
                <Link href="/" className="text-muted-foreground hover:text-foreground">
                  Home
                </Link>
                <Link href="/about" className="text-muted-foreground hover:text-foreground">
                  About
                </Link>
                <Link href="/contact" className="text-muted-foreground hover:text-foreground">
                  Contact
                </Link>
              </nav>
            </div>
          </div>
        </header>
      )}

      {/* Main Content */}
      <main className="flex-1">{children}</main>

      {/* Footer */}
      {showFooter && (
        <footer className="border-t border-border bg-card">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            <div className="text-center text-muted-foreground">
              <p>&copy; 2024 Marketer Gen. All rights reserved.</p>
            </div>
          </div>
        </footer>
      )}
    </div>
  )
}
