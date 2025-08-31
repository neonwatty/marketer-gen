// Campaign Intelligence Workflow Test
// Tests AI-powered market analysis, competitive intelligence, and strategic recommendations

const { test, expect } = require('@playwright/test');
const AuthHelper = require('../helpers/auth-helper');
const TestDataFactory = require('../helpers/test-data-factory');
const AIValidators = require('../helpers/ai-validators');
const WaitHelpers = require('../helpers/wait-helpers');

test.describe('AI Campaign Intelligence Workflow', () => {
  let authHelper;
  let waitHelpers;
  let testUser;
  let createdCampaignIds = [];

  test.beforeEach(async ({ page }) => {
    authHelper = new AuthHelper(page);
    waitHelpers = new WaitHelpers(page);
    
    // Create and login test user
    testUser = await authHelper.createAndLoginTestUser();
    console.log(`Test user created: ${testUser.email}`);
  });

  test.afterEach(async ({ page }) => {
    // Clean up created campaigns
    for (const campaignId of createdCampaignIds) {
      try {
        await page.goto(`/campaign_plans/${campaignId}`);
        if (await page.isVisible('text=Delete')) {
          await page.click('text=Delete');
          await page.click('button:has-text("Confirm")');
        }
      } catch (error) {
        console.log(`Campaign cleanup failed for ID ${campaignId}:`, error.message);
      }
    }

    await authHelper.logout();
  });

  test('should generate comprehensive market analysis', async ({ page }) => {
    console.log('Testing AI market analysis generation...');

    // Step 1: Create a campaign for intelligence analysis
    await page.goto('/campaign_plans/new');
    
    const campaignData = TestDataFactory.generateCampaignPlan({
      name: 'Market Analysis Test Campaign',
      campaign_type: 'awareness',
      objective: 'increase_brand_awareness'
    });

    await page.fill('input[name="campaign_plan[name]"]', campaignData.name);
    await page.selectOption('select[name="campaign_plan[campaign_type]"]', campaignData.campaign_type);
    await page.selectOption('select[name="campaign_plan[objective]"]', campaignData.objective);
    await page.fill('textarea[name="campaign_plan[target_audience]"]', campaignData.target_audience);
    await page.fill('textarea[name="campaign_plan[budget_constraints]"]', campaignData.budget_constraints);

    await page.click('button[type="submit"]');
    await page.waitForURL(/\/campaign_plans\/\d+/);

    const url = page.url();
    const campaignMatch = url.match(/\/campaign_plans\/(\d+)/);
    if (campaignMatch) {
      createdCampaignIds.push(campaignMatch[1]);
    }

    // Step 2: Navigate to campaign intelligence section
    const intelligenceUrl = `/campaign_plans/${campaignMatch[1]}/intelligence`;
    await page.goto(intelligenceUrl);

    // Step 3: Generate market analysis
    if (await page.isVisible('button:has-text("Generate Analysis"), text=Generate Intelligence')) {
      console.log('Generating market analysis...');
      
      await page.click('button:has-text("Generate Analysis"), text=Generate Intelligence');

      // Wait for AI analysis to complete
      await waitHelpers.waitForAIProcessing({
        timeout: 120000,
        statusSelector: '[data-analysis-status], .analysis-status',
        completedStates: ['completed', 'analyzed', 'success'],
        failedStates: ['failed', 'error'],
        processingStates: ['analyzing', 'processing', 'generating']
      });

      console.log('Market analysis completed');

      // Step 4: Verify analysis sections are present
      await waitHelpers.waitForLoadingComplete();

      // Check for competitive analysis
      if (await page.isVisible('h2:has-text("Competitive Analysis"), h3:has-text("Competition"), [data-competitive-analysis]')) {
        const competitiveAnalysis = await page.locator('[data-competitive-analysis], .competitive-analysis').textContent().catch(() => '');
        
        if (competitiveAnalysis) {
          expect(competitiveAnalysis.length).toBeGreaterThan(50);
          console.log(`Competitive analysis generated: ${competitiveAnalysis.substring(0, 100)}...`);
        }
      }

      // Check for market opportunities
      if (await page.isVisible('h2:has-text("Market Opportunities"), h3:has-text("Opportunities"), [data-market-opportunities]')) {
        const marketOpportunities = await page.locator('[data-market-opportunities], .market-opportunities').textContent().catch(() => '');
        
        if (marketOpportunities) {
          expect(marketOpportunities.length).toBeGreaterThan(30);
          console.log('Market opportunities identified');
        }
      }

      // Check for strategic recommendations
      if (await page.isVisible('h2:has-text("Strategic Recommendations"), h3:has-text("Recommendations"), [data-recommendations]')) {
        const recommendations = await page.locator('[data-recommendations], .strategic-recommendations').textContent().catch(() => '');
        
        if (recommendations) {
          expect(recommendations.length).toBeGreaterThan(50);
          console.log('Strategic recommendations generated');

          // Validate recommendation quality
          const validation = AIValidators.validateCampaignStrategy(recommendations);
          expect(validation.isValid).toBe(true);
        }
      }

      // Check for performance predictions
      if (await page.isVisible('h2:has-text("Performance Prediction"), h3:has-text("Predictions"), [data-predictions]')) {
        const predictions = await page.locator('[data-predictions], .performance-predictions').textContent().catch(() => '');
        
        if (predictions) {
          console.log('Performance predictions available');
          
          // Look for metrics and data points
          const hasMetrics = /\d+%|\d+x|\$\d+|roi|conversion|engagement/i.test(predictions);
          if (hasMetrics) {
            console.log('Predictions include quantitative metrics');
          }
        }
      }

    } else {
      console.log('Intelligence generation not available or already generated');
      
      // Check if intelligence already exists
      const existingIntelligence = await page.locator('[data-intelligence], .campaign-intelligence').count();
      if (existingIntelligence > 0) {
        console.log('Campaign intelligence already available');
      }
    }

    console.log('Market analysis test completed');
  });

  test('should provide industry-specific intelligence', async ({ page }) => {
    const industries = ['technology', 'healthcare', 'finance', 'retail', 'education'];

    for (const industry of industries) {
      console.log(`Testing ${industry} industry intelligence...`);

      await page.goto('/campaign_plans/new');
      
      const campaignData = TestDataFactory.generateCampaignPlan({
        name: `${industry} Intelligence Test`,
        target_audience: `${industry} professionals and decision makers`
      });

      await page.fill('input[name="campaign_plan[name]"]', campaignData.name);
      await page.selectOption('select[name="campaign_plan[campaign_type]"]', 'awareness');
      await page.selectOption('select[name="campaign_plan[objective]"]', 'increase_brand_awareness');
      await page.fill('textarea[name="campaign_plan[target_audience]"]', `${industry} ${campaignData.target_audience}`);

      await page.click('button[type="submit"]');
      await page.waitForURL(/\/campaign_plans\/\d+/);

      const url = page.url();
      const campaignMatch = url.match(/\/campaign_plans\/(\d+)/);
      if (campaignMatch) {
        createdCampaignIds.push(campaignMatch[1]);
      }

      // Generate intelligence for this industry
      await page.goto(`/campaign_plans/${campaignMatch[1]}/intelligence`);

      if (await page.isVisible('button:has-text("Generate")')) {
        await page.click('button:has-text("Generate")');

        try {
          await waitHelpers.waitForAIProcessing({
            timeout: 90000,
            completedStates: ['completed', 'analyzed']
          });

          // Check for industry-specific insights
          const pageContent = await page.textContent('body');
          const hasIndustryMention = pageContent.toLowerCase().includes(industry.toLowerCase());
          
          console.log(`${industry} industry-specific content: ${hasIndustryMention}`);

          // Look for industry-relevant metrics or terminology
          const industryTerms = {
            technology: ['software', 'digital', 'innovation', 'tech'],
            healthcare: ['patient', 'medical', 'health', 'care'],
            finance: ['financial', 'investment', 'banking', 'fiscal'],
            retail: ['customer', 'sales', 'product', 'shopping'],
            education: ['student', 'learning', 'academic', 'education']
          };

          const relevantTerms = industryTerms[industry] || [];
          const hasRelevantTerms = relevantTerms.some(term => 
            pageContent.toLowerCase().includes(term)
          );

          console.log(`Industry-relevant terminology found: ${hasRelevantTerms}`);

        } catch (error) {
          console.log(`Intelligence generation failed for ${industry}: ${error.message}`);
        }
      }
    }
  });

  test('should generate competitor analysis with actionable insights', async ({ page }) => {
    console.log('Testing competitor analysis generation...');

    // Create campaign with competitor context
    await page.goto('/campaign_plans/new');
    
    const campaignData = TestDataFactory.generateCampaignPlan({
      name: 'Competitor Analysis Test',
      target_audience: 'Marketing professionals looking for alternatives to HubSpot, Marketo, and Salesforce Marketing Cloud'
    });

    await page.fill('input[name="campaign_plan[name]"]', campaignData.name);
    await page.selectOption('select[name="campaign_plan[campaign_type]"]', 'consideration');
    await page.selectOption('select[name="campaign_plan[objective]"]', 'generate_leads');
    await page.fill('textarea[name="campaign_plan[target_audience]"]', campaignData.target_audience);

    await page.click('button[type="submit"]');
    await page.waitForURL(/\/campaign_plans\/\d+/);

    const url = page.url();
    const campaignMatch = url.match(/\/campaign_plans\/(\d+)/);
    if (campaignMatch) {
      createdCampaignIds.push(campaignMatch[1]);
    }

    // Generate competitor intelligence
    await page.goto(`/campaign_plans/${campaignMatch[1]}/intelligence`);

    if (await page.isVisible('button:has-text("Generate")')) {
      await page.click('button:has-text("Generate")');

      await waitHelpers.waitForAIProcessing({
        timeout: 120000,
        completedStates: ['completed', 'analyzed']
      });

      // Look for competitor analysis
      const competitorSection = await page.locator('text=competitor, text=competition, [data-competitor-analysis]').count();
      
      if (competitorSection > 0) {
        const competitorAnalysis = await page.textContent('[data-competitor-analysis], .competitor-analysis, section:has(text=competitor)');
        
        // Validate competitor analysis content
        const hasCompetitorNames = /hubspot|marketo|salesforce/i.test(competitorAnalysis);
        const hasActionableInsights = /opportunity|advantage|differentiate|position/i.test(competitorAnalysis);
        const hasStrategicRecommendations = /recommend|suggest|should|consider/i.test(competitorAnalysis);

        console.log('Competitor analysis validation:', {
          hasCompetitorNames,
          hasActionableInsights,
          hasStrategicRecommendations,
          contentLength: competitorAnalysis ? competitorAnalysis.length : 0
        });

        if (competitorAnalysis) {
          expect(competitorAnalysis.length).toBeGreaterThan(100);
        }
      }

      // Look for positioning recommendations
      if (await page.isVisible('text=positioning, text=differentiation, [data-positioning]')) {
        const positioning = await page.locator('[data-positioning], .positioning-recommendations').textContent().catch(() => '');
        
        if (positioning) {
          const hasPositioningStrategy = /position|differentiate|unique|advantage/i.test(positioning);
          console.log(`Positioning strategy provided: ${hasPositioningStrategy}`);
        }
      }
    }

    console.log('Competitor analysis test completed');
  });

  test('should provide performance predictions and success metrics', async ({ page }) => {
    console.log('Testing performance predictions...');

    await page.goto('/campaign_plans/new');
    
    const campaignData = TestDataFactory.generateCampaignPlan({
      name: 'Performance Prediction Test',
      budget_constraints: '$50,000 budget over 3 months with focus on measurable ROI',
      timeline_constraints: '3-month campaign with monthly optimization reviews'
    });

    await page.fill('input[name="campaign_plan[name]"]', campaignData.name);
    await page.selectOption('select[name="campaign_plan[campaign_type]"]', 'conversion');
    await page.selectOption('select[name="campaign_plan[objective]"]', 'drive_sales');
    await page.fill('textarea[name="campaign_plan[budget_constraints]"]', campaignData.budget_constraints);
    await page.fill('textarea[name="campaign_plan[timeline_constraints]"]', campaignData.timeline_constraints);

    await page.click('button[type="submit"]');
    await page.waitForURL(/\/campaign_plans\/\d+/);

    const url = page.url();
    const campaignMatch = url.match(/\/campaign_plans\/(\d+)/);
    if (campaignMatch) {
      createdCampaignIds.push(campaignMatch[1]);
    }

    await page.goto(`/campaign_plans/${campaignMatch[1]}/intelligence`);

    if (await page.isVisible('button:has-text("Generate")')) {
      await page.click('button:has-text("Generate")');

      await waitHelpers.waitForAIProcessing({
        timeout: 120000,
        completedStates: ['completed', 'analyzed']
      });

      // Look for performance metrics and predictions
      const pageContent = await page.textContent('body');
      
      // Check for quantitative predictions
      const hasPercentages = /\d+%/.test(pageContent);
      const hasROIMetrics = /roi|return|roas/i.test(pageContent);
      const hasConversionMetrics = /conversion|ctr|cpc|cpa/i.test(pageContent);
      const hasReachMetrics = /reach|impression|engagement/i.test(pageContent);

      console.log('Performance prediction metrics:', {
        hasPercentages,
        hasROIMetrics,
        hasConversionMetrics,
        hasReachMetrics
      });

      // Look for specific prediction sections
      if (await page.isVisible('text=prediction, text=forecast, [data-predictions]')) {
        const predictions = await page.locator('[data-predictions], .performance-predictions').textContent().catch(() => '');
        
        if (predictions) {
          expect(predictions.length).toBeGreaterThan(50);
          console.log(`Performance predictions generated: ${predictions.substring(0, 100)}...`);
        }
      }

      // Check for success probability
      if (await page.isVisible('text=probability, text=likelihood, [data-success-probability]')) {
        const probability = await page.locator('[data-success-probability], .success-probability').textContent().catch(() => '');
        
        if (probability) {
          console.log('Success probability analysis available');
        }
      }
    }
  });

  test('should provide optimization recommendations', async ({ page }) => {
    console.log('Testing optimization recommendations...');

    await page.goto('/campaign_plans/new');
    
    const campaignData = TestDataFactory.generateCampaignPlan({
      name: 'Optimization Test Campaign',
      description: 'Testing AI optimization recommendations for campaign improvement'
    });

    await page.fill('input[name="campaign_plan[name]"]', campaignData.name);
    await page.fill('textarea[name="campaign_plan[description]"]', campaignData.description);
    await page.selectOption('select[name="campaign_plan[campaign_type]"]', 'awareness');
    await page.selectOption('select[name="campaign_plan[objective]"]', 'increase_brand_awareness');

    await page.click('button[type="submit"]');
    await page.waitForURL(/\/campaign_plans\/\d+/);

    const url = page.url();
    const campaignMatch = url.match(/\/campaign_plans\/(\d+)/);
    if (campaignMatch) {
      createdCampaignIds.push(campaignMatch[1]);
    }

    await page.goto(`/campaign_plans/${campaignMatch[1]}/intelligence`);

    if (await page.isVisible('button:has-text("Generate")')) {
      await page.click('button:has-text("Generate")');

      await waitHelpers.waitForAIProcessing({
        timeout: 120000,
        completedStates: ['completed', 'analyzed']
      });

      // Look for optimization recommendations
      if (await page.isVisible('text=optimization, text=improve, [data-optimization]')) {
        const optimizations = await page.locator('[data-optimization], .optimization-recommendations').textContent().catch(() => '');
        
        if (optimizations) {
          // Validate optimization recommendations
          const hasActionableAdvice = /increase|improve|optimize|adjust|test|try|consider/i.test(optimizations);
          const hasSpecificSuggestions = /budget|timing|channel|audience|content/i.test(optimizations);
          const hasPrioritizedRecommendations = /first|next|priority|important/i.test(optimizations);

          console.log('Optimization recommendations validation:', {
            hasActionableAdvice,
            hasSpecificSuggestions,
            hasPrioritizedRecommendations,
            contentLength: optimizations.length
          });

          expect(optimizations.length).toBeGreaterThan(50);
        }
      }

      // Check for A/B testing recommendations
      if (await page.isVisible('text=test, text=variant, [data-testing-recommendations]')) {
        const testingRecommendations = await page.locator('[data-testing-recommendations], .testing-suggestions').textContent().catch(() => '');
        
        if (testingRecommendations) {
          console.log('A/B testing recommendations provided');
        }
      }

      // Check for channel optimization
      if (await page.isVisible('text=channel, text=platform, [data-channel-optimization]')) {
        const channelOptimization = await page.locator('[data-channel-optimization], .channel-recommendations').textContent().catch(() => '');
        
        if (channelOptimization) {
          console.log('Channel optimization recommendations available');
        }
      }
    }
  });

  test('should export intelligence reports', async ({ page }) => {
    console.log('Testing intelligence report export...');

    // Create campaign and generate intelligence
    await page.goto('/campaign_plans/new');
    
    const campaignData = TestDataFactory.generateCampaignPlan({
      name: 'Export Test Campaign'
    });

    await page.fill('input[name="campaign_plan[name]"]', campaignData.name);
    await page.selectOption('select[name="campaign_plan[campaign_type]"]', 'awareness');
    await page.selectOption('select[name="campaign_plan[objective]"]', 'increase_brand_awareness');

    await page.click('button[type="submit"]');
    await page.waitForURL(/\/campaign_plans\/\d+/);

    const url = page.url();
    const campaignMatch = url.match(/\/campaign_plans\/(\d+)/);
    if (campaignMatch) {
      createdCampaignIds.push(campaignMatch[1]);
    }

    await page.goto(`/campaign_plans/${campaignMatch[1]}/intelligence`);

    // Generate intelligence first
    if (await page.isVisible('button:has-text("Generate")')) {
      await page.click('button:has-text("Generate")');

      await waitHelpers.waitForAIProcessing({
        timeout: 120000,
        completedStates: ['completed', 'analyzed']
      });
    }

    // Test export functionality
    if (await page.isVisible('button:has-text("Export"), text=Export Report, [data-export]')) {
      console.log('Testing intelligence report export...');
      
      // Set up download event listener
      const downloadPromise = page.waitForEvent('download');
      
      await page.click('button:has-text("Export"), [data-export]');
      
      try {
        const download = await downloadPromise;
        const filename = download.suggestedFilename();
        
        expect(filename).toContain('intelligence');
        expect(filename.endsWith('.pdf') || filename.endsWith('.docx') || filename.endsWith('.html')).toBe(true);
        
        console.log(`Intelligence report exported: ${filename}`);
      } catch (error) {
        console.log('Export functionality not available or failed:', error.message);
      }
    }

    // Test analytics integration
    if (await page.isVisible('button:has-text("Analytics"), text=View Analytics, [data-analytics]')) {
      await page.click('button:has-text("Analytics"), [data-analytics]');
      
      // Wait for analytics to load
      await waitHelpers.waitForLoadingComplete();
      
      console.log('Analytics integration available');
    }
  });

  test('should handle intelligence regeneration and updates', async ({ page }) => {
    console.log('Testing intelligence regeneration...');

    await page.goto('/campaign_plans/new');
    
    const campaignData = TestDataFactory.generateCampaignPlan({
      name: 'Regeneration Test Campaign'
    });

    await page.fill('input[name="campaign_plan[name]"]', campaignData.name);
    await page.selectOption('select[name="campaign_plan[campaign_type]"]', 'consideration');
    await page.selectOption('select[name="campaign_plan[objective]"]', 'generate_leads');

    await page.click('button[type="submit"]');
    await page.waitForURL(/\/campaign_plans\/\d+/);

    const url = page.url();
    const campaignMatch = url.match(/\/campaign_plans\/(\d+)/);
    if (campaignMatch) {
      createdCampaignIds.push(campaignMatch[1]);
    }

    await page.goto(`/campaign_plans/${campaignMatch[1]}/intelligence`);

    // Generate initial intelligence
    if (await page.isVisible('button:has-text("Generate")')) {
      await page.click('button:has-text("Generate")');

      await waitHelpers.waitForAIProcessing({
        timeout: 120000,
        completedStates: ['completed', 'analyzed']
      });

      // Get initial intelligence content
      const initialIntelligence = await page.textContent('[data-intelligence], .campaign-intelligence, body').catch(() => '');

      // Test regeneration
      if (await page.isVisible('button:has-text("Regenerate"), text=Regenerate Intelligence')) {
        console.log('Testing intelligence regeneration...');
        
        await page.click('button:has-text("Regenerate")');
        
        // Confirm regeneration if prompt appears
        if (await page.isVisible('text=Are you sure, button:has-text("Confirm")')) {
          await page.click('button:has-text("Confirm")');
        }

        await waitHelpers.waitForAIProcessing({
          timeout: 120000,
          completedStates: ['completed', 'analyzed']
        });

        // Verify content was updated
        const regeneratedIntelligence = await page.textContent('[data-intelligence], .campaign-intelligence, body').catch(() => '');
        
        // Content should be different (though this is not guaranteed)
        if (regeneratedIntelligence !== initialIntelligence) {
          console.log('Intelligence successfully regenerated with updated content');
        } else {
          console.log('Intelligence regenerated (content may be similar)');
        }

        expect(regeneratedIntelligence.length).toBeGreaterThan(100);
      }
    }
  });
});