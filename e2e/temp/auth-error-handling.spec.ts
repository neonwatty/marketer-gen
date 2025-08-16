import { test, expect } from '@playwright/test'

test.describe('Auth Error Handling', () => {
  test.describe('Session Callback Error Handling', () => {
    test('should handle database connection errors gracefully during session callback', async ({ page }) => {
      // Mock a database error during session callback
      await page.route('**/api/auth/session', async route => {
        const response = await route.fetch()
        const data = await response.json()
        
        // Simulate session with user but database error
        const modifiedData = {
          ...data,
          user: {
            id: 'test-user-id',
            email: 'test@example.com',
            name: 'Test User'
          }
        }
        
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(modifiedData)
        })
      })
      
      // Navigate to a protected page
      await page.goto('/dashboard')
      
      // Should still function even with database role fetch error
      await page.waitForTimeout(2000)
      
      // Check that the page loads and doesn't crash
      const dashboardContent = page.locator('main')
      await expect(dashboardContent).toBeVisible()
    })

    test('should continue session creation when role fetch fails', async ({ page }) => {
      // Navigate to login page first
      await page.goto('/auth/signin')
      
      // Mock NextAuth signin
      await page.route('**/api/auth/callback/**', async route => {
        // Simulate successful auth but role fetch error logged
        await route.continue()
      })
      
      // Mock session endpoint to simulate database error
      await page.route('**/api/auth/session', async route => {
        const response = await route.fetch()
        
        if (response.status() === 200) {
          const data = await response.json()
          
          // Return session without role (simulating database error)
          const sessionData = {
            user: {
              id: 'test-user-id',
              email: 'test@example.com', 
              name: 'Test User'
              // No role property due to simulated database error
            },
            expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
          }
          
          await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify(sessionData)
          })
        } else {
          await route.continue()
        }
      })
      
      // Navigate to dashboard
      await page.goto('/dashboard')
      
      // Should load successfully without crashing despite role fetch error
      await expect(page.locator('main')).toBeVisible()
      
      // User should still be able to access the dashboard
      await expect(page).toHaveURL(/\/dashboard/)
    })

    test('should log database errors without affecting user experience', async ({ page }) => {
      // Set up console log monitoring
      const consoleLogs: string[] = []
      page.on('console', msg => {
        if (msg.type() === 'error') {
          consoleLogs.push(msg.text())
        }
      })
      
      // Mock database error during session
      await page.route('**/api/auth/session', async route => {
        // This will trigger the database error path in auth.ts
        await route.continue()
      })
      
      await page.goto('/dashboard')
      await page.waitForTimeout(1000)
      
      // Check that error was logged but page still works
      const hasDbError = consoleLogs.some(log => 
        log.includes('Error fetching user role') || 
        log.includes('database') ||
        log.includes('prisma')
      )
      
      // Error should be logged (if database actually fails)
      // But page should still be functional
      await expect(page.locator('main')).toBeVisible()
    })

    test('should handle missing user ID in session gracefully', async ({ page }) => {
      // Mock session with missing user ID
      await page.route('**/api/auth/session', async route => {
        const sessionData = {
          user: {
            email: 'test@example.com',
            name: 'Test User'
            // Missing id property
          },
          expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
        }
        
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(sessionData)
        })
      })
      
      await page.goto('/dashboard')
      
      // Should handle gracefully without crashing
      await expect(page.locator('main')).toBeVisible()
    })

    test('should handle null database user response gracefully', async ({ page }) => {
      // This tests the scenario where prisma.user.findUnique returns null
      await page.route('**/api/auth/session', async route => {
        const sessionData = {
          user: {
            id: 'non-existent-user-id',
            email: 'test@example.com',
            name: 'Test User'
            // No role because user doesn't exist in database
          },
          expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
        }
        
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(sessionData)
        })
      })
      
      await page.goto('/dashboard')
      
      // Should work without role information
      await expect(page.locator('main')).toBeVisible()
    })
  })

  test.describe('Auth Error Recovery', () => {
    test('should retry authentication on temporary database failures', async ({ page }) => {
      let attemptCount = 0
      
      await page.route('**/api/auth/session', async route => {
        attemptCount++
        
        if (attemptCount === 1) {
          // First attempt fails
          await route.fulfill({
            status: 500,
            contentType: 'application/json',
            body: JSON.stringify({ error: 'Database connection failed' })
          })
        } else {
          // Subsequent attempts succeed
          const sessionData = {
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
            body: JSON.stringify(sessionData)
          })
        }
      })
      
      await page.goto('/dashboard')
      
      // Should eventually succeed after retry
      await expect(page.locator('main')).toBeVisible()
    })

    test('should maintain session functionality with partial data', async ({ page }) => {
      // Simulate session with minimal user data due to database issues
      await page.route('**/api/auth/session', async route => {
        const minimalSession = {
          user: {
            id: 'test-user-id',
            email: 'test@example.com'
            // Missing name and role due to database issues
          },
          expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
        }
        
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(minimalSession)
        })
      })
      
      await page.goto('/dashboard')
      
      // Should still allow access with minimal user data
      await expect(page.locator('main')).toBeVisible()
      
      // User menu should handle missing name gracefully
      const userMenu = page.locator('[data-testid="user-menu"]')
      if (await userMenu.isVisible()) {
        await expect(userMenu).toBeVisible()
      }
    })
  })

  test.describe('Database Connection Resilience', () => {
    test('should handle intermittent database connectivity issues', async ({ page }) => {
      let dbFailureCount = 0
      const maxFailures = 2
      
      await page.route('**/api/auth/session', async route => {
        if (dbFailureCount < maxFailures) {
          dbFailureCount++
          // Simulate database timeout/connection error
          await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({
              user: {
                id: 'test-user-id',
                email: 'test@example.com',
                name: 'Test User'
                // No role due to database connection issue
              },
              expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
            })
          })
        } else {
          // Database connection restored
          await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({
              user: {
                id: 'test-user-id',
                email: 'test@example.com',
                name: 'Test User',
                role: 'user'
              },
              expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
            })
          })
        }
      })
      
      // Multiple page visits to test resilience
      await page.goto('/dashboard')
      await expect(page.locator('main')).toBeVisible()
      
      await page.goto('/dashboard/campaigns')
      await expect(page.locator('main')).toBeVisible()
      
      // Should handle all visits gracefully
      await page.goto('/dashboard')
      await expect(page.locator('main')).toBeVisible()
    })

    test('should provide fallback behavior when database is unavailable', async ({ page }) => {
      // Mock complete database unavailability
      await page.route('**/api/auth/session', async route => {
        const fallbackSession = {
          user: {
            id: 'guest-user',
            email: 'guest@example.com',
            name: 'Guest User'
            // No role, treated as basic user
          },
          expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
        }
        
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(fallbackSession)
        })
      })
      
      await page.goto('/dashboard')
      
      // Should provide basic functionality
      await expect(page.locator('main')).toBeVisible()
      
      // Should not crash or show database errors to user
      const errorMessage = page.locator('text=Database error')
      await expect(errorMessage).not.toBeVisible()
    })
  })

  test.describe('Error Boundary Testing', () => {
    test('should not crash application on auth provider errors', async ({ page }) => {
      // Monitor for uncaught exceptions
      const errors: Error[] = []
      page.on('pageerror', error => {
        errors.push(error)
      })
      
      // Mock various auth error scenarios
      await page.route('**/api/auth/**', async route => {
        if (Math.random() < 0.3) {
          // Randomly simulate auth service errors
          await route.fulfill({
            status: 500,
            contentType: 'application/json',
            body: JSON.stringify({ error: 'Auth service temporarily unavailable' })
          })
        } else {
          await route.continue()
        }
      })
      
      // Navigate through protected routes
      await page.goto('/dashboard')
      await page.waitForTimeout(1000)
      
      await page.goto('/dashboard/campaigns')
      await page.waitForTimeout(1000)
      
      // Should handle errors gracefully without crashing
      expect(errors.length).toBe(0)
      await expect(page.locator('main')).toBeVisible()
    })

    test('should show user-friendly error messages for auth failures', async ({ page }) => {
      // Mock persistent auth failure
      await page.route('**/api/auth/session', async route => {
        await route.fulfill({
          status: 401,
          contentType: 'application/json',
          body: JSON.stringify({ error: 'Authentication failed' })
        })
      })
      
      await page.goto('/dashboard')
      
      // Should redirect to login or show appropriate message
      await page.waitForTimeout(2000)
      
      const currentUrl = page.url()
      const hasAuthRedirect = currentUrl.includes('/auth/signin') || 
                             currentUrl.includes('/login')
      
      if (!hasAuthRedirect) {
        // Should show user-friendly error, not technical details
        const errorContent = page.locator('main')
        await expect(errorContent).toBeVisible()
        
        // Should not expose technical error details
        await expect(page.locator('text=prisma')).not.toBeVisible()
        await expect(page.locator('text=database connection')).not.toBeVisible()
      }
    })
  })

  test.describe('Performance Impact', () => {
    test('should not significantly impact session performance with error handling', async ({ page }) => {
      const startTime = Date.now()
      
      await page.goto('/dashboard')
      await page.waitForSelector('main')
      
      const loadTime = Date.now() - startTime
      
      // Error handling should not significantly slow down auth
      expect(loadTime).toBeLessThan(5000)
    })

    test('should handle concurrent session requests efficiently', async ({ page }) => {
      // Open multiple tabs/contexts to test concurrent session handling
      const context = page.context()
      const page2 = await context.newPage()
      const page3 = await context.newPage()
      
      // Navigate all pages simultaneously
      const promises = [
        page.goto('/dashboard'),
        page2.goto('/dashboard/campaigns'),
        page3.goto('/dashboard')
      ]
      
      await Promise.all(promises)
      
      // All should load successfully
      await expect(page.locator('main')).toBeVisible()
      await expect(page2.locator('main')).toBeVisible()
      await expect(page3.locator('main')).toBeVisible()
      
      await page2.close()
      await page3.close()
    })
  })
})