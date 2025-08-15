import { render, screen } from '@testing-library/react'
import * as React from 'react'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'

describe('Alert Components', () => {
  describe('Alert Container', () => {
    it('renders alert with description', () => {
      render(
        <Alert>
          <AlertDescription>This is an alert message</AlertDescription>
        </Alert>
      )
      
      expect(screen.getByText('This is an alert message')).toBeInTheDocument()
    })

    it('renders complete alert structure', () => {
      render(
        <Alert>
          <AlertTitle>Alert Title</AlertTitle>
          <AlertDescription>Alert description content</AlertDescription>
        </Alert>
      )
      
      expect(screen.getByText('Alert Title')).toBeInTheDocument()
      expect(screen.getByText('Alert description content')).toBeInTheDocument()
    })

    it('renders without title', () => {
      render(
        <Alert>
          <AlertDescription>Description only alert</AlertDescription>
        </Alert>
      )
      
      expect(screen.getByText('Description only alert')).toBeInTheDocument()
    })

    it('accepts custom className', () => {
      render(
        <Alert className="custom-alert" data-testid="alert">
          <AlertDescription>Custom alert</AlertDescription>
        </Alert>
      )
      
      const alert = screen.getByTestId('alert')
      expect(alert).toHaveClass('custom-alert')
    })
  })

  describe('Alert Variants', () => {
    it('renders default alert', () => {
      render(
        <Alert data-testid="alert">
          <AlertDescription>Default alert</AlertDescription>
        </Alert>
      )
      
      const alert = screen.getByTestId('alert')
      expect(alert).toHaveClass('border')
    })

    it('renders destructive alert', () => {
      render(
        <Alert variant="destructive" data-testid="alert">
          <AlertDescription>Error alert</AlertDescription>
        </Alert>
      )
      
      const alert = screen.getByTestId('alert')
      expect(alert).toHaveClass('text-destructive')
    })

    it('applies correct styling for default variant', () => {
      render(
        <Alert data-testid="alert">
          <AlertDescription>Default styling</AlertDescription>
        </Alert>
      )
      
      const alert = screen.getByTestId('alert')
      expect(alert).toHaveClass('bg-card', 'text-card-foreground')
    })

    it('applies correct styling for destructive variant', () => {
      render(
        <Alert variant="destructive" data-testid="alert">
          <AlertDescription>Destructive styling</AlertDescription>
        </Alert>
      )
      
      const alert = screen.getByTestId('alert')
      expect(alert).toHaveClass('text-destructive', 'bg-card')
    })
  })

  describe('AlertTitle Component', () => {
    it('renders as div', () => {
      render(<AlertTitle>Alert Title</AlertTitle>)
      const title = screen.getByText('Alert Title')
      
      expect(title).toBeInTheDocument()
      expect(title.tagName).toBe('DIV')
    })

    it('has correct typography classes', () => {
      render(<AlertTitle>Title</AlertTitle>)
      const title = screen.getByText('Title')
      
      expect(title).toHaveClass('font-medium', 'tracking-tight')
    })

    it('accepts custom className', () => {
      render(<AlertTitle className="custom-title">Title</AlertTitle>)
      const title = screen.getByText('Title')
      
      expect(title).toHaveClass('custom-title')
    })

    it('renders as div by default', () => {
      render(<AlertTitle>Default Title</AlertTitle>)
      const title = screen.getByText('Default Title')
      
      expect(title.tagName).toBe('DIV')
    })
  })

  describe('AlertDescription Component', () => {
    it('renders description text', () => {
      render(<AlertDescription>Alert description content</AlertDescription>)
      const description = screen.getByText('Alert description content')
      
      expect(description).toBeInTheDocument()
    })

    it('has correct typography', () => {
      render(<AlertDescription>Description</AlertDescription>)
      const description = screen.getByText('Description')
      
      expect(description).toHaveClass('text-sm', '[&_p]:leading-relaxed')
    })

    it('renders as div by default', () => {
      render(<AlertDescription>Description text</AlertDescription>)
      const description = screen.getByText('Description text')
      
      expect(description.tagName).toBe('DIV')
    })

    it('accepts custom className', () => {
      render(<AlertDescription className="custom-desc">Description</AlertDescription>)
      const description = screen.getByText('Description')
      
      expect(description).toHaveClass('custom-desc')
    })

    it('can contain rich content', () => {
      render(
        <AlertDescription>
          <p>Paragraph content</p>
          <a href="/link">Link content</a>
          <strong>Bold content</strong>
        </AlertDescription>
      )
      
      expect(screen.getByText('Paragraph content')).toBeInTheDocument()
      expect(screen.getByRole('link', { name: 'Link content' })).toBeInTheDocument()
      expect(screen.getByText('Bold content')).toBeInTheDocument()
    })
  })

  describe('Accessibility', () => {
    it('has proper ARIA role by default', () => {
      render(
        <Alert data-testid="alert">
          <AlertDescription>Alert message</AlertDescription>
        </Alert>
      )
      
      const alert = screen.getByTestId('alert')
      expect(alert).toHaveAttribute('role', 'alert')
    })

    it('supports custom ARIA roles', () => {
      render(
        <Alert role="status" data-testid="alert">
          <AlertDescription>Status message</AlertDescription>
        </Alert>
      )
      
      const alert = screen.getByTestId('alert')
      expect(alert).toHaveAttribute('role', 'status')
    })

    it('can be found by role', () => {
      render(
        <Alert>
          <AlertDescription>Important message</AlertDescription>
        </Alert>
      )
      
      const alert = screen.getByRole('alert')
      expect(alert).toBeInTheDocument()
    })

    it('supports aria-labelledby when title is present', () => {
      render(
        <Alert aria-labelledby="alert-title">
          <AlertTitle id="alert-title">Important Alert</AlertTitle>
          <AlertDescription>This is important information</AlertDescription>
        </Alert>
      )
      
      const alert = screen.getByRole('alert')
      const title = screen.getByText('Important Alert')
      
      expect(alert).toHaveAttribute('aria-labelledby', 'alert-title')
      expect(title).toHaveAttribute('id', 'alert-title')
    })

    it('supports aria-describedby', () => {
      render(
        <Alert aria-describedby="alert-desc">
          <AlertDescription id="alert-desc">
            Detailed alert description
          </AlertDescription>
        </Alert>
      )
      
      const alert = screen.getByRole('alert')
      expect(alert).toHaveAttribute('aria-describedby', 'alert-desc')
    })
  })

  describe('Layout and Structure', () => {
    it('has correct layout classes', () => {
      render(
        <Alert data-testid="alert">
          <AlertDescription>Layout test</AlertDescription>
        </Alert>
      )
      
      const alert = screen.getByTestId('alert')
      expect(alert).toHaveClass('relative', 'w-full', 'rounded-lg', 'border', 'px-4', 'py-3')
    })

    it('maintains proper spacing between title and description', () => {
      render(
        <Alert>
          <AlertTitle>Title</AlertTitle>
          <AlertDescription>Description</AlertDescription>
        </Alert>
      )
      
      const title = screen.getByText('Title')
      expect(title).toHaveClass('col-start-2')
    })

    it('can contain icons', () => {
      render(
        <Alert>
          <div data-testid="alert-icon">🚨</div>
          <AlertTitle>Alert with Icon</AlertTitle>
          <AlertDescription>This alert has an icon</AlertDescription>
        </Alert>
      )
      
      expect(screen.getByTestId('alert-icon')).toBeInTheDocument()
      expect(screen.getByText('Alert with Icon')).toBeInTheDocument()
    })
  })

  describe('Integration', () => {
    it('works within forms', () => {
      render(
        <form>
          <Alert>
            <AlertDescription>
              Please correct the errors below
            </AlertDescription>
          </Alert>
          <input type="text" aria-invalid="true" />
          <button type="submit">Submit</button>
        </form>
      )
      
      expect(screen.getByText('Please correct the errors below')).toBeInTheDocument()
      expect(screen.getByRole('textbox')).toHaveAttribute('aria-invalid', 'true')
    })

    it('can be used for success messages', () => {
      render(
        <Alert role="status">
          <AlertTitle>Success!</AlertTitle>
          <AlertDescription>Your changes have been saved</AlertDescription>
        </Alert>
      )
      
      const alert = screen.getByRole('status')
      expect(alert).toBeInTheDocument()
      expect(screen.getByText('Success!')).toBeInTheDocument()
    })

    it('can be used for error messages', () => {
      render(
        <Alert variant="destructive">
          <AlertTitle>Error</AlertTitle>
          <AlertDescription>Something went wrong</AlertDescription>
        </Alert>
      )
      
      const alert = screen.getByRole('alert')
      expect(alert).toBeInTheDocument()
      expect(screen.getByText('Error')).toBeInTheDocument()
    })
  })

  describe('Ref Forwarding', () => {
    it('forwards ref correctly', () => {
      const ref = React.createRef<HTMLDivElement>()
      render(
        <Alert ref={ref}>
          <AlertDescription>Ref test</AlertDescription>
        </Alert>
      )
      
      expect(ref.current).toBeInstanceOf(HTMLDivElement)
      expect(ref.current).toHaveTextContent('Ref test')
    })
  })
})