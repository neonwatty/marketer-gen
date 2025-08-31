const { chromium } = require('playwright');

(async () => {
  console.log('🧪 Testing cleaned up demo system...');
  
  const browser = await chromium.launch({ headless: false, slowMo: 1000 });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Enable console logging
  page.on('console', msg => {
    console.log(`🖥️  BROWSER: ${msg.text()}`);
  });
  
  try {
    console.log('📡 Navigating to demos page...');
    await page.goto('http://127.0.0.1:3000/demos', { waitUntil: 'networkidle' });
    
    console.log('⏳ Waiting for page to fully load...');
    await page.waitForTimeout(3000);
    
    // Check demo controller status
    const demoStatus = await page.evaluate(() => {
      return {
        demoControllerExists: typeof window.demoController !== 'undefined',
        demoControllerConstructor: window.demoController?.constructor?.name,
        workflowsAvailable: window.demoController ? Object.keys(window.demoController.workflows).length : 0,
        startTourMethod: typeof window.demoController?.startTour === 'function'
      };
    });
    
    console.log('Demo system status:', demoStatus);
    
    if (!demoStatus.demoControllerExists) {
      console.log('❌ Demo controller not found - checking for errors...');
      return;
    }
    
    // Check for demo cards
    const cardsFound = await page.evaluate(() => {
      const cards = document.querySelectorAll('.start-demo-btn');
      return {
        count: cards.length,
        workflows: Array.from(cards).map(card => card.getAttribute('data-workflow'))
      };
    });
    
    console.log('Demo cards:', cardsFound);
    
    // Test clicking a demo card
    console.log('🖱️  Testing social-content demo...');
    await page.click('.start-demo-btn[data-workflow="social-content"]');
    
    // Handle the confirmation dialog
    console.log('⏳ Waiting for confirmation dialog...');
    let dialogHandled = false;
    
    page.once('dialog', async dialog => {
      console.log(`📋 Dialog received: ${dialog.type()}`);
      console.log(`📋 Dialog message: ${dialog.message()}`);
      
      // Click "OK" to choose interactive app tour
      await dialog.accept();
      dialogHandled = true;
      console.log('✅ Chose interactive app tour');
    });
    
    // Wait for dialog or timeout
    await page.waitForTimeout(3000);
    
    if (!dialogHandled) {
      console.log('⚠️  No dialog appeared - checking for errors...');
      
      // Check for any error messages or issues
      const errorCheck = await page.evaluate(() => {
        return {
          consoleErrors: window.console?.error || 'Not available',
          alerts: document.querySelectorAll('.alert, .error, .notification').length,
          currentUrl: window.location.href
        };
      });
      
      console.log('Error check:', errorCheck);
    } else {
      console.log('🔍 Waiting for navigation...');
      await page.waitForTimeout(2000);
      
      const finalState = await page.evaluate(() => {
        return {
          currentUrl: window.location.href,
          urlHasDemoParams: window.location.search.includes('demo_tour='),
          demoTourManagerExists: typeof window.demoTourManager !== 'undefined'
        };
      });
      
      console.log('Final state:', finalState);
      
      if (finalState.urlHasDemoParams) {
        console.log('🎯 Successfully navigated with demo parameters!');
        
        // Wait for tour to initialize
        await page.waitForTimeout(3000);
        
        // Check for tour elements
        const tourElements = await page.evaluate(() => {
          return {
            tooltips: document.querySelectorAll('.introjs-tooltip, .demo-tour-tooltip').length,
            overlays: document.querySelectorAll('.introjs-overlay').length,
            highlights: document.querySelectorAll('.introjs-highlight, .demo-tour-highlight').length
          };
        });
        
        console.log('Tour elements found:', tourElements);
      }
    }
    
    // Keep browser open for inspection
    console.log('🔍 Keeping browser open for inspection...');
    await page.waitForTimeout(15000);
    
  } catch (error) {
    console.log('💥 Error during testing:', error.message);
  } finally {
    await browser.close();
  }
})();