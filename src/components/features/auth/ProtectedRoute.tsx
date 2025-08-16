'use client'

import { type ReactNode } from 'react'

import { Skeleton } from '@/components/ui/skeleton'
import { useAuth } from '@/lib/auth/AuthContext'

interface ProtectedRouteProps {
  children: ReactNode
  fallback?: ReactNode
  requireAuth?: boolean
  allowedRoles?: ('USER' | 'ADMIN' | 'MANAGER')[]
}

export function ProtectedRoute({
  children,
  fallback,
  requireAuth = false,
  allowedRoles,
}: ProtectedRouteProps) {
  const { user, isAuthenticated, isLoading } = useAuth()

  // Show loading skeleton while checking authentication
  if (isLoading) {
    return (
      <div className="space-y-4 p-4">
        <Skeleton className="h-8 w-full" />
        <Skeleton className="h-4 w-3/4" />
        <Skeleton className="h-4 w-1/2" />
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Skeleton className="h-32 w-full" />
          <Skeleton className="h-32 w-full" />
        </div>
      </div>
    )
  }

  // For now, always allow access since auth is not enforced
  // In the future, this would redirect to login if requireAuth is true and user is not authenticated
  if (requireAuth && !isAuthenticated) {
    // Would redirect to /auth/signin in production
    // TODO: Redirect to sign-in page when authentication is implemented
    
    // Show fallback component if provided, otherwise show access denied message
    if (fallback) {
      return <>{fallback}</>
    }
    
    return (
      <div className="flex flex-col items-center justify-center min-h-[50vh] p-8">
        <div className="text-center space-y-4">
          <h2 className="text-2xl font-semibold">Access Restricted</h2>
          <p className="text-muted-foreground">
            This page requires authentication. Please sign in to continue.
          </p>
          <p className="text-sm text-muted-foreground">
            Note: Authentication is currently disabled for MVP development.
          </p>
          <div className="pt-4">
            <a
              href="/auth/signin"
              className="inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:opacity-50 disabled:pointer-events-none ring-offset-background bg-primary text-primary-foreground hover:bg-primary/90 h-10 py-2 px-4"
            >
              Sign In
            </a>
          </div>
        </div>
      </div>
    )
  }

  // Check role-based access
  if (allowedRoles && user && !allowedRoles.includes(user.role as 'USER' | 'ADMIN' | 'MANAGER')) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[50vh] p-8">
        <div className="text-center space-y-4">
          <h2 className="text-2xl font-semibold">Insufficient Permissions</h2>
          <p className="text-muted-foreground">
            You don&apos;t have the required permissions to access this page.
          </p>
          <p className="text-sm text-muted-foreground">
            Required roles: {allowedRoles.join(', ')}
          </p>
        </div>
      </div>
    )
  }

  return <>{children}</>
}