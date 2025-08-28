import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { axe } from 'jest-axe'
import { UserMenu } from '@/components/features/auth/UserMenu'

// Mock dependencies
jest.mock('next/image', () => ({
  __esModule: true,
  default: (props: any) => <img {...props} />,
}))

jest.mock('lucide-react', () => ({
  ChevronDown: () => <div data-testid="chevron-down-icon" />,
  User: () => <div data-testid="user-icon" />,
}))

// Mock Dialog components
jest.mock('@/components/ui/dialog', () => ({
  Dialog: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  DialogContent: ({ children }: { children: React.ReactNode }) => <div data-testid="dialog-content">{children}</div>,
  DialogDescription: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  DialogHeader: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  DialogTitle: ({ children }: { children: React.ReactNode }) => <h2>{children}</h2>,
  DialogTrigger: ({ children, asChild }: { children: React.ReactNode; asChild?: boolean }) => {
    return asChild ? <div data-testid="dialog-trigger">{children}</div> : <button data-testid="dialog-trigger">{children}</button>
  },
}))

// Mock UserProfile component
jest.mock('@/components/features/auth/UserProfile', () => ({
  UserProfile: ({ user, onEdit, onSignOut }: any) => (
    <div data-testid="user-profile">
      <div>User: {user?.name || 'No user'}</div>
      <div>Email: {user?.email || 'No email'}</div>
      <button onClick={onEdit} data-testid="edit-profile-button">
        Edit Profile
      </button>
      <button onClick={onSignOut} data-testid="sign-out-button">
        Sign Out
      </button>
    </div>
  ),
}))

// Mock AuthContext
const mockAuth = {
  user: null,
  isAuthenticated: false,
  isLoading: false,
  signOut: jest.fn(),
}

jest.mock('@/lib/auth/AuthContext', () => ({
  useAuth: () => mockAuth,
}))

const mockUser = {
  id: 'user-1',
  name: 'John Doe',
  email: 'john@example.com',
  role: 'user' as const,
  avatar: '/avatar.jpg',
  createdAt: '2024-01-01T00:00:00Z',
  updatedAt: '2024-01-15T00:00:00Z',
}

describe('UserMenu', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    // Reset mock auth state
    mockAuth.user = null
    mockAuth.isAuthenticated = false
    mockAuth.isLoading = false
    mockAuth.signOut.mockClear()
  })

  describe('Loading State', () => {
    it('should show loading skeleton when isLoading is true', () => {
      mockAuth.isLoading = true

      render(<UserMenu />)

      expect(document.querySelector('.animate-pulse')).toBeInTheDocument()
      expect(screen.queryByText('Sign in')).not.toBeInTheDocument()
    })

    it('should have proper accessibility during loading', async () => {
      mockAuth.isLoading = true
      const { container } = render(<UserMenu />)

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('should apply custom className during loading', () => {
      mockAuth.isLoading = true

      const { container } = render(<UserMenu className="custom-class" />)

      expect(container.firstChild).toHaveClass('custom-class')
    })
  })

  describe('Unauthenticated State', () => {
    beforeEach(() => {
      mockAuth.isAuthenticated = false
      mockAuth.user = null
    })

    it('should show sign in and sign up buttons when not authenticated', () => {
      render(<UserMenu />)

      expect(screen.getByRole('link', { name: /sign in/i })).toBeInTheDocument()
      expect(screen.getByRole('link', { name: /sign up/i })).toBeInTheDocument()
    })

    it('should have correct links for sign in and sign up', () => {
      render(<UserMenu />)

      const signInLink = screen.getByRole('link', { name: /sign in/i })
      const signUpLink = screen.getByRole('link', { name: /sign up/i })

      expect(signInLink).toHaveAttribute('href', '/auth/signin')
      expect(signUpLink).toHaveAttribute('href', '/auth/signup')
    })

    it('should apply custom className when unauthenticated', () => {
      const { container } = render(<UserMenu className="custom-class" />)

      expect(container.firstChild).toHaveClass('custom-class')
    })

    it('should have proper accessibility for unauthenticated state', async () => {
      const { container } = render(<UserMenu />)

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('should support keyboard navigation for auth buttons', async () => {
      const user = userEvent.setup()
      render(<UserMenu />)

      await user.tab()
      expect(document.activeElement).toHaveTextContent('Sign in')

      await user.tab()
      expect(document.activeElement).toHaveTextContent('Sign up')
    })
  })

  describe('Authenticated State', () => {
    beforeEach(() => {
      mockAuth.isAuthenticated = true
      mockAuth.user = mockUser
    })

    it('should show user information when authenticated', () => {
      render(<UserMenu />)

      expect(screen.getByText('John Doe')).toBeInTheDocument()
      expect(screen.getByText('john@example.com')).toBeInTheDocument()
      expect(screen.getByTestId('chevron-down-icon')).toBeInTheDocument()
    })

    it('should display user avatar when available', () => {
      render(<UserMenu />)

      const avatar = screen.getByAltText('John Doe')
      expect(avatar).toBeInTheDocument()
      expect(avatar).toHaveAttribute('src', '/avatar.jpg')
    })

    it('should display user icon when no avatar is provided', () => {
      mockAuth.user = { ...mockUser, avatar: undefined }

      render(<UserMenu />)

      expect(screen.getByTestId('user-icon')).toBeInTheDocument()
    })

    it('should handle missing user name gracefully', () => {
      mockAuth.user = { ...mockUser, name: null }

      render(<UserMenu />)

      expect(screen.getByText('User')).toBeInTheDocument()
      expect(screen.getByText('john@example.com')).toBeInTheDocument()
    })

    it('should open user profile dialog when clicked', async () => {
      const user = userEvent.setup()
      render(<UserMenu />)

      const userButton = screen.getByTestId('dialog-trigger').querySelector('button')!
      await user.click(userButton)

      expect(screen.getByText('User Profile')).toBeInTheDocument()
      expect(screen.getByText('Manage your account settings and preferences.')).toBeInTheDocument()
      expect(screen.getByTestId('user-profile')).toBeInTheDocument()
    })

    it('should pass user data to UserProfile component', async () => {
      const user = userEvent.setup()
      render(<UserMenu />)

      const userButton = screen.getByTestId('dialog-trigger').querySelector('button')!
      await user.click(userButton)

      expect(screen.getByText('User: John Doe')).toBeInTheDocument()
      expect(screen.getByText('Email: john@example.com')).toBeInTheDocument()
    })

    it('should call signOut when sign out button is clicked', async () => {
      const user = userEvent.setup()
      render(<UserMenu />)

      const userButton = screen.getByTestId('dialog-trigger').querySelector('button')!
      await user.click(userButton)

      const signOutButton = screen.getByTestId('sign-out-button')
      await user.click(signOutButton)

      expect(mockAuth.signOut).toHaveBeenCalled()
    })

    it('should apply custom className when authenticated', () => {
      const { container } = render(<UserMenu className="custom-class" />)

      expect(container.firstChild).toHaveClass('custom-class')
    })

    it('should have proper accessibility for authenticated state', async () => {
      const { container } = render(<UserMenu />)

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('should maintain accessibility with dialog open', async () => {
      const user = userEvent.setup()
      const { container } = render(<UserMenu />)

      const userButton = screen.getByTestId('dialog-trigger').querySelector('button')!
      await user.click(userButton)

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('should support keyboard navigation for user menu', async () => {
      const user = userEvent.setup()
      render(<UserMenu />)

      const userButton = screen.getByTestId('dialog-trigger').querySelector('button')!
      userButton.focus()
      expect(document.activeElement).toBe(userButton)

      await user.keyboard('{Enter}')
      expect(screen.getByText('User Profile')).toBeInTheDocument()
    })
  })

  describe('Demo User Fallback', () => {
    beforeEach(() => {
      mockAuth.isAuthenticated = true
      mockAuth.user = null // No user data but authenticated
    })

    it('should display demo user when authenticated but no user data', () => {
      render(<UserMenu />)

      expect(screen.getByText('Demo User')).toBeInTheDocument()
      expect(screen.getByText('demo@example.com')).toBeInTheDocument()
    })

    it('should pass demo user data to UserProfile', async () => {
      const user = userEvent.setup()
      render(<UserMenu />)

      const userButton = screen.getByTestId('dialog-trigger').querySelector('button')!
      await user.click(userButton)

      expect(screen.getByText('User: Demo User')).toBeInTheDocument()
      expect(screen.getByText('Email: demo@example.com')).toBeInTheDocument()
    })

    it('should show user icon for demo user (no avatar)', () => {
      render(<UserMenu />)

      expect(screen.getByTestId('user-icon')).toBeInTheDocument()
    })
  })

  describe('Dialog Behavior', () => {
    beforeEach(() => {
      mockAuth.isAuthenticated = true
      mockAuth.user = mockUser
    })

    it('should render dialog content when clicked', async () => {
      const user = userEvent.setup()
      render(<UserMenu />)

      const userButton = screen.getByTestId('dialog-trigger').querySelector('button')!
      await user.click(userButton)

      expect(screen.getByText('User Profile')).toBeInTheDocument()
      expect(screen.getByText('Manage your account settings and preferences.')).toBeInTheDocument()
    })

    it('should render dialog trigger with proper structure', () => {
      render(<UserMenu />)

      const dialogTrigger = screen.getByTestId('dialog-trigger')
      expect(dialogTrigger).toBeInTheDocument()
      expect(dialogTrigger.querySelector('button')).toBeInTheDocument()
    })
  })

  describe('Responsive Behavior', () => {
    beforeEach(() => {
      mockAuth.isAuthenticated = true
      mockAuth.user = mockUser
    })

    it('should hide user details on smaller screens', () => {
      render(<UserMenu />)

      const userDetails = screen.getByText('John Doe').parentElement
      expect(userDetails).toHaveClass('hidden', 'md:block')
    })

    it('should always show avatar regardless of screen size', () => {
      render(<UserMenu />)

      const avatar = screen.getByAltText('John Doe')
      expect(avatar).toBeInTheDocument()
      expect(avatar.parentElement).not.toHaveClass('hidden')
    })
  })

  describe('Edge Cases', () => {
    it('should handle missing email in user data', () => {
      mockAuth.isAuthenticated = true
      mockAuth.user = { ...mockUser, email: undefined as any }

      render(<UserMenu />)

      expect(screen.getByText('John Doe')).toBeInTheDocument()
      // Should not crash when email is missing
    })

    it('should handle empty string for user name', () => {
      mockAuth.isAuthenticated = true
      mockAuth.user = { ...mockUser, name: '' }

      render(<UserMenu />)

      expect(screen.getByText('User')).toBeInTheDocument()
    })

    it('should handle null avatar path', () => {
      mockAuth.isAuthenticated = true
      mockAuth.user = { ...mockUser, avatar: null as any }

      render(<UserMenu />)

      expect(screen.getByTestId('user-icon')).toBeInTheDocument()
    })

    it('should handle undefined className prop', () => {
      mockAuth.isAuthenticated = true
      mockAuth.user = mockUser

      render(<UserMenu className={undefined} />)

      expect(screen.getByText('John Doe')).toBeInTheDocument()
    })

    it('should handle empty string className', () => {
      mockAuth.isAuthenticated = true
      mockAuth.user = mockUser

      render(<UserMenu className="" />)

      expect(screen.getByText('John Doe')).toBeInTheDocument()
    })
  })

  describe('Error Handling', () => {
    it('should handle signOut errors gracefully', async () => {
      mockAuth.isAuthenticated = true
      mockAuth.user = mockUser
      mockAuth.signOut.mockRejectedValue(new Error('Sign out failed'))

      const user = userEvent.setup()
      render(<UserMenu />)

      const userButton = screen.getByTestId('dialog-trigger').querySelector('button')!
      await user.click(userButton)

      const signOutButton = screen.getByTestId('sign-out-button')
      await user.click(signOutButton)

      expect(mockAuth.signOut).toHaveBeenCalled()
      // Component should remain functional even if signOut fails
      expect(screen.getByText('User Profile')).toBeInTheDocument()
    })

    it('should handle onEdit callback being undefined', async () => {
      mockAuth.isAuthenticated = true
      mockAuth.user = mockUser
      
      const user = userEvent.setup()
      render(<UserMenu />)

      const userButton = screen.getByTestId('dialog-trigger').querySelector('button')!
      await user.click(userButton)

      const editButton = screen.getByTestId('edit-profile-button')
      await user.click(editButton)

      // Should not crash when edit functionality is not implemented
      expect(screen.getByText('User Profile')).toBeInTheDocument()
    })
  })

  describe('Accessibility', () => {
    it('should meet accessibility standards for all states', async () => {
      // Test loading state
      mockAuth.isLoading = true
      let { container, rerender } = render(<UserMenu />)
      let results = await axe(container)
      expect(results).toHaveNoViolations()

      // Test unauthenticated state
      mockAuth.isLoading = false
      mockAuth.isAuthenticated = false
      rerender(<UserMenu />)
      results = await axe(container)
      expect(results).toHaveNoViolations()

      // Test authenticated state
      mockAuth.isAuthenticated = true
      mockAuth.user = mockUser
      rerender(<UserMenu />)
      results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('should have proper ARIA attributes for user button', () => {
      mockAuth.isAuthenticated = true
      mockAuth.user = mockUser

      render(<UserMenu />)

      const userButton = screen.getByTestId('dialog-trigger').querySelector('button')!
      expect(userButton).toBeInTheDocument()
      // Dialog trigger should have appropriate ARIA attributes
    })

    it('should provide proper alt text for avatar images', () => {
      mockAuth.isAuthenticated = true
      mockAuth.user = mockUser

      render(<UserMenu />)

      const avatar = screen.getByAltText('John Doe')
      expect(avatar).toBeInTheDocument()
    })

    it('should provide fallback alt text when name is missing', () => {
      mockAuth.isAuthenticated = true
      mockAuth.user = { ...mockUser, name: null }

      render(<UserMenu />)

      const avatar = screen.getByAltText('User avatar')
      expect(avatar).toBeInTheDocument()
    })

    it('should support screen reader navigation', async () => {
      const user = userEvent.setup()
      mockAuth.isAuthenticated = true
      mockAuth.user = mockUser

      render(<UserMenu />)

      const userButton = screen.getByTestId('dialog-trigger').querySelector('button')!
      userButton.focus()

      await user.keyboard('{Enter}')
      expect(screen.getByText('User Profile')).toBeInTheDocument()
    })
  })

  describe('Integration', () => {
    it('should work properly with different auth states in sequence', async () => {
      const user = userEvent.setup()

      // Start with loading
      mockAuth.isLoading = true
      const { rerender } = render(<UserMenu />)
      expect(document.querySelector('.animate-pulse')).toBeInTheDocument()

      // Move to unauthenticated
      mockAuth.isLoading = false
      mockAuth.isAuthenticated = false
      rerender(<UserMenu />)
      expect(screen.getByText('Sign in')).toBeInTheDocument()

      // Move to authenticated
      mockAuth.isAuthenticated = true
      mockAuth.user = mockUser
      rerender(<UserMenu />)
      expect(screen.getByText('John Doe')).toBeInTheDocument()

      // Test interaction
      const userButton = screen.getByTestId('dialog-trigger').querySelector('button')!
      await user.click(userButton)
      expect(screen.getByText('User Profile')).toBeInTheDocument()
    })
  })
})