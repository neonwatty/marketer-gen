// Content Optimization & Variants Test
// Tests AI-powered content improvement, A/B variant generation, and performance optimization

const { test, expect } = require('@playwright/test');
const AuthHelper = require('../helpers/auth-helper');
const TestDataFactory = require('../helpers/test-data-factory');
const AIValidators = require('../helpers/ai-validators');
const WaitHelpers = require('../helpers/wait-helpers');

test.describe('AI Content Optimization & Variants Workflow', () => {
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

  test('should optimize existing content for better performance', async ({ page }) => {
    console.log('Testing content optimization...');

    // Step 1: Create base content that can be optimized
    await page.goto('/generated_contents/new');
    
    const baseContent = `Check out our new features. We have some updates to share with you. 
      Our platform now has new tools. Thanks for reading.`;

    await page.fill('input[name="generated_content[title]"]', 'Basic Content for Optimization');
    await page.selectOption('select[name="generated_content[content_type]"]', 'social_post');
    await page.selectOption('select[name="generated_content[format_variant]"]', 'medium');
    await page.fill('textarea[name="generated_content[body_content]"]', baseContent);

    await page.click('button:has-text("Generate Content")');
    await page.waitForURL(/\/generated_contents\/\d+/);

    const url = page.url();
    const contentMatch = url.match(/\/generated_contents\/(\d+)/);
    if (contentMatch) {
      createdContentIds.push(contentMatch[1]);
    }

    // Step 2: Test optimization features
    if (await page.isVisible('button:has-text("Optimize"), text=Optimize Content, [data-optimize]')) {
      console.log('Content optimization available, testing...');
      
      await page.click('button:has-text("Optimize"), [data-optimize]');

      // Wait for optimization suggestions
      await waitHelpers.waitForAIProcessing({
        timeout: 60000,
        statusSelector: '[data-optimization-status], .optimization-status',
        completedStates: ['optimized', 'completed', 'success'],
        processingStates: ['optimizing', 'analyzing']
      });

      // Check for optimization suggestions
      if (await page.isVisible('[data-optimization-suggestions], .optimization-suggestions')) {
        const suggestions = await page.locator('[data-optimization-suggestions], .optimization-suggestions').textContent();
        
        expect(suggestions.length).toBeGreaterThan(20);
        console.log(`Optimization suggestions: ${suggestions.substring(0, 100)}...`);

        // Look for specific optimization types
        const hasHeadlineImprovement = /headline|title|subject/i.test(suggestions);
        const hasCTAImprovement = /call.*action|cta|click|try|get/i.test(suggestions);
        const hasEngagementImprovement = /engagement|hook|attention/i.test(suggestions);

        console.log('Optimization types found:', {
          hasHeadlineImprovement,
          hasCTAImprovement,
          hasEngagementImprovement
        });
      }

      // Apply optimization if available
      if (await page.isVisible('button:has-text("Apply Optimization"), [data-apply-optimization]')) {
        await page.click('button:has-text("Apply Optimization")');
        
        await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .optimized-content');

        const optimizedContent = await page.$eval(
          'textarea[name="generated_content[body_content]"], .optimized-content',
          el => el.value || el.textContent
        );

        // Validate optimization improved the content
        expect(optimizedContent).not.toBe(baseContent);
        expect(optimizedContent.length).toBeGreaterThan(baseContent.length);

        // Validate optimization quality
        const validation = AIValidators.validateSocialMediaContent(optimizedContent, 'linkedin');
        expect(validation.metrics.hasCallToAction).toBe(true);

        console.log(`Original: ${baseContent.length} chars`);
        console.log(`Optimized: ${optimizedContent.length} chars`);
        console.log('Content successfully optimized');
      }
    } else {
      // Test regeneration as optimization alternative
      if (await page.isVisible('button:has-text("Regenerate")')) {
        console.log('Testing regeneration for content improvement...');
        
        const originalContent = await page.$eval(
          'textarea[name="generated_content[body_content]"], .generated-content',
          el => el.value || el.textContent
        );

        await page.click('button:has-text("Regenerate")');
        
        await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');

        const regeneratedContent = await page.$eval(
          'textarea[name="generated_content[body_content]"], .generated-content',
          el => el.value || el.textContent
        );

        // Verify regeneration produced different content
        expect(regeneratedContent).not.toBe(originalContent);
        
        const validation = AIValidators.validateContentQuality(regeneratedContent);
        expect(validation.isValid).toBe(true);

        console.log('Content regenerated successfully');
      }
    }
  });

  test('should generate A/B testing variants', async ({ page }) => {
    console.log('Testing A/B variant generation...');

    // Create base content
    await page.goto('/generated_contents/new');
    
    await page.fill('input[name="generated_content[title]"]', 'A/B Variant Test Content');
    await page.selectOption('select[name="generated_content[content_type]"]', 'email');
    await page.selectOption('select[name="generated_content[format_variant]"]', 'medium');
    await page.fill('textarea[name="generated_content[body_content]"]', '');

    await page.click('button:has-text("Generate Content")');
    await page.waitForURL(/\/generated_contents\/\d+/);

    const url = page.url();
    const contentMatch = url.match(/\/generated_contents\/(\d+)/);
    if (contentMatch) {
      createdContentIds.push(contentMatch[1]);
    }

    await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');

    const originalContent = await page.$eval(
      'textarea[name="generated_content[body_content]"], .generated-content',
      el => el.value || el.textContent
    );

    // Test A/B variant generation
    if (await page.isVisible('button:has-text("Create Variants"), text=A/B Variants, [data-variants]')) {
      console.log('Creating A/B variants...');
      
      await page.click('button:has-text("Create Variants"), [data-variants]');

      // Wait for variant generation
      await waitHelpers.waitForAIProcessing({
        timeout: 90000,
        completedStates: ['completed', 'variants_created'],
        processingStates: ['generating_variants', 'creating_variants']
      });

      // Check for generated variants
      const variantCount = await page.locator('[data-variant], .content-variant, .variant').count();
      
      if (variantCount > 0) {
        console.log(`Generated ${variantCount} A/B variants`);

        // Validate each variant is different
        const variants = [];
        for (let i = 0; i < Math.min(variantCount, 3); i++) {
          const variant = await page.locator('[data-variant], .content-variant, .variant').nth(i);
          const variantText = await variant.textContent();
          variants.push(variantText);
        }

        // Ensure variants are unique
        const uniqueVariants = new Set(variants);
        expect(uniqueVariants.size).toBeGreaterThan(1);

        // Validate each variant quality
        for (const variant of variants) {
          if (variant && variant.length > 10) {
            const validation = AIValidators.validateEmailContent(variant);
            expect(validation.metrics.wordCount).toBeGreaterThan(5);
          }
        }

        console.log(`All ${variants.length} variants are unique and valid`);
      }
    } else {
      // Alternative: test multiple regenerations as variants
      console.log('Testing multiple regenerations as variant alternatives...');
      
      const variants = [originalContent];
      
      for (let i = 0; i < 2; i++) {
        if (await page.isVisible('button:has-text("Regenerate")')) {
          await page.click('button:has-text("Regenerate")');
          
          await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');

          const variantContent = await page.$eval(
            'textarea[name="generated_content[body_content]"], .generated-content',
            el => el.value || el.textContent
          );

          variants.push(variantContent);
        }
      }

      // Validate we have multiple unique variants
      const uniqueVariants = new Set(variants);
      console.log(`Generated ${uniqueVariants.size} unique variants through regeneration`);
      expect(uniqueVariants.size).toBeGreaterThan(1);
    }
  });

  test('should provide performance optimization suggestions', async ({ page }) => {
    const contentTypes = [
      { type: 'social_post', platform: 'linkedin' },
      { type: 'email', context: { audience: 'professionals' } },
      { type: 'ad_copy', platform: 'google_ads' }
    ];

    for (const contentTypeData of contentTypes) {
      console.log(`Testing optimization for ${contentTypeData.type}...`);

      await page.goto('/generated_contents/new');
      
      await page.fill('input[name="generated_content[title]"]', `Optimization Test - ${contentTypeData.type}`);
      await page.selectOption('select[name="generated_content[content_type]"]', contentTypeData.type);
      await page.selectOption('select[name="generated_content[format_variant]"]', 'medium');
      
      // Create suboptimal content for optimization testing
      const suboptimalContent = 'This is basic content that could be better. Please check it out.';
      await page.fill('textarea[name="generated_content[body_content]"]', suboptimalContent);

      await page.click('button:has-text("Generate Content")');
      await page.waitForURL(/\/generated_contents\/\d+/);

      const url = page.url();
      const contentMatch = url.match(/\/generated_contents\/(\d+)/);
      if (contentMatch) {
        createdContentIds.push(contentMatch[1]);
      }

      // Look for optimization suggestions
      if (await page.isVisible('[data-suggestions], .improvement-suggestions, text=Suggestions')) {
        const suggestions = await page.locator('[data-suggestions], .improvement-suggestions').textContent().catch(() => '');
        
        if (suggestions) {
          console.log(`Optimization suggestions for ${contentTypeData.type}:`);
          
          // Validate suggestions are content-type appropriate
          switch (contentTypeData.type) {
            case 'social_post':
              const hasSocialSuggestions = /hashtag|engagement|share|follow/i.test(suggestions);
              console.log(`Social-specific suggestions: ${hasSocialSuggestions}`);
              break;
              
            case 'email':
              const hasEmailSuggestions = /subject|open rate|click|personalization/i.test(suggestions);
              console.log(`Email-specific suggestions: ${hasEmailSuggestions}`);
              break;
              
            case 'ad_copy':
              const hasAdSuggestions = /ctr|conversion|cta|headline/i.test(suggestions);
              console.log(`Ad-specific suggestions: ${hasAdSuggestions}`);
              break;
          }

          expect(suggestions.length).toBeGreaterThan(20);
        }
      }

      // Test performance prediction if available
      if (await page.isVisible('[data-performance], .performance-prediction, text=Performance')) {
        const performancePrediction = await page.locator('[data-performance], .performance-prediction').textContent().catch(() => '');
        
        if (performancePrediction) {
          console.log(`Performance prediction available for ${contentTypeData.type}`);
          
          // Look for metrics
          const hasMetrics = /\d+%|score|rating|prediction/i.test(performancePrediction);
          if (hasMetrics) {
            console.log('Performance prediction includes metrics');
          }
        }
      }
    }
  });

  test('should optimize content for specific platforms', async ({ page }) => {
    const platforms = [
      { name: 'Twitter', charLimit: 280, expectations: ['hashtags', 'brevity', 'engagement'] },
      { name: 'LinkedIn', charLimit: 3000, expectations: ['professional', 'insights', 'networking'] },
      { name: 'Facebook', charLimit: 63206, expectations: ['personal', 'community', 'sharing'] }
    ];

    for (const platform of platforms) {
      console.log(`Testing ${platform.name} platform optimization...`);

      await page.goto('/generated_contents/new');
      
      const genericContent = `Our product is great and you should try it. We have many features 
        that will help you succeed in your business goals. Contact us for more information.`;

      await page.fill('input[name="generated_content[title]"]', `${platform.name} Optimization Test`);
      await page.selectOption('select[name="generated_content[content_type]"]', 'social_post');
      await page.fill('textarea[name="generated_content[body_content]"]', genericContent);

      await page.click('button:has-text("Generate Content")');
      await page.waitForURL(/\/generated_contents\/\d+/);

      const url = page.url();
      const contentMatch = url.match(/\/generated_contents\/(\d+)/);
      if (contentMatch) {
        createdContentIds.push(contentMatch[1]);
      }

      // Test platform-specific optimization
      if (await page.isVisible(`text=${platform.name}, select[name*="platform"], [data-platform]`)) {
        // Set platform context
        if (await page.isVisible('select[name*="platform"]')) {
          await page.selectOption('select[name*="platform"]', platform.name.toLowerCase());
        }

        // Trigger optimization
        if (await page.isVisible('button:has-text("Optimize for Platform"), [data-platform-optimize]')) {
          await page.click('button:has-text("Optimize for Platform")');
          
          await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .optimized-content');

          const optimizedContent = await page.$eval(
            'textarea[name="generated_content[body_content]"], .optimized-content',
            el => el.value || el.textContent
          );

          // Validate platform optimization
          expect(optimizedContent.length).toBeLessThanOrEqual(platform.charLimit);
          
          // Platform-specific validation
          const validation = AIValidators.validateSocialMediaContent(optimizedContent, platform.name.toLowerCase());
          expect(validation.isValid).toBe(true);

          console.log(`${platform.name} optimization:`, {
            charCount: optimizedContent.length,
            charLimit: platform.charLimit,
            withinLimit: optimizedContent.length <= platform.charLimit,
            hasHashtags: validation.metrics.hashtagCount > 0,
            hasCTA: validation.metrics.hasCallToAction
          });
        }
      }
    }
  });

  test('should provide content scoring and improvement metrics', async ({ page }) => {
    console.log('Testing content scoring and metrics...');

    // Create content with measurable elements
    await page.goto('/generated_contents/new');
    
    const scorableContent = `Transform your marketing ROI with our AI-powered platform! 
      Join 500+ companies seeing 300% growth. Try our 14-day free trial today. 
      #MarketingAI #Growth #ROI`;

    await page.fill('input[name="generated_content[title]"]', 'Content Scoring Test');
    await page.selectOption('select[name="generated_content[content_type]"]', 'social_post');
    await page.fill('textarea[name="generated_content[body_content]"]', scorableContent);

    await page.click('button:has-text("Generate Content")');
    await page.waitForURL(/\/generated_contents\/\d+/);

    const url = page.url();
    const contentMatch = url.match(/\/generated_contents\/(\d+)/);
    if (contentMatch) {
      createdContentIds.push(contentMatch[1]);
    }

    // Look for content scoring
    if (await page.isVisible('[data-score], .content-score, text=Score')) {
      const scoreElement = await page.locator('[data-score], .content-score').first();
      const scoreText = await scoreElement.textContent();
      
      console.log(`Content score: ${scoreText}`);
      
      // Check for numeric score
      const hasNumericScore = /\d+/.test(scoreText);
      if (hasNumericScore) {
        console.log('Numeric content score provided');
      }
    }

    // Check for improvement metrics
    if (await page.isVisible('[data-metrics], .improvement-metrics, text=Metrics')) {
      const metrics = await page.locator('[data-metrics], .improvement-metrics').textContent().catch(() => '');
      
      if (metrics) {
        console.log('Improvement metrics available');
        
        // Look for specific metric types
        const hasEngagementMetrics = /engagement|click|share/i.test(metrics);
        const hasReadabilityMetrics = /readability|clarity|comprehension/i.test(metrics);
        const hasSEOMetrics = /seo|keyword|search/i.test(metrics);

        console.log('Metric types found:', {
          hasEngagementMetrics,
          hasReadabilityMetrics,
          hasSEOMetrics
        });
      }
    }

    // Test improvement tracking
    if (await page.isVisible('button:has-text("Optimize"), [data-optimize]')) {
      const beforeContent = await page.$eval(
        'textarea[name="generated_content[body_content]"], .generated-content',
        el => el.value || el.textContent
      );

      await page.click('button:has-text("Optimize")');
      
      await waitHelpers.waitForAIProcessing({
        timeout: 60000,
        completedStates: ['optimized', 'completed']
      });

      // Check for improvement indicators
      if (await page.isVisible('[data-improvement], .improvement-indicator, text=Improved')) {
        const improvement = await page.locator('[data-improvement], .improvement-indicator').textContent().catch(() => '');
        
        if (improvement) {
          console.log(`Improvement indicators: ${improvement}`);
          
          // Look for quantified improvements
          const hasQuantifiedImprovement = /\+\d+%|\d+% better|improved by/i.test(improvement);
          if (hasQuantifiedImprovement) {
            console.log('Quantified improvement metrics provided');
          }
        }
      }
    }
  });

  test('should handle bulk optimization operations', async ({ page }) => {
    console.log('Testing bulk content optimization...');

    const contentPieces = [
      { title: 'Bulk Test 1', content: 'Basic content one that needs optimization.' },
      { title: 'Bulk Test 2', content: 'Another piece of content for bulk testing.' },
      { title: 'Bulk Test 3', content: 'Third content piece for bulk optimization test.' }
    ];

    // Create multiple content pieces
    for (const piece of contentPieces) {
      await page.goto('/generated_contents/new');
      
      await page.fill('input[name="generated_content[title]"]', piece.title);
      await page.selectOption('select[name="generated_content[content_type]"]', 'social_post');
      await page.fill('textarea[name="generated_content[body_content]"]', piece.content);

      await page.click('button:has-text("Generate Content")');
      await page.waitForURL(/\/generated_contents\/\d+/);

      const url = page.url();
      const contentMatch = url.match(/\/generated_contents\/(\d+)/);
      if (contentMatch) {
        createdContentIds.push(contentMatch[1]);
      }
    }

    // Test bulk operations if available
    await page.goto('/generated_contents');

    if (await page.isVisible('[data-bulk-actions], .bulk-actions, text=Bulk Actions')) {
      console.log('Bulk actions available, testing bulk optimization...');

      // Select multiple content pieces
      const checkboxes = await page.locator('input[type="checkbox"][name*="content"]').count();
      if (checkboxes >= contentPieces.length) {
        for (let i = 0; i < Math.min(checkboxes, contentPieces.length); i++) {
          await page.check(`input[type="checkbox"][name*="content"]`);
        }

        // Apply bulk optimization
        if (await page.isVisible('button:has-text("Optimize Selected"), [data-bulk-optimize]')) {
          await page.click('button:has-text("Optimize Selected")');
          
          // Wait for bulk processing
          await waitHelpers.waitForAIProcessing({
            timeout: 180000, // Longer timeout for bulk operations
            completedStates: ['bulk_completed', 'completed'],
            processingStates: ['bulk_processing', 'optimizing']
          });

          console.log('Bulk optimization completed');

          // Verify results
          const optimizedCount = await page.locator('.optimized, [data-optimized="true"]').count();
          if (optimizedCount > 0) {
            console.log(`${optimizedCount} pieces optimized in bulk operation`);
          }
        }
      }
    } else {
      console.log('Bulk actions not available, testing completed individual optimizations');
    }
  });
});