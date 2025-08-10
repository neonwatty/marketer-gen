# Main AI Service orchestrator
# Coordinates between different AI providers, Context7 documentation, and application needs
class AIService
  include ActiveModel::Model
  include ActiveModel::Attributes

  class ServiceError < StandardError; end
  class ConfigurationError < ServiceError; end

  # Service configuration
  attribute :provider, :string
  attribute :model, :string
  attribute :enable_context7, :boolean, default: true
  attribute :enable_caching, :boolean, default: true
  attribute :cache_duration, :integer, default: 1800 # 30 minutes

  attr_reader :ai_provider, :context7_service, :errors

  def initialize(attributes = {})
    super(attributes)
    @errors = []
    @cache = {}
    
    setup_services
  end

  # High-level AI operations for the marketing platform

  # Generate comprehensive campaign content
  def generate_campaign_content(campaign, options = {})
    validate_campaign_data(campaign)
    
    begin
      # Gather context from brand assets
      brand_context = build_brand_context(campaign)
      
      # Get relevant documentation if needed
      tech_docs = fetch_relevant_documentation(options[:technologies] || [])
      
      # Generate the campaign plan
      campaign_plan = @ai_provider.generate_campaign_plan({
        name: campaign.name,
        purpose: campaign.purpose,
        budget: campaign.budget,
        start_date: campaign.start_date,
        end_date: campaign.end_date,
        brand_context: brand_context,
        technical_context: tech_docs
      }, options)
      
      # Generate content for each channel
      channel_content = generate_multi_channel_content(campaign, brand_context, campaign_plan, options)
      
      {
        campaign_plan: campaign_plan,
        channel_content: channel_content,
        brand_context: brand_context,
        generated_at: Time.current,
        provider: @ai_provider.provider_name,
        model: @ai_provider.model_name
      }
    rescue => e
      error_message = "Campaign content generation failed: #{e.message}"
      @errors << error_message
      Rails.logger.error error_message
      Rails.logger.error e.backtrace.join("\n") if e.respond_to?(:backtrace)
      nil
    end
  end

  # Analyze brand assets for insights
  def analyze_brand_assets(assets, options = {})
    return { error: "No assets provided" } if assets.empty?
    
    cache_key = "brand_analysis_#{assets.map(&:id).sort.join('_')}_#{options.hash}"
    
    if enable_caching && cached_result = get_from_cache(cache_key)
      return cached_result
    end
    
    begin
      # Prepare assets for analysis
      prepared_assets = prepare_assets_for_analysis(assets)
      
      # Get technical documentation for any mentioned frameworks
      mentioned_tech = extract_mentioned_technologies(prepared_assets)
      tech_context = fetch_relevant_documentation(mentioned_tech) if mentioned_tech.any?
      
      # Analyze with AI
      analysis = @ai_provider.analyze_brand_assets(prepared_assets, {
        focus_areas: options[:focus_areas] || ["brand_voice", "messaging", "compliance"],
        technical_context: tech_context,
        **options
      })
      
      # Enhance analysis with additional insights
      enhanced_analysis = enhance_brand_analysis(analysis, assets, tech_context)
      
      cache_result(cache_key, enhanced_analysis) if enable_caching
      enhanced_analysis
    rescue => e
      error_message = "Brand asset analysis failed: #{e.message}"
      @errors << error_message
      Rails.logger.error error_message
      nil
    end
  end

  # Generate content for specific channel
  def generate_channel_content(channel, campaign, options = {})
    brand_context = build_brand_context(campaign)
    
    # Get channel-specific documentation if needed
    channel_tech = get_channel_technologies(channel)
    tech_docs = fetch_relevant_documentation(channel_tech)
    
    enhanced_brand_context = [brand_context, tech_docs].compact.join("\n\n")
    
    @ai_provider.generate_content_for_channel(
      channel, 
      enhanced_brand_context, 
      {
        campaign_name: campaign.name,
        campaign_purpose: campaign.purpose,
        **options
      }
    )
  end

  # Get AI-powered campaign optimization suggestions
  def suggest_campaign_optimizations(campaign, performance_data = {})
    context = build_optimization_context(campaign, performance_data)
    
    prompt = build_optimization_prompt(context)
    
    response = @ai_provider.generate_content(prompt, {
      system_message: build_optimization_system_message,
      temperature: 0.4,
      max_tokens: 2000
    })
    
    parse_optimization_suggestions(response)
  end

  # Service health and diagnostics
  def healthy?
    service_health = {
      ai_provider: @ai_provider&.healthy? || false,
      context7: @context7_service&.available? || false,
      overall: false
    }
    
    service_health[:overall] = service_health[:ai_provider] && 
                              (!enable_context7 || service_health[:context7])
    
    service_health
  end

  def service_info
    {
      provider: @ai_provider&.provider_name,
      model: @ai_provider&.model_name,
      context7_enabled: enable_context7,
      caching_enabled: enable_caching,
      max_context_tokens: @ai_provider&.max_context_tokens,
      cache_stats: cache_stats
    }
  end

  private

  def setup_services
    begin
      # Initialize AI provider
      @ai_provider = AIServiceFactory.create(
        provider: provider, 
        model: model,
        timeout_seconds: 60,
        max_retries: 2
      )
      
      # Initialize Context7 service if enabled
      if enable_context7
        @context7_service = Context7IntegrationService.new(
          enabled: true,
          cache_duration: cache_duration
        )
      end
    rescue => e
      raise ConfigurationError, "Failed to initialize AI services: #{e.message}"
    end
  end

  def validate_campaign_data(campaign)
    raise ServiceError, "Campaign is required" unless campaign
    raise ServiceError, "Campaign must have a name" unless campaign.name.present?
    raise ServiceError, "Campaign must have a purpose" unless campaign.purpose.present?
  end

  def build_brand_context(campaign)
    context_parts = []
    
    # Campaign information
    context_parts << "Campaign: #{campaign.name}"
    context_parts << "Purpose: #{campaign.purpose}"
    context_parts << "Budget: $#{campaign.budget}" if campaign.budget
    
    # Brand identity information
    if campaign.brand_identity
      identity = campaign.brand_identity
      context_parts << "Brand: #{identity.name}" if identity.name
      context_parts << "Brand Voice: #{identity.voice_tone}" if identity.voice_tone
      context_parts << "Brand Values: #{identity.core_values}" if identity.core_values
      context_parts << "Target Audience: #{identity.target_audience}" if identity.target_audience
    end
    
    # Brand assets context
    if campaign.brand_assets.any?
      asset_context = campaign.brand_assets.map do |asset|
        text_content = asset.extracted_text.present? ? asset.extracted_text[0..500] : ""
        "Asset: #{asset.filename} - #{text_content}"
      end.join("\n")
      
      context_parts << "Brand Assets Context:\n#{asset_context}"
    end
    
    context_parts.join("\n\n")
  end

  def fetch_relevant_documentation(technologies)
    return "" unless enable_context7 && @context7_service&.available? && technologies.any?
    
    docs = @context7_service.batch_lookup(technologies)
    
    relevant_docs = docs.compact.map do |tech, doc_data|
      next unless doc_data
      "#{tech.upcase} Documentation:\n#{doc_data[:content][0..1000]}"
    end.compact
    
    relevant_docs.join("\n\n---\n\n")
  end

  def generate_multi_channel_content(campaign, brand_context, campaign_plan, options)
    channels = %w[email social_media web]
    content = {}
    
    channels.each do |channel|
      begin
        content[channel] = generate_channel_content(channel, campaign, {
          campaign_plan: campaign_plan,
          brand_context: brand_context,
          **options
        })
      rescue => e
        Rails.logger.error "Failed to generate content for #{channel}: #{e.message}"
        content[channel] = { error: e.message }
      end
    end
    
    content
  end

  def prepare_assets_for_analysis(assets)
    assets.map do |asset|
      {
        filename: asset.filename,
        content_type: asset.file.blob.content_type,
        extracted_text: asset.extracted_text&.truncate(2000),
        file_size: asset.file.blob.byte_size,
        category: asset.category
      }
    end
  end

  def extract_mentioned_technologies(prepared_assets)
    text_content = prepared_assets.map { |a| a[:extracted_text] }.compact.join(" ")
    
    technologies = []
    tech_patterns = {
      "react" => /\breact\b/i,
      "rails" => /\b(?:rails|ruby on rails)\b/i,
      "next.js" => /\bnext\.?js\b/i,
      "tailwindcss" => /\btailwind\s?css\b/i,
      "stimulus" => /\bstimulus\b/i
    }
    
    tech_patterns.each do |tech, pattern|
      technologies << tech if text_content.match?(pattern)
    end
    
    technologies
  end

  def enhance_brand_analysis(analysis, assets, tech_context)
    return analysis unless analysis.is_a?(Hash)
    
    analysis.merge(
      asset_count: assets.size,
      technical_mentions: extract_mentioned_technologies(prepare_assets_for_analysis(assets)),
      compliance_score: calculate_compliance_score(analysis),
      actionable_insights: generate_actionable_insights(analysis),
      enhancement_suggestions: suggest_brand_enhancements(analysis, tech_context)
    )
  end

  def get_channel_technologies(channel)
    case channel.to_s
    when "email"
      ["html", "css"]
    when "social_media"  
      ["instagram-api", "twitter-api", "facebook-api"]
    when "web"
      ["html", "css", "tailwindcss", "stimulus"]
    else
      []
    end
  end

  def calculate_compliance_score(analysis)
    # Simple compliance scoring based on analysis content
    compliance_indicators = [
      analysis.dig("compliance_considerations")&.size || 0,
      analysis.dig("brand_guidelines")&.keys&.size || 0,
      analysis.dig("content_restrictions")&.size || 0
    ]
    
    total_score = compliance_indicators.sum
    [100, total_score * 10].min # Cap at 100
  end

  def generate_actionable_insights(analysis)
    insights = []
    
    if analysis["brand_voice"].present?
      insights << "Maintain consistent brand voice: #{analysis['brand_voice'][0..100]}..."
    end
    
    if analysis["competitive_advantages"]&.any?
      insights << "Leverage key advantages: #{analysis['competitive_advantages'].first(2).join(', ')}"
    end
    
    if analysis["content_opportunities"]&.any?
      insights << "Explore content opportunities: #{analysis['content_opportunities'].first}"
    end
    
    insights
  end

  def suggest_brand_enhancements(analysis, tech_context)
    suggestions = []
    
    if tech_context.present?
      suggestions << "Consider technical implementation guidelines from documentation"
    end
    
    if analysis["brand_guidelines"].blank?
      suggestions << "Develop comprehensive brand guidelines"
    end
    
    suggestions << "Create content templates based on identified themes"
    suggestions << "Establish measurement criteria for brand consistency"
    
    suggestions
  end

  def build_optimization_context(campaign, performance_data)
    {
      campaign: {
        name: campaign.name,
        status: campaign.status,
        duration_days: campaign.duration_days,
        progress: campaign.progress_percentage
      },
      performance: performance_data,
      current_date: Date.current.strftime("%Y-%m-%d")
    }
  end

  def build_optimization_prompt(context)
    <<~PROMPT
      Analyze the following campaign performance and provide optimization suggestions:

      Campaign Details:
      #{context[:campaign].map { |k, v| "#{k.to_s.humanize}: #{v}" }.join("\n")}

      Performance Data:
      #{context[:performance].empty? ? "No performance data available yet" : context[:performance].inspect}

      Current Date: #{context[:current_date]}

      Please provide specific, actionable optimization recommendations that can improve campaign performance.
    PROMPT
  end

  def build_optimization_system_message
    "You are a marketing optimization specialist. Provide specific, data-driven recommendations for improving campaign performance. Focus on actionable insights that can be implemented immediately."
  end

  def parse_optimization_suggestions(response)
    content = extract_content_from_response(response)
    json_data = extract_json_from_response(content)
    
    if json_data
      json_data
    else
      {
        suggestions: content,
        format: "text",
        generated_at: Time.current.iso8601
      }
    end
  end

  def extract_content_from_response(response)
    if response.is_a?(Hash) && response["content"]
      response["content"].map { |block| block["text"] }.compact.join("\n")
    else
      response.to_s
    end
  end

  def extract_json_from_response(text)
    @ai_provider.extract_json_from_response(text)
  end

  # Cache management
  def get_from_cache(cache_key)
    cached_entry = @cache[cache_key]
    return nil unless cached_entry
    
    if cached_entry[:cached_at] + cache_duration > Time.current.to_i
      cached_entry[:data]
    else
      @cache.delete(cache_key)
      nil
    end
  end

  def cache_result(cache_key, data)
    @cache[cache_key] = {
      data: data,
      cached_at: Time.current.to_i
    }
  end

  def cache_stats
    {
      entries: @cache.size,
      memory_usage_mb: (@cache.to_s.bytesize / 1024.0 / 1024.0).round(2)
    }
  end
end