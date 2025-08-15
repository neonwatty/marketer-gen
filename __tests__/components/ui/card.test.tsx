import { render, screen } from '@testing-library/react'
import * as React from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'

describe('Card Components', () => {
  describe('Card Structure', () => {
    it('renders complete card structure', () => {
      render(
        <Card data-testid="test-card">
          <CardHeader>
            <CardTitle>Test Title</CardTitle>
            <CardDescription>Test Description</CardDescription>
          </CardHeader>
          <CardContent>
            <p>Test Content</p>
          </CardContent>
        </Card>
      )

      expect(screen.getByTestId('test-card')).toBeInTheDocument()
      expect(screen.getByText('Test Title')).toBeInTheDocument()
      expect(screen.getByText('Test Description')).toBeInTheDocument()
      expect(screen.getByText('Test Content')).toBeInTheDocument()
    })

    it('applies correct CSS classes', () => {
      render(<Card className="custom-class">Content</Card>)
      const card = screen.getByText('Content')

      expect(card).toHaveClass('custom-class')
      expect(card).toHaveClass('bg-card', 'text-card-foreground', 'flex', 'flex-col')
    })

    it('can render without header or content', () => {
      render(<Card>Simple card</Card>)
      expect(screen.getByText('Simple card')).toBeInTheDocument()
    })

    it('forwards ref correctly', () => {
      const ref = React.createRef<HTMLDivElement>()
      render(<Card ref={ref}>Card with ref</Card>)

      expect(ref.current).toBeInstanceOf(HTMLDivElement)
      expect(ref.current).toHaveTextContent('Card with ref')
    })
  })

  describe('CardHeader Component', () => {
    it('renders correctly', () => {
      render(<CardHeader data-testid="card-header">Header content</CardHeader>)
      const header = screen.getByTestId('card-header')

      expect(header).toBeInTheDocument()
      expect(header).toHaveTextContent('Header content')
    })

    it('applies correct spacing classes', () => {
      render(<CardHeader data-testid="header">Content</CardHeader>)
      const header = screen.getByTestId('header')

      expect(header).toHaveClass('grid', 'px-6', 'gap-1.5')
    })

    it('accepts custom className', () => {
      render(<CardHeader className="custom-header">Content</CardHeader>)
      const header = screen.getByText('Content')

      expect(header).toHaveClass('custom-header')
    })
  })

  describe('CardTitle Component', () => {
    it('renders with correct styling', () => {
      render(<CardTitle>Title Text</CardTitle>)
      const title = screen.getByText('Title Text')

      expect(title).toBeInTheDocument()
      expect(title.tagName).toBe('DIV')
    })

    it('has correct typography classes', () => {
      render(<CardTitle>Title</CardTitle>)
      const title = screen.getByText('Title')

      expect(title).toHaveClass('font-semibold', 'leading-none')
    })

    it('renders as div by default', () => {
      render(<CardTitle>Default Title</CardTitle>)
      const title = screen.getByText('Default Title')

      expect(title.tagName).toBe('DIV')
    })

    it('accepts custom className', () => {
      render(<CardTitle className="custom-title">Title</CardTitle>)
      const title = screen.getByText('Title')

      expect(title).toHaveClass('custom-title')
    })
  })

  describe('CardDescription Component', () => {
    it('has muted styling', () => {
      render(<CardDescription>Description text</CardDescription>)
      const description = screen.getByText('Description text')

      expect(description).toBeInTheDocument()
      expect(description).toHaveClass('text-muted-foreground')
    })

    it('has correct typography', () => {
      render(<CardDescription>Description</CardDescription>)
      const description = screen.getByText('Description')

      expect(description).toHaveClass('text-sm')
    })

    it('renders as div by default', () => {
      render(<CardDescription>Description text</CardDescription>)
      const description = screen.getByText('Description text')

      expect(description.tagName).toBe('DIV')
    })

    it('accepts custom className', () => {
      render(<CardDescription className="custom-desc">Description</CardDescription>)
      const description = screen.getByText('Description')

      expect(description).toHaveClass('custom-desc')
    })
  })

  describe('CardContent Component', () => {
    it('renders content correctly', () => {
      render(<CardContent>Card content here</CardContent>)
      const content = screen.getByText('Card content here')

      expect(content).toBeInTheDocument()
    })

    it('has correct padding', () => {
      render(<CardContent data-testid="content">Content</CardContent>)
      const content = screen.getByTestId('content')

      expect(content).toHaveClass('px-6')
    })

    it('can contain complex content', () => {
      render(
        <CardContent>
          <div>
            <h4>Nested heading</h4>
            <p>Nested paragraph</p>
            <button>Nested button</button>
          </div>
        </CardContent>
      )

      expect(screen.getByText('Nested heading')).toBeInTheDocument()
      expect(screen.getByText('Nested paragraph')).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Nested button' })).toBeInTheDocument()
    })

    it('accepts custom className', () => {
      render(<CardContent className="custom-content">Content</CardContent>)
      const content = screen.getByText('Content')

      expect(content).toHaveClass('custom-content')
    })
  })

  describe('Accessibility', () => {
    it('maintains proper semantic structure', () => {
      render(
        <Card role="article" aria-labelledby="card-title">
          <CardHeader>
            <CardTitle id="card-title">Accessible Card Title</CardTitle>
            <CardDescription>Card description for screen readers</CardDescription>
          </CardHeader>
          <CardContent>
            <p>Accessible content</p>
          </CardContent>
        </Card>
      )

      const article = screen.getByRole('article')
      expect(article).toHaveAttribute('aria-labelledby', 'card-title')

      const title = screen.getByText('Accessible Card Title')
      expect(title).toHaveAttribute('id', 'card-title')
    })

    it('supports ARIA attributes', () => {
      render(
        <Card aria-describedby="card-description" data-testid="test-card">
          <CardContent id="card-description">This card has proper ARIA relationships</CardContent>
        </Card>
      )

      const card = screen.getByTestId('test-card')
      expect(card).toHaveAttribute('aria-describedby', 'card-description')
    })
  })

  describe('Integration', () => {
    it('works with form elements', () => {
      render(
        <Card>
          <CardHeader>
            <CardTitle>Form Card</CardTitle>
          </CardHeader>
          <CardContent>
            <form>
              <label htmlFor="test-input">Test Input</label>
              <input id="test-input" type="text" />
              <button type="submit">Submit</button>
            </form>
          </CardContent>
        </Card>
      )

      expect(screen.getByLabelText('Test Input')).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Submit' })).toBeInTheDocument()
    })

    it('can be nested', () => {
      render(
        <Card>
          <CardContent>
            <Card>
              <CardHeader>
                <CardTitle>Nested Card</CardTitle>
              </CardHeader>
            </Card>
          </CardContent>
        </Card>
      )

      expect(screen.getByText('Nested Card')).toBeInTheDocument()
    })
  })
})
