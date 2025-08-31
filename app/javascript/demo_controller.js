// Demo Controller for managing interactive demo tours
import 'intro.js';

class DemoController {
  constructor(workflows) {
    console.log('DemoController constructor called');
    console.log('Workflows data:', workflows);
    
    this.workflows = workflows;
    this.currentTour = null;
    this.setupCardInteractions();
    
    console.log('DemoController constructor completed');
  }
  
  setupCardInteractions() {
    // Set up hover effects and card interactions
    const cards = document.querySelectorAll('.workflow-card');
    const previewBtns = document.querySelectorAll('.preview-btn');
    const startBtns = document.querySelectorAll('.start-demo-btn');

    cards.forEach(card => {
      card.addEventListener('mouseenter', () => this.showPreview(card));
      card.addEventListener('mouseleave', () => this.hidePreview(card));
    });

    previewBtns.forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const workflowKey = btn.getAttribute('data-workflow');
        console.log(`Preview clicked for: ${workflowKey}`);
        
        switch(workflowKey) {
          case 'guided-path':
            this.startGuidedPath();
            break;
          case 'developer-demo':
            this.showDeveloperDemo();
            break;
          case 'debug-info':
            console.log('Test button clicked');
            console.log('introJs available:', typeof introJs);
            console.log('demoController:', window.demoController);
            break;
        }
      });
    });
  }
  
  showPreview(cardElement) {
    const overlay = cardElement.querySelector('.preview-overlay');
    if (overlay) {
      overlay.classList.remove('hidden', 'pointer-events-none');
    }
  }
  
  hidePreview(cardElement) {
    const overlay = cardElement.querySelector('.preview-overlay');
    if (overlay) {
      overlay.classList.add('hidden', 'pointer-events-none');
    }
  }
  
  async startTour(workflowKey) {
    console.log(`🚀 Starting tour: ${workflowKey}`);
    
    try {
      // Show loading state
      const card = document.querySelector(`[data-workflow="${workflowKey}"]`);
      if (card) {
        card.classList.add('opacity-50', 'pointer-events-none');
      }

      // Fetch tour configuration from API
      const response = await fetch(`/demos/start_tour?workflow=${workflowKey}`);
      const tourData = await response.json();

      // Remove loading state
      if (card) {
        card.classList.remove('opacity-50', 'pointer-events-none');
      }

      if (!tourData.success) {
        console.error('Failed to fetch tour configuration:', tourData.error);
        alert('Demo system not ready. Please refresh the page and try again.');
        return;
      }

      console.log('Tour data received:', tourData);
      
      // Ask user to choose between interactive app tour or text overview
      const shouldNavigateToApp = confirm(
        `🚀 Experience the REAL ${tourData.workflow_info.title}!\n\n` +
        `Choose your demo type:\n\n` +
        `✅ OK = Interactive App Tour (navigate to real app)\n` +
        `❌ Cancel = Text Overview (stay here)`
      );
      
      if (shouldNavigateToApp) {
        // Navigate to the actual app page with demo parameters
        const startUrl = this.getStartUrlForWorkflow(workflowKey);
        const analyticsId = tourData.analytics_id;
        
        console.log(`🧭 Navigating to app: ${startUrl}?demo_tour=${workflowKey}&analytics_id=${analyticsId}`);
        
        // Navigate to the real app page with demo tour parameters
        window.location.href = `${startUrl}?demo_tour=${workflowKey}&analytics_id=${analyticsId}`;
        
      } else {
        // Show text-only overview tour here
        this.startTextOnlyTour(workflowKey, tourData);
      }
      
    } catch (error) {
      console.error('Error starting tour:', error);
      alert('Failed to start demo tour. Please try again.');
      
      // Remove loading state on error
      const card = document.querySelector(`[data-workflow="${workflowKey}"]`);
      if (card) {
        card.classList.remove('opacity-50', 'pointer-events-none');
      }
    }
  }
  
  getStartUrlForWorkflow(workflowKey) {
    // Map workflow keys to their actual app page URLs
    const workflowUrls = {
      'social-content': '/generated_contents/new',
      'journey-ai': '/journeys/new', 
      'campaign-intelligence': '/campaign_plans/new',
      'content-optimization': '/generated_contents',
      'email-content': '/generated_contents/new?content_type=email',
      'brand-processing': '/brand_identities/new',
      'campaign-generation': '/campaign_plans/new',
      'api-integration': '/help?section=api'
    };
    
    return workflowUrls[workflowKey] || '/';
  }
  
  startTextOnlyTour(workflowKey, tourData) {
    // Check if introJs is available
    if (typeof introJs === 'undefined') {
      console.error('Intro.js not available for text-only tour');
      alert('Tour system not ready. Please refresh and try again.');
      return;
    }
    
    console.log(`📝 Starting text-only tour: ${workflowKey}`);
    
    // Create steps for text-only tour
    const steps = tourData.tour_config.steps.map((step, index) => ({
      intro: step.intro,
      position: 'auto'
    }));
    
    if (steps.length === 0) {
      alert('No tour steps available for this workflow.');
      return;
    }
    
    // Start Intro.js tour
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
      console.log(`✅ Text tour started: ${workflowKey}`);
    })
    .onchange((targetElement) => {
      // Track step progress
      if (tourData.analytics_id) {
        const currentStep = intro._currentStep;
        const stepData = {
          step_number: currentStep,
          step_content: tourData.tour_config.steps[currentStep - 1]?.intro || `Step ${currentStep}`,
          timestamp: new Date().toISOString()
        };
        this.trackStepProgress(tourData.analytics_id, stepData);
      }
    })
    .oncomplete(() => {
      console.log(`🎊 Text tour completed: ${workflowKey}`);
      this.onTourComplete(workflowKey, tourData.analytics_id);
    })
    .onexit(() => {
      this.onTourExit(workflowKey, intro._currentStep || 0);
    })
    .start();
    
    this.currentTour = intro;
  }
  
  async onTourComplete(workflowKey, analyticsId) {
    console.log(`🎉 Tour completed: ${workflowKey}`);
    
    if (analyticsId) {
      await this.trackCompletion(analyticsId, 'completed');
    }
    
    // Show completion message
    this.showCompletionMessage(workflowKey);
  }
  
  async onTourExit(workflowKey, currentStep) {
    console.log(`🚪 Tour exited: ${workflowKey} at step ${currentStep}`);
    // Track exit event if needed
  }
  
  async trackStepProgress(analyticsId, stepData) {
    try {
      await fetch('/demos/track_progress', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify({
          analytics_id: analyticsId,
          step_data: stepData
        })
      });
    } catch (error) {
      console.log('Step tracking failed:', error);
    }
  }
  
  async trackCompletion(analyticsId, status) {
    try {
      await fetch('/demos/track_completion', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify({
          analytics_id: analyticsId,
          event: status,
          timestamp: new Date().toISOString()
        })
      });
    } catch (error) {
      console.log('Completion tracking failed:', error);
    }
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

export default DemoController;