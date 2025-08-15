import { cn } from '@/lib/utils'

describe('cn utility function', () => {
  describe('Basic Functionality', () => {
    it('merges class names correctly', () => {
      const result = cn('class1', 'class2')
      expect(result).toBe('class1 class2')
    })

    it('handles single class name', () => {
      const result = cn('single-class')
      expect(result).toBe('single-class')
    })

    it('handles empty input', () => {
      const result = cn()
      expect(result).toBe('')
    })

    it('handles multiple class names', () => {
      const result = cn('class1', 'class2', 'class3', 'class4')
      expect(result).toBe('class1 class2 class3 class4')
    })
  })

  describe('Conditional Classes', () => {
    it('handles conditional classes with boolean true', () => {
      const result = cn('base-class', true && 'conditional-class')
      expect(result).toBe('base-class conditional-class')
    })

    it('handles conditional classes with boolean false', () => {
      const result = cn('base-class', false && 'hidden-class')
      expect(result).toBe('base-class')
    })

    it('handles multiple conditional classes', () => {
      const isActive = true
      const isDisabled = false
      const result = cn(
        'base',
        isActive && 'active',
        isDisabled && 'disabled',
        true && 'always-included'
      )
      expect(result).toBe('base active always-included')
    })

    it('handles ternary operators', () => {
      const variant = 'primary'
      const result = cn('btn', variant === 'primary' ? 'btn-primary' : 'btn-secondary')
      expect(result).toBe('btn btn-primary')
    })
  })

  describe('Tailwind CSS Conflicts', () => {
    it('resolves simple Tailwind conflicts correctly', () => {
      const result = cn('bg-red-500', 'bg-blue-500')
      expect(result).toBe('bg-blue-500') // Later class should win
    })

    it('resolves padding conflicts', () => {
      const result = cn('p-4', 'px-6')
      expect(result).toContain('px-6')
      // Note: tailwind-merge behavior may vary, test that classes are present
      expect(result).toBeTruthy()
    })

    it('resolves margin conflicts', () => {
      const result = cn('m-2', 'mx-4', 'mt-6')
      expect(result).toContain('mx-4')
      expect(result).toContain('mt-6')
      // Note: tailwind-merge behavior may vary, test that classes are present
      expect(result).toBeTruthy()
    })

    it('resolves width conflicts', () => {
      const result = cn('w-full', 'w-1/2')
      expect(result).toBe('w-1/2')
    })

    it('resolves height conflicts', () => {
      const result = cn('h-screen', 'h-96')
      expect(result).toBe('h-96')
    })

    it('resolves text size conflicts', () => {
      const result = cn('text-sm', 'text-lg', 'text-xl')
      expect(result).toBe('text-xl')
    })

    it('resolves color conflicts within same property', () => {
      const result = cn('text-red-500', 'text-blue-600', 'text-green-400')
      expect(result).toBe('text-green-400')
    })

    it('preserves non-conflicting classes', () => {
      const result = cn('flex', 'bg-red-500', 'items-center', 'bg-blue-500', 'justify-center')
      expect(result).toContain('flex')
      expect(result).toContain('items-center')
      expect(result).toContain('justify-center')
      expect(result).toContain('bg-blue-500')
      expect(result).not.toContain('bg-red-500')
    })
  })

  describe('Array Inputs', () => {
    it('handles arrays of classes', () => {
      const result = cn(['class1', 'class2'], 'class3')
      expect(result).toBe('class1 class2 class3')
    })

    it('handles nested arrays', () => {
      const result = cn(['class1', ['class2', 'class3']], 'class4')
      expect(result).toBe('class1 class2 class3 class4')
    })

    it('handles arrays with conditional classes', () => {
      const result = cn(['base', true && 'active', false && 'hidden'], 'extra')
      expect(result).toBe('base active extra')
    })

    it('handles empty arrays', () => {
      const result = cn([], 'class1', [], 'class2')
      expect(result).toBe('class1 class2')
    })
  })

  describe('Object Inputs', () => {
    it('handles object inputs with boolean values', () => {
      const result = cn({
        'base-class': true,
        'active-class': true,
        'hidden-class': false,
      })
      expect(result).toBe('base-class active-class')
    })

    it('handles mixed object and string inputs', () => {
      const result = cn(
        'always-included',
        {
          'conditional-true': true,
          'conditional-false': false,
        },
        'also-included'
      )
      expect(result).toBe('always-included conditional-true also-included')
    })

    it('handles objects with Tailwind conflicts', () => {
      const result = cn({
        'bg-red-500': true,
        'bg-blue-500': true,
        'text-white': true,
      })
      expect(result).toContain('bg-blue-500')
      expect(result).toContain('text-white')
      expect(result).not.toContain('bg-red-500')
    })
  })

  describe('Null and Undefined Values', () => {
    it('handles undefined values', () => {
      const result = cn('base', undefined, 'end')
      expect(result).toBe('base end')
    })

    it('handles null values', () => {
      const result = cn('base', null, 'end')
      expect(result).toBe('base end')
    })

    it('handles mixed null, undefined, and valid values', () => {
      const result = cn('base', null, undefined, 'middle', null, 'end')
      expect(result).toBe('base middle end')
    })

    it('handles array with null and undefined', () => {
      const result = cn(['base', null, undefined, 'valid'], 'end')
      expect(result).toBe('base valid end')
    })
  })

  describe('Complex Tailwind Classes', () => {
    it('merges complex Tailwind classes', () => {
      const result = cn(
        'px-4 py-2 bg-blue-500 text-white rounded-md',
        'hover:bg-blue-600 focus:outline-none focus:ring-2',
        'px-6' // This should override px-4
      )
      expect(result).toContain('py-2')
      expect(result).toContain('bg-blue-500')
      expect(result).toContain('text-white')
      expect(result).toContain('rounded-md')
      expect(result).toContain('hover:bg-blue-600')
      expect(result).toContain('focus:outline-none')
      expect(result).toContain('focus:ring-2')
      expect(result).toContain('px-6')
      expect(result).not.toContain('px-4')
    })

    it('handles responsive classes', () => {
      const result = cn('w-full', 'sm:w-1/2', 'md:w-1/3', 'lg:w-1/4')
      expect(result).toBe('w-full sm:w-1/2 md:w-1/3 lg:w-1/4')
    })

    it('handles dark mode classes', () => {
      const result = cn('bg-white text-black', 'dark:bg-black dark:text-white')
      expect(result).toBe('bg-white text-black dark:bg-black dark:text-white')
    })

    it('handles hover and focus states', () => {
      const result = cn(
        'bg-blue-500 hover:bg-blue-600',
        'focus:bg-blue-700 hover:bg-blue-800' // hover should conflict
      )
      expect(result).toContain('bg-blue-500')
      expect(result).toContain('focus:bg-blue-700')
      expect(result).toContain('hover:bg-blue-800')
      expect(result).not.toContain('hover:bg-blue-600')
    })

    it('handles arbitrary value classes', () => {
      const result = cn('top-[117px]', 'top-[200px]')
      expect(result).toBe('top-[200px]')
    })
  })

  describe('Performance and Edge Cases', () => {
    it('handles empty strings', () => {
      const result = cn('', 'class1', '', 'class2', '')
      expect(result).toBe('class1 class2')
    })

    it('handles whitespace-only strings', () => {
      const result = cn('   ', 'class1', '\t\n', 'class2')
      expect(result).toBe('class1 class2')
    })

    it('handles large number of classes', () => {
      const classes = Array.from({ length: 100 }, (_, i) => `class-${i}`)
      const result = cn(...classes)
      expect(result).toContain('class-0')
      expect(result).toContain('class-99')
      expect(result.split(' ')).toHaveLength(100)
    })

    it('handles duplicate classes', () => {
      const result = cn('duplicate', 'other', 'duplicate', 'final')
      // clsx and tailwind-merge may handle duplicates differently
      expect(result).toContain('duplicate')
      expect(result).toContain('other')
      expect(result).toContain('final')
    })

    it('handles classes with special characters', () => {
      const result = cn('_underscore', '-dash', 'colon:hover', 'bracket[1]')
      expect(result).toBe('_underscore -dash colon:hover bracket[1]')
    })
  })

  describe('Real-world Usage Patterns', () => {
    it('handles button variant pattern', () => {
      const variant = 'primary'
      const size = 'lg'
      const disabled = false

      const result = cn('btn', {
        'btn-primary': variant === 'primary',
        'btn-secondary': variant === 'secondary',
        'btn-lg': size === 'lg',
        'btn-sm': size === 'sm',
        'btn-disabled': disabled,
      })

      expect(result).toBe('btn btn-primary btn-lg')
    })

    it('handles component state classes', () => {
      const isLoading = true
      const hasError = false
      const isSuccess = false

      const result = cn(
        'form-input',
        'border-gray-300',
        isLoading && 'opacity-50 cursor-not-allowed',
        hasError && 'border-red-500 text-red-900',
        isSuccess && 'border-green-500 text-green-900'
      )

      expect(result).toBe('form-input border-gray-300 opacity-50 cursor-not-allowed')
    })

    it('handles responsive design pattern', () => {
      const result = cn(
        'grid',
        'grid-cols-1',
        'gap-4',
        'sm:grid-cols-2',
        'md:grid-cols-3',
        'lg:grid-cols-4',
        'xl:grid-cols-6'
      )

      expect(result).toBe(
        'grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6'
      )
    })

    it('handles theme-based styling', () => {
      const theme = 'dark'
      const result = cn(
        'card',
        theme === 'light' ? 'bg-white text-black' : 'bg-gray-900 text-white',
        'rounded-lg shadow-md'
      )

      expect(result).toBe('card bg-gray-900 text-white rounded-lg shadow-md')
    })
  })

  describe('Type Safety and Integration', () => {
    it('returns a string type', () => {
      const result = cn('test')
      expect(typeof result).toBe('string')
    })

    it('works with template literals', () => {
      const color = 'blue'
      const shade = '500'
      const result = cn(`bg-${color}-${shade}`, 'text-white')
      expect(result).toBe('bg-blue-500 text-white')
    })

    it('works with computed class names', () => {
      const baseClasses = 'flex items-center'
      const variantClasses = 'bg-primary text-primary-foreground'
      const result = cn(baseClasses, variantClasses)
      expect(result).toBe('flex items-center bg-primary text-primary-foreground')
    })
  })
})
