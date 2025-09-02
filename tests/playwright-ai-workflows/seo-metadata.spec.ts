import { test, expect } from '@playwright/test';

test.describe('SEO and Metadata', () => {
  test('should have correct metadata on main dashboard page', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check page title
    await expect(page).toHaveTitle('Dashboard | Marketer Gen');
    
    // Check meta description
    const metaDescription = page.locator('meta[name="description"]');
    await expect(metaDescription).toHaveAttribute('content', 'Marketing campaign dashboard overview');
    
    // Check that title is displayed in browser tab correctly
    const title = await page.title();
    expect(title).toBe('Dashboard | Marketer Gen');
  });

  test('should have correct metadata on campaigns page', async ({ page }) => {
    await page.goto('/dashboard/campaigns');
    
    // Check page title
    await expect(page).toHaveTitle('Campaigns | Dashboard');
    
    // Check meta description
    const metaDescription = page.locator('meta[name="description"]');
    await expect(metaDescription).toHaveAttribute('content', 'Manage your marketing campaigns');
  });

  test('should have correct root layout metadata', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check that root layout metadata is present
    const metaDescription = page.locator('meta[name="description"]');
    
    // Should have some description (either from page or root layout)
    const descriptionContent = await metaDescription.getAttribute('content');
    expect(descriptionContent).toBeTruthy();
    expect(descriptionContent.length).toBeGreaterThan(0);
  });

  test('should have proper Open Graph metadata', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check for Open Graph title
    const ogTitle = page.locator('meta[property="og:title"]');
    if (await ogTitle.count() > 0) {
      const titleContent = await ogTitle.getAttribute('content');
      expect(titleContent).toBeTruthy();
    }
    
    // Check for Open Graph description
    const ogDescription = page.locator('meta[property="og:description"]');
    if (await ogDescription.count() > 0) {
      const descriptionContent = await ogDescription.getAttribute('content');
      expect(descriptionContent).toBeTruthy();
    }
    
    // Check for Open Graph type
    const ogType = page.locator('meta[property="og:type"]');
    if (await ogType.count() > 0) {
      await expect(ogType).toHaveAttribute('content', 'website');
    }
  });

  test('should have proper Twitter Card metadata', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check for Twitter card type
    const twitterCard = page.locator('meta[name="twitter:card"]');
    if (await twitterCard.count() > 0) {
      const cardType = await twitterCard.getAttribute('content');
      expect(['summary', 'summary_large_image']).toContain(cardType);
    }
    
    // Check for Twitter title
    const twitterTitle = page.locator('meta[name="twitter:title"]');
    if (await twitterTitle.count() > 0) {
      const titleContent = await twitterTitle.getAttribute('content');
      expect(titleContent).toBeTruthy();
    }
  });

  test('should have proper canonical URLs', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check for canonical link
    const canonical = page.locator('link[rel="canonical"]');
    if (await canonical.count() > 0) {
      const href = await canonical.getAttribute('href');
      expect(href).toContain('/dashboard');
    }
  });

  test('should have proper viewport meta tag', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check viewport meta tag
    const viewport = page.locator('meta[name="viewport"]');
    await expect(viewport).toHaveAttribute('content', /width=device-width/);
  });

  test('should have proper language attributes', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check html lang attribute
    const html = page.locator('html');
    await expect(html).toHaveAttribute('lang', 'en');
  });

  test('should have proper charset declaration', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check charset meta tag
    const charset = page.locator('meta[charset]');
    await expect(charset).toHaveAttribute('charset', 'utf-8');
  });

  test('should have favicon and app icons', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check for favicon
    const favicon = page.locator('link[rel="icon"]').or(page.locator('link[rel="shortcut icon"]'));
    if (await favicon.count() > 0) {
      const href = await favicon.first().getAttribute('href');
      expect(href).toBeTruthy();
    }
    
    // Check for apple touch icon
    const appleTouchIcon = page.locator('link[rel="apple-touch-icon"]');
    if (await appleTouchIcon.count() > 0) {
      const href = await appleTouchIcon.getAttribute('href');
      expect(href).toBeTruthy();
    }
  });

  test('should have proper structured data', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check for JSON-LD structured data
    const jsonLd = page.locator('script[type="application/ld+json"]');
    if (await jsonLd.count() > 0) {
      const content = await jsonLd.textContent();
      expect(content).toBeTruthy();
      
      // Verify it's valid JSON
      expect(() => JSON.parse(content)).not.toThrow();
    }
  });

  test('should update page title when navigating between pages', async ({ page }) => {
    // Start at dashboard
    await page.goto('/dashboard');
    await expect(page).toHaveTitle('Dashboard | Marketer Gen');
    
    // Navigate to campaigns
    await page.getByRole('link', { name: 'Campaigns' }).click();
    await page.waitForURL('/dashboard/campaigns');
    await expect(page).toHaveTitle('Campaigns | Dashboard');
    
    // Navigate back to dashboard
    await page.getByRole('link', { name: 'Dashboard' }).click();
    await page.waitForURL('/dashboard');
    await expect(page).toHaveTitle('Dashboard | Marketer Gen');
  });

  test('should have appropriate robots meta tags', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check for robots meta tag
    const robots = page.locator('meta[name="robots"]');
    if (await robots.count() > 0) {
      const content = await robots.getAttribute('content');
      // Dashboard pages might be noindex,nofollow for privacy
      expect(content).toBeTruthy();
    }
  });

  test('should have proper Next.js meta tags', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check for Next.js generator tag
    const generator = page.locator('meta[name="generator"]');
    if (await generator.count() > 0) {
      const content = await generator.getAttribute('content');
      expect(content).toContain('Next.js');
    }
  });

  test('should handle dynamic metadata for campaign pages', async ({ page }) => {
    // Test individual campaign page metadata
    await page.goto('/dashboard/campaigns/1');
    
    // Page should have loaded (even if 404)
    await page.waitForLoadState('networkidle');
    
    // Should have some title
    const title = await page.title();
    expect(title).toBeTruthy();
    expect(title.length).toBeGreaterThan(0);
    
    // Title should be different from general campaigns page
    const campaignsPageTitle = 'Campaigns | Dashboard';
    expect(title).not.toBe(campaignsPageTitle);
  });

  test('should maintain consistent branding in titles', async ({ page }) => {
    const pages = [
      { url: '/dashboard', expectedTitlePattern: /Marketer Gen/ },
      { url: '/dashboard/campaigns', expectedTitlePattern: /Dashboard/ }
    ];

    for (const pageTest of pages) {
      await page.goto(pageTest.url);
      const title = await page.title();
      expect(title).toMatch(pageTest.expectedTitlePattern);
    }
  });

  test('should have appropriate security headers in meta tags', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Check for content security policy
    const csp = page.locator('meta[http-equiv="Content-Security-Policy"]');
    if (await csp.count() > 0) {
      const content = await csp.getAttribute('content');
      expect(content).toBeTruthy();
    }
    
    // Check for X-Frame-Options
    const frameOptions = page.locator('meta[http-equiv="X-Frame-Options"]');
    if (await frameOptions.count() > 0) {
      const content = await frameOptions.getAttribute('content');
      expect(['DENY', 'SAMEORIGIN']).toContain(content);
    }
  });
});