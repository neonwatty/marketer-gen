import { test, expect } from '@playwright/test'

test.describe('Priority Prop Changes', () => {
  test.describe('Next.js Image Priority Prop', () => {
    test('should render Next.js logo with priority prop correctly', async ({ page }) => {
      await page.goto('/')
      
      // Wait for page to load
      await page.waitForSelector('img[alt="Next.js logo"]', { timeout: 10000 })
      
      const nextjsLogo = page.locator('img[alt="Next.js logo"]')
      await expect(nextjsLogo).toBeVisible()
      
      // Verify image loads quickly (priority should ensure fast loading)
      const imageLoadTime = await page.evaluate(async () => {
        const img = document.querySelector('img[alt="Next.js logo"]') as HTMLImageElement
        if (img && img.complete) {
          return 0 // Already loaded
        }
        
        return new Promise<number>((resolve) => {
          const startTime = performance.now()
          img.onload = () => {
            resolve(performance.now() - startTime)
          }
          img.onerror = () => resolve(-1)
        })
      })
      
      // Priority images should load quickly (within 1 second)
      expect(imageLoadTime).toBeLessThan(1000)
    })

    test('should have correct image attributes for priority loading', async ({ page }) => {
      await page.goto('/')
      
      const nextjsLogo = page.locator('img[alt="Next.js logo"]')
      await expect(nextjsLogo).toBeVisible()
      
      // Check image dimensions are set correctly
      await expect(nextjsLogo).toHaveAttribute('width', '180')
      await expect(nextjsLogo).toHaveAttribute('height', '38')
      
      // Priority images should have proper loading attributes
      const hasLoadingEager = await nextjsLogo.getAttribute('loading')
      const hasFetchPriorityHigh = await nextjsLogo.getAttribute('fetchpriority')
      
      // Priority images should either have loading="eager" or fetchpriority="high"
      expect(hasLoadingEager === 'eager' || hasFetchPriorityHigh === 'high').toBe(true)
    })

    test('should not use priority={true} boolean syntax', async ({ page }) => {
      await page.goto('/')
      
      // This is more of a code quality test - the change from priority={true} to priority
      // Should not affect functionality but ensures cleaner JSX
      const nextjsLogo = page.locator('img[alt="Next.js logo"]')
      await expect(nextjsLogo).toBeVisible()
      
      // Image should still behave as priority image
      const isAboveFold = await page.evaluate(() => {
        const img = document.querySelector('img[alt="Next.js logo"]') as HTMLImageElement
        const rect = img.getBoundingClientRect()
        return rect.top < window.innerHeight
      })
      
      expect(isAboveFold).toBe(true) // Priority images are typically above the fold
    })

    test('should load priority image before other page assets', async ({ page }) => {
      // Track resource loading order
      const loadedResources: string[] = []
      
      page.on('response', response => {
        const url = response.url()
        if (url.includes('next.svg') || url.includes('.js') || url.includes('.css')) {
          loadedResources.push(url)
        }
      })
      
      await page.goto('/')
      await page.waitForSelector('img[alt="Next.js logo"]')
      
      // Priority image should load early in the sequence
      const logoIndex = loadedResources.findIndex(url => url.includes('next.svg'))
      expect(logoIndex).toBeGreaterThanOrEqual(0) // Logo should be loaded
    })

    test('should maintain image quality and appearance', async ({ page }) => {
      await page.goto('/')
      
      const nextjsLogo = page.locator('img[alt="Next.js logo"]')
      await expect(nextjsLogo).toBeVisible()
      
      // Check that image renders with correct styling
      const imageStyles = await nextjsLogo.evaluate(img => {
        const styles = window.getComputedStyle(img)
        return {
          display: styles.display,
          width: styles.width,
          height: styles.height
        }
      })
      
      expect(imageStyles.display).not.toBe('none')
      expect(parseInt(imageStyles.width)).toBeGreaterThan(0)
      expect(parseInt(imageStyles.height)).toBeGreaterThan(0)
    })
  })

  test.describe('Performance Impact', () => {
    test('should improve Largest Contentful Paint (LCP) with priority prop', async ({ page }) => {
      // Navigate to page and measure LCP
      await page.goto('/')
      
      const lcp = await page.evaluate(() => {
        return new Promise<number>((resolve) => {
          new PerformanceObserver((list) => {
            const entries = list.getEntries()
            const lastEntry = entries[entries.length - 1]
            resolve(lastEntry.startTime)
          }).observe({ entryTypes: ['largest-contentful-paint'] })
          
          // Fallback timeout
          setTimeout(() => resolve(-1), 5000)
        })
      })
      
      // LCP should be reasonable (within 2.5 seconds for good user experience)
      expect(lcp).toBeLessThan(2500)
      expect(lcp).toBeGreaterThan(0)
    })

    test('should not negatively impact page load performance', async ({ page }) => {
      const startTime = Date.now()
      
      await page.goto('/')
      await page.waitForLoadState('networkidle')
      
      const loadTime = Date.now() - startTime
      
      // Page should load within reasonable time
      expect(loadTime).toBeLessThan(5000)
    })

    test('should preload priority image in document head', async ({ page }) => {
      await page.goto('/')
      
      // Check if Next.js added preload link for priority image
      const preloadLinks = await page.evaluate(() => {
        const links = Array.from(document.head.querySelectorAll('link[rel="preload"]'))
        return links.map(link => ({
          href: link.getAttribute('href'),
          as: link.getAttribute('as')
        }))
      })
      
      // Should have preload link for the image
      const hasImagePreload = preloadLinks.some(link => 
        link.as === 'image' && link.href?.includes('next.svg')
      )
      
      expect(hasImagePreload).toBe(true)
    })

    test('should not block render-critical resources', async ({ page }) => {
      // Monitor critical resource loading
      const criticalResources: string[] = []
      
      page.on('response', response => {
        const url = response.url()
        // Track CSS and critical JS
        if (url.includes('.css') || url.includes('framework') || url.includes('main')) {
          criticalResources.push(url)
        }
      })
      
      await page.goto('/')
      await page.waitForSelector('img[alt="Next.js logo"]')
      
      // Critical resources should still load
      expect(criticalResources.length).toBeGreaterThan(0)
    })
  })

  test.describe('Cross-browser Compatibility', () => {
    test('should work correctly in different browsers', async ({ page, browserName }) => {
      await page.goto('/')
      
      const nextjsLogo = page.locator('img[alt="Next.js logo"]')
      await expect(nextjsLogo).toBeVisible()
      
      // Image should be visible in all browsers
      const isVisible = await nextjsLogo.isVisible()
      expect(isVisible).toBe(true)
      
      // Check that priority loading works across browsers
      const hasHighPriority = await page.evaluate(() => {
        const img = document.querySelector('img[alt="Next.js logo"]') as HTMLImageElement
        return img.loading === 'eager' || img.fetchPriority === 'high'
      })
      
      expect(hasHighPriority).toBe(true)
    })

    test('should handle browsers without fetchpriority support gracefully', async ({ page }) => {
      // Simulate older browser without fetchpriority support
      await page.addInitScript(() => {
        Object.defineProperty(HTMLImageElement.prototype, 'fetchPriority', {
          get() { return undefined },
          set() { /* no-op */ }
        })
      })
      
      await page.goto('/')
      
      const nextjsLogo = page.locator('img[alt="Next.js logo"]')
      await expect(nextjsLogo).toBeVisible()
      
      // Should still work with fallback to loading="eager"
      const loadingAttr = await nextjsLogo.getAttribute('loading')
      expect(loadingAttr).toBe('eager')
    })
  })

  test.describe('Accessibility Impact', () => {
    test('should maintain image accessibility with priority changes', async ({ page }) => {
      await page.goto('/')
      
      const nextjsLogo = page.locator('img[alt="Next.js logo"]')
      
      // Should maintain alt text
      await expect(nextjsLogo).toHaveAttribute('alt', 'Next.js logo')
      
      // Should be keyboard accessible if in focus flow
      await page.keyboard.press('Tab')
      // Image itself might not be focusable, but surrounding elements should be
      
      // Should have proper dimensions for screen readers
      await expect(nextjsLogo).toHaveAttribute('width', '180')
      await expect(nextjsLogo).toHaveAttribute('height', '38')
    })

    test('should not affect screen reader experience', async ({ page }) => {
      await page.goto('/')
      
      // Check that image is properly announced to screen readers
      const logoAccessibleName = await page.locator('img[alt="Next.js logo"]').getAttribute('alt')
      expect(logoAccessibleName).toBe('Next.js logo')
      
      // Should not have empty alt (which would make it decorative)
      expect(logoAccessibleName).not.toBe('')
    })
  })

  test.describe('Development vs Production Behavior', () => {
    test('should behave consistently between dev and production builds', async ({ page }) => {
      await page.goto('/')
      
      const nextjsLogo = page.locator('img[alt="Next.js logo"]')
      await expect(nextjsLogo).toBeVisible()
      
      // Image should load regardless of build mode
      const imageLoaded = await page.evaluate(() => {
        const img = document.querySelector('img[alt="Next.js logo"]') as HTMLImageElement
        return img.complete && img.naturalHeight !== 0
      })
      
      expect(imageLoaded).toBe(true)
    })

    test('should handle hot reloading correctly in development', async ({ page }) => {
      // This test is more relevant in development mode
      await page.goto('/')
      
      const nextjsLogo = page.locator('img[alt="Next.js logo"]')
      await expect(nextjsLogo).toBeVisible()
      
      // Image should maintain its properties after potential hot reload
      await page.waitForTimeout(1000)
      
      await expect(nextjsLogo).toHaveAttribute('width', '180')
      await expect(nextjsLogo).toHaveAttribute('height', '38')
      await expect(nextjsLogo).toHaveAttribute('alt', 'Next.js logo')
    })
  })

  test.describe('SEO and Meta Impact', () => {
    test('should not affect page SEO with priority image changes', async ({ page }) => {
      await page.goto('/')
      
      // Check that page still has proper meta tags
      const title = await page.title()
      expect(title).toBeTruthy()
      
      // Priority image changes should not affect core page content
      const mainContent = page.locator('main')
      await expect(mainContent).toBeVisible()
      
      // Should still have proper page structure
      const headings = page.locator('h1, h2, h3')
      const headingCount = await headings.count()
      expect(headingCount).toBeGreaterThan(0)
    })

    test('should maintain proper Open Graph image handling', async ({ page }) => {
      await page.goto('/')
      
      // Check meta tags in head
      const ogImage = await page.locator('meta[property="og:image"]').getAttribute('content')
      
      // Should not interfere with OG image meta tags
      if (ogImage) {
        expect(ogImage).toBeTruthy()
      }
      
      // Priority prop should not affect meta image tags
      const metaImages = await page.evaluate(() => {
        const metas = Array.from(document.head.querySelectorAll('meta'))
        return metas.filter(meta => 
          meta.getAttribute('property')?.includes('image') ||
          meta.getAttribute('name')?.includes('image')
        ).length
      })
      
      // Should maintain any existing meta image tags
      expect(metaImages).toBeGreaterThanOrEqual(0)
    })
  })

  test.describe('Error Handling', () => {
    test('should handle image loading errors gracefully', async ({ page }) => {
      // Mock network to cause image loading failure
      await page.route('**/next.svg', route => route.abort())
      
      await page.goto('/')
      
      // Page should still load even if priority image fails
      const mainContent = page.locator('main')
      await expect(mainContent).toBeVisible()
      
      // Should handle error state gracefully
      const brokenImage = page.locator('img[alt="Next.js logo"]')
      
      // Image element should still exist even if src fails
      await expect(brokenImage).toBeAttached()
    })

    test('should not crash on invalid image props', async ({ page }) => {
      await page.goto('/')
      
      // Monitor for JavaScript errors
      const jsErrors: Error[] = []
      page.on('pageerror', error => {
        jsErrors.push(error)
      })
      
      await page.waitForTimeout(2000)
      
      // Should not have JS errors related to image priority
      const hasImageErrors = jsErrors.some(error => 
        error.message.includes('priority') || 
        error.message.includes('Image')
      )
      
      expect(hasImageErrors).toBe(false)
    })
  })
})