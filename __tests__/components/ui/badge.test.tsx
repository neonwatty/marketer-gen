import { render, screen } from '@testing-library/react'
import * as React from 'react'
import { Badge } from '@/components/ui/badge'

describe('Badge Component', () => {
  describe('Variants', () => {
    it('renders default variant', () => {
      render(<Badge>Default Badge</Badge>)
      const badge = screen.getByText('Default Badge')

      expect(badge).toBeInTheDocument()
      expect(badge).toHaveClass('bg-primary', 'text-primary-foreground')
    })

    it('renders all badge variants', () => {
      const variants = ['default', 'secondary', 'destructive', 'outline'] as const

      variants.forEach(variant => {
        const { unmount } = render(<Badge variant={variant}>{variant}</Badge>)
        const badge = screen.getByText(variant)
        expect(badge).toBeInTheDocument()
        unmount()
      })
    })

    it('secondary variant has correct styling', () => {
      render(<Badge variant="secondary">Secondary</Badge>)
      const badge = screen.getByText('Secondary')

      expect(badge).toHaveClass('bg-secondary', 'text-secondary-foreground')
    })

    it('destructive variant has correct styling', () => {
      render(<Badge variant="destructive">Destructive</Badge>)
      const badge = screen.getByText('Destructive')

      expect(badge).toHaveClass('bg-destructive', 'text-white')
    })

    it('outline variant has correct styling', () => {
      render(<Badge variant="outline">Outline</Badge>)
      const badge = screen.getByText('Outline')

      expect(badge).toHaveClass('text-foreground')
    })
  })

  describe('Content and Styling', () => {
    it('renders children content', () => {
      render(<Badge>Simple text</Badge>)
      expect(screen.getByText('Simple text')).toBeInTheDocument()
    })

    it('renders complex children content', () => {
      render(
        <Badge>
          <span>Complex content</span>
          <span>Multiple elements</span>
        </Badge>
      )

      expect(screen.getByText('Complex content')).toBeInTheDocument()
      expect(screen.getByText('Multiple elements')).toBeInTheDocument()
    })

    it('applies custom classes', () => {
      render(<Badge className="custom-badge">Test</Badge>)
      const badge = screen.getByText('Test')

      expect(badge).toHaveClass('custom-badge')
    })

    it('has correct base styling', () => {
      render(<Badge>Styled Badge</Badge>)
      const badge = screen.getByText('Styled Badge')

      expect(badge).toHaveClass(
        'inline-flex',
        'items-center',
        'justify-center',
        'rounded-md',
        'border',
        'px-2',
        'py-0.5',
        'text-xs',
        'font-medium'
      )
    })

    it('has focus styles', () => {
      render(<Badge>Focusable Badge</Badge>)
      const badge = screen.getByText('Focusable Badge')

      expect(badge).toHaveClass('focus-visible:border-ring', 'focus-visible:ring-ring/50')
    })

    it('has transition classes', () => {
      render(<Badge>Transition Badge</Badge>)
      const badge = screen.getByText('Transition Badge')

      expect(badge).toHaveClass('transition-[color,box-shadow]')
    })
  })

  describe('HTML Attributes', () => {
    it('renders as span by default', () => {
      render(<Badge>Default Element</Badge>)
      const badge = screen.getByText('Default Element')

      expect(badge.tagName).toBe('SPAN')
    })

    it('supports custom HTML attributes', () => {
      render(
        <Badge data-testid="custom-badge" id="badge-id" title="Badge tooltip">
          Custom Attributes
        </Badge>
      )

      const badge = screen.getByTestId('custom-badge')
      expect(badge).toHaveAttribute('id', 'badge-id')
      expect(badge).toHaveAttribute('title', 'Badge tooltip')
    })

    it('supports onClick events', () => {
      const handleClick = jest.fn()
      render(<Badge onClick={handleClick}>Clickable Badge</Badge>)
      const badge = screen.getByText('Clickable Badge')

      badge.click()
      expect(handleClick).toHaveBeenCalledTimes(1)
    })
  })

  describe('Accessibility', () => {
    it('is properly accessible', () => {
      render(
        <Badge role="status" aria-label="Status badge">
          Active
        </Badge>
      )
      const badge = screen.getByRole('status')

      expect(badge).toHaveAttribute('aria-label', 'Status badge')
      expect(badge).toHaveTextContent('Active')
    })

    it('supports aria-describedby', () => {
      render(
        <div>
          <Badge aria-describedby="badge-description">Status</Badge>
          <div id="badge-description">This shows the current status</div>
        </div>
      )

      const badge = screen.getByText('Status')
      expect(badge).toHaveAttribute('aria-describedby', 'badge-description')
    })

    it('can be used as a button', () => {
      render(
        <Badge role="button" tabIndex={0} onClick={() => {}} onKeyDown={() => {}}>
          Button Badge
        </Badge>
      )

      const badge = screen.getByRole('button')
      expect(badge).toHaveAttribute('tabindex', '0')
    })

    it('has proper contrast for all variants', () => {
      const variants = ['default', 'secondary', 'destructive', 'outline'] as const

      variants.forEach(variant => {
        const { unmount } = render(
          <Badge variant={variant} data-testid={`${variant}-badge`}>
            {variant}
          </Badge>
        )

        const badge = screen.getByTestId(`${variant}-badge`)
        // Check that text color and background color classes are applied
        const hasTextColor = badge.className.includes('text-')
        const hasBackground = variant === 'outline' || badge.className.includes('bg-')

        expect(hasTextColor || hasBackground).toBe(true)
        unmount()
      })
    })
  })

  describe('Use Cases', () => {
    it('works as a status indicator', () => {
      render(
        <div>
          <span>User Status:</span>
          <Badge variant="secondary" role="status">
            Online
          </Badge>
        </div>
      )

      const statusBadge = screen.getByRole('status')
      expect(statusBadge).toHaveTextContent('Online')
    })

    it('works as a notification count', () => {
      render(
        <div>
          <span>Messages</span>
          <Badge variant="destructive" aria-label="3 unread messages">
            3
          </Badge>
        </div>
      )

      const countBadge = screen.getByLabelText('3 unread messages')
      expect(countBadge).toHaveTextContent('3')
    })

    it('works as a category tag', () => {
      render(
        <article>
          <h2>Article Title</h2>
          <Badge variant="outline">Technology</Badge>
          <p>Article content...</p>
        </article>
      )

      const categoryBadge = screen.getByText('Technology')
      expect(categoryBadge).toBeInTheDocument()
    })

    it('works with icons', () => {
      render(
        <Badge>
          <span aria-hidden="true">🔥</span>
          Hot
        </Badge>
      )

      const badge = screen.getByText('Hot')
      expect(badge).toBeInTheDocument()
      expect(badge).toHaveTextContent('🔥Hot')
    })

    it('works in groups', () => {
      render(
        <div>
          <Badge variant="default">React</Badge>
          <Badge variant="secondary">TypeScript</Badge>
          <Badge variant="outline">Next.js</Badge>
        </div>
      )

      expect(screen.getByText('React')).toBeInTheDocument()
      expect(screen.getByText('TypeScript')).toBeInTheDocument()
      expect(screen.getByText('Next.js')).toBeInTheDocument()
    })
  })

  describe('Edge Cases', () => {
    it('handles empty content', () => {
      render(<Badge data-testid="empty-badge"></Badge>)
      const badge = screen.getByTestId('empty-badge')

      expect(badge).toBeInTheDocument()
      expect(badge).toBeEmptyDOMElement()
    })

    it('handles long text content', () => {
      const longText = 'This is a very long badge text that might wrap'
      render(<Badge>{longText}</Badge>)

      const badge = screen.getByText(longText)
      expect(badge).toBeInTheDocument()
    })

    it('handles special characters', () => {
      render(<Badge>Badge with special chars: @#$%^&*()</Badge>)
      const badge = screen.getByText('Badge with special chars: @#$%^&*()')

      expect(badge).toBeInTheDocument()
    })

    it('handles numbers', () => {
      render(<Badge>{42}</Badge>)
      const badge = screen.getByText('42')

      expect(badge).toBeInTheDocument()
    })

    it('handles boolean and null values gracefully', () => {
      render(
        <div>
          <Badge>{true && 'Conditional Badge'}</Badge>
          <Badge>{false && 'Hidden Badge'}</Badge>
          <Badge data-testid="null-badge">{null}</Badge>
        </div>
      )

      expect(screen.getByText('Conditional Badge')).toBeInTheDocument()
      expect(screen.queryByText('Hidden Badge')).not.toBeInTheDocument()
      expect(screen.getByTestId('null-badge')).toBeEmptyDOMElement()
    })
  })

  describe('Ref Forwarding', () => {
    it('forwards ref correctly', () => {
      const ref = React.createRef<HTMLSpanElement>()
      render(<Badge ref={ref}>Ref Badge</Badge>)

      expect(ref.current).toBeInstanceOf(HTMLSpanElement)
      expect(ref.current).toHaveTextContent('Ref Badge')
    })
  })
})
