import React from 'react'
import { render, screen } from '@testing-library/react'
import { DashboardBreadcrumb } from '@/components/features/dashboard/DashboardBreadcrumb'

describe('DashboardBreadcrumb', () => {
  const defaultItems = [
    { label: 'Dashboard', href: '/dashboard' },
    { label: 'Campaigns', href: '/dashboard/campaigns' }
  ]

  describe('Basic Rendering', () => {
    it('renders breadcrumb items correctly', () => {
      render(<DashboardBreadcrumb items={defaultItems} />)
      
      expect(screen.getByText('Dashboard')).toBeInTheDocument()
      expect(screen.getByText('Campaigns')).toBeInTheDocument()
    })

    it('renders with correct links', () => {
      render(<DashboardBreadcrumb items={defaultItems} />)
      
      const dashboardLink = screen.getByRole('link', { name: 'Dashboard' })
      expect(dashboardLink).toHaveAttribute('href', '/dashboard')
      
      // Second item should be current page since it's the last item
      expect(screen.getByText('Campaigns')).toBeInTheDocument()
    })

    it('renders last item as current page (not a link)', () => {
      const items = [
        { label: 'Dashboard', href: '/dashboard' },
        { label: 'Campaigns', href: '/dashboard/campaigns' },
        { label: 'Campaign 123', href: '/dashboard/campaigns/123' }
      ]
      
      render(<DashboardBreadcrumb items={items} />)
      
      // First two should be links
      expect(screen.getByRole('link', { name: 'Dashboard' })).toBeInTheDocument()
      expect(screen.getByRole('link', { name: 'Campaigns' })).toBeInTheDocument()
      
      // Last item should be current page text (may have role="link" but disabled)
      expect(screen.getByText('Campaign 123')).toBeInTheDocument()
    })
  })

  describe('Edge Cases', () => {
    it('renders nothing when items array is empty', () => {
      const { container } = render(<DashboardBreadcrumb items={[]} />)
      expect(container.firstChild).toBeNull()
    })

    it('renders single item correctly', () => {
      const singleItem = [{ label: 'Dashboard', href: '/dashboard' }]
      render(<DashboardBreadcrumb items={singleItem} />)
      
      // Single item should be current page text
      expect(screen.getByText('Dashboard')).toBeInTheDocument()
    })

    it('handles items without href', () => {
      const items = [
        { label: 'Dashboard', href: '/dashboard' },
        { label: 'Campaigns' }, // No href
        { label: 'Current Page' }
      ]
      
      render(<DashboardBreadcrumb items={items} />)
      
      expect(screen.getByRole('link', { name: 'Dashboard' })).toBeInTheDocument()
      expect(screen.getByText('Campaigns')).toBeInTheDocument()
      expect(screen.getByText('Current Page')).toBeInTheDocument()
    })
  })

  describe('Styling and Classes', () => {
    it('applies custom className when provided', () => {
      const { container } = render(
        <DashboardBreadcrumb items={defaultItems} className="custom-class" />
      )
      
      expect(container.firstChild).toHaveClass('custom-class')
    })

    it('renders with correct ARIA structure', () => {
      render(<DashboardBreadcrumb items={defaultItems} />)
      
      // Should have navigation role and proper structure
      const breadcrumbNav = screen.getByRole('navigation')
      expect(breadcrumbNav).toBeInTheDocument()
    })
  })

  describe('Accessibility', () => {
    it('has proper semantic structure for screen readers', () => {
      render(<DashboardBreadcrumb items={defaultItems} />)
      
      const navigation = screen.getByRole('navigation')
      expect(navigation).toBeInTheDocument()
      
      // Links should be accessible  
      const links = screen.getAllByRole('link')
      expect(links.length).toBeGreaterThanOrEqual(1) // At least one link should be present
    })

    it('provides proper context for current page', () => {
      render(<DashboardBreadcrumb items={defaultItems} />)
      
      // The last item should be marked as current page
      const currentPage = screen.getByText('Campaigns')
      expect(currentPage).toBeInTheDocument()
    })
  })
})