const { chromium } = require('playwright');

(async () => {
  console.log('🔧 Testing demo tour fixes...');
  
  const browser = await chromium.launch({ headless: false, slowMo: 500 });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Enable console logging
  page.on('console', msg => {
    console.log(`🖥️  BROWSER: ${msg.text()}`);
  });
  
  // Enable network request logging for CSS
  page.on('response', response => {
    if (response.url().includes('intro.css') || response.url().includes('intro.min.css')) {
      console.log(`🌐 CSS: ${response.status()} ${response.url()}`);
    }
  });
  
  try {
    console.log('📡 Navigating to demos page...');
    await page.goto('http://127.0.0.1:3000/demos', { waitUntil: 'networkidle' });
    
    console.log('⏳ Waiting for page to fully load...');
    await page.waitForTimeout(2000);
    
    console.log('🖱️  Trying to click demo button with force click...');
    await page.click('.start-demo-btn[data-workflow="social-content"]', { force: true });
    
    console.log('⏳ Waiting for tour to start...');
    await page.waitForTimeout(3000);
    
    console.log('🔍 Checking for Intro.js elements...');
    const introElements = await page.evaluate(() => {
      return {
        tooltips: document.querySelectorAll('.introjs-tooltip').length,
        overlays: document.querySelectorAll('.introjs-overlay').length,
        helperLayers: document.querySelectorAll('.introjs-helperLayer').length,
        hints: document.querySelectorAll('.introjs-hint').length,
        bodyHasClass: document.body.classList.contains('introjs-on')
      };
    });
    
    console.log('📊 Intro.js elements found:', introElements);
    
    // Try to find any elements with intro in their class or id
    const anyIntroElements = await page.evaluate(() => {
      const allElements = document.querySelectorAll('*');
      let introRelated = [];
      for (let el of allElements) {
        if (el.className.includes('intro') || el.id.includes('intro')) {
          introRelated.push({
            tag: el.tagName,
            class: el.className,
            id: el.id,
            visible: el.offsetWidth > 0 && el.offsetHeight > 0
          });
        }
      }
      return introRelated;
    });
    
    console.log('🔍 Any intro-related elements:', anyIntroElements);
    
    // Take a screenshot
    await page.screenshot({ path: 'demo-fix-test.png', fullPage: true });
    console.log('📸 Screenshot saved as demo-fix-test.png');
    
    // Keep browser open to inspect
    console.log('🔍 Keeping browser open for manual inspection...');
    await page.waitForTimeout(15000);
    
  } catch (error) {
    console.log('💥 Error during testing:', error.message);
  } finally {
    await browser.close();
  }
})();