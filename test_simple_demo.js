const { chromium } = require('playwright');

(async () => {
  console.log('🔍 Simple demo controller test...');
  
  const browser = await chromium.launch({ headless: false, slowMo: 2000 });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Capture all console messages and errors
  page.on('console', msg => {
    const type = msg.type();
    if (type === 'error') {
      console.log(`🚨 BROWSER ERROR: ${msg.text()}`);
    } else {
      console.log(`🖥️  BROWSER ${type.toUpperCase()}: ${msg.text()}`);
    }
  });
  
  page.on('pageerror', error => {
    console.log(`🚨 PAGE ERROR: ${error.message}`);
  });

  try {
    console.log('📡 Loading demos page...');
    await page.goto('http://127.0.0.1:3000/demos', { waitUntil: 'networkidle' });
    
    console.log('⏳ Waiting for modules to load...');
    await page.waitForTimeout(5000);
    
    console.log('🔍 Checking what loaded...');
    const status = await page.evaluate(() => {
      const info = {
        // Check if modules loaded
        applicationLoaded: typeof window !== 'undefined',
        importMapExists: document.querySelector('script[type="importmap"]') !== null,
        
        // Check specific objects
        demoController: typeof window.demoController,
        demoTourManager: typeof window.demoTourManager,
        
        // Check intro.js
        introJs: typeof window.introJs,
        
        // Check DOM elements
        demoCards: document.querySelectorAll('.start-demo-btn').length,
        
        // Check for any errors in the console
        errors: []
      };
      
      return info;
    });
    
    console.log('📊 Page status:', JSON.stringify(status, null, 2));
    
    // Check if we can manually execute the DemoController
    if (status.demoController === 'undefined') {
      console.log('⚠️  Demo controller not loaded. Checking importmap...');
      
      const importmapContent = await page.evaluate(() => {
        const importmap = document.querySelector('script[type="importmap"]');
        return importmap ? importmap.textContent : 'Not found';
      });
      
      console.log('📝 Importmap content:', importmapContent.substring(0, 500) + '...');
    }
    
    console.log('🔍 Keeping browser open for 15 seconds...');
    await page.waitForTimeout(15000);
    
  } catch (error) {
    console.log('💥 Error:', error.message);
  } finally {
    await browser.close();
  }
})();