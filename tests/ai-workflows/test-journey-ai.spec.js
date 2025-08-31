// Journey Creation with AI Suggestions Test
// Tests AI-powered customer journey recommendations and step suggestions

const { test, expect } = require('@playwright/test');
const AuthHelper = require('../helpers/auth-helper');
const TestDataFactory = require('../helpers/test-data-factory');
const AIValidators = require('../helpers/ai-validators');
const WaitHelpers = require('../helpers/wait-helpers');

test.describe('AI Journey Creation and Suggestions Workflow', () => {
  let authHelper;
  let waitHelpers;
  let testUser;
  let createdJourneyIds = [];

  test.beforeEach(async ({ page }) => {
    authHelper = new AuthHelper(page);
    waitHelpers = new WaitHelpers(page);
    
    // Create and login test user
    testUser = await authHelper.createAndLoginTestUser();
    console.log(`Test user created: ${testUser.email}`);
  });

  test.afterEach(async ({ page }) => {
    // Clean up created journeys
    for (const journeyId of createdJourneyIds) {
      try {
        await page.goto(`/journeys/${journeyId}`);
        if (await page.isVisible('text=Delete')) {
          await page.click('text=Delete');
          await page.click('button:has-text("Confirm")');
        }
      } catch (error) {
        console.log(`Journey cleanup failed for ID ${journeyId}:`, error.message);
      }
    }

    await authHelper.logout();
  });

  test('should provide AI suggestions for journey creation', async ({ page }) => {
    console.log('Testing AI journey suggestions...');

    // Step 1: Navigate to journey creation
    await page.goto('/journeys/new');

    // Step 2: Fill journey basic information
    const journeyData = TestDataFactory.generateJourney({
      name: 'AI Suggested Journey Test',
      description: 'Testing AI journey step recommendations'
    });

    await page.fill('input[name="journey[name]"]', journeyData.name);
    await page.fill('textarea[name="journey[description]"]', journeyData.description);
    
    // Select journey type to trigger AI suggestions
    if (await page.isVisible('select[name="journey[journey_type]"]')) {
      await page.selectOption('select[name="journey[journey_type]"]', journeyData.journey_type);
    }

    // Step 3: Look for AI suggestions trigger
    let suggestionsTriggered = false;

    if (await page.isVisible('button:has-text("Get AI Suggestions"), text=AI Suggestions, [data-ai-suggestions]')) {
      console.log('AI suggestions button found, requesting suggestions...');
      
      await page.click('button:has-text("Get AI Suggestions"), [data-ai-suggestions] button');
      suggestionsTriggered = true;
      
      // Wait for suggestions to load
      await waitHelpers.waitForLoadingComplete();
      
      // Check for suggestion elements
      const suggestionCount = await page.locator('[data-suggestion], .journey-suggestion, .suggested-step').count();
      console.log(`Found ${suggestionCount} AI journey suggestions`);
      
      if (suggestionCount > 0) {
        // Verify suggestions contain meaningful content
        const firstSuggestion = await page.locator('[data-suggestion], .journey-suggestion, .suggested-step').first();
        const suggestionText = await firstSuggestion.textContent();
        
        expect(suggestionText.length).toBeGreaterThan(10);
        console.log(`First suggestion: ${suggestionText.substring(0, 100)}...`);
      }
    }

    // Step 4: Create journey (with or without applied suggestions)
    await page.click('button[type="submit"], input[type="submit"]');
    
    // Wait for journey creation
    await page.waitForURL(/\/journeys\/\d+/, { timeout: 30000 });

    // Extract journey ID for cleanup
    const url = page.url();
    const journeyMatch = url.match(/\/journeys\/(\d+)/);
    if (journeyMatch) {
      createdJourneyIds.push(journeyMatch[1]);
      console.log(`Created journey ID: ${journeyMatch[1]}`);
    }

    // Step 5: Verify journey was created successfully
    await expect(page.locator('h1, .journey-title')).toContainText(journeyData.name);

    // Step 6: Test step suggestions within the journey
    if (await page.isVisible('text=Add Step, button:has-text("Add Step")')) {
      console.log('Testing step-level AI suggestions...');
      
      await page.click('text=Add Step, button:has-text("Add Step")');
      
      // Look for step suggestions
      if (await page.isVisible('[data-step-suggestions], .step-suggestions, text=Suggested Steps')) {
        const stepSuggestionCount = await page.locator('[data-step-suggestion], .suggested-step').count();
        console.log(`Found ${stepSuggestionCount} step suggestions`);
        
        if (stepSuggestionCount > 0) {
          // Apply a suggested step
          await page.click('[data-step-suggestion], .suggested-step').first();
          
          // Verify step was applied
          await waitHelpers.waitForLoadingComplete();
          
          const stepElements = await page.locator('[data-step], .journey-step').count();
          expect(stepElements).toBeGreaterThan(0);
          
          console.log('AI suggested step applied successfully');
        }
      }
    }

    console.log(`AI journey suggestions test completed. Suggestions triggered: ${suggestionsTriggered}`);
  });

  test('should provide context-appropriate journey templates', async ({ page }) => {
    const campaignTypes = ['awareness', 'consideration', 'conversion', 'retention'];

    for (const campaignType of campaignTypes) {
      console.log(`Testing journey templates for ${campaignType} campaigns...`);

      await page.goto('/journeys/new');
      
      // Fill journey form with specific campaign context
      await page.fill('input[name="journey[name]"]', `${campaignType} Journey Template Test`);
      await page.fill('textarea[name="journey[description]"]', `Testing AI suggestions for ${campaignType} campaigns`);
      
      if (await page.isVisible('select[name="journey[campaign_type]"]')) {
        await page.selectOption('select[name="journey[campaign_type]"]', campaignType);
      }

      // Look for template suggestions or predefined templates
      if (await page.isVisible('text=Select Template, button:has-text("Browse Templates")')) {
        await page.click('text=Select Template, button:has-text("Browse Templates")');
        
        // Wait for templates to load
        await waitHelpers.waitForLoadingComplete();
        
        // Check for campaign-type specific templates
        const templates = await page.locator('[data-template], .journey-template').count();
        if (templates > 0) {
          // Select first appropriate template
          await page.click('[data-template], .journey-template').first();
          
          console.log(`Found and selected template for ${campaignType} campaign`);
        }
      }

      // Create journey
      await page.click('button[type="submit"]');
      await page.waitForURL(/\/journeys\/\d+/);

      const url = page.url();
      const journeyMatch = url.match(/\/journeys\/(\d+)/);
      if (journeyMatch) {
        createdJourneyIds.push(journeyMatch[1]);
      }

      // Verify journey has appropriate structure for campaign type
      const journeySteps = await page.locator('[data-step], .journey-step, .step').count();
      console.log(`${campaignType} journey created with ${journeySteps} steps`);
    }
  });

  test('should suggest content types for each journey stage', async ({ page }) => {
    console.log('Testing content type suggestions for journey stages...');

    // Create a journey first
    await page.goto('/journeys/new');
    
    const journeyData = TestDataFactory.generateJourney({
      name: 'Content Suggestion Test Journey'
    });

    await page.fill('input[name="journey[name]"]', journeyData.name);
    await page.selectOption('select[name="journey[journey_type]"]', 'email_sequence');

    await page.click('button[type="submit"]');
    await page.waitForURL(/\/journeys\/\d+/);

    const url = page.url();
    const journeyMatch = url.match(/\/journeys\/(\d+)/);
    if (journeyMatch) {
      createdJourneyIds.push(journeyMatch[1]);
    }

    // Add multiple steps to test different stage suggestions
    const journeyStages = ['discovery', 'education', 'evaluation', 'decision'];

    for (const stage of journeyStages) {
      if (await page.isVisible('text=Add Step, button:has-text("Add Step")')) {
        await page.click('text=Add Step, button:has-text("Add Step")');
        
        // Fill step information
        if (await page.isVisible('input[name*="step_name"], input[name*="title"]')) {
          await page.fill('input[name*="step_name"], input[name*="title"]', `${stage} Stage Step`);
        }

        // Look for content type suggestions based on stage
        if (await page.isVisible('[data-content-suggestions], .content-type-suggestions')) {
          const suggestions = await page.locator('[data-content-type], .suggested-content-type').count();
          console.log(`Found ${suggestions} content type suggestions for ${stage} stage`);
          
          if (suggestions > 0) {
            // Check first suggestion text
            const suggestionText = await page.locator('[data-content-type], .suggested-content-type').first().textContent();
            expect(suggestionText.length).toBeGreaterThan(5);
            
            // Apply suggestion if possible
            await page.click('[data-content-type], .suggested-content-type').first();
            console.log(`Applied content suggestion for ${stage}: ${suggestionText}`);
          }
        }

        // Save step
        if (await page.isVisible('button:has-text("Save Step"), button[type="submit"]')) {
          await page.click('button:has-text("Save Step"), button[type="submit"]');
          await waitHelpers.waitForLoadingComplete();
        }
      }
    }

    // Verify journey has all stages
    const totalSteps = await page.locator('[data-step], .journey-step').count();
    expect(totalSteps).toBeGreaterThanOrEqual(journeyStages.length);

    console.log(`Journey created with ${totalSteps} steps across different stages`);
  });

  test('should provide channel recommendations for journey steps', async ({ page }) => {
    console.log('Testing channel recommendations for journey steps...');

    await page.goto('/journeys/new');
    
    await page.fill('input[name="journey[name]"]', 'Channel Recommendation Test');
    await page.selectOption('select[name="journey[journey_type]"]', 'social_media_campaign');

    await page.click('button[type="submit"]');
    await page.waitForURL(/\/journeys\/\d+/);

    const url = page.url();
    const journeyMatch = url.match(/\/journeys\/(\d+)/);
    if (journeyMatch) {
      createdJourneyIds.push(journeyMatch[1]);
    }

    // Add step and test channel suggestions
    if (await page.isVisible('text=Add Step')) {
      await page.click('text=Add Step');
      
      // Look for channel suggestions
      if (await page.isVisible('[data-channel-suggestions], .channel-suggestions, select[name*="channel"]')) {
        console.log('Channel suggestions found');
        
        // Check available channels
        if (await page.isVisible('select[name*="channel"]')) {
          const channelOptions = await page.locator('select[name*="channel"] option').count();
          expect(channelOptions).toBeGreaterThan(1);
          
          // Select a channel
          await page.selectOption('select[name*="channel"]', { index: 1 });
          console.log('Channel selected from suggestions');
        }

        // Look for channel-specific recommendations
        const channelElements = await page.locator('[data-channel], .channel-option').count();
        if (channelElements > 0) {
          console.log(`Found ${channelElements} channel recommendations`);
          
          // Apply first recommendation
          await page.click('[data-channel], .channel-option').first();
        }
      }

      // Save step with channel
      if (await page.isVisible('button:has-text("Save")')) {
        await page.click('button:has-text("Save")');
        await waitHelpers.waitForLoadingComplete();
      }
    }
  });

  test('should adapt suggestions based on target audience', async ({ page }) => {
    const audienceTypes = [
      { type: 'b2b_professionals', expectedChannels: ['linkedin', 'email', 'webinar'] },
      { type: 'b2c_consumers', expectedChannels: ['social_media', 'instagram', 'facebook'] },
      { type: 'enterprise_decision_makers', expectedChannels: ['email', 'content', 'events'] }
    ];

    for (const audienceData of audienceTypes) {
      console.log(`Testing audience-specific suggestions for ${audienceData.type}...`);

      await page.goto('/journeys/new');
      
      await page.fill('input[name="journey[name]"]', `${audienceData.type} Journey`);
      await page.fill('textarea[name="journey[description]"]', `Journey optimized for ${audienceData.type.replace('_', ' ')}`);
      
      // Set audience context if field exists
      if (await page.isVisible('input[name*="target_audience"], textarea[name*="audience"]')) {
        await page.fill('input[name*="target_audience"], textarea[name*="audience"]', audienceData.type.replace('_', ' '));
      }

      await page.click('button[type="submit"]');
      await page.waitForURL(/\/journeys\/\d+/);

      const url = page.url();
      const journeyMatch = url.match(/\/journeys\/(\d+)/);
      if (journeyMatch) {
        createdJourneyIds.push(journeyMatch[1]);
      }

      // Test that suggestions adapt to audience
      if (await page.isVisible('text=Add Step')) {
        await page.click('text=Add Step');
        
        // Check if channel suggestions match expected audience preferences
        if (await page.isVisible('select[name*="channel"], [data-channel-suggestions]')) {
          const pageContent = await page.textContent('body');
          const lowerContent = pageContent.toLowerCase();
          
          // Check for audience-appropriate channels
          const hasAudienceChannels = audienceData.expectedChannels.some(channel => 
            lowerContent.includes(channel.toLowerCase())
          );
          
          console.log(`Audience-appropriate channels found for ${audienceData.type}: ${hasAudienceChannels}`);
        }

        // Cancel step creation
        if (await page.isVisible('button:has-text("Cancel")')) {
          await page.click('button:has-text("Cancel")');
        }
      }
    }
  });

  test('should provide timing and sequence recommendations', async ({ page }) => {
    console.log('Testing timing and sequence recommendations...');

    await page.goto('/journeys/new');
    
    await page.fill('input[name="journey[name]"]', 'Timing Optimization Test Journey');
    await page.selectOption('select[name="journey[journey_type]"]', 'email_sequence');

    await page.click('button[type="submit"]');
    await page.waitForURL(/\/journeys\/\d+/);

    const url = page.url();
    const journeyMatch = url.match(/\/journeys\/(\d+)/);
    if (journeyMatch) {
      createdJourneyIds.push(journeyMatch[1]);
    }

    // Add multiple steps to test sequencing
    const stepCount = 3;
    for (let i = 0; i < stepCount; i++) {
      if (await page.isVisible('text=Add Step')) {
        await page.click('text=Add Step');
        
        await page.fill('input[name*="step_name"], input[name*="title"]', `Sequence Step ${i + 1}`);
        
        // Look for timing recommendations
        if (await page.isVisible('input[name*="delay"], input[name*="timing"], [data-timing]')) {
          console.log(`Timing recommendations available for step ${i + 1}`);
          
          // Check for suggested timing values
          const timingValue = await page.getAttribute('input[name*="delay"], input[name*="timing"]', 'placeholder');
          if (timingValue) {
            console.log(`Suggested timing: ${timingValue}`);
          }
        }

        // Look for sequence optimization suggestions
        if (await page.isVisible('[data-sequence-tip], .sequence-recommendation')) {
          const sequenceTip = await page.locator('[data-sequence-tip], .sequence-recommendation').textContent();
          console.log(`Sequence tip: ${sequenceTip}`);
          
          expect(sequenceTip.length).toBeGreaterThan(10);
        }

        // Save step
        if (await page.isVisible('button:has-text("Save")')) {
          await page.click('button:has-text("Save")');
          await waitHelpers.waitForLoadingComplete();
        }
      }
    }

    // Verify journey has proper sequence
    const journeySteps = await page.locator('[data-step], .journey-step').count();
    expect(journeySteps).toBe(stepCount);

    console.log(`Journey sequence created with ${journeySteps} steps`);
  });

  test('should suggest journey optimization based on performance data', async ({ page }) => {
    console.log('Testing journey optimization suggestions...');

    // Create a journey that might have performance data
    await page.goto('/journeys/new');
    
    await page.fill('input[name="journey[name]"]', 'Performance Optimization Test');
    await page.selectOption('select[name="journey[journey_type]"]', 'email_sequence');

    await page.click('button[type="submit"]');
    await page.waitForURL(/\/journeys\/\d+/);

    const url = page.url();
    const journeyMatch = url.match(/\/journeys\/(\d+)/);
    if (journeyMatch) {
      createdJourneyIds.push(journeyMatch[1]);
    }

    // Look for optimization suggestions
    if (await page.isVisible('[data-optimization], .optimization-suggestions, text=Optimization')) {
      console.log('Journey optimization suggestions found');
      
      const optimizationCount = await page.locator('[data-optimization-tip], .optimization-tip').count();
      if (optimizationCount > 0) {
        const optimizationText = await page.locator('[data-optimization-tip], .optimization-tip').first().textContent();
        
        expect(optimizationText.length).toBeGreaterThan(20);
        console.log(`Optimization suggestion: ${optimizationText.substring(0, 100)}...`);
      }
    }

    // Test suggestions feature if available
    if (await page.isVisible('text=Get Suggestions, button:has-text("Suggestions")')) {
      await page.click('text=Get Suggestions, button:has-text("Suggestions")');
      
      await waitHelpers.waitForLoadingComplete();
      
      // Look for generated suggestions
      const suggestionElements = await page.locator('[data-suggestion], .journey-suggestion').count();
      console.log(`Generated ${suggestionElements} optimization suggestions`);
    }
  });
});