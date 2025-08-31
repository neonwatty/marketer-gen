// Authentication helper utilities for Playwright AI workflow tests

class AuthHelper {
  constructor(page) {
    this.page = page;
  }

  /**
   * Create a test user and log them in with better error handling
   * @param {Object} options - User options
   * @returns {Object} User data
   */
  async createAndLoginTestUser(options = {}) {
    const userData = {
      email: options.email || `test-${Date.now()}-${Math.random().toString(36).substring(7)}@example.com`,
      password: options.password || 'testpassword123',
      name: options.name || 'Test User'
    };

    try {
      // Navigate to sign up page with extended timeout for slow server
      await this.page.goto('/sign_up', { timeout: 60000 });

      // Fill out registration form with individual error handling
      await this.page.fill('input[name="user[email_address]"]', userData.email);
      await this.page.fill('input[name="user[password]"]', userData.password);
      await this.page.fill('input[name="user[password_confirmation]"]', userData.password);
      
      // Optional name field
      try {
        if (await this.page.isVisible('input[name="user[name]"]', { timeout: 2000 })) {
          await this.page.fill('input[name="user[name]"]', userData.name);
        }
      } catch (error) {
        console.log('Name field not available or required');
      }

      // Submit registration with better selector
      const submitSelectors = [
        'button[type="submit"]:not([role="menuitem"])',
        'input[type="submit"]', 
        'button:has-text("Sign Up")',
        'form button'
      ];
      
      let submitted = false;
      for (const selector of submitSelectors) {
        try {
          if (await this.page.isVisible(selector, { timeout: 2000 })) {
            await this.page.click(selector);
            submitted = true;
            break;
          }
        } catch (error) {
          continue;
        }
      }
      
      if (!submitted) {
        throw new Error('Could not find submit button for registration form');
      }

      // Wait for successful registration and redirect with more lenient checks
      try {
        await this.page.waitForURL('/', { timeout: 30000 });
      } catch (error) {
        // Check if we're on a page that indicates successful login
        if (this.page.url().includes('/campaign_plans') || 
            this.page.url().includes('/dashboard') ||
            await this.page.isVisible('text=You are logged in', { timeout: 2000 })) {
          console.log('Registration successful, on alternative landing page');
        } else {
          throw error;
        }
      }

      // Verify we're logged in with more flexible check
      try {
        await this.page.waitForSelector(`text=You are logged in as: ${userData.email}`, { timeout: 8000 });
      } catch (error) {
        // Alternative check - look for any logged-in indicator
        const loggedInIndicators = [
          'text=You are logged in',
          'button:has-text("Sign Out")',
          'text=Dashboard',
          'text=Campaign Plans'
        ];
        
        let isLoggedIn = false;
        for (const indicator of loggedInIndicators) {
          if (await this.page.isVisible(indicator, { timeout: 1000 })) {
            isLoggedIn = true;
            break;
          }
        }
        
        if (!isLoggedIn) {
          // If registration didn't auto-login, try explicit login
          console.log('Registration did not auto-login, attempting explicit login...');
          await this.login(userData.email, userData.password);
        }
      }

      return userData;
    } catch (error) {
      console.error('User creation and login failed:', error.message);
      throw error;
    }
  }

  /**
   * Log in with existing user credentials
   * @param {string} email 
   * @param {string} password 
   */
  async login(email, password) {
    // Navigate to login page (using session resource route)
    await this.page.goto('/session/new', { timeout: 30000 });

    // Fill login form with proper field names
    await this.page.fill('input[name="session[email_address]"], input[name="email_address"]', email);
    await this.page.fill('input[name="session[password]"], input[name="password"]', password);

    // Submit login form
    await this.page.click('button[type="submit"], input[type="submit"]');

    // Wait for successful login redirect
    await this.page.waitForURL('/', { timeout: 20000 });
    
    // Verify login success with flexible checking
    try {
      await this.page.waitForSelector('text=You are logged in as: ' + email, { timeout: 8000 });
    } catch (error) {
      // Check for alternative login indicators
      const loginSuccessIndicators = [
        'button:has-text("Sign Out")',
        'text=Dashboard',
        'text=You are logged in',
        '.bg-green-50'
      ];
      
      let loginSuccess = false;
      for (const indicator of loginSuccessIndicators) {
        if (await this.page.isVisible(indicator, { timeout: 2000 })) {
          loginSuccess = true;
          break;
        }
      }
      
      if (!loginSuccess) {
        throw new Error(`Login verification failed for ${email}. Current URL: ${this.page.url()}`);
      }
    }
  }

  /**
   * Log out current user with better error handling
   */
  async logout() {
    // Check if page context is still active
    if (this.page.isClosed()) {
      console.log('Page context already closed, skipping logout');
      return;
    }

    try {
      // Look for sign out button/form
      if (await this.page.isVisible('button:has-text("Sign Out")', { timeout: 5000 })) {
        await this.page.click('button:has-text("Sign Out")');
      } else if (await this.page.isVisible('form[action="/session"]', { timeout: 5000 })) {
        await this.page.click('form[action="/session"] button[type="submit"]');
      } else {
        console.log('No logout button found, may already be logged out');
        return;
      }

      // Wait for redirect to login/home page with shorter timeout
      try {
        await this.page.waitForFunction(() => 
          window.location.pathname === '/' || 
          window.location.pathname === '/sessions/new',
          { timeout: 10000 }
        );
      } catch (error) {
        console.log('Logout redirect timeout, checking current URL:', this.page.url());
        
        // Check if context is still active before navigation
        if (!this.page.isClosed()) {
          try {
            // Fallback: if we're not already on login page, navigate there
            if (!this.page.url().includes('/sessions/new') && !this.page.url().endsWith('/')) {
              await this.page.goto('/sessions/new', { timeout: 5000 });
            }
          } catch (navError) {
            console.log('Navigation during logout failed, context may be closing');
          }
        }
      }
    } catch (error) {
      console.log('Logout operation failed:', error.message);
      // Don't throw - cleanup should not fail the test
    }
  }

  /**
   * Ensure user is logged in, create account if needed
   */
  async ensureLoggedIn() {
    // Check if already logged in by looking for sign out button
    if (await this.page.isVisible('button:has-text("Sign Out")')) {
      return;
    }

    // Not logged in, create and login test user
    return await this.createAndLoginTestUser();
  }

  /**
   * Get current user info from the page
   */
  async getCurrentUserInfo() {
    await this.page.goto('/');
    
    // Extract user email from the green banner
    const userEmail = await this.page.textContent('.bg-green-50 p:has-text("You are logged in as:")');
    
    if (userEmail) {
      return {
        email: userEmail.replace('You are logged in as: ', '').trim()
      };
    }
    
    return null;
  }

  /**
   * Clean up test user data (if supported by the app)
   */
  async cleanupTestUser(email) {
    // This would need to be implemented based on the app's user management
    // For now, we'll rely on test database cleanup
    console.log(`Test cleanup needed for user: ${email}`);
  }
}

module.exports = AuthHelper;