import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { DashboardLayout } from '@/components/layout/DashboardLayout'
import { setViewportSize, breakpoints } from '@/test/test-utils'

// Mock the sidebar components for testing
vi.mock('@/components/ui/sidebar', () => ({
  Sidebar: ({ children, collapsible, variant }: any) => (
    <div 
      data-testid="sidebar" 
      data-collapsible={collapsible}
      data-variant={variant}
      className="sidebar-mock"
    >
      {children}
    </div>
  ),
  SidebarContent: ({ children }: any) => (
    <div data-testid="sidebar-content">{children}</div>
  ),
  SidebarFooter: ({ children }: any) => (
    <div data-testid="sidebar-footer">{children}</div>
  ),
  SidebarGroup: ({ children }: any) => (
    <div data-testid="sidebar-group">{children}</div>
  ),
  SidebarGroupContent: ({ children }: any) => (
    <div data-testid="sidebar-group-content">{children}</div>
  ),
  SidebarGroupLabel: ({ children }: any) => (
    <div data-testid="sidebar-group-label">{children}</div>
  ),
  SidebarHeader: ({ children }: any) => (
    <div data-testid="sidebar-header">{children}</div>
  ),
  SidebarMenu: ({ children }: any) => (
    <nav data-testid="sidebar-menu">{children}</nav>
  ),
  SidebarMenuItem: ({ children }: any) => (
    <div data-testid="sidebar-menu-item">{children}</div>
  ),
  SidebarMenuButton: ({ children, asChild, tooltip, ...props }: any) => {
    const Component = asChild ? 'span' : 'button'
    return (
      <Component 
        data-testid="sidebar-menu-button"
        data-tooltip={tooltip}
        {...props}
      >
        {children}
      </Component>
    )
  },
  SidebarInset: ({ children }: any) => (
    <main data-testid="sidebar-inset" className="sidebar-inset-mock">
      {children}
    </main>
  ),
  SidebarProvider: ({ children }: any) => (
    <div data-testid="sidebar-provider">{children}</div>
  ),
  SidebarRail: ({ children }: any) => (
    <div data-testid="sidebar-rail">{children}</div>
  ),
  SidebarTrigger: (props: any) => (
    <button data-testid="sidebar-trigger" {...props}>
      Toggle Sidebar
    </button>
  ),
  useSidebar: () => ({
    state: 'expanded',
    open: true,
    setOpen: vi.fn(),
    isMobile: false,
    openMobile: false,
    setOpenMobile: vi.fn(),
    toggleSidebar: vi.fn(),
  }),
}))

// Note: Header is rendered inline in DashboardLayout, not as a separate component

// Mock other UI components
vi.mock('@/components/ui/button', () => ({
  Button: ({ children, ...props }: any) => (
    <button data-testid="button" {...props}>{children}</button>
  ),
}))

vi.mock('@/components/ui/input', () => ({
  Input: (props: any) => <input data-testid="input" {...props} />,
}))

vi.mock('@/components/ui/separator', () => ({
  Separator: (props: any) => <hr data-testid="separator" {...props} />,
}))

// Mock Next.js router
vi.mock('next/navigation', () => ({
  usePathname: () => '/dashboard',
}))

describe('Responsive Layout Tests', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    // Reset to desktop size by default
    setViewportSize(breakpoints.desktop.width, breakpoints.desktop.height)
  })

  afterEach(() => {
    // Clean up any viewport changes
    setViewportSize(breakpoints.desktop.width, breakpoints.desktop.height)
  })

  describe('Desktop Layout (≥1024px)', () => {
    it('renders full desktop layout with expanded sidebar', () => {
      setViewportSize(breakpoints.desktop.width, breakpoints.desktop.height)

      const { getByTestId, container } = render(
        <DashboardLayout>
          <div data-testid="main-content">Dashboard Content</div>
        </DashboardLayout>
      )

      // Desktop layout should show all components
      expect(getByTestId('sidebar-provider')).toBeInTheDocument()
      expect(getByTestId('sidebar')).toBeInTheDocument()
      expect(getByTestId('sidebar-content')).toBeInTheDocument()
      expect(getByTestId('sidebar-inset')).toBeInTheDocument()
      
      // Check for inline header element
      const header = container.querySelector('header')
      expect(header).toBeInTheDocument()
      expect(getByTestId('main-content')).toBeInTheDocument()
    })

    it('displays sidebar menu items in desktop layout', () => {
      setViewportSize(breakpoints.desktop.width, breakpoints.desktop.height)

      const { getAllByTestId } = render(
        <DashboardLayout>
          <div>Content</div>
        </DashboardLayout>
      )

      // Should have navigation menu items
      const menuButtons = getAllByTestId('sidebar-menu-button')
      expect(menuButtons.length).toBeGreaterThan(0)
      
      // Should have multiple menu items for dashboard, campaigns, content, etc.
      expect(menuButtons.length).toBeGreaterThanOrEqual(4)
    })

    it('shows header with search functionality on desktop', () => {
      setViewportSize(breakpoints.desktop.width, breakpoints.desktop.height)

      const { container } = render(
        <DashboardLayout>
          <div>Content</div>
        </DashboardLayout>
      )

      const header = container.querySelector('header')
      expect(header).toBeInTheDocument()
      
      // Check for search input
      const searchInput = container.querySelector('input[type="search"]')
      expect(searchInput).toBeInTheDocument()
      expect(searchInput).toHaveAttribute('placeholder', 'Search...')
    })
  })

  describe('Tablet Layout (768px - 1023px)', () => {
    it('renders collapsible sidebar for tablet screens', () => {
      setViewportSize(breakpoints.tablet.width, breakpoints.tablet.height)

      const { getByTestId } = render(
        <DashboardLayout>
          <div data-testid="main-content">Tablet Content</div>
        </DashboardLayout>
      )

      // Tablet should still show sidebar but potentially in collapsed state
      expect(getByTestId('sidebar')).toBeInTheDocument()
      expect(getByTestId('sidebar-content')).toBeInTheDocument()
      expect(getByTestId('main-content')).toBeInTheDocument()
    })

    it('provides sidebar toggle functionality on tablets', () => {
      setViewportSize(breakpoints.tablet.width, breakpoints.tablet.height)

      const { getByTestId } = render(
        <DashboardLayout>
          <div>Content</div>
        </DashboardLayout>
      )

      // Should have trigger button for collapsing/expanding
      expect(getByTestId('sidebar-trigger')).toBeInTheDocument()
    })

    it('maintains navigation functionality on tablets', () => {
      setViewportSize(breakpoints.tablet.width, breakpoints.tablet.height)

      const { getAllByTestId } = render(
        <DashboardLayout>
          <div>Content</div>
        </DashboardLayout>
      )

      // Navigation should still be available
      const menuButtons = getAllByTestId('sidebar-menu-button')
      expect(menuButtons.length).toBeGreaterThan(0)
    })
  })

  describe('Mobile Layout (<768px)', () => {
    it('adapts layout for mobile screens', () => {
      setViewportSize(breakpoints.mobile.width, breakpoints.mobile.height)

      const { getByTestId } = render(
        <DashboardLayout>
          <div data-testid="mobile-content">Mobile Content</div>
        </DashboardLayout>
      )

      // Mobile should show main content
      expect(getByTestId('mobile-content')).toBeInTheDocument()
      
      // Sidebar should be present but behavior may be different
      expect(getByTestId('sidebar')).toBeInTheDocument()
    })

    it('provides mobile navigation trigger', () => {
      setViewportSize(breakpoints.mobile.width, breakpoints.mobile.height)

      const { getByTestId } = render(
        <DashboardLayout>
          <div>Content</div>
        </DashboardLayout>
      )

      // Mobile should have sidebar trigger for navigation
      expect(getByTestId('sidebar-trigger')).toBeInTheDocument()
    })

    it('maintains essential navigation on mobile', () => {
      setViewportSize(breakpoints.mobile.width, breakpoints.mobile.height)

      const { getAllByTestId } = render(
        <DashboardLayout>
          <div>Content</div>
        </DashboardLayout>
      )

      // Essential navigation items should still be present
      const menuButtons = getAllByTestId('sidebar-menu-button')
      expect(menuButtons.length).toBeGreaterThan(0)
    })

    it('optimizes header for mobile display', () => {
      setViewportSize(breakpoints.mobile.width, breakpoints.mobile.height)

      const { container, getByTestId } = render(
        <DashboardLayout>
          <div>Content</div>
        </DashboardLayout>
      )

      const header = container.querySelector('header')
      expect(header).toBeInTheDocument()
      
      // Check that header still contains sidebar trigger for mobile navigation
      const sidebarTrigger = getByTestId('sidebar-trigger')
      expect(sidebarTrigger).toBeInTheDocument()
    })
  })

  describe('Responsive Behavior Transitions', () => {
    it('adapts when resizing from desktop to mobile', async () => {
      // Start with desktop
      setViewportSize(breakpoints.desktop.width, breakpoints.desktop.height)

      const { getByTestId, rerender } = render(
        <DashboardLayout>
          <div data-testid="responsive-content">Responsive Content</div>
        </DashboardLayout>
      )

      // Verify desktop layout
      expect(getByTestId('sidebar')).toBeInTheDocument()
      expect(getByTestId('responsive-content')).toBeInTheDocument()

      // Resize to mobile
      setViewportSize(breakpoints.mobile.width, breakpoints.mobile.height)
      
      // Force re-render to simulate responsive behavior
      rerender(
        <DashboardLayout>
          <div data-testid="responsive-content">Responsive Content</div>
        </DashboardLayout>
      )

      // Content should still be present after resize
      expect(getByTestId('responsive-content')).toBeInTheDocument()
      expect(getByTestId('sidebar')).toBeInTheDocument()
    })

    it('handles window resize events', async () => {
      const { getByTestId } = render(
        <DashboardLayout>
          <div data-testid="resize-test-content">Resize Test</div>
        </DashboardLayout>
      )

      // Test multiple viewport sizes
      const sizes = [
        breakpoints.desktop,
        breakpoints.tablet,
        breakpoints.mobile,
        breakpoints.ultrawide,
      ]

      for (const size of sizes) {
        setViewportSize(size.width, size.height)
        
        // Content should remain accessible at all sizes
        expect(getByTestId('resize-test-content')).toBeInTheDocument()
        expect(getByTestId('sidebar')).toBeInTheDocument()
      }
    })
  })

  describe('Interactive Sidebar Behavior', () => {
    it('handles sidebar toggle interactions on desktop', async () => {
      setViewportSize(breakpoints.desktop.width, breakpoints.desktop.height)
      const user = userEvent.setup()

      const { getByTestId } = render(
        <DashboardLayout>
          <div>Interactive Content</div>
        </DashboardLayout>
      )

      const trigger = getByTestId('sidebar-trigger')
      expect(trigger).toBeInTheDocument()

      // Should be clickable
      await user.click(trigger)
      
      // Verify button is interactive
      expect(trigger).not.toBeDisabled()
    })

    it('handles sidebar navigation clicks', async () => {
      const user = userEvent.setup()

      const { getAllByTestId } = render(
        <DashboardLayout>
          <div>Navigation Test</div>
        </DashboardLayout>
      )

      const menuButtons = getAllByTestId('sidebar-menu-button')
      
      // Test clicking navigation items
      for (const button of menuButtons.slice(0, 3)) { // Test first 3 items
        await user.click(button)
        expect(button).not.toBeDisabled()
      }
    })

    it('maintains keyboard navigation accessibility', async () => {
      const user = userEvent.setup()

      const { getByTestId, getAllByTestId } = render(
        <DashboardLayout>
          <div>Keyboard Test</div>
        </DashboardLayout>
      )

      // Test tab navigation
      await user.tab()
      
      const focusableElements = [
        getByTestId('sidebar-trigger'),
        ...getAllByTestId('sidebar-menu-button'),
      ]

      // Should be able to focus on interactive elements
      for (const element of focusableElements.slice(0, 3)) {
        expect(element).not.toHaveAttribute('tabindex', '-1')
      }
    })
  })

  describe('Content Area Responsiveness', () => {
    it('adjusts main content area based on sidebar state', () => {
      setViewportSize(breakpoints.desktop.width, breakpoints.desktop.height)

      const { getByTestId } = render(
        <DashboardLayout>
          <div data-testid="content-area">
            <h1>Main Dashboard</h1>
            <p>This content should adapt to sidebar state</p>
          </div>
        </DashboardLayout>
      )

      const contentArea = getByTestId('content-area')
      expect(contentArea).toBeInTheDocument()
      expect(contentArea).toHaveTextContent('Main Dashboard')
      
      const sidebarInset = getByTestId('sidebar-inset')
      expect(sidebarInset).toContainElement(contentArea)
    })

    it('handles long content in responsive layout', () => {
      const longContent = 'Lorem ipsum '.repeat(200)
      
      const { getByTestId } = render(
        <DashboardLayout>
          <div data-testid="long-content">
            <h1>Long Content Test</h1>
            <p>{longContent}</p>
          </div>
        </DashboardLayout>
      )

      expect(getByTestId('long-content')).toBeInTheDocument()
      expect(getByTestId('long-content')).toHaveTextContent('Long Content Test')
    })

    it('maintains proper spacing and layout at different screen sizes', () => {
      const testSizes = [
        { name: 'mobile', ...breakpoints.mobile },
        { name: 'tablet', ...breakpoints.tablet },
        { name: 'desktop', ...breakpoints.desktop }
      ]

      testSizes.forEach(size => {
        setViewportSize(size.width, size.height)

        const { getByTestId, unmount } = render(
          <DashboardLayout>
            <div data-testid={`spacing-test-${size.name}`}>
              <h1>Spacing Test at {size.width}px</h1>
              <div>Content with proper spacing</div>
            </div>
          </DashboardLayout>
        )

        expect(getByTestId(`spacing-test-${size.name}`)).toBeInTheDocument()
        expect(getByTestId('sidebar-inset')).toBeInTheDocument()
        
        // Clean up after each test to avoid multiple elements
        unmount()
      })
    })
  })

  describe('Edge Cases and Browser Compatibility', () => {
    it('handles very small screen sizes gracefully', () => {
      setViewportSize(320, 480) // Very small mobile screen

      const { getByTestId } = render(
        <DashboardLayout>
          <div data-testid="tiny-screen-content">Tiny Screen Content</div>
        </DashboardLayout>
      )

      // Should still render essential components
      expect(getByTestId('tiny-screen-content')).toBeInTheDocument()
      expect(getByTestId('sidebar')).toBeInTheDocument()
    })

    it('handles very wide screen sizes appropriately', () => {
      setViewportSize(2560, 1440) // 4K/wide screen

      const { getByTestId } = render(
        <DashboardLayout>
          <div data-testid="wide-screen-content">Wide Screen Content</div>
        </DashboardLayout>
      )

      expect(getByTestId('wide-screen-content')).toBeInTheDocument()
      expect(getByTestId('sidebar')).toBeInTheDocument()
    })

    it('handles landscape vs portrait orientation', () => {
      // Portrait mobile
      setViewportSize(375, 667)
      const { getByTestId: getByTestIdPortrait, rerender } = render(
        <DashboardLayout>
          <div data-testid="orientation-content">Portrait Content</div>
        </DashboardLayout>
      )
      expect(getByTestIdPortrait('orientation-content')).toBeInTheDocument()

      // Landscape mobile
      setViewportSize(667, 375)
      rerender(
        <DashboardLayout>
          <div data-testid="orientation-content">Landscape Content</div>
        </DashboardLayout>
      )
      expect(getByTestIdPortrait('orientation-content')).toBeInTheDocument()
    })

    it('preserves layout integrity during rapid size changes', () => {
      const { getByTestId, rerender } = render(
        <DashboardLayout>
          <div data-testid="stability-content">Stability Test</div>
        </DashboardLayout>
      )

      // Rapidly change sizes
      const sizes = [320, 768, 1024, 1920, 375, 1440]
      sizes.forEach(width => {
        setViewportSize(width, 800)
        rerender(
          <DashboardLayout>
            <div data-testid="stability-content">Stability Test</div>
          </DashboardLayout>
        )
        expect(getByTestId('stability-content')).toBeInTheDocument()
      })
    })
  })
})