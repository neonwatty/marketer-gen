const { chromium } = require('playwright');

(async () => {
  console.log('🖱️  Testing button click event handlers...');
  
  const browser = await chromium.launch({ headless: false, slowMo: 500 });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Enable console logging
  page.on('console', msg => {
    console.log(`🖥️  BROWSER: ${msg.text()}`);
  });
  
  try {
    await page.goto('http://127.0.0.1:3000/demos', { waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);
    
    console.log('🔍 Checking button event handlers setup...');
    const buttonInfo = await page.evaluate(() => {
      const buttons = document.querySelectorAll('.start-demo-btn');
      const buttonData = [];
      
      buttons.forEach((button, index) => {
        // Check if event listeners are attached
        const hasClickListener = button._listeners && button._listeners.click;
        
        buttonData.push({
          index: index,
          dataWorkflow: button.getAttribute('data-workflow'),
          hasClickListener: !!hasClickListener,
          tagName: button.tagName,
          className: button.className.substring(0, 50) + '...'
        });
      });
      
      return {
        buttonCount: buttons.length,
        buttons: buttonData,
        demoControllerExists: typeof window.demoController !== 'undefined'
      };
    });
    
    console.log('Button analysis:', buttonInfo);
    
    console.log('🧪 Testing button click programmatically...');
    const clickResult = await page.evaluate(() => {
      const button = document.querySelector('.start-demo-btn[data-workflow="social-content"]');
      if (button) {
        console.log('Found button, triggering click event...');
        // Create and dispatch a click event
        const event = new Event('click', { bubbles: true, cancelable: true });
        button.dispatchEvent(event);
        return { success: true, message: 'Click event dispatched' };
      }
      return { success: false, message: 'Button not found' };
    });
    
    console.log('Programmatic click result:', clickResult);
    
    await page.waitForTimeout(3000);
    
    console.log('🖱️  Testing actual mouse click...');
    await page.click('.start-demo-btn[data-workflow="social-content"]', { force: true });
    
    await page.waitForTimeout(5000);
    
    console.log('🔍 Final tour check...');
    const finalCheck = await page.evaluate(() => {
      return {
        tooltips: document.querySelectorAll('.introjs-tooltip').length,
        overlays: document.querySelectorAll('.introjs-overlay').length
      };
    });
    
    console.log('Final tour elements:', finalCheck);
    
    // Keep browser open
    console.log('🔍 Keeping browser open for inspection...');
    await page.waitForTimeout(15000);
    
  } catch (error) {
    console.log('💥 Error:', error.message);
  } finally {
    await browser.close();
  }
})();