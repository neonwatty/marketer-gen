const { chromium } = require('playwright');

(async () => {
  console.log('🚀 Starting Playwright debug session for demo tours...');
  
  const browser = await chromium.launch({ headless: false, slowMo: 1000 });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Enable console logging
  page.on('console', msg => {
    console.log(`🖥️  BROWSER: ${msg.text()}`);
  });
  
  // Enable error logging
  page.on('pageerror', error => {
    console.log(`❌ PAGE ERROR: ${error.message}`);
  });
  
  // Enable network request logging
  page.on('response', response => {
    if (response.url().includes('intro.js') || response.status() >= 400) {
      console.log(`🌐 NETWORK: ${response.status()} ${response.url()}`);
    }
  });
  
  try {
    console.log('📡 Navigating to demos page...');
    await page.goto('http://127.0.0.1:3000/demos', { waitUntil: 'networkidle' });
    
    console.log('⏳ Waiting for page to fully load...');
    await page.waitForTimeout(2000);
    
    console.log('🔍 Checking if demo controller is initialized...');
    const demoControllerExists = await page.evaluate(() => {
      return typeof window.demoController !== 'undefined';
    });
    console.log(`Demo controller exists: ${demoControllerExists}`);
    
    console.log('🔍 Checking if Intro.js is loaded...');
    const introJsExists = await page.evaluate(() => {
      return typeof introJs !== 'undefined';
    });
    console.log(`Intro.js loaded: ${introJsExists}`);
    
    console.log('🔍 Looking for demo buttons...');
    const buttons = await page.$$('.start-demo-btn');
    console.log(`Found ${buttons.length} demo buttons`);
    
    if (buttons.length > 0) {
      console.log('🖱️  Clicking first demo button (social-content)...');
      await buttons[0].click();
      
      console.log('⏳ Waiting for tour to start...');
      await page.waitForTimeout(3000);
      
      console.log('🔍 Checking for Intro.js elements on page...');
      const introElements = await page.evaluate(() => {
        const elements = {
          tooltips: document.querySelectorAll('.introjs-tooltip').length,
          overlays: document.querySelectorAll('.introjs-overlay').length,
          helperLayer: document.querySelectorAll('.introjs-helperLayer').length,
          arrows: document.querySelectorAll('.introjs-arrow').length
        };
        return elements;
      });
      
      console.log('📊 Intro.js elements found:', introElements);
      
      // Check if any Intro.js CSS is applied
      const hasIntroStyles = await page.evaluate(() => {
        const style = window.getComputedStyle(document.body);
        return {
          bodyOverflow: style.overflow,
          hasIntroClass: document.body.classList.contains('introjs-on')
        };
      });
      
      console.log('🎨 Page styling info:', hasIntroStyles);
      
      // Take a screenshot for debugging
      console.log('📸 Taking screenshot for debugging...');
      await page.screenshot({ path: 'demo-debug-screenshot.png', fullPage: true });
      console.log('Screenshot saved as demo-debug-screenshot.png');
      
    } else {
      console.log('❌ No demo buttons found on page!');
    }
    
  } catch (error) {
    console.log('💥 Error during testing:', error.message);
  } finally {
    console.log('🏁 Debug session complete. Keeping browser open for 10 seconds...');
    await page.waitForTimeout(10000);
    await browser.close();
  }
})();