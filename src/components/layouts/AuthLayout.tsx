import type { BaseComponentProps } from '@/lib/types'

interface AuthLayoutProps extends BaseComponentProps {
  showLogo?: boolean
}

/**
 * Layout component for authentication pages (login, register, etc.)
 */
export function AuthLayout({ children, className, showLogo = true }: AuthLayoutProps) {
  return (
    <div className={`min-h-screen bg-background flex flex-col ${className || ''}`}>
      <div className="flex-1 flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-md w-full space-y-8">
          {showLogo && (
            <div className="text-center">
              <h1 className="text-2xl font-bold text-foreground">Marketer Gen</h1>
              <p className="mt-2 text-sm text-muted-foreground">Sign in to your account</p>
            </div>
          )}
          {children}
        </div>
      </div>
    </div>
  )
}
