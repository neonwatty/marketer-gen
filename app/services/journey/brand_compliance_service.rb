module Journey
  class BrandComplianceService
    include ActiveSupport::Configurable
    
    config_accessor :default_compliance_level, default: :standard
    config_accessor :cache_results, default: true
    config_accessor :async_processing, default: false
    config_accessor :broadcast_violations, default: true
    
    attr_reader :journey, :step, :brand, :content, :content_type, :context, :results
    
    # Content types specific to journey steps
    JOURNEY_CONTENT_TYPES = {
      'email' => 'email_content',
      'blog_post' => 'blog_content',
      'social_post' => 'social_media_content',
      'landing_page' => 'web_content',
      'video' => 'video_script',
      'webinar' => 'presentation_content',
      'advertisement' => 'advertising_content',
      'newsletter' => 'email_content'
    }.freeze
    
    def initialize(journey:, step: nil, content:, context: {})
      @journey = journey
      @step = step
      @brand = journey.brand
      @content = content
      @context = context.with_indifferent_access
      @content_type = determine_content_type
      @results = {}
      
      validate_initialization
    end
    
    # Main method to check compliance for journey content
    def check_compliance(options = {})
      return no_brand_compliance_result unless brand.present?
      
      compliance_options = build_compliance_options(options)
      
      # Create compliance service instance
      compliance_service = Branding::ComplianceServiceV2.new(
        brand,
        content,
        @content_type,
        compliance_options
      )
      
      # Perform compliance check
      @results = compliance_service.check_compliance
      
      # Add journey-specific metadata
      enhance_results_with_journey_context
      
      # Store compliance insights
      store_compliance_insights if options[:store_insights] != false
      
      # Broadcast real-time updates
      broadcast_compliance_results if config.broadcast_violations
      
      @results
    rescue StandardError => e
      handle_compliance_error(e)
    end
    
    # Pre-generation compliance check for suggested content
    def pre_generation_check(suggested_content, options = {})
      return { allowed: true, suggestions: [] } unless brand.present?
      
      # Quick compliance check for content suggestions
      compliance_options = build_compliance_options(options.merge(
        generate_suggestions: false,
        cache_results: false
      ))
      
      compliance_service = Branding::ComplianceServiceV2.new(
        brand,
        suggested_content,
        @content_type,
        compliance_options
      )
      
      results = compliance_service.check_compliance
      
      {
        allowed: results[:compliant],
        score: results[:score],
        violations: results[:violations] || [],
        suggestions: results[:suggestions] || [],
        quick_check: true
      }
    end
    
    # Validate content against specific brand aspects
    def validate_aspects(aspects, options = {})
      return no_brand_compliance_result unless brand.present?
      
      compliance_options = build_compliance_options(options)
      
      compliance_service = Branding::ComplianceServiceV2.new(
        brand,
        content,
        @content_type,
        compliance_options
      )
      
      @results = compliance_service.check_specific_aspects(aspects)
      enhance_results_with_journey_context
      
      @results
    end
    
    # Auto-fix compliance violations
    def auto_fix_violations(options = {})
      return no_brand_compliance_result unless brand.present?
      
      compliance_options = build_compliance_options(options)
      
      compliance_service = Branding::ComplianceServiceV2.new(
        brand,
        content,
        @content_type,
        compliance_options
      )
      
      fix_results = compliance_service.validate_and_fix
      
      if fix_results[:fixed_content].present?
        @content = fix_results[:fixed_content]
      end
      
      @results = fix_results
      enhance_results_with_journey_context
      
      @results
    end
    
    # Get compliance recommendations for improving the content
    def get_recommendations(options = {})
      return { recommendations: [] } unless brand.present?
      
      # First check current compliance
      compliance_results = check_compliance(options)
      
      # Get intelligent suggestions for improvements
      compliance_service = Branding::ComplianceServiceV2.new(
        brand,
        content,
        @content_type,
        build_compliance_options(options)
      )
      
      recommendations = compliance_service.preview_fixes(compliance_results[:violations])
      
      {
        current_score: compliance_results[:score],
        recommendations: recommendations,
        priority_fixes: filter_priority_recommendations(recommendations),
        estimated_improvement: calculate_estimated_improvement(recommendations)
      }
    end
    
    # Check if content meets minimum compliance threshold
    def meets_minimum_compliance?(threshold = nil)
      results = check_compliance
      threshold ||= compliance_threshold_for_level(config.default_compliance_level)
      
      results[:score] >= threshold && results[:compliant]
    end
    
    # Get compliance score without full validation
    def quick_score
      return 1.0 unless brand.present?
      
      compliance_service = Branding::ComplianceServiceV2.new(
        brand,
        content,
        @content_type,
        { generate_suggestions: false, cache_results: true }
      )
      
      results = compliance_service.check_compliance
      results[:score] || 0.0
    end
    
    # Get brand-specific validation rules for the content type
    def applicable_brand_rules
      return [] unless brand.present?
      
      brand.brand_guidelines
           .active
           .where(category: content_category_mapping)
           .or(brand.brand_guidelines.active.where(rule_type: 'universal'))
           .order(priority: :desc)
    end
    
    # Check if specific messaging is allowed
    def messaging_allowed?(message_text)
      return true unless brand&.messaging_framework.present?
      
      framework = brand.messaging_framework
      
      # Check for banned words
      banned_words = framework.banned_words || []
      contains_banned = banned_words.any? { |word| message_text.downcase.include?(word.downcase) }
      
      # Check tone compliance
      tone_compliant = check_message_tone_compliance(message_text, framework.tone_attributes || {})
      
      !contains_banned && tone_compliant
    end
    
    private
    
    def validate_initialization
      raise ArgumentError, "Journey is required" unless journey.present?
      raise ArgumentError, "Content is required" unless content.present?
    end
    
    def determine_content_type
      if step.present?
        JOURNEY_CONTENT_TYPES[step.content_type] || step.content_type || 'general'
      else
        context[:content_type] || 'general'
      end
    end
    
    def build_compliance_options(options = {})
      base_options = {
        compliance_level: config.default_compliance_level,
        async: config.async_processing,
        generate_suggestions: true,
        real_time_updates: config.broadcast_violations,
        cache_results: config.cache_results,
        channel: step&.channel || context[:channel],
        audience: journey.target_audience,
        campaign_context: build_campaign_context
      }
      
      base_options.merge(options)
    end
    
    def build_campaign_context
      {
        journey_id: journey.id,
        journey_name: journey.name,
        campaign_type: journey.campaign_type,
        journey_stage: step&.stage,
        step_position: step&.position,
        target_audience: journey.target_audience,
        goals: journey.goals
      }
    end
    
    def enhance_results_with_journey_context
      return unless @results.is_a?(Hash)
      
      @results[:journey_context] = {
        journey_id: journey.id,
        journey_name: journey.name,
        step_id: step&.id,
        step_name: step&.name,
        content_type: @content_type,
        checked_at: Time.current
      }
      
      # Add step-specific recommendations
      if step.present?
        @results[:step_recommendations] = generate_step_specific_recommendations
      end
      
      # Add journey-level compliance trends
      @results[:compliance_trend] = calculate_journey_compliance_trend
    end
    
    def generate_step_specific_recommendations
      recommendations = []
      
      # Recommend content types that perform better for this stage
      if step.stage.present?
        stage_recommendations = get_stage_specific_recommendations(step.stage)
        recommendations.concat(stage_recommendations)
      end
      
      # Recommend channels with better brand compliance
      if step.channel.present?
        channel_recommendations = get_channel_specific_recommendations(step.channel)
        recommendations.concat(channel_recommendations)
      end
      
      recommendations.uniq
    end
    
    def get_stage_specific_recommendations(stage)
      case stage
      when 'awareness'
        [
          'Focus on brand storytelling and value proposition',
          'Use approved brand messaging for first impressions',
          'Ensure visual consistency with brand guidelines'
        ]
      when 'consideration'
        [
          'Highlight key differentiators from messaging framework',
          'Use case studies that align with brand voice',
          'Maintain consistent tone across comparison content'
        ]
      when 'conversion'
        [
          'Use approved call-to-action phrases',
          'Ensure urgency messaging aligns with brand tone',
          'Maintain brand voice in promotional content'
        ]
      when 'retention'
        [
          'Use consistent brand voice in ongoing communications',
          'Apply brand guidelines to support content',
          'Maintain visual brand consistency'
        ]
      when 'advocacy'
        [
          'Encourage brand-aligned testimonials',
          'Use consistent brand messaging in referral content',
          'Ensure social sharing aligns with brand guidelines'
        ]
      else
        []
      end
    end
    
    def get_channel_specific_recommendations(channel)
      case channel
      when 'email'
        ['Ensure email templates follow brand visual guidelines', 'Use approved email signature and branding']
      when 'social_media', 'facebook', 'instagram', 'twitter', 'linkedin'
        ['Use brand-approved hashtags', 'Maintain consistent visual style', 'Follow social media brand guidelines']
      when 'website'
        ['Ensure web content follows brand typography', 'Use approved color schemes', 'Follow brand content guidelines']
      else
        []
      end
    end
    
    def calculate_journey_compliance_trend
      return nil unless journey.journey_steps.any?
      
      # Get recent compliance scores for this journey
      recent_insights = journey.journey_insights
                              .where(insights_type: 'brand_compliance')
                              .where('calculated_at >= ?', 7.days.ago)
                              .order(calculated_at: :desc)
                              .limit(10)
      
      return nil if recent_insights.empty?
      
      scores = recent_insights.map { |insight| insight.data['score'] }.compact
      return nil if scores.empty?
      
      {
        average_score: scores.sum.to_f / scores.length,
        trend: calculate_trend(scores),
        total_checks: scores.length,
        latest_score: scores.first
      }
    end
    
    def calculate_trend(scores)
      return 'stable' if scores.length < 2
      
      recent_avg = scores.first(3).sum.to_f / [scores.first(3).length, 1].max
      older_avg = scores.last(3).sum.to_f / [scores.last(3).length, 1].max
      
      diff = recent_avg - older_avg
      
      if diff > 0.05
        'improving'
      elsif diff < -0.05
        'declining'
      else
        'stable'
      end
    end
    
    def store_compliance_insights
      return unless journey.present?
      
      insight_data = {
        score: @results[:score],
        compliant: @results[:compliant],
        violations_count: (@results[:violations] || []).length,
        suggestions_count: (@results[:suggestions] || []).length,
        content_type: @content_type,
        step_id: step&.id,
        brand_id: brand&.id,
        detailed_results: @results.except(:journey_context)
      }
      
      journey.journey_insights.create!(
        insights_type: 'brand_compliance',
        data: insight_data,
        calculated_at: Time.current,
        expires_at: 7.days.from_now,
        metadata: {
          brand_name: brand&.name,
          content_length: content.length,
          step_name: step&.name
        }
      )
    rescue => e
      Rails.logger.error "Failed to store compliance insights: #{e.message}"
    end
    
    def broadcast_compliance_results
      return unless journey.present? && brand.present?
      
      ActionCable.server.broadcast(
        "journey_compliance_#{journey.id}",
        {
          event: 'compliance_check_complete',
          journey_id: journey.id,
          step_id: step&.id,
          brand_id: brand.id,
          compliant: @results[:compliant],
          score: @results[:score],
          violations_count: (@results[:violations] || []).length,
          timestamp: Time.current
        }
      )
    rescue => e
      Rails.logger.error "Failed to broadcast compliance results: #{e.message}"
    end
    
    def no_brand_compliance_result
      {
        compliant: true,
        score: 1.0,
        summary: "No brand guidelines to check against",
        violations: [],
        suggestions: [],
        journey_context: {
          journey_id: journey.id,
          no_brand: true
        }
      }
    end
    
    def handle_compliance_error(error)
      Rails.logger.error "Journey compliance check failed: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
      
      {
        compliant: false,
        error: error.message,
        error_type: error.class.name,
        score: 0.0,
        violations: [],
        suggestions: [],
        summary: "Compliance check failed due to an error",
        journey_context: {
          journey_id: journey.id,
          error_occurred: true
        }
      }
    end
    
    def filter_priority_recommendations(recommendations)
      return [] unless recommendations.is_a?(Hash)
      
      recommendations.select do |_, recommendation| 
        recommendation[:confidence] > 0.7 && recommendation[:impact] == 'high'
      end
    end
    
    def calculate_estimated_improvement(recommendations)
      return 0.0 unless recommendations.is_a?(Hash)
      
      # Estimate improvement based on number and confidence of recommendations
      high_impact_fixes = recommendations.count { |_, rec| rec[:confidence] > 0.8 }
      medium_impact_fixes = recommendations.count { |_, rec| rec[:confidence] > 0.5 && rec[:confidence] <= 0.8 }
      
      # Rough improvement estimation
      (high_impact_fixes * 0.15) + (medium_impact_fixes * 0.08)
    end
    
    def compliance_threshold_for_level(level)
      case level.to_sym
      when :strict then 0.95
      when :standard then 0.85
      when :flexible then 0.70
      when :advisory then 0.50
      else 0.85
      end
    end
    
    def content_category_mapping
      case @content_type
      when 'email_content', 'newsletter'
        'messaging'
      when 'social_media_content', 'social_post'
        'social_media'
      when 'web_content', 'landing_page'
        'website'
      when 'advertising_content'
        'advertising'
      when 'video_script'
        'multimedia'
      else
        'general'
      end
    end
    
    def check_message_tone_compliance(message_text, tone_attributes)
      return true if tone_attributes.empty?
      
      content = message_text.downcase
      
      # Check formality level
      if tone_attributes['formality'] == 'formal'
        informal_patterns = ['hey', 'yeah', 'cool', 'awesome', 'gonna', 'wanna', '!', 'lol', 'omg']
        return false if informal_patterns.any? { |pattern| content.include?(pattern) }
      elsif tone_attributes['formality'] == 'casual'
        formal_patterns = ['utilize', 'facilitate', 'endeavor', 'subsequently', 'henceforth']
        return false if formal_patterns.any? { |pattern| content.include?(pattern) }
      end
      
      # Check style requirements
      if tone_attributes['style'] == 'professional'
        unprofessional_patterns = ['slang', 'yo', 'dude', 'bro', 'sick', 'lit']
        return false if unprofessional_patterns.any? { |pattern| content.include?(pattern) }
      end
      
      true
    end
  end
end