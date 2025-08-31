// Wait helpers for handling asynchronous operations in AI workflow tests
const SelectorHelper = require('./selector-helper');

class WaitHelpers {
  constructor(page) {
    this.page = page;
    this.selectorHelper = new SelectorHelper(page);
  }

  /**
   * Wait for AI processing to complete by monitoring status changes
   * Enhanced to handle the actual UI status system
   * @param {Object} options - Configuration options
   * @returns {string} Final status
   */
  async waitForAIProcessing(options = {}) {
    const {
      timeout = 300000, // 5 minutes default for AI operations
      pollingInterval = 3000, // 3 seconds to match UI polling
      statusSelector = '.bg-yellow-100.text-yellow-800, .bg-green-100.text-green-800, .bg-red-100.text-red-800',
      completedStates = ['Completed', 'completed', 'success', 'done', 'generated'],
      failedStates = ['Failed', 'failed', 'error'],
      processingStates = ['Generating', 'generating', 'processing', 'in_progress']
    } = options;

    const startTime = Date.now();

    return new Promise(async (resolve, reject) => {
      const checkStatus = async () => {
        try {
          const elapsedTime = Date.now() - startTime;
          
          // Warn at 80% of timeout
          if (elapsedTime > timeout * 0.8 && !this.timeoutWarningShown) {
            console.warn(`AI processing taking longer than expected (${Math.round(elapsedTime/1000)}s/${Math.round(timeout/1000)}s)`);
            this.timeoutWarningShown = true;
          }
          
          // Check if we've exceeded timeout
          if (elapsedTime > timeout) {
            reject(new Error(`AI processing timeout after ${Math.round(timeout/1000)} seconds. Consider increasing timeout or checking server performance.`));
            return;
          }

          // Get current status using multiple strategies
          let currentStatus = null;

          // Strategy 1: Check status badge text content
          const statusSelectors = statusSelector.split(', ');
          for (const selector of statusSelectors) {
            try {
              if (await this.page.isVisible(selector, { timeout: 1000 })) {
                currentStatus = await this.page.textContent(selector);
                console.log(`Found status badge: "${currentStatus}" via ${selector}`);
                break;
              }
            } catch (error) {
              // Try next selector
            }
          }

          // Strategy 2: Check for progress tracking section
          if (!currentStatus) {
            if (await this.page.isVisible('[data-controller="progress-tracker"]', { timeout: 1000 })) {
              currentStatus = 'generating'; // Progress tracker means still generating
              console.log('Found progress tracker - status: generating');
            }
          }

          // Strategy 3: Check for success/completion indicators
          if (!currentStatus) {
            const completionIndicators = [
              { selector: '.bg-green-50.border-green-200', status: 'completed' },
              { selector: 'text="Campaign Plan Generated Successfully"', status: 'completed' },
              { selector: '.bg-red-50.border-red-200', status: 'failed' }
            ];
            
            for (const { selector, status } of completionIndicators) {
              if (await this.page.isVisible(selector, { timeout: 1000 })) {
                currentStatus = status;
                console.log(`Found completion indicator: ${selector} -> ${status}`);
                break;
              }
            }
          }

          // Strategy 4: Fallback to page text search (last resort)
          if (!currentStatus) {
            try {
              const pageText = await this.page.textContent('body');
              
              for (const state of [...completedStates, ...failedStates, ...processingStates]) {
                if (pageText.toLowerCase().includes(state.toLowerCase())) {
                  currentStatus = state;
                  console.log(`Found status in page text: "${state}"`);
                  break;
                }
              }
            } catch (error) {
              console.log('Failed to get page text for status detection');
            }
          }

          console.log(`AI Processing Status: ${currentStatus}`);

          // Check if completed successfully
          if (completedStates.includes(currentStatus)) {
            resolve(currentStatus);
            return;
          }

          // Check if failed
          if (failedStates.includes(currentStatus)) {
            reject(new Error(`AI processing failed with status: ${currentStatus}`));
            return;
          }

          // Still processing, continue polling
          setTimeout(checkStatus, pollingInterval);

        } catch (error) {
          reject(error);
        }
      };

      // Start status checking
      checkStatus();
    });
  }

  /**
   * Wait for content to appear in a specific element
   * @param {string} selector - Element selector
   * @param {Object} options - Configuration options
   * @returns {string} Generated content
   */
  async waitForContentGeneration(selector, options = {}) {
    const {
      timeout = 120000, // 2 minutes for content generation
      minLength = 10,
      excludeText = ['loading', 'generating', 'processing']
    } = options;

    await this.page.waitForSelector(selector, { timeout });

    // Wait for meaningful content to appear
    await this.page.waitForFunction(
      ({ selector, minLength, excludeText }) => {
        const element = document.querySelector(selector);
        if (!element) return false;

        const content = element.textContent || element.value || '';
        
        // Check minimum length
        if (content.trim().length < minLength) return false;

        // Exclude loading/processing text
        const lowerContent = content.toLowerCase();
        for (const exclude of excludeText) {
          if (lowerContent.includes(exclude.toLowerCase())) return false;
        }

        return true;
      },
      { selector, minLength, excludeText },
      { timeout }
    );

    // Return the generated content
    return await this.page.$eval(selector, el => el.textContent || el.value || '');
  }

  /**
   * Wait for form submission and response
   * @param {string} submitSelector - Submit button selector
   * @param {Object} options - Configuration options
   */
  async waitForFormSubmission(submitSelector, options = {}) {
    const {
      timeout = 30000,
      waitForNavigation = false,
      successIndicators = ['.alert-success', '.bg-green-', '[data-success]'],
      errorIndicators = ['.alert-error', '.bg-red-', '[data-error]']
    } = options;

    // Click submit button
    await this.page.click(submitSelector);

    if (waitForNavigation) {
      // Wait for page navigation
      await this.page.waitForNavigation({ timeout });
    } else {
      // Wait for success or error indicators
      await Promise.race([
        // Wait for success
        Promise.all(successIndicators.map(selector => 
          this.page.waitForSelector(selector, { timeout }).catch(() => null)
        )),
        // Wait for error
        Promise.all(errorIndicators.map(selector => 
          this.page.waitForSelector(selector, { timeout }).catch(() => null)
        ))
      ]);
    }
  }

  /**
   * Wait for page to stabilize (no more network requests)
   * @param {Object} options - Configuration options
   */
  async waitForPageStable(options = {}) {
    const {
      timeout = 10000,
      networkIdleTimeout = 2000,
      maxRequests = 2
    } = options;

    let requestCount = 0;
    let lastRequestTime = Date.now();

    // Monitor network requests
    this.page.on('request', () => {
      requestCount++;
      lastRequestTime = Date.now();
    });

    // Wait for network to be idle
    await this.page.waitForFunction(
      ({ networkIdleTimeout, maxRequests, startTime }) => {
        return Date.now() - window.lastRequestTime > networkIdleTimeout;
      },
      { networkIdleTimeout, maxRequests, startTime: Date.now() },
      { timeout }
    );
  }

  /**
   * Wait for specific text to appear on page
   * @param {string} text - Text to wait for
   * @param {Object} options - Configuration options
   */
  async waitForText(text, options = {}) {
    const {
      timeout = 10000,
      selector = 'body',
      caseSensitive = false
    } = options;

    const searchText = caseSensitive ? text : text.toLowerCase();

    await this.page.waitForFunction(
      ({ selector, searchText, caseSensitive }) => {
        const element = document.querySelector(selector);
        if (!element) return false;

        const content = caseSensitive ? 
          element.textContent : 
          element.textContent.toLowerCase();

        return content.includes(searchText);
      },
      { selector, searchText, caseSensitive },
      { timeout }
    );
  }
  
  /**
   * Wait for any of multiple conditions to be met
   * @param {Object} conditions - Object with condition names and selectors
   * @param {Object} options - Wait options
   * @returns {Promise<{condition: string, selector: string}>} The condition that was met
   */
  async waitForAnyCondition(conditions, options = {}) {
    const { timeout = 30000 } = options;
    const startTime = Date.now();

    while (Date.now() - startTime < timeout) {
      for (const [conditionName, selectors] of Object.entries(conditions)) {
        const selectorArray = Array.isArray(selectors) ? selectors : [selectors];
        
        for (const selector of selectorArray) {
          try {
            if (await this.page.isVisible(selector, { timeout: 500 })) {
              console.log(`✅ Condition met: ${conditionName} (${selector})`);
              return { condition: conditionName, selector };
            }
          } catch (error) {
            // Continue checking other selectors
          }
        }
      }
      
      // Wait a bit before checking again
      await this.page.waitForTimeout(1000);
    }

    throw new Error(`None of the conditions were met within ${timeout}ms. Conditions: ${Object.keys(conditions).join(', ')}`);
  }

  /**
   * Wait for element to be stable (not changing)
   * @param {string} selector - Element selector
   * @param {Object} options - Configuration options
   */
  async waitForElementStable(selector, options = {}) {
    const {
      timeout = 10000,
      stableTime = 1000,
      attribute = 'textContent'
    } = options;

    let lastValue = null;
    let stableStart = null;

    const checkStability = async () => {
      const element = await this.page.$(selector);
      if (!element) return false;

      const currentValue = await element.evaluate((el, attr) => {
        return attr === 'textContent' ? el.textContent : el.getAttribute(attr);
      }, attribute);

      if (currentValue === lastValue) {
        if (!stableStart) stableStart = Date.now();
        return Date.now() - stableStart >= stableTime;
      } else {
        lastValue = currentValue;
        stableStart = null;
        return false;
      }
    };

    await this.page.waitForFunction(
      checkStability,
      {},
      { timeout, polling: 100 }
    );
  }

  /**
   * Wait for loading states to complete
   * @param {Object} options - Configuration options
   */
  async waitForLoadingComplete(options = {}) {
    const {
      timeout = 30000,
      loadingSelectors = [
        '.loading',
        '.spinner',
        '[data-loading]',
        '.skeleton',
        'text=Loading',
        'text=Generating',
        'text=Processing'
      ]
    } = options;

    // Wait for all loading indicators to disappear
    for (const selector of loadingSelectors) {
      try {
        await this.page.waitForSelector(selector, { state: 'detached', timeout: 5000 });
      } catch (error) {
        // Ignore if selector not found - that's what we want
      }
    }

    // Wait for any animations to complete
    await this.page.waitForLoadState('networkidle');
  }

  /**
   * Smart wait that combines multiple waiting strategies
   * @param {Object} options - Configuration options
   */
  async smartWait(options = {}) {
    const {
      waitForContent = false,
      contentSelector = null,
      waitForStable = false,
      waitForNetwork = true,
      customValidator = null
    } = options;

    // Wait for loading to complete
    await this.waitForLoadingComplete();

    // Wait for network if requested
    if (waitForNetwork) {
      await this.page.waitForLoadState('networkidle');
    }

    // Wait for content if requested
    if (waitForContent && contentSelector) {
      await this.waitForContentGeneration(contentSelector);
    }

    // Wait for stability if requested
    if (waitForStable && contentSelector) {
      await this.waitForElementStable(contentSelector);
    }

    // Run custom validator if provided
    if (customValidator) {
      await this.page.waitForFunction(customValidator);
    }
  }

  /**
   * Retry an operation with exponential backoff
   * @param {Function} operation - Operation to retry
   * @param {Object} options - Configuration options
   */
  async retryOperation(operation, options = {}) {
    const {
      maxRetries = 3,
      baseDelay = 1000,
      backoffMultiplier = 2,
      maxDelay = 10000
    } = options;

    let lastError;
    
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        lastError = error;
        
        if (attempt === maxRetries) {
          throw lastError;
        }

        const delay = Math.min(
          baseDelay * Math.pow(backoffMultiplier, attempt - 1),
          maxDelay
        );

        console.log(`Attempt ${attempt} failed, retrying in ${delay}ms...`);
        await this.page.waitForTimeout(delay);
      }
    }
  }

  /**
   * Robust button click that tries multiple strategies (delegates to SelectorHelper)
   * @param {Array|string} selectors - Selector(s) to try
   * @param {Object} options - Configuration options
   * @returns {Promise<boolean>} True if successful
   */
  async robustClick(selectors, options = {}) {
    return await this.selectorHelper.robustClick(selectors, options);
  }
  
  /**
   * Robust fill that handles different input types (delegates to SelectorHelper)
   * @param {string|Array} selectors - Selector(s) to try
   * @param {string} value - Value to fill
   * @param {Object} options - Fill options
   */
  async robustFill(selectors, value, options = {}) {
    return await this.selectorHelper.robustFill(selectors, value, options);
  }
  
  /**
   * Robust select that handles different select types (delegates to SelectorHelper)
   * @param {string|Array} selectors - Selector(s) to try
   * @param {string} value - Value to select
   * @param {Object} options - Select options
   */
  async robustSelect(selectors, value, options = {}) {
    return await this.selectorHelper.robustSelect(selectors, value, options);
  }
}

module.exports = WaitHelpers;