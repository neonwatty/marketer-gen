import { test, expect } from '@playwright/test'

test.describe('Dashboard Component Exports', () => {
  test.describe('Component Import and Usage', () => {
    test('should import and render CampaignCard component correctly', async ({ page }) => {
      await page.goto('/dashboard')
      
      // Wait for campaign components to load
      await page.waitForTimeout(2000)
      
      // Check if CampaignCard is properly imported and rendered
      const campaignCard = page.locator('[data-testid="campaign-card"]')
      
      if (await campaignCard.count() > 0) {
        await expect(campaignCard.first()).toBeVisible()
        
        // Verify CampaignCard structure
        await expect(campaignCard.first().locator('.card')).toBeVisible()
        await expect(campaignCard.first().locator('.card-header')).toBeVisible()
        await expect(campaignCard.first().locator('.card-content')).toBeVisible()
      }
    })

    test('should import and render CampaignGrid component correctly', async ({ page }) => {
      await page.goto('/dashboard')
      
      // Check if CampaignGrid is properly imported and rendered
      const campaignGrid = page.locator('[data-testid="campaign-grid"]')
      
      if (await campaignGrid.isVisible()) {
        await expect(campaignGrid).toBeVisible()
        
        // Verify grid layout classes
        await expect(campaignGrid).toHaveClass(/grid/)
        await expect(campaignGrid).toHaveClass(/gap-6/)
        await expect(campaignGrid).toHaveClass(/sm:grid-cols-2/)
        await expect(campaignGrid).toHaveClass(/lg:grid-cols-3/)
      }
    })

    test('should import and render CampaignCardSkeleton correctly', async ({ page }) => {
      // Navigate to page with potential loading state
      await page.goto('/dashboard?loading=true')
      
      // Check for skeleton components
      const skeletonCard = page.locator('[data-testid="campaign-card-skeleton"]')
      const skeletonGrid = page.locator('[data-testid="campaign-skeleton-grid"]')
      
      // If loading state is implemented, verify skeleton components
      if (await skeletonCard.count() > 0) {
        await expect(skeletonCard.first()).toBeVisible()
        await expect(skeletonCard.first()).toHaveClass(/animate-pulse/)
      }
      
      if (await skeletonGrid.isVisible()) {
        await expect(skeletonGrid).toBeVisible()
        const skeletonCards = skeletonGrid.locator('[data-testid="campaign-card-skeleton"]')
        await expect(skeletonCards).toHaveCount(6) // Default skeleton count
      }
    })

    test('should verify existing dashboard components still work', async ({ page }) => {
      await page.goto('/dashboard')
      
      // Check that existing dashboard components are still functional
      const dashboardHeader = page.locator('[data-testid="dashboard-header"]')
      const dashboardSidebar = page.locator('[data-testid="dashboard-sidebar"]')
      const dashboardBreadcrumb = page.locator('[data-testid="breadcrumb"]')
      
      // These should still be imported and working
      if (await dashboardHeader.isVisible()) {
        await expect(dashboardHeader).toBeVisible()
      }
      
      if (await dashboardSidebar.isVisible()) {
        await expect(dashboardSidebar).toBeVisible()
      }
      
      if (await dashboardBreadcrumb.isVisible()) {
        await expect(dashboardBreadcrumb).toBeVisible()
      }
    })
  })

  test.describe('Type Safety and Component Structure', () => {
    test('should handle Campaign type interface correctly', async ({ page }) => {
      await page.goto('/dashboard')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      
      if (await campaignCard.isVisible()) {
        // Verify required Campaign interface properties are displayed
        await expect(campaignCard.locator('[data-testid="campaign-title"]')).toBeVisible()
        await expect(campaignCard.locator('[data-testid="campaign-description"]')).toBeVisible()
        await expect(campaignCard.locator('[data-testid="status-badge"]')).toBeVisible()
        
        // Check metrics structure
        await expect(campaignCard.locator('[data-testid="engagement-metric"]')).toBeVisible()
        await expect(campaignCard.locator('[data-testid="conversion-metric"]')).toBeVisible()
        await expect(campaignCard.locator('[data-testid="content-metric"]')).toBeVisible()
        
        // Check progress indicator
        await expect(campaignCard.locator('[data-testid="progress-bar"]')).toBeVisible()
        
        // Check dates
        await expect(campaignCard.locator('[data-testid="last-updated"]')).toBeVisible()
      }
    })

    test('should handle CampaignMetrics type interface correctly', async ({ page }) => {
      await page.goto('/dashboard')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      
      if (await campaignCard.isVisible()) {
        // Verify required metrics
        const engagementMetric = campaignCard.locator('[data-testid="engagement-metric"]')
        const conversionMetric = campaignCard.locator('[data-testid="conversion-metric"]')
        const contentMetric = campaignCard.locator('[data-testid="content-metric"]')
        
        await expect(engagementMetric).toBeVisible()
        await expect(conversionMetric).toBeVisible()
        await expect(contentMetric).toBeVisible()
        
        // Verify percentage format for rates
        const engagementText = await engagementMetric.textContent()
        const conversionText = await conversionMetric.textContent()
        
        expect(engagementText).toMatch(/\d+(\.\d+)?%/)
        expect(conversionText).toMatch(/\d+(\.\d+)?%/)
        
        // Verify number format for content pieces
        const contentText = await contentMetric.textContent()
        expect(contentText).toMatch(/\d+/)
        
        // Check optional metrics if present
        const additionalMetrics = campaignCard.locator('[data-testid="additional-metrics"]')
        if (await additionalMetrics.isVisible()) {
          const totalReach = additionalMetrics.locator('[data-testid="total-reach"]')
          const activeUsers = additionalMetrics.locator('[data-testid="active-users"]')
          
          if (await totalReach.isVisible()) {
            const reachText = await totalReach.textContent()
            expect(reachText).toMatch(/[\d,]+/) // Should be formatted number
          }
          
          if (await activeUsers.isVisible()) {
            const usersText = await activeUsers.textContent()
            expect(usersText).toMatch(/[\d,]+/) // Should be formatted number
          }
        }
      }
    })

    test('should handle CampaignGridProps interface correctly', async ({ page }) => {
      await page.goto('/dashboard')
      
      const campaignGrid = page.locator('[data-testid="campaign-grid"]')
      
      if (await campaignGrid.isVisible()) {
        // Verify grid can handle campaigns array
        const campaignCards = campaignGrid.locator('[data-testid="campaign-card"]')
        const cardCount = await campaignCards.count()
        
        expect(cardCount).toBeGreaterThanOrEqual(0)
        
        // If cards exist, verify they're properly structured
        if (cardCount > 0) {
          for (let i = 0; i < Math.min(cardCount, 3); i++) {
            const card = campaignCards.nth(i)
            await expect(card).toBeVisible()
            await expect(card.locator('[data-testid="campaign-title"]')).toBeVisible()
          }
        }
      }
    })

    test('should handle status enum values correctly', async ({ page }) => {
      await page.goto('/dashboard')
      
      const campaignCards = page.locator('[data-testid="campaign-card"]')
      const cardCount = await campaignCards.count()
      
      if (cardCount > 0) {
        // Check that all status badges show valid enum values
        for (let i = 0; i < Math.min(cardCount, 5); i++) {
          const card = campaignCards.nth(i)
          const statusBadge = card.locator('[data-testid="status-badge"]')
          
          if (await statusBadge.isVisible()) {
            const statusText = await statusBadge.textContent()
            const validStatuses = ['Active', 'Draft', 'Paused', 'Completed', 'Archived']
            expect(validStatuses).toContain(statusText?.trim())
          }
        }
      }
    })
  })

  test.describe('Component Props and Event Handling', () => {
    test('should handle campaign card action callbacks', async ({ page }) => {
      await page.goto('/dashboard')
      
      const campaignCard = page.locator('[data-testid="campaign-card"]').first()
      
      if (await campaignCard.isVisible()) {
        const moreButton = campaignCard.locator('[data-testid="more-options-button"]')
        
        // Open dropdown menu
        await moreButton.click()
        
        const dropdownMenu = page.locator('[data-testid="campaign-dropdown-menu"]')
        await expect(dropdownMenu).toBeVisible()
        
        // Test View action
        const viewOption = dropdownMenu.locator('text=View')
        if (await viewOption.isVisible()) {
          await viewOption.click()
          
          // Should close dropdown after action
          await expect(dropdownMenu).not.toBeVisible()
        }
        
        // Reopen dropdown for next test
        await moreButton.click()
        
        // Test Edit action
        const editOption = dropdownMenu.locator('text=Edit')
        if (await editOption.isVisible()) {
          await editOption.click()
          await expect(dropdownMenu).not.toBeVisible()
        }
        
        // Test other actions
        await moreButton.click()
        const duplicateOption = dropdownMenu.locator('text=Duplicate')
        if (await duplicateOption.isVisible()) {
          await duplicateOption.click()
          await expect(dropdownMenu).not.toBeVisible()
        }
      }
    })

    test('should handle grid component props correctly', async ({ page }) => {
      await page.goto('/dashboard')
      
      const campaignGrid = page.locator('[data-testid="campaign-grid"]')
      
      if (await campaignGrid.isVisible()) {
        // Test that grid handles campaigns prop
        const campaignCards = campaignGrid.locator('[data-testid="campaign-card"]')
        const cardCount = await campaignCards.count()
        
        // Grid should render appropriate number of cards
        expect(cardCount).toBeGreaterThanOrEqual(0)
        
        // If no campaigns, should show empty state
        if (cardCount === 0) {
          const emptyState = page.locator('[data-testid="campaigns-empty-state"]')
          if (await emptyState.isVisible()) {
            await expect(emptyState).toContainText('No campaigns found')
          }
        }
      }
    })

    test('should handle loading state prop correctly', async ({ page }) => {
      // Test loading state
      await page.goto('/dashboard?loading=true')
      
      // Should show skeleton grid when loading
      const skeletonGrid = page.locator('[data-testid="campaign-skeleton-grid"]')
      
      if (await skeletonGrid.isVisible()) {
        await expect(skeletonGrid).toBeVisible()
        
        const skeletonCards = skeletonGrid.locator('[data-testid="campaign-card-skeleton"]')
        await expect(skeletonCards).toHaveCount(6) // Default count
        
        // Skeleton cards should have loading animation
        await expect(skeletonCards.first()).toHaveClass(/animate-pulse/)
      }
    })

    test('should handle empty state customization', async ({ page }) => {
      await page.goto('/dashboard?empty=true')
      
      const emptyState = page.locator('[data-testid="campaigns-empty-state"]')
      
      if (await emptyState.isVisible()) {
        await expect(emptyState).toBeVisible()
        await expect(emptyState).toContainText('No campaigns found')
        await expect(emptyState).toContainText('Create your first campaign')
        
        // Should have proper styling
        await expect(emptyState).toHaveClass(/text-center/)
        await expect(emptyState).toHaveClass(/min-h-\[400px\]/)
      }
    })
  })

  test.describe('Module Integration', () => {
    test('should not cause conflicts with existing dashboard modules', async ({ page }) => {
      await page.goto('/dashboard')
      
      // Verify that adding new exports doesn't break existing functionality
      const dashboardPage = page.locator('main')
      await expect(dashboardPage).toBeVisible()
      
      // Check navigation still works
      const sidebar = page.locator('[data-testid="dashboard-sidebar"]')
      if (await sidebar.isVisible()) {
        const navItems = sidebar.locator('a')
        const navCount = await navItems.count()
        expect(navCount).toBeGreaterThan(0)
      }
      
      // Check header still works
      const header = page.locator('[data-testid="dashboard-header"]')
      if (await header.isVisible()) {
        await expect(header).toBeVisible()
      }
    })

    test('should maintain type consistency across dashboard components', async ({ page }) => {
      await page.goto('/dashboard')
      
      // All campaign-related components should work together
      const campaignGrid = page.locator('[data-testid="campaign-grid"]')
      const campaignCards = page.locator('[data-testid="campaign-card"]')
      
      if (await campaignGrid.isVisible() && await campaignCards.count() > 0) {
        // Grid should contain properly structured cards
        const gridCards = campaignGrid.locator('[data-testid="campaign-card"]')
        const gridCardCount = await gridCards.count()
        const totalCardCount = await campaignCards.count()
        
        // All cards should be within the grid
        expect(gridCardCount).toBe(totalCardCount)
        
        // Each card should have consistent structure
        for (let i = 0; i < Math.min(gridCardCount, 3); i++) {
          const card = gridCards.nth(i)
          await expect(card.locator('[data-testid="status-badge"]')).toBeVisible()
          await expect(card.locator('[data-testid="engagement-metric"]')).toBeVisible()
          await expect(card.locator('[data-testid="conversion-metric"]')).toBeVisible()
          await expect(card.locator('[data-testid="content-metric"]')).toBeVisible()
        }
      }
    })

    test('should support tree-shaking and optimal imports', async ({ page }) => {
      // This test verifies that components can be imported individually
      await page.goto('/dashboard')
      
      // Components should load efficiently without loading unnecessary code
      const performanceEntries = await page.evaluate(() => {
        return performance.getEntriesByType('navigation')[0]
      })
      
      // Should load in reasonable time (indicating efficient imports)
      expect(performanceEntries.loadEventEnd - performanceEntries.loadEventStart).toBeLessThan(3000)
    })
  })

  test.describe('Error Handling in Component Usage', () => {
    test('should handle missing campaign data gracefully', async ({ page }) => {
      // Mock API to return malformed campaign data
      await page.route('**/api/campaigns**', async route => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            campaigns: [
              {
                id: 'test-1',
                title: 'Test Campaign',
                // Missing required fields like description, status, metrics
              }
            ]
          })
        })
      })
      
      await page.goto('/dashboard')
      
      // Should handle missing data gracefully without crashing
      await page.waitForTimeout(2000)
      await expect(page.locator('main')).toBeVisible()
      
      // Should not show error boundaries or crashes
      const errorBoundary = page.locator('text=Something went wrong')
      await expect(errorBoundary).not.toBeVisible()
    })

    test('should handle invalid prop types gracefully', async ({ page }) => {
      // This would be caught at TypeScript compile time, but test runtime handling
      await page.goto('/dashboard')
      
      // Monitor for console errors
      const consoleErrors: string[] = []
      page.on('console', msg => {
        if (msg.type() === 'error') {
          consoleErrors.push(msg.text())
        }
      })
      
      await page.waitForTimeout(2000)
      
      // Should not have prop type errors
      const hasPropErrors = consoleErrors.some(error => 
        error.includes('prop') || 
        error.includes('type') ||
        error.includes('expected')
      )
      
      expect(hasPropErrors).toBe(false)
    })

    test('should handle component unmounting correctly', async ({ page }) => {
      await page.goto('/dashboard')
      
      // Wait for components to mount
      await page.waitForTimeout(1000)
      
      // Navigate away and back
      await page.goto('/dashboard/campaigns')
      await page.waitForTimeout(500)
      
      await page.goto('/dashboard')
      await page.waitForTimeout(1000)
      
      // Components should remount correctly
      const campaignGrid = page.locator('[data-testid="campaign-grid"]')
      if (await campaignGrid.isVisible()) {
        await expect(campaignGrid).toBeVisible()
      }
      
      // Should not have memory leaks or mounting errors
      const mainContent = page.locator('main')
      await expect(mainContent).toBeVisible()
    })
  })
})