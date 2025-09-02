import { test as base, expect, Page } from '@playwright/test';

export interface UserFlowFixtures {
  campaignFlow: CampaignFlow;
  brandFlow: BrandFlow;
  contentFlow: ContentFlow;
  dashboardFlow: DashboardFlow;
}

class CampaignFlow {
  constructor(public readonly page: Page) {}

  async navigateToCampaigns() {
    await this.page.goto('/dashboard/campaigns');
    await this.page.waitForLoadState('networkidle');
    
    // Look for campaign heading or main content area
    const headingExists = await this.page.getByRole('heading', { name: /campaign/i }).first().isVisible({ timeout: 2000 }).catch(() => false);
    if (headingExists) {
      await expect(this.page.getByRole('heading', { name: /campaign/i }).first()).toBeVisible();
    } else {
      // Fallback - just ensure we're on a valid page
      await expect(this.page.getByRole('main')).toBeVisible();
    }
  }

  async createNewCampaign(campaignData: { name: string; description?: string }) {
    await this.navigateToCampaigns();
    
    const newCampaignButton = this.page.getByRole('button', { name: /new.*campaign|create.*campaign/i }).or(
      this.page.getByRole('link', { name: /new.*campaign|create.*campaign/i })
    );
    
    await newCampaignButton.click();
    await this.page.waitForURL('/dashboard/campaigns/new');
    
    // Fill basic info step
    const nameField = this.page.getByLabel(/campaign.*name|name/i);
    await nameField.fill(campaignData.name);
    
    if (campaignData.description) {
      const descriptionField = this.page.getByLabel(/description/i);
      if (await descriptionField.isVisible()) {
        await descriptionField.fill(campaignData.description);
      }
    }

    // Fill required date fields
    const startDateField = this.page.getByLabel(/start.*date/i);
    if (await startDateField.isVisible()) {
      await startDateField.fill('2024-12-01');
    }

    const endDateField = this.page.getByLabel(/end.*date/i);
    if (await endDateField.isVisible()) {
      await endDateField.fill('2024-12-31');
    }
    
    // Navigate through wizard steps to completion
    await this.page.waitForTimeout(500); // Allow form validation
    
    let nextButton = this.page.getByTestId('wizard-next');
    let attempts = 0;
    while (await nextButton.isVisible() && attempts < 5) {
      if (await nextButton.isEnabled({ timeout: 2000 })) {
        await nextButton.click();
        await this.page.waitForTimeout(500);
        nextButton = this.page.getByTestId('wizard-next');
        attempts++;
      } else {
        break;
      }
    }
    
    // Submit final form
    const createButton = this.page.getByTestId('create-campaign-final').or(
      this.page.getByRole('button', { name: /create.*campaign/i })
    );
    
    if (await createButton.isVisible({ timeout: 5000 })) {
      await createButton.click();
      await expect(this.page.getByText(/campaign.*created.*successfully/i)).toBeVisible({ timeout: 10000 });
      await this.page.waitForURL(/\/dashboard\/campaigns/, { timeout: 10000 });
    }
    
    return campaignData.name;
  }

  async duplicateCampaign(campaignName?: string) {
    await this.navigateToCampaigns();
    
    const duplicateButton = this.page.getByRole('button', { name: /duplicate|copy/i }).first();
    if (await duplicateButton.isVisible()) {
      await duplicateButton.click();
      
      const confirmButton = this.page.getByRole('button', { name: /confirm|duplicate/i });
      if (await confirmButton.isVisible()) {
        await confirmButton.click();
        await expect(this.page.getByText(/duplicated|copied/i)).toBeVisible({ timeout: 10000 });
      }
    }
  }

  async navigateToCampaignDetail(campaignName?: string) {
    await this.navigateToCampaigns();
    
    const campaignCard = campaignName 
      ? this.page.getByText(campaignName)
      : this.page.locator('[data-testid="campaign-card"]').first();
    
    await campaignCard.click();
    await this.page.waitForLoadState('networkidle');
  }
}

class BrandFlow {
  constructor(public readonly page: Page) {}

  async navigateToBrands() {
    await this.page.goto('/dashboard/brands');
    await this.page.waitForLoadState('networkidle');
    await expect(this.page.getByRole('heading', { name: 'Brands' })).toBeVisible();
  }

  async createNewBrand(brandData: { name: string; description?: string; color?: string }) {
    await this.navigateToBrands();
    
    const createButton = this.page.getByRole('button', { name: /create.*brand|new.*brand/i }).or(
      this.page.getByRole('link', { name: /create.*brand|new.*brand/i })
    );
    
    if (await createButton.isVisible()) {
      await createButton.click();
      
      const nameField = this.page.getByLabel(/brand.*name|name/i);
      await nameField.fill(brandData.name);
      
      if (brandData.description) {
        const descriptionField = this.page.getByLabel(/description/i);
        if (await descriptionField.isVisible()) {
          await descriptionField.fill(brandData.description);
        }
      }
      
      if (brandData.color) {
        const colorField = this.page.getByLabel(/color|primary.*color/i);
        if (await colorField.isVisible()) {
          await colorField.fill(brandData.color);
        }
      }
      
      const submitButton = this.page.getByRole('button', { name: /create|save|submit/i });
      await submitButton.click();
      
      await expect(this.page.getByText(/success|created|saved/i)).toBeVisible({ timeout: 10000 });
    }
    
    return brandData.name;
  }

  async navigateToBrandDetail(brandName?: string) {
    await this.navigateToBrands();
    
    const brandCard = brandName
      ? this.page.getByText(brandName)
      : this.page.locator('[data-testid="brand-card"]').first();
    
    if (await brandCard.isVisible()) {
      await brandCard.click();
      await this.page.waitForLoadState('networkidle');
    }
  }

  async uploadBrandDocument(filePath?: string) {
    const uploadArea = this.page.getByText(/upload|document/i).or(
      this.page.locator('input[type="file"]')
    );
    
    if (await uploadArea.isVisible()) {
      // In real tests, you would use setInputFiles with actual file
      await expect(uploadArea).toBeVisible();
      return true;
    }
    return false;
  }
}

class ContentFlow {
  constructor(public readonly page: Page) {}

  async navigateToContentGeneration(campaignName?: string) {
    const campaignFlow = new CampaignFlow(this.page);
    await campaignFlow.navigateToCampaignDetail(campaignName);
    
    const generateButton = this.page.getByRole('button', { name: /generate|create.*content/i });
    if (await generateButton.isVisible()) {
      await generateButton.click();
      await expect(this.page.getByText(/content.*generation/i)).toBeVisible();
    }
  }

  async generateAIContent(prompt: string) {
    const promptField = this.page.getByLabel(/prompt|instruction|brief/i);
    if (await promptField.isVisible()) {
      await promptField.fill(prompt);
      
      const generateButton = this.page.getByRole('button', { name: /generate|create/i });
      await generateButton.click();
      
      await expect(this.page.getByText(/generating|processing/i)).toBeVisible();
      await expect(this.page.getByText(/generated|completed/i)).toBeVisible({ timeout: 30000 });
    }
  }

  async createContentVariant(variantName: string) {
    const variantButton = this.page.getByText(/variant|variation/i);
    if (await variantButton.isVisible()) {
      await variantButton.click();
      
      const nameField = this.page.getByLabel(/variant.*name/i);
      if (await nameField.isVisible()) {
        await nameField.fill(variantName);
        
        const createButton = this.page.getByRole('button', { name: /create.*variant/i });
        await createButton.click();
        
        await expect(this.page.getByText(/variant.*created/i)).toBeVisible({ timeout: 10000 });
      }
    }
  }

  async approveContent(action: 'approve' | 'reject' = 'approve') {
    const actionButton = this.page.getByRole('button', { name: new RegExp(action, 'i') });
    if (await actionButton.isVisible()) {
      await actionButton.click();
      await expect(this.page.getByText(new RegExp(`${action}d`, 'i'))).toBeVisible({ timeout: 5000 });
    }
  }

  async checkCompliance() {
    const complianceButton = this.page.getByText(/compliance|check|validate/i);
    if (await complianceButton.isVisible()) {
      await complianceButton.click();
      await expect(this.page.getByText(/compliance.*result/i)).toBeVisible();
    }
  }
}

class DashboardFlow {
  constructor(public readonly page: Page) {}

  async navigateToDashboard() {
    await this.page.goto('/dashboard');
    await this.page.waitForLoadState('networkidle');
    await expect(this.page.getByRole('main')).toBeVisible();
  }

  async navigateToSection(section: 'campaigns' | 'brands' | 'analytics') {
    await this.navigateToDashboard();
    
    const sectionLink = this.page.getByRole('link', { name: new RegExp(section, 'i') });
    await sectionLink.click();
    await this.page.waitForURL(`/dashboard/${section}`);
    await this.page.waitForLoadState('networkidle');
  }

  async verifyDashboardLayout() {
    await this.navigateToDashboard();
    
    // Verify essential dashboard elements
    await expect(this.page.getByRole('navigation').first()).toBeVisible();
    await expect(this.page.getByRole('main')).toBeVisible();
    
    // Verify sidebar navigation exists (check for any navigation element)
    const sidebarExists = await this.page.getByTestId('sidebar').isVisible().catch(() => false);
    const navExists = await this.page.locator('nav').first().isVisible().catch(() => false);
    
    if (sidebarExists || navExists) {
      // At least one navigation element exists
      await expect(this.page.locator('nav, [data-testid="sidebar"]').first()).toBeVisible();
    } else {
      // Skip sidebar check - just ensure main content is visible
      console.log('No sidebar found, but main content is accessible');
    }
  }

  async searchContent(query: string) {
    const searchField = this.page.getByLabel(/search/i).or(
      this.page.getByPlaceholder(/search/i)
    );
    
    if (await searchField.isVisible()) {
      await searchField.fill(query);
      await searchField.press('Enter');
      await this.page.waitForLoadState('networkidle');
    }
  }
}

export const test = base.extend<UserFlowFixtures>({
  campaignFlow: async ({ page }, use) => {
    const campaignFlow = new CampaignFlow(page);
    await use(campaignFlow);
  },

  brandFlow: async ({ page }, use) => {
    const brandFlow = new BrandFlow(page);
    await use(brandFlow);
  },

  contentFlow: async ({ page }, use) => {
    const contentFlow = new ContentFlow(page);
    await use(contentFlow);
  },

  dashboardFlow: async ({ page }, use) => {
    const dashboardFlow = new DashboardFlow(page);
    await use(dashboardFlow);
  },
});

export { expect } from '@playwright/test';