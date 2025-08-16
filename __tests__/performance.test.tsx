import { render } from '@testing-library/react'
import Home from '../src/app/page'

// Mock Next.js Image component for performance tests
jest.mock('next/image', () => ({
  __esModule: true,
  default: ({
    alt,
    priority,
    ...props
  }: React.ImgHTMLAttributes<HTMLImageElement> & { priority?: boolean }) => {
    // eslint-disable-next-line @next/next/no-img-element
    return <img alt={alt} data-priority={priority} {...props} />
  },
}))

describe('Performance', () => {
  it('should render home page within performance budget', () => {
    const startTime = performance.now()
    render(<Home />)
    const endTime = performance.now()

    expect(endTime - startTime).toBeLessThan(500) // 500ms budget for test environment
  })

  it('should have priority loading for Next.js logo', () => {
    const { container } = render(<Home />)
    const priorityImage = container.querySelector('img[alt="Next.js logo"]')

    // Check for priority attribute in test environment
    expect(priorityImage?.getAttribute('data-priority')).toBeTruthy()
  })
})
