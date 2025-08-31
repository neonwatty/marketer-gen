const { chromium } = require('playwright');

(async () => {
  console.log('🎯 Final demo tour test with correct CSS...');
  
  const browser = await chromium.launch({ headless: false, slowMo: 1000 });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Enable console logging
  page.on('console', msg => {
    if (msg.text().includes('Started tour:') || msg.text().includes('Demo steps prepared:') || msg.text().includes('Error') || msg.text().includes('Failed')) {
      console.log(`🖥️  BROWSER: ${msg.text()}`);
    }
  });
  
  // Monitor CSS loading
  page.on('response', response => {
    if (response.url().includes('introjs.css')) {
      console.log(`🎨 CSS: ${response.status()} ${response.url()}`);
    }
  });
  
  try {
    console.log('📡 Navigating to demos page...');
    await page.goto('http://127.0.0.1:3000/demos', { waitUntil: 'networkidle' });
    
    console.log('⏳ Waiting for page to fully load...');
    await page.waitForTimeout(3000);
    
    console.log('🖱️  Clicking social-content demo button...');
    await page.click('.start-demo-btn[data-workflow="social-content"]', { force: true });
    
    console.log('⏳ Waiting for tour to initialize...');
    await page.waitForTimeout(2000);
    
    console.log('🔍 Looking for Intro.js tour elements...');
    const hasIntroElements = await page.evaluate(() => {
      return {
        tooltips: document.querySelectorAll('.introjs-tooltip').length,
        overlays: document.querySelectorAll('.introjs-overlay').length,
        helperLayers: document.querySelectorAll('.introjs-helperLayer').length,
        bodyClass: document.body.className,
        hasIntroClass: document.body.classList.contains('introjs-on'),
        anyIntroElements: document.querySelectorAll('[class*="introjs"]').length
      };
    });
    
    console.log('📊 Tour elements found:', hasIntroElements);
    
    if (hasIntroElements.tooltips > 0 || hasIntroElements.overlays > 0) {
      console.log('✅ SUCCESS: Intro.js tour elements detected!');
      
      // Try to find and click next button
      const nextButton = await page.$('.introjs-nextbutton');
      if (nextButton) {
        console.log('🖱️  Found next button, clicking...');
        await nextButton.click();
        await page.waitForTimeout(1000);
      }
      
    } else if (hasIntroElements.anyIntroElements > 0) {
      console.log('⚠️  Some intro elements found, but not standard tour elements');
    } else {
      console.log('❌ No Intro.js tour elements found');
    }
    
    // Take screenshot
    await page.screenshot({ path: 'final-demo-test.png', fullPage: true });
    console.log('📸 Screenshot saved as final-demo-test.png');
    
    // Keep browser open for inspection
    console.log('🔍 Keeping browser open for 15 seconds for manual inspection...');
    await page.waitForTimeout(15000);
    
  } catch (error) {
    console.log('💥 Error during testing:', error.message);
  } finally {
    await browser.close();
  }
})();