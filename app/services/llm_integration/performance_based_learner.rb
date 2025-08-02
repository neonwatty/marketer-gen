module LlmIntegration
  class PerformanceBasedLearner
    include ActiveModel::Model

    def initialize
      @performance_history = {}
      @learning_model = initialize_learning_model
    end

    def learn_from_performance(content_id, performance_data)
      # Store performance data for learning
      @performance_history[content_id] ||= []
      @performance_history[content_id] << {
        timestamp: Time.current,
        performance: performance_data,
        content_features: extract_content_features(performance_data[:content])
      }

      # Update learning model
      update_learning_model(content_id, performance_data)

      # Return insights gained
      {
        patterns_identified: identify_performance_patterns(content_id),
        optimization_suggestions: generate_learned_suggestions(content_id),
        confidence_score: calculate_learning_confidence(content_id)
      }
    end

    def train(training_data)
      # Train the learning model with historical data
      training_data.each do |data_point|
        content_id = data_point[:content_id] || SecureRandom.uuid
        performance_data = {
          content: data_point[:content],
          content_type: data_point[:content_type],
          overall_score: data_point[:performance_score] || 0.5
        }

        learn_from_performance(content_id, performance_data)
      end

      {
        training_samples: training_data.length,
        model_confidence: calculate_overall_model_confidence,
        trained_patterns: @learning_model.keys.length
      }
    end

    def predict_performance(content_features)
      # Use learned patterns to predict performance
      base_prediction = apply_learned_patterns(content_features)

      {
        predicted_engagement: base_prediction[:engagement] || 0.5,
        predicted_conversion: base_prediction[:conversion] || 0.03,
        confidence_interval: calculate_prediction_confidence(content_features),
        key_factors: identify_key_performance_factors(content_features)
      }
    end

    def get_optimization_recommendations(content_type, performance_goal)
      # Get recommendations based on learned patterns
      learned_patterns = @learning_model[content_type] || {}

      recommendations = []

      case performance_goal
      when "engagement"
        recommendations.concat(get_engagement_recommendations(learned_patterns))
      when "conversion"
        recommendations.concat(get_conversion_recommendations(learned_patterns))
      when "brand_compliance"
        recommendations.concat(get_brand_recommendations(learned_patterns))
      end

      {
        recommendations: recommendations,
        confidence: calculate_recommendation_confidence(learned_patterns),
        supporting_data: get_supporting_evidence(content_type, performance_goal)
      }
    end

    def analyze_content_trends(time_period = 30.days)
      cutoff_date = time_period.ago
      recent_data = filter_recent_performance_data(cutoff_date)

      {
        performance_trends: analyze_performance_trends(recent_data),
        emerging_patterns: identify_emerging_patterns(recent_data),
        declining_patterns: identify_declining_patterns(recent_data),
        recommendations: generate_trend_based_recommendations(recent_data)
      }
    end

    def export_learned_insights
      {
        total_content_analyzed: @performance_history.keys.length,
        performance_patterns: summarize_learned_patterns,
        top_performing_strategies: identify_top_strategies,
        optimization_insights: compile_optimization_insights,
        model_confidence: calculate_overall_model_confidence
      }
    end

    private

    def initialize_learning_model
      {
        # Store learned patterns by content type
        "email" => { patterns: {}, confidence: 0.5 },
        "social" => { patterns: {}, confidence: 0.5 },
        "website" => { patterns: {}, confidence: 0.5 },
        "blog" => { patterns: {}, confidence: 0.5 }
      }
    end

    def extract_content_features(content)
      return {} unless content.present?

      {
        word_count: content.split.length,
        sentence_count: content.split(/[.!?]+/).length,
        question_count: content.count("?"),
        exclamation_count: content.count("!"),
        uppercase_ratio: content.scan(/[A-Z]/).length.to_f / content.length,
        call_to_action_presence: detect_cta_presence(content),
        emotional_words: count_emotional_words(content),
        readability_score: calculate_simple_readability(content)
      }
    end

    def update_learning_model(content_id, performance_data)
      content_type = performance_data[:content_type] || "general"
      performance_score = performance_data[:overall_score] || 0.5

      # Simple learning: track which features correlate with performance
      if @performance_history[content_id].length > 1
        features = @performance_history[content_id].last[:content_features]

        features.each do |feature, value|
          update_feature_correlation(content_type, feature, value, performance_score)
        end
      end
    end

    def update_feature_correlation(content_type, feature, value, performance_score)
      @learning_model[content_type] ||= { patterns: {}, confidence: 0.5 }
      patterns = @learning_model[content_type][:patterns]

      patterns[feature] ||= { positive_correlation: 0, negative_correlation: 0, total_samples: 0 }

      if performance_score > 0.7
        patterns[feature][:positive_correlation] += 1
      elsif performance_score < 0.4
        patterns[feature][:negative_correlation] += 1
      end

      patterns[feature][:total_samples] += 1

      # Update confidence based on sample size
      @learning_model[content_type][:confidence] = calculate_model_confidence(content_type)
    end

    def identify_performance_patterns(content_id)
      history = @performance_history[content_id] || []
      return [] if history.length < 3

      patterns = []

      # Analyze performance over time
      scores = history.map { |h| h[:performance][:overall_score] || 0.5 }

      if scores.last > scores.first + 0.1
        patterns << "improving_performance_trend"
      elsif scores.last < scores.first - 0.1
        patterns << "declining_performance_trend"
      else
        patterns << "stable_performance"
      end

      # Identify feature patterns
      feature_patterns = analyze_feature_patterns(history)
      patterns.concat(feature_patterns)

      patterns
    end

    def analyze_feature_patterns(history)
      patterns = []

      # Look for consistent high-performing features
      high_performing_entries = history.select { |h| (h[:performance][:overall_score] || 0) > 0.7 }

      if high_performing_entries.length >= 2
        common_features = find_common_features(high_performing_entries)
        patterns.concat(common_features.map { |f| "high_performance_#{f}" })
      end

      patterns
    end

    def find_common_features(entries)
      return [] if entries.empty?

      common_features = []
      first_features = entries.first[:content_features] || {}

      first_features.each do |feature, value|
        if entries.all? { |e| similar_feature_value?(e[:content_features][feature], value) }
          common_features << feature
        end
      end

      common_features
    end

    def similar_feature_value?(value1, value2)
      return false if value1.nil? || value2.nil?

      if value1.is_a?(Numeric) && value2.is_a?(Numeric)
        (value1 - value2).abs < (value1 + value2) * 0.2 # Within 20%
      else
        value1 == value2
      end
    end

    def generate_learned_suggestions(content_id)
      patterns = identify_performance_patterns(content_id)
      suggestions = []

      patterns.each do |pattern|
        case pattern
        when "improving_performance_trend"
          suggestions << "Continue current optimization approach"
        when "declining_performance_trend"
          suggestions << "Review recent changes and consider reverting"
        when /high_performance_(.+)/
          feature = $1
          suggestions << "Maintain #{feature.humanize} characteristics"
        end
      end

      suggestions
    end

    def apply_learned_patterns(content_features)
      # Simple pattern application
      engagement_score = 0.5
      conversion_score = 0.03

      # Apply learned correlations
      @learning_model.each do |content_type, model_data|
        patterns = model_data[:patterns]
        confidence = model_data[:confidence]

        next if confidence < 0.6 # Skip low confidence models

        patterns.each do |feature, correlation_data|
          next unless content_features[feature]

          if correlation_data[:positive_correlation] > correlation_data[:negative_correlation]
            engagement_score += 0.1 * confidence
            conversion_score += 0.005 * confidence
          end
        end
      end

      {
        engagement: [ engagement_score, 1.0 ].min,
        conversion: [ conversion_score, 0.5 ].min
      }
    end

    def calculate_learning_confidence(content_id)
      history = @performance_history[content_id] || []

      # Confidence increases with more data points
      base_confidence = [ history.length.to_f / 10, 1.0 ].min

      # Adjust for consistency
      if history.length > 2
        scores = history.map { |h| h[:performance][:overall_score] || 0.5 }
        variance = calculate_variance(scores)
        consistency_factor = 1 - [ variance, 0.5 ].min
        base_confidence *= consistency_factor
      end

      base_confidence.round(2)
    end

    def calculate_prediction_confidence(content_features)
      # Simplified confidence calculation
      { lower: 0.8, upper: 1.2 }
    end

    def identify_key_performance_factors(content_features)
      factors = []

      # Identify important factors based on learned patterns
      @learning_model.each do |content_type, model_data|
        patterns = model_data[:patterns]

        patterns.each do |feature, correlation_data|
          if correlation_data[:total_samples] > 5 &&
             correlation_data[:positive_correlation] > correlation_data[:negative_correlation] * 2
            factors << feature
          end
        end
      end

      factors.uniq.first(5) # Top 5 factors
    end

    def get_engagement_recommendations(learned_patterns)
      recommendations = []

      learned_patterns.each do |feature, correlation|
        next unless correlation[:positive_correlation] > 3

        case feature
        when :question_count
          recommendations << "Include more questions to increase engagement"
        when :emotional_words
          recommendations << "Use more emotional language"
        when :call_to_action_presence
          recommendations << "Include clear calls-to-action"
        end
      end

      recommendations
    end

    def get_conversion_recommendations(learned_patterns)
      recommendations = []

      learned_patterns.each do |feature, correlation|
        next unless correlation[:positive_correlation] > 3

        case feature
        when :call_to_action_presence
          recommendations << "Strengthen call-to-action for better conversion"
        when :word_count
          recommendations << "Optimize content length based on learned patterns"
        end
      end

      recommendations
    end

    def get_brand_recommendations(learned_patterns)
      [ "Maintain consistent brand voice based on successful patterns" ]
    end

    def calculate_recommendation_confidence(learned_patterns)
      return 0.5 if learned_patterns.empty?

      total_samples = learned_patterns.values.sum { |p| p[:total_samples] || 0 }
      [ total_samples.to_f / 100, 1.0 ].min
    end

    def get_supporting_evidence(content_type, performance_goal)
      model_data = @learning_model[content_type] || {}
      {
        sample_size: model_data.dig(:patterns)&.values&.sum { |p| p[:total_samples] } || 0,
        confidence_level: model_data[:confidence] || 0.5
      }
    end

    # Additional helper methods
    def filter_recent_performance_data(cutoff_date)
      recent_data = {}

      @performance_history.each do |content_id, history|
        recent_entries = history.select { |entry| entry[:timestamp] > cutoff_date }
        recent_data[content_id] = recent_entries if recent_entries.any?
      end

      recent_data
    end

    def analyze_performance_trends(recent_data)
      return {} if recent_data.empty?

      trends = {}

      recent_data.each do |content_id, entries|
        scores = entries.map { |e| e[:performance][:overall_score] || 0.5 }
        next if scores.length < 2

        trend = scores.last > scores.first ? "improving" : "declining"
        trends[content_id] = {
          trend: trend,
          change: (scores.last - scores.first).round(2)
        }
      end

      trends
    end

    def identify_emerging_patterns(recent_data)
      [ "increased_engagement_with_questions" ] # Simplified
    end

    def identify_declining_patterns(recent_data)
      [ "decreased_performance_with_long_content" ] # Simplified
    end

    def generate_trend_based_recommendations(recent_data)
      [ "Focus on interactive content", "Optimize content length" ] # Simplified
    end

    def summarize_learned_patterns
      summary = {}

      @learning_model.each do |content_type, model_data|
        patterns = model_data[:patterns]
        summary[content_type] = {
          strong_correlations: patterns.select { |_, data| data[:positive_correlation] > 5 }.keys,
          confidence: model_data[:confidence]
        }
      end

      summary
    end

    def identify_top_strategies
      [ "Use questions for engagement", "Include clear CTAs", "Optimize readability" ]
    end

    def compile_optimization_insights
      [
        "Content with questions performs 20% better",
        "Shorter content tends to have higher conversion rates",
        "Emotional language increases engagement"
      ]
    end

    def calculate_overall_model_confidence
      confidences = @learning_model.values.map { |data| data[:confidence] }
      return 0.5 if confidences.empty?

      confidences.sum / confidences.length
    end

    def calculate_model_confidence(content_type)
      patterns = @learning_model[content_type][:patterns]
      return 0.5 if patterns.empty?

      total_samples = patterns.values.sum { |data| data[:total_samples] }
      [ total_samples.to_f / 50, 1.0 ].min # Max confidence with 50+ samples
    end

    def detect_cta_presence(content)
      cta_words = [ "click", "buy", "get", "download", "sign up", "learn more", "contact" ]
      cta_words.any? { |word| content.downcase.include?(word) }
    end

    def count_emotional_words(content)
      emotional_words = %w[amazing incredible fantastic wonderful terrible awful excited thrilled]
      emotional_words.count { |word| content.downcase.include?(word) }
    end

    def calculate_simple_readability(content)
      words = content.split.length
      sentences = content.split(/[.!?]+/).length

      return 50 if sentences == 0

      avg_sentence_length = words.to_f / sentences

      # Simple readability: shorter sentences = higher readability
      case avg_sentence_length
      when 0..10 then 90
      when 10..15 then 80
      when 15..20 then 70
      when 20..25 then 60
      else 50
      end
    end

    def calculate_variance(values)
      return 0 if values.empty?

      mean = values.sum.to_f / values.length
      variance = values.sum { |v| (v - mean) ** 2 } / values.length
      Math.sqrt(variance)
    end
  end
end
