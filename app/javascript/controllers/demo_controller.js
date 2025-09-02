import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Demo controller connected")
  }

  startTour() {
    console.log("Starting demo tour...")
    
    // Check current page to determine which tour to show
    const currentPath = window.location.pathname
    let tourSteps = []
    
    if (currentPath === '/' || currentPath === '') {
      // Dashboard tour
      tourSteps = this.getDashboardTourSteps()
    } else if (currentPath.includes('/campaign_plans')) {
      // Campaign plans tour
      tourSteps = this.getCampaignPlansTourSteps()
    } else if (currentPath.includes('/journeys')) {
      // Journeys tour
      tourSteps = this.getJourneysTourSteps()
    } else if (currentPath.includes('/brand_identities')) {
      // Brand identity tour
      tourSteps = this.getBrandIdentityTourSteps()
    } else if (currentPath.includes('/generated_contents')) {
      // Content generation tour
      tourSteps = this.getContentGenerationTourSteps()
    } else {
      // Generic tour
      tourSteps = this.getGenericTourSteps()
    }
    
    // Initialize and start the tour (using global introJs loaded from CDN)
    if (typeof introJs === 'undefined') {
      console.error('Intro.js is not loaded')
      alert('Demo tour system is not available. Please refresh the page and try again.')
      return
    }
    
    const intro = introJs()
    intro.setOptions({
      steps: tourSteps,
      showProgress: true,
      showBullets: true,
      exitOnOverlayClick: false,
      exitOnEsc: true,
      nextLabel: "Next →",
      prevLabel: "← Back",
      doneLabel: "Finish Tour",
      skipLabel: "Skip",
      showStepNumbers: true
    })
    
    intro.onstart(() => {
      console.log("Demo tour started")
      this.trackEvent('tour_started', { page: currentPath })
    })
    
    intro.oncomplete(() => {
      console.log("Demo tour completed")
      this.trackEvent('tour_completed', { page: currentPath })
      this.showCompletionMessage()
    })
    
    intro.onexit(() => {
      console.log("Demo tour exited")
      this.trackEvent('tour_exited', { page: currentPath, step: intro._currentStep })
    })
    
    intro.start()
  }
  
  getDashboardTourSteps() {
    return [
      {
        intro: "Welcome to Marketer Gen! 🎉 Let me show you around the dashboard.",
        position: 'bottom'
      },
      {
        element: 'nav',
        intro: "This is your main navigation bar. Access all major features from here.",
        position: 'bottom'
      },
      {
        element: '[href="/journeys"]',
        intro: "Create and manage customer journey campaigns with our visual builder.",
        position: 'bottom'
      },
      {
        element: '[href="/campaign_plans"]',
        intro: "Build comprehensive marketing campaign strategies powered by AI.",
        position: 'bottom'
      },
      {
        element: '[href="/brand_identities"]',
        intro: "Set up your brand guidelines to ensure consistent messaging.",
        position: 'bottom'
      },
      {
        element: '[href="/generated_contents"]',
        intro: "Generate AI-powered content for your marketing campaigns.",
        position: 'bottom'
      },
      {
        intro: "That's it! You're ready to start creating amazing marketing campaigns. Click on any section to begin.",
        position: 'center'
      }
    ]
  }
  
  getCampaignPlansTourSteps() {
    return [
      {
        intro: "Welcome to Campaign Plans! Here you can create comprehensive marketing strategies.",
        position: 'center'
      },
      {
        element: '[href="/campaign_plans/new"]',
        intro: "Click here to create a new campaign plan.",
        position: 'bottom'
      },
      {
        element: '[name="search"]',
        intro: "Use the search bar to quickly find existing campaign plans.",
        position: 'bottom'
      },
      {
        element: 'select[name="campaign_type"]',
        intro: "Filter campaigns by type to organize your work.",
        position: 'bottom'
      },
      {
        intro: "Each campaign plan includes AI-generated strategies, timelines, and content recommendations.",
        position: 'center'
      }
    ]
  }
  
  getJourneysTourSteps() {
    return [
      {
        intro: "Customer Journeys help you map out the entire customer experience.",
        position: 'center'
      },
      {
        element: '[href="/journeys/new"]',
        intro: "Create a new customer journey from scratch.",
        position: 'bottom'
      },
      {
        element: '[href="/journeys/select_template"]',
        intro: "Or use one of our pre-built templates to get started quickly.",
        position: 'bottom'
      },
      {
        intro: "Journeys include touchpoints, engagement strategies, and automated workflows.",
        position: 'center'
      }
    ]
  }
  
  getBrandIdentityTourSteps() {
    return [
      {
        intro: "Brand Identity ensures all your content maintains consistent voice and messaging.",
        position: 'center'
      },
      {
        element: '[href="/brand_identities/new"]',
        intro: "Create your brand identity with guidelines, tone, and messaging frameworks.",
        position: 'bottom'
      },
      {
        intro: "Your brand identity will be automatically applied to all generated content.",
        position: 'center'
      }
    ]
  }
  
  getContentGenerationTourSteps() {
    return [
      {
        intro: "Generate AI-powered content for all your marketing needs.",
        position: 'center'
      },
      {
        intro: "Create emails, social posts, blog articles, and more - all aligned with your brand.",
        position: 'center'
      },
      {
        intro: "Content is automatically optimized based on your campaign goals and target audience.",
        position: 'center'
      }
    ]
  }
  
  getGenericTourSteps() {
    return [
      {
        intro: "Welcome to Marketer Gen! This platform helps you create AI-powered marketing campaigns.",
        position: 'center'
      },
      {
        element: 'nav',
        intro: "Use the navigation bar to access different features.",
        position: 'bottom'
      },
      {
        intro: "Start by creating a brand identity, then build campaign plans and generate content.",
        position: 'center'
      }
    ]
  }
  
  trackEvent(eventName, data) {
    // Send tracking data to the server
    fetch('/demos/track_completion', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
      },
      body: JSON.stringify({
        event: eventName,
        ...data
      })
    }).catch(error => {
      console.log('Tracking failed:', error)
    })
  }
  
  showCompletionMessage() {
    const message = document.createElement('div')
    message.className = 'fixed top-20 right-4 bg-green-500 text-white p-4 rounded-lg shadow-lg z-[10000] max-w-sm animate-slide-in'
    message.innerHTML = `
      <div class="flex items-center space-x-3">
        <span class="text-2xl">🎉</span>
        <div>
          <div class="font-semibold">Tour Complete!</div>
          <div class="text-sm">You now know the basics of Marketer Gen.</div>
        </div>
      </div>
    `
    
    document.body.appendChild(message)
    
    // Add slide-in animation
    const style = document.createElement('style')
    style.textContent = `
      @keyframes slide-in {
        from {
          transform: translateX(100%);
          opacity: 0;
        }
        to {
          transform: translateX(0);
          opacity: 1;
        }
      }
      .animate-slide-in {
        animation: slide-in 0.3s ease-out;
      }
    `
    document.head.appendChild(style)
    
    setTimeout(() => {
      message.style.opacity = '0'
      message.style.transition = 'opacity 0.3s ease-out'
      setTimeout(() => {
        message.remove()
        style.remove()
      }, 300)
    }, 5000)
  }
}