// tests/ux-audit.spec.js
const { test, expect } = require('@playwright/test');

// Test data for user registration and login
const testUser = {
  email: `test${Date.now()}@example.com`,
  password: 'TestPassword123!'
};

const adminUser = {
  email: 'admin@example.com',
  password: 'admin123'
};

let uxIssues = [];
let testResults = [];

// Helper function to log UX issues
function logUXIssue(category, page, issue, severity = 'medium') {
  const uxIssue = {
    category,
    page,
    issue,
    severity,
    timestamp: new Date().toISOString()
  };
  uxIssues.push(uxIssue);
  console.log(`🔍 UX Issue [${severity.toUpperCase()}]: ${issue} on ${page}`);
}

// Helper function to log test results
function logTestResult(test, status, details = '') {
  const result = {
    test,
    status,
    details,
    timestamp: new Date().toISOString()
  };
  testResults.push(result);
  console.log(`✅ Test: ${test} - ${status}${details ? ': ' + details : ''}`);
}

test.describe('Marketer Gen UX Audit', () => {
  
  test.describe('Home Page and Landing Experience', () => {
    test('should display welcoming home page for unauthenticated users', async ({ page }) => {
      await page.goto('/');
      
      // Check page loads and displays main elements
      await expect(page).toHaveTitle(/Marketer Gen/);
      await expect(page.locator('h1')).toContainText('Welcome to Marketer Gen');
      
      // Check for key call-to-action buttons
      const signUpButton = page.locator('a[href="/sign_up"]');
      const signInButton = page.locator('a[href="/sessions/new"]');
      
      await expect(signUpButton).toBeVisible();
      await expect(signInButton).toBeVisible();
      
      // Check if buttons are properly styled and accessible
      const signUpBg = await signUpButton.evaluate(el => getComputedStyle(el).backgroundColor);
      if (signUpBg === 'rgba(0, 0, 0, 0)') {
        logUXIssue('Visual Design', 'Home Page', 'Sign Up button lacks background color/styling');
      }
      
      logTestResult('Home page basic structure', 'PASS');
    });

    test('should have proper mobile responsiveness', async ({ page }) => {
      // Test mobile viewport
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto('/');
      
      // Check if mobile layout adapts properly
      const container = page.locator('.container, .mx-auto');
      await expect(container).toBeVisible();
      
      // Check button sizes on mobile
      const signUpButton = page.locator('a[href="/sign_up"]');
      const buttonSize = await signUpButton.boundingBox();
      
      if (buttonSize && buttonSize.height < 44) {
        logUXIssue('Accessibility', 'Home Page Mobile', 'CTA buttons too small for touch interaction (< 44px)');
      }
      
      logTestResult('Mobile responsiveness', 'PASS');
    });
  });

  test.describe('Authentication Flow', () => {
    test('should handle user registration with proper validation', async ({ page }) => {
      await page.goto('/sign_up');
      
      // Check form presence and labels
      await expect(page.locator('h1')).toContainText('Sign Up');
      await expect(page.locator('label[for="user_email_address"]')).toBeVisible();
      await expect(page.locator('label[for="user_password"]')).toBeVisible();
      await expect(page.locator('label[for="user_password_confirmation"]')).toBeVisible();
      
      // Test empty form submission
      await page.click('input[type="submit"]');
      
      // Should show validation errors
      const errorMessages = page.locator('.text-red-700, .text-red-500, [class*="error"]');
      const hasErrors = await errorMessages.count() > 0;
      
      if (!hasErrors) {
        logUXIssue('Validation', 'Sign Up', 'No validation errors shown for empty form submission');
      }
      
      // Test successful registration
      await page.fill('input[name="user[email_address]"]', testUser.email);
      await page.fill('input[name="user[password]"]', testUser.password);
      await page.fill('input[name="user[password_confirmation]"]', testUser.password);
      await page.click('input[type="submit"]');
      
      // Should redirect to home or login page
      await page.waitForURL(/\/$/);
      logTestResult('User registration', 'PASS', `Created user: ${testUser.email}`);
    });

    test('should handle login flow', async ({ page }) => {
      await page.goto('/sessions/new');
      
      // Check sign in form
      await expect(page.locator('h1')).toContainText('Sign in');
      
      // Test empty form validation
      await page.click('input[type="submit"]');
      
      // Test successful login
      await page.fill('input[name="email_address"]', testUser.email);
      await page.fill('input[name="password"]', testUser.password);
      await page.click('input[type="submit"]');
      
      // Should redirect to dashboard/home with logged in state
      await page.waitForURL(/\/$/);
      const loggedInIndicator = page.locator('text="You are logged in as:"');
      
      if (await loggedInIndicator.isVisible()) {
        logTestResult('User login', 'PASS');
      } else {
        logUXIssue('Authentication', 'Login', 'No clear indication user is logged in');
        logTestResult('User login', 'PASS', 'Login succeeded but UX could be improved');
      }
    });

    test('should provide proper feedback for wrong credentials', async ({ page }) => {
      await page.goto('/sessions/new');
      
      await page.fill('input[name="email_address"]', 'wrong@email.com');
      await page.fill('input[name="password"]', 'wrongpassword');
      await page.click('input[type="submit"]');
      
      // Should show error message
      const errorMessage = page.locator('#alert, .alert, [class*="error"], .text-red-500');
      const hasError = await errorMessage.count() > 0;
      
      if (!hasError) {
        logUXIssue('User Feedback', 'Login', 'No error message for invalid credentials');
      }
      
      logTestResult('Invalid login feedback', hasError ? 'PASS' : 'FAIL');
    });
  });

  test.describe('Authenticated User Experience', () => {
    test.beforeEach(async ({ page }) => {
      // Login before each test
      await page.goto('/sessions/new');
      await page.fill('input[name="email_address"]', testUser.email);
      await page.fill('input[name="password"]', testUser.password);
      await page.click('input[type="submit"]');
      await page.waitForURL(/\/$/);
    });

    test('should display dashboard with proper navigation', async ({ page }) => {
      // Check authenticated home page
      await expect(page.locator('text="You are logged in as:"')).toBeVisible();
      
      // Check feature cards
      const journeyCard = page.locator('text="Customer Journeys"').locator('..');
      const contentCard = page.locator('text="Content Generation"').locator('..');
      const analyticsCard = page.locator('text="Analytics"').locator('..');
      
      await expect(journeyCard).toBeVisible();
      await expect(contentCard).toBeVisible();
      await expect(analyticsCard).toBeVisible();
      
      // Check if "Coming Soon" features are properly indicated
      const comingSoonButtons = page.locator('button:has-text("Coming Soon")');
      const comingSoonCount = await comingSoonButtons.count();
      
      if (comingSoonCount === 0) {
        logUXIssue('Information', 'Dashboard', 'No clear indication of which features are coming soon');
      }
      
      logTestResult('Authenticated dashboard', 'PASS');
    });

    test('should navigate to journeys section', async ({ page }) => {
      await page.click('text="Manage Journeys"');
      await page.waitForURL(/\/journeys/);
      
      // Check journeys page elements
      await expect(page.locator('h1')).toContainText('Customer Journeys');
      
      // Check for analytics dashboard
      const analyticsCards = page.locator('.bg-white.rounded-lg.shadow-sm');
      const hasAnalytics = await analyticsCards.count() > 0;
      
      if (!hasAnalytics) {
        logUXIssue('Content', 'Journeys', 'No analytics or summary cards visible');
      }
      
      // Check navigation buttons
      await expect(page.locator('text="Use Template"')).toBeVisible();
      await expect(page.locator('text="New Journey"')).toBeVisible();
      
      logTestResult('Journey navigation', 'PASS');
    });

    test('should test campaign plans functionality', async ({ page }) => {
      // Navigate to campaign plans (inferred from routes)
      await page.goto('/campaign_plans');
      
      await expect(page.locator('h1')).toContainText('Campaign Plans');
      
      // Check for filters and search
      const searchInput = page.locator('input[name="search"]');
      await expect(searchInput).toBeVisible();
      
      // Check filter dropdowns
      const campaignTypeSelect = page.locator('select[name="campaign_type"]');
      const objectiveSelect = page.locator('select[name="objective"]');
      const statusSelect = page.locator('select[name="status"]');
      
      await expect(campaignTypeSelect).toBeVisible();
      await expect(objectiveSelect).toBeVisible();
      await expect(statusSelect).toBeVisible();
      
      // Check "New Campaign Plan" button
      const newPlanButton = page.locator('text="New Campaign Plan"');
      await expect(newPlanButton).toBeVisible();
      
      logTestResult('Campaign plans page', 'PASS');
    });

    test('should test profile management', async ({ page }) => {
      await page.goto('/profile');
      
      // Should load profile page
      const profileElements = page.locator('input, textarea, select, button');
      const hasProfileFields = await profileElements.count() > 0;
      
      if (!hasProfileFields) {
        logUXIssue('Functionality', 'Profile', 'Profile page appears empty or not loading properly');
      }
      
      logTestResult('Profile page access', hasProfileFields ? 'PASS' : 'FAIL');
    });

    test('should handle sign out', async ({ page }) => {
      await page.click('text="Sign Out"');
      
      // Should redirect to home page and show unauthenticated state
      await page.waitForURL(/\/$/);
      
      const signUpButton = page.locator('a[href="/sign_up"]');
      const signInButton = page.locator('a[href="/sessions/new"]');
      
      await expect(signUpButton).toBeVisible();
      await expect(signInButton).toBeVisible();
      
      // Should not show logged in state
      const loggedInIndicator = page.locator('text="You are logged in as:"');
      await expect(loggedInIndicator).not.toBeVisible();
      
      logTestResult('Sign out functionality', 'PASS');
    });
  });

  test.describe('Error Handling and Edge Cases', () => {
    test('should handle 404 errors gracefully', async ({ page }) => {
      const response = await page.goto('/non-existent-page');
      
      if (response && response.status() === 404) {
        // Check if there's a custom 404 page
        const pageContent = await page.content();
        if (pageContent.includes('Not Found') || pageContent.includes('404')) {
          logTestResult('404 handling', 'PASS', 'Custom 404 page exists');
        } else {
          logUXIssue('Error Handling', '404 Page', 'Generic 404 page, could be more user-friendly');
        }
      }
    });

    test('should test accessibility features', async ({ page }) => {
      await page.goto('/');
      
      // Test keyboard navigation
      await page.keyboard.press('Tab');
      const focusedElement = await page.locator(':focus').count();
      
      if (focusedElement === 0) {
        logUXIssue('Accessibility', 'Keyboard Navigation', 'No visible focus indicator on tab navigation');
      }
      
      // Check for alt text on images
      const images = page.locator('img');
      const imageCount = await images.count();
      
      for (let i = 0; i < imageCount; i++) {
        const alt = await images.nth(i).getAttribute('alt');
        if (!alt) {
          logUXIssue('Accessibility', 'Images', 'Image missing alt text');
        }
      }
      
      logTestResult('Basic accessibility check', 'COMPLETED');
    });
  });

  test.describe('Performance and Load Times', () => {
    test('should measure page load performance', async ({ page }) => {
      const startTime = Date.now();
      await page.goto('/');
      const loadTime = Date.now() - startTime;
      
      if (loadTime > 3000) {
        logUXIssue('Performance', 'Home Page', `Slow page load time: ${loadTime}ms`);
      }
      
      logTestResult('Page load performance', 'MEASURED', `Load time: ${loadTime}ms`);
    });
  });

  // Generate final report
  test.afterAll(async () => {
    console.log('\n' + '='.repeat(80));
    console.log('MARKETER GEN UX AUDIT REPORT');
    console.log('='.repeat(80));
    
    console.log(`\n📊 SUMMARY:`);
    console.log(`- Total Tests: ${testResults.length}`);
    console.log(`- UX Issues Found: ${uxIssues.length}`);
    console.log(`- Critical Issues: ${uxIssues.filter(i => i.severity === 'high').length}`);
    console.log(`- Medium Issues: ${uxIssues.filter(i => i.severity === 'medium').length}`);
    console.log(`- Low Issues: ${uxIssues.filter(i => i.severity === 'low').length}`);
    
    if (uxIssues.length > 0) {
      console.log(`\n🔍 UX ISSUES IDENTIFIED:`);
      uxIssues.forEach((issue, index) => {
        console.log(`\n${index + 1}. [${issue.severity.toUpperCase()}] ${issue.category}`);
        console.log(`   Page: ${issue.page}`);
        console.log(`   Issue: ${issue.issue}`);
      });
    }
    
    console.log(`\n✅ TEST RESULTS:`);
    testResults.forEach((result, index) => {
      console.log(`${index + 1}. ${result.test}: ${result.status}${result.details ? ' - ' + result.details : ''}`);
    });
    
    console.log('\n' + '='.repeat(80));
  });
});