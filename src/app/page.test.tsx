import { render, screen } from '@testing-library/react'
import Home from './page'

// Fixed Next.js Image mock
jest.mock('next/image', () => ({
  __esModule: true,
  default: ({ alt, ...props }: React.ImgHTMLAttributes<HTMLImageElement>) => {
    // eslint-disable-next-line @next/next/no-img-element
    return <img alt={alt} {...props} />
  },
}))

describe('Home Page', () => {
  beforeEach(() => {
    render(<Home />)
  })

  describe('Content Rendering', () => {
    it('renders the main heading text', () => {
      expect(screen.getByText(/Get started by editing/)).toBeInTheDocument()
      expect(screen.getByText(/src\/app\/page.tsx/)).toBeInTheDocument()
      expect(screen.getByText(/Save and see your changes instantly/)).toBeInTheDocument()
    })

    it('renders all images with correct alt text', () => {
      expect(screen.getByAltText('Next.js logo')).toBeInTheDocument()
      expect(screen.getByAltText('Vercel logomark')).toBeInTheDocument()
      expect(screen.getByAltText('File icon')).toBeInTheDocument()
      expect(screen.getByAltText('Window icon')).toBeInTheDocument()
      expect(screen.getByAltText('Globe icon')).toBeInTheDocument()
    })
  })

  describe('Navigation Links', () => {
    it('renders main action buttons with correct href', () => {
      const deployLink = screen.getByRole('link', { name: /Deploy now/ })
      const docsLink = screen.getByRole('link', { name: /Read our docs/ })
      
      expect(deployLink).toHaveAttribute('href', expect.stringContaining('vercel.com/new'))
      expect(docsLink).toHaveAttribute('href', expect.stringContaining('nextjs.org/docs'))
    })

    it('renders footer links with correct href', () => {
      const learnLink = screen.getByRole('link', { name: /Learn/ })
      const examplesLink = screen.getByRole('link', { name: /Examples/ })
      const nextjsLink = screen.getByRole('link', { name: /Go to nextjs.org/ })
      
      expect(learnLink).toHaveAttribute('href', expect.stringContaining('nextjs.org/learn'))
      expect(examplesLink).toHaveAttribute('href', expect.stringContaining('vercel.com/templates'))
      expect(nextjsLink).toHaveAttribute('href', expect.stringContaining('nextjs.org'))
    })

    it('opens external links in new tab', () => {
      const externalLinks = screen.getAllByRole('link')
      
      externalLinks.forEach(link => {
        expect(link).toHaveAttribute('target', '_blank')
        expect(link).toHaveAttribute('rel', 'noopener noreferrer')
      })
    })
  })

  describe('Responsive Design', () => {
    it('applies responsive classes correctly', () => {
      const mainElement = screen.getByRole('main')
      expect(mainElement).toHaveClass('sm:items-start')
      
      const buttonContainer = mainElement.querySelector('.flex.gap-4')
      expect(buttonContainer).toHaveClass('flex-col', 'sm:flex-row')
    })
  })

  describe('Accessibility', () => {
    it('has proper semantic structure', () => {
      expect(screen.getByRole('main')).toBeInTheDocument()
      expect(screen.getByRole('contentinfo')).toBeInTheDocument() // footer
      expect(screen.getByRole('list')).toBeInTheDocument() // ol element
    })

    it('has aria-hidden images in footer', () => {
      const images = screen.getAllByRole('img')
      const footerImages = images.slice(-3) // last 3 images are in footer
      
      footerImages.forEach(img => {
        if (img.getAttribute('alt') !== 'Next.js logo' && img.getAttribute('alt') !== 'Vercel logomark') {
          expect(img).toHaveAttribute('aria-hidden')
        }
      })
    })
  })
})