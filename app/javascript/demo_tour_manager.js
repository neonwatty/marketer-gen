// Demo Tour Manager - Handles interactive tours throughout the app
class DemoTourManager {
  constructor() {
    this.currentTour = null;
    this.currentAnalyticsId = null;
    this.init();
  }
  
  init() {
    // Check if we arrived here from a demo tour
    const urlParams = new URLSearchParams(window.location.search);
    const demoTour = urlParams.get('demo_tour');
    const analyticsId = urlParams.get('analytics_id');
    
    if (demoTour && analyticsId) {
      console.log(`🎯 Demo tour detected: ${demoTour} (analytics: ${analyticsId})`);
      this.currentTour = demoTour;
      this.currentAnalyticsId = analyticsId;
      
      // Start tour after page loads
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => this.startInteractiveTour(demoTour));
      } else {
        setTimeout(() => this.startInteractiveTour(demoTour), 1000);
      }
    }
  }
  
  async startInteractiveTour(workflowKey) {
    try {
      console.log(`🚀 Starting interactive tour: ${workflowKey}`);
      
      // Fetch tour configuration from our API
      const response = await fetch(`/demos/start_tour?workflow=${workflowKey}`);
      const tourData = await response.json();
      
      if (tourData.success) {
        const steps = this.createInteractiveSteps(workflowKey, tourData.tour_config.steps);
        
        if (steps.length > 0) {
          this.runIntroJsTour(steps, workflowKey);
        } else {
          this.showFallbackTour(tourData.tour_config.steps);
        }
      }
    } catch (error) {
      console.error('Failed to start interactive tour:', error);
    }
  }
  
  createInteractiveSteps(workflowKey, originalSteps) {
    const interactiveSteps = [];
    
    // Define real UI elements for each workflow
    const workflowElements = this.getWorkflowElements(workflowKey);
    
    workflowElements.forEach((element, index) => {
      if (document.querySelector(element.selector)) {
        interactiveSteps.push({
          element: element.selector,
          intro: element.intro || originalSteps[index]?.intro || `Step ${index + 1}: ${element.action}`,
          position: element.position || 'auto',
          tooltipClass: 'demo-tour-tooltip'
        });
      }
    });
    
    return interactiveSteps;
  }
  
  getWorkflowElements(workflowKey) {
    const workflows = {
      'social-content': [
        {
          selector: 'h1, .page-title, [data-testid="page-title"]',
          intro: '🎯 **Create AI Social Content**: This is where you generate platform-optimized social media posts with AI.',
          action: 'Welcome'
        },
        {
          selector: 'form, .content-form, [data-testid="content-form"]',
          intro: '📝 **Content Form**: Fill in your campaign details and brand voice preferences here.',
          action: 'Form Input'
        },
        {
          selector: 'button[type="submit"], .generate-btn, .create-btn',
          intro: '🚀 **Generate Content**: Click here to let AI create optimized social media content.',
          action: 'Generate'
        },
        {
          selector: '.generated-content, .results, .content-preview',
          intro: '✨ **AI Results**: Your AI-generated social media content will appear here with platform-specific optimizations.',
          action: 'Results'
        }
      ],
      
      'journey-ai': [
        {
          selector: 'h1, .page-title',
          intro: '🧠 **AI Journey Builder**: Create intelligent customer journey maps with AI recommendations.',
          action: 'Welcome'
        },
        {
          selector: '.journey-builder, .canvas, .workflow-canvas',
          intro: '🗺️ **Journey Canvas**: This is where you\'ll build your customer journey with drag-and-drop steps.',
          action: 'Canvas'
        },
        {
          selector: '.add-step-btn, .new-step, [data-testid="add-step"]',
          intro: '➕ **Add Steps**: Click here to add new touchpoints and interactions to your journey.',
          action: 'Add Step'
        },
        {
          selector: '.ai-suggestions, .recommendations',
          intro: '🤖 **AI Suggestions**: Get intelligent recommendations for optimizing your customer journey.',
          action: 'AI Help'
        }
      ],
      
      'campaign-intelligence': [
        {
          selector: 'h1, .page-title',
          intro: '📊 **Campaign Intelligence**: Generate comprehensive marketing strategies with AI analysis.',
          action: 'Welcome'
        },
        {
          selector: '.campaign-form, form',
          intro: '📋 **Campaign Details**: Enter your business goals, target audience, and market information.',
          action: 'Form'
        },
        {
          selector: '.generate-plan-btn, button[type="submit"]',
          intro: '⚡ **Generate Plan**: Let AI analyze your market and create a strategic campaign plan.',
          action: 'Generate'
        },
        {
          selector: '.campaign-results, .analytics, .insights',
          intro: '💡 **Strategic Insights**: View AI-generated market analysis, competitive intelligence, and campaign recommendations.',
          action: 'Results'
        }
      ],
      
      'brand-processing': [
        {
          selector: 'h1, .page-title',
          intro: '🎨 **Brand Voice Extraction**: Upload your brand materials and let AI learn your unique voice and style.',
          action: 'Welcome'
        },
        {
          selector: '.file-upload, input[type="file"], .upload-zone',
          intro: '📁 **Upload Materials**: Upload your existing marketing materials, brand guidelines, or website content.',
          action: 'Upload'
        },
        {
          selector: '.analyze-btn, .process-btn',
          intro: '🔍 **AI Analysis**: AI will analyze your materials to extract tone, voice, and brand characteristics.',
          action: 'Analyze'
        },
        {
          selector: '.brand-profile, .voice-analysis, .results',
          intro: '📈 **Brand Profile**: See your extracted brand voice profile that AI will use for future content generation.',
          action: 'Results'
        }
      ]
    };
    
    return workflows[workflowKey] || [];
  }
  
  runIntroJsTour(steps, workflowKey) {
    if (typeof introJs === 'undefined') {
      console.error('Intro.js not loaded');
      return;
    }
    
    const intro = introJs();
    intro.setOptions({
      steps: steps,
      showProgress: true,
      showBullets: false,
      exitOnOverlayClick: false,
      exitOnEsc: true,
      nextLabel: "Next →",
      prevLabel: "← Back",
      doneLabel: "🎉 Complete Tour!",
      tooltipClass: "demo-tour-tooltip",
      highlightClass: "demo-tour-highlight"
    })
    .onstart(() => {
      console.log(`✅ Interactive tour started: ${workflowKey}`);
    })
    .oncomplete(() => {
      console.log(`🎊 Tour completed: ${workflowKey}`);
      this.trackCompletion('completed');
      this.showCompletionMessage(workflowKey);
    })
    .onexit(() => {
      this.trackCompletion('exited');
    })
    .start();
  }
  
  showFallbackTour(originalSteps) {
    // Fallback to text-only tour if no elements found
    const textSteps = originalSteps.map(step => ({
      intro: step.intro,
      position: 'auto'
    }));
    
    this.runIntroJsTour(textSteps, this.currentTour);
  }
  
  trackCompletion(event) {
    if (!this.currentAnalyticsId) return;
    
    fetch('/demos/track_completion', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify({
        analytics_id: this.currentAnalyticsId,
        event: event,
        timestamp: new Date().toISOString()
      })
    }).catch(error => console.log('Analytics tracking failed:', error));
  }
  
  showCompletionMessage(workflowKey) {
    const message = document.createElement('div');
    message.className = 'fixed top-4 right-4 bg-green-500 text-white p-4 rounded-lg shadow-lg z-50 max-w-sm';
    message.innerHTML = `
      <div class="flex items-center space-x-2">
        <span class="text-2xl">🎉</span>
        <div>
          <div class="font-semibold">Tour Complete!</div>
          <div class="text-sm">You've experienced the ${workflowKey} workflow</div>
        </div>
      </div>
    `;
    
    document.body.appendChild(message);
    
    setTimeout(() => {
      message.remove();
    }, 5000);
  }
}

// Auto-initialize when script loads
if (typeof window !== 'undefined') {
  window.demoTourManager = new DemoTourManager();
}

export default DemoTourManager;