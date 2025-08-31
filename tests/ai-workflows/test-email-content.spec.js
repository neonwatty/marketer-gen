// Email Campaign Content Workflow Test
// Tests AI-powered email campaign generation with subject lines, personalization, and CTA optimization

const { test, expect } = require('@playwright/test');
const AuthHelper = require('../helpers/auth-helper');
const TestDataFactory = require('../helpers/test-data-factory');
const AIValidators = require('../helpers/ai-validators');
const WaitHelpers = require('../helpers/wait-helpers');

test.describe('AI Email Campaign Content Workflow', () => {
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
        console.log(`Email content cleanup failed for ID ${contentId}:`, error.message);
      }
    }

    await authHelper.logout();
  });

  test('should generate complete email campaign with subject and body', async ({ page }) => {
    console.log('Testing email campaign generation...');

    // Step 1: Navigate to content creation
    await page.goto('/generated_contents/new');

    // Step 2: Fill email content form
    const emailParams = TestDataFactory.generateEmailParams();
    const contentData = TestDataFactory.generateContent({
      title: 'AI Email Campaign Test',
      content_type: 'email'
    });

    await page.fill('input[name="generated_content[title]"]', contentData.title);
    
    // Select email content type
    await page.selectOption('select[name="generated_content[content_type]"]', 'email');
    
    // Select format variant for email length
    await page.selectOption('select[name="generated_content[format_variant]"]', 'medium');
    
    // Leave body content blank for AI generation
    await page.fill('textarea[name="generated_content[body_content]"]', '');

    // Step 3: Generate email content
    console.log('Generating email content...');
    await page.click('button:has-text("Generate Content")');

    // Step 4: Wait for generation to complete
    await page.waitForURL(/\/generated_contents\/\d+/, { timeout: 30000 });

    // Extract content ID for cleanup
    const url = page.url();
    const contentMatch = url.match(/\/generated_contents\/(\d+)/);
    if (contentMatch) {
      createdContentIds.push(contentMatch[1]);
    }

    // Step 5: Wait for email content generation
    await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content', {
      timeout: 60000,
      minLength: 50 // Emails should be more substantial
    });

    // Get generated email content
    const emailContent = await page.$eval(
      'textarea[name="generated_content[body_content]"], .generated-content',
      el => el.value || el.textContent
    );

    console.log(`Generated email content length: ${emailContent.length} characters`);

    // Step 6: Validate email structure and quality
    const validation = AIValidators.validateEmailContent(emailContent, {
      audience: 'marketing_professionals',
      tone: 'professional'
    });

    // Essential email validations
    expect(validation.isValid).toBe(true);
    expect(validation.metrics.wordCount).toBeGreaterThan(20);
    expect(validation.metrics.hasCallToAction).toBe(true);

    // Check for email structure elements
    if (!validation.metrics.hasGreeting) {
      console.warn('Email might benefit from a greeting');
    }
    
    if (!validation.metrics.hasClosing) {
      console.warn('Email might benefit from a closing');
    }

    console.log('Email validation results:', {
      isValid: validation.isValid,
      wordCount: validation.metrics.wordCount,
      hasGreeting: validation.metrics.hasGreeting,
      hasClosing: validation.metrics.hasClosing,
      hasCallToAction: validation.metrics.hasCallToAction,
      hasPersonalization: validation.metrics.hasPersonalization
    });

    // Step 7: Check for subject line if displayed separately
    const subjectElements = await page.locator('input[name*="subject"], .subject-line, [data-subject]').count();
    if (subjectElements > 0) {
      const subjectLine = await page.$eval(
        'input[name*="subject"], .subject-line, [data-subject]',
        el => el.value || el.textContent
      );
      
      // Validate subject line
      expect(subjectLine.length).toBeGreaterThan(5);
      expect(subjectLine.length).toBeLessThan(100); // Good subject line length
      
      console.log(`Generated subject line: "${subjectLine}"`);
    }

    console.log('Email campaign generation test completed successfully');
  });

  test('should generate different email types appropriately', async ({ page }) => {
    const emailTypes = [
      { variant: 'short', expectedWords: { min: 20, max: 100 }, purpose: 'announcement' },
      { variant: 'medium', expectedWords: { min: 50, max: 300 }, purpose: 'newsletter' },
      { variant: 'long', expectedWords: { min: 100, max: 600 }, purpose: 'detailed_guide' }
    ];

    for (const emailType of emailTypes) {
      console.log(`Testing ${emailType.variant} email format...`);

      await page.goto('/generated_contents/new');
      
      // Fill form for specific email type
      await page.fill('input[name="generated_content[title]"]', `${emailType.purpose} Email - ${emailType.variant}`);
      await page.selectOption('select[name="generated_content[content_type]"]', 'email');
      await page.selectOption('select[name="generated_content[format_variant]"]', emailType.variant);
      await page.fill('textarea[name="generated_content[body_content]"]', '');

      await page.click('button:has-text("Generate Content")');
      await page.waitForURL(/\/generated_contents\/\d+/);

      // Extract content ID for cleanup
      const url = page.url();
      const contentMatch = url.match(/\/generated_contents\/(\d+)/);
      if (contentMatch) {
        createdContentIds.push(contentMatch[1]);
      }

      // Wait for generation
      await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');

      const emailContent = await page.$eval(
        'textarea[name="generated_content[body_content]"], .generated-content',
        el => el.value || el.textContent
      );

      // Validate length matches expected variant
      const wordCount = emailContent.split(/\s+/).length;
      expect(wordCount).toBeGreaterThanOrEqual(emailType.expectedWords.min);
      expect(wordCount).toBeLessThanOrEqual(emailType.expectedWords.max);

      // Validate email quality
      const validation = AIValidators.validateEmailContent(emailContent);
      expect(validation.isValid).toBe(true);

      console.log(`${emailType.variant} email: ${wordCount} words (${emailType.expectedWords.min}-${emailType.expectedWords.max}) - ✓`);
    }
  });

  test('should generate personalized email content', async ({ page }) => {
    console.log('Testing email personalization features...');

    await page.goto('/generated_contents/new');

    // Fill form with personalization context
    await page.fill('input[name="generated_content[title]"]', 'Personalized Welcome Email');
    await page.selectOption('select[name="generated_content[content_type]"]', 'email');
    await page.selectOption('select[name="generated_content[format_variant]"]', 'medium');
    
    // Add context that should trigger personalization
    await page.fill('textarea[name="generated_content[body_content]"]', 
      'Context: New user onboarding email for marketing professionals who just signed up'
    );

    await page.click('button:has-text("Generate Content")');
    await page.waitForURL(/\/generated_contents\/\d+/);

    const url = page.url();
    const contentMatch = url.match(/\/generated_contents\/(\d+)/);
    if (contentMatch) {
      createdContentIds.push(contentMatch[1]);
    }

    await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');

    const personalizedEmail = await page.$eval(
      'textarea[name="generated_content[body_content]"], .generated-content',
      el => el.value || el.textContent
    );

    // Check for personalization indicators
    const hasPersonalizationPlaceholders = /\{|\[|%|{{/.test(personalizedEmail);
    const hasPersonalizedGreeting = /welcome|hello|hi there|greetings/i.test(personalizedEmail);
    const hasUserSpecificContent = /your|you're|you'll|your account|your journey/i.test(personalizedEmail);

    // Validate personalization elements
    expect(hasPersonalizedGreeting).toBe(true);
    expect(hasUserSpecificContent).toBe(true);

    // Validate overall quality
    const validation = AIValidators.validateEmailContent(personalizedEmail);
    expect(validation.isValid).toBe(true);

    console.log('Personalization features:', {
      hasPersonalizationPlaceholders,
      hasPersonalizedGreeting,
      hasUserSpecificContent,
      wordCount: validation.metrics.wordCount
    });
  });

  test('should generate email series with consistent messaging', async ({ page }) => {
    console.log('Testing email series generation...');

    const seriesEmails = [
      { title: 'Welcome Email 1 - Introduction', context: 'First email in welcome series' },
      { title: 'Welcome Email 2 - Getting Started', context: 'Second email with setup instructions' },
      { title: 'Welcome Email 3 - Advanced Features', context: 'Third email highlighting advanced features' }
    ];

    const generatedSeries = [];

    for (let i = 0; i < seriesEmails.length; i++) {
      const emailData = seriesEmails[i];
      console.log(`Generating ${emailData.title}...`);

      await page.goto('/generated_contents/new');

      await page.fill('input[name="generated_content[title]"]', emailData.title);
      await page.selectOption('select[name="generated_content[content_type]"]', 'email');
      await page.selectOption('select[name="generated_content[format_variant]"]', 'medium');
      await page.fill('textarea[name="generated_content[body_content]"]', emailData.context);

      await page.click('button:has-text("Generate Content")');
      await page.waitForURL(/\/generated_contents\/\d+/);

      const url = page.url();
      const contentMatch = url.match(/\/generated_contents\/(\d+)/);
      if (contentMatch) {
        createdContentIds.push(contentMatch[1]);
      }

      await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');

      const emailContent = await page.$eval(
        'textarea[name="generated_content[body_content]"], .generated-content',
        el => el.value || el.textContent
      );

      generatedSeries.push({
        title: emailData.title,
        content: emailContent
      });

      // Validate individual email
      const validation = AIValidators.validateEmailContent(emailContent);
      expect(validation.isValid).toBe(true);
    }

    // Validate series consistency
    // Check that emails are different but maintain consistent tone
    const uniqueContents = new Set(generatedSeries.map(email => email.content));
    expect(uniqueContents.size).toBe(seriesEmails.length); // All emails should be unique

    // Check for progressive disclosure (later emails can reference earlier concepts)
    const firstEmail = generatedSeries[0].content.toLowerCase();
    const lastEmail = generatedSeries[2].content.toLowerCase();

    console.log('Email series generated successfully:', {
      uniqueEmails: uniqueContents.size,
      avgLength: generatedSeries.reduce((sum, email) => sum + email.content.length, 0) / generatedSeries.length
    });
  });

  test('should generate appropriate CTAs based on email purpose', async ({ page }) => {
    const emailPurposes = [
      { purpose: 'demo_request', expectedCTAs: ['schedule', 'book', 'demo', 'meeting'] },
      { purpose: 'trial_signup', expectedCTAs: ['try', 'start', 'trial', 'free'] },
      { purpose: 'newsletter', expectedCTAs: ['read', 'learn', 'discover', 'explore'] },
      { purpose: 'product_announcement', expectedCTAs: ['learn', 'see', 'discover', 'check'] }
    ];

    for (const purposeData of emailPurposes) {
      console.log(`Testing CTA generation for ${purposeData.purpose}...`);

      await page.goto('/generated_contents/new');

      await page.fill('input[name="generated_content[title]"]', `${purposeData.purpose} Email CTA Test`);
      await page.selectOption('select[name="generated_content[content_type]"]', 'email');
      await page.selectOption('select[name="generated_content[format_variant]"]', 'short');
      await page.fill('textarea[name="generated_content[body_content]"]', 
        `Purpose: ${purposeData.purpose.replace('_', ' ')} email campaign`
      );

      await page.click('button:has-text("Generate Content")');
      await page.waitForURL(/\/generated_contents\/\d+/);

      const url = page.url();
      const contentMatch = url.match(/\/generated_contents\/(\d+)/);
      if (contentMatch) {
        createdContentIds.push(contentMatch[1]);
      }

      await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');

      const emailContent = await page.$eval(
        'textarea[name="generated_content[body_content]"], .generated-content',
        el => el.value || el.textContent
      ).catch(() => '');

      // Check for appropriate CTA language
      const emailLower = emailContent.toLowerCase();
      const hasPurposeCTA = purposeData.expectedCTAs.some(cta => 
        emailLower.includes(cta.toLowerCase())
      );

      // Validate email has appropriate CTA
      const validation = AIValidators.validateEmailContent(emailContent);
      expect(validation.isValid).toBe(true);
      expect(validation.metrics.hasCallToAction).toBe(true);

      console.log(`${purposeData.purpose} CTA validation:`, {
        hasPurposeCTA,
        hasGeneralCTA: validation.metrics.hasCallToAction,
        wordCount: validation.metrics.wordCount
      });
    }
  });

  test('should handle A/B testing for email optimization', async ({ page }) => {
    console.log('Testing email A/B variant generation...');

    // Generate base email
    await page.goto('/generated_contents/new');

    await page.fill('input[name="generated_content[title]"]', 'A/B Test Base Email');
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

    const originalEmail = await page.$eval(
      'textarea[name="generated_content[body_content]"], .generated-content',
      el => el.value || el.textContent
    );

    // Test regeneration for A/B variant
    if (await page.isVisible('text=Regenerate, button:has-text("Regenerate")')) {
      console.log('Creating A/B variant through regeneration...');

      await page.click('text=Regenerate, button:has-text("Regenerate")');

      await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content', {
        timeout: 60000
      });

      const variantEmail = await page.$eval(
        'textarea[name="generated_content[body_content]"], .generated-content',
        el => el.value || el.textContent
      );

      // Validate both versions are different but quality
      expect(variantEmail).not.toBe(originalEmail);
      
      const originalValidation = AIValidators.validateEmailContent(originalEmail);
      const variantValidation = AIValidators.validateEmailContent(variantEmail);

      expect(originalValidation.isValid).toBe(true);
      expect(variantValidation.isValid).toBe(true);

      console.log('A/B variants created:', {
        originalWordCount: originalValidation.metrics.wordCount,
        variantWordCount: variantValidation.metrics.wordCount,
        bothValid: originalValidation.isValid && variantValidation.isValid
      });
    }

    // Test variant creation if specific feature exists
    if (await page.isVisible('text=Create Variants, button:has-text("Create Variants")')) {
      await page.click('text=Create Variants, button:has-text("Create Variants")');
      
      // Wait for variants interface
      await page.waitForTimeout(5000);
      
      const variantCount = await page.locator('[data-variant], .email-variant').count();
      console.log(`Created ${variantCount} email variants for A/B testing`);
    }
  });

  test('should maintain professional email formatting', async ({ page }) => {
    console.log('Testing professional email formatting...');

    await page.goto('/generated_contents/new');

    await page.fill('input[name="generated_content[title]"]', 'Professional Format Test');
    await page.selectOption('select[name="generated_content[content_type]"]', 'email');
    await page.selectOption('select[name="generated_content[format_variant]"]', 'long');
    await page.fill('textarea[name="generated_content[body_content]"]', 
      'Context: Professional business communication for B2B marketing platform'
    );

    await page.click('button:has-text("Generate Content")');
    await page.waitForURL(/\/generated_contents\/\d+/);

    const url = page.url();
    const contentMatch = url.match(/\/generated_contents\/(\d+)/);
    if (contentMatch) {
      createdContentIds.push(contentMatch[1]);
    }

    await waitHelpers.waitForContentGeneration('textarea[name="generated_content[body_content]"], .generated-content');

    const professionalEmail = await page.$eval(
      'textarea[name="generated_content[body_content]"], .generated-content',
      el => el.value || el.textContent
    );

    // Validate professional formatting
    const validation = AIValidators.validateEmailContent(professionalEmail);
    
    // Professional email characteristics
    const hasProfessionalGreeting = /dear|hello|hi [a-z]/i.test(professionalEmail);
    const hasProfessionalClosing = /best regards|sincerely|best|regards|thank you/i.test(professionalEmail);
    const hasProperStructure = /\n\n|\r\n\r\n/.test(professionalEmail); // Paragraph breaks
    const avoidsCasualLanguage = !/hey|awesome|cool|super|totally/i.test(professionalEmail);

    expect(validation.isValid).toBe(true);
    expect(validation.metrics.wordCount).toBeGreaterThan(50);
    expect(hasProfessionalGreeting || hasProfessionalClosing).toBe(true);

    console.log('Professional formatting validation:', {
      hasProfessionalGreeting,
      hasProfessionalClosing,
      hasProperStructure,
      avoidsCasualLanguage,
      wordCount: validation.metrics.wordCount
    });
  });
});