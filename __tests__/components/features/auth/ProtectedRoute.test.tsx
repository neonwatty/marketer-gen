import React from 'react'
import { render, screen } from '@testing-library/react'
import { ProtectedRoute } from '@/components/features/auth/ProtectedRoute'

// Mock the skeleton component
jest.mock('@/components/ui/skeleton', () => ({
  Skeleton: ({ className, ...props }: any) => (
    <div className={className} data-testid="skeleton" {...props} />
  ),
}))

// Mock the auth context
const mockUseAuth = jest.fn()
jest.mock('@/lib/auth/AuthContext', () => ({
  useAuth: () => mockUseAuth(),
}))

describe('ProtectedRoute', () => {
  const TestComponent = () => <div data-testid="protected-content">Protected Content</div>
  const FallbackComponent = () => <div data-testid="fallback-content">Fallback Content</div>

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('Loading State', () => {
    it('displays loading skeleton when isLoading is true', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: true,
        error: null,
      })

      render(
        <ProtectedRoute>
          <TestComponent />
        </ProtectedRoute>
      )

      // Should show skeleton loading state
      expect(screen.getAllByTestId('skeleton')).toHaveLength(5) // Based on skeleton structure
      expect(screen.queryByTestId('protected-content')).not.toBeInTheDocument()
    })

    it('does not display content while loading', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: true,
        error: null,
      })

      render(
        <ProtectedRoute>
          <TestComponent />
        </ProtectedRoute>
      )

      expect(screen.queryByTestId('protected-content')).not.toBeInTheDocument()
    })
  })

  describe('Authentication Not Required (requireAuth=false)', () => {
    it('displays content when not authenticated and requireAuth is false', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute requireAuth={false}>
          <TestComponent />
        </ProtectedRoute>
      )

      expect(screen.getByTestId('protected-content')).toBeInTheDocument()
    })

    it('displays content when authenticated and requireAuth is false', () => {
      mockUseAuth.mockReturnValue({
        user: { id: '1', email: 'test@example.com', name: 'Test User', role: 'USER' },
        isAuthenticated: true,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute requireAuth={false}>
          <TestComponent />
        </ProtectedRoute>
      )

      expect(screen.getByTestId('protected-content')).toBeInTheDocument()
    })

    it('uses requireAuth=false as default behavior', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute>
          <TestComponent />
        </ProtectedRoute>
      )

      // Should display content even when not authenticated (default behavior)
      expect(screen.getByTestId('protected-content')).toBeInTheDocument()
    })
  })

  describe('Authentication Required (requireAuth=true)', () => {
    it('displays access restricted message when not authenticated', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute requireAuth={true}>
          <TestComponent />
        </ProtectedRoute>
      )

      expect(screen.getByText('Access Restricted')).toBeInTheDocument()
      expect(screen.getByText('This page requires authentication. Please sign in to continue.')).toBeInTheDocument()
      expect(screen.getByText('Note: Authentication is currently disabled for MVP development.')).toBeInTheDocument()
      expect(screen.queryByTestId('protected-content')).not.toBeInTheDocument()
    })

    it('displays sign in button when access is restricted', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute requireAuth={true}>
          <TestComponent />
        </ProtectedRoute>
      )

      const signInButton = screen.getByRole('link', { name: /sign in/i })
      expect(signInButton).toBeInTheDocument()
      expect(signInButton).toHaveAttribute('href', '/auth/signin')
    })

    it('displays content when authenticated and requireAuth is true', () => {
      mockUseAuth.mockReturnValue({
        user: { id: '1', email: 'test@example.com', name: 'Test User', role: 'USER' },
        isAuthenticated: true,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute requireAuth={true}>
          <TestComponent />
        </ProtectedRoute>
      )

      expect(screen.getByTestId('protected-content')).toBeInTheDocument()
      expect(screen.queryByText('Access Restricted')).not.toBeInTheDocument()
    })

    it('displays custom fallback when provided and not authenticated', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute requireAuth={true} fallback={<FallbackComponent />}>
          <TestComponent />
        </ProtectedRoute>
      )

      expect(screen.getByTestId('fallback-content')).toBeInTheDocument()
      expect(screen.queryByTestId('protected-content')).not.toBeInTheDocument()
      expect(screen.queryByText('Access Restricted')).not.toBeInTheDocument()
    })
  })

  describe('Role-Based Access Control', () => {
    const userWithUserRole = {
      id: '1',
      email: 'user@example.com',
      name: 'Regular User',
      role: 'USER' as const,
    }

    const userWithAdminRole = {
      id: '2',
      email: 'admin@example.com',
      name: 'Admin User',
      role: 'ADMIN' as const,
    }

    const userWithManagerRole = {
      id: '3',
      email: 'manager@example.com',
      name: 'Manager User',
      role: 'MANAGER' as const,
    }

    it('allows access when user has required role', () => {
      mockUseAuth.mockReturnValue({
        user: userWithAdminRole,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute allowedRoles={['ADMIN']}>
          <TestComponent />
        </ProtectedRoute>
      )

      expect(screen.getByTestId('protected-content')).toBeInTheDocument()
    })

    it('allows access when user has one of multiple allowed roles', () => {
      mockUseAuth.mockReturnValue({
        user: userWithManagerRole,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute allowedRoles={['ADMIN', 'MANAGER']}>
          <TestComponent />
        </ProtectedRoute>
      )

      expect(screen.getByTestId('protected-content')).toBeInTheDocument()
    })

    it('denies access when user does not have required role', () => {
      mockUseAuth.mockReturnValue({
        user: userWithUserRole,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute allowedRoles={['ADMIN']}>
          <TestComponent />
        </ProtectedRoute>
      )

      expect(screen.getByText('Insufficient Permissions')).toBeInTheDocument()
      expect(screen.getByText("You don't have the required permissions to access this page.")).toBeInTheDocument()
      expect(screen.getByText('Required roles: ADMIN')).toBeInTheDocument()
      expect(screen.queryByTestId('protected-content')).not.toBeInTheDocument()
    })

    it('displays multiple required roles in error message', () => {
      mockUseAuth.mockReturnValue({
        user: userWithUserRole,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute allowedRoles={['ADMIN', 'MANAGER']}>
          <TestComponent />
        </ProtectedRoute>
      )

      expect(screen.getByText('Required roles: ADMIN, MANAGER')).toBeInTheDocument()
    })

    it('ignores role check when no allowedRoles specified', () => {
      mockUseAuth.mockReturnValue({
        user: userWithUserRole,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute>
          <TestComponent />
        </ProtectedRoute>
      )

      expect(screen.getByTestId('protected-content')).toBeInTheDocument()
    })

    it('handles missing user gracefully when checking roles', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute allowedRoles={['ADMIN']}>
          <TestComponent />
        </ProtectedRoute>
      )

      // Should show content (no auth required by default)
      expect(screen.getByTestId('protected-content')).toBeInTheDocument()
    })
  })

  describe('Combined Authentication and Role Requirements', () => {
    it('requires both authentication and role when both are specified', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute requireAuth={true} allowedRoles={['ADMIN']}>
          <TestComponent />
        </ProtectedRoute>
      )

      // Should show authentication error first
      expect(screen.getByText('Access Restricted')).toBeInTheDocument()
      expect(screen.queryByText('Insufficient Permissions')).not.toBeInTheDocument()
      expect(screen.queryByTestId('protected-content')).not.toBeInTheDocument()
    })

    it('checks role after authentication passes', () => {
      mockUseAuth.mockReturnValue({
        user: { id: '1', email: 'user@example.com', name: 'User', role: 'USER' },
        isAuthenticated: true,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute requireAuth={true} allowedRoles={['ADMIN']}>
          <TestComponent />
        </ProtectedRoute>
      )

      // Should show role permission error
      expect(screen.getByText('Insufficient Permissions')).toBeInTheDocument()
      expect(screen.queryByText('Access Restricted')).not.toBeInTheDocument()
      expect(screen.queryByTestId('protected-content')).not.toBeInTheDocument()
    })

    it('allows access when both authentication and role requirements are met', () => {
      mockUseAuth.mockReturnValue({
        user: { id: '1', email: 'admin@example.com', name: 'Admin', role: 'ADMIN' },
        isAuthenticated: true,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute requireAuth={true} allowedRoles={['ADMIN']}>
          <TestComponent />
        </ProtectedRoute>
      )

      expect(screen.getByTestId('protected-content')).toBeInTheDocument()
      expect(screen.queryByText('Access Restricted')).not.toBeInTheDocument()
      expect(screen.queryByText('Insufficient Permissions')).not.toBeInTheDocument()
    })
  })

  describe('Loading Skeleton Structure', () => {
    it('renders proper skeleton layout matching expected content', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: true,
        error: null,
      })

      render(
        <ProtectedRoute>
          <TestComponent />
        </ProtectedRoute>
      )

      const skeletons = screen.getAllByTestId('skeleton')
      expect(skeletons).toHaveLength(5) // Based on the skeleton structure in component
    })

    it('uses proper spacing and padding for skeleton', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: true,
        error: null,
      })

      const { container } = render(
        <ProtectedRoute>
          <TestComponent />
        </ProtectedRoute>
      )

      const skeletonContainer = container.querySelector('.space-y-4.p-4')
      expect(skeletonContainer).toBeInTheDocument()
    })
  })

  describe('Error Handling', () => {
    it('handles auth context errors gracefully', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: 'Authentication service unavailable',
      })

      render(
        <ProtectedRoute>
          <TestComponent />
        </ProtectedRoute>
      )

      // Should still render content when not requiring auth
      expect(screen.getByTestId('protected-content')).toBeInTheDocument()
    })
  })

  describe('Accessibility', () => {
    it('has proper heading structure for access restricted message', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute requireAuth={true}>
          <TestComponent />
        </ProtectedRoute>
      )

      const heading = screen.getByRole('heading', { name: /access restricted/i })
      expect(heading).toBeInTheDocument()
    })

    it('has proper heading structure for insufficient permissions message', () => {
      mockUseAuth.mockReturnValue({
        user: { id: '1', email: 'user@example.com', name: 'User', role: 'USER' },
        isAuthenticated: true,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute allowedRoles={['ADMIN']}>
          <TestComponent />
        </ProtectedRoute>
      )

      const heading = screen.getByRole('heading', { name: /insufficient permissions/i })
      expect(heading).toBeInTheDocument()
    })

    it('has accessible sign in link', () => {
      mockUseAuth.mockReturnValue({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      })

      render(
        <ProtectedRoute requireAuth={true}>
          <TestComponent />
        </ProtectedRoute>
      )

      const signInLink = screen.getByRole('link', { name: /sign in/i })
      expect(signInLink).toHaveAttribute('href', '/auth/signin')
    })
  })
})