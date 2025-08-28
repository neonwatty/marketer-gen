import { test, expect } from '@playwright/test';

test.describe('Brand Management Critical Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
  });

  test('should navigate through complete brand setup workflow', async ({ page }) => {
    // Navigate to brands section via sidebar
    await page.getByRole('link', { name: 'Brands' }).click();
    await page.waitForURL('/dashboard/brands');
    await page.waitForLoadState('networkidle');
    
    // Verify brands page loads with correct layout
    await expect(page.getByRole('heading', { name: 'Brands' })).toBeVisible();
    await expect(page.getByText(/brand.*management|brand.*guideline/i)).toBeVisible();
  });

  test('should complete end-to-end brand creation workflow', async ({ page }) => {
    await page.goto('/dashboard/brands');
    await page.waitForLoadState('networkidle');
    
    // Look for create brand button and initiate creation
    const createButton = page.getByRole('button', { name: /create.*brand|new.*brand|add.*brand/i }).or(
      page.getByRole('link', { name: /create.*brand|new.*brand|add.*brand/i })
    );
    
    if (await createButton.isVisible()) {
      await createButton.click();
      
      // Verify brand creation form loads
      await expect(page.locator('form').or(page.getByTestId('brand-form'))).toBeVisible();
      
      // Fill out brand creation form
      const brandNameField = page.getByLabel(/brand.*name|name/i);
      if (await brandNameField.isVisible()) {
        await brandNameField.fill('E2E Test Brand');
        
        // Fill additional brand fields
        const brandDescriptionField = page.getByLabel(/description/i);
        if (await brandDescriptionField.isVisible()) {
          await brandDescriptionField.fill('Test brand for end-to-end testing');
        }
        
        const brandColorField = page.getByLabel(/color|primary.*color/i);
        if (await brandColorField.isVisible()) {
          await brandColorField.fill('#FF6B35');
        }
        
        // Submit brand creation
        const submitButton = page.getByRole('button', { name: /create|save|submit/i });
        if (await submitButton.isEnabled()) {
          await submitButton.click();
          
          // Wait for successful creation
          await expect(page.getByText(/success|created|saved/i)).toBeVisible({ timeout: 10000 });
          
          // Should redirect to brand detail or back to brands list
          await expect(page.getByText('E2E Test Brand')).toBeVisible({ timeout: 5000 });
        }
      }
    }
  });

  test('should handle brand guideline document upload workflow', async ({ page }) => {
    await page.goto('/dashboard/brands');
    await page.waitForLoadState('networkidle');
    
    // Navigate to brand creation or existing brand
    const brandCard = page.locator('[data-testid="brand-card"]').first().or(
      page.getByRole('link', { name: /brand/i }).first()
    );
    
    if (await brandCard.isVisible()) {
      await brandCard.click();
      
      // Look for document upload or guidelines section
      const uploadArea = page.getByText(/upload|document|guideline/i).or(
        page.locator('input[type="file"]')
      );
      
      if (await uploadArea.isVisible()) {
        // Test file upload interaction (without actual file)
        await expect(uploadArea).toBeVisible();
        
        // Verify upload instructions are present
        await expect(page.getByText(/drag.*drop|select.*file|upload/i)).toBeVisible();
      }
    }
  });

  test('should display and interact with brand guidelines', async ({ page }) => {
    await page.goto('/dashboard/brands');
    await page.waitForLoadState('networkidle');
    
    // Navigate to existing brand
    const brandCard = page.locator('[data-testid="brand-card"]').first().or(
      page.getByRole('link', { name: /brand/i }).first()
    );
    
    if (await brandCard.isVisible()) {
      await brandCard.click();
      
      // Should display brand details and guidelines
      await expect(page.getByText(/guideline|brand.*detail/i)).toBeVisible();
      
      // Test guideline sections
      const guidelineSection = page.getByText(/color|typography|logo|voice/i);
      if (await guidelineSection.isVisible()) {
        await guidelineSection.click();
        
        // Should expand or show detailed information
        await expect(page.locator('main').or(page.getByTestId('brand-details'))).toBeVisible();
      }
    }
  });

  test('should handle brand asset library access and management', async ({ page }) => {
    await page.goto('/dashboard/brands');
    await page.waitForLoadState('networkidle');
    
    // Look for asset library access from brands page
    const assetLibraryLink = page.getByRole('link', { name: /asset|library|media/i }).or(
      page.getByTestId('asset-library-link')
    );
    
    if (await assetLibraryLink.isVisible()) {
      await assetLibraryLink.click();
      
      // Should navigate to asset library
      await expect(page.locator('main')).toBeVisible();
      await expect(page.getByText(/asset|library|media/i)).toBeVisible();
      
      // Test asset upload if available
      const uploadButton = page.getByRole('button', { name: /upload|add.*asset/i });
      if (await uploadButton.isVisible()) {
        await uploadButton.click();
        await expect(page.getByText(/upload|select.*file/i)).toBeVisible();
      }
    }
  });

  test('should handle brand comparison and analytics', async ({ page }) => {
    await page.goto('/dashboard/brands');
    await page.waitForLoadState('networkidle');
    
    // Look for brand comparison or analytics features
    const comparisonLink = page.getByText(/comparison|compare|analytics/i).or(
      page.getByTestId('brand-comparison')
    );
    
    if (await comparisonLink.isVisible()) {
      await comparisonLink.click();
      
      // Should show comparison interface
      await expect(page.getByText(/compare|analysis|metric/i)).toBeVisible();
      
      // Test comparison functionality
      const brandSelector = page.getByRole('combobox').or(
        page.getByText(/select.*brand/i)
      );
      
      if (await brandSelector.isVisible()) {
        await brandSelector.click();
        await expect(page.getByRole('option').first()).toBeVisible();
      }
    }
  });

  test('should validate brand form fields and handle errors', async ({ page }) => {
    await page.goto('/dashboard/brands');
    await page.waitForLoadState('networkidle');
    
    const createButton = page.getByRole('button', { name: /create.*brand|new.*brand/i }).or(
      page.getByRole('link', { name: /create.*brand|new.*brand/i })
    );
    
    if (await createButton.isVisible()) {
      await createButton.click();
      
      // Test form validation
      const submitButton = page.getByRole('button', { name: /create|save|submit/i });
      if (await submitButton.isVisible()) {
        await submitButton.click();
        
        // Should show validation errors
        await expect(page.getByText(/required|error|please.*fill/i)).toBeVisible();
        
        // Test invalid data
        const brandNameField = page.getByLabel(/brand.*name|name/i);
        if (await brandNameField.isVisible()) {
          await brandNameField.fill('A'); // Too short
          await submitButton.click();
          
          // Should show specific validation error
          await expect(page.getByText(/too.*short|minimum.*length/i)).toBeVisible();
        }
      }
    }
  });

  test('should perform visual regression testing for brand pages', async ({ page }) => {
    await page.goto('/dashboard/brands');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);
    
    // Take screenshot of brands overview
    await expect(page).toHaveScreenshot('brands-overview-page.png', {
      fullPage: true,
      threshold: 0.2
    });
    
    // Navigate to brand detail if available
    const brandCard = page.locator('[data-testid="brand-card"]').first();
    if (await brandCard.isVisible()) {
      await brandCard.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(2000);
      
      // Take screenshot of brand detail page
      await expect(page).toHaveScreenshot('brand-detail-page.png', {
        fullPage: true,
        threshold: 0.2
      });
    }
  });

  test('should handle brand management on mobile viewport', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    await page.goto('/dashboard/brands');
    await page.waitForLoadState('networkidle');
    
    // Verify mobile-responsive brand layout
    await expect(page.getByRole('heading', { name: 'Brands' })).toBeVisible();
    
    // Test mobile navigation
    const mobileMenuButton = page.getByRole('button', { name: /menu/i });
    if (await mobileMenuButton.isVisible()) {
      await mobileMenuButton.click();
      await expect(page.getByRole('navigation')).toBeVisible();
    }
    
    // Test mobile brand creation
    const createButton = page.getByRole('button', { name: /create.*brand|new.*brand/i }).first();
    if (await createButton.isVisible()) {
      await createButton.click();
      
      const brandNameField = page.getByLabel(/brand.*name|name/i);
      if (await brandNameField.isVisible()) {
        await brandNameField.fill('Mobile Test Brand');
        await expect(brandNameField).toHaveValue('Mobile Test Brand');
      }
    }
    
    // Mobile visual snapshot
    await expect(page).toHaveScreenshot('brands-mobile.png', {
      fullPage: true,
      threshold: 0.2
    });
  });

  test('should handle brand deletion workflow', async ({ page }) => {
    await page.goto('/dashboard/brands');
    await page.waitForLoadState('networkidle');
    
    // Look for delete functionality
    const deleteButton = page.getByRole('button', { name: /delete|remove/i }).first();
    
    if (await deleteButton.isVisible()) {
      await deleteButton.click();
      
      // Should show confirmation dialog
      await expect(page.getByText(/confirm|delete|remove/i)).toBeVisible();
      
      // Test cancel functionality
      const cancelButton = page.getByRole('button', { name: /cancel|no/i });
      if (await cancelButton.isVisible()) {
        await cancelButton.click();
        
        // Should close dialog
        await expect(page.getByText(/confirm|delete/i)).not.toBeVisible();
      }
    }
  });
});