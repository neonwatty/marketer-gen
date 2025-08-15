import { render, screen, act } from '@testing-library/react'
import * as React from 'react'
import { Label } from '@/components/ui/label'

describe('Label Component', () => {
  describe('Basic Functionality', () => {
    it('renders label text correctly', () => {
      render(<Label>Test Label</Label>)
      const label = screen.getByText('Test Label')
      
      expect(label).toBeInTheDocument()
      expect(label.tagName).toBe('LABEL')
    })

    it('renders with htmlFor attribute', () => {
      render(<Label htmlFor="test-input">Input Label</Label>)
      const label = screen.getByText('Input Label')
      
      expect(label).toHaveAttribute('for', 'test-input')
    })

    it('associates with input element correctly', () => {
      render(
        <div>
          <Label htmlFor="associated-input">Associated Label</Label>
          <input id="associated-input" type="text" />
        </div>
      )
      
      const input = screen.getByLabelText('Associated Label')
      expect(input).toBeInTheDocument()
      expect(input).toHaveAttribute('id', 'associated-input')
    })
  })

  describe('Styling and Classes', () => {
    it('has correct base styling classes', () => {
      render(<Label>Styled Label</Label>)
      const label = screen.getByText('Styled Label')
      
      expect(label).toHaveClass('text-sm', 'font-medium', 'leading-none')
    })

    it('applies custom className', () => {
      render(<Label className="custom-label-class">Custom Label</Label>)
      const label = screen.getByText('Custom Label')
      
      expect(label).toHaveClass('custom-label-class')
    })

    it('has proper peer styling for form validation', () => {
      render(<Label>Validation Label</Label>)
      const label = screen.getByText('Validation Label')
      
      // Should have peer validation styling
      expect(label).toHaveClass('peer-disabled:cursor-not-allowed', 'peer-disabled:opacity-50')
    })
  })

  describe('HTML Attributes', () => {
    it('supports all standard label attributes', () => {
      render(
        <Label 
          htmlFor="test"
          id="label-id"
          title="Label tooltip"
          data-testid="test-label"
        >
          Full Attributes Label
        </Label>
      )
      
      const label = screen.getByTestId('test-label')
      expect(label).toHaveAttribute('for', 'test')
      expect(label).toHaveAttribute('id', 'label-id')
      expect(label).toHaveAttribute('title', 'Label tooltip')
    })

    it('forwards all props correctly', () => {
      render(
        <Label 
          role="presentation"
          aria-hidden="true"
          data-custom="value"
        >
          Props Label
        </Label>
      )
      
      const label = screen.getByText('Props Label')
      expect(label).toHaveAttribute('role', 'presentation')
      expect(label).toHaveAttribute('aria-hidden', 'true')
      expect(label).toHaveAttribute('data-custom', 'value')
    })
  })

  describe('Content Rendering', () => {
    it('renders simple text content', () => {
      render(<Label>Simple Text</Label>)
      expect(screen.getByText('Simple Text')).toBeInTheDocument()
    })

    it('renders complex children content', () => {
      render(
        <Label>
          <span>Complex</span>
          <strong>Content</strong>
        </Label>
      )
      
      expect(screen.getByText('Complex')).toBeInTheDocument()
      expect(screen.getByText('Content')).toBeInTheDocument()
    })

    it('renders with icons or other elements', () => {
      render(
        <Label>
          <span aria-hidden="true">📧</span>
          Email Address
        </Label>
      )
      
      const label = screen.getByText('Email Address')
      expect(label).toBeInTheDocument()
      expect(label).toHaveTextContent('📧Email Address')
    })

    it('handles empty content', () => {
      render(<Label data-testid="empty-label"></Label>)
      const label = screen.getByTestId('empty-label')
      
      expect(label).toBeInTheDocument()
      expect(label).toBeEmptyDOMElement()
    })
  })

  describe('Form Integration', () => {
    it('works with various input types', () => {
      const inputTypes = ['text', 'email', 'password', 'number', 'tel'] as const
      
      inputTypes.forEach(type => {
        const { unmount } = render(
          <div>
            <Label htmlFor={`${type}-input`}>{type} Label</Label>
            <input id={`${type}-input`} type={type} />
          </div>
        )
        
        const input = screen.getByLabelText(`${type} Label`)
        expect(input).toHaveAttribute('type', type)
        
        unmount()
      })
    })

    it('works with textarea elements', () => {
      render(
        <div>
          <Label htmlFor="textarea-input">Textarea Label</Label>
          <textarea id="textarea-input" />
        </div>
      )
      
      const textarea = screen.getByLabelText('Textarea Label')
      expect(textarea.tagName).toBe('TEXTAREA')
    })

    it('works with select elements', () => {
      render(
        <div>
          <Label htmlFor="select-input">Select Label</Label>
          <select id="select-input">
            <option value="1">Option 1</option>
            <option value="2">Option 2</option>
          </select>
        </div>
      )
      
      const select = screen.getByLabelText('Select Label')
      expect(select.tagName).toBe('SELECT')
    })

    it('supports required field indicators', () => {
      render(
        <Label htmlFor="required-input">
          Required Field
          <span aria-hidden="true">*</span>
        </Label>
      )
      
      const label = screen.getByText('Required Field')
      expect(label).toHaveTextContent('Required Field*')
    })
  })

  describe('Accessibility', () => {
    it('provides proper label association', () => {
      render(
        <div>
          <Label htmlFor="accessible-input">Accessible Label</Label>
          <input id="accessible-input" type="text" />
        </div>
      )
      
      const input = screen.getByRole('textbox', { name: 'Accessible Label' })
      expect(input).toBeInTheDocument()
    })

    it('supports aria-describedby for additional context', () => {
      render(
        <div>
          <Label htmlFor="described-input">Input with Description</Label>
          <input 
            id="described-input" 
            type="text"
            aria-describedby="input-description"
          />
          <div id="input-description">Additional help text</div>
        </div>
      )
      
      const input = screen.getByLabelText('Input with Description')
      expect(input).toHaveAttribute('aria-describedby', 'input-description')
    })

    it('works with form validation states', () => {
      render(
        <div>
          <Label htmlFor="invalid-input">Invalid Input</Label>
          <input 
            id="invalid-input" 
            type="text"
            aria-invalid="true"
            aria-describedby="error-message"
          />
          <div id="error-message" role="alert">This field has an error</div>
        </div>
      )
      
      const input = screen.getByLabelText('Invalid Input')
      expect(input).toHaveAttribute('aria-invalid', 'true')
      expect(input).toHaveAttribute('aria-describedby', 'error-message')
    })

    it('supports screen reader only content', () => {
      render(
        <Label htmlFor="sr-input">
          Visible Label
          <span className="sr-only">Additional context for screen readers</span>
        </Label>
      )
      
      const label = screen.getByText('Visible Label')
      expect(label).toBeInTheDocument()
      expect(label).toHaveTextContent('Visible LabelAdditional context for screen readers')
    })
  })

  describe('State Management', () => {
    it('reflects disabled state correctly', () => {
      render(
        <div>
          <Label htmlFor="disabled-input">Disabled Input Label</Label>
          <input id="disabled-input" type="text" disabled />
        </div>
      )
      
      const input = screen.getByLabelText('Disabled Input Label')
      expect(input).toBeDisabled()
      
      // Label should have peer styling for disabled state
      const label = screen.getByText('Disabled Input Label')
      expect(label).toHaveClass('peer-disabled:cursor-not-allowed', 'peer-disabled:opacity-50')
    })

    it('maintains styling with peer validation states', () => {
      render(
        <form>
          <Label htmlFor="peer-input">Peer Input Label</Label>
          <input 
            id="peer-input" 
            type="text" 
            className="peer"
            required
          />
        </form>
      )
      
      const label = screen.getByText('Peer Input Label')
      expect(label).toHaveClass('peer-disabled:cursor-not-allowed', 'peer-disabled:opacity-50')
    })
  })

  describe('Edge Cases', () => {
    it('handles special characters in content', () => {
      render(<Label>Label with special chars: @#$%^&*()</Label>)
      const label = screen.getByText('Label with special chars: @#$%^&*()')
      
      expect(label).toBeInTheDocument()
    })

    it('handles very long label text', () => {
      const longText = 'This is a very long label text that might wrap to multiple lines and should still work correctly'
      render(<Label>{longText}</Label>)
      
      const label = screen.getByText(longText)
      expect(label).toBeInTheDocument()
    })

    it('handles numeric content', () => {
      render(<Label>{42}</Label>)
      const label = screen.getByText('42')
      
      expect(label).toBeInTheDocument()
    })

    it('handles conditional content', () => {
      const showOptional = true
      render(
        <Label>
          Required Field
          {showOptional && <span> (Optional)</span>}
        </Label>
      )
      
      const label = screen.getAllByText((content, element) => {
        return element && element.textContent === 'Required Field (Optional)'
      })[0] // Take the first one
      expect(label).toBeInTheDocument()
    })
  })

  describe('Integration with Form Libraries', () => {
    it('works with controlled components', () => {
      const TestForm = () => {
        const [value, setValue] = React.useState('')
        
        return (
          <div>
            <Label htmlFor="controlled-input">Controlled Input</Label>
            <input 
              id="controlled-input"
              type="text"
              value={value}
              onChange={(e) => setValue(e.target.value)}
            />
          </div>
        )
      }
      
      render(<TestForm />)
      const input = screen.getByLabelText('Controlled Input')
      expect(input).toBeInTheDocument()
    })

    it('maintains association during dynamic updates', () => {
      const DynamicForm = () => {
        const [fieldName, setFieldName] = React.useState('initial')
        
        return (
          <div>
            <button onClick={() => setFieldName('updated')}>
              Update Field
            </button>
            <Label htmlFor={`${fieldName}-input`}>{fieldName} Label</Label>
            <input id={`${fieldName}-input`} type="text" />
          </div>
        )
      }
      
      render(<DynamicForm />)
      
      // Initial state
      expect(screen.getByLabelText('initial Label')).toBeInTheDocument()
      
      // After update
      const button = screen.getByRole('button', { name: 'Update Field' })
      act(() => {
        button.click()
      })
      
      expect(screen.getByLabelText('updated Label')).toBeInTheDocument()
    })
  })

  describe('Ref Forwarding', () => {
    it('forwards ref correctly', () => {
      const ref = React.createRef<HTMLLabelElement>()
      render(<Label ref={ref}>Ref Label</Label>)
      
      expect(ref.current).toBeInstanceOf(HTMLLabelElement)
      expect(ref.current).toHaveTextContent('Ref Label')
    })

    it('allows focusing through ref', () => {
      const ref = React.createRef<HTMLLabelElement>()
      render(<Label ref={ref} tabIndex={0}>Focusable Label</Label>)
      
      ref.current?.focus()
      expect(ref.current).toHaveFocus()
    })
  })
})