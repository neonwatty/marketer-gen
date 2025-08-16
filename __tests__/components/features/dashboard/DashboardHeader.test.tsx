import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import { DashboardHeader } from '@/components/features/dashboard/DashboardHeader'

// Mock the sidebar trigger since it might have context dependencies
jest.mock('@/components/ui/sidebar', () => ({
  SidebarTrigger: ({ children, className }: any) => (
    <button className={className} data-testid="sidebar-trigger">
      {children || 'Menu'}
    </button>
  )
}))

describe('DashboardHeader', () => {
  beforeEach(() => {
    // Clear any previous renders
    jest.clearAllMocks()
  })

  describe('Basic Rendering', () => {
    it('renders header with search functionality', () => {
      render(<DashboardHeader />)
      
      // Check for search input (desktop)
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      expect(searchInput).toBeInTheDocument()
      expect(searchInput).toHaveAttribute('type', 'search')
    })

    it('renders user menu', () => {
      render(<DashboardHeader />)
      
      // Check for user avatar/menu button - it's a dropdown trigger button
      const userMenuButtons = screen.getAllByRole('button')
      const userMenuButton = userMenuButtons.find(button => 
        button.hasAttribute('aria-haspopup') && button.getAttribute('aria-haspopup') === 'menu'
      )
      expect(userMenuButton).toBeInTheDocument()
    })

    it('renders notifications button with badge', () => {
      render(<DashboardHeader />)
      
      const notificationsButton = screen.getByRole('button', { name: /notifications/i })
      expect(notificationsButton).toBeInTheDocument()
      
      // Check for notification badge
      const badge = screen.getByText('3')
      expect(badge).toBeInTheDocument()
    })

    it('renders sidebar trigger for mobile', () => {
      render(<DashboardHeader />)
      
      const sidebarTrigger = screen.getByTestId('sidebar-trigger')
      expect(sidebarTrigger).toBeInTheDocument()
    })
  })

  describe('Search Functionality', () => {
    it('allows typing in search input', () => {
      render(<DashboardHeader />)
      
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      fireEvent.change(searchInput, { target: { value: 'test campaign' } })
      
      expect(searchInput).toHaveValue('test campaign')
    })

    it('has search icon in input', () => {
      render(<DashboardHeader />)
      
      // The search icon should be present (rendered as SVG)
      const searchIcon = document.querySelector('svg')
      expect(searchIcon).toBeInTheDocument()
    })
  })

  describe('User Menu Interaction', () => {
    it('user menu button is clickable', () => {
      render(<DashboardHeader />)
      
      const userMenuButtons = screen.getAllByRole('button')
      const userMenuButton = userMenuButtons.find(button => 
        button.hasAttribute('aria-haspopup') && button.getAttribute('aria-haspopup') === 'menu'
      )
      
      if (userMenuButton) {
        fireEvent.click(userMenuButton)
        // After click, button should still exist (menu might open in portal)
        expect(userMenuButton).toBeInTheDocument()
      }
    })

    it('user menu is accessible', () => {
      render(<DashboardHeader />)
      
      const userMenuButtons = screen.getAllByRole('button')
      const userMenuButton = userMenuButtons.find(button => 
        button.hasAttribute('aria-haspopup') && button.getAttribute('aria-haspopup') === 'menu'
      )
      
      expect(userMenuButton).toBeInTheDocument()
      expect(userMenuButton).toHaveAttribute('aria-expanded', 'false')
    })
  })

  describe('Responsive Design', () => {
    it('shows mobile search button on small screens', () => {
      render(<DashboardHeader />)
      
      // Mobile search button should be present
      const mobileSearchButton = screen.getByRole('button', { name: /search/i })
      expect(mobileSearchButton).toBeInTheDocument()
    })

    it('has proper responsive classes', () => {
      const { container } = render(<DashboardHeader />)
      
      // Check that header has responsive classes
      const header = container.querySelector('header')
      expect(header).toHaveClass('sticky', 'top-0', 'z-50', 'w-full', 'border-b')
    })
  })

  describe('Accessibility', () => {
    it('has proper header role', () => {
      render(<DashboardHeader />)
      
      const header = screen.getByRole('banner')
      expect(header).toBeInTheDocument()
    })

    it('buttons have proper screen reader labels', () => {
      render(<DashboardHeader />)
      
      const searchButton = screen.getByRole('button', { name: /search/i })
      const notificationsButton = screen.getByRole('button', { name: /notifications/i })
      
      expect(searchButton).toBeInTheDocument()
      expect(notificationsButton).toBeInTheDocument()
    })

    it('search input has proper labeling', () => {
      render(<DashboardHeader />)
      
      const searchInput = screen.getByPlaceholderText('Search campaigns...')
      expect(searchInput).toHaveAttribute('type', 'search')
    })
  })

  describe('Visual Elements', () => {
    it('renders backdrop blur effect', () => {
      const { container } = render(<DashboardHeader />)
      
      const header = container.querySelector('header')
      expect(header).toHaveClass('backdrop-blur')
    })

    it('has correct height and padding', () => {
      const { container } = render(<DashboardHeader />)
      
      const headerContent = container.querySelector('.flex.h-14')
      expect(headerContent).toBeInTheDocument()
    })
  })
})