import { test, expect, Page } from '@playwright/test';

// Visual regression tests for UI components
test.describe('UI Visual Regression Tests', () => {
  // Dashboard Components
  test.describe('Dashboard Components', () => {
    test('dashboard widgets should render consistently', async ({ page, browserName }) => {
      await page.goto('/dashboard');
      
      // Wait for dashboard to load
      await page.waitForSelector('[data-testid="dashboard-widgets"]');
      
      // Hide dynamic content (dates, numbers that change)
      await page.addStyleTag({
        content: `
          [data-testid="dynamic-timestamp"] { visibility: hidden; }
          [data-testid="live-metric"] { visibility: hidden; }
        `
      });
      
      // Screenshot individual widgets
      const widgets = await page.locator('[data-testid="dashboard-widget"]').all();
      
      for (let i = 0; i < widgets.length; i++) {
        await expect(widgets[i]).toHaveScreenshot(`dashboard-widget-${i}-${browserName}.png`);
      }
      
      // Screenshot entire dashboard
      await expect(page.locator('[data-testid="dashboard-widgets"]')).toHaveScreenshot(
        `dashboard-full-${browserName}.png`
      );
    });

    test('navigation should render consistently across breakpoints', async ({ page, browserName }) => {
      await page.goto('/dashboard');
      
      // Test different viewport sizes
      const viewports = [
        { width: 320, height: 568, name: 'mobile' },
        { width: 768, height: 1024, name: 'tablet' },
        { width: 1024, height: 768, name: 'desktop' },
        { width: 1440, height: 900, name: 'large' },
        { width: 2560, height: 1440, name: 'ultrawide' }
      ];
      
      for (const viewport of viewports) {
        await page.setViewportSize({ width: viewport.width, height: viewport.height });
        await page.waitForTimeout(500); // Allow layout to settle
        
        const navigation = page.locator('[data-testid="main-navigation"]');
        await expect(navigation).toHaveScreenshot(
          `navigation-${viewport.name}-${browserName}.png`
        );
      }
    });

    test('metric cards should display correctly with different data states', async ({ page, browserName }) => {
      await page.goto('/dashboard');
      
      // Test loading state
      await page.route('/api/metrics', route => {
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ loading: true })
        });
      });
      
      await page.reload();
      const loadingCard = page.locator('[data-testid="metric-card-loading"]').first();
      await expect(loadingCard).toHaveScreenshot(`metric-card-loading-${browserName}.png`);
      
      // Test error state
      await page.route('/api/metrics', route => {
        route.fulfill({
          status: 500,
          contentType: 'application/json',
          body: JSON.stringify({ error: 'Failed to load metrics' })
        });
      });
      
      await page.reload();
      const errorCard = page.locator('[data-testid="metric-card-error"]').first();
      await expect(errorCard).toHaveScreenshot(`metric-card-error-${browserName}.png`);
      
      // Test normal state with data
      await page.route('/api/metrics', route => {
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            campaigns: { value: 24, trend: 12.5 },
            revenue: { value: 45600, trend: -3.2 },
            conversions: { value: 89, trend: 8.7 }
          })
        });
      });
      
      await page.reload();
      const normalCard = page.locator('[data-testid="metric-card"]').first();
      await expect(normalCard).toHaveScreenshot(`metric-card-normal-${browserName}.png`);
    });
  });

  // Content Editor Components
  test.describe('Content Editor Components', () => {
    test('rich text editor should render consistently', async ({ page, browserName }) => {
      await page.goto('/content/new');
      
      const editor = page.locator('[data-testid="rich-text-editor"]');
      await editor.waitFor({ state: 'visible' });
      
      // Test empty state
      await expect(editor).toHaveScreenshot(`editor-empty-${browserName}.png`);
      
      // Add content and test filled state
      await editor.locator('[contenteditable]').fill('This is test content with **bold** and *italic* text.');
      await expect(editor).toHaveScreenshot(`editor-with-content-${browserName}.png`);
      
      // Test toolbar
      const toolbar = page.locator('[data-testid="editor-toolbar"]');
      await expect(toolbar).toHaveScreenshot(`editor-toolbar-${browserName}.png`);
    });

    test('media manager should render consistently', async ({ page, browserName }) => {
      await page.goto('/content/media');
      
      const mediaManager = page.locator('[data-testid="media-manager"]');
      await mediaManager.waitFor({ state: 'visible' });
      
      // Test empty state
      await expect(mediaManager).toHaveScreenshot(`media-manager-empty-${browserName}.png`);
      
      // Mock media files
      await page.route('/api/media', route => {
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([
            { id: 1, name: 'image1.jpg', type: 'image', url: '/test-image.jpg' },
            { id: 2, name: 'video1.mp4', type: 'video', url: '/test-video.mp4' },
            { id: 3, name: 'document.pdf', type: 'document', url: '/test-doc.pdf' }
          ])
        });
      });
      
      await page.reload();
      await expect(mediaManager).toHaveScreenshot(`media-manager-with-files-${browserName}.png`);
    });

    test('live preview should render across different channels', async ({ page, browserName }) => {
      await page.goto('/content/preview');
      
      const preview = page.locator('[data-testid="live-preview"]');
      await preview.waitFor({ state: 'visible' });
      
      const channels = ['email', 'social', 'web', 'print'];
      
      for (const channel of channels) {
        await page.selectOption('[data-testid="channel-selector"]', channel);
        await page.waitForTimeout(500); // Allow preview to update
        
        await expect(preview).toHaveScreenshot(`preview-${channel}-${browserName}.png`);
      }
    });
  });

  // Campaign Management Components
  test.describe('Campaign Management Components', () => {
    test('campaign table should render with different data states', async ({ page, browserName }) => {
      await page.goto('/campaigns');
      
      const table = page.locator('[data-testid="campaign-table"]');
      await table.waitFor({ state: 'visible' });
      
      // Test with mock data
      await page.route('/api/campaigns', route => {
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([
            { id: 1, name: 'Q4 Campaign', status: 'active', budget: 5000 },
            { id: 2, name: 'Holiday Campaign', status: 'draft', budget: 3000 },
            { id: 3, name: 'Brand Awareness', status: 'paused', budget: 7500 }
          ])
        });
      });
      
      await page.reload();
      await expect(table).toHaveScreenshot(`campaign-table-${browserName}.png`);
      
      // Test selected state
      await page.locator('[data-testid="campaign-checkbox"]').first().check();
      await expect(table).toHaveScreenshot(`campaign-table-selected-${browserName}.png`);
      
      // Test bulk actions
      const bulkActions = page.locator('[data-testid="bulk-actions"]');
      await expect(bulkActions).toHaveScreenshot(`bulk-actions-${browserName}.png`);
    });

    test('campaign form should render consistently', async ({ page, browserName }) => {
      await page.goto('/campaigns/new');
      
      const form = page.locator('[data-testid="campaign-form"]');
      await form.waitFor({ state: 'visible' });
      
      // Test step 1
      await expect(form).toHaveScreenshot(`campaign-form-step1-${browserName}.png`);
      
      // Fill form and move to step 2
      await page.fill('[data-testid="campaign-name"]', 'Test Campaign');
      await page.selectOption('[data-testid="campaign-type"]', 'awareness');
      await page.click('[data-testid="next-step"]');
      
      await expect(form).toHaveScreenshot(`campaign-form-step2-${browserName}.png`);
      
      // Test validation errors
      await page.click('[data-testid="submit-campaign"]');
      await expect(form).toHaveScreenshot(`campaign-form-errors-${browserName}.png`);
    });

    test('filters should render consistently', async ({ page, browserName }) => {
      await page.goto('/campaigns');
      
      const filters = page.locator('[data-testid="campaign-filters"]');
      await filters.waitFor({ state: 'visible' });
      
      // Test default state
      await expect(filters).toHaveScreenshot(`filters-default-${browserName}.png`);
      
      // Test expanded state
      await page.click('[data-testid="expand-filters"]');
      await expect(filters).toHaveScreenshot(`filters-expanded-${browserName}.png`);
      
      // Test with active filters
      await page.selectOption('[data-testid="status-filter"]', 'active');
      await page.fill('[data-testid="date-range-start"]', '2024-01-01');
      await expect(filters).toHaveScreenshot(`filters-active-${browserName}.png`);
    });
  });

  // Analytics Dashboard Components
  test.describe('Analytics Dashboard Components', () => {
    test('interactive charts should render consistently', async ({ page, browserName }) => {
      await page.goto('/analytics');
      
      // Mock chart data
      await page.route('/api/analytics/chart-data', route => {
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            lineChart: [
              { date: '2024-01-01', value: 100 },
              { date: '2024-01-02', value: 150 },
              { date: '2024-01-03', value: 120 }
            ],
            barChart: [
              { category: 'Email', value: 35 },
              { category: 'Social', value: 28 },
              { category: 'Paid', value: 22 }
            ]
          })
        });
      });
      
      await page.reload();
      
      const lineChart = page.locator('[data-testid="line-chart"]');
      await lineChart.waitFor({ state: 'visible' });
      await expect(lineChart).toHaveScreenshot(`line-chart-${browserName}.png`);
      
      const barChart = page.locator('[data-testid="bar-chart"]');
      await barChart.waitFor({ state: 'visible' });
      await expect(barChart).toHaveScreenshot(`bar-chart-${browserName}.png`);
      
      // Test chart interactions
      await lineChart.hover();
      await expect(lineChart).toHaveScreenshot(`line-chart-hover-${browserName}.png`);
    });

    test('time range picker should render consistently', async ({ page, browserName }) => {
      await page.goto('/analytics');
      
      const timePicker = page.locator('[data-testid="time-range-picker"]');
      await timePicker.waitFor({ state: 'visible' });
      
      // Test default state
      await expect(timePicker).toHaveScreenshot(`time-picker-default-${browserName}.png`);
      
      // Test expanded state
      await page.click('[data-testid="time-picker-trigger"]');
      await expect(timePicker).toHaveScreenshot(`time-picker-expanded-${browserName}.png`);
      
      // Test custom range
      await page.click('[data-testid="custom-range"]');
      await expect(timePicker).toHaveScreenshot(`time-picker-custom-${browserName}.png`);
    });
  });

  // Theme System Components
  test.describe('Theme System Components', () => {
    test('theme customizer should render consistently', async ({ page, browserName }) => {
      await page.goto('/settings/theme');
      
      const customizer = page.locator('[data-testid="theme-customizer"]');
      await customizer.waitFor({ state: 'visible' });
      
      // Test light theme
      await expect(customizer).toHaveScreenshot(`theme-customizer-light-${browserName}.png`);
      
      // Switch to dark theme
      await page.click('[data-testid="dark-theme"]');
      await page.waitForTimeout(500); // Allow theme transition
      await expect(customizer).toHaveScreenshot(`theme-customizer-dark-${browserName}.png`);
      
      // Test custom colors
      await page.click('[data-testid="customize-colors"]');
      await expect(customizer).toHaveScreenshot(`theme-customizer-colors-${browserName}.png`);
    });

    test('branding panel should render consistently', async ({ page, browserName }) => {
      await page.goto('/settings/branding');
      
      const branding = page.locator('[data-testid="branding-panel"]');
      await branding.waitFor({ state: 'visible' });
      
      // Test default state
      await expect(branding).toHaveScreenshot(`branding-panel-default-${browserName}.png`);
      
      // Test logo upload area
      const logoUpload = page.locator('[data-testid="logo-upload"]');
      await expect(logoUpload).toHaveScreenshot(`logo-upload-${browserName}.png`);
      
      // Test color picker
      await page.click('[data-testid="primary-color-picker"]');
      const colorPicker = page.locator('[data-testid="color-picker"]');
      await expect(colorPicker).toHaveScreenshot(`color-picker-${browserName}.png`);
    });
  });

  // UX Optimization Components
  test.describe('UX Optimization Components', () => {
    test('loading states should render consistently', async ({ page, browserName }) => {
      await page.goto('/test/loading-states');
      
      // Test spinner
      const spinner = page.locator('[data-testid="loading-spinner"]');
      await expect(spinner).toHaveScreenshot(`loading-spinner-${browserName}.png`);
      
      // Test skeleton
      const skeleton = page.locator('[data-testid="skeleton-loader"]');
      await expect(skeleton).toHaveScreenshot(`skeleton-loader-${browserName}.png`);
      
      // Test progress
      const progress = page.locator('[data-testid="progress-indicator"]');
      await expect(progress).toHaveScreenshot(`progress-indicator-${browserName}.png`);
    });

    test('toast notifications should render consistently', async ({ page, browserName }) => {
      await page.goto('/test/notifications');
      
      // Test different toast types
      const toastTypes = ['success', 'error', 'warning', 'info'];
      
      for (const type of toastTypes) {
        await page.click(`[data-testid="trigger-${type}-toast"]`);
        const toast = page.locator(`[data-testid="toast-${type}"]`);
        await toast.waitFor({ state: 'visible' });
        await expect(toast).toHaveScreenshot(`toast-${type}-${browserName}.png`);
      }
    });

    test('error boundaries should render consistently', async ({ page, browserName }) => {
      await page.goto('/test/error-boundary');
      
      // Trigger error
      await page.click('[data-testid="trigger-error"]');
      
      const errorBoundary = page.locator('[data-testid="error-boundary"]');
      await errorBoundary.waitFor({ state: 'visible' });
      await expect(errorBoundary).toHaveScreenshot(`error-boundary-${browserName}.png`);
    });
  });

  // Responsive Design Tests
  test.describe('Responsive Design', () => {
    const breakpoints = [
      { width: 320, height: 568, name: 'mobile-portrait' },
      { width: 568, height: 320, name: 'mobile-landscape' },
      { width: 768, height: 1024, name: 'tablet-portrait' },
      { width: 1024, height: 768, name: 'tablet-landscape' },
      { width: 1440, height: 900, name: 'desktop' },
      { width: 2560, height: 1440, name: 'ultrawide' }
    ];

    for (const breakpoint of breakpoints) {
      test(`dashboard should render correctly at ${breakpoint.name}`, async ({ page, browserName }) => {
        await page.setViewportSize({ 
          width: breakpoint.width, 
          height: breakpoint.height 
        });
        
        await page.goto('/dashboard');
        await page.waitForSelector('[data-testid="dashboard-widgets"]');
        
        // Allow layout to settle
        await page.waitForTimeout(1000);
        
        await expect(page).toHaveScreenshot(
          `dashboard-${breakpoint.name}-${browserName}.png`,
          { fullPage: true }
        );
      });
    }
  });

  // Dark Theme Tests
  test.describe('Dark Theme', () => {
    test.beforeEach(async ({ page }) => {
      // Set dark theme
      await page.emulateMedia({ colorScheme: 'dark' });
    });

    test('dashboard should render consistently in dark theme', async ({ page, browserName }) => {
      await page.goto('/dashboard');
      await page.waitForSelector('[data-testid="dashboard-widgets"]');
      
      await expect(page).toHaveScreenshot(`dashboard-dark-${browserName}.png`);
    });

    test('forms should render consistently in dark theme', async ({ page, browserName }) => {
      await page.goto('/campaigns/new');
      const form = page.locator('[data-testid="campaign-form"]');
      await form.waitFor({ state: 'visible' });
      
      await expect(form).toHaveScreenshot(`form-dark-${browserName}.png`);
    });
  });

  // High Contrast Tests
  test.describe('High Contrast', () => {
    test.beforeEach(async ({ page }) => {
      // Emulate high contrast mode
      await page.emulateMedia({ forcedColors: 'active' });
    });

    test('dashboard should be readable in high contrast mode', async ({ page, browserName }) => {
      await page.goto('/dashboard');
      await page.waitForSelector('[data-testid="dashboard-widgets"]');
      
      await expect(page).toHaveScreenshot(`dashboard-high-contrast-${browserName}.png`);
    });
  });

  // Print Styles Tests
  test.describe('Print Styles', () => {
    test('dashboard should have proper print styles', async ({ page, browserName }) => {
      await page.goto('/dashboard');
      await page.waitForSelector('[data-testid="dashboard-widgets"]');
      
      // Emulate print media
      await page.emulateMedia({ media: 'print' });
      
      await expect(page).toHaveScreenshot(`dashboard-print-${browserName}.png`);
    });
  });
});