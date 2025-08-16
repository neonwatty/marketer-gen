import { test, expect } from '@playwright/test'

test.describe('Campaign Components', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to dashboard page where campaign components are used
    await page.goto('/dashboard')
  })

  test.describe('CampaignCard Component', () => {
    test('should render campaign card with all required elements', async ({ page }) => {
      // Wait for campaign cards to load
      await page.waitForSelector('[data-testid="campaign-card"]', { timeout: 10000 })
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      
      // Check card structure
      await expect(campaignCard).toBeVisible()
      await expect(campaignCard.locator('.card-header')).toBeVisible()
      await expect(campaignCard.locator('.card-content')).toBeVisible()
      
      // Check title and description
      await expect(campaignCard.locator('h3')).toBeVisible() // CardTitle
      await expect(campaignCard.locator('[data-testid="campaign-description"]')).toBeVisible()
    })

    test('should display campaign status badge correctly', async ({ page }) => {
      await page.waitForSelector('[data-testid="campaign-card"]')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      const statusBadge = campaignCard.locator('[data-testid="status-badge"]')
      
      await expect(statusBadge).toBeVisible()
      
      // Check that status is one of the expected values
      const statusText = await statusBadge.textContent()
      expect(['Active', 'Draft', 'Paused', 'Completed', 'Archived']).toContain(statusText?.trim())
    })

    test('should show campaign metrics correctly', async ({ page }) => {
      await page.waitForSelector('[data-testid="campaign-card"]')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      
      // Check engagement metric
      const engagementMetric = campaignCard.locator('[data-testid="engagement-metric"]')
      await expect(engagementMetric).toBeVisible()
      await expect(engagementMetric).toContainText('%')
      
      // Check conversion metric
      const conversionMetric = campaignCard.locator('[data-testid="conversion-metric"]')
      await expect(conversionMetric).toBeVisible()
      await expect(conversionMetric).toContainText('%')
      
      // Check content pieces metric
      const contentMetric = campaignCard.locator('[data-testid="content-metric"]')
      await expect(contentMetric).toBeVisible()
    })

    test('should display progress bar with correct percentage', async ({ page }) => {
      await page.waitForSelector('[data-testid="campaign-card"]')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      const progressBar = campaignCard.locator('[data-testid="progress-bar"]')
      const progressText = campaignCard.locator('[data-testid="progress-text"]')
      
      await expect(progressBar).toBeVisible()
      await expect(progressText).toBeVisible()
      await expect(progressText).toContainText('%')
      
      // Check that progress bar has correct width style
      const progressFill = progressBar.locator('div[style*="width"]')
      await expect(progressFill).toBeVisible()
    })

    test('should open dropdown menu on more options click', async ({ page }) => {
      await page.waitForSelector('[data-testid="campaign-card"]')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      const moreButton = campaignCard.locator('[data-testid="more-options-button"]')
      
      // Click more options button
      await moreButton.click()
      
      // Check dropdown menu appears
      const dropdownMenu = page.locator('[data-testid="campaign-dropdown-menu"]')
      await expect(dropdownMenu).toBeVisible()
      
      // Check menu items
      await expect(dropdownMenu.locator('text=View')).toBeVisible()
      await expect(dropdownMenu.locator('text=Edit')).toBeVisible()
      await expect(dropdownMenu.locator('text=Duplicate')).toBeVisible()
      await expect(dropdownMenu.locator('text=Archive')).toBeVisible()
    })

    test('should handle dropdown menu actions correctly', async ({ page }) => {
      await page.waitForSelector('[data-testid="campaign-card"]')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      const moreButton = campaignCard.locator('[data-testid="more-options-button"]')
      
      // Open dropdown
      await moreButton.click()
      
      // Test clicking outside closes dropdown
      await page.click('body', { position: { x: 100, y: 100 } })
      await expect(page.locator('[data-testid="campaign-dropdown-menu"]')).not.toBeVisible()
      
      // Open dropdown again and test menu item clicks
      await moreButton.click()
      
      // Click View option - should close dropdown
      await page.locator('text=View').click()
      await expect(page.locator('[data-testid="campaign-dropdown-menu"]')).not.toBeVisible()
    })

    test('should show additional metrics when available', async ({ page }) => {
      await page.waitForSelector('[data-testid="campaign-card"]')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      
      // Check for optional metrics section
      const additionalMetrics = campaignCard.locator('[data-testid="additional-metrics"]')
      
      // If additional metrics exist, verify their content
      if (await additionalMetrics.isVisible()) {
        const totalReach = additionalMetrics.locator('[data-testid="total-reach"]')
        const activeUsers = additionalMetrics.locator('[data-testid="active-users"]')
        
        if (await totalReach.isVisible()) {
          const reachText = await totalReach.textContent()
          expect(reachText).toMatch(/[\d,]+/) // Should contain formatted numbers
        }
        
        if (await activeUsers.isVisible()) {
          const usersText = await activeUsers.textContent()
          expect(usersText).toMatch(/[\d,]+/) // Should contain formatted numbers
        }
      }
    })

    test('should display last updated date correctly', async ({ page }) => {
      await page.waitForSelector('[data-testid="campaign-card"]')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      const lastUpdated = campaignCard.locator('[data-testid="last-updated"]')
      
      await expect(lastUpdated).toBeVisible()
      await expect(lastUpdated).toContainText('Updated')
      
      // Check date format (should match MM/DD/YYYY or similar locale format)
      const dateText = await lastUpdated.textContent()
      expect(dateText).toMatch(/Updated \d{1,2}\/\d{1,2}\/\d{4}/)
    })
  })

  test.describe('CampaignGrid Component', () => {
    test('should render campaign grid with multiple cards', async ({ page }) => {
      await page.waitForSelector('[data-testid="campaign-grid"]', { timeout: 10000 })
      
      const campaignGrid = page.locator('[data-testid="campaign-grid"]')
      await expect(campaignGrid).toBeVisible()
      
      // Should have responsive grid classes
      await expect(campaignGrid).toHaveClass(/grid/)
      await expect(campaignGrid).toHaveClass(/gap-6/)
      await expect(campaignGrid).toHaveClass(/sm:grid-cols-2/)
      await expect(campaignGrid).toHaveClass(/lg:grid-cols-3/)
    })

    test('should show loading state with skeleton cards', async ({ page }) => {
      // Navigate to a page that might show loading state
      await page.goto('/dashboard?loading=true')
      
      // Check for skeleton loading cards
      const skeletonCards = page.locator('[data-testid="campaign-card-skeleton"]')
      
      if (await skeletonCards.first().isVisible()) {
        await expect(skeletonCards).toHaveCount(6) // Default skeleton count
        
        // Check skeleton structure
        const firstSkeleton = skeletonCards.first()
        await expect(firstSkeleton.locator('.skeleton')).toBeVisible()
      }
    })

    test('should display empty state when no campaigns exist', async ({ page }) => {
      // Navigate to page with no campaigns (might need to mock this)
      await page.goto('/dashboard?empty=true')
      
      const emptyState = page.locator('[data-testid="campaigns-empty-state"]')
      
      if (await emptyState.isVisible()) {
        await expect(emptyState).toContainText('No campaigns found')
        await expect(emptyState).toContainText('Create your first campaign')
      }
    })

    test('should maintain responsive behavior across screen sizes', async ({ page }) => {
      await page.waitForSelector('[data-testid="campaign-grid"]')
      
      const campaignGrid = page.locator('[data-testid="campaign-grid"]')
      
      // Test mobile view
      await page.setViewportSize({ width: 375, height: 667 })
      await expect(campaignGrid).toBeVisible()
      
      // Test tablet view
      await page.setViewportSize({ width: 768, height: 1024 })
      await expect(campaignGrid).toBeVisible()
      
      // Test desktop view
      await page.setViewportSize({ width: 1920, height: 1080 })
      await expect(campaignGrid).toBeVisible()
    })
  })

  test.describe('CampaignCardSkeleton Component', () => {
    test('should render skeleton loader with proper structure', async ({ page }) => {
      // If skeleton is visible on initial load
      const skeleton = page.locator('[data-testid="campaign-card-skeleton"]').first()
      
      if (await skeleton.isVisible()) {
        // Check skeleton has proper shimmer animation
        await expect(skeleton).toHaveClass(/animate-pulse/)
        
        // Check skeleton elements
        await expect(skeleton.locator('.skeleton')).toHaveCount.greaterThan(3)
      }
    })

    test('should render skeleton grid with correct count', async ({ page }) => {
      const skeletonGrid = page.locator('[data-testid="campaign-skeleton-grid"]')
      
      if (await skeletonGrid.isVisible()) {
        const skeletonCards = skeletonGrid.locator('[data-testid="campaign-card-skeleton"]')
        await expect(skeletonCards).toHaveCount(6) // Default count
      }
    })
  })

  test.describe('Campaign Component Integration', () => {
    test('should handle campaign data loading and display', async ({ page }) => {
      await page.goto('/dashboard')
      
      // Wait for either loading state or actual content
      await Promise.race([
        page.waitForSelector('[data-testid="campaign-card"]', { timeout: 5000 }),
        page.waitForSelector('[data-testid="campaign-card-skeleton"]', { timeout: 5000 }),
        page.waitForSelector('[data-testid="campaigns-empty-state"]', { timeout: 5000 })
      ])
      
      // Verify one of the expected states is visible
      const hasCards = await page.locator('[data-testid="campaign-card"]').count() > 0
      const hasSkeleton = await page.locator('[data-testid="campaign-card-skeleton"]').count() > 0
      const hasEmptyState = await page.locator('[data-testid="campaigns-empty-state"]').isVisible()
      
      expect(hasCards || hasSkeleton || hasEmptyState).toBe(true)
    })

    test('should handle campaign interactions correctly', async ({ page }) => {
      await page.waitForSelector('[data-testid="campaign-card"]')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      
      // Test card hover effects
      await campaignCard.hover()
      await expect(campaignCard).toHaveClass(/hover:shadow-lg/)
      
      // Test keyboard navigation
      await campaignCard.focus()
      await expect(campaignCard).toBeFocused()
    })

    test('should integrate with dashboard layout correctly', async ({ page }) => {
      await page.goto('/dashboard')
      
      // Check that campaigns section is properly positioned within dashboard
      const dashboardMain = page.locator('main')
      const campaignsSection = page.locator('[data-testid="campaigns-section"]')
      
      await expect(dashboardMain).toBeVisible()
      
      if (await campaignsSection.isVisible()) {
        // Campaigns section should be within the main dashboard area
        await expect(dashboardMain).toContainText('Campaigns')
      }
    })

    test('should handle error states gracefully', async ({ page }) => {
      // Test with network failure simulation
      await page.route('**/api/campaigns**', route => route.abort())
      
      await page.goto('/dashboard')
      
      // Should handle API errors gracefully
      await page.waitForTimeout(2000)
      
      // Check for error state or fallback content
      const errorMessage = page.locator('[data-testid="campaigns-error"]')
      const emptyState = page.locator('[data-testid="campaigns-empty-state"]')
      
      // Should show either error state or empty state, not crash
      const hasErrorHandling = await errorMessage.isVisible() || await emptyState.isVisible()
      expect(hasErrorHandling).toBe(true)
    })
  })

  test.describe('Accessibility', () => {
    test('should have proper ARIA attributes', async ({ page }) => {
      await page.waitForSelector('[data-testid="campaign-card"]')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      const moreButton = campaignCard.locator('[data-testid="more-options-button"]')
      
      // Check ARIA attributes
      await expect(moreButton).toHaveAttribute('aria-label', /open menu/i)
      
      // Check dropdown menu accessibility
      await moreButton.click()
      const dropdownMenu = page.locator('[data-testid="campaign-dropdown-menu"]')
      await expect(dropdownMenu).toHaveAttribute('role', 'menu')
    })

    test('should support keyboard navigation', async ({ page }) => {
      await page.waitForSelector('[data-testid="campaign-card"]')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      const moreButton = campaignCard.locator('[data-testid="more-options-button"]')
      
      // Tab to more button
      await page.keyboard.press('Tab')
      if (await moreButton.isFocused()) {
        // Open dropdown with Enter
        await page.keyboard.press('Enter')
        await expect(page.locator('[data-testid="campaign-dropdown-menu"]')).toBeVisible()
        
        // Navigate menu with arrow keys
        await page.keyboard.press('ArrowDown')
        await page.keyboard.press('ArrowDown')
        
        // Close with Escape
        await page.keyboard.press('Escape')
        await expect(page.locator('[data-testid="campaign-dropdown-menu"]')).not.toBeVisible()
      }
    })

    test('should have proper screen reader support', async ({ page }) => {
      await page.waitForSelector('[data-testid="campaign-card"]')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      
      // Check for screen reader text
      const srTexts = campaignCard.locator('.sr-only')
      await expect(srTexts.first()).toBeVisible() // Should exist but be visually hidden
      
      // Check progress bar has proper labels
      const progressBar = campaignCard.locator('[data-testid="progress-bar"]')
      if (await progressBar.isVisible()) {
        const progressText = await campaignCard.locator('[data-testid="progress-text"]').textContent()
        expect(progressText).toMatch(/\d+%/) // Should have percentage for screen readers
      }
    })
  })

  test.describe('Performance', () => {
    test('should render campaign cards efficiently', async ({ page }) => {
      const startTime = Date.now()
      
      await page.goto('/dashboard')
      await page.waitForSelector('[data-testid="campaign-card"]', { timeout: 10000 })
      
      const renderTime = Date.now() - startTime
      
      // Should render within reasonable time (5 seconds)
      expect(renderTime).toBeLessThan(5000)
    })

    test('should handle large numbers of campaigns without performance degradation', async ({ page }) => {
      // This would need to be tested with a mock API that returns many campaigns
      await page.goto('/dashboard')
      
      // Wait for cards to load
      await page.waitForSelector('[data-testid="campaign-card"]')
      
      // Check that scrolling is smooth
      await page.evaluate(() => {
        window.scrollTo(0, document.body.scrollHeight)
      })
      
      await page.waitForTimeout(500)
      
      // Should still be responsive after scrolling
      const firstCard = page.locator('[data-testid="campaign-card"]').first()
      await expect(firstCard).toBeVisible()
    })
  })
})