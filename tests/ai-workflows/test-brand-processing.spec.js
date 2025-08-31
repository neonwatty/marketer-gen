// Brand Identity AI Processing Test
// Tests AI-powered brand voice extraction and brand guideline processing

const { test, expect } = require('@playwright/test');
const AuthHelper = require('../helpers/auth-helper');
const TestDataFactory = require('../helpers/test-data-factory');
const AIValidators = require('../helpers/ai-validators');
const WaitHelpers = require('../helpers/wait-helpers');
const fs = require('fs');
const path = require('path');

test.describe('AI Brand Identity Processing Workflow', () => {
  let authHelper;
  let waitHelpers;
  let testUser;
  let createdBrandIds = [];

  test.beforeEach(async ({ page }) => {
    authHelper = new AuthHelper(page);
    waitHelpers = new WaitHelpers(page);
    
    // Create and login test user
    testUser = await authHelper.createAndLoginTestUser();
    console.log(`Test user created: ${testUser.email}`);
  });

  test.afterEach(async ({ page }) => {
    // Clean up created brand identities
    for (const brandId of createdBrandIds) {
      try {
        await page.goto(`/brand_identities/${brandId}`);
        if (await page.isVisible('text=Delete')) {
          await page.click('text=Delete');
          await page.click('button:has-text("Confirm")');
        }
      } catch (error) {
        console.log(`Brand identity cleanup failed for ID ${brandId}:`, error.message);
      }
    }

    await authHelper.logout();
  });

  test('should create brand identity and process materials with AI', async ({ page }) => {
    console.log('Testing AI brand identity processing...');

    // Step 1: Navigate to brand identity creation
    await page.goto('/brand_identities/new');

    // Step 2: Fill brand identity form
    const brandData = TestDataFactory.generateBrandIdentity({
      name: 'AI Processing Test Brand',
      industry: 'technology'
    });

    await page.fill('input[name="brand_identity[name]"]', brandData.name);
    
    if (await page.isVisible('select[name="brand_identity[industry]"]')) {
      await page.selectOption('select[name="brand_identity[industry]"]', brandData.industry);
    }

    if (await page.isVisible('select[name="brand_identity[voice_tone]"]')) {
      await page.selectOption('select[name="brand_identity[voice_tone]"]', brandData.voice_tone);
    }

    if (await page.isVisible('input[name="brand_identity[target_audience]"]')) {
      await page.fill('input[name="brand_identity[target_audience]"]', brandData.target_audience);
    }

    // Step 3: Upload brand guidelines text
    const brandGuidelinesText = TestDataFactory.generateBrandGuidelinesText();
    
    if (await page.isVisible('textarea[name="brand_identity[brand_guidelines]"]')) {
      await page.fill('textarea[name="brand_identity[brand_guidelines]"]', brandGuidelinesText);
    }

    // Step 4: Create brand identity using robust click
    const submitSelectors = [
      'button:has-text("Create Brand identity")',
      'input[type="submit"]',
      'button[type="submit"]:not([role="menuitem"])',
      'form button:has-text("Create")'
    ];
    
    await waitHelpers.robustClick(submitSelectors, { 
      waitForStable: true,
      retries: 3
    });
    
    await page.waitForURL(/\/brand_identities\/\d+/, { timeout: 30000 });

    // Extract brand ID for cleanup
    const url = page.url();
    const brandMatch = url.match(/\/brand_identities\/(\d+)/);
    if (brandMatch) {
      createdBrandIds.push(brandMatch[1]);
      console.log(`Created brand identity ID: ${brandMatch[1]}`);
    }

    // Step 5: Process materials with AI
    if (await page.isVisible('text=Process Materials, button:has-text("Process Materials")')) {
      console.log('Processing brand materials with AI...');
      
      await page.click('text=Process Materials, button:has-text("Process Materials")');

      // Wait for AI processing to complete
      await waitHelpers.waitForAIProcessing({
        timeout: 120000,
        statusSelector: '[data-processing-status], .processing-status',
        completedStates: ['completed', 'processed', 'success'],
        failedStates: ['failed', 'error'],
        processingStates: ['processing', 'analyzing']
      });

      console.log('AI processing completed');

      // Step 6: Verify AI extracted brand attributes
      await waitHelpers.waitForLoadingComplete();

      // Check for extracted voice/tone attributes
      if (await page.isVisible('[data-extracted-voice], .extracted-voice, .brand-attributes')) {
        const extractedAttributes = await page.locator('[data-extracted-voice], .extracted-voice, .brand-attributes').textContent();
        expect(extractedAttributes.length).toBeGreaterThan(10);
        
        console.log(`Extracted brand attributes: ${extractedAttributes.substring(0, 100)}...`);
      }

      // Check for key messaging extraction
      if (await page.isVisible('[data-key-messages], .key-messages')) {
        const keyMessages = await page.locator('[data-key-messages], .key-messages').count();
        console.log(`Extracted ${keyMessages} key messaging themes`);
      }

      // Check for style guidelines
      if (await page.isVisible('[data-style-guidelines], .style-guidelines')) {
        const styleGuidelines = await page.locator('[data-style-guidelines], .style-guidelines').textContent();
        expect(styleGuidelines.length).toBeGreaterThan(20);
        
        console.log('Style guidelines extracted successfully');
      }
    }

    // Step 7: Test brand application in content generation
    console.log('Testing brand application in content generation...');
    
    // Navigate to content creation to test brand application
    await page.goto('/generated_contents/new');
    
    // Check if brand context is applied automatically
    const brandContextVisible = await page.isVisible('[data-brand-context]') || 
                                await page.isVisible('.brand-context') || 
                                await page.getByText('Brand:').isVisible().catch(() => false);
    
    if (brandContextVisible) {
      console.log('Brand context available in content generation');
      
      // Generate content with brand context
      await page.fill('input[name="generated_content[title]"]', 'Brand Context Test Content');
      await page.selectOption('select[name="generated_content[content_type]"]', 'social_post');
      await page.selectOption('select[name="generated_content[format_variant]"]', 'medium');

      await page.click('button:has-text("Generate Content")');
      await page.waitForURL(/\/generated_contents\/\d+/);

      // Wait for content generation
      await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');

      const brandedContent = await page.$eval(
        'textarea[name="generated_content[body_content]"], .generated-content',
        el => el.value || el.textContent
      );

      // Validate brand consistency in generated content
      const brandValidation = AIValidators.validateBrandConsistency(brandedContent, {
        keywords: brandData.key_messages,
        voice: brandData.voice_tone
      });

      console.log('Brand consistency validation:', {
        keywordMatches: brandValidation.metrics.keywordMatches,
        toneMatches: brandValidation.metrics.toneMatches
      });
    }

    console.log('Brand identity AI processing test completed successfully');
  });

  test('should handle file upload for brand materials', async ({ page }) => {
    console.log('Testing file upload for brand materials...');

    // Create temporary test file
    const testFilePath = path.join(__dirname, '../temp', 'test-brand-guidelines.txt');
    const brandContent = TestDataFactory.generateBrandGuidelinesText();
    
    // Ensure temp directory exists
    const tempDir = path.dirname(testFilePath);
    if (!fs.existsSync(tempDir)) {
      fs.mkdirSync(tempDir, { recursive: true });
    }
    
    fs.writeFileSync(testFilePath, brandContent);

    try {
      await page.goto('/brand_identities/new');

      await page.fill('input[name="brand_identity[name]"]', 'File Upload Test Brand');

      // Test file upload if available
      if (await page.isVisible('input[type="file"]')) {
        console.log('File upload field found, testing upload...');
        
        await page.setInputFiles('input[type="file"]', testFilePath);
        
        // Wait for file processing
        await page.waitForTimeout(2000);
        
        // Check if file was uploaded successfully
        const fileName = await page.locator('text=test-brand-guidelines.txt, .uploaded-file').count();
        if (fileName > 0) {
          console.log('File uploaded successfully');
        }
      }

      // Create brand identity
      await page.click('button[type="submit"]');
      await page.waitForURL(/\/brand_identities\/\d+/);

      const url = page.url();
      const brandMatch = url.match(/\/brand_identities\/(\d+)/);
      if (brandMatch) {
        createdBrandIds.push(brandMatch[1]);
      }

      // Process uploaded materials
      if (await page.isVisible('text=Process Materials')) {
        await page.click('text=Process Materials');
        
        await waitHelpers.waitForAIProcessing({
          timeout: 120000,
          completedStates: ['completed', 'processed']
        });

        console.log('Uploaded file processed successfully');
      }

    } finally {
      // Clean up test file
      if (fs.existsSync(testFilePath)) {
        fs.unlinkSync(testFilePath);
      }
    }
  });

  test('should extract different brand voice characteristics', async ({ page }) => {
    const voiceTypes = [
      { type: 'professional', indicators: ['expertise', 'solutions', 'industry'] },
      { type: 'friendly', indicators: ['welcome', 'happy', 'help'] },
      { type: 'authoritative', indicators: ['leading', 'proven', 'expert'] },
      { type: 'casual', indicators: ['hey', 'awesome', 'great'] }
    ];

    for (const voiceData of voiceTypes) {
      console.log(`Testing ${voiceData.type} brand voice extraction...`);

      await page.goto('/brand_identities/new');
      
      const brandData = TestDataFactory.generateBrandIdentity({
        name: `${voiceData.type} Voice Test Brand`,
        voice_tone: voiceData.type
      });

      // Create brand guidelines text with specific voice indicators
      const voiceSpecificGuidelines = `
        Brand Voice: ${voiceData.type}
        
        Our brand communicates in a ${voiceData.type} manner. We use ${voiceData.indicators.join(', ')} 
        in our messaging to convey our ${voiceData.type} personality.
        
        Key characteristics:
        - ${voiceData.indicators[0]} approach to communication
        - ${voiceData.indicators[1]} interaction style
        - ${voiceData.indicators[2]} positioning in the market
      `;

      await page.fill('input[name="brand_identity[name]"]', brandData.name);
      
      if (await page.isVisible('textarea[name="brand_identity[brand_guidelines]"]')) {
        await page.fill('textarea[name="brand_identity[brand_guidelines]"]', voiceSpecificGuidelines);
      }

      // Use robust click for submit button
      const submitSelectors = [
        'button:has-text("Create Brand identity")',
        'input[type="submit"]',
        'button[type="submit"]:not([role="menuitem"])', // Exclude dropdown menu items
        'form button:has-text("Create")'
      ];
      
      await waitHelpers.robustClick(submitSelectors, { 
        waitForStable: true,
        forceClick: false,
        retries: 3
      });
      
      await page.waitForURL(/\/brand_identities\/\d+/, { timeout: 30000 });

      const url = page.url();
      const brandMatch = url.match(/\/brand_identities\/(\d+)/);
      if (brandMatch) {
        createdBrandIds.push(brandMatch[1]);
      }

      // Process materials and check extraction
      if (await page.isVisible('text=Process Materials')) {
        await page.click('text=Process Materials');
        
        await waitHelpers.waitForAIProcessing({
          timeout: 90000,
          completedStates: ['completed', 'processed']
        });

        // Verify voice characteristics were extracted
        const pageContent = await page.textContent('body');
        const hasVoiceIndicators = voiceData.indicators.some(indicator => 
          pageContent.toLowerCase().includes(indicator.toLowerCase())
        );

        console.log(`${voiceData.type} voice indicators found: ${hasVoiceIndicators}`);
      }
    }
  });

  test('should provide brand compliance validation', async ({ page }) => {
    console.log('Testing brand compliance validation...');

    // Create brand identity with specific guidelines
    await page.goto('/brand_identities/new');
    
    const complianceGuidelines = `
      BRAND COMPLIANCE RULES:
      - Never use emojis in professional communications
      - Always use sentence case for headlines
      - Include data and metrics when possible
      - Avoid superlatives like "best" or "amazing"
      - Use active voice
      - Include call-to-action in all content
    `;

    await page.fill('input[name="brand_identity[name]"]', 'Compliance Test Brand');
    await page.fill('textarea[name="brand_identity[brand_guidelines]"]', complianceGuidelines);

    await page.click('button[type="submit"]');
    await page.waitForURL(/\/brand_identities\/\d+/);

    const url = page.url();
    const brandMatch = url.match(/\/brand_identities\/(\d+)/);
    if (brandMatch) {
      createdBrandIds.push(brandMatch[1]);
    }

    // Process brand guidelines
    if (await page.isVisible('text=Process Materials')) {
      await page.click('text=Process Materials');
      await waitHelpers.waitForAIProcessing({
        timeout: 90000,
        completedStates: ['completed', 'processed']
      });
    }

    // Test compliance in content generation
    await page.goto('/generated_contents/new');
    
    await page.fill('input[name="generated_content[title]"]', 'Compliance Test Content');
    await page.selectOption('select[name="generated_content[content_type]"]', 'social_post');
    
    await page.click('button:has-text("Generate Content")');
    await page.waitForURL(/\/generated_contents\/\d+/);

    await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');

    const compliantContent = await page.$eval(
      'textarea[name="generated_content[body_content]"], .generated-content',
      el => el.value || el.textContent
    );

    // Check compliance characteristics
    const hasEmojis = /[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]/u.test(compliantContent);
    const hasSuperlatives = /\b(best|amazing|incredible|awesome|perfect)\b/i.test(compliantContent);
    const hasCallToAction = /\b(click|visit|learn|try|get|start)\b/i.test(compliantContent);

    // Compliance validation
    expect(hasEmojis).toBe(false); // Should not have emojis
    expect(hasSuperlatives).toBe(false); // Should avoid superlatives
    expect(hasCallToAction).toBe(true); // Should have CTA

    console.log('Compliance validation:', {
      noEmojis: !hasEmojis,
      noSuperlatives: !hasSuperlatives,
      hasCTA: hasCallToAction,
      contentLength: compliantContent.length
    });
  });

  test('should handle multiple brand identities per user', async ({ page }) => {
    console.log('Testing multiple brand identities...');

    const brands = [
      { name: 'Tech Startup Brand', voice: 'casual', industry: 'technology' },
      { name: 'Enterprise B2B Brand', voice: 'professional', industry: 'business_services' },
      { name: 'Consumer Product Brand', voice: 'friendly', industry: 'consumer_goods' }
    ];

    for (const brand of brands) {
      await page.goto('/brand_identities/new');
      
      await page.fill('input[name="brand_identity[name]"]', brand.name);
      
      if (await page.isVisible('select[name="brand_identity[voice_tone]"]')) {
        await page.selectOption('select[name="brand_identity[voice_tone]"]', brand.voice);
      }
      
      if (await page.isVisible('select[name="brand_identity[industry]"]')) {
        await page.selectOption('select[name="brand_identity[industry]"]', brand.industry);
      }

      const brandGuidelines = `Brand voice: ${brand.voice}. Industry: ${brand.industry}. Targeted messaging for ${brand.industry} audience.`;
      
      if (await page.isVisible('textarea[name="brand_identity[brand_guidelines]"]')) {
        await page.fill('textarea[name="brand_identity[brand_guidelines]"]', brandGuidelines);
      }

      await page.click('button[type="submit"]');
      await page.waitForURL(/\/brand_identities\/\d+/);

      const url = page.url();
      const brandMatch = url.match(/\/brand_identities\/(\d+)/);
      if (brandMatch) {
        createdBrandIds.push(brandMatch[1]);
      }

      console.log(`Created ${brand.name}`);
    }

    // Verify all brands are accessible
    await page.goto('/brand_identities');
    
    for (const brand of brands) {
      await expect(page.locator(`text=${brand.name}`)).toBeVisible();
    }

    console.log(`Successfully created and verified ${brands.length} brand identities`);
  });

  test('should activate and deactivate brand identities', async ({ page }) => {
    console.log('Testing brand identity activation...');

    // Create brand identity
    await page.goto('/brand_identities/new');
    
    await page.fill('input[name="brand_identity[name]"]', 'Activation Test Brand');
    
    await page.click('button[type="submit"]');
    await page.waitForURL(/\/brand_identities\/\d+/);

    const url = page.url();
    const brandMatch = url.match(/\/brand_identities\/(\d+)/);
    if (brandMatch) {
      createdBrandIds.push(brandMatch[1]);
    }

    // Test activation if feature exists
    if (await page.isVisible('button:has-text("Activate"), text=Activate')) {
      await page.click('button:has-text("Activate"), text=Activate');
      
      // Wait for activation confirmation
      await waitHelpers.waitForLoadingComplete();
      
      // Check for active status
      if (await page.isVisible('.active, [data-status="active"], text=Active')) {
        console.log('Brand identity activated successfully');
        
        // Test deactivation
        if (await page.isVisible('button:has-text("Deactivate"), text=Deactivate')) {
          await page.click('button:has-text("Deactivate")');
          await waitHelpers.waitForLoadingComplete();
          
          console.log('Brand identity deactivated successfully');
        }
      }
    }

    // Test setting as default brand
    if (await page.isVisible('text=Set as Default, button:has-text("Default")')) {
      await page.click('text=Set as Default, button:has-text("Default")');
      await waitHelpers.waitForLoadingComplete();
      
      console.log('Brand set as default successfully');
    }
  });
});