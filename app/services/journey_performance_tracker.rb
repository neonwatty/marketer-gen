class JourneyPerformanceTracker
  def initialize(journey, user)
    @journey = journey
    @user = user
    @brand_identity = user.active_brand_identity
  end

  # Track performance metrics for AI-generated steps
  def track_step_performance(step, metrics = {})
    return unless step.ai_generated?

    performance_data = {
      journey_id: @journey.id,
      step_id: step.id,
      user_id: @user.id,
      brand_identity_id: @brand_identity&.id,
      step_type: step.step_type,
      channels: [step.channel].compact,
      performance_metrics: {
        engagement_rate: metrics[:engagement_rate],
        conversion_rate: metrics[:conversion_rate],
        click_through_rate: metrics[:click_through_rate],
        unsubscribe_rate: metrics[:unsubscribe_rate],
        completion_rate: metrics[:completion_rate],
        time_to_complete: metrics[:time_to_complete],
        user_satisfaction_score: metrics[:user_satisfaction_score]
      },
      brand_compliance_score: step.brand_compliance_score,
      timestamp: Time.current
    }

    # Store in learning database
    if defined?(JourneyLearningData)
      JourneyLearningData.create!(
        journey: @journey,
        user: @user,
        brand_identity: @brand_identity,
        step_type: step.step_type,
        performance_data: performance_data,
        learning_model_input: build_learning_input(step, metrics),
        learning_model_output: calculate_learning_output(metrics)
      )
    end

    # Update step with performance data
    step.update!(
      performance_metrics: performance_data[:performance_metrics],
      last_performance_update: Time.current
    )

    # Update journey's overall AI performance score
    update_journey_ai_performance
  end

  # Analyze performance patterns for learning
  def analyze_performance_patterns
    return {} unless defined?(JourneyLearningData)

    learning_data = JourneyLearningData
      .where(journey: @journey)
      .order(created_at: :desc)
      .limit(100)

    patterns = {
      best_performing_step_types: identify_best_performers(learning_data),
      optimal_timing: analyze_timing_patterns(learning_data),
      channel_effectiveness: analyze_channel_effectiveness(learning_data),
      content_patterns: analyze_content_patterns(learning_data),
      brand_compliance_impact: analyze_brand_compliance_impact(learning_data)
    }

    # Store patterns for future AI suggestions
    store_learning_patterns(patterns)
    
    patterns
  end

  # Get recommendations based on performance data
  def get_performance_recommendations
    patterns = analyze_performance_patterns
    
    recommendations = []

    # Recommend high-performing step types
    if patterns[:best_performing_step_types] && patterns[:best_performing_step_types].any?
      recommendations << {
        type: :step_type,
        priority: :high,
        recommendation: "Consider using more #{patterns[:best_performing_step_types].first[:type]} steps",
        reasoning: "These have shown #{patterns[:best_performing_step_types].first[:avg_performance]}% higher engagement",
        data: patterns[:best_performing_step_types]
      }
    end

    # Recommend optimal channels
    if patterns[:channel_effectiveness] && patterns[:channel_effectiveness].any?
      best_channel = patterns[:channel_effectiveness].max_by { |c| c[:effectiveness_score] }
      recommendations << {
        type: :channel,
        priority: :medium,
        recommendation: "Focus on #{best_channel[:channel]} for better results",
        reasoning: "This channel has #{best_channel[:effectiveness_score]}% effectiveness rate",
        data: patterns[:channel_effectiveness]
      }
    end

    # Brand compliance recommendations
    if patterns[:brand_compliance_impact] && patterns[:brand_compliance_impact][:correlation] && patterns[:brand_compliance_impact][:correlation] > 0.7
      recommendations << {
        type: :brand_compliance,
        priority: :high,
        recommendation: "Maintain high brand compliance scores (>85%)",
        reasoning: "Strong correlation (#{(patterns[:brand_compliance_impact][:correlation] * 100).round}%) between brand compliance and performance",
        data: patterns[:brand_compliance_impact]
      }
    end

    recommendations
  end

  # Feed learning data back to AI service
  def export_for_ai_training
    return {} unless defined?(JourneyLearningData)

    training_data = JourneyLearningData
      .where(journey: @journey)
      .where('learning_model_output > ?', 0.7) # Only successful outcomes
      .map do |data|
        {
          input: data.learning_model_input,
          output: data.learning_model_output,
          context: {
            brand_identity_id: data.brand_identity_id,
            step_type: data.step_type,
            performance_metrics: data.performance_data['performance_metrics']
          }
        }
      end

    {
      journey_id: @journey.id,
      training_samples: training_data,
      performance_summary: calculate_performance_summary,
      brand_context: @brand_identity ? build_brand_training_context : nil
    }
  end

  private

  def build_learning_input(step, metrics)
    {
      step_attributes: {
        type: step.step_type,
        channels: [step.channel].compact,
        timing: step.timing_trigger_type,
        content_length: step.description&.length,
        ai_generated: step.ai_generated,
        brand_compliance_score: step.brand_compliance_score
      },
      journey_context: {
        campaign_type: @journey.campaign_type,
        stage: step.stage,
        position_in_journey: step.sequence_order,
        total_steps: @journey.journey_steps.count
      },
      brand_context: @brand_identity ? {
        industry: @brand_identity.industry,
        tone_of_voice: @brand_identity.tone_of_voice,
        has_style_guide: @brand_identity.style_guide.present?
      } : nil
    }
  end

  def calculate_learning_output(metrics)
    # Calculate overall performance score (0-1)
    scores = []
    scores << metrics[:engagement_rate] / 100.0 if metrics[:engagement_rate]
    scores << metrics[:conversion_rate] / 100.0 if metrics[:conversion_rate]
    scores << metrics[:click_through_rate] / 100.0 if metrics[:click_through_rate]
    scores << (100 - (metrics[:unsubscribe_rate] || 0)) / 100.0
    
    return 0.5 if scores.empty?
    scores.sum / scores.length
  end

  def identify_best_performers(learning_data)
    return [] if learning_data.empty?

    learning_data
      .group_by(&:step_type)
      .map do |type, records|
        avg_performance = records.map(&:learning_model_output).sum / records.length
        {
          type: type,
          avg_performance: (avg_performance * 100).round(1),
          sample_size: records.count
        }
      end
      .sort_by { |p| -p[:avg_performance] }
      .first(3)
  end

  def analyze_timing_patterns(learning_data)
    timing_performance = {}
    
    learning_data.each do |record|
      timing = record.learning_model_input.dig('step_attributes', 'timing') || 'unknown'
      timing_performance[timing] ||= []
      timing_performance[timing] << record.learning_model_output
    end

    timing_performance.map do |timing, scores|
      {
        timing: timing,
        avg_performance: (scores.sum / scores.length * 100).round(1),
        sample_size: scores.length
      }
    end
  end

  def analyze_channel_effectiveness(learning_data)
    channel_performance = {}
    
    learning_data.each do |record|
      channels = record.learning_model_input.dig('step_attributes', 'channels') || []
      channels.each do |channel|
        channel_performance[channel] ||= []
        channel_performance[channel] << record.learning_model_output
      end
    end

    channel_performance.map do |channel, scores|
      {
        channel: channel,
        effectiveness_score: (scores.sum / scores.length * 100).round(1),
        sample_size: scores.length
      }
    end.sort_by { |c| -c[:effectiveness_score] }
  end

  def analyze_content_patterns(learning_data)
    content_patterns = {
      optimal_content_length: nil,
      high_performing_keywords: [],
      successful_formats: []
    }

    # Analyze content length vs performance
    length_performance = learning_data.map do |record|
      {
        length: record.learning_model_input.dig('step_attributes', 'content_length') || 0,
        performance: record.learning_model_output
      }
    end

    if length_performance.any?
      # Find optimal length range
      sorted = length_performance.sort_by { |l| -l[:performance] }
      top_performers = sorted.first(sorted.length / 4) # Top 25%
      
      if top_performers.any?
        lengths = top_performers.map { |p| p[:length] }
        content_patterns[:optimal_content_length] = {
          min: lengths.min,
          max: lengths.max,
          average: lengths.sum / lengths.length
        }
      end
    end

    content_patterns
  end

  def analyze_brand_compliance_impact(learning_data)
    compliance_scores = []
    performance_scores = []

    learning_data.each do |record|
      compliance = record.learning_model_input.dig('step_attributes', 'brand_compliance_score')
      if compliance
        compliance_scores << compliance
        performance_scores << record.learning_model_output
      end
    end

    return { correlation: 0, impact: 'unknown' } if compliance_scores.empty?

    # Calculate correlation between brand compliance and performance
    correlation = calculate_correlation(compliance_scores, performance_scores)
    
    {
      correlation: correlation.round(2),
      impact: correlation > 0.7 ? 'high' : correlation > 0.4 ? 'medium' : 'low',
      average_compliance: (compliance_scores.sum / compliance_scores.length).round(1),
      performance_by_compliance: group_performance_by_compliance(learning_data)
    }
  end

  def calculate_correlation(x_values, y_values)
    return 0 if x_values.length != y_values.length || x_values.empty?
    
    n = x_values.length
    sum_x = x_values.sum
    sum_y = y_values.sum
    sum_x_squared = x_values.map { |x| x ** 2 }.sum
    sum_y_squared = y_values.map { |y| y ** 2 }.sum
    sum_xy = x_values.zip(y_values).map { |x, y| x * y }.sum
    
    numerator = n * sum_xy - sum_x * sum_y
    denominator_x = Math.sqrt(n * sum_x_squared - sum_x ** 2)
    denominator_y = Math.sqrt(n * sum_y_squared - sum_y ** 2)
    
    return 0 if denominator_x == 0 || denominator_y == 0
    
    numerator / (denominator_x * denominator_y)
  end

  def group_performance_by_compliance(learning_data)
    groups = {
      high: { range: '85-100', performances: [] },
      medium: { range: '70-84', performances: [] },
      low: { range: '<70', performances: [] }
    }

    learning_data.each do |record|
      compliance = record.learning_model_input.dig('step_attributes', 'brand_compliance_score')
      next unless compliance

      if compliance >= 85
        groups[:high][:performances] << record.learning_model_output
      elsif compliance >= 70
        groups[:medium][:performances] << record.learning_model_output
      else
        groups[:low][:performances] << record.learning_model_output
      end
    end

    groups.map do |level, data|
      avg_performance = data[:performances].any? ? 
        (data[:performances].sum / data[:performances].length * 100).round(1) : 0
      
      {
        compliance_level: level,
        compliance_range: data[:range],
        avg_performance: avg_performance,
        sample_size: data[:performances].length
      }
    end
  end

  def store_learning_patterns(patterns)
    # Cache patterns for quick access
    Rails.cache.write(
      "journey_learning_patterns_#{@journey.id}",
      patterns,
      expires_in: 1.hour
    )

    # Update journey metadata with learning insights
    @journey.update!(
      ai_learning_data: {
        last_analysis: Time.current,
        patterns: patterns,
        recommendations: get_performance_recommendations
      }
    )
  end

  def update_journey_ai_performance
    return unless @journey.journey_steps.any?(&:ai_generated?)

    ai_steps = @journey.journey_steps.where(ai_generated: true)
    
    if ai_steps.any?
      performances = ai_steps.filter_map do |step|
        step.performance_metrics&.dig('engagement_rate')
      end

      if performances.any?
        avg_performance = performances.sum / performances.length
        @journey.update!(ai_performance_score: avg_performance)
      end
    end
  end

  def calculate_performance_summary
    {
      total_ai_steps: @journey.journey_steps.where(ai_generated: true).count,
      avg_brand_compliance: calculate_avg_brand_compliance,
      overall_performance: @journey.ai_performance_score || 0,
      top_performing_types: identify_best_performers(JourneyLearningData.where(journey: @journey).limit(50))
    }
  end

  def calculate_avg_brand_compliance
    ai_steps = @journey.journey_steps.where(ai_generated: true)
    return 0 if ai_steps.empty?

    scores = ai_steps.filter_map(&:brand_compliance_score)
    return 0 if scores.empty?

    scores.sum / scores.length
  end

  def build_brand_training_context
    {
      brand_id: @brand_identity.id,
      industry: @brand_identity.industry,
      tone_of_voice: @brand_identity.tone_of_voice,
      key_messages: @brand_identity.key_messages,
      has_style_guide: @brand_identity.style_guide.present?,
      has_visual_assets: @brand_identity.brand_assets.any?
    }
  end
end