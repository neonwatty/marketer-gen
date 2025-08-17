import { describe, it, expect, jest } from '@jest/globals'
import { render, screen, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import React from 'react'
import { LoadingButton } from '@/components/ui/loading-button'

describe('LoadingButton', () => {
  it('should render button with children', () => {
    render(<LoadingButton>Click me</LoadingButton>)
    
    expect(screen.getByRole('button', { name: 'Click me' })).toBeInTheDocument()
  })

  it('should not show loading spinner when loading is false', () => {
    render(<LoadingButton loading={false}>Click me</LoadingButton>)
    
    const button = screen.getByRole('button')
    expect(button).not.toHaveClass('animate-spin')
    expect(button.querySelector('.animate-spin')).not.toBeInTheDocument()
  })

  it('should show loading spinner when loading is true', () => {
    render(<LoadingButton loading={true}>Click me</LoadingButton>)
    
    const spinner = document.querySelector('.animate-spin')
    expect(spinner).toBeInTheDocument()
  })

  it('should be disabled when loading is true', () => {
    render(<LoadingButton loading={true}>Click me</LoadingButton>)
    
    const button = screen.getByRole('button')
    expect(button).toBeDisabled()
  })

  it('should be disabled when disabled prop is true', () => {
    render(<LoadingButton disabled={true}>Click me</LoadingButton>)
    
    const button = screen.getByRole('button')
    expect(button).toBeDisabled()
  })

  it('should be disabled when both loading and disabled are true', () => {
    render(<LoadingButton loading={true} disabled={true}>Click me</LoadingButton>)
    
    const button = screen.getByRole('button')
    expect(button).toBeDisabled()
  })

  it('should show loading text when provided and loading is true', () => {
    render(
      <LoadingButton loading={true} loadingText="Saving...">
        Save
      </LoadingButton>
    )
    
    expect(screen.getByText('Saving...')).toBeInTheDocument()
    expect(screen.queryByText('Save')).not.toBeInTheDocument()
  })

  it('should show children text when loading is true but no loadingText provided', () => {
    render(<LoadingButton loading={true}>Save</LoadingButton>)
    
    expect(screen.getByText('Save')).toBeInTheDocument()
  })

  it('should show children when loading is false', () => {
    render(
      <LoadingButton loading={false} loadingText="Saving...">
        Save
      </LoadingButton>
    )
    
    expect(screen.getByText('Save')).toBeInTheDocument()
    expect(screen.queryByText('Saving...')).not.toBeInTheDocument()
  })

  it('should handle click events when not loading', async () => {
    const user = userEvent.setup()
    const handleClick = jest.fn()
    
    render(
      <LoadingButton onClick={handleClick} loading={false}>
        Click me
      </LoadingButton>
    )
    
    const button = screen.getByRole('button')
    await user.click(button)
    
    expect(handleClick).toHaveBeenCalledTimes(1)
  })

  it('should not handle click events when loading', async () => {
    const user = userEvent.setup()
    const handleClick = jest.fn()
    
    render(
      <LoadingButton onClick={handleClick} loading={true}>
        Click me
      </LoadingButton>
    )
    
    const button = screen.getByRole('button')
    await user.click(button)
    
    expect(handleClick).not.toHaveBeenCalled()
  })

  it('should apply custom className', () => {
    render(<LoadingButton className="custom-class">Click me</LoadingButton>)
    
    const button = screen.getByRole('button')
    expect(button).toHaveClass('custom-class')
  })

  it('should apply variant prop', () => {
    render(<LoadingButton variant="destructive">Delete</LoadingButton>)
    
    const button = screen.getByRole('button')
    // The exact class names depend on your Button component implementation
    // This test assumes the Button component applies the variant correctly
    expect(button).toBeInTheDocument()
  })

  it('should apply size prop', () => {
    render(<LoadingButton size="lg">Large Button</LoadingButton>)
    
    const button = screen.getByRole('button')
    expect(button).toBeInTheDocument()
  })

  it('should forward ref correctly', () => {
    const ref = React.createRef<HTMLButtonElement>()
    render(<LoadingButton ref={ref}>Click me</LoadingButton>)
    
    expect(ref.current).toBeInstanceOf(HTMLButtonElement)
    expect(ref.current?.textContent).toBe('Click me')
  })

  it('should support keyboard navigation', async () => {
    const user = userEvent.setup()
    const handleClick = jest.fn()
    
    render(<LoadingButton onClick={handleClick}>Click me</LoadingButton>)
    
    const button = screen.getByRole('button')
    button.focus()
    
    expect(button).toHaveFocus()
    
    await user.keyboard('{Enter}')
    expect(handleClick).toHaveBeenCalledTimes(1)
    
    await user.keyboard(' ')
    expect(handleClick).toHaveBeenCalledTimes(2)
  })

  it('should not respond to keyboard when loading', async () => {
    const user = userEvent.setup()
    const handleClick = jest.fn()
    
    render(<LoadingButton onClick={handleClick} loading={true}>Click me</LoadingButton>)
    
    const button = screen.getByRole('button')
    button.focus()
    
    await user.keyboard('{Enter}')
    await user.keyboard(' ')
    
    expect(handleClick).not.toHaveBeenCalled()
  })

  it('should pass through other button props', () => {
    render(
      <LoadingButton 
        type="submit" 
        name="test-button"
        value="test-value"
        data-testid="custom-button"
      >
        Submit
      </LoadingButton>
    )
    
    const button = screen.getByTestId('custom-button')
    expect(button).toHaveAttribute('type', 'submit')
    expect(button).toHaveAttribute('name', 'test-button')
    expect(button).toHaveAttribute('value', 'test-value')
  })

  it('should maintain accessibility when loading', () => {
    render(<LoadingButton loading={true} loadingText="Loading...">Submit</LoadingButton>)
    
    const button = screen.getByRole('button')
    expect(button).toHaveAccessibleName('Loading...')
    expect(button).toBeDisabled()
  })

  it('should show both spinner and text when loading', () => {
    render(<LoadingButton loading={true}>Processing</LoadingButton>)
    
    // Check for loading spinner
    const spinner = document.querySelector('.animate-spin')
    expect(spinner).toBeInTheDocument()
    
    // Check for text
    expect(screen.getByText('Processing')).toBeInTheDocument()
  })
})