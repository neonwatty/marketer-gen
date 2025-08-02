module LlmIntegration
  class ContentPerformanceAnalyzer
    include ActiveModel::Model

    def initialize
      @performance_cache = {}
      @benchmark_data = load_benchmark_data
    end

    def analyze_content_performance(content, metrics_data = {})
      {
        overall_score: calculate_overall_score(metrics_data),
        engagement_analysis: analyze_engagement(content, metrics_data),
        conversion_analysis: analyze_conversion(content, metrics_data),
        brand_performance: analyze_brand_performance(content, metrics_data),
        competitive_analysis: analyze_competitive_performance(content, metrics_data),
        improvement_opportunities: identify_improvement_opportunities(content, metrics_data),
        performance_trends: analyze_performance_trends(content, metrics_data),
        recommendations: generate_performance_recommendations(content, metrics_data)
      }
    end

    def benchmark_content(content, industry = nil, content_type = nil)
      benchmark_key = "#{industry}_#{content_type}".downcase
      benchmarks = @benchmark_data[benchmark_key] || @benchmark_data["default"]

      content_metrics = extract_content_metrics(content)

      {
        benchmark_comparison: compare_to_benchmarks(content_metrics, benchmarks),
        percentile_ranking: calculate_percentile_ranking(content_metrics, benchmarks),
        performance_gaps: identify_performance_gaps(content_metrics, benchmarks),
        improvement_potential: calculate_improvement_potential(content_metrics, benchmarks)
      }
    end

    def predict_performance(content, context = {})
      # Handle both string content and hash with content
      if content.is_a?(Hash)
        actual_content = content[:content] || content[:text] || ""
        context = content.except(:content, :text).merge(context)
      else
        actual_content = content.to_s
      end

      content_features = extract_content_features(actual_content)
      contextual_factors = analyze_contextual_factors(context)

      {
        predicted_engagement_rate: predict_engagement_rate(content_features, contextual_factors),
        predicted_conversion_rate: predict_conversion_rate(content_features, contextual_factors),
        confidence_interval: calculate_prediction_confidence(content_features),
        risk_factors: identify_risk_factors(content_features, contextual_factors),
        success_probability: calculate_success_probability(content_features, contextual_factors)
      }
    end

    def track_performance_over_time(content_id, metrics_data)
      cache_key = "performance_#{content_id}"
      @performance_cache[cache_key] ||= []

      performance_point = {
        timestamp: Time.current,
        metrics: metrics_data,
        calculated_score: calculate_overall_score(metrics_data)
      }

      @performance_cache[cache_key] << performance_point

      # Keep only last 90 days
      cutoff_date = 90.days.ago
      @performance_cache[cache_key] = @performance_cache[cache_key]
                                        .select { |point| point[:timestamp] > cutoff_date }

      analyze_performance_trends(content_id)
    end

    def generate_performance_report(content, time_period = 30.days)
      end_date = Time.current
      start_date = end_date - time_period

      {
        summary: generate_performance_summary(content, start_date, end_date),
        detailed_metrics: extract_detailed_metrics(content, start_date, end_date),
        trend_analysis: analyze_trends_for_period(content, start_date, end_date),
        comparative_analysis: compare_to_previous_period(content, start_date, end_date),
        actionable_insights: generate_actionable_insights(content, start_date, end_date),
        next_steps: recommend_next_steps(content, start_date, end_date)
      }
    end

    private

    def calculate_overall_score(metrics_data)
      return 0.5 if metrics_data.empty?

      # Weight different metrics based on importance
      weights = {
        engagement_rate: 0.25,
        conversion_rate: 0.30,
        click_through_rate: 0.20,
        time_on_page: 0.15,
        social_shares: 0.10
      }

      weighted_score = 0
      total_weight = 0

      weights.each do |metric, weight|
        if metrics_data[metric].present?
          normalized_value = normalize_metric_value(metric, metrics_data[metric])
          weighted_score += normalized_value * weight
          total_weight += weight
        end
      end

      total_weight > 0 ? (weighted_score / total_weight).round(3) : 0.5
    end

    def analyze_engagement(content, metrics_data)
      {
        engagement_rate: metrics_data[:engagement_rate] || 0,
        engagement_quality: assess_engagement_quality(metrics_data),
        engagement_drivers: identify_engagement_drivers(content),
        engagement_trends: analyze_engagement_trends(metrics_data),
        benchmark_comparison: compare_engagement_to_benchmark(metrics_data)
      }
    end

    def analyze_conversion(content, metrics_data)
      {
        conversion_rate: metrics_data[:conversion_rate] || 0,
        conversion_funnel_performance: analyze_conversion_funnel(metrics_data),
        conversion_drivers: identify_conversion_drivers(content),
        conversion_barriers: identify_conversion_barriers(content, metrics_data),
        optimization_opportunities: find_conversion_optimization_opportunities(content, metrics_data)
      }
    end

    def analyze_brand_performance(content, metrics_data)
      {
        brand_awareness_lift: metrics_data[:brand_awareness_lift] || 0,
        brand_sentiment_score: metrics_data[:brand_sentiment] || 0.5,
        brand_recall_rate: metrics_data[:brand_recall] || 0,
        brand_association_strength: assess_brand_associations(content),
        brand_consistency_score: assess_brand_consistency(content)
      }
    end

    def analyze_competitive_performance(content, metrics_data)
      {
        competitive_benchmark: compare_to_competitors(metrics_data),
        market_position: assess_market_position(metrics_data),
        competitive_advantages: identify_competitive_advantages(content, metrics_data),
        competitive_gaps: identify_competitive_gaps(metrics_data),
        market_share_impact: estimate_market_share_impact(metrics_data)
      }
    end

    def identify_improvement_opportunities(content, metrics_data)
      opportunities = []

      # Check for low-performing metrics
      if (metrics_data[:engagement_rate] || 0) < 0.3
        opportunities << {
          area: "engagement",
          priority: "high",
          description: "Low engagement rate indicates content may not resonate with audience",
          suggested_actions: [ "Review content relevance", "Test different formats", "Analyze audience preferences" ]
        }
      end

      if (metrics_data[:conversion_rate] || 0) < 0.05
        opportunities << {
          area: "conversion",
          priority: "high",
          description: "Low conversion rate suggests optimization needed",
          suggested_actions: [ "Strengthen call-to-action", "Simplify conversion process", "Test different value propositions" ]
        }
      end

      opportunities
    end

    def extract_content_features(content)
      return default_content_features if content.blank?

      {
        word_count: content.split.length,
        sentence_count: content.split(/[.!?]+/).length,
        readability_score: calculate_readability_score(content),
        sentiment_score: analyze_sentiment(content),
        keyword_density: calculate_keyword_density(content),
        emotional_triggers: identify_emotional_triggers(content),
        call_to_action_strength: assess_cta_strength(content)
      }
    end

    def default_content_features
      {
        word_count: 0,
        sentence_count: 0,
        readability_score: 50,
        sentiment_score: 0.5,
        keyword_density: 0,
        emotional_triggers: 0,
        call_to_action_strength: 0
      }
    end

    def analyze_contextual_factors(context)
      {
        target_audience: context[:audience] || "general",
        channel: context[:channel] || "web",
        timing: context[:timing] || "general",
        campaign_type: context[:campaign_type] || "general",
        competitive_landscape: context[:competitive_intensity] || "medium"
      }
    end

    def predict_engagement_rate(content_features, contextual_factors)
      # Simplified prediction model
      base_rate = 0.15

      # Adjust based on content features
      if content_features[:readability_score] > 60
        base_rate += 0.05
      end

      if content_features[:emotional_triggers] > 2
        base_rate += 0.03
      end

      # Adjust based on context
      channel_multipliers = {
        "social" => 1.2,
        "email" => 0.9,
        "web" => 1.0,
        "mobile" => 1.1
      }

      multiplier = channel_multipliers[contextual_factors[:channel]] || 1.0

      (base_rate * multiplier).round(3)
    end

    def predict_conversion_rate(content_features, contextual_factors)
      # Simplified conversion prediction
      base_rate = 0.03

      if content_features[:call_to_action_strength] > 0.7
        base_rate += 0.02
      end

      if content_features[:sentiment_score] > 0.6
        base_rate += 0.01
      end

      base_rate.round(3)
    end

    def normalize_metric_value(metric, value)
      # Normalize different metrics to 0-1 scale
      case metric
      when :engagement_rate
        [ value.to_f, 1.0 ].min
      when :conversion_rate
        [ value.to_f * 10, 1.0 ].min # Assuming conversion rates are typically low
      when :click_through_rate
        [ value.to_f * 5, 1.0 ].min
      when :time_on_page
        [ (value.to_f / 300), 1.0 ].min # Normalize to 5 minutes max
      when :social_shares
        [ (value.to_f / 100), 1.0 ].min # Normalize to 100 shares max
      else
        [ value.to_f, 1.0 ].min
      end
    end

    def load_benchmark_data
      {
        "default" => {
          engagement_rate: 0.15,
          conversion_rate: 0.025,
          click_through_rate: 0.05,
          time_on_page: 120,
          social_shares: 5
        },
        "technology_blog" => {
          engagement_rate: 0.22,
          conversion_rate: 0.035,
          click_through_rate: 0.08,
          time_on_page: 180,
          social_shares: 12
        },
        "ecommerce_product" => {
          engagement_rate: 0.18,
          conversion_rate: 0.045,
          click_through_rate: 0.12,
          time_on_page: 90,
          social_shares: 3
        }
      }
    end

    def calculate_readability_score(content)
      # Simplified Flesch Reading Ease approximation
      words = content.split.length
      sentences = content.split(/[.!?]+/).length
      syllables = content.split.sum { |word| count_syllables(word) }

      return 50 if sentences == 0 || words == 0

      206.835 - (1.015 * (words.to_f / sentences)) - (84.6 * (syllables.to_f / words))
    end

    def count_syllables(word)
      # Simplified syllable counting
      vowels = word.downcase.scan(/[aeiouy]/).length
      [ vowels, 1 ].max
    end

    def analyze_sentiment(content)
      # Simplified sentiment analysis
      positive_words = %w[great excellent amazing wonderful fantastic good best love excellent]
      negative_words = %w[bad terrible awful horrible hate worst disappointing poor]

      words = content.downcase.split
      positive_count = words.count { |word| positive_words.include?(word) }
      negative_count = words.count { |word| negative_words.include?(word) }

      return 0.5 if words.empty?

      score = 0.5 + ((positive_count - negative_count).to_f / words.length)
      [ [ score, 0.0 ].max, 1.0 ].min
    end

    def calculate_keyword_density(content)
      words = content.downcase.split
      return 0 if words.empty?

      word_frequency = Hash.new(0)
      words.each { |word| word_frequency[word] += 1 }

      # Return density of most frequent word (excluding common words)
      common_words = %w[the and or but in on at to for of with by]
      content_words = word_frequency.reject { |word, _| common_words.include?(word) }

      return 0 if content_words.empty?

      max_frequency = content_words.values.max
      (max_frequency.to_f / words.length * 100).round(2)
    end

    def identify_emotional_triggers(content)
      emotional_words = %w[exciting breakthrough revolutionary amazing incredible transform discover unlock secret proven guaranteed]
      words = content.downcase.split

      emotional_words.count { |trigger| words.any? { |word| word.include?(trigger) } }
    end

    def assess_cta_strength(content)
      cta_phrases = [ "click here", "buy now", "get started", "learn more", "sign up", "download", "contact us" ]
      action_words = %w[discover explore join start begin try test experience]

      cta_score = 0

      # Check for explicit CTAs
      cta_phrases.each do |phrase|
        if content.downcase.include?(phrase)
          cta_score += 0.3
        end
      end

      # Check for action words
      action_words.each do |word|
        if content.downcase.include?(word)
          cta_score += 0.1
        end
      end

      [ cta_score, 1.0 ].min
    end

    # Placeholder methods for complex analyses
    def assess_engagement_quality(metrics_data)
      "high" # Simplified
    end

    def identify_engagement_drivers(content)
      [ "relevant content", "clear value proposition" ] # Simplified
    end

    def analyze_engagement_trends(metrics_data)
      "stable" # Simplified
    end

    def compare_engagement_to_benchmark(metrics_data)
      "above average" # Simplified
    end

    def analyze_conversion_funnel(metrics_data)
      { awareness: 0.8, consideration: 0.6, conversion: 0.4 } # Simplified
    end

    def identify_conversion_drivers(content)
      [ "strong call-to-action", "clear benefits" ] # Simplified
    end

    def identify_conversion_barriers(content, metrics_data)
      [] # Simplified
    end

    def find_conversion_optimization_opportunities(content, metrics_data)
      [ "strengthen value proposition" ] # Simplified
    end

    def assess_brand_associations(content)
      0.7 # Simplified
    end

    def assess_brand_consistency(content)
      0.8 # Simplified
    end

    def compare_to_competitors(metrics_data)
      "competitive" # Simplified
    end

    def assess_market_position(metrics_data)
      "strong" # Simplified
    end

    def identify_competitive_advantages(content, metrics_data)
      [ "unique positioning" ] # Simplified
    end

    def identify_competitive_gaps(metrics_data)
      [] # Simplified
    end

    def estimate_market_share_impact(metrics_data)
      0.05 # Simplified
    end

    def analyze_performance_trends(content_id)
      cache_key = "performance_#{content_id}"
      performance_history = @performance_cache[cache_key] || []

      return { trend: "insufficient_data" } if performance_history.length < 2

      recent_scores = performance_history.last(7).map { |p| p[:calculated_score] }
      trend_direction = recent_scores.last > recent_scores.first ? "improving" : "declining"

      { trend: trend_direction, data_points: performance_history.length }
    end

    def compare_to_benchmarks(content_metrics, benchmarks)
      comparison = {}

      benchmarks.each do |metric, benchmark_value|
        content_value = content_metrics[metric] || 0
        percentage_difference = ((content_value - benchmark_value) / benchmark_value * 100).round(2)

        comparison[metric] = {
          content_value: content_value,
          benchmark_value: benchmark_value,
          percentage_difference: percentage_difference,
          performance: percentage_difference > 0 ? "above_benchmark" : "below_benchmark"
        }
      end

      comparison
    end

    def calculate_percentile_ranking(content_metrics, benchmarks)
      # Simplified percentile calculation
      { overall: 65 } # Placeholder
    end

    def identify_performance_gaps(content_metrics, benchmarks)
      gaps = []

      benchmarks.each do |metric, benchmark_value|
        content_value = content_metrics[metric] || 0
        if content_value < benchmark_value * 0.8 # 20% below benchmark
          gaps << {
            metric: metric,
            gap_size: benchmark_value - content_value,
            improvement_needed: ((benchmark_value - content_value) / benchmark_value * 100).round(2)
          }
        end
      end

      gaps
    end

    def calculate_improvement_potential(content_metrics, benchmarks)
      total_potential = 0
      metric_count = 0

      benchmarks.each do |metric, benchmark_value|
        content_value = content_metrics[metric] || 0
        if content_value < benchmark_value
          potential = ((benchmark_value - content_value) / benchmark_value)
          total_potential += potential
          metric_count += 1
        end
      end

      metric_count > 0 ? (total_potential / metric_count * 100).round(2) : 0
    end

    def calculate_prediction_confidence(content_features)
      # Simplified confidence calculation
      { lower: 0.8, upper: 1.2 }
    end

    def identify_risk_factors(content_features, contextual_factors)
      [ "market_volatility" ] # Simplified
    end

    def calculate_success_probability(content_features, contextual_factors)
      0.75 # Simplified
    end

    # Additional placeholder methods for report generation
    def generate_performance_summary(content, start_date, end_date)
      { status: "positive", key_metrics: {} }
    end

    def extract_detailed_metrics(content, start_date, end_date)
      {}
    end

    def analyze_trends_for_period(content, start_date, end_date)
      {}
    end

    def compare_to_previous_period(content, start_date, end_date)
      {}
    end

    def generate_actionable_insights(content, start_date, end_date)
      []
    end

    def recommend_next_steps(content, start_date, end_date)
      []
    end

    def extract_content_metrics(content)
      # Extract basic metrics from content
      {
        word_count: content.split.length,
        readability_score: calculate_readability_score(content),
        sentiment_score: analyze_sentiment(content)
      }
    end
  end
end
