// Robust Selector Helper for Playwright tests
// Provides reliable selectors and interaction methods to reduce test flakiness

class SelectorHelper {
  constructor(page) {
    this.page = page;
  }

  /**
   * Get robust selectors for common UI elements
   */
  getSelectors() {
    return {
      // Authentication elements
      auth: {
        signUpForm: 'form[action*="sign_up"], form:has(input[name*="email_address"])',
        loginForm: 'form[action*="session"], form:has(input[name="email_address"])',
        emailInput: 'input[name="user[email_address]"], input[name="email_address"]',
        passwordInput: 'input[name="user[password]"], input[name="password"]',
        passwordConfirmInput: 'input[name="user[password_confirmation]"]',
        nameInput: 'input[name="user[name]"]',
        submitButton: 'button[type="submit"], input[type="submit"]',
        signOutButton: 'button:has-text("Sign Out"), form[action="/session"] button[type="submit"]',
        loggedInIndicator: 'text="You are logged in as:"'
      },

      // Campaign Plan elements - updated based on actual form structure
      campaignPlan: {
        newButton: [
          'a[href="/campaign_plans/new"]',
          'text="New Campaign"',
          'button:has-text("New Campaign")',
          'a:has-text("New Campaign")',
          'a:has-text("Create Campaign Plan")',
          '[data-action="new-campaign"]'
        ],
        nameInput: [
          'input[name="campaign_plan[name]"]',
          'input#campaign_plan_name',
          '.smart-field[data-smart-suggestions-field-name-value="name"] input',
          'input[placeholder*="Campaign"][placeholder*="name"]'
        ],
        descriptionTextarea: [
          'textarea[name="campaign_plan[description]"]',
          'textarea#campaign_plan_description', 
          '.smart-field[data-smart-suggestions-field-name-value="description"] textarea',
          'textarea[placeholder*="description"]'
        ],
        typeSelect: [
          'select[name="campaign_plan[campaign_type]"]',
          'select#campaign_plan_campaign_type',
          'select:has(option:contains("campaign type"))'
        ],
        objectiveSelect: [
          'select[name="campaign_plan[objective]"]',
          'select#campaign_plan_objective',
          'select:has(option:contains("objective"))'
        ],
        audienceTextarea: [
          'textarea[name="campaign_plan[target_audience]"]',
          'textarea#campaign_plan_target_audience',
          '.smart-field[data-smart-suggestions-field-name-value="target_audience"] textarea',
          'textarea[placeholder*="audience"]'
        ],
        budgetTextarea: [
          'textarea[name="campaign_plan[budget_constraints]"]',
          'textarea#campaign_plan_budget_constraints',
          '.smart-field[data-smart-suggestions-field-name-value="budget_constraints"] textarea',
          'textarea[placeholder*="budget"]'
        ],
        timelineTextarea: [
          'textarea[name="campaign_plan[timeline_constraints]"]',
          'textarea#campaign_plan_timeline_constraints',
          '.smart-field[data-smart-suggestions-field-name-value="timeline_constraints"] textarea',
          'textarea[placeholder*="timeline"]'
        ],
        generateButton: [
          'button:has-text("Generate Plan")',
          'text="Generate Plan"',
          'button[data-action="generate"]',
          'a:has-text("Generate Plan")',
          'input[value*="Generate"]'
        ],
        regenerateButton: [
          'button:has-text("Regenerate")',
          'text="Regenerate"',
          'button[data-action="regenerate"]',
          'a:has-text("Regenerate")'
        ],
        statusIndicator: [
          '[data-status]',
          '.status-indicator',
          '[class*="bg-"][class*="text-"]',
          '.bg-yellow-100',
          '.bg-green-100',
          '.bg-red-100'
        ]
      },

      // Content Generation elements
      content: {
        newButton: [
          'a[href="/generated_contents/new"]',
          'text="New Content"',
          'button:has-text("New Content")'
        ],
        titleInput: 'input[name="generated_content[title]"]',
        typeSelect: 'select[name="generated_content[content_type]"]',
        variantSelect: 'select[name="generated_content[format_variant]"]',
        bodyTextarea: 'textarea[name="generated_content[body_content]"]',
        generateButton: [
          'button:has-text("Generate Content")',
          'text="Generate Content"',
          'button[data-action="generate"]'
        ],
        optimizeButton: [
          'button:has-text("Optimize")',
          'text="Optimize Content"',
          '[data-optimize]'
        ],
        createVariantsButton: [
          'button:has-text("Create Variants")',
          'text="A/B Variants"',
          '[data-variants]'
        ]
      },

      // Journey elements
      journey: {
        newButton: [
          'a[href="/journeys/new"]',
          'text="New Journey"',
          'button:has-text("New Journey")'
        ],
        nameInput: 'input[name="journey[name]"]',
        descriptionTextarea: 'textarea[name="journey[description]"]',
        typeSelect: 'select[name="journey[journey_type]"]',
        addStepButton: [
          'button:has-text("Add Step")',
          'text="Add Step"',
          'button[data-action="add-step"]'
        ],
        suggestionsButton: [
          'button:has-text("Get AI Suggestions")',
          'text="AI Suggestions"',
          '[data-ai-suggestions] button'
        ]
      },

      // Brand Identity elements
      brand: {
        newButton: [
          'a[href="/brand_identities/new"]',
          'text="New Brand Identity"',
          'button:has-text("New Brand Identity")'
        ],
        nameInput: 'input[name="brand_identity[name]"]',
        industrySelect: 'select[name="brand_identity[industry]"]',
        voiceToneSelect: 'select[name="brand_identity[voice_tone]"]',
        audienceInput: 'input[name="brand_identity[target_audience]"]',
        guidelinesTextarea: 'textarea[name="brand_identity[brand_guidelines]"]',
        fileUpload: 'input[type="file"]',
        processMaterialsButton: [
          'button:has-text("Process Materials")',
          'text="Process Materials"',
          'button[data-action="process"]'
        ]
      },

      // Common form elements - updated with more robust selectors
      form: {
        submitButton: [
          'button[type="submit"]:not([role="menuitem"])',
          'input[type="submit"]',
          'button:has-text("Create Campaign Plan")',
          'form button:has-text("Create")',
          'form button:has-text("Save")',
          'form button:has-text("Submit")',
          'button.bg-blue-600',
          '[data-action="submit"]'
        ],
        cancelButton: [
          'button:has-text("Cancel")',
          'a:has-text("Cancel")',
          'button[data-action="cancel"]'
        ],
        deleteButton: [
          'button:has-text("Delete")',
          'text="Delete"',
          'button[data-action="delete"]'
        ],
        confirmButton: [
          'button:has-text("Confirm")',
          'button:has-text("Yes")',
          'button[data-action="confirm"]'
        ]
      },

      // Status and loading indicators
      status: {
        loading: [
          '.loading',
          '[data-loading]',
          'text="Loading"',
          '.spinner'
        ],
        success: [
          '.bg-green',
          '[data-status="success"]',
          'text="Success"',
          '.alert-success'
        ],
        error: [
          '.bg-red',
          '[data-status="error"]',
          '.alert-error',
          '[data-error]'
        ],
        processing: [
          'text="generating"',
          'text="processing"',
          '[data-status="processing"]',
          '.bg-yellow'
        ]
      }
    };
  }

  /**
   * Try multiple selectors until one works
   * @param {string|Array} selectors - Single selector or array of selectors
   * @param {Object} options - Options for the operation
   * @returns {Promise<boolean>} - True if element was found
   */
  async trySelectors(selectors, options = {}) {
    const selectorArray = Array.isArray(selectors) ? selectors : [selectors];
    const { timeout = 5000, action = 'waitFor' } = options;

    for (const selector of selectorArray) {
      try {
        switch (action) {
          case 'click':
            await this.page.click(selector, { timeout });
            return true;
          case 'fill':
            await this.page.fill(selector, options.value, { timeout });
            return true;
          case 'isVisible':
            return await this.page.isVisible(selector);
          case 'waitFor':
          default:
            await this.page.waitForSelector(selector, { timeout });
            return true;
        }
      } catch (error) {
        // Log the attempt for debugging
        console.log(`Selector "${selector}" failed: ${error.message}`);
        continue;
      }
    }

    console.log(`All selectors failed: ${selectorArray.join(', ')}`);
    return false;
  }

  /**
   * Check if page context is still active
   * @returns {boolean} True if context is active
   */
  isContextActive() {
    try {
      return !this.page.isClosed();
    } catch (error) {
      return false;
    }
  }

  /**
   * Robust click that tries multiple strategies with context checking
   * @param {string|Array} selectors - Selector(s) to try
   * @param {Object} options - Click options
   */
  async robustClick(selectors, options = {}) {
    const { 
      timeout = 10000, 
      retries = 3, 
      waitForStable = false,
      forceClick = false 
    } = options;

    if (!this.isContextActive()) {
      throw new Error('Page context is closed, cannot perform click operation');
    }

    const selectorArray = Array.isArray(selectors) ? selectors : [selectors];
    const individualTimeout = Math.max(1000, timeout / (retries * selectorArray.length));

    for (let attempt = 0; attempt < retries; attempt++) {
      if (!this.isContextActive()) {
        throw new Error('Page context was closed during click attempts');
      }

      for (const selector of selectorArray) {
        try {
          // Wait for element to be visible and stable
          await this.page.waitForSelector(selector, { 
            state: 'visible', 
            timeout: individualTimeout
          });

          // Optional: wait for element to be stable (not moving)
          if (waitForStable) {
            await this.page.waitForTimeout(200); // Reduced from 500ms
          }

          // Try normal click first
          if (!forceClick) {
            await this.page.click(selector, { timeout: 2000 });
          } else {
            // Force click if normal click fails
            await this.page.locator(selector).first().click({ force: true });
          }

          console.log(`Successfully clicked: ${selector}`);
          return true;
        } catch (error) {
          console.log(`Click attempt ${attempt + 1} failed for selector "${selector}": ${error.message}`);
          
          // Don't continue if context is closed
          if (error.message.includes('Target page, context or browser has been closed')) {
            throw new Error('Browser context closed during operation');
          }
          continue;
        }
      }
      
      // Wait before retry, but check context first
      if (attempt < retries - 1 && this.isContextActive()) {
        try {
          await this.page.waitForTimeout(500); // Reduced from 1000ms
        } catch (error) {
          // Context may have closed during wait
          break;
        }
      }
    }

    throw new Error(`Failed to click any of the selectors: ${selectorArray.join(', ')}`);
  }

  /**
   * Robust fill that handles different input types with context checking
   * @param {string|Array} selectors - Selector(s) to try
   * @param {string} value - Value to fill
   * @param {Object} options - Fill options
   */
  async robustFill(selectors, value, options = {}) {
    const { timeout = 10000, clear = true } = options;
    
    if (!this.isContextActive()) {
      throw new Error('Page context is closed, cannot perform fill operation');
    }

    const selectorArray = Array.isArray(selectors) ? selectors : [selectors];
    const individualTimeout = Math.max(1000, timeout / selectorArray.length);

    for (const selector of selectorArray) {
      try {
        await this.page.waitForSelector(selector, { 
          state: 'visible', 
          timeout: individualTimeout 
        });
        
        if (clear) {
          await this.page.fill(selector, ''); // Clear first
        }
        
        await this.page.fill(selector, value);
        console.log(`Successfully filled "${value}" in ${selector}`);
        return true;
      } catch (error) {
        console.log(`Fill attempt failed for ${selector}: ${error.message}`);
        
        // Don't continue if context is closed
        if (error.message.includes('Target page, context or browser has been closed')) {
          throw new Error('Browser context closed during operation');
        }
        continue;
      }
    }

    throw new Error(`Failed to fill any of the selectors: ${selectorArray.join(', ')}`);
  }

  /**
   * Robust select that handles different select types
   * @param {string|Array} selectors - Selector(s) to try
   * @param {string} value - Value to select
   * @param {Object} options - Select options
   */
  async robustSelect(selectors, value, options = {}) {
    const { timeout = 10000, allowMissing = false } = options;
    const selectorArray = Array.isArray(selectors) ? selectors : [selectors];

    for (const selector of selectorArray) {
      try {
        // Check if element exists and is visible
        const element = await this.page.locator(selector).first();
        await element.waitFor({ state: 'visible', timeout: timeout / selectorArray.length });
        
        // Get both option text and values
        const optionTexts = await element.locator('option').allTextContents();
        const optionValues = await element.locator('option').evaluateAll(opts => 
          opts.map(opt => opt.value)
        );
        
        // Try to match by value first (exact match)
        let hasOption = optionValues.includes(value);
        let selectionValue = value;
        
        // If not found by value, try by text (case-insensitive)
        if (!hasOption) {
          const matchingText = optionTexts.find(text => 
            text.toLowerCase() === value.toLowerCase() ||
            text.toLowerCase().replace(/[_\s]/g, '') === value.toLowerCase().replace(/[_\s]/g, '')
          );
          
          if (matchingText) {
            const textIndex = optionTexts.indexOf(matchingText);
            selectionValue = optionValues[textIndex];
            hasOption = true;
            console.log(`Matched "${value}" to option text "${matchingText}" with value "${selectionValue}"`);
          }
        }
        
        if (hasOption) {
          await this.page.selectOption(selector, selectionValue);
          console.log(`Successfully selected "${selectionValue}" from ${selector}`);
          return true;
        } else {
          console.log(`Option "${value}" not available in ${selector}.`);
          console.log(`Available texts: ${optionTexts.slice(0, 5).join(', ')}`);
          console.log(`Available values: ${optionValues.slice(0, 5).join(', ')}`);
          if (allowMissing) return true; // Consider it successful if missing is allowed
        }
      } catch (error) {
        console.log(`Select attempt failed for ${selector}: ${error.message}`);
        continue;
      }
    }

    if (allowMissing) {
      console.log(`Select field not found but allowMissing=true: ${selectorArray.join(', ')}`);
      return true;
    }
    
    throw new Error(`Failed to select "${value}" from any of the selectors: ${selectorArray.join(', ')}`);
  }

  /**
   * Wait for any of multiple conditions
   * @param {Object} conditions - Object with condition names and selectors
   * @param {Object} options - Wait options
   */
  async waitForAnyCondition(conditions, options = {}) {
    const { timeout = 30000 } = options;
    const startTime = Date.now();

    while (Date.now() - startTime < timeout) {
      for (const [conditionName, selectors] of Object.entries(conditions)) {
        const selectorArray = Array.isArray(selectors) ? selectors : [selectors];
        
        for (const selector of selectorArray) {
          try {
            if (await this.page.isVisible(selector)) {
              return { condition: conditionName, selector };
            }
          } catch (error) {
            // Continue checking other selectors
          }
        }
      }
      
      // Wait a bit before checking again
      await this.page.waitForTimeout(500);
    }

    throw new Error(`None of the conditions were met within ${timeout}ms`);
  }

  /**
   * Smart form submission that handles different form types
   * @param {Object} formData - Data to fill in the form
   * @param {Object} options - Submission options
   */
  async submitForm(formData, options = {}) {
    const { 
      submitSelectors,
      waitForRedirect = true,
      expectedUrl 
    } = options;
    
    const selectors = this.getSelectors();
    const defaultSubmitSelectors = submitSelectors || selectors.form.submitButton;

    // Fill form fields
    for (const [fieldName, value] of Object.entries(formData)) {
      const fieldSelectors = this.getFieldSelectors(fieldName);
      if (fieldSelectors) {
        if (fieldSelectors.type === 'select') {
          await this.robustSelect(fieldSelectors.selectors, value);
        } else {
          await this.robustFill(fieldSelectors.selectors, value);
        }
      }
    }

    // Submit form
    await this.robustClick(defaultSubmitSelectors, { 
      waitForStable: true,
      retries: 3
    });

    // Wait for form submission result
    if (waitForRedirect) {
      if (expectedUrl) {
        await this.page.waitForURL(expectedUrl, { timeout: 30000 });
      } else {
        // Wait for URL change or success indicator
        await this.waitForAnyCondition({
          urlChange: () => this.page.url() !== this.initialUrl,
          success: selectors.status.success,
          error: selectors.status.error
        }, { timeout: 30000 });
      }
    }
  }

  /**
   * Get field selectors based on common field names
   * @private
   */
  getFieldSelectors(fieldName) {
    const fieldMap = {
      email: {
        type: 'input',
        selectors: ['input[name*="email"]', 'input[type="email"]']
      },
      password: {
        type: 'input',
        selectors: ['input[name*="password"]', 'input[type="password"]']
      },
      name: {
        type: 'input', 
        selectors: ['input[name*="name"]', 'input[name*="title"]']
      },
      description: {
        type: 'textarea',
        selectors: ['textarea[name*="description"]']
      },
      type: {
        type: 'select',
        selectors: ['select[name*="type"]']
      },
      audience: {
        type: 'textarea',
        selectors: ['textarea[name*="audience"]', 'input[name*="audience"]']
      }
    };

    return fieldMap[fieldName] || null;
  }
}

module.exports = SelectorHelper;