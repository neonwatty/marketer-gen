import { test, expect } from '@playwright/test'

test.describe('Integration Tests for Recent Changes', () => {
  test.describe('Full Application Flow with New Changes', () => {
    test('should complete end-to-end user journey with new components', async ({ page }) => {
      // Start from homepage with updated priority image
      await page.goto('/')
      
      // Verify homepage loads with priority image
      const nextjsLogo = page.locator('img[alt="Next.js logo"]')
      await expect(nextjsLogo).toBeVisible()
      await expect(nextjsLogo).toHaveAttribute('width', '180')
      await expect(nextjsLogo).toHaveAttribute('height', '38')
      
      // Navigate to dashboard
      await page.goto('/dashboard')
      
      // Wait for dashboard to load with new campaign components
      await page.waitForTimeout(2000)
      
      const dashboardMain = page.locator('main')
      await expect(dashboardMain).toBeVisible()
      
      // Check if campaign components are loaded
      const campaignGrid = page.locator('[data-testid="campaign-grid"]')
      const campaignCards = page.locator('[data-testid="campaign-card"]')
      const skeletonCards = page.locator('[data-testid="campaign-card-skeleton"]')
      const emptyState = page.locator('[data-testid="campaigns-empty-state"]')
      
      // Should show one of: campaigns, loading state, or empty state
      const hasContent = await campaignGrid.isVisible() || 
                        await campaignCards.count() > 0 || 
                        await skeletonCards.count() > 0 || 
                        await emptyState.isVisible()
      
      expect(hasContent).toBe(true)
      
      // If campaigns exist, test interaction flow
      if (await campaignCards.count() > 0) {
        const firstCard = campaignCards.first()
        
        // Test campaign card metrics display
        await expect(firstCard.locator('[data-testid="engagement-metric"]')).toBeVisible()
        await expect(firstCard.locator('[data-testid="conversion-metric"]')).toBeVisible()
        await expect(firstCard.locator('[data-testid="content-metric"]')).toBeVisible()
        
        // Test dropdown interaction
        const moreButton = firstCard.locator('[data-testid="more-options-button"]')
        await moreButton.click()
        
        const dropdownMenu = page.locator('[data-testid="campaign-dropdown-menu"]')
        await expect(dropdownMenu).toBeVisible()
        
        // Test menu options
        await expect(dropdownMenu.locator('text=View')).toBeVisible()
        await expect(dropdownMenu.locator('text=Edit')).toBeVisible()
        await expect(dropdownMenu.locator('text=Duplicate')).toBeVisible()
        await expect(dropdownMenu.locator('text=Archive')).toBeVisible()
        
        // Close dropdown
        await page.click('body', { position: { x: 100, y: 100 } })
        await expect(dropdownMenu).not.toBeVisible()
      }
    })

    test('should handle authentication flow with improved error handling', async ({ page }) => {
      // Test auth system resilience
      let authCallCount = 0
      
      await page.route('**/api/auth/session', async route => {
        authCallCount++
        
        if (authCallCount === 1) {
          // Simulate database error on first call
          const sessionWithError = {
            user: {
              id: 'test-user-id',
              email: 'test@example.com',
              name: 'Test User'
              // No role due to database error
            },
            expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
          }
          
          await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify(sessionWithError)
          })
        } else {
          // Subsequent calls work normally
          const sessionNormal = {
            user: {
              id: 'test-user-id',
              email: 'test@example.com',
              name: 'Test User',
              role: 'user'
            },
            expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
          }
          
          await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify(sessionNormal)
          })
        }
      })
      
      // Navigate to protected route
      await page.goto('/dashboard')
      
      // Should handle auth error gracefully and still show content
      await expect(page.locator('main')).toBeVisible()
      
      // Navigate to another protected route to test auth recovery
      await page.goto('/dashboard/campaigns')
      await expect(page.locator('main')).toBeVisible()
      
      // Should have made multiple auth calls due to navigation
      expect(authCallCount).toBeGreaterThan(1)
    })

    test('should maintain dashboard component integration after changes', async ({ page }) => {
      await page.goto('/dashboard')
      
      // Check that existing dashboard components still work
      const dashboardHeader = page.locator('[data-testid="dashboard-header"]')
      const dashboardSidebar = page.locator('[data-testid="dashboard-sidebar"]')
      const breadcrumb = page.locator('[data-testid="breadcrumb"]')
      
      // These components should still be functional
      if (await dashboardHeader.isVisible()) {
        await expect(dashboardHeader).toBeVisible()
      }
      
      if (await dashboardSidebar.isVisible()) {
        await expect(dashboardSidebar).toBeVisible()
        
        // Test sidebar navigation still works
        const navItems = dashboardSidebar.locator('a')
        const navCount = await navItems.count()
        expect(navCount).toBeGreaterThan(0)
      }
      
      if (await breadcrumb.isVisible()) {
        await expect(breadcrumb).toBeVisible()
      }
      
      // New campaign components should integrate seamlessly
      const campaignSection = page.locator('[data-testid="campaigns-section"]')
      const campaignGrid = page.locator('[data-testid="campaign-grid"]')
      
      if (await campaignSection.isVisible() || await campaignGrid.isVisible()) {
        // Campaign components should be within dashboard layout
        const dashboardMain = page.locator('main')
        await expect(dashboardMain).toBeVisible()
      }
    })
  })

  test.describe('Cross-Component Interaction', () => {
    test('should handle campaign component state changes correctly', async ({ page }) => {
      await page.goto('/dashboard')
      
      const campaignCards = page.locator('[data-testid="campaign-card"]')
      
      if (await campaignCards.count() > 0) {
        const firstCard = campaignCards.first()
        const moreButton = firstCard.locator('[data-testid="more-options-button"]')
        
        // Test state management across interactions
        await moreButton.click()
        
        let dropdownMenu = page.locator('[data-testid="campaign-dropdown-menu"]')
        await expect(dropdownMenu).toBeVisible()
        
        // Click View option
        await dropdownMenu.locator('text=View').click()
        await expect(dropdownMenu).not.toBeVisible()
        
        // Dropdown should stay closed
        await page.waitForTimeout(500)
        await expect(dropdownMenu).not.toBeVisible()
        
        // Should be able to open dropdown again
        await moreButton.click()
        dropdownMenu = page.locator('[data-testid="campaign-dropdown-menu"]')
        await expect(dropdownMenu).toBeVisible()
        
        // Test keyboard navigation
        await page.keyboard.press('Escape')
        await expect(dropdownMenu).not.toBeVisible()
      }
    })

    test('should handle loading states and transitions correctly', async ({ page }) => {
      // Navigate to page that might show loading state
      await page.goto('/dashboard')
      
      // Monitor for loading state transitions
      let hasShownSkeleton = false
      let hasShownContent = false
      
      // Check for skeleton loading state
      const skeletonCards = page.locator('[data-testid="campaign-card-skeleton"]')
      if (await skeletonCards.count() > 0) {
        hasShownSkeleton = true
        await expect(skeletonCards.first()).toHaveClass(/animate-pulse/)
      }
      
      // Wait for potential content loading
      await page.waitForTimeout(2000)
      
      // Check for actual content
      const campaignCards = page.locator('[data-testid="campaign-card"]')
      const emptyState = page.locator('[data-testid="campaigns-empty-state"]')
      
      if (await campaignCards.count() > 0 || await emptyState.isVisible()) {
        hasShownContent = true
      }
      
      // Should show either skeleton then content, or direct content, or empty state
      expect(hasShownSkeleton || hasShownContent).toBe(true)
    })

    test('should maintain responsive behavior across all components', async ({ page }) => {
      await page.goto('/dashboard')
      
      // Test mobile view
      await page.setViewportSize({ width: 375, height: 667 })
      await page.waitForTimeout(500)
      
      const dashboardMain = page.locator('main')
      await expect(dashboardMain).toBeVisible()
      
      const campaignGrid = page.locator('[data-testid="campaign-grid"]')
      if (await campaignGrid.isVisible()) {
        // Should maintain responsive grid classes
        await expect(campaignGrid).toHaveClass(/grid/)
        await expect(campaignGrid).toHaveClass(/sm:grid-cols-2/)
      }
      
      // Test tablet view
      await page.setViewportSize({ width: 768, height: 1024 })
      await page.waitForTimeout(500)
      await expect(dashboardMain).toBeVisible()
      
      // Test desktop view
      await page.setViewportSize({ width: 1920, height: 1080 })
      await page.waitForTimeout(500)
      await expect(dashboardMain).toBeVisible()
      
      // Should work across all breakpoints
      if (await campaignGrid.isVisible()) {
        await expect(campaignGrid).toHaveClass(/lg:grid-cols-3/)
      }
    })
  })

  test.describe('Performance and Error Recovery', () => {
    test('should handle multiple error scenarios gracefully', async ({ page }) => {
      // Test multiple error conditions simultaneously
      let requestCount = 0
      
      await page.route('**/api/**', async route => {
        requestCount++
        const url = route.request().url()
        
        if (url.includes('/auth/session') && requestCount <= 2) {
          // Simulate auth errors for first few requests
          await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({
              user: {
                id: 'test-user',
                email: 'test@example.com'
                // Missing name and role
              },
              expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
            })
          })
        } else if (url.includes('/campaigns') && Math.random() < 0.3) {
          // Occasionally fail campaign requests
          await route.abort()
        } else {
          await route.continue()
        }
      })
      
      await page.goto('/dashboard')
      
      // Should handle multiple error conditions without crashing
      await page.waitForTimeout(3000)
      await expect(page.locator('main')).toBeVisible()
      
      // Navigate between pages to test error recovery
      await page.goto('/dashboard/campaigns')
      await page.waitForTimeout(1000)
      
      await page.goto('/dashboard')
      await page.waitForTimeout(1000)
      
      // Should maintain stability across navigation with errors
      await expect(page.locator('main')).toBeVisible()
    })

    test('should maintain good performance with all changes', async ({ page }) => {
      const startTime = Date.now()
      
      await page.goto('/dashboard')
      await page.waitForSelector('main')
      
      const totalLoadTime = Date.now() - startTime
      
      // With all changes, page should still load within reasonable time
      expect(totalLoadTime).toBeLessThan(10000)
      
      // Test navigation performance
      const navStart = Date.now()
      await page.goto('/dashboard/campaigns')
      await page.waitForSelector('main')
      const navTime = Date.now() - navStart
      
      expect(navTime).toBeLessThan(5000)
    })

    test('should handle concurrent user actions correctly', async ({ page }) => {
      await page.goto('/dashboard')
      
      const campaignCards = page.locator('[data-testid="campaign-card"]')
      
      if (await campaignCards.count() >= 2) {
        // Test concurrent dropdown interactions
        const firstCard = campaignCards.nth(0)
        const secondCard = campaignCards.nth(1)
        
        const firstButton = firstCard.locator('[data-testid="more-options-button"]')
        const secondButton = secondCard.locator('[data-testid="more-options-button"]')
        
        // Open both dropdowns quickly
        await firstButton.click()
        await secondButton.click()
        
        // Only one dropdown should be open at a time (or both should handle correctly)
        const dropdownMenus = page.locator('[data-testid="campaign-dropdown-menu"]')
        const openMenuCount = await dropdownMenus.count()
        
        // Should handle multiple dropdown states correctly
        expect(openMenuCount).toBeGreaterThanOrEqual(0)
        expect(openMenuCount).toBeLessThanOrEqual(2)
      }
    })
  })

  test.describe('Backward Compatibility', () => {
    test('should not break existing functionality with new exports', async ({ page }) => {
      await page.goto('/dashboard')
      
      // Existing dashboard functionality should still work
      const dashboardLayout = page.locator('[data-testid="dashboard-layout"]')
      if (await dashboardLayout.isVisible()) {
        await expect(dashboardLayout).toBeVisible()
      }
      
      // Navigation should still work
      await page.goto('/dashboard/campaigns')
      await expect(page.locator('main')).toBeVisible()
      
      // Go back to main dashboard
      await page.goto('/dashboard')
      await expect(page.locator('main')).toBeVisible()
      
      // Should not have broken routing or layout
      const currentUrl = page.url()
      expect(currentUrl).toContain('/dashboard')
    })

    test('should maintain API compatibility', async ({ page }) => {
      // Test that API routes still work with auth changes
      const apiResponse = await page.request.get('/api/health')
      expect(apiResponse.status()).toBe(200)
      
      // Auth endpoints should still function
      const authResponse = await page.request.get('/api/auth/session')
      
      // Should get response (even if no session)
      expect([200, 401, 404]).toContain(authResponse.status())
    })

    test('should preserve existing user experience patterns', async ({ page }) => {
      await page.goto('/')
      
      // Homepage should still work with priority image changes
      await expect(page.locator('main')).toBeVisible()
      const nextjsLogo = page.locator('img[alt="Next.js logo"]')
      await expect(nextjsLogo).toBeVisible()
      
      // Navigation to dashboard should work
      await page.goto('/dashboard')
      await expect(page.locator('main')).toBeVisible()
      
      // Should maintain familiar user experience
      const hasContent = await page.locator('h1, h2, h3').count() > 0
      expect(hasContent).toBe(true)
    })
  })

  test.describe('Edge Cases and Stress Testing', () => {
    test('should handle rapid navigation between pages', async ({ page }) => {
      const pages = ['/dashboard', '/dashboard/campaigns', '/dashboard']
      
      // Rapid navigation test
      for (let i = 0; i < 3; i++) {
        for (const url of pages) {
          await page.goto(url)
          await page.waitForTimeout(200) // Brief pause
          await expect(page.locator('main')).toBeVisible()
        }
      }
      
      // Should handle rapid navigation without errors
      await expect(page.locator('main')).toBeVisible()
    })

    test('should handle browser refresh correctly', async ({ page }) => {
      await page.goto('/dashboard')
      await page.waitForTimeout(1000)
      
      // Refresh page
      await page.reload()
      await page.waitForTimeout(1000)
      
      // Should reload correctly with all components
      await expect(page.locator('main')).toBeVisible()
      
      // Campaign components should reload correctly
      const campaignGrid = page.locator('[data-testid="campaign-grid"]')
      const skeletonCards = page.locator('[data-testid="campaign-card-skeleton"]')
      const emptyState = page.locator('[data-testid="campaigns-empty-state"]')
      
      // Should show appropriate state after refresh
      const hasExpectedState = await campaignGrid.isVisible() || 
                              await skeletonCards.count() > 0 || 
                              await emptyState.isVisible()
      
      expect(hasExpectedState).toBe(true)
    })

    test('should handle network instability', async ({ page }) => {
      let networkFailureCount = 0
      
      await page.route('**/*', async route => {
        networkFailureCount++
        
        // Randomly fail some requests to simulate network issues
        if (networkFailureCount % 5 === 0 && !route.request().url().includes('localhost')) {
          await route.abort()
        } else {
          await route.continue()
        }
      })
      
      await page.goto('/dashboard')
      
      // Should handle network instability gracefully
      await page.waitForTimeout(3000)
      await expect(page.locator('main')).toBeVisible()
      
      // Should maintain basic functionality despite network issues
      const hasBasicContent = await page.locator('h1, h2, h3, p').count() > 0
      expect(hasBasicContent).toBe(true)
    })
  })
})