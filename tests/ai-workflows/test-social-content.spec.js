// Social Media Content Creation Workflow Test
// Tests AI-powered social media content generation with platform-specific optimization

const { test, expect } = require('@playwright/test');
const AuthHelper = require('../helpers/auth-helper');
const TestDataFactory = require('../helpers/test-data-factory');
const AIValidators = require('../helpers/ai-validators');
const WaitHelpers = require('../helpers/wait-helpers');

test.describe('AI Social Media Content Creation Workflow', () => {
  let authHelper;
  let waitHelpers;
  let testUser;
  let createdContentIds = [];

  test.beforeEach(async ({ page }) => {
    authHelper = new AuthHelper(page);
    waitHelpers = new WaitHelpers(page);
    
    // Create and login test user
    testUser = await authHelper.createAndLoginTestUser();
    console.log(`Test user created: ${testUser.email}`);
  });

  test.afterEach(async ({ page }) => {
    // Clean up created content
    for (const contentId of createdContentIds) {
      try {
        await page.goto(`/generated_contents/${contentId}`);
        if (await page.isVisible('text=Delete')) {
          await page.click('text=Delete');
          await page.click('button:has-text("Confirm")');
        }
      } catch (error) {
        console.log(`Content cleanup failed for ID ${contentId}:`, error.message);
      }
    }

    await authHelper.logout();
  });

  // Test social media content generation for different platforms
  const socialPlatforms = TestDataFactory.getSocialMediaPlatforms();
  
  socialPlatforms.forEach(platform => {
    test(`should generate ${platform.name} content with proper optimization`, async ({ page }) => {
      console.log(`Testing ${platform.name} content generation...`);

      // Step 1: Create a campaign plan first (required for content creation)
      console.log(`🔄 Creating campaign plan for content generation...`);
      await page.goto('/campaign_plans/new');
      
      const campaignData = TestDataFactory.generateCampaignPlan({
        name: `${platform.name} Content Test Campaign`
      });
      
      await page.fill('input[name="campaign_plan[name]"]', campaignData.name);
      await page.selectOption('select[name="campaign_plan[campaign_type]"]', 'awareness');
      await page.selectOption('select[name="campaign_plan[objective]"]', 'increase_brand_awareness');
      await page.fill('textarea[name="campaign_plan[target_audience]"]', campaignData.target_audience);
      
      await page.click('button[type="submit"]');
      await page.waitForURL(/\/campaign_plans\/\d+/);
      
      const campaignUrl = page.url();
      const campaignId = campaignUrl.match(/\/campaign_plans\/(\d+)/)[1];
      console.log(`✅ Created campaign plan ID: ${campaignId}`);

      // Step 2: Navigate to content creation within campaign context
      console.log(`🔄 Navigating to content creation form...`);
      const contentFormUrl = `/campaign_plans/${campaignId}/generated_contents/new`;
      try {
        await page.goto(contentFormUrl);
        console.log(`✅ Successfully navigated to: ${page.url()}`);
      } catch (error) {
        console.log(`❌ Navigation failed: ${error.message}`);
        console.log(`Current URL: ${page.url()}`);
        throw error;
      }

      // Step 3: Fill out content form
      const contentData = TestDataFactory.generateContent({
        title: `${platform.name} Test Post`,
        content_type: 'social_post'
      });

      console.log(`🔄 Filling form with title: ${contentData.title}`);
      try {
        // Wait for form to be ready
        await page.waitForSelector('input[name="generated_content[title]"]', { timeout: 10000 });
        await page.fill('input[name="generated_content[title]"]', contentData.title);
        console.log(`✅ Form title filled successfully`);
      } catch (error) {
        console.log(`❌ Form filling failed: ${error.message}`);
        console.log(`Page title: ${await page.title()}`);
        await page.screenshot({ path: `debug-form-${Date.now()}.png` });
        throw error;
      }
      
      // Select social media content type
      await page.selectOption('select[name="generated_content[content_type]"]', 'social_post');
      
      // Select format variant
      await page.selectOption('select[name="generated_content[format_variant]"]', 'short');
      
      // Leave body content blank for AI generation
      await page.fill('textarea[name="generated_content[body_content]"]', '');

      // Step 3: Generate content
      console.log(`Generating ${platform.name} content...`);
      await page.click('button:has-text("Generate Content")');

      // Step 4: Wait for content generation to complete
      await page.waitForURL(/\/generated_contents\/\d+/, { timeout: 30000 });

      // Extract content ID for cleanup
      const url = page.url();
      const contentMatch = url.match(/\/generated_contents\/(\d+)/);
      if (contentMatch) {
        createdContentIds.push(contentMatch[1]);
      }

      // Step 5: Verify generated content appears
      await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content', {
        timeout: 60000,
        minLength: 10
      });

      // Get generated content
      const generatedContent = await page.$eval(
        'textarea[name="generated_content[body_content]"], .generated-content', 
        el => el.value || el.textContent
      );

      console.log(`Generated content length: ${generatedContent.length} characters`);

      // Step 6: Validate platform-specific requirements
      const validation = AIValidators.validateSocialMediaContent(generatedContent, platform.value);
      
      // Check character limits
      expect(generatedContent.length).toBeLessThanOrEqual(platform.charLimit);
      
      // Verify content quality
      expect(validation.isValid).toBe(true);
      expect(validation.metrics.wordCount).toBeGreaterThan(3);

      // Platform-specific validations
      if (platform.value === 'twitter') {
        // Twitter content should be concise
        expect(generatedContent.length).toBeLessThanOrEqual(280);
        expect(validation.metrics.hashtagCount).toBeGreaterThan(0);
      }

      if (platform.value === 'linkedin') {
        // LinkedIn content can be longer and more professional
        expect(validation.metrics.wordCount).toBeGreaterThan(5);
      }

      console.log(`${platform.name} validation:`, {
        isValid: validation.isValid,
        wordCount: validation.metrics.wordCount,
        hashtagCount: validation.metrics.hashtagCount,
        hasCallToAction: validation.metrics.hasCallToAction
      });

      // Step 7: Test content editing and regeneration
      if (await page.isVisible('text=Regenerate, button:has-text("Regenerate")')) {
        console.log('Testing content regeneration...');
        
        const originalContent = generatedContent;
        await page.click('text=Regenerate, button:has-text("Regenerate")');
        
        // Wait for new content
        await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content', {
          timeout: 60000
        });

        const regeneratedContent = await page.$eval(
          'textarea[name="generated_content[body_content]"], .generated-content',
          el => el.value || el.textContent
        );

        // Verify content changed
        expect(regeneratedContent).not.toBe(originalContent);
        expect(regeneratedContent.length).toBeGreaterThan(10);

        console.log('Content regeneration successful');
      }
    });
  });

  test('should handle different content format variants', async ({ page }) => {
    const formatVariants = ['short', 'medium', 'long'];
    
    for (const variant of formatVariants) {
      console.log(`Testing ${variant} format variant...`);
      
      await page.goto('/generated_contents/new');
      
      // Fill form with specific variant
      await page.fill('input[name="generated_content[title]"]', `Test ${variant} Format`);
      await page.selectOption('select[name="generated_content[content_type]"]', 'social_post');
      await page.selectOption('select[name="generated_content[format_variant]"]', variant);
      await page.fill('textarea[name="generated_content[body_content]"]', '');
      
      await page.click('button:has-text("Generate Content")');
      await page.waitForURL(/\/generated_contents\/\d+/);
      
      // Extract content ID for cleanup
      const url = page.url();
      const contentMatch = url.match(/\/generated_contents\/(\d+)/);
      if (contentMatch) {
        createdContentIds.push(contentMatch[1]);
      }

      // Wait for content generation
      await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');
      
      const content = await page.$eval(
        'textarea[name="generated_content[body_content]"], .generated-content',
        el => el.value || el.textContent
      );

      // Validate format-appropriate length
      const wordCount = content.split(/\s+/).length;
      
      switch (variant) {
        case 'short':
          expect(wordCount).toBeLessThanOrEqual(30);
          break;
        case 'medium':
          expect(wordCount).toBeGreaterThan(20);
          expect(wordCount).toBeLessThanOrEqual(100);
          break;
        case 'long':
          expect(wordCount).toBeGreaterThan(50);
          break;
      }

      console.log(`${variant} format: ${wordCount} words - ✓`);
    }
  });

  test('should generate content within campaign context', async ({ page }) => {
    // Step 1: Create a campaign first
    await page.goto('/campaign_plans/new');
    
    const campaignData = TestDataFactory.generateCampaignPlan({
      name: 'Social Content Test Campaign'
    });

    await page.fill('input[name="campaign_plan[name]"]', campaignData.name);
    await page.selectOption('select[name="campaign_plan[campaign_type]"]', campaignData.campaign_type);
    await page.selectOption('select[name="campaign_plan[objective]"]', campaignData.objective);
    await page.fill('textarea[name="campaign_plan[target_audience]"]', campaignData.target_audience);

    await page.click('button[type="submit"]');
    await page.waitForURL(/\/campaign_plans\/\d+/);

    const campaignUrl = page.url();
    const campaignMatch = campaignUrl.match(/\/campaign_plans\/(\d+)/);
    const campaignId = campaignMatch[1];

    // Step 2: Generate content within campaign context
    await page.goto(`/campaign_plans/${campaignId}/generated_contents/new`);

    // Verify campaign context is shown
    await expect(page.locator('text=' + campaignData.name)).toBeVisible();

    // Fill content form
    await page.fill('input[name="generated_content[title]"]', 'Campaign Context Test Post');
    await page.selectOption('select[name="generated_content[content_type]"]', 'social_post');
    await page.selectOption('select[name="generated_content[format_variant]"]', 'medium');

    await page.click('button:has-text("Generate Content")');
    await page.waitForURL(/\/generated_contents\/\d+/);

    // Extract content ID for cleanup
    const contentUrl = page.url();
    const contentMatch = contentUrl.match(/\/generated_contents\/(\d+)/);
    if (contentMatch) {
      createdContentIds.push(contentMatch[1]);
    }

    // Wait for generation and validate
    await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');
    
    const campaignContextContent = await page.$eval(
      'textarea[name="generated_content[body_content]"], .generated-content',
      el => el.value || el.textContent
    );

    // Validate content incorporates campaign context
    expect(campaignContextContent.length).toBeGreaterThan(20);
    
    // The content should be contextually relevant (basic check)
    const validation = AIValidators.validateContentQuality(campaignContextContent);
    expect(validation.isValid).toBe(true);

    console.log('Campaign context content generated successfully');
  });

  test('should handle content generation errors gracefully', async ({ page }) => {
    await page.goto('/generated_contents/new');
    
    // Fill form with minimal/potentially problematic data
    await page.fill('input[name="generated_content[title]"]', 'Error Test');
    await page.selectOption('select[name="generated_content[content_type]"]', 'social_post');

    // Try to generate without proper setup
    await page.click('button:has-text("Generate Content")');

    // Check for either success or graceful error handling
    try {
      await page.waitForURL(/\/generated_contents\/\d+/, { timeout: 30000 });
      
      // If successful, verify content
      await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content', {
        timeout: 60000
      });
      
      console.log('Content generation succeeded despite minimal input');
    } catch (error) {
      // Check for error message
      const hasErrorMessage = await page.isVisible('.bg-red-50, .alert-error, [data-error]');
      if (hasErrorMessage) {
        console.log('Error handled gracefully with user feedback');
      } else {
        // Check if still on the form page with validation errors
        const currentUrl = page.url();
        if (currentUrl.includes('/new')) {
          console.log('Form validation prevented submission');
        } else {
          throw error;
        }
      }
    }
  });

  test('should support content variants and A/B testing', async ({ page }) => {
    // Create base content
    await page.goto('/generated_contents/new');
    
    await page.fill('input[name="generated_content[title]"]', 'A/B Test Content');
    await page.selectOption('select[name="generated_content[content_type]"]', 'social_post');
    await page.selectOption('select[name="generated_content[format_variant]"]', 'medium');

    await page.click('button:has-text("Generate Content")');
    await page.waitForURL(/\/generated_contents\/\d+/);

    const contentUrl = page.url();
    const contentMatch = contentUrl.match(/\/generated_contents\/(\d+)/);
    if (contentMatch) {
      createdContentIds.push(contentMatch[1]);
    }

    // Wait for initial content
    await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');
    
    const originalContent = await page.$eval(
      'textarea[name="generated_content[body_content]"], .generated-content',
      el => el.value || el.textContent
    );

    // Test variant creation if available
    if (await page.isVisible('text=Create Variants, button:has-text("Create Variants")')) {
      console.log('Testing A/B variant creation...');
      
      await page.click('text=Create Variants, button:has-text("Create Variants")');
      
      // Wait for variants to be generated
      await page.waitForTimeout(5000); // Allow time for variant generation
      
      // Check if variants were created successfully
      const variantElements = await page.locator('[data-variant], .variant-content').count();
      if (variantElements > 0) {
        console.log(`Created ${variantElements} content variants`);
      }
    }

    // Validate original content quality
    const validation = AIValidators.validateSocialMediaContent(originalContent, 'linkedin');
    expect(validation.isValid).toBe(true);

    console.log('Content variants test completed');
  });

  test('should maintain content quality across multiple generations', async ({ page }) => {
    const generationCount = 3;
    const generatedContents = [];

    for (let i = 0; i < generationCount; i++) {
      console.log(`Generation ${i + 1} of ${generationCount}...`);
      
      await page.goto('/generated_contents/new');
      
      await page.fill('input[name="generated_content[title]"]', `Quality Test ${i + 1}`);
      await page.selectOption('select[name="generated_content[content_type]"]', 'social_post');
      await page.selectOption('select[name="generated_content[format_variant]"]', 'medium');

      await page.click('button:has-text("Generate Content")');
      await page.waitForURL(/\/generated_contents\/\d+/);

      const contentUrl = page.url();
      const contentMatch = contentUrl.match(/\/generated_contents\/(\d+)/);
      if (contentMatch) {
        createdContentIds.push(contentMatch[1]);
      }

      // Wait for content and validate
      await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');
      
      const content = await page.$eval(
        'textarea[name="generated_content[body_content]"], .generated-content',
        el => el.value || el.textContent
      );

      generatedContents.push(content);

      // Validate each generation
      const validation = AIValidators.validateContentQuality(content);
      expect(validation.isValid).toBe(true);
      expect(validation.metrics.wordCount).toBeGreaterThan(5);
    }

    // Verify content diversity (not generating identical content)
    const uniqueContents = new Set(generatedContents);
    expect(uniqueContents.size).toBeGreaterThan(1);

    console.log(`Generated ${uniqueContents.size} unique pieces of content out of ${generationCount} attempts`);
  });
});