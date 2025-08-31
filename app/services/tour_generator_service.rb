# frozen_string_literal: true

# Service for converting Playwright AI workflows into Intro.js guided tours
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

    def add_journey_intelligence_context(steps)
      steps.map.with_index do |step, index|
        case index
        when 0
          step.merge(
            intro: "🧠 **Customer Journey AI Intelligence**\n\nDiscover how our AI analyzes customer behavior patterns and recommends optimal touchpoint sequences for maximum conversion."
          )
        else
          step
        end
      end
    end

    def add_market_analysis_context(steps)
      steps.map.with_index do |step, index|
        case index
        when 0
          step.merge(
            intro: "📊 **Market Intelligence & Competitive Analysis**\n\nWatch our AI analyze market trends, competitor strategies, and generate actionable insights for your campaigns."
          )
        else
          step
        end
      end
    end
  end

  # Workflow configuration with metadata for each of the 8 AI workflows
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