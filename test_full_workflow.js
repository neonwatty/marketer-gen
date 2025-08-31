const { chromium } = require('playwright');

(async () => {
  console.log('🎯 Testing full demo workflow: click → dialog → navigation → interactive tour...');
  
  const browser = await chromium.launch({ headless: false, slowMo: 1500 });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Capture console messages
  page.on('console', msg => {
    const type = msg.type();
    console.log(`🖥️  BROWSER: ${msg.text()}`);
  });

  try {
    console.log('📡 Loading demos page...');
    await page.goto('http://127.0.0.1:3000/demos', { waitUntil: 'networkidle' });
    
    console.log('⏳ Waiting for demo controller to initialize...');
    await page.waitForTimeout(3000);
    
    // Verify everything is loaded
    const initialStatus = await page.evaluate(() => {
      return {
        demoControllerExists: typeof window.demoController === 'object',
        cardsFound: document.querySelectorAll('.start-demo-btn').length,
        introJsAvailable: typeof window.introJs === 'function'
      };
    });
    
    console.log('📊 Initial status:', initialStatus);
    
    if (!initialStatus.demoControllerExists) {
      console.log('❌ Demo controller not found, aborting test');
      return;
    }
    
    console.log('🖱️  Clicking "social-content" demo card...');
    
    // Set up dialog handler BEFORE clicking
    let dialogResult = null;
    page.on('dialog', async dialog => {
      console.log(`📋 Dialog appeared: ${dialog.type()}`);
      console.log(`📋 Dialog message preview: ${dialog.message().substring(0, 100)}...`);
      
      // Accept the dialog to choose "Interactive App Tour"
      await dialog.accept();
      dialogResult = 'accepted';
      console.log('✅ Chose Interactive App Tour');
    });
    
    // Click the demo card
    await page.click('.start-demo-btn[data-workflow="social-content"]');
    
    console.log('⏳ Waiting for dialog and navigation...');
    await page.waitForTimeout(3000);
    
    if (!dialogResult) {
      console.log('⚠️  No dialog appeared. Checking for errors...');
      
      const errorState = await page.evaluate(() => {
        return {
          currentUrl: window.location.href,
          lastError: window.lastError || 'No error recorded'
        };
      });
      
      console.log('Error state:', errorState);
      return;
    }
    
    console.log('🧭 Checking if navigation occurred...');
    await page.waitForTimeout(2000);
    
    const navigationResult = await page.evaluate(() => {
      return {
        currentUrl: window.location.href,
        urlParams: window.location.search,
        hasDemoTourParam: window.location.search.includes('demo_tour=social-content'),
        hasAnalyticsParam: window.location.search.includes('analytics_id='),
        demoTourManagerExists: typeof window.demoTourManager !== 'undefined'
      };
    });
    
    console.log('🎯 Navigation result:', navigationResult);
    
    if (navigationResult.hasDemoTourParam) {
      console.log('🎉 SUCCESS: Navigated to app with demo parameters!');
      
      console.log('⏳ Waiting for interactive tour to start...');
      await page.waitForTimeout(5000);
      
      // Check for tour elements
      const tourStatus = await page.evaluate(() => {
        return {
          tooltipElements: document.querySelectorAll('.introjs-tooltip, .demo-tour-tooltip').length,
          overlayElements: document.querySelectorAll('.introjs-overlay').length,
          highlightElements: document.querySelectorAll('.introjs-highlight, .demo-tour-highlight').length,
          bodyHasIntroClass: document.body.classList.contains('introjs-on'),
          pageTitle: document.title,
          formElements: document.querySelectorAll('form, input, button[type="submit"]').length
        };
      });
      
      console.log('🎬 Tour status on target page:', tourStatus);
      
      if (tourStatus.tooltipElements > 0 || tourStatus.overlayElements > 0) {
        console.log('🎊 SUCCESS: Interactive tour is running!');
      } else {
        console.log('⚠️  Tour elements not detected. Tour might not have started yet.');
      }
      
    } else {
      console.log('❌ Navigation failed - still on demo page');
    }
    
    console.log('🔍 Keeping browser open for inspection...');
    await page.waitForTimeout(15000);
    
  } catch (error) {
    console.log('💥 Error during workflow test:', error.message);
  } finally {
    await browser.close();
  }
})();