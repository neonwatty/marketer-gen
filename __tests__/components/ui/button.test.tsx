import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import * as React from 'react'

// Unmock the button component for this test
jest.unmock('@/components/ui/button')
import { Button } from '@/components/ui/button'

describe('Button Component', () => {
  describe('Rendering', () => {
    it('renders with default variant', () => {
      render(<Button>Click me</Button>)
      const button = screen.getByRole('button', { name: 'Click me' })
      expect(button).toBeInTheDocument()
      expect(button).toHaveClass('bg-primary', 'text-primary-foreground', 'inline-flex')
    })

    it('renders all variants correctly', () => {
      const variants = ['default', 'destructive', 'outline', 'secondary', 'ghost', 'link'] as const

      variants.forEach(variant => {
        const { unmount } = render(<Button variant={variant}>{variant} button</Button>)
        const button = screen.getByRole('button', { name: `${variant} button` })
        expect(button).toBeInTheDocument()
        unmount()
      })
    })

    it('renders all sizes correctly', () => {
      const sizes = ['default', 'sm', 'lg', 'icon'] as const

      sizes.forEach(size => {
        const { unmount } = render(<Button size={size}>{size} button</Button>)
        const button = screen.getByRole('button', { name: `${size} button` })
        expect(button).toBeInTheDocument()
        unmount()
      })
    })

    it('renders with custom className', () => {
      render(<Button className="custom-class">Custom Button</Button>)
      const button = screen.getByRole('button', { name: 'Custom Button' })
      expect(button).toHaveClass('custom-class')
    })
  })

  describe('Functionality', () => {
    it('handles click events', async () => {
      const user = userEvent.setup()
      const handleClick = jest.fn()

      render(<Button onClick={handleClick}>Click me</Button>)
      const button = screen.getByRole('button', { name: 'Click me' })

      await user.click(button)
      expect(handleClick).toHaveBeenCalledTimes(1)
    })

    it('is disabled when disabled prop is true', () => {
      render(<Button disabled>Disabled button</Button>)
      const button = screen.getByRole('button', { name: 'Disabled button' })

      expect(button).toBeDisabled()
      expect(button).toHaveClass('disabled:pointer-events-none', 'disabled:opacity-50')
    })

    it('can be used with different HTML elements', () => {
      render(<Button type="submit">Submit Button</Button>)
      const button = screen.getByRole('button', { name: 'Submit Button' })

      expect(button).toHaveAttribute('type', 'submit')
    })

    it('prevents click when disabled', async () => {
      const user = userEvent.setup()
      const handleClick = jest.fn()

      render(
        <Button disabled onClick={handleClick}>
          Disabled button
        </Button>
      )
      const button = screen.getByRole('button', { name: 'Disabled button' })

      await user.click(button)
      expect(handleClick).not.toHaveBeenCalled()
    })
  })

  describe('Accessibility', () => {
    it('has proper focus styles', () => {
      render(<Button>Focus me</Button>)
      const button = screen.getByRole('button', { name: 'Focus me' })

      expect(button).toHaveClass('focus-visible:ring-ring/50', 'focus-visible:ring-[3px]')
    })

    it('supports aria attributes', () => {
      render(
        <Button aria-label="Custom aria label" aria-describedby="description">
          Button
        </Button>
      )

      const button = screen.getByRole('button', { name: 'Custom aria label' })
      expect(button).toHaveAttribute('aria-describedby', 'description')
    })

    it('maintains semantic button role', () => {
      render(<Button>Semantic button</Button>)
      const button = screen.getByRole('button')
      expect(button).toBeInTheDocument()
    })

    it('renders as button element by default', () => {
      render(<Button>Default type</Button>)
      const button = screen.getByRole('button')
      expect(button.tagName).toBe('BUTTON')
    })

    it('allows custom button type', () => {
      render(<Button type="submit">Submit button</Button>)
      const button = screen.getByRole('button')
      expect(button).toHaveAttribute('type', 'submit')
    })
  })

  describe('Variant Specific Tests', () => {
    it('destructive variant has correct styling', () => {
      render(<Button variant="destructive">Destructive</Button>)
      const button = screen.getByRole('button')
      expect(button).toHaveClass('bg-destructive', 'text-white', 'shadow-xs')
    })

    it('outline variant has border', () => {
      render(<Button variant="outline">Outline</Button>)
      const button = screen.getByRole('button')
      expect(button).toHaveClass('border', 'bg-background', 'shadow-xs')
    })

    it('ghost variant has hover styles', () => {
      render(<Button variant="ghost">Ghost</Button>)
      const button = screen.getByRole('button')
      expect(button).toHaveClass('hover:bg-accent', 'hover:text-accent-foreground')
    })

    it('link variant looks like a link', () => {
      render(<Button variant="link">Link</Button>)
      const button = screen.getByRole('button')
      expect(button).toHaveClass('text-primary', 'underline-offset-4', 'hover:underline')
    })
  })

  describe('Size Variants', () => {
    it('sm size has correct dimensions', () => {
      render(<Button size="sm">Small</Button>)
      const button = screen.getByRole('button')
      expect(button).toHaveClass('h-8', 'px-3')
    })

    it('lg size has correct dimensions', () => {
      render(<Button size="lg">Large</Button>)
      const button = screen.getByRole('button')
      expect(button).toHaveClass('h-10', 'px-6')
    })

    it('icon size is square', () => {
      render(<Button size="icon">🔥</Button>)
      const button = screen.getByRole('button')
      expect(button).toHaveClass('size-9')
    })
  })
})
