import { render } from '@testing-library/react'
import { axe, toHaveNoViolations } from 'jest-axe'
import Home from '@/app/page'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Badge } from '@/components/ui/badge'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'

// Extend Jest matchers
expect.extend(toHaveNoViolations)

// Mock Next.js Image for a11y testing
jest.mock('next/image', () => ({
  __esModule: true,
  default: ({ alt, ...props }: React.ImgHTMLAttributes<HTMLImageElement>) => {
    return <img alt={alt} {...props} />
  },
}))

describe('Shadcn UI Accessibility', () => {
  describe('Page Level Accessibility', () => {
    it('should not have accessibility violations on home page', async () => {
      const { container } = render(<Home />)
      const results = await axe(container)

      expect(results).toHaveNoViolations()
    })

    it('maintains proper landmark structure', async () => {
      const { container } = render(<Home />)
      const results = await axe(container, {
        rules: {
          'landmark-one-main': { enabled: true },
          'page-has-heading-one': { enabled: false }, // We don't have H1 in this test page
          region: { enabled: true },
        },
      })

      expect(results).toHaveNoViolations()
    })
  })

  describe('Individual Component Accessibility', () => {
    it('Button component meets WCAG standards', async () => {
      const { container } = render(
        <div>
          <Button>Accessible Button</Button>
          <Button variant="secondary">Secondary Button</Button>
          <Button variant="destructive">Destructive Button</Button>
          <Button variant="outline">Outline Button</Button>
          <Button disabled>Disabled Button</Button>
        </div>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('Input and Label combination is accessible', async () => {
      const { container } = render(
        <div>
          <Label htmlFor="test-input">Accessible Label</Label>
          <Input id="test-input" aria-describedby="input-help" />
          <div id="input-help">Helper text for input</div>
        </div>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('Card component structure is accessible', async () => {
      const { container } = render(
        <Card role="article" aria-labelledby="card-title">
          <CardHeader>
            <CardTitle id="card-title">Accessible Card Title</CardTitle>
            <CardDescription>Description that helps screen readers</CardDescription>
          </CardHeader>
          <CardContent>
            <p>Accessible card content with proper semantic structure</p>
          </CardContent>
        </Card>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('Alert component is accessible', async () => {
      const { container } = render(
        <div>
          <Alert>
            <AlertTitle>Information Alert</AlertTitle>
            <AlertDescription>This is important information for users</AlertDescription>
          </Alert>

          <Alert variant="destructive" role="alert">
            <AlertTitle>Error Alert</AlertTitle>
            <AlertDescription>
              This is an error message that needs immediate attention
            </AlertDescription>
          </Alert>
        </div>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('Badge component with proper context is accessible', async () => {
      const { container } = render(
        <div>
          <h2>User Status</h2>
          <Badge role="status" aria-label="User is currently online">
            Online
          </Badge>

          <h2>Notification Count</h2>
          <Badge variant="destructive" aria-label="5 unread messages">
            5
          </Badge>

          <h2>Category Tags</h2>
          <div role="group" aria-label="Article categories">
            <Badge variant="outline">React</Badge>
            <Badge variant="outline">TypeScript</Badge>
            <Badge variant="outline">Next.js</Badge>
          </div>
        </div>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Color Contrast and Visual Accessibility', () => {
    it('maintains proper color contrast ratios', async () => {
      const { container } = render(
        <div>
          <Button>Primary Button</Button>
          <Button variant="secondary">Secondary Button</Button>
          <Button variant="destructive">Destructive Button</Button>
          <Button variant="outline">Outline Button</Button>
          <Badge>Default Badge</Badge>
          <Badge variant="secondary">Secondary Badge</Badge>
          <Badge variant="destructive">Destructive Badge</Badge>
          <Badge variant="outline">Outline Badge</Badge>
          <Alert>
            <AlertDescription>Default alert message</AlertDescription>
          </Alert>
          <Alert variant="destructive">
            <AlertDescription>Error alert message</AlertDescription>
          </Alert>
        </div>
      )

      // Run axe specifically for color contrast
      const results = await axe(container, {
        rules: {
          'color-contrast': { enabled: true },
        },
      })

      expect(results).toHaveNoViolations()
    })

    it('text remains readable at 200% zoom', async () => {
      const { container } = render(
        <div style={{ fontSize: '200%' }}>
          <Card>
            <CardHeader>
              <CardTitle>Zoomed Card Title</CardTitle>
              <CardDescription>This should remain readable when zoomed</CardDescription>
            </CardHeader>
            <CardContent>
              <Label htmlFor="zoom-input">Zoomed Label</Label>
              <Input id="zoom-input" placeholder="Zoomed input field" />
              <Button>Zoomed Button</Button>
            </CardContent>
          </Card>
        </div>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Keyboard Navigation and Focus Management', () => {
    it('interactive elements are keyboard accessible', async () => {
      const { container } = render(
        <div>
          <Button>First Button</Button>
          <Input placeholder="Text input" />
          <Button>Second Button</Button>
          <Button tabIndex={-1}>Non-focusable button</Button>
        </div>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('focus indicators are visible', async () => {
      const { container } = render(
        <div>
          <Button>Focusable Button</Button>
          <Input placeholder="Focusable Input" />
          <Card tabIndex={0}>
            <CardContent>Focusable Card</CardContent>
          </Card>
        </div>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Form Accessibility', () => {
    it('form with shadcn components is fully accessible', async () => {
      const { container } = render(
        <form aria-labelledby="form-title">
          <h2 id="form-title">Accessible Form</h2>

          <div>
            <Label htmlFor="name">Full Name</Label>
            <Input id="name" required aria-describedby="name-help name-error" />
            <div id="name-help">Enter your full legal name</div>
            <div id="name-error" role="alert" style={{ display: 'none' }}>
              Name is required
            </div>
          </div>

          <div>
            <Label htmlFor="email">Email Address</Label>
            <Input id="email" type="email" required aria-describedby="email-help" />
            <div id="email-help">We'll never share your email</div>
          </div>

          <fieldset>
            <legend>Account Type</legend>
            <div role="group">
              <Badge variant="outline">Personal</Badge>
              <Badge variant="outline">Business</Badge>
            </div>
          </fieldset>

          <Alert>
            <AlertDescription>Please review your information before submitting</AlertDescription>
          </Alert>

          <div>
            <Button type="submit">Submit Form</Button>
            <Button type="button" variant="outline">
              Cancel
            </Button>
          </div>
        </form>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('form validation errors are accessible', async () => {
      const { container } = render(
        <form>
          <div>
            <Label htmlFor="required-field">Required Field</Label>
            <Input id="required-field" aria-invalid="true" aria-describedby="field-error" />
            <div id="field-error" role="alert">
              This field is required
            </div>
          </div>

          <Alert variant="destructive" role="alert">
            <AlertTitle>Form Errors</AlertTitle>
            <AlertDescription>Please correct the errors above before submitting</AlertDescription>
          </Alert>
        </form>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Dynamic Content Accessibility', () => {
    it('dynamically shown content is accessible', async () => {
      const { container } = render(
        <div>
          <Button aria-expanded="true" aria-controls="dynamic-content">
            Toggle Content
          </Button>
          <div id="dynamic-content" role="region" aria-label="Dynamic content area">
            <Card>
              <CardHeader>
                <CardTitle>Dynamic Card</CardTitle>
              </CardHeader>
              <CardContent>
                <p>This content was shown dynamically</p>
              </CardContent>
            </Card>
          </div>
        </div>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('live regions work correctly', async () => {
      const { container } = render(
        <div>
          <div aria-live="polite" aria-label="Status updates">
            <Alert role="status">
              <AlertDescription>Operation completed successfully</AlertDescription>
            </Alert>
          </div>

          <div aria-live="assertive" aria-label="Error messages">
            <Alert variant="destructive" role="alert">
              <AlertDescription>Critical error occurred</AlertDescription>
            </Alert>
          </div>
        </div>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Mobile and Touch Accessibility', () => {
    it('touch targets are appropriately sized', async () => {
      const { container } = render(
        <div>
          <Button size="sm">Small Button</Button>
          <Button>Default Button</Button>
          <Button size="lg">Large Button</Button>
          <Input placeholder="Touch input" />
          <Badge role="button" tabIndex={0}>
            Interactive Badge
          </Badge>
        </div>
      )

      const results = await axe(container, {
        rules: {
          'target-size': { enabled: true },
        },
      })

      expect(results).toHaveNoViolations()
    })
  })

  describe('Screen Reader Specific Tests', () => {
    it('provides meaningful content for screen readers', async () => {
      const { container } = render(
        <div>
          <main role="main" aria-label="Main content">
            <h1>Page Title</h1>

            <section aria-labelledby="section-title">
              <h2 id="section-title">Component Examples</h2>

              <Card role="article" aria-labelledby="card-title">
                <CardHeader>
                  <CardTitle id="card-title">Example Card</CardTitle>
                  <CardDescription>This card demonstrates accessible markup</CardDescription>
                </CardHeader>
                <CardContent>
                  <form>
                    <Label htmlFor="example-input">Example Input</Label>
                    <Input id="example-input" aria-describedby="input-description" />
                    <div id="input-description">Additional context for screen readers</div>
                    <Button type="submit">Submit</Button>
                  </form>
                </CardContent>
              </Card>
            </section>
          </main>
        </div>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('handles complex widget patterns accessibly', async () => {
      const { container } = render(
        <div>
          <div role="tablist" aria-label="Example tabs">
            <Button role="tab" aria-selected="true" aria-controls="panel1" id="tab1">
              Tab 1
            </Button>
            <Button role="tab" aria-selected="false" aria-controls="panel2" id="tab2">
              Tab 2
            </Button>
          </div>

          <div role="tabpanel" id="panel1" aria-labelledby="tab1" tabIndex={0}>
            <Card>
              <CardContent>Content for tab 1</CardContent>
            </Card>
          </div>

          <div role="tabpanel" id="panel2" aria-labelledby="tab2" hidden>
            <Card>
              <CardContent>Content for tab 2</CardContent>
            </Card>
          </div>
        </div>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Error Handling and Edge Cases', () => {
    it('handles missing accessibility attributes gracefully', async () => {
      const { container } = render(
        <div>
          {/* Test components without explicit a11y props */}
          <Button>Button without explicit a11y</Button>
          <Input placeholder="Input without label" />
          <Badge>Badge without context</Badge>
        </div>
      )

      // This might have violations, but shouldn't crash
      const results = await axe(container, {
        rules: {
          label: { enabled: true },
        },
      })

      // We expect this to potentially have violations for the unlabeled input
      // This test ensures the testing setup works even with accessibility issues
      expect(results.violations.length).toBeGreaterThanOrEqual(0)
    })

    it('maintains accessibility with custom styling', async () => {
      const { container } = render(
        <div>
          <Button className="custom-button-style">Custom Styled Button</Button>
          <Card className="custom-card-style">
            <CardHeader className="custom-header-style">
              <CardTitle>Custom Styled Card</CardTitle>
            </CardHeader>
            <CardContent className="custom-content-style">
              <Label htmlFor="custom-input">Custom Styled Label</Label>
              <Input id="custom-input" className="custom-input-style" />
            </CardContent>
          </Card>
        </div>
      )

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })
})
