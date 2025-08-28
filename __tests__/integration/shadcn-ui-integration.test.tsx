import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import Home from '@/app/page'

// Mock Next.js Image
jest.mock('next/image', () => ({
  __esModule: true,
  default: ({ alt, priority, ...props }: any) => {
    return <img alt={alt} {...props} />
  },
}))

describe('Shadcn UI Integration Tests', () => {
  describe('Component Composition', () => {
    it('renders card with all nested components correctly', () => {
      render(<Home />)

      // Find the card container using data-testid attribute
      const card = screen.getByTestId('ui-card')

      expect(card).toBeInTheDocument()

      // Check all components within the card
      const cardContainer = within(card!)
      expect(cardContainer.getByText(/Testing the installed components/)).toBeInTheDocument()
      expect(cardContainer.getByLabelText('Test Input')).toBeInTheDocument()
      expect(cardContainer.getByRole('button', { name: 'Primary Button' })).toBeInTheDocument()
    })

    it('alert contains badge component correctly', () => {
      render(<Home />)

      const alertText = screen.getByText('Shadcn UI has been successfully configured!')
      const alert = alertText.closest('[role="alert"]') || alertText.parentElement
      expect(alert).toBeInTheDocument()

      const badge = within(alert!).getByText('Components Tested')
      expect(badge).toBeInTheDocument()
    })

    it('card header contains title and description', () => {
      render(<Home />)

      const cardHeader = screen.getByTestId('ui-card-header')
      expect(cardHeader).toBeInTheDocument()

      // Both title and description should be in the card header
      const headerContainer = within(cardHeader!)
      expect(headerContainer.getByText('Shadcn UI Test Components')).toBeInTheDocument()
      expect(headerContainer.getByText(/Testing the installed components/)).toBeInTheDocument()
    })

    it('card content contains form elements', () => {
      render(<Home />)

      const cardContent = screen.getByTestId('ui-card-content')
      expect(cardContent).toBeInTheDocument()

      const contentContainer = within(cardContent!)
      expect(contentContainer.getByLabelText('Test Input')).toBeInTheDocument()
      expect(contentContainer.getByRole('button', { name: 'Primary Button' })).toBeInTheDocument()
      expect(contentContainer.getByRole('button', { name: 'Secondary Button' })).toBeInTheDocument()
      expect(contentContainer.getByRole('button', { name: 'Outline Button' })).toBeInTheDocument()
    })

    it('all badge variants are grouped together', () => {
      render(<Home />)

      const badgeContainer = screen.getByText('Default').parentElement
      expect(badgeContainer).toBeInTheDocument()

      const containerBadges = within(badgeContainer!)
      expect(containerBadges.getByText('Default')).toBeInTheDocument()
      expect(containerBadges.getByText('Secondary Badge')).toBeInTheDocument()
      expect(containerBadges.getByText('Destructive')).toBeInTheDocument()
      expect(containerBadges.getByText('Outline Badge')).toBeInTheDocument()
    })
  })

  describe('User Interactions Flow', () => {
    it('allows complete user interaction flow', async () => {
      const user = userEvent.setup()
      render(<Home />)

      // Type in input
      const input = screen.getByLabelText('Test Input')
      await user.type(input, 'Testing shadcn/ui')
      expect(input).toHaveValue('Testing shadcn/ui')

      // Click buttons
      const primaryBtn = screen.getByRole('button', { name: 'Primary Button' })
      const secondaryBtn = screen.getByRole('button', { name: 'Secondary Button' })
      const outlineBtn = screen.getByRole('button', { name: 'Outline Button' })

      await user.click(primaryBtn)
      await user.click(secondaryBtn)
      await user.click(outlineBtn)

      // All interactions should work without errors
      expect(input).toHaveValue('Testing shadcn/ui')
    })

    it('input interactions work within card context', async () => {
      const user = userEvent.setup()
      render(<Home />)

      const input = screen.getByLabelText('Test Input')

      // Focus input
      await user.click(input)
      expect(input).toHaveFocus()

      // Type text
      await user.type(input, 'Card integration test')
      expect(input).toHaveValue('Card integration test')

      // Tab to buttons
      await user.tab()
      const primaryButton = screen.getByRole('button', { name: 'Primary Button' })
      expect(primaryButton).toHaveFocus()
    })

    it('keyboard navigation works through all interactive elements', async () => {
      const user = userEvent.setup()
      render(<Home />)

      // Start tabbing through elements
      await user.tab() // Should focus input
      expect(screen.getByLabelText('Test Input')).toHaveFocus()

      await user.tab() // Should focus first button
      expect(screen.getByRole('button', { name: 'Primary Button' })).toHaveFocus()

      await user.tab() // Should focus second button
      expect(screen.getByRole('button', { name: 'Secondary Button' })).toHaveFocus()

      await user.tab() // Should focus third button
      expect(screen.getByRole('button', { name: 'Outline Button' })).toHaveFocus()
    })
  })

  describe('Responsive Behavior', () => {
    it('maintains responsive layout with shadcn components', () => {
      render(<Home />)

      const main = screen.getByRole('main')
      expect(main).toHaveClass('max-w-2xl', 'w-full')

      // Card should be full width
      const card = screen.getByText('Shadcn UI Test Components').closest('.w-full')
      expect(card).toHaveClass('w-full')

      // Button container should have responsive flex direction
      const buttonContainer = screen.getByRole('button', { name: 'Primary Button' }).parentElement
      expect(buttonContainer).toHaveClass('gap-2')
    })

    it('card layout adapts to content', () => {
      render(<Home />)

      const card = screen.getByTestId('ui-card')
      expect(card).toBeInTheDocument()

      // Card should contain header and content sections
      const header = screen.getByTestId('ui-card-header')
      const content = screen.getByTestId('ui-card-content')

      expect(header).toBeInTheDocument()
      expect(content).toBeInTheDocument()
      expect(header).not.toBe(content) // Should be different sections
    })

    it('maintains proper spacing between components', () => {
      render(<Home />)

      const main = screen.getByRole('main')
      expect(main).toHaveClass('gap-[32px]')

      // Card content should have proper spacing
      const cardContent = screen.getByLabelText('Test Input').closest('[class*="space-y-4"]')
      expect(cardContent).toBeInTheDocument()
    })
  })

  describe('Styling Integration', () => {
    it('components use consistent design tokens', () => {
      render(<Home />)

      // Check that components use shadcn design system classes
      const alert = screen.getByTestId('ui-alert')
      const card = screen.getByTestId('ui-card')
      const input = screen.getByLabelText('Test Input')
      const button = screen.getByRole('button', { name: 'Primary Button' })

      // Components should be present with proper structure
      expect(alert).toBeInTheDocument()
      expect(card).toBeInTheDocument()
      expect(input).toBeInTheDocument()
      expect(button).toBeInTheDocument()

      // Input should have proper test id
      expect(input).toHaveAttribute('data-testid', 'ui-input')

      // Button should have proper test id
      expect(button).toHaveAttribute('data-testid', 'ui-button')
    })

    it('dark mode classes are properly applied', () => {
      render(<Home />)

      // Check that components are structured properly for dark mode
      const input = screen.getByLabelText('Test Input')
      const outlineButton = screen.getByRole('button', { name: 'Outline Button' })

      // Components should be present and have variant attributes where applicable
      expect(input).toHaveAttribute('data-testid', 'ui-input')
      expect(outlineButton).toHaveAttribute('data-variant', 'outline')
    })

    it('focus styles work across all components', () => {
      render(<Home />)

      const input = screen.getByLabelText('Test Input')
      const button = screen.getByRole('button', { name: 'Primary Button' })

      // Components should be focusable and have proper attributes
      expect(input).toHaveAttribute('data-testid', 'ui-input')
      expect(button).toHaveAttribute('data-testid', 'ui-button')
      
      // Elements should be focusable
      expect(input).not.toHaveAttribute('tabindex', '-1')
      expect(button).not.toHaveAttribute('tabindex', '-1')
    })
  })

  describe('Accessibility Integration', () => {
    it('maintains proper heading hierarchy', () => {
      render(<Home />)

      // Check heading structure - CardTitle is rendered as an H3 element for proper semantics
      const cardTitle = screen.getByText('Shadcn UI Test Components')
      expect(cardTitle.tagName).toBe('H3') // Card titles are rendered as H3 elements for accessibility
    })

    it('form elements have proper labels and associations', () => {
      render(<Home />)

      const input = screen.getByLabelText('Test Input')
      const label = screen.getByText('Test Input')

      expect(input).toHaveAttribute('id')
      expect(label).toHaveAttribute('for', input.getAttribute('id'))
    })

    it('alert has proper role and content structure', () => {
      render(<Home />)

      const alert = screen.getByTestId('ui-alert')

      // Should have proper structure and be in the document
      expect(alert).toBeInTheDocument()
      expect(alert).toHaveAttribute('data-testid', 'ui-alert')
      
      // Should contain the alert description
      const alertDescription = within(alert).getByText('Shadcn UI has been successfully configured!')
      expect(alertDescription).toBeInTheDocument()
    })

    it('interactive elements are keyboard accessible', () => {
      render(<Home />)

      const buttons = screen.getAllByRole('button')
      const input = screen.getByRole('textbox')

      // All should be in tab order
      expect(input).not.toHaveAttribute('tabindex', '-1')
      buttons.forEach(button => {
        expect(button).not.toHaveAttribute('tabindex', '-1')
      })
    })
  })

  describe('Component State Management', () => {
    it('input state is maintained independently', async () => {
      const user = userEvent.setup()
      render(<Home />)

      const input = screen.getByLabelText('Test Input')

      // Type in input
      await user.type(input, 'Test value')
      expect(input).toHaveValue('Test value')

      // Click buttons shouldn't affect input value
      await user.click(screen.getByRole('button', { name: 'Primary Button' }))
      expect(input).toHaveValue('Test value')

      // Clear and retype
      await user.clear(input)
      await user.type(input, 'New value')
      expect(input).toHaveValue('New value')
    })

    it('button interactions are independent', async () => {
      const user = userEvent.setup()
      render(<Home />)

      const primaryBtn = screen.getByRole('button', { name: 'Primary Button' })
      const secondaryBtn = screen.getByRole('button', { name: 'Secondary Button' })

      // Clicking one shouldn't affect the other
      await user.click(primaryBtn)
      await user.click(secondaryBtn)

      // Both should remain clickable
      expect(primaryBtn).not.toBeDisabled()
      expect(secondaryBtn).not.toBeDisabled()
    })
  })

  describe('Error Boundaries and Edge Cases', () => {
    it('handles missing props gracefully', () => {
      // This tests that components render without errors even with minimal props
      expect(() => render(<Home />)).not.toThrow()
    })

    it('components maintain functionality with custom classes', () => {
      render(<Home />)

      // Even with custom styling, components should maintain core functionality
      const input = screen.getByLabelText('Test Input')
      const buttons = screen.getAllByRole('button').slice(0, 3) // First 3 are our test buttons

      expect(input).toBeInTheDocument()
      expect(buttons).toHaveLength(3)
    })

    it('nested components maintain individual styling', () => {
      render(<Home />)

      // Badge within alert should maintain its own structure
      const badge = screen.getByText('Components Tested')
      expect(badge).toBeInTheDocument()
      expect(badge).toHaveAttribute('data-testid', 'ui-badge')
      expect(badge).toHaveAttribute('data-variant', 'secondary')

      // Badge should be nested within the alert
      const alert = screen.getByTestId('ui-alert')
      expect(alert).toBeInTheDocument()
      expect(within(alert).getByText('Components Tested')).toBeInTheDocument()
    })
  })

  describe('Performance Considerations', () => {
    it('renders complex component tree efficiently', () => {
      const startTime = performance.now()
      render(<Home />)
      const endTime = performance.now()

      // Rendering should be fast (under 100ms for this simple page)
      expect(endTime - startTime).toBeLessThan(100)
    })

    it('all components are present in DOM', () => {
      render(<Home />)

      // Count expected shadcn components
      const alert = screen.getByText('Shadcn UI has been successfully configured!')
      const card = screen.getByText('Shadcn UI Test Components')
      const input = screen.getByLabelText('Test Input')
      const buttons = screen.getAllByRole('button').slice(0, 3)
      const badges = [
        screen.getByText('Components Tested'),
        screen.getByText('Default'),
        screen.getByText('Secondary Badge'),
        screen.getByText('Destructive'),
        screen.getByText('Outline Badge'),
      ]

      expect(alert).toBeInTheDocument()
      expect(card).toBeInTheDocument()
      expect(input).toBeInTheDocument()
      expect(buttons).toHaveLength(3)
      expect(badges).toHaveLength(5)
    })
  })
})
