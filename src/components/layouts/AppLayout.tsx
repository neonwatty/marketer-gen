import { Header } from '@/components/features/navigation'
import { AuthProvider } from '@/lib/auth/AuthContext'
import { SessionProvider } from '@/lib/auth/SessionProvider'

import type { BaseComponentProps } from '@/lib/types'

interface AppLayoutProps extends BaseComponentProps {
  includeHeader?: boolean
  requireAuth?: boolean
  allowedRoles?: ('USER' | 'ADMIN' | 'MANAGER')[]
}

/**
 * Main application layout with authentication support
 * This component wraps the app with session and auth providers
 */
export function AppLayout({
  children,
  className,
  includeHeader = true,
  requireAuth: _requireAuth = false,
  allowedRoles: _allowedRoles,
}: AppLayoutProps) {
  return (
    <SessionProvider>
      <AuthProvider>
        <div className={`min-h-screen bg-background text-foreground ${className || ''}`}>
          {includeHeader && <Header />}
          <main className={includeHeader ? 'pt-0' : 'pt-8'}>
            {children}
          </main>
        </div>
      </AuthProvider>
    </SessionProvider>
  )
}