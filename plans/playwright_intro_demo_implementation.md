# **Playwright → Intro.js Interactive Demo Implementation Plan**

## **🎯 Project Overview**

Transform 8 existing Playwright AI workflows into interactive Intro.js tours accessible through a professional landing page with workflow selection cards (Option 1: Hero Section with Workflow Cards Grid).

**Goal**: Convert test automation into powerful product demonstration system showcasing AI marketing platform capabilities.

---

## **📋 Implementation Phases**

### **Phase 1: Foundation Setup** ⏱ *Days 1-2*

#### **1.1 Install Dependencies**
```ruby
# Gemfile additions
gem 'introjs-rails'
```

```bash
bundle install
rails assets:precompile  # Ensure Intro.js assets are available
```

#### **1.2 Create Core Infrastructure**

**Generate Controllers & Routes:**
```ruby
# config/routes.rb - Add demo routes
resources :demos, only: [:index] do
  collection do
    get :start_tour
    post :track_completion
  end
end

# Generate controller
rails generate controller Demos index start_tour track_completion
```

**Basic Service Classes:**
```ruby
# app/services/tour_generator_service.rb
class TourGeneratorService
  # Core service for workflow → tour conversion
end

# app/services/playwright_to_tour_converter.rb  
class PlaywrightToTourConverter
  # Parse Playwright files and convert to Intro.js format
end
```

#### **1.3 Database Schema (Optional Analytics)**
```ruby
# Migration for demo analytics tracking
rails generate migration CreateDemoAnalytics user:references workflow_key:string completed_at:timestamp session_duration:integer

# Migration for demo progress tracking  
rails generate migration CreateDemoProgress user:references workflow_key:string step_number:integer completed_steps:text
```

---

### **Phase 2: Playwright Parser & Converter** ⏱ *Days 3-5*

#### **2.1 Build PlaywrightToTourConverter Class**

**Core Parsing Logic:**
```ruby
class PlaywrightToTourConverter
  def self.convert(playwright_file_path)
    playwright_content = File.read(playwright_file_path)
    
    # Extract test steps using regex/AST parsing
    steps = extract_playwright_steps(playwright_content)
    
    # Convert to Intro.js format
    {
      steps: steps.map { |step| convert_step(step) },
      options: tour_options
    }
  end
  
  private
  
  def self.extract_playwright_steps(content)
    # Regex patterns to match Playwright actions:
    # - await page.click('selector')
    # - await page.fill('selector', 'value')  
    # - await page.selectOption('selector', 'value')
    # - await page.goto('url')
  end
  
  def self.convert_step(playwright_step)
    {
      element: convert_selector(playwright_step.selector),
      intro: generate_educational_content(playwright_step),
      position: determine_optimal_position(playwright_step),
      tooltipClass: 'ai-demo-tooltip'
    }
  end
end
```

#### **2.2 Create Tour Configuration System**

**Workflow Metadata:**
```ruby
class TourGeneratorService
  WORKFLOW_CONFIGS = {
    'social-content' => {
      title: '📱 AI Social Media Content Creation',
      description: 'Watch AI create platform-optimized posts with brand voice matching and engagement optimization',
      icon: '📱',
      duration: '3 min',
      difficulty: 'Beginner', 
      tags: ['content-creation', 'social-media', 'ai-optimization'],
      preview_image: 'previews/social-content-demo.png',
      playwright_file: 'tests/ai-workflows/test-social-content.spec.js'
    },
    'journey-ai' => {
      title: '🧠 Customer Journey AI Recommendations', 
      description: 'Experience intelligent customer touchpoint suggestions and automated sequence optimization',
      icon: '🧠',
      duration: '4 min',
      difficulty: 'Intermediate',
      tags: ['strategy', 'automation', 'customer-journey'],
      preview_image: 'previews/journey-ai-demo.png',
      playwright_file: 'tests/ai-workflows/test-journey-ai.spec.js'
    },
    'campaign-intelligence' => {
      title: '📊 Market Intelligence & Competitive Analysis',
      description: 'See AI analyze market trends, competitor strategies, and generate actionable insights',
      icon: '📊', 
      duration: '5 min',
      difficulty: 'Advanced',
      tags: ['analytics', 'competitive-intelligence', 'market-research'], 
      preview_image: 'previews/campaign-intelligence-demo.png',
      playwright_file: 'tests/ai-workflows/test-campaign-intelligence.spec.js'
    },
    'content-optimization' => {
      title: '✨ Content Optimization & A/B Testing',
      description: 'Watch AI improve content performance through intelligent optimization and variant testing',
      icon: '✨',
      duration: '3 min', 
      difficulty: 'Intermediate',
      tags: ['optimization', 'ab-testing', 'performance'],
      preview_image: 'previews/content-optimization-demo.png',
      playwright_file: 'tests/ai-workflows/test-content-optimization.spec.js'
    },
    'email-content' => {
      title: '📧 AI Email Campaign Generation',
      description: 'Experience AI creating personalized email campaigns with subject line optimization',
      icon: '📧',
      duration: '4 min',
      difficulty: 'Beginner',
      tags: ['email-marketing', 'personalization', 'automation'],
      preview_image: 'previews/email-content-demo.png', 
      playwright_file: 'tests/ai-workflows/test-email-content.spec.js'
    },
    'brand-processing' => {
      title: '🎨 Brand Voice Extraction & Processing',
      description: 'See how AI analyzes brand materials to extract voice, tone, and style guidelines',
      icon: '🎨',
      duration: '5 min',
      difficulty: 'Advanced', 
      tags: ['brand-analysis', 'voice-extraction', 'style-guide'],
      preview_image: 'previews/brand-processing-demo.png',
      playwright_file: 'tests/ai-workflows/test-brand-processing.spec.js'
    },
    'campaign-generation' => {
      title: '🚀 Strategic Campaign Planning',
      description: 'Watch AI generate comprehensive marketing strategies with timelines and resource allocation', 
      icon: '🚀',
      duration: '6 min',
      difficulty: 'Advanced',
      tags: ['strategy', 'planning', 'resource-allocation'],
      preview_image: 'previews/campaign-generation-demo.png',
      playwright_file: 'tests/ai-workflows/test-campaign-generation.spec.js'
    },
    'api-integration' => {
      title: '🔗 Programmatic API Integration', 
      description: 'Explore developer-focused workflows for integrating AI capabilities via REST APIs',
      icon: '🔗',
      duration: '4 min',
      difficulty: 'Developer',
      tags: ['api', 'integration', 'developer-tools'],
      preview_image: 'previews/api-integration-demo.png',
      playwright_file: 'tests/ai-workflows/test-api-integration.spec.js'
    }
  }.freeze
end
```

#### **2.3 Enhanced Step Generation with AI Context**

**Educational Content Generator:**
```ruby
def self.generate_educational_content(playwright_step)
  case playwright_step.action
  when :fill_form
    case playwright_step.field_name.downcase
    when /title/
      "✏️ **Campaign Title**: Enter a descriptive name. Our AI uses this to understand your campaign's purpose and adjust content tone accordingly."
    when /audience/
      "🎯 **Target Audience**: Describe your ideal customers. AI analyzes this to personalize messaging and select optimal channels."
    when /budget/
      "💰 **Budget Information**: Our AI uses budget constraints to prioritize channels and recommend resource allocation."
    end
    
  when :click_button
    if playwright_step.text.include?('Generate')
      "🤖 **AI Generation**: Click to activate our advanced AI engine. It will analyze your inputs, apply brand guidelines, and create optimized content in seconds."
    elsif playwright_step.text.include?('Submit')
      "✅ **Submit Form**: Save your inputs and proceed to the next step in the workflow."
    end
    
  when :select_option
    "🎨 **Select Option**: Choose '#{playwright_step.value}' to #{explain_option_purpose(playwright_step)}"
  end
end

def self.explain_option_purpose(step)
  option_explanations = {
    'social_post' => 'activate AI social media optimization algorithms that consider platform-specific best practices',
    'email_campaign' => 'enable AI email personalization and subject line optimization features', 
    'awareness' => 'configure AI to focus on reach, impressions, and brand recognition metrics',
    'conversion' => 'optimize AI recommendations for sales funnel efficiency and ROI'
  }
  
  option_explanations[step.value] || "optimize the AI's approach for your specific use case"
end
```

---

### **Phase 3: Landing Page UI** ⏱ *Days 6-7*

#### **3.1 Responsive Card Grid Layout**

**HTML Structure:**
```erb
<!-- app/views/demos/index.html.erb -->
<div class="demo-landing-page">
  <!-- Hero Section -->
  <header class="hero-section bg-gradient-to-r from-blue-600 to-purple-600 text-white">
    <div class="container mx-auto px-4 py-16 text-center">
      <h1 class="text-4xl md:text-6xl font-bold mb-6">
        🤖 Experience AI Marketing in Action
      </h1>
      <p class="text-xl md:text-2xl mb-8">
        Interactive demos showcasing real AI workflows that power modern marketing campaigns
      </p>
      <div class="flex justify-center space-x-4">
        <span class="bg-white/20 px-4 py-2 rounded-full text-sm">
          8 Interactive Workflows
        </span>
        <span class="bg-white/20 px-4 py-2 rounded-full text-sm">
          Real AI Demonstrations  
        </span>
        <span class="bg-white/20 px-4 py-2 rounded-full text-sm">
          3-6 Minutes Each
        </span>
      </div>
    </div>
  </header>

  <!-- Workflow Selection Grid -->
  <section class="workflow-selection py-16 bg-gray-50">
    <div class="container mx-auto px-4">
      <h2 class="text-3xl font-bold text-center mb-12 text-gray-800">
        Choose Your AI Journey
      </h2>
      
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
        <% TourGeneratorService::WORKFLOW_CONFIGS.each do |workflow_key, config| %>
          <div class="workflow-card bg-white rounded-xl shadow-lg hover:shadow-xl transition-all duration-300 transform hover:-translate-y-2" 
               data-workflow="<%= workflow_key %>">
            
            <!-- Card Header -->
            <div class="card-header p-6 text-center border-b">
              <div class="text-4xl mb-4"><%= config[:icon] %></div>
              <h3 class="text-lg font-semibold text-gray-800 mb-2">
                <%= config[:title] %>
              </h3>
              <p class="text-sm text-gray-600 leading-relaxed">
                <%= config[:description] %>
              </p>
            </div>
            
            <!-- Card Meta -->
            <div class="card-meta p-4 bg-gray-50">
              <div class="flex justify-between items-center mb-4">
                <span class="text-xs text-blue-600 bg-blue-100 px-2 py-1 rounded-full">
                  ⏱ <%= config[:duration] %>
                </span>
                <span class="text-xs text-green-600 bg-green-100 px-2 py-1 rounded-full">
                  <%= config[:difficulty] %>
                </span>
              </div>
              
              <!-- Tags -->
              <div class="flex flex-wrap gap-1 mb-4">
                <% config[:tags].each do |tag| %>
                  <span class="text-xs text-gray-500 bg-gray-200 px-2 py-1 rounded">
                    #<%= tag %>
                  </span>
                <% end %>
              </div>
              
              <!-- CTA Button -->
              <button class="start-demo-btn w-full bg-gradient-to-r from-blue-500 to-purple-600 text-white font-semibold py-3 px-4 rounded-lg hover:from-blue-600 hover:to-purple-700 transition-all duration-200"
                      onclick="startTour('<%= workflow_key %>')">
                ▶ Start Interactive Demo
              </button>
            </div>
            
            <!-- Preview Overlay (Hidden by default) -->
            <div class="preview-overlay absolute inset-0 bg-black bg-opacity-75 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity duration-300 rounded-xl"
                 style="display: none;">
              <div class="text-center text-white p-4">
                <img src="<%= asset_path(config[:preview_image]) %>" 
                     alt="<%= config[:title] %> Preview" 
                     class="w-32 h-24 object-cover rounded mb-4 mx-auto">
                <p class="text-sm">Click to start this workflow demo</p>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
  </section>

  <!-- Quick Start Options -->
  <section class="quick-start py-12 bg-white">
    <div class="container mx-auto px-4 text-center">
      <h2 class="text-2xl font-bold mb-8 text-gray-800">🚀 Quick Start Options</h2>
      
      <div class="flex flex-col md:flex-row justify-center space-y-4 md:space-y-0 md:space-x-6">
        <button onclick="startRandomTour()" 
                class="bg-yellow-500 hover:bg-yellow-600 text-white font-semibold py-3 px-6 rounded-lg transition-colors">
          🎲 Surprise Me! (Random Demo)
        </button>
        
        <button onclick="startGuidedPath()" 
                class="bg-green-500 hover:bg-green-600 text-white font-semibold py-3 px-6 rounded-lg transition-colors">
          🗺 Guided Tour (All Features)
        </button>
        
        <button onclick="showDeveloperDemo()" 
                class="bg-purple-500 hover:bg-purple-600 text-white font-semibold py-3 px-6 rounded-lg transition-colors">
          👩‍💻 Developer Walkthrough
        </button>
      </div>
    </div>
  </section>
</div>
```

#### **3.2 Interactive JavaScript Controller**

**Demo Management JavaScript:**
```javascript
// app/assets/javascripts/demo_controller.js
class DemoController {
  constructor() {
    this.workflows = <%= raw TourGeneratorService::WORKFLOW_CONFIGS.to_json %>;
    this.currentTour = null;
    this.setupCardInteractions();
    this.setupAnalytics();
  }
  
  setupCardInteractions() {
    // Hover preview effects for workflow cards
    document.querySelectorAll('.workflow-card').forEach(card => {
      card.addEventListener('mouseenter', (e) => {
        this.showPreview(e.currentTarget);
      });
      
      card.addEventListener('mouseleave', (e) => {
        this.hidePreview(e.currentTarget);
      });
    });
  }
  
  showPreview(cardElement) {
    const overlay = cardElement.querySelector('.preview-overlay');
    if (overlay) {
      overlay.style.display = 'flex';
      setTimeout(() => overlay.classList.add('opacity-100'), 50);
    }
  }
  
  hidePreview(cardElement) {
    const overlay = cardElement.querySelector('.preview-overlay');
    if (overlay) {
      overlay.classList.remove('opacity-100');
      setTimeout(() => overlay.style.display = 'none', 300);
    }
  }
  
  async startTour(workflowKey) {
    try {
      // Analytics tracking
      this.trackDemoStart(workflowKey);
      
      // Show loading state
      this.showLoadingState();
      
      // Load tour configuration
      const response = await fetch(`/demos/start_tour?workflow=${workflowKey}`);
      const tourData = await response.json();
      
      if (tourData.success) {
        this.currentTour = workflowKey;
        
        // Initialize and start Intro.js tour
        introJs()
          .setOptions({
            ...tourData.tour_config,
            showProgress: true,
            showBullets: false,
            exitOnOverlayClick: false,
            exitOnEsc: false,
            nextLabel: 'Next →',
            prevLabel: '← Back', 
            doneLabel: '🎉 Complete Tour!',
            tooltipClass: 'ai-demo-tooltip'
          })
          .onstart(() => {
            this.onTourStart(workflowKey);
          })
          .oncomplete(() => {
            this.onTourComplete(workflowKey);
          })
          .onexit(() => {
            this.onTourExit(workflowKey);
          })
          .start();
          
      } else {
        console.error('Failed to load tour:', tourData.error);
        this.showErrorMessage('Failed to start demo. Please try again.');
      }
    } catch (error) {
      console.error('Error starting tour:', error);
      this.showErrorMessage('An error occurred while starting the demo.');
    } finally {
      this.hideLoadingState();
    }
  }
  
  startRandomTour() {
    const workflowKeys = Object.keys(this.workflows);
    const randomKey = workflowKeys[Math.floor(Math.random() * workflowKeys.length)];
    this.startTour(randomKey);
  }
  
  startGuidedPath() {
    // Sequential tour through beginner → intermediate → advanced workflows
    const guidedSequence = ['social-content', 'email-content', 'journey-ai', 'content-optimization'];
    this.startSequentialTours(guidedSequence);
  }
  
  startSequentialTours(sequence, index = 0) {
    if (index >= sequence.length) {
      this.showCompletionMessage('🎉 Congratulations! You\'ve completed the guided tour of our AI platform!');
      return;
    }
    
    const workflowKey = sequence[index];
    this.startTour(workflowKey).then(() => {
      // Auto-advance to next tour after completion
      setTimeout(() => {
        this.startSequentialTours(sequence, index + 1);
      }, 2000);
    });
  }
  
  // Analytics and tracking methods
  trackDemoStart(workflowKey) {
    if (typeof gtag !== 'undefined') {
      gtag('event', 'demo_started', {
        'workflow': workflowKey,
        'source': 'landing_page'
      });
    }
    
    // Track in backend
    fetch('/demos/track_completion', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify({
        workflow_key: workflowKey,
        event: 'started',
        timestamp: new Date().toISOString()
      })
    });
  }
  
  onTourComplete(workflowKey) {
    // Track completion
    this.trackDemoCompletion(workflowKey);
    
    // Show success message
    this.showCompletionMessage(`✅ Demo completed! You experienced "${this.workflows[workflowKey].title}"`);
    
    // Show next recommendations
    this.showNextRecommendations(workflowKey);
  }
  
  showCompletionMessage(message) {
    // Create and show success notification
    const notification = document.createElement('div');
    notification.className = 'fixed top-4 right-4 bg-green-500 text-white p-4 rounded-lg shadow-lg z-50';
    notification.innerHTML = message;
    document.body.appendChild(notification);
    
    setTimeout(() => {
      notification.remove();
    }, 5000);
  }
}

// Initialize demo controller when page loads
document.addEventListener('DOMContentLoaded', () => {
  window.demoController = new DemoController();
});

// Global functions for button onclick handlers
function startTour(workflowKey) {
  window.demoController.startTour(workflowKey);
}

function startRandomTour() {
  window.demoController.startRandomTour();
}

function startGuidedPath() {
  window.demoController.startGuidedPath();
}
```

#### **3.3 Custom Styling**

**SCSS Styling:**
```scss
// app/assets/stylesheets/demo_landing.scss
.demo-landing-page {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  
  .hero-section {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    position: relative;
    overflow: hidden;
    
    &::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><pattern id="grain" width="100" height="100" patternUnits="userSpaceOnUse"><circle cx="50" cy="50" r="0.5" fill="rgba(255,255,255,0.1)"/></pattern></defs><rect width="100" height="100" fill="url(%23grain)"/></svg>');
      opacity: 0.1;
    }
  }
  
  .workflow-card {
    position: relative;
    overflow: hidden;
    border: 1px solid rgba(0,0,0,0.08);
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    
    &:hover {
      transform: translateY(-8px);
      box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
      
      .preview-overlay {
        opacity: 1;
      }
    }
    
    .card-header {
      background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
    }
    
    .start-demo-btn {
      background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%);
      position: relative;
      overflow: hidden;
      
      &::before {
        content: '';
        position: absolute;
        top: 0;
        left: -100%;
        width: 100%;
        height: 100%;
        background: linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent);
        transition: left 0.5s;
      }
      
      &:hover::before {
        left: 100%;
      }
    }
  }
  
  .preview-overlay {
    backdrop-filter: blur(10px);
    transition: all 0.3s ease;
  }
}

// Intro.js Custom Styling
.ai-demo-tooltip {
  background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
  border: none;
  border-radius: 12px;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  
  .introjs-tooltip-header {
    background: rgba(255, 255, 255, 0.1);
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 12px 12px 0 0;
  }
  
  .introjs-tooltiptext {
    color: #f1f5f9;
    font-size: 16px;
    line-height: 1.6;
  }
  
  .introjs-button {
    background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%);
    border: none;
    border-radius: 8px;
    color: white;
    font-weight: 600;
    padding: 10px 16px;
    transition: all 0.2s;
    
    &:hover {
      background: linear-gradient(135deg, #4338ca 0%, #6d28d9 100%);
      transform: translateY(-1px);
    }
  }
}

// Loading states
.loading-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  
  .loading-spinner {
    width: 50px;
    height: 50px;
    border: 4px solid rgba(255, 255, 255, 0.3);
    border-top: 4px solid #4f46e5;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

// Mobile optimizations
@media (max-width: 768px) {
  .workflow-selection .grid {
    grid-template-columns: 1fr;
    gap: 1rem;
  }
  
  .workflow-card {
    margin: 0 1rem;
  }
  
  .hero-section h1 {
    font-size: 2.5rem;
  }
  
  .hero-section p {
    font-size: 1.25rem;
  }
}
```

---

### **Phase 4: Tour Integration** ⏱ *Days 8-10*

#### **4.1 Backend Controller Implementation**

**DemosController:**
```ruby
# app/controllers/demos_controller.rb
class DemosController < ApplicationController
  include Authentication
  
  # Allow anonymous access to demos
  skip_before_action :require_authentication, only: [:index, :start_tour]
  
  def index
    @workflows = TourGeneratorService::WORKFLOW_CONFIGS
    @user_progress = current_user ? load_user_progress : {}
  end
  
  def start_tour
    workflow_key = params[:workflow]
    
    unless TourGeneratorService::WORKFLOW_CONFIGS.key?(workflow_key)
      return render json: { success: false, error: 'Invalid workflow' }, status: :bad_request
    end
    
    begin
      tour_config = TourGeneratorService.generate(workflow_key)
      
      # Track demo start
      track_demo_event(workflow_key, 'started')
      
      render json: {
        success: true,
        tour_config: tour_config,
        workflow_info: TourGeneratorService::WORKFLOW_CONFIGS[workflow_key]
      }
    rescue => e
      Rails.logger.error "Failed to generate tour for #{workflow_key}: #{e.message}"
      render json: { success: false, error: 'Failed to generate tour' }, status: :internal_server_error
    end
  end
  
  def track_completion
    workflow_key = params[:workflow_key]
    event = params[:event] # 'started', 'completed', 'exited'
    
    if current_user
      DemoAnalytic.create!(
        user: current_user,
        workflow_key: workflow_key,
        event: event,
        completed_at: (event == 'completed' ? Time.current : nil),
        session_duration: params[:session_duration]&.to_i
      )
    end
    
    # Anonymous analytics
    Rails.logger.info "Demo #{event}: #{workflow_key} by #{current_user&.id || 'anonymous'}"
    
    render json: { success: true }
  end
  
  private
  
  def load_user_progress
    return {} unless current_user
    
    DemoAnalytic.where(user: current_user)
                .where(event: 'completed')
                .group(:workflow_key)
                .maximum(:completed_at)
  end
  
  def track_demo_event(workflow_key, event)
    return unless current_user
    
    DemoAnalytic.create!(
      user: current_user,
      workflow_key: workflow_key,
      event: event,
      completed_at: (event == 'completed' ? Time.current : nil)
    )
  end
end
```

#### **4.2 Enhanced Tour Generator Service**

**Complete Service Implementation:**
```ruby
# app/services/tour_generator_service.rb
class TourGeneratorService
  class << self
    def generate(workflow_key)
      config = WORKFLOW_CONFIGS[workflow_key]
      return nil unless config
      
      # Use caching for performance
      Rails.cache.fetch("demo_tour_#{workflow_key}", expires_in: 1.hour) do
        generate_tour_config(workflow_key, config)
      end
    end
    
    private
    
    def generate_tour_config(workflow_key, config)
      # Convert Playwright file to Intro.js tour
      tour_steps = PlaywrightToTourConverter.convert(
        Rails.root.join(config[:playwright_file])
      )
      
      # Add workflow-specific enhancements
      enhanced_steps = enhance_steps_for_workflow(tour_steps, workflow_key)
      
      {
        steps: enhanced_steps,
        options: {
          showProgress: true,
          showBullets: false,
          exitOnOverlayClick: false,
          exitOnEsc: false,
          nextLabel: 'Next →',
          prevLabel: '← Back',
          doneLabel: '🎉 Complete Demo!',
          tooltipClass: 'ai-demo-tooltip',
          highlightClass: 'ai-demo-highlight'
        }
      }
    end
    
    def enhance_steps_for_workflow(base_steps, workflow_key)
      case workflow_key
      when 'social-content'
        add_social_media_context(base_steps)
      when 'journey-ai'
        add_journey_intelligence_context(base_steps)
      when 'campaign-intelligence'
        add_market_analysis_context(base_steps)
      # ... other workflow enhancements
      else
        base_steps
      end
    end
    
    def add_social_media_context(steps)
      steps.map.with_index do |step, index|
        case index
        when 0
          step.merge(
            intro: "🚀 **Welcome to AI Social Media Creation!**\n\nYou're about to see how our AI creates platform-optimized social posts that match your brand voice and maximize engagement.\n\n*This demo uses real AI capabilities - no fake data!*"
          )
        when 1
          step.merge(
            intro: "📋 **Campaign Context**: First, we need a campaign to provide context. Our AI uses campaign goals to tailor content strategy and messaging approach."
          )
        else
          step
        end
      end
    end
  end
  
  # [WORKFLOW_CONFIGS constant as defined earlier]
end
```

#### **4.3 Demo Data Management**

**Realistic Demo Data Service:**
```ruby
# app/services/demo_data_service.rb
class DemoDataService
  def self.populate_for_user(user)
    # Create demo campaign plans
    create_demo_campaigns(user)
    
    # Create demo brand identities  
    create_demo_brands(user)
    
    # Create demo generated content
    create_demo_content(user)
  end
  
  private
  
  def self.create_demo_campaigns(user)
    demo_campaigns = [
      {
        name: "Q1 Product Launch Campaign",
        campaign_type: "product_launch",
        objective: "increase_brand_awareness", 
        target_audience: "Tech-savvy professionals aged 25-45 interested in productivity tools",
        budget_constraints: "$50,000 quarterly budget with focus on digital channels",
        timeline_constraints: "3-month campaign launching February 1st"
      },
      {
        name: "Summer Engagement Drive",
        campaign_type: "engagement",
        objective: "improve_engagement",
        target_audience: "Existing customers and newsletter subscribers",
        budget_constraints: "$25,000 for content creation and paid promotion",
        timeline_constraints: "June-August seasonal campaign"
      }
    ]
    
    demo_campaigns.each do |campaign_data|
      CampaignPlan.create!(
        campaign_data.merge(
          user: user,
          status: 'completed', # Pre-generated for demo
          ai_generation_status: 'completed',
          strategic_overview: generate_demo_strategic_overview(campaign_data),
          timeline_visualization: generate_demo_timeline(campaign_data)
        )
      )
    end
  end
  
  def self.generate_demo_strategic_overview(campaign_data)
    case campaign_data[:campaign_type]
    when 'product_launch'
      "## Strategic Overview\n\n**Campaign Goal**: Drive awareness and adoption of our new productivity platform among tech professionals.\n\n**Key Strategies**:\n- Content marketing showcasing platform benefits\n- Influencer partnerships with productivity experts\n- Targeted LinkedIn and Google Ads campaigns\n- Email nurture sequences for trial conversions\n\n**Success Metrics**:\n- 10,000 trial signups\n- 500 paid conversions\n- 25% email open rates\n- 5% click-through rates on ads"
    when 'engagement'
      "## Strategic Overview\n\n**Campaign Goal**: Strengthen relationships with existing customers and increase platform usage.\n\n**Key Strategies**:\n- User-generated content campaigns\n- Feature spotlight email series\n- Community challenges and contests\n- Customer success story highlights\n\n**Success Metrics**:\n- 40% increase in daily active users\n- 60% email engagement rate\n- 100 user-generated content pieces\n- 25% increase in feature adoption"
    end
  end
end
```

---

### **Phase 5: Enhancement & Launch** ⏱ *Days 11-12*

#### **5.1 Advanced Features**

**Progress Tracking:**
```ruby
# app/models/demo_progress.rb
class DemoProgress < ApplicationRecord
  belongs_to :user
  
  validates :workflow_key, presence: true
  validates :step_number, presence: true, numericality: { greater_than: 0 }
  
  serialize :completed_steps, Array
  
  def completion_percentage
    return 0 if total_steps.zero?
    (completed_steps.length.to_f / total_steps * 100).round
  end
  
  def next_recommended_workflow
    # Logic to suggest next workflow based on completion patterns
    case workflow_key
    when 'social-content'
      'email-content' # Natural progression
    when 'email-content'
      'journey-ai'
    when 'journey-ai'
      'campaign-intelligence'
    else
      nil
    end
  end
end
```

**Achievement System:**
```ruby
# app/services/demo_achievement_service.rb
class DemoAchievementService
  ACHIEVEMENTS = {
    'first_demo' => {
      title: '🎯 First Demo',
      description: 'Completed your first AI workflow demo',
      reward: 'Unlocked advanced workflow recommendations'
    },
    'social_expert' => {
      title: '📱 Social Media Expert',
      description: 'Mastered AI social media content creation',
      reward: 'Access to advanced social media templates'
    },
    'ai_explorer' => {
      title: '🔍 AI Explorer', 
      description: 'Tried 5+ different AI workflows',
      reward: 'Exclusive beta access to new AI features'
    },
    'demo_master' => {
      title: '🏆 Demo Master',
      description: 'Completed all 8 AI workflow demos',
      reward: 'Free consultation with our AI specialists'
    }
  }.freeze
  
  def self.check_achievements(user)
    return [] unless user
    
    completed_workflows = DemoAnalytic.where(user: user, event: 'completed')
                                     .distinct(:workflow_key)
                                     .count
    
    achievements = []
    
    achievements << 'first_demo' if completed_workflows >= 1
    achievements << 'ai_explorer' if completed_workflows >= 5  
    achievements << 'demo_master' if completed_workflows >= 8
    
    # Check specific workflow achievements
    social_completed = DemoAnalytic.exists?(user: user, workflow_key: 'social-content', event: 'completed')
    achievements << 'social_expert' if social_completed
    
    achievements
  end
end
```

#### **5.2 Analytics Dashboard**

**Admin Analytics View:**
```erb
<!-- app/views/admin/demo_analytics.html.erb -->
<div class="analytics-dashboard">
  <h1>📊 Demo Analytics Dashboard</h1>
  
  <div class="stats-grid grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
    <div class="stat-card bg-white p-6 rounded-lg shadow">
      <h3 class="text-lg font-semibold text-gray-800">Total Demo Starts</h3>
      <p class="text-3xl font-bold text-blue-600"><%= @analytics[:total_starts] %></p>
      <p class="text-sm text-gray-500">Last 30 days</p>
    </div>
    
    <div class="stat-card bg-white p-6 rounded-lg shadow">
      <h3 class="text-lg font-semibold text-gray-800">Completion Rate</h3>
      <p class="text-3xl font-bold text-green-600"><%= @analytics[:completion_rate] %>%</p>
      <p class="text-sm text-gray-500">Demos completed vs started</p>
    </div>
    
    <div class="stat-card bg-white p-6 rounded-lg shadow">
      <h3 class="text-lg font-semibold text-gray-800">Avg Session Time</h3>
      <p class="text-3xl font-bold text-purple-600"><%= @analytics[:avg_session_time] %>m</p>
      <p class="text-sm text-gray-500">Time spent in demos</p>
    </div>
    
    <div class="stat-card bg-white p-6 rounded-lg shadow">
      <h3 class="text-lg font-semibold text-gray-800">Lead Conversion</h3>
      <p class="text-3xl font-bold text-orange-600"><%= @analytics[:lead_conversion] %>%</p>
      <p class="text-sm text-gray-500">Demo to signup rate</p>
    </div>
  </div>
  
  <!-- Workflow Performance Chart -->
  <div class="workflow-performance bg-white p-6 rounded-lg shadow mb-8">
    <h2 class="text-xl font-semibold mb-4">Workflow Performance</h2>
    <canvas id="workflowChart" width="400" height="200"></canvas>
  </div>
  
  <!-- User Journey Funnel -->
  <div class="user-funnel bg-white p-6 rounded-lg shadow">
    <h2 class="text-xl font-semibold mb-4">User Journey Funnel</h2>
    <div class="funnel-steps">
      <% @analytics[:funnel_data].each do |step| %>
        <div class="funnel-step flex justify-between items-center p-4 border-b">
          <span class="font-medium"><%= step[:name] %></span>
          <div class="flex items-center space-x-4">
            <span class="text-2xl font-bold"><%= step[:count] %></span>
            <span class="text-sm text-gray-500">(<%= step[:percentage] %>%)</span>
          </div>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

#### **5.3 Documentation & Training Materials**

**Admin Documentation:**
```markdown
# Demo Management Guide

## Adding New Workflows

1. Create Playwright test file in `tests/ai-workflows/`
2. Add workflow configuration to `TourGeneratorService::WORKFLOW_CONFIGS`
3. Create preview image and place in `app/assets/images/previews/`
4. Clear Rails cache to regenerate tour configurations

## Customizing Tour Content

Tour content is generated from Playwright test files with AI-specific enhancements:

- **Educational Context**: Added via `generate_educational_content()` method
- **Step Positioning**: Automatically calculated based on element positions
- **Demo Data**: Populated via `DemoDataService` for realistic workflows

## Analytics Insights

- **High Drop-off Points**: Steps where users commonly exit
- **Popular Workflows**: Most frequently started demos
- **Conversion Paths**: Which demos lead to user signups
- **Session Duration**: Time investment per workflow type

## Troubleshooting

**Common Issues:**
- Tour won't start: Check browser console for JavaScript errors
- Missing elements: Verify selectors match current application UI
- Slow loading: Check Rails cache and Playwright file parsing performance
```

---

## **🎯 Success Metrics & KPIs**

### **User Engagement Metrics**
- **Demo Completion Rate**: Target >75% completion across all workflows
- **Session Duration**: Target 8-12 minutes average engagement time  
- **Multi-Demo Usage**: Target 30% of users trying 2+ workflows
- **Return Visits**: Target 25% of users returning within 7 days

### **Business Impact Metrics**  
- **Lead Generation**: Demo-to-signup conversion rate >15%
- **Sales Qualified Leads**: Target 200+ SQLs per month from demos
- **Feature Adoption**: 40% increase in trial-to-paid conversion
- **Customer Education**: 60% reduction in support tickets for demoed features

### **Technical Performance Metrics**
- **Page Load Speed**: <3 seconds for landing page
- **Tour Initialization**: <2 seconds to start any demo
- **Mobile Usage**: 35%+ of demos on mobile devices
- **Browser Compatibility**: 99%+ success rate across modern browsers

---

## **📋 Implementation Checklist**

### **Phase 1: Foundation** ✅
- [ ] Install intro.js-rails gem
- [ ] Create demos controller and routes
- [ ] Set up basic service classes
- [ ] Create database migrations for analytics

### **Phase 2: Parser & Converter** ✅
- [ ] Build PlaywrightToTourConverter class
- [ ] Define workflow configurations
- [ ] Implement educational content generation
- [ ] Test tour conversion for 2-3 workflows

### **Phase 3: Landing Page** ✅
- [ ] Create responsive card grid layout  
- [ ] Implement JavaScript demo controller
- [ ] Add custom styling and animations
- [ ] Test mobile responsiveness

### **Phase 4: Tour Integration** ✅
- [ ] Convert all 8 Playwright workflows
- [ ] Implement demo data population
- [ ] Add tour state management
- [ ] Test end-to-end user flows

### **Phase 5: Enhancement** ✅
- [ ] Add progress tracking system
- [ ] Implement achievement badges
- [ ] Create analytics dashboard
- [ ] Prepare documentation and training

---

## **🚀 Go-Live Plan**

### **Pre-Launch (Week 1)**
1. **Quality Assurance**: Test all workflows across devices/browsers
2. **Performance Optimization**: Minimize load times and smooth animations  
3. **Analytics Setup**: Configure Google Analytics and internal tracking
4. **Content Review**: Validate educational content accuracy

### **Soft Launch (Week 2)**  
1. **Internal Testing**: Deploy to staging for team validation
2. **Beta User Testing**: Invite 10-20 customers for feedback
3. **Iterate Based on Feedback**: Refine tours and fix issues
4. **Documentation Finalization**: Complete admin and user guides

### **Full Launch (Week 3)**
1. **Production Deployment**: Launch to all website visitors
2. **Marketing Coordination**: Announce via email, social media, blog
3. **Sales Training**: Educate team on demo features and analytics
4. **Monitor & Optimize**: Track metrics and continuously improve

---

## **🔄 Maintenance & Updates**

### **Regular Tasks**
- **Weekly**: Review analytics and identify optimization opportunities  
- **Monthly**: Update demo data with fresh, realistic examples
- **Quarterly**: Add new workflows as product features expand
- **As Needed**: Update tours when UI changes affect selectors

### **Scaling Considerations**
- **Multi-language Support**: Translate tour content for global audiences
- **Advanced Personalization**: Tailor tours based on user company size/industry  
- **API Integration**: Allow customers to embed demos in their own websites
- **White-label Options**: Customize branding for reseller partners

---

This comprehensive plan transforms your Playwright test automation into a powerful product demonstration system that showcases your AI platform's capabilities through engaging, interactive experiences that drive user engagement and business growth.