import { test, expect } from './fixtures/user-flow-fixtures';

test.describe('Comprehensive User Flow Integration', () => {
  test('should complete full campaign creation to content generation workflow', async ({ 
    campaignFlow, 
    brandFlow, 
    contentFlow, 
    dashboardFlow 
  }) => {
    // Step 1: Verify dashboard is accessible
    await dashboardFlow.verifyDashboardLayout();
    
    // Step 2: Create a new brand for the campaign
    const brandName = await brandFlow.createNewBrand({
      name: 'Integration Test Brand',
      description: 'Test brand for complete E2E workflow',
      color: '#FF6B35'
    });
    
    // Step 3: Create a new campaign
    const campaignName = await campaignFlow.createNewCampaign({
      name: 'Full Integration Test Campaign',
      description: 'Complete end-to-end test campaign workflow'
    });
    
    // Step 4: Navigate to content generation
    await contentFlow.navigateToContentGeneration(campaignName);
    
    // Step 5: Generate AI content
    await contentFlow.generateAIContent('Create engaging marketing content for our product launch');
    
    // Step 6: Create content variant
    await contentFlow.createContentVariant('A/B Test Version');
    
    // Step 7: Check compliance
    await contentFlow.checkCompliance();
    
    // Step 8: Approve content
    await contentFlow.approveContent('approve');
    
    // Verify complete workflow success
    await expect(dashboardFlow.page.getByText(/workflow.*completed|process.*finished/i))
      .toBeVisible({ timeout: 5000 });
  });

  test('should handle brand setup to campaign creation workflow', async ({ 
    brandFlow, 
    campaignFlow, 
    dashboardFlow 
  }) => {
    // Start from dashboard
    await dashboardFlow.navigateToDashboard();
    
    // Create comprehensive brand setup
    const brandName = await brandFlow.createNewBrand({
      name: 'Brand-to-Campaign Test',
      description: 'Testing brand to campaign workflow integration',
      color: '#4A90E2'
    });
    
    // Navigate to brand detail and upload guidelines
    await brandFlow.navigateToBrandDetail(brandName);
    await brandFlow.uploadBrandDocument();
    
    // Create campaign using the brand
    await campaignFlow.navigateToCampaigns();
    const campaignName = await campaignFlow.createNewCampaign({
      name: 'Brand-Integrated Campaign',
      description: 'Campaign using the newly created brand guidelines'
    });
    
    // Verify brand-campaign integration
    await campaignFlow.navigateToCampaignDetail(campaignName);
    await expect(dashboardFlow.page.getByText(brandName)).toBeVisible({ timeout: 5000 });
  });

  test('should handle complete content lifecycle workflow', async ({ 
    campaignFlow, 
    contentFlow, 
    dashboardFlow 
  }) => {
    // Setup: Create campaign for content testing
    await dashboardFlow.navigateToDashboard();
    const campaignName = await campaignFlow.createNewCampaign({
      name: 'Content Lifecycle Test Campaign',
      description: 'Testing complete content creation lifecycle'
    });
    
    // Navigate to content generation
    await contentFlow.navigateToContentGeneration(campaignName);
    
    // Generate multiple content pieces
    await contentFlow.generateAIContent('Create email marketing content');
    await contentFlow.createContentVariant('Email Version A');
    
    await contentFlow.generateAIContent('Create social media content');  
    await contentFlow.createContentVariant('Social Version A');
    
    // Content review and approval workflow
    await contentFlow.checkCompliance();
    await contentFlow.approveContent('approve');
    
    // Verify content workflow completion
    await expect(dashboardFlow.page.getByText(/content.*approved|workflow.*complete/i))
      .toBeVisible({ timeout: 10000 });
  });

  test('should handle cross-browser campaign duplication workflow', async ({ 
    campaignFlow, 
    dashboardFlow 
  }) => {
    // Create original campaign
    await dashboardFlow.navigateToDashboard();
    const originalCampaign = await campaignFlow.createNewCampaign({
      name: 'Original Campaign for Duplication',
      description: 'Campaign that will be duplicated in cross-browser test'
    });
    
    // Duplicate the campaign
    await campaignFlow.duplicateCampaign(originalCampaign);
    
    // Verify duplication success
    await campaignFlow.navigateToCampaigns();
    await expect(dashboardFlow.page.getByText(/duplicate|copy/i)).toBeVisible();
  });

  test('should handle mobile responsive complete user journey', async ({ 
    page,
    campaignFlow, 
    brandFlow, 
    contentFlow, 
    dashboardFlow 
  }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    // Mobile dashboard navigation
    await dashboardFlow.navigateToDashboard();
    
    // Mobile brand creation
    const mobileBrandName = await brandFlow.createNewBrand({
      name: 'Mobile Test Brand',
      description: 'Brand created on mobile viewport'
    });
    
    // Mobile campaign creation
    const mobileCampaignName = await campaignFlow.createNewCampaign({
      name: 'Mobile Test Campaign', 
      description: 'Campaign created on mobile viewport'
    });
    
    // Mobile content generation
    await contentFlow.navigateToContentGeneration(mobileCampaignName);
    await contentFlow.generateAIContent('Mobile content generation test');
    
    // Verify mobile workflow completion
    await expect(page.getByText(/mobile.*workflow|process.*completed/i))
      .toBeVisible({ timeout: 10000 });
    
    // Take mobile visual regression snapshot
    await expect(page).toHaveScreenshot('mobile-complete-workflow.png', {
      fullPage: true,
      threshold: 0.2
    });
  });

  test('should handle error recovery in complete workflow', async ({ 
    page,
    campaignFlow, 
    contentFlow, 
    dashboardFlow 
  }) => {
    // Setup campaign for error testing
    await dashboardFlow.navigateToDashboard();
    const campaignName = await campaignFlow.createNewCampaign({
      name: 'Error Recovery Test Campaign',
      description: 'Testing error recovery in complete workflow'
    });
    
    // Navigate to content generation
    await contentFlow.navigateToContentGeneration(campaignName);
    
    // Simulate network failure during content generation
    await page.route('**/api/ai/**', route => route.abort());
    
    // Attempt content generation (should fail gracefully)
    const promptField = page.getByLabel(/prompt|instruction/i);
    if (await promptField.isVisible()) {
      await promptField.fill('This should fail due to network error');
      
      const generateButton = page.getByRole('button', { name: /generate/i });
      await generateButton.click();
      
      // Should show error message
      await expect(page.getByText(/error|failed|network/i)).toBeVisible({ timeout: 10000 });
    }
    
    // Reset network and retry
    await page.unroute('**/api/ai/**');
    
    // Retry content generation (should succeed)
    const retryButton = page.getByRole('button', { name: /retry|try.*again/i });
    if (await retryButton.isVisible()) {
      await retryButton.click();
      await expect(page.getByText(/generating|processing/i)).toBeVisible();
    }
  });

  test('should perform visual regression testing across complete user flows', async ({ 
    page,
    campaignFlow, 
    brandFlow, 
    contentFlow, 
    dashboardFlow 
  }) => {
    // Dashboard visual snapshot
    await dashboardFlow.navigateToDashboard();
    await page.waitForTimeout(2000);
    await expect(page).toHaveScreenshot('dashboard-complete-flow.png', {
      fullPage: true,
      threshold: 0.2
    });
    
    // Brand creation visual snapshot
    await brandFlow.navigateToBrands();
    await page.waitForTimeout(2000);
    await expect(page).toHaveScreenshot('brands-complete-flow.png', {
      fullPage: true,
      threshold: 0.2
    });
    
    // Campaign creation visual snapshot
    await campaignFlow.navigateToCampaigns();
    await page.waitForTimeout(2000);
    await expect(page).toHaveScreenshot('campaigns-complete-flow.png', {
      fullPage: true,
      threshold: 0.2
    });
    
    // Create campaign for content flow testing
    const testCampaign = await campaignFlow.createNewCampaign({
      name: 'Visual Test Campaign',
      description: 'Campaign for visual regression testing'
    });
    
    // Content generation visual snapshot
    await contentFlow.navigateToContentGeneration(testCampaign);
    await page.waitForTimeout(2000);
    await expect(page).toHaveScreenshot('content-generation-complete-flow.png', {
      fullPage: true,
      threshold: 0.2
    });
  });
});