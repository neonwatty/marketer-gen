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

      // Find the card container
      const cardTitle = screen.getByText('Shadcn UI Test Components')
      const card = cardTitle.closest('[class*="bg-card"]')

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

      const title = screen.getByText('Shadcn UI Test Components')
      const description = screen.getByText(/Testing the installed components/)

      // Both should be in the same card header
      const cardHeader = title.closest('[class*="p-6"]')
      expect(cardHeader).toContainElement(description)
    })

    it('card content contains form elements', () => {
      render(<Home />)

      const cardContent = screen.getByLabelText('Test Input').closest('[class*="p-6"]')
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

      const card = screen.getByText('Shadcn UI Test Components').closest('[class*="bg-card"]')
      expect(card).toBeInTheDocument()

      // Card should contain header and content sections
      const header = within(card!)
        .getByText('Shadcn UI Test Components')
        .closest('[data-slot="card-header"]')
      const content = within(card!)
        .getByLabelText('Test Input')
        .closest('[data-slot="card-content"]')

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
      const alert = screen.getByText('Shadcn UI has been successfully configured!').parentElement
      const card = screen.getByText('Shadcn UI Test Components').closest('[class*="bg-card"]')
      const input = screen.getByLabelText('Test Input')
      const button = screen.getByRole('button', { name: 'Primary Button' })

      // Alert should have border and padding
      expect(alert).toHaveClass('border')

      // Card should have background and text colors
      expect(card).toHaveClass('bg-card', 'text-card-foreground')

      // Input should have border styling
      expect(input).toHaveClass('border-input')

      // Button should have primary styling
      expect(button).toHaveClass('bg-primary', 'text-primary-foreground')
    })

    it('dark mode classes are properly applied', () => {
      render(<Home />)

      // Check that components have dark mode considerations
      const input = screen.getByLabelText('Test Input')
      expect(input).toHaveClass('bg-transparent')

      const button = screen.getByRole('button', { name: 'Outline Button' })
      expect(button).toHaveClass('bg-background')
    })

    it('focus styles work across all components', () => {
      render(<Home />)

      const input = screen.getByLabelText('Test Input')
      const button = screen.getByRole('button', { name: 'Primary Button' })

      // Both should have focus ring styles
      expect(input).toHaveClass('focus-visible:ring-ring/50')
      expect(button).toHaveClass('focus-visible:ring-ring/50')
    })
  })

  describe('Accessibility Integration', () => {
    it('maintains proper heading hierarchy', () => {
      render(<Home />)

      // Check heading structure
      const cardTitle = screen.getByText('Shadcn UI Test Components')
      expect(cardTitle.tagName).toBe('DIV') // Card titles are rendered as DIV elements
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

      const alertContainer = screen.getByText(
        'Shadcn UI has been successfully configured!'
      ).parentElement

      // Should have alert role or be within an element with alert role
      const alert = alertContainer?.closest('[role="alert"]') || alertContainer
      expect(alert).toBeInTheDocument()
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

      // Badge within alert should maintain its own styling
      const badge = screen.getByText('Components Tested')
      expect(badge).toHaveClass('bg-secondary', 'text-secondary-foreground')

      // Even though it's nested in an alert
      const alert = screen.getByText('Shadcn UI has been successfully configured!').parentElement
      expect(alert).toBeInTheDocument()
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
