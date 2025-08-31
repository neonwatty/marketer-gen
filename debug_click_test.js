const { chromium } = require('playwright');

(async () => {
  console.log('🔍 Debug clicking and tour start process...');
  
  const browser = await chromium.launch({ headless: false, slowMo: 1000 });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Enable all console logging
  page.on('console', msg => {
    console.log(`🖥️  BROWSER: ${msg.text()}`);
  });
  
  try {
    console.log('📡 Navigating to demos page...');
    await page.goto('http://127.0.0.1:3000/demos', { waitUntil: 'networkidle' });
    
    console.log('⏳ Waiting for page to fully load...');
    await page.waitForTimeout(3000);
    
    // Test if demo controller exists and works manually
    console.log('🧪 Testing demo controller manually...');
    const manualTest = await page.evaluate(() => {
      console.log('Manual test - Demo controller exists:', typeof window.demoController);
      console.log('Manual test - startTour method exists:', typeof window.demoController?.startTour);
      
      // Try to call startTour directly
      if (window.demoController && window.demoController.startTour) {
        console.log('Manual test - Calling startTour directly...');
        window.demoController.startTour('social-content');
        return { success: true, message: 'startTour called directly' };
      } else {
        return { success: false, message: 'Demo controller not available' };
      }
    });
    
    console.log('Manual test result:', manualTest);
    
    console.log('⏳ Waiting for manual tour call to process...');
    await page.waitForTimeout(5000);
    
    console.log('🔍 Checking for tour elements after manual call...');
    const tourCheck = await page.evaluate(() => {
      return {
        tooltips: document.querySelectorAll('.introjs-tooltip').length,
        overlays: document.querySelectorAll('.introjs-overlay').length,
        anyIntroElements: document.querySelectorAll('[class*="introjs"]').length,
        bodyHasIntroClass: document.body.classList.contains('introjs-on')
      };
    });
    
    console.log('Tour elements after manual call:', tourCheck);
    
    // Keep browser open for inspection
    console.log('🔍 Keeping browser open for inspection...');
    await page.waitForTimeout(20000);
    
  } catch (error) {
    console.log('💥 Error during testing:', error.message);
  } finally {
    await browser.close();
  }
})();