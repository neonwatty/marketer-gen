import React, { ReactElement } from 'react'
import { render, RenderOptions } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { FormProvider, useForm, FieldValues } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

// Custom render function with providers
interface CustomRenderOptions extends Omit<RenderOptions, 'wrapper'> {
  // Add custom options here
  initialEntries?: string[]
}

export function customRender(
  ui: ReactElement,
  options: CustomRenderOptions = {}
): ReturnType<typeof render> & { user: ReturnType<typeof userEvent.setup> } {
  const { ...renderOptions } = options

  const Wrapper = ({ children }: { children: React.ReactNode }) => {
    // Add any global providers here (Theme, Router, etc.)
    return <>{children}</>
  }

  const renderResult = render(ui, { wrapper: Wrapper, ...renderOptions })
  
  return {
    ...renderResult,
    user: userEvent.setup(),
  }
}

// Form testing wrapper with React Hook Form context
interface FormTestWrapperProps<T extends FieldValues> {
  children: React.ReactNode
  schema?: z.ZodSchema<T>
  defaultValues?: Partial<T>
  onSubmit?: (data: T) => void
}

export function FormTestWrapper<T extends FieldValues>({
  children,
  schema,
  defaultValues,
  onSubmit = () => {},
}: FormTestWrapperProps<T>) {
  const formMethods = useForm<T>({
    ...(schema && { resolver: zodResolver(schema) }),
    ...(defaultValues && { defaultValues }),
  })

  return (
    <FormProvider {...formMethods}>
      <form onSubmit={formMethods.handleSubmit(onSubmit)}>
        {children}
        <button type="submit" data-testid="submit-button">
          Submit
        </button>
      </form>
    </FormProvider>
  )
}

// Custom render with form context
export function renderWithForm<T extends FieldValues>(
  ui: ReactElement,
  formOptions: {
    schema?: z.ZodSchema<T>
    defaultValues?: Partial<T>
    onSubmit?: (data: T) => void
    skipAutoDefaults?: boolean
  } = {},
  renderOptions: CustomRenderOptions = {}
) {
  const defaultDefaultValues = formOptions.skipAutoDefaults ? {} : {
    attachments: [],
    brandAssets: [],
    targetAudience: 'Restored audience',
  }
  
  const finalOptions = {
    ...formOptions,
    defaultValues: {
      ...defaultDefaultValues,
      ...(formOptions.defaultValues || {}),
    }
  }
  
  const Wrapper = ({ children }: { children: React.ReactNode }) => (
    <FormTestWrapper {...finalOptions}>{children}</FormTestWrapper>
  )

  return customRender(ui, { ...renderOptions, wrapper: Wrapper })
}

// File mock helpers
export function createMockFile(
  name: string,
  size: number,
  type: string,
  content: string = 'mock file content'
): File {
  const file = new File([content], name, { type })
  Object.defineProperty(file, 'size', { value: size })
  return file
}

export function createMockImageFile(
  name: string = 'test-image.jpg',
  size: number = 50000
): File {
  return createMockFile(name, size, 'image/jpeg')
}

export function createMockPdfFile(
  name: string = 'test-document.pdf',
  size: number = 100000
): File {
  return createMockFile(name, size, 'application/pdf')
}

export function createMockVideoFile(
  name: string = 'test-video.mp4',
  size: number = 5000000
): File {
  return createMockFile(name, size, 'video/mp4')
}

// Drag and drop event helpers
export function createMockDragEvent(
  type: string,
  files: File[] = []
): DragEvent {
  const dataTransfer = new DataTransfer()
  files.forEach(file => {
    const item = {
      kind: 'file' as const,
      type: file.type,
      getAsFile: () => file,
    }
    dataTransfer.items.add as any
  })

  Object.defineProperty(dataTransfer, 'files', {
    value: {
      length: files.length,
      item: (index: number) => files[index] || null,
      [Symbol.iterator]: function* () {
        yield* files
      },
    },
  })

  const event = new Event(type) as DragEvent
  Object.defineProperty(event, 'dataTransfer', {
    value: dataTransfer,
  })

  return event
}

// Async testing helpers
export function waitForFileProcessing(timeout: number = 1000): Promise<void> {
  return new Promise(resolve => {
    setTimeout(resolve, timeout)
  })
}

export async function waitForUploadCompletion(
  getByTestId: (testId: string) => HTMLElement,
  timeout: number = 5000
): Promise<void> {
  const startTime = Date.now()
  
  while (Date.now() - startTime < timeout) {
    try {
      const element = getByTestId('upload-progress')
      if (element.textContent?.includes('100%')) {
        return
      }
    } catch {
      // Element might not exist yet
    }
    await new Promise(resolve => setTimeout(resolve, 100))
  }
  
  throw new Error('Upload did not complete within timeout')
}

// Form validation testing helpers
export async function submitFormAndWaitForValidation(
  user: ReturnType<typeof userEvent.setup>,
  getByTestId: (testId: string) => HTMLElement
): Promise<void> {
  const submitButton = getByTestId('submit-button')
  await user.click(submitButton)
  
  // Wait for validation to complete
  await new Promise(resolve => setTimeout(resolve, 100))
}

export function expectFormError(
  container: HTMLElement,
  fieldName: string,
  errorMessage: string
) {
  const errorElement = container.querySelector(`[data-field="${fieldName}"] .error-message`)
  expect(errorElement).toBeInTheDocument()
  expect(errorElement).toHaveTextContent(errorMessage)
}

// Accessibility testing helpers
export function expectProperAriLabeling(element: HTMLElement) {
  expect(element).toHaveAttribute('aria-label')
  const ariaLabel = element.getAttribute('aria-label')
  expect(ariaLabel).toBeTruthy()
  expect(ariaLabel!.length).toBeGreaterThan(0)
}

export function expectKeyboardAccessible(element: HTMLElement) {
  expect(element).toHaveAttribute('tabindex')
  const tabIndex = element.getAttribute('tabindex')
  expect(tabIndex).not.toBe('-1') // Should be keyboard accessible
}

export function expectScreenReaderText(
  container: HTMLElement,
  text: string
) {
  const srElement = container.querySelector('.sr-only')
  expect(srElement).toBeInTheDocument()
  expect(srElement).toHaveTextContent(text)
}

// Responsive testing helpers
export function setViewportSize(width: number, height: number) {
  Object.defineProperty(window, 'innerWidth', {
    writable: true,
    configurable: true,
    value: width,
  })
  Object.defineProperty(window, 'innerHeight', {
    writable: true,
    configurable: true,
    value: height,
  })
  
  // Trigger resize event
  window.dispatchEvent(new Event('resize'))
}

export const breakpoints = {
  mobile: { width: 375, height: 667 },
  tablet: { width: 768, height: 1024 },
  desktop: { width: 1440, height: 900 },
  ultrawide: { width: 1920, height: 1080 },
}

// Re-export testing library utilities
export * from '@testing-library/react'
export { default as userEvent } from '@testing-library/user-event'

// Make customRender the default export
export { customRender as render }