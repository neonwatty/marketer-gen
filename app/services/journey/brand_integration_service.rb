module Journey
  class BrandIntegrationService
    include ActiveSupport::Configurable
    
    config_accessor :enable_real_time_validation, default: true
    config_accessor :enable_auto_suggestions, default: true
    config_accessor :compliance_check_threshold, default: 0.7
    config_accessor :auto_fix_enabled, default: false
    
    attr_reader :journey, :user, :integration_context
    
    def initialize(journey:, user: nil, context: {})
      @journey = journey
      @user = user || journey.user
      @integration_context = context.with_indifferent_access
      @results = {}
    end
    
    # Main orchestration method for brand-aware journey operations
    def orchestrate_brand_journey_flow(operation:, **options)
      case operation.to_sym
      when :generate_suggestions
        orchestrate_brand_aware_suggestions(options)
      when :validate_content
        orchestrate_content_validation(options)
      when :auto_enhance_compliance
        orchestrate_compliance_enhancement(options)
      when :analyze_brand_performance
        orchestrate_brand_performance_analysis(options)
      when :sync_brand_updates
        orchestrate_brand_sync(options)
      else
        raise ArgumentError, "Unknown operation: #{operation}"
      end
    end
    
    # Generate brand-aware journey suggestions
    def orchestrate_brand_aware_suggestions(options = {})
      return no_brand_suggestions_result unless journey.brand.present?
      
      # Initialize suggestion engine with brand context
      suggestion_engine = JourneySuggestionEngine.new(
        journey: journey,
        user: user,
        current_step: options[:current_step],
        provider: options[:provider] || :openai
      )
      
      # Generate suggestions with brand filtering
      raw_suggestions = suggestion_engine.generate_suggestions(options[:filters] || {})
      
      # Apply additional brand compliance filtering
      compliant_suggestions = filter_suggestions_for_brand_compliance(raw_suggestions)
      
      # Enhance suggestions with brand-specific recommendations
      enhanced_suggestions = enhance_suggestions_with_brand_insights(compliant_suggestions)
      
      # Store integration results
      store_integration_insights('brand_aware_suggestions', {
        total_suggestions: raw_suggestions.length,
        compliant_suggestions: compliant_suggestions.length,
        enhanced_suggestions: enhanced_suggestions.length,
        suggestions: enhanced_suggestions
      })
      
      {
        success: true,
        suggestions: enhanced_suggestions,
        brand_integration: {
          brand_filtered: raw_suggestions.length - compliant_suggestions.length,
          brand_enhanced: enhanced_suggestions.length - compliant_suggestions.length,
          compliance_applied: true
        }
      }
    rescue => e
      handle_integration_error(e, 'suggestion_generation')
    end
    
    # Validate journey content against brand guidelines
    def orchestrate_content_validation(options = {})
      return no_brand_validation_result unless journey.brand.present?
      
      validation_results = []
      steps_to_validate = determine_validation_scope(options)
      
      steps_to_validate.each do |step|
        compliance_service = Journey::BrandComplianceService.new(
          journey: journey,
          step: step,
          content: step.description || step.name,
          context: build_step_context(step)
        )
        
        step_result = compliance_service.check_compliance(options[:compliance_options] || {})
        step_result[:step_id] = step.id
        step_result[:step_name] = step.name
        
        validation_results << step_result
      end
      
      # Calculate overall journey compliance
      overall_compliance = calculate_overall_journey_compliance(validation_results)
      
      # Generate actionable recommendations
      recommendations = generate_journey_compliance_recommendations(validation_results, overall_compliance)
      
      # Store validation insights
      store_integration_insights('content_validation', {
        overall_compliance: overall_compliance,
        step_results: validation_results,
        recommendations: recommendations,
        validated_steps: steps_to_validate.length
      })
      
      {
        success: true,
        overall_compliance: overall_compliance,
        step_results: validation_results,
        recommendations: recommendations,
        validation_summary: build_validation_summary(validation_results)
      }
    rescue => e
      handle_integration_error(e, 'content_validation')
    end
    
    # Auto-enhance journey content for better brand compliance
    def orchestrate_compliance_enhancement(options = {})
      return no_brand_enhancement_result unless journey.brand.present? && config.auto_fix_enabled
      
      enhancement_results = []
      steps_to_enhance = determine_enhancement_scope(options)
      
      steps_to_enhance.each do |step|
        compliance_service = Journey::BrandComplianceService.new(
          journey: journey,
          step: step,
          content: step.description || step.name,
          context: build_step_context(step)
        )
        
        # Check current compliance
        current_compliance = compliance_service.check_compliance
        
        if current_compliance[:score] < config.compliance_check_threshold
          # Attempt auto-fix
          fix_result = compliance_service.auto_fix_violations
          
          if fix_result[:fixed_content].present?
            # Update step with fixed content
            step.update!(description: fix_result[:fixed_content])
            
            enhancement_results << {
              step_id: step.id,
              step_name: step.name,
              enhanced: true,
              original_score: current_compliance[:score],
              improved_score: compliance_service.quick_score,
              fixes_applied: fix_result[:fixes_applied] || []
            }
          else
            enhancement_results << {
              step_id: step.id,
              step_name: step.name,
              enhanced: false,
              original_score: current_compliance[:score],
              issues: current_compliance[:violations] || []
            }
          end
        else
          enhancement_results << {
            step_id: step.id,
            step_name: step.name,
            enhanced: false,
            original_score: current_compliance[:score],
            already_compliant: true
          }
        end
      end
      
      # Store enhancement insights
      store_integration_insights('compliance_enhancement', {
        enhancement_results: enhancement_results,
        steps_processed: steps_to_enhance.length,
        steps_enhanced: enhancement_results.count { |r| r[:enhanced] }
      })
      
      {
        success: true,
        enhancement_results: enhancement_results,
        summary: build_enhancement_summary(enhancement_results)
      }
    rescue => e
      handle_integration_error(e, 'compliance_enhancement')
    end
    
    # Analyze brand performance across the journey
    def orchestrate_brand_performance_analysis(options = {})
      return no_brand_analysis_result unless journey.brand.present?
      
      analysis_period = options[:period_days] || 30
      
      # Gather brand compliance analytics
      compliance_summary = journey.brand_compliance_summary(analysis_period)
      compliance_by_step = journey.brand_compliance_by_step(analysis_period)
      violations_breakdown = journey.brand_violations_breakdown(analysis_period)
      
      # Analyze brand health trends
      brand_health = journey.overall_brand_health_score
      compliance_trend = journey.brand_compliance_trend(analysis_period)
      alerts = journey.brand_compliance_alerts
      
      # Generate insights and recommendations
      performance_insights = generate_brand_performance_insights(
        compliance_summary, 
        compliance_by_step, 
        violations_breakdown,
        brand_health,
        compliance_trend
      )
      
      recommendations = generate_brand_performance_recommendations(
        performance_insights,
        alerts
      )
      
      # Store performance analysis
      store_integration_insights('brand_performance_analysis', {
        analysis_period: analysis_period,
        compliance_summary: compliance_summary,
        brand_health_score: brand_health,
        compliance_trend: compliance_trend,
        insights: performance_insights,
        recommendations: recommendations,
        alerts: alerts
      })
      
      {
        success: true,
        brand_health_score: brand_health,
        compliance_trend: compliance_trend,
        compliance_summary: compliance_summary,
        compliance_by_step: compliance_by_step,
        violations_breakdown: violations_breakdown,
        insights: performance_insights,
        recommendations: recommendations,
        alerts: alerts
      }
    rescue => e
      handle_integration_error(e, 'brand_performance_analysis')
    end
    
    # Sync journey content with updated brand guidelines
    def orchestrate_brand_sync(options = {})
      return no_brand_sync_result unless journey.brand.present?
      
      sync_results = []
      updated_guidelines = options[:updated_guidelines] || []
      
      # If no specific guidelines provided, sync all active guidelines
      if updated_guidelines.empty?
        updated_guidelines = journey.brand.brand_guidelines.active.pluck(:id)
      end
      
      # Re-validate all journey steps against updated guidelines
      journey.journey_steps.each do |step|
        compliance_service = Journey::BrandComplianceService.new(
          journey: journey,
          step: step,
          content: step.description || step.name,
          context: build_step_context(step)
        )
        
        # Check compliance with updated guidelines
        updated_compliance = compliance_service.check_compliance(
          compliance_level: :standard,
          force_refresh: true
        )
        
        # Compare with previous compliance if available
        previous_check = step.latest_compliance_check
        previous_score = previous_check&.data&.dig('score') || 0.0
        
        sync_results << {
          step_id: step.id,
          step_name: step.name,
          previous_score: previous_score,
          updated_score: updated_compliance[:score],
          score_change: updated_compliance[:score] - previous_score,
          new_violations: updated_compliance[:violations] || [],
          requires_attention: updated_compliance[:score] < config.compliance_check_threshold
        }
      end
      
      # Generate sync recommendations
      sync_recommendations = generate_sync_recommendations(sync_results)
      
      # Store sync insights
      store_integration_insights('brand_sync', {
        synced_guidelines: updated_guidelines,
        sync_results: sync_results,
        steps_requiring_attention: sync_results.count { |r| r[:requires_attention] },
        recommendations: sync_recommendations
      })
      
      {
        success: true,
        sync_results: sync_results,
        steps_requiring_attention: sync_results.count { |r| r[:requires_attention] },
        recommendations: sync_recommendations,
        summary: build_sync_summary(sync_results)
      }
    rescue => e
      handle_integration_error(e, 'brand_sync')
    end
    
    # Get integration health status
    def integration_health_check
      return { healthy: false, reason: 'No brand associated' } unless journey.brand.present?
      
      health_indicators = {
        brand_setup: check_brand_setup_health,
        journey_compliance: check_journey_compliance_health,
        integration_performance: check_integration_performance_health,
        recent_activity: check_recent_activity_health
      }
      
      overall_health = health_indicators.values.all? { |indicator| indicator[:healthy] }
      
      {
        healthy: overall_health,
        indicators: health_indicators,
        recommendations: overall_health ? [] : generate_health_recommendations(health_indicators)
      }
    end
    
    private
    
    def filter_suggestions_for_brand_compliance(suggestions)
      return suggestions unless journey.brand.present?
      
      suggestions.select do |suggestion|
        # Filter based on brand compliance score
        compliance_score = suggestion['brand_compliance_score'] || 0.5
        compliance_score >= config.compliance_check_threshold
      end
    end
    
    def enhance_suggestions_with_brand_insights(suggestions)
      return suggestions unless journey.brand.present?
      
      brand_context = extract_brand_enhancement_context
      
      suggestions.map do |suggestion|
        enhanced_suggestion = suggestion.dup
        
        # Add brand-specific enhancements
        enhanced_suggestion['brand_enhancements'] = generate_brand_enhancements(suggestion, brand_context)
        enhanced_suggestion['brand_compliance_tips'] = generate_compliance_tips(suggestion, brand_context)
        
        enhanced_suggestion
      end
    end
    
    def extract_brand_enhancement_context
      brand = journey.brand
      
      {
        messaging_framework: brand.messaging_framework,
        recent_guidelines: brand.brand_guidelines.active.order(updated_at: :desc).limit(5),
        voice_attributes: brand.brand_voice_attributes,
        industry_context: brand.industry
      }
    end
    
    def generate_brand_enhancements(suggestion, brand_context)
      enhancements = []
      
      # Messaging framework enhancements
      if brand_context[:messaging_framework]&.key_messages.present?
        relevant_messages = find_relevant_key_messages(suggestion, brand_context[:messaging_framework])
        if relevant_messages.any?
          enhancements << {
            type: 'key_messaging',
            recommendation: "Consider incorporating: #{relevant_messages.join(', ')}",
            priority: 'high'
          }
        end
      end
      
      # Voice attribute enhancements
      if brand_context[:voice_attributes].present?
        voice_recommendations = generate_voice_recommendations(suggestion, brand_context[:voice_attributes])
        enhancements.concat(voice_recommendations)
      end
      
      enhancements
    end
    
    def generate_compliance_tips(suggestion, brand_context)
      tips = []
      
      # Content type specific tips
      content_type = suggestion['content_type']
      case content_type
      when 'email'
        tips << "Ensure email signature includes brand elements"
        tips << "Use approved email templates if available"
      when 'social_post'
        tips << "Include brand hashtags where appropriate"
        tips << "Follow social media brand voice guidelines"
      when 'blog_post'
        tips << "Include brand storytelling elements"
        tips << "Use brand-approved images and formatting"
      end
      
      # Channel specific tips
      channel = suggestion['channel']
      if channel == 'website'
        tips << "Ensure consistent with website brand guidelines"
        tips << "Use approved fonts and color schemes"
      end
      
      tips.uniq
    end
    
    def find_relevant_key_messages(suggestion, messaging_framework)
      # Simple keyword matching - could be enhanced with NLP
      suggestion_text = "#{suggestion['name']} #{suggestion['description']}".downcase
      relevant_messages = []
      
      messaging_framework.key_messages.each do |category, messages|
        messages.each do |message|
          if suggestion_text.include?(message.downcase) || 
             message.downcase.split.any? { |word| suggestion_text.include?(word) }
            relevant_messages << message
          end
        end
      end
      
      relevant_messages.uniq.first(3)  # Limit to 3 most relevant
    end
    
    def generate_voice_recommendations(suggestion, voice_attributes)
      recommendations = []
      
      if voice_attributes['tone']
        recommendations << {
          type: 'tone_guidance',
          recommendation: "Maintain #{voice_attributes['tone']} tone throughout content",
          priority: 'medium'
        }
      end
      
      if voice_attributes['formality']
        recommendations << {
          type: 'formality_guidance',
          recommendation: "Use #{voice_attributes['formality']} language style",
          priority: 'medium'
        }
      end
      
      recommendations
    end
    
    def determine_validation_scope(options)
      if options[:step_ids].present?
        journey.journey_steps.where(id: options[:step_ids])
      elsif options[:stage].present?
        journey.journey_steps.where(stage: options[:stage])
      else
        journey.journey_steps
      end
    end
    
    def determine_enhancement_scope(options)
      if options[:step_ids].present?
        journey.journey_steps.where(id: options[:step_ids])
      elsif options[:low_compliance_only]
        # Find steps with low compliance scores
        step_ids_needing_enhancement = []
        journey.journey_steps.each do |step|
          if step.quick_compliance_score < config.compliance_check_threshold
            step_ids_needing_enhancement << step.id
          end
        end
        journey.journey_steps.where(id: step_ids_needing_enhancement)
      else
        journey.journey_steps
      end
    end
    
    def build_step_context(step)
      {
        step_id: step.id,
        step_type: step.content_type,
        channel: step.channel,
        stage: step.stage,
        position: step.position,
        journey_context: {
          campaign_type: journey.campaign_type,
          target_audience: journey.target_audience
        }
      }
    end
    
    def calculate_overall_journey_compliance(validation_results)
      return { score: 1.0, compliant: true } if validation_results.empty?
      
      scores = validation_results.map { |result| result[:score] || 0.0 }
      average_score = scores.sum / scores.length
      compliant_count = validation_results.count { |result| result[:compliant] }
      
      {
        score: average_score.round(3),
        compliant: compliant_count == validation_results.length,
        compliant_steps: compliant_count,
        total_steps: validation_results.length,
        compliance_rate: (compliant_count.to_f / validation_results.length * 100).round(1)
      }
    end
    
    def generate_journey_compliance_recommendations(validation_results, overall_compliance)
      recommendations = []
      
      # Overall recommendations
      if overall_compliance[:score] < 0.8
        recommendations << {
          type: 'overall_improvement',
          priority: 'high',
          message: 'Journey has low brand compliance overall',
          action: 'Review and update content across multiple steps'
        }
      end
      
      # Step-specific recommendations
      validation_results.each do |result|
        next if result[:compliant]
        
        recommendations << {
          type: 'step_improvement',
          priority: result[:score] < 0.5 ? 'high' : 'medium',
          step_id: result[:step_id],
          step_name: result[:step_name],
          message: "Step has #{result[:violations]&.length || 0} brand violations",
          action: 'Review content against brand guidelines'
        }
      end
      
      recommendations
    end
    
    def generate_brand_performance_insights(compliance_summary, compliance_by_step, violations_breakdown, brand_health, compliance_trend)
      insights = []
      
      # Compliance trend insight
      case compliance_trend
      when 'improving'
        insights << {
          type: 'positive_trend',
          message: 'Brand compliance is improving over time',
          impact: 'Brand consistency is strengthening'
        }
      when 'declining'
        insights << {
          type: 'negative_trend',
          message: 'Brand compliance is declining',
          impact: 'Brand consistency may be weakening'
        }
      end
      
      # Step performance insights
      if compliance_by_step.any?
        worst_performing_step = compliance_by_step.min_by { |_, data| data[:average_score] }
        best_performing_step = compliance_by_step.max_by { |_, data| data[:average_score] }
        
        if worst_performing_step[1][:average_score] < 0.6
          insights << {
            type: 'step_performance',
            message: "Step ID #{worst_performing_step[0]} has consistently low compliance",
            impact: 'May negatively affect brand perception'
          }
        end
        
        if best_performing_step[1][:average_score] > 0.9
          insights << {
            type: 'step_success',
            message: "Step ID #{best_performing_step[0]} maintains excellent brand compliance",
            impact: 'Can serve as a template for other steps'
          }
        end
      end
      
      # Violation pattern insights
      if violations_breakdown[:by_category].any?
        most_common_violation = violations_breakdown[:by_category].max_by { |_, count| count }
        
        insights << {
          type: 'violation_pattern',
          message: "Most common violation type: #{most_common_violation[0]}",
          impact: 'Focus improvement efforts on this area'
        }
      end
      
      insights
    end
    
    def generate_brand_performance_recommendations(insights, alerts)
      recommendations = []
      
      # Convert alerts to recommendations
      alerts.each do |alert|
        recommendations << {
          type: alert[:type],
          priority: alert[:severity],
          message: alert[:message],
          action: alert[:recommendation]
        }
      end
      
      # Add insight-based recommendations
      insights.each do |insight|
        case insight[:type]
        when 'negative_trend'
          recommendations << {
            type: 'trend_improvement',
            priority: 'high',
            message: 'Address declining compliance trend',
            action: 'Audit recent content changes and reinforce brand guidelines'
          }
        when 'violation_pattern'
          recommendations << {
            type: 'pattern_fix',
            priority: 'medium',
            message: 'Address common violation pattern',
            action: "Focus on improving #{insight[:message].split(': ').last} compliance"
          }
        end
      end
      
      recommendations.uniq { |r| [r[:type], r[:message]] }
    end
    
    def generate_sync_recommendations(sync_results)
      recommendations = []
      
      # Find steps that need immediate attention
      critical_steps = sync_results.select { |r| r[:requires_attention] && r[:updated_score] < 0.5 }
      
      if critical_steps.any?
        recommendations << {
          type: 'critical_fixes',
          priority: 'high',
          message: "#{critical_steps.length} steps require immediate attention",
          action: 'Review and fix critical brand violations',
          step_ids: critical_steps.map { |s| s[:step_id] }
        }
      end
      
      # Find steps with significant score decreases
      declining_steps = sync_results.select { |r| r[:score_change] < -0.2 }
      
      if declining_steps.any?
        recommendations << {
          type: 'score_decline',
          priority: 'medium',
          message: "#{declining_steps.length} steps show significant compliance decline",
          action: 'Investigate what changed in brand guidelines',
          step_ids: declining_steps.map { |s| s[:step_id] }
        }
      end
      
      recommendations
    end
    
    def store_integration_insights(operation_type, data)
      journey.journey_insights.create!(
        insights_type: 'brand_integration',
        data: data.merge(
          operation_type: operation_type,
          integration_timestamp: Time.current,
          brand_id: journey.brand&.id
        ),
        calculated_at: Time.current,
        expires_at: 7.days.from_now,
        metadata: {
          service: 'BrandIntegrationService',
          user_id: user&.id,
          context: integration_context
        }
      )
    rescue => e
      Rails.logger.error "Failed to store integration insights: #{e.message}"
    end
    
    def build_validation_summary(validation_results)
      return {} if validation_results.empty?
      
      {
        total_steps: validation_results.length,
        compliant_steps: validation_results.count { |r| r[:compliant] },
        average_score: (validation_results.sum { |r| r[:score] || 0.0 } / validation_results.length).round(3),
        total_violations: validation_results.sum { |r| (r[:violations] || []).length }
      }
    end
    
    def build_enhancement_summary(enhancement_results)
      return {} if enhancement_results.empty?
      
      enhanced_count = enhancement_results.count { |r| r[:enhanced] }
      
      {
        total_steps: enhancement_results.length,
        enhanced_steps: enhanced_count,
        enhancement_rate: (enhanced_count.to_f / enhancement_results.length * 100).round(1),
        average_improvement: calculate_average_improvement(enhancement_results)
      }
    end
    
    def build_sync_summary(sync_results)
      return {} if sync_results.empty?
      
      {
        total_steps: sync_results.length,
        steps_requiring_attention: sync_results.count { |r| r[:requires_attention] },
        average_score_change: (sync_results.sum { |r| r[:score_change] } / sync_results.length).round(3),
        improved_steps: sync_results.count { |r| r[:score_change] > 0 },
        declined_steps: sync_results.count { |r| r[:score_change] < 0 }
      }
    end
    
    def calculate_average_improvement(enhancement_results)
      enhanced_results = enhancement_results.select { |r| r[:enhanced] && r[:improved_score] && r[:original_score] }
      return 0.0 if enhanced_results.empty?
      
      improvements = enhanced_results.map { |r| r[:improved_score] - r[:original_score] }
      (improvements.sum / improvements.length).round(3)
    end
    
    def check_brand_setup_health
      brand = journey.brand
      issues = []
      
      issues << "No messaging framework" unless brand.messaging_framework.present?
      issues << "No active brand guidelines" unless brand.brand_guidelines.active.any?
      issues << "No brand voice attributes" unless brand.brand_voice_attributes.present?
      
      { healthy: issues.empty?, issues: issues }
    end
    
    def check_journey_compliance_health
      compliance_summary = journey.brand_compliance_summary(7)
      
      if compliance_summary.empty?
        { healthy: false, issues: ["No recent compliance checks"] }
      elsif compliance_summary[:average_score] < 0.7
        { healthy: false, issues: ["Low average compliance score: #{compliance_summary[:average_score]}"] }
      else
        { healthy: true, issues: [] }
      end
    end
    
    def check_integration_performance_health
      recent_insights = journey.journey_insights
                               .where(insights_type: 'brand_integration')
                               .where('calculated_at >= ?', 24.hours.ago)
      
      if recent_insights.empty?
        { healthy: false, issues: ["No recent integration activity"] }
      else
        { healthy: true, issues: [] }
      end
    end
    
    def check_recent_activity_health
      recent_updates = journey.journey_steps.where('updated_at >= ?', 24.hours.ago)
      
      if recent_updates.any?
        # Check if recent updates maintained compliance
        low_compliance_updates = recent_updates.select { |step| step.quick_compliance_score < 0.7 }
        
        if low_compliance_updates.any?
          { healthy: false, issues: ["Recent updates decreased compliance"] }
        else
          { healthy: true, issues: [] }
        end
      else
        { healthy: true, issues: [] }
      end
    end
    
    def generate_health_recommendations(health_indicators)
      recommendations = []
      
      health_indicators.each do |indicator_name, indicator_data|
        next if indicator_data[:healthy]
        
        indicator_data[:issues].each do |issue|
          case indicator_name
          when :brand_setup
            recommendations << {
              type: 'brand_setup',
              priority: 'high',
              message: issue,
              action: get_brand_setup_action(issue)
            }
          when :journey_compliance
            recommendations << {
              type: 'compliance_improvement',
              priority: 'medium',
              message: issue,
              action: 'Review and improve journey content'
            }
          when :integration_performance
            recommendations << {
              type: 'integration_activity',
              priority: 'low',
              message: issue,
              action: 'Run brand integration operations'
            }
          when :recent_activity
            recommendations << {
              type: 'recent_compliance',
              priority: 'medium',
              message: issue,
              action: 'Review recent changes for brand compliance'
            }
          end
        end
      end
      
      recommendations
    end
    
    def get_brand_setup_action(issue)
      case issue
      when /messaging framework/
        'Set up brand messaging framework with key messages and tone'
      when /brand guidelines/
        'Create active brand guidelines for content validation'
      when /voice attributes/
        'Define brand voice attributes and tone guidelines'
      else
        'Complete brand setup'
      end
    end
    
    def handle_integration_error(error, operation)
      Rails.logger.error "Brand integration error in #{operation}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
      
      {
        success: false,
        error: error.message,
        error_type: error.class.name,
        operation: operation,
        timestamp: Time.current
      }
    end
    
    def no_brand_suggestions_result
      {
        success: true,
        suggestions: [],
        brand_integration: {
          brand_filtered: 0,
          brand_enhanced: 0,
          compliance_applied: false,
          message: 'No brand associated with journey'
        }
      }
    end
    
    def no_brand_validation_result
      {
        success: true,
        overall_compliance: { score: 1.0, compliant: true },
        step_results: [],
        recommendations: [],
        validation_summary: {},
        message: 'No brand guidelines to validate against'
      }
    end
    
    def no_brand_enhancement_result
      {
        success: true,
        enhancement_results: [],
        summary: {},
        message: 'No brand guidelines for enhancement or auto-fix disabled'
      }
    end
    
    def no_brand_analysis_result
      {
        success: true,
        brand_health_score: 1.0,
        compliance_trend: 'stable',
        insights: [],
        recommendations: [],
        alerts: [],
        message: 'No brand associated for analysis'
      }
    end
    
    def no_brand_sync_result
      {
        success: true,
        sync_results: [],
        recommendations: [],
        summary: {},
        message: 'No brand guidelines to sync'
      }
    end
  end
end