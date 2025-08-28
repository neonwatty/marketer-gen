import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Input } from '@/components/ui/input'
import * as React from 'react'

describe('Input Component', () => {
  describe('Basic Functionality', () => {
    it('renders input element', () => {
      render(<Input placeholder="Enter text" />)
      const input = screen.getByPlaceholderText('Enter text')

      expect(input).toBeInTheDocument()
      expect(input.tagName).toBe('INPUT')
    })

    it('accepts user input', async () => {
      const user = userEvent.setup()
      render(<Input placeholder="Type here" />)
      const input = screen.getByPlaceholderText('Type here')

      await user.type(input, 'Hello World')
      expect(input).toHaveValue('Hello World')
    })

    it('handles controlled input', async () => {
      const user = userEvent.setup()
      const TestComponent = () => {
        const [value, setValue] = React.useState('')
        return (
          <Input
            value={value}
            onChange={e => setValue(e.target.value)}
            placeholder="Controlled input"
          />
        )
      }

      render(<TestComponent />)
      const input = screen.getByPlaceholderText('Controlled input')

      await user.type(input, 'test')
      expect(input).toHaveValue('test')
    })

    it('handles uncontrolled input with defaultValue', () => {
      render(<Input defaultValue="Initial value" data-testid="input" />)
      const input = screen.getByTestId('input')

      expect(input).toHaveValue('Initial value')
    })

    it('clears input value', async () => {
      const user = userEvent.setup()
      render(<Input defaultValue="Clear me" data-testid="input" />)
      const input = screen.getByTestId('input')

      await user.clear(input)
      expect(input).toHaveValue('')
    })
  })

  describe('Props and Attributes', () => {
    it('forwards all input props', () => {
      render(
        <Input
          type="email"
          required
          disabled
          placeholder="Email"
          data-testid="test-input"
          maxLength={50}
          minLength={5}
        />
      )
      const input = screen.getByTestId('test-input')

      expect(input).toHaveAttribute('type', 'email')
      expect(input).toHaveAttribute('required')
      expect(input).toBeDisabled()
      expect(input).toHaveAttribute('placeholder', 'Email')
      expect(input).toHaveAttribute('maxlength', '50')
      expect(input).toHaveAttribute('minlength', '5')
    })

    it('applies custom className', () => {
      render(<Input className="custom-class" data-testid="input" />)
      const input = screen.getByTestId('input')

      expect(input).toHaveClass('custom-class')
    })

    it('supports different input types', () => {
      const inputTypes = ['text', 'email', 'password', 'number', 'tel', 'url'] as const

      inputTypes.forEach(type => {
        const { unmount } = render(<Input type={type} data-testid={`${type}-input`} />)
        const input = screen.getByTestId(`${type}-input`)

        expect(input).toHaveAttribute('type', type)
        unmount()
      })
    })

    it('supports ARIA attributes', () => {
      render(
        <Input
          aria-label="Custom label"
          aria-describedby="help-text"
          aria-invalid="true"
          data-testid="input"
        />
      )
      const input = screen.getByTestId('input')

      expect(input).toHaveAttribute('aria-label', 'Custom label')
      expect(input).toHaveAttribute('aria-describedby', 'help-text')
      expect(input).toHaveAttribute('aria-invalid', 'true')
    })
  })

  describe('Styling', () => {
    it('has correct base classes', () => {
      render(<Input data-testid="input" />)
      const input = screen.getByTestId('input')

      // Input component should have some basic styling classes
      expect(input).toHaveClass('flex', 'h-9', 'w-full', 'rounded-md', 'border')
    })

    it('shows focus styles', async () => {
      const user = userEvent.setup()
      render(<Input data-testid="input" />)
      const input = screen.getByTestId('input')

      // Check that focus-related CSS classes are present
      const className = input.className
      expect(className).toMatch(/focus-visible/)
    })

    it('has disabled styling when disabled', () => {
      render(<Input disabled data-testid="input" />)
      const input = screen.getByTestId('input')

      // Check basic disabled properties
      expect(input).toBeDisabled()
      const className = input.className
      expect(className).toMatch(/disabled/)
    })

    it('has invalid styling classes', () => {
      render(<Input aria-invalid="true" data-testid="input" />)
      const input = screen.getByTestId('input')

      // Check that aria-invalid classes are applied
      expect(input).toHaveAttribute('aria-invalid', 'true')
      const className = input.className
      expect(className).toMatch(/aria-invalid/)
    })
  })

  describe('Events', () => {
    it('triggers onChange event', async () => {
      const user = userEvent.setup()
      const handleChange = jest.fn()

      render(<Input onChange={handleChange} data-testid="input" />)
      const input = screen.getByTestId('input')

      await user.type(input, 'a')
      expect(handleChange).toHaveBeenCalledTimes(1)
    })

    it('triggers onFocus event', async () => {
      const user = userEvent.setup()
      const handleFocus = jest.fn()

      render(<Input onFocus={handleFocus} data-testid="input" />)
      const input = screen.getByTestId('input')

      await user.click(input)
      expect(handleFocus).toHaveBeenCalledTimes(1)
    })

    it('triggers onBlur event', async () => {
      const user = userEvent.setup()
      const handleBlur = jest.fn()

      render(
        <div>
          <Input onBlur={handleBlur} data-testid="input" />
          <button>Other element</button>
        </div>
      )
      const input = screen.getByTestId('input')
      const button = screen.getByRole('button')

      await user.click(input)
      await user.click(button)
      expect(handleBlur).toHaveBeenCalledTimes(1)
    })

    it('triggers onKeyDown event', async () => {
      const user = userEvent.setup()
      const handleKeyDown = jest.fn()

      render(<Input onKeyDown={handleKeyDown} data-testid="input" />)
      const input = screen.getByTestId('input')

      await user.click(input)
      await user.keyboard('{Enter}')
      expect(handleKeyDown).toHaveBeenCalledTimes(1)
    })
  })

  describe('Accessibility', () => {
    it('is focusable', async () => {
      const user = userEvent.setup()
      render(<Input data-testid="input" />)
      const input = screen.getByTestId('input')

      await user.tab()
      expect(input).toHaveFocus()
    })

    it('works with labels', () => {
      render(
        <div>
          <label htmlFor="test-input">Input Label</label>
          <Input id="test-input" />
        </div>
      )

      const input = screen.getByLabelText('Input Label')
      expect(input).toBeInTheDocument()
    })

    it('supports screen reader descriptions', () => {
      render(
        <div>
          <Input aria-describedby="help-text" data-testid="input" />
          <div id="help-text">This input needs help text</div>
        </div>
      )

      const input = screen.getByTestId('input')
      expect(input).toHaveAttribute('aria-describedby', 'help-text')
    })

    it('announces validation errors', () => {
      render(<Input aria-invalid="true" aria-describedby="error" data-testid="input" />)
      const input = screen.getByTestId('input')

      expect(input).toHaveAttribute('aria-invalid', 'true')
      expect(input).toHaveAttribute('aria-describedby', 'error')
    })
  })

  describe('Form Integration', () => {
    it('submits with form', async () => {
      const user = userEvent.setup()
      const handleSubmit = jest.fn(e => e.preventDefault())

      render(
        <form onSubmit={handleSubmit}>
          <Input name="username" data-testid="input" />
          <button type="submit">Submit</button>
        </form>
      )

      const input = screen.getByTestId('input')
      const submitButton = screen.getByRole('button', { name: 'Submit' })

      await user.type(input, 'testuser')
      await user.click(submitButton)

      expect(handleSubmit).toHaveBeenCalledTimes(1)
    })

    it('supports form validation', () => {
      render(
        <form>
          <Input required pattern="[a-zA-Z]+" data-testid="input" />
        </form>
      )

      const input = screen.getByTestId('input')
      expect(input).toHaveAttribute('required')
      expect(input).toHaveAttribute('pattern', '[a-zA-Z]+')
    })
  })

  describe('Ref Forwarding', () => {
    it('forwards ref correctly', () => {
      const ref = React.createRef<HTMLInputElement>()
      render(<Input ref={ref} />)

      expect(ref.current).toBeInstanceOf(HTMLInputElement)
    })

    it('allows calling focus through ref', () => {
      const ref = React.createRef<HTMLInputElement>()
      render(<Input ref={ref} />)

      ref.current?.focus()
      expect(ref.current).toHaveFocus()
    })
  })
})
