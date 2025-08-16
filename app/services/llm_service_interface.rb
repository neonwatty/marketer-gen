# frozen_string_literal: true

# Interface defining the contract for LLM services
# This allows easy switching between mock and real LLM implementations
module LlmServiceInterface
  # Generate social media content
  # @param [Hash] params - parameters for content generation
  # @option params [String] :platform - target platform (twitter, linkedin, facebook, instagram)
  # @option params [String] :tone - content tone (professional, casual, friendly, etc.)
  # @option params [String] :topic - main topic or campaign message
  # @option params [Hash] :brand_context - brand guidelines and voice
  # @option params [Integer] :character_limit - platform character limit
  # @return [Hash] { content: String, metadata: Hash }
  def generate_social_media_content(params)
    raise NotImplementedError, "#{self.class} must implement generate_social_media_content"
  end

  # Generate email content
  # @param [Hash] params - parameters for email generation
  # @option params [String] :email_type - type (welcome, promotional, newsletter, follow-up)
  # @option params [String] :subject - email subject or topic
  # @option params [String] :tone - email tone
  # @option params [Hash] :brand_context - brand guidelines and voice
  # @option params [Array] :personalization - personalization fields
  # @return [Hash] { subject: String, content: String, metadata: Hash }
  def generate_email_content(params)
    raise NotImplementedError, "#{self.class} must implement generate_email_content"
  end

  # Generate ad copy
  # @param [Hash] params - parameters for ad generation
  # @option params [String] :ad_type - type (search, display, social, video)
  # @option params [String] :platform - target platform
  # @option params [String] :objective - campaign objective
  # @option params [Hash] :brand_context - brand guidelines and voice
  # @option params [Hash] :target_audience - audience demographics
  # @return [Hash] { headline: String, description: String, call_to_action: String, metadata: Hash }
  def generate_ad_copy(params)
    raise NotImplementedError, "#{self.class} must implement generate_ad_copy"
  end

  # Generate landing page content
  # @param [Hash] params - parameters for landing page generation
  # @option params [String] :page_type - type (product, service, event, download)
  # @option params [String] :objective - page objective
  # @option params [Hash] :brand_context - brand guidelines and voice
  # @option params [Array] :key_features - product/service features
  # @return [Hash] { headline: String, subheadline: String, body: String, cta: String, metadata: Hash }
  def generate_landing_page_content(params)
    raise NotImplementedError, "#{self.class} must implement generate_landing_page_content"
  end

  # Generate campaign summary plan
  # @param [Hash] params - parameters for campaign plan generation
  # @option params [String] :campaign_type - type of campaign
  # @option params [String] :objective - campaign objective
  # @option params [Hash] :brand_context - brand guidelines and voice
  # @option params [Hash] :target_audience - audience information
  # @option params [Hash] :budget_timeline - budget and timeline constraints
  # @return [Hash] { summary: String, strategy: Hash, timeline: Array, assets: Array, metadata: Hash }
  def generate_campaign_plan(params)
    raise NotImplementedError, "#{self.class} must implement generate_campaign_plan"
  end

  # Generate content variations for A/B testing
  # @param [Hash] params - parameters for variation generation
  # @option params [String] :original_content - base content to vary
  # @option params [String] :content_type - type of content
  # @option params [Integer] :variant_count - number of variations needed
  # @option params [Array] :variation_strategies - strategies for variation
  # @return [Array] array of content variations with metadata
  def generate_content_variations(params)
    raise NotImplementedError, "#{self.class} must implement generate_content_variations"
  end

  # Optimize existing content
  # @param [Hash] params - parameters for content optimization
  # @option params [String] :content - original content
  # @option params [String] :content_type - type of content
  # @option params [Hash] :performance_data - current performance metrics
  # @option params [Hash] :optimization_goals - target improvements
  # @return [Hash] { optimized_content: String, changes: Array, metadata: Hash }
  def optimize_content(params)
    raise NotImplementedError, "#{self.class} must implement optimize_content"
  end

  # Check content for brand compliance
  # @param [Hash] params - parameters for compliance checking
  # @option params [String] :content - content to check
  # @option params [Hash] :brand_guidelines - brand guidelines to check against
  # @return [Hash] { compliant: Boolean, issues: Array, suggestions: Array, metadata: Hash }
  def check_brand_compliance(params)
    raise NotImplementedError, "#{self.class} must implement check_brand_compliance"
  end

  # Generate analytics insights and recommendations
  # @param [Hash] params - parameters for insights generation
  # @option params [Hash] :performance_data - campaign performance data
  # @option params [String] :time_period - analysis time period
  # @option params [Array] :metrics - metrics to analyze
  # @return [Hash] { insights: Array, recommendations: Array, metadata: Hash }
  def generate_analytics_insights(params)
    raise NotImplementedError, "#{self.class} must implement generate_analytics_insights"
  end

  # Health check for the LLM service
  # @return [Hash] { status: String, response_time: Float, metadata: Hash }
  def health_check
    raise NotImplementedError, "#{self.class} must implement health_check"
  end
end