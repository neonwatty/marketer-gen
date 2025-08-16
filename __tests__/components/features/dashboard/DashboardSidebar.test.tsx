import React from 'react'
import { render, screen } from '@testing-library/react'
import { usePathname } from 'next/navigation'
import { DashboardSidebar } from '@/components/features/dashboard/DashboardSidebar'

// Mock Next.js navigation hook
jest.mock('next/navigation', () => ({
  usePathname: jest.fn()
}))

// Mock the sidebar components
jest.mock('@/components/ui/sidebar', () => ({
  Sidebar: ({ children, ...props }: any) => <div data-testid="sidebar" {...props}>{children}</div>,
  SidebarContent: ({ children }: any) => <div data-testid="sidebar-content">{children}</div>,
  SidebarFooter: ({ children }: any) => <div data-testid="sidebar-footer">{children}</div>,
  SidebarGroup: ({ children }: any) => <div data-testid="sidebar-group">{children}</div>,
  SidebarGroupContent: ({ children }: any) => <div data-testid="sidebar-group-content">{children}</div>,
  SidebarGroupLabel: ({ children }: any) => <div data-testid="sidebar-group-label">{children}</div>,
  SidebarHeader: ({ children }: any) => <div data-testid="sidebar-header">{children}</div>,
  SidebarMenu: ({ children }: any) => <ul data-testid="sidebar-menu">{children}</ul>,
  SidebarMenuButton: ({ children, asChild, isActive, ...props }: any) => 
    asChild ? <div data-active={isActive} {...props}>{children}</div> : <button data-active={isActive} {...props}>{children}</button>,
  SidebarMenuItem: ({ children }: any) => <li data-testid="sidebar-menu-item">{children}</li>,
  SidebarRail: () => <div data-testid="sidebar-rail" />
}))

describe('DashboardSidebar', () => {
  const mockUsePathname = usePathname as jest.MockedFunction<typeof usePathname>

  beforeEach(() => {
    mockUsePathname.mockReturnValue('/dashboard')
  })

  afterEach(() => {
    jest.clearAllMocks()
  })

  describe('Basic Rendering', () => {
    it('renders sidebar structure', () => {
      render(<DashboardSidebar />)
      
      expect(screen.getByTestId('sidebar')).toBeInTheDocument()
      expect(screen.getByTestId('sidebar-header')).toBeInTheDocument()
      expect(screen.getByTestId('sidebar-content')).toBeInTheDocument()
      expect(screen.getByTestId('sidebar-footer')).toBeInTheDocument()
    })

    it('renders brand logo and title in header', () => {
      render(<DashboardSidebar />)
      
      expect(screen.getByText('Marketer Gen')).toBeInTheDocument()
      expect(screen.getByText('Dashboard')).toBeInTheDocument()
    })

    it('renders all navigation items', () => {
      render(<DashboardSidebar />)
      
      expect(screen.getByText('Overview')).toBeInTheDocument()
      expect(screen.getByText('Campaigns')).toBeInTheDocument()
      expect(screen.getByText('Analytics')).toBeInTheDocument()
      expect(screen.getByText('Audience')).toBeInTheDocument()
      expect(screen.getByText('Templates')).toBeInTheDocument()
      expect(screen.getByText('Settings')).toBeInTheDocument()
    })

    it('renders quick actions section', () => {
      render(<DashboardSidebar />)
      
      expect(screen.getByText('Quick Actions')).toBeInTheDocument()
      expect(screen.getByText('New Campaign')).toBeInTheDocument()
    })

    it('renders account settings in footer', () => {
      render(<DashboardSidebar />)
      
      expect(screen.getByText('Account Settings')).toBeInTheDocument()
    })
  })

  describe('Navigation Links', () => {
    it('renders navigation links with correct hrefs', () => {
      render(<DashboardSidebar />)
      
      const overviewLink = screen.getByRole('link', { name: /overview/i })
      const campaignsLink = screen.getByRole('link', { name: /campaigns/i })
      const analyticsLink = screen.getByRole('link', { name: /analytics/i })
      
      expect(overviewLink).toHaveAttribute('href', '/dashboard')
      expect(campaignsLink).toHaveAttribute('href', '/dashboard/campaigns')
      expect(analyticsLink).toHaveAttribute('href', '/dashboard/analytics')
    })

    it('renders new campaign link', () => {
      render(<DashboardSidebar />)
      
      const newCampaignLink = screen.getByRole('link', { name: /new campaign/i })
      expect(newCampaignLink).toHaveAttribute('href', '/dashboard/campaigns/new')
    })
  })

  describe('Active State Logic', () => {
    it('marks overview as active when on dashboard root', () => {
      mockUsePathname.mockReturnValue('/dashboard')
      render(<DashboardSidebar />)
      
      // Find the Overview menu button and check if it's marked as active
      const overviewItem = screen.getByText('Overview').closest('[data-active]')
      expect(overviewItem).toHaveAttribute('data-active', 'true')
    })

    it('marks campaigns as active when on campaigns page', () => {
      mockUsePathname.mockReturnValue('/dashboard/campaigns')
      render(<DashboardSidebar />)
      
      const campaignsItem = screen.getByText('Campaigns').closest('[data-active]')
      expect(campaignsItem).toHaveAttribute('data-active', 'true')
    })

    it('marks campaigns as active when on individual campaign page', () => {
      mockUsePathname.mockReturnValue('/dashboard/campaigns/123')
      render(<DashboardSidebar />)
      
      const campaignsItem = screen.getByText('Campaigns').closest('[data-active]')
      expect(campaignsItem).toHaveAttribute('data-active', 'true')
    })

    it('does not mark dashboard as active when on sub-pages', () => {
      mockUsePathname.mockReturnValue('/dashboard/campaigns')
      render(<DashboardSidebar />)
      
      const overviewItem = screen.getByText('Overview').closest('[data-active]')
      expect(overviewItem).toHaveAttribute('data-active', 'false')
    })
  })

  describe('Icons and Visual Elements', () => {
    it('renders navigation icons', () => {
      render(<DashboardSidebar />)
      
      // Check that SVG icons are rendered (they should be in the DOM)
      const svgElements = document.querySelectorAll('svg')
      expect(svgElements.length).toBeGreaterThan(0)
    })

    it('has proper sidebar structure classes', () => {
      render(<DashboardSidebar />)
      
      const sidebar = screen.getByTestId('sidebar')
      expect(sidebar).toHaveAttribute('variant', 'inset')
    })
  })

  describe('Accessibility', () => {
    it('has proper sidebar structure for accessibility', () => {
      render(<DashboardSidebar />)
      
      // Check that sidebar has proper structure
      expect(screen.getByTestId('sidebar')).toBeInTheDocument()
      expect(screen.getAllByTestId('sidebar-menu')).toHaveLength(2) // Navigation + Quick Actions
    })

    it('all navigation items are focusable links', () => {
      render(<DashboardSidebar />)
      
      const links = screen.getAllByRole('link')
      expect(links.length).toBeGreaterThan(0)
      
      links.forEach(link => {
        expect(link).toBeInTheDocument()
      })
    })

    it('account settings button is accessible', () => {
      render(<DashboardSidebar />)
      
      const accountButton = screen.getByRole('button', { name: /account settings/i })
      expect(accountButton).toBeInTheDocument()
    })
  })

  describe('Responsive Design', () => {
    it('has rail component for mobile interactions', () => {
      render(<DashboardSidebar />)
      
      expect(screen.getByTestId('sidebar-rail')).toBeInTheDocument()
    })
  })
})