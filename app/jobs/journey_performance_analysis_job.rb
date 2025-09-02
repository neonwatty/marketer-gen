class JourneyPerformanceAnalysisJob < ApplicationJob
  queue_as :low_priority

  def perform(journey_id = nil)
    if journey_id
      # Analyze specific journey
      analyze_journey(journey_id)
    else
      # Analyze all active journeys with AI features
      analyze_all_active_journeys
    end
  end

  private

  def analyze_journey(journey_id)
    journey = Journey.find(journey_id)
    return unless journey.journey_steps.where(ai_generated: true).any?

    user = journey.user
    tracker = JourneyPerformanceTracker.new(journey, user)

    # Analyze performance patterns
    patterns = tracker.analyze_performance_patterns
    
    # Get recommendations
    recommendations = tracker.get_performance_recommendations

    # Export for AI training if enough data
    if journey.journey_steps.where(ai_generated: true).count >= 5
      training_data = tracker.export_for_ai_training
      store_training_data(training_data)
    end

    # Update journey with insights
    journey.update!(
      last_ai_analysis: Time.current,
      ai_insights: {
        patterns: patterns,
        recommendations: recommendations,
        analysis_timestamp: Time.current
      }
    )

    # Notify user if significant insights found
    if recommendations.any? { |r| r[:priority] == :high }
      notify_user_of_insights(journey, recommendations)
    end

    Rails.logger.info "Analyzed journey #{journey_id}: Found #{recommendations.count} recommendations"
  rescue StandardError => e
    Rails.logger.error "Failed to analyze journey #{journey_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def analyze_all_active_journeys
    # Find journeys that need analysis
    journeys_to_analyze = Journey
      .joins(:journey_steps)
      .where(journey_steps: { ai_generated: true })
      .where(status: %w[active in_progress])
      .where('journeys.last_ai_analysis IS NULL OR journeys.last_ai_analysis < ?', 24.hours.ago)
      .distinct
      .limit(50) # Process in batches

    Rails.logger.info "Starting performance analysis for #{journeys_to_analyze.count} journeys"

    journeys_to_analyze.find_each do |journey|
      # Queue individual analysis jobs to avoid timeout
      JourneyPerformanceAnalysisJob.perform_later(journey.id)
    end

    # Aggregate learning across all journeys for global insights
    if journeys_to_analyze.count >= 10
      aggregate_global_insights
    end
  end

  def store_training_data(training_data)
    return if training_data[:training_samples].empty?

    # Store in a format ready for AI model training
    training_file = Rails.root.join('tmp', 'ai_training', "journey_#{training_data[:journey_id]}_#{Time.current.to_i}.json")
    
    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(training_file))
    
    # Write training data
    File.write(training_file, JSON.pretty_generate(training_data))

    # Also store in database if training data model exists
    if defined?(AiTrainingData)
      AiTrainingData.create!(
        model_type: 'journey_suggestions',
        training_data: training_data,
        data_points_count: training_data[:training_samples].count,
        journey_id: training_data[:journey_id]
      )
    end
  end

  def notify_user_of_insights(journey, recommendations)
    high_priority_recs = recommendations.select { |r| r[:priority] == :high }
    
    # Create notification or send email (depending on system setup)
    if defined?(Notification)
      Notification.create!(
        user: journey.user,
        title: "AI Performance Insights for #{journey.name}",
        message: build_insights_message(high_priority_recs),
        notification_type: 'ai_insights',
        metadata: {
          journey_id: journey.id,
          recommendations_count: high_priority_recs.count
        }
      )
    end

    # Log for tracking
    Rails.logger.info "Notified user #{journey.user.id} about insights for journey #{journey.id}"
  end

  def build_insights_message(recommendations)
    message = "We've identified #{recommendations.count} high-priority insights:\n\n"
    
    recommendations.each_with_index do |rec, index|
      message += "#{index + 1}. #{rec[:recommendation]}\n"
      message += "   Reason: #{rec[:reasoning]}\n\n"
    end
    
    message
  end

  def aggregate_global_insights
    # Collect patterns across all journeys
    global_patterns = {
      most_effective_step_types: aggregate_step_type_effectiveness,
      optimal_journey_length: calculate_optimal_journey_length,
      brand_compliance_correlation: analyze_global_brand_compliance,
      channel_performance_matrix: build_channel_performance_matrix,
      timing_optimization: analyze_global_timing_patterns
    }

    # Store global insights
    Rails.cache.write(
      'journey_ai_global_insights',
      global_patterns,
      expires_in: 1.week
    )

    # Update AI configuration with learnings
    update_ai_configuration_with_insights(global_patterns)

    Rails.logger.info "Updated global AI insights from #{Journey.count} journeys"
  end

  def aggregate_step_type_effectiveness
    return {} unless defined?(JourneyLearningData)

    JourneyLearningData
      .group(:step_type)
      .average(:learning_model_output)
      .transform_values { |v| (v * 100).round(1) }
      .sort_by { |_, v| -v }
      .to_h
  end

  def calculate_optimal_journey_length
    successful_journeys = Journey
      .where(status: 'completed')
      .where('completion_rate > ?', 70)
      .includes(:journey_steps)

    if successful_journeys.any?
      lengths = successful_journeys.map { |j| j.journey_steps.count }
      {
        min: lengths.min,
        max: lengths.max,
        average: lengths.sum / lengths.length,
        median: lengths.sort[lengths.length / 2]
      }
    else
      { min: 3, max: 10, average: 6, median: 5 }
    end
  end

  def analyze_global_brand_compliance
    return {} unless defined?(JourneyStep)

    ai_steps = JourneyStep.where(ai_generated: true).where.not(brand_compliance_score: nil)
    
    if ai_steps.any?
      scores = ai_steps.pluck(:brand_compliance_score)
      performance_metrics = ai_steps.filter_map { |s| s.performance_metrics&.dig('engagement_rate') }
      
      if scores.any? && performance_metrics.any?
        {
          average_compliance: (scores.sum / scores.length).round(1),
          high_compliance_performance: calculate_high_compliance_performance(ai_steps),
          compliance_threshold: 85 # Recommended minimum
        }
      else
        {}
      end
    else
      {}
    end
  end

  def calculate_high_compliance_performance(ai_steps)
    high_compliance = ai_steps.select { |s| s.brand_compliance_score >= 85 }
    low_compliance = ai_steps.select { |s| s.brand_compliance_score < 85 }
    
    high_perf = high_compliance.filter_map { |s| s.performance_metrics&.dig('engagement_rate') }
    low_perf = low_compliance.filter_map { |s| s.performance_metrics&.dig('engagement_rate') }
    
    if high_perf.any? && low_perf.any?
      {
        high_compliance_avg: (high_perf.sum / high_perf.length).round(1),
        low_compliance_avg: (low_perf.sum / low_perf.length).round(1),
        performance_lift: ((high_perf.sum / high_perf.length) - (low_perf.sum / low_perf.length)).round(1)
      }
    else
      {}
    end
  end

  def build_channel_performance_matrix
    return {} unless defined?(JourneyStep)

    channel_data = {}
    
    JourneyStep.where(ai_generated: true).find_each do |step|
      next unless step.channels.any? && step.performance_metrics

      step.channels.each do |channel|
        channel_data[channel] ||= []
        if (engagement = step.performance_metrics['engagement_rate'])
          channel_data[channel] << engagement
        end
      end
    end

    channel_data.transform_values do |performances|
      {
        average: (performances.sum / performances.length).round(1),
        sample_size: performances.length,
        confidence: performances.length >= 10 ? 'high' : 'low'
      }
    end
  end

  def analyze_global_timing_patterns
    return {} unless defined?(JourneyStep)

    timing_data = JourneyStep
      .where(ai_generated: true)
      .where.not(timing_trigger_type: nil)
      .group(:timing_trigger_type)
      .average('performance_metrics->\'engagement_rate\'')

    timing_data.transform_values { |v| v&.round(1) }.compact
  end

  def update_ai_configuration_with_insights(patterns)
    # Update AI service configuration with learned patterns
    config_updates = {
      preferred_step_types: patterns[:most_effective_step_types]&.keys&.first(5),
      optimal_journey_length: patterns[:optimal_journey_length],
      minimum_brand_compliance: patterns[:brand_compliance_correlation][:compliance_threshold],
      channel_preferences: extract_channel_preferences(patterns[:channel_performance_matrix]),
      timing_preferences: patterns[:timing_optimization]
    }

    # Store configuration updates
    Rails.cache.write(
      'journey_ai_learned_config',
      config_updates,
      expires_in: 1.week
    )

    Rails.logger.info "Updated AI configuration with learned insights"
  end

  def extract_channel_preferences(channel_matrix)
    return [] unless channel_matrix.is_a?(Hash)

    channel_matrix
      .select { |_, data| data[:confidence] == 'high' }
      .sort_by { |_, data| -data[:average] }
      .first(3)
      .map(&:first)
  end
end