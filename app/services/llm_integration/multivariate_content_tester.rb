module LlmIntegration
  class MultivariateContentTester
    include ActiveModel::Model

    def initialize
      @active_tests = {}
      @test_results = {}
    end

    def setup_test(variants, parameters = {})
      test_id = SecureRandom.uuid

      test_config = {
        id: test_id,
        variants: variants,
        parameters: parameters,
        status: "setup",
        created_at: Time.current,
        traffic_allocation: distribute_traffic(variants.length, parameters),
        success_metrics: parameters[:success_metrics] || [ "engagement", "conversion" ],
        confidence_level: parameters[:confidence_level] || 0.95,
        minimum_sample_size: calculate_minimum_sample_size(parameters)
      }

      @active_tests[test_id] = test_config
      test_config
    end

    def create_test(test_variables)
      # Create test with variables configuration
      variants = generate_test_variants(test_variables)
      parameters = extract_test_parameters(test_variables)

      setup_test(variants, parameters)
    end

    def start_test(test_id)
      test = @active_tests[test_id]
      return nil unless test

      test[:status] = "running"
      test[:started_at] = Time.current

      # Initialize tracking for each variant
      test[:variants].each_with_index do |variant, index|
        variant[:test_data] = {
          impressions: 0,
          clicks: 0,
          conversions: 0,
          engagement_score: 0.0,
          conversion_rate: 0.0
        }
      end

      test
    end

    def record_interaction(test_id, variant_index, interaction_type, value = 1)
      test = @active_tests[test_id]
      return false unless test && test[:status] == "running"
      return false unless variant_index < test[:variants].length

      variant_data = test[:variants][variant_index][:test_data]

      case interaction_type.to_sym
      when :impression
        variant_data[:impressions] += value
      when :click
        variant_data[:clicks] += value
      when :conversion
        variant_data[:conversions] += value
      when :engagement
        variant_data[:engagement_score] =
          (variant_data[:engagement_score] + value) / 2.0
      end

      # Update calculated metrics
      update_calculated_metrics(variant_data)

      # Check if test should be concluded
      check_test_completion(test_id)

      true
    end

    def get_test_results(test_id)
      test = @active_tests[test_id]
      return nil unless test

      {
        test_id: test_id,
        status: test[:status],
        duration: test[:started_at] ? Time.current - test[:started_at] : 0,
        variants_performance: analyze_variants_performance(test),
        statistical_significance: calculate_statistical_significance(test),
        winner: determine_winner(test),
        confidence_intervals: calculate_confidence_intervals(test),
        recommendations: generate_recommendations(test)
      }
    end

    def stop_test(test_id, reason = "manual")
      test = @active_tests[test_id]
      return nil unless test

      test[:status] = "completed"
      test[:completed_at] = Time.current
      test[:completion_reason] = reason

      final_results = get_test_results(test_id)
      @test_results[test_id] = final_results

      final_results
    end

    def list_active_tests
      @active_tests.select { |_, test| test[:status] == "running" }
    end

    def get_test_summary(test_id)
      test = @active_tests[test_id] || @test_results[test_id]
      return nil unless test

      {
        id: test_id,
        status: test[:status],
        variants_count: test[:variants]&.length || 0,
        duration: calculate_duration(test),
        total_impressions: sum_metric(test, :impressions),
        total_conversions: sum_metric(test, :conversions),
        overall_conversion_rate: calculate_overall_conversion_rate(test)
      }
    end

    private

    def distribute_traffic(variants_count, parameters)
      if parameters[:traffic_distribution].present?
        parameters[:traffic_distribution]
      else
        equal_split = (100.0 / variants_count).round(2)
        variants_count.times.map { |i| { variant: i, percentage: equal_split } }
      end
    end

    def calculate_minimum_sample_size(parameters)
      # Simplified sample size calculation
      baseline_rate = parameters[:baseline_conversion_rate] || 0.05
      minimum_detectable_effect = parameters[:minimum_effect] || 0.2

      # Basic statistical power calculation
      base_sample = (100 / baseline_rate).to_i
      effect_factor = (1 / minimum_detectable_effect).to_i

      [ base_sample * effect_factor, 1000 ].max
    end

    def update_calculated_metrics(variant_data)
      if variant_data[:impressions] > 0
        variant_data[:click_through_rate] =
          variant_data[:clicks].to_f / variant_data[:impressions]
      end

      if variant_data[:clicks] > 0
        variant_data[:conversion_rate] =
          variant_data[:conversions].to_f / variant_data[:clicks]
      end

      # Overall performance score
      variant_data[:performance_score] = calculate_performance_score(variant_data)
    end

    def calculate_performance_score(data)
      ctr_score = (data[:click_through_rate] || 0) * 0.3
      conversion_score = (data[:conversion_rate] || 0) * 0.4
      engagement_score = (data[:engagement_score] || 0) * 0.3

      (ctr_score + conversion_score + engagement_score).round(3)
    end

    def check_test_completion(test_id)
      test = @active_tests[test_id]
      return unless test[:status] == "running"

      # Check if minimum sample size reached
      total_conversions = sum_metric(test, :conversions)
      if total_conversions >= test[:minimum_sample_size]
        significance = calculate_statistical_significance(test)
        if significance[:significant]
          stop_test(test_id, "statistical_significance_reached")
        end
      end

      # Check for maximum duration (auto-stop after 30 days)
      if Time.current - test[:started_at] > 30.days
        stop_test(test_id, "maximum_duration_reached")
      end
    end

    def analyze_variants_performance(test)
      test[:variants].map.with_index do |variant, index|
        data = variant[:test_data] || {}

        {
          variant_index: index,
          variant_content: variant[:content],
          optimization_strategy: variant[:optimization_strategy],
          impressions: data[:impressions] || 0,
          clicks: data[:clicks] || 0,
          conversions: data[:conversions] || 0,
          click_through_rate: data[:click_through_rate] || 0,
          conversion_rate: data[:conversion_rate] || 0,
          performance_score: data[:performance_score] || 0,
          engagement_score: data[:engagement_score] || 0
        }
      end
    end

    def calculate_statistical_significance(test)
      return { significant: false, p_value: 1.0 } unless test[:variants]&.length >= 2

      # Simplified significance calculation
      # In practice, you'd use proper statistical tests like Chi-square or t-test
      best_variant = test[:variants].max_by { |v| v[:test_data][:performance_score] || 0 }
      second_best = test[:variants].select { |v| v != best_variant }
                                   .max_by { |v| v[:test_data][:performance_score] || 0 }

      return { significant: false, p_value: 1.0 } unless best_variant && second_best

      best_score = best_variant[:test_data][:performance_score] || 0
      second_score = second_best[:test_data][:performance_score] || 0

      difference = best_score - second_score
      sample_size = best_variant[:test_data][:impressions] || 0

      # Simplified p-value calculation
      p_value = if difference > 0.05 && sample_size > 100
        0.02
      elsif difference > 0.03 && sample_size > 500
        0.04
      else
        0.15
      end

      {
        significant: p_value < 0.05,
        p_value: p_value,
        confidence_level: 1 - p_value,
        effect_size: difference
      }
    end

    def determine_winner(test)
      return nil unless test[:variants]&.any?

      best_variant = test[:variants].each_with_index
                                   .max_by { |variant, _| variant[:test_data][:performance_score] || 0 }

      return nil unless best_variant

      variant, index = best_variant

      {
        variant_index: index,
        content: variant[:content],
        optimization_strategy: variant[:optimization_strategy],
        performance_score: variant[:test_data][:performance_score] || 0,
        improvement_over_baseline: calculate_improvement_over_baseline(test, index)
      }
    end

    def calculate_confidence_intervals(test)
      test[:variants].map.with_index do |variant, index|
        data = variant[:test_data] || {}
        conversion_rate = data[:conversion_rate] || 0
        sample_size = data[:clicks] || 0

        if sample_size > 0
          margin_of_error = 1.96 * Math.sqrt((conversion_rate * (1 - conversion_rate)) / sample_size)
          {
            variant_index: index,
            conversion_rate: conversion_rate,
            confidence_interval: {
              lower: [ conversion_rate - margin_of_error, 0 ].max,
              upper: [ conversion_rate + margin_of_error, 1 ].min
            }
          }
        else
          {
            variant_index: index,
            conversion_rate: 0,
            confidence_interval: { lower: 0, upper: 0 }
          }
        end
      end
    end

    def generate_recommendations(test)
      winner = determine_winner(test)
      significance = calculate_statistical_significance(test)

      recommendations = []

      if significance[:significant] && winner
        recommendations << "Implement the winning variant (#{winner[:optimization_strategy]}) for significant performance improvement"
        recommendations << "Monitor performance after implementation to ensure sustained results"
      elsif !significance[:significant]
        recommendations << "Extend test duration to reach statistical significance"
        recommendations << "Consider increasing traffic allocation to accelerate results"
      end

      if test[:variants].any? { |v| (v[:test_data][:impressions] || 0) < 100 }
        recommendations << "Some variants have insufficient sample size - consider traffic redistribution"
      end

      recommendations
    end

    def calculate_improvement_over_baseline(test, winner_index)
      return 0 unless test[:variants].length > 1

      winner_score = test[:variants][winner_index][:test_data][:performance_score] || 0
      baseline_score = test[:variants][0][:test_data][:performance_score] || 0

      return 0 if baseline_score == 0

      ((winner_score - baseline_score) / baseline_score * 100).round(2)
    end

    def sum_metric(test, metric)
      return 0 unless test[:variants]

      test[:variants].sum { |v| v[:test_data][metric] || 0 }
    end

    def calculate_overall_conversion_rate(test)
      total_clicks = sum_metric(test, :clicks)
      total_conversions = sum_metric(test, :conversions)

      return 0 if total_clicks == 0

      (total_conversions.to_f / total_clicks * 100).round(2)
    end

    def calculate_duration(test)
      return 0 unless test[:started_at]

      end_time = test[:completed_at] || Time.current
      ((end_time - test[:started_at]) / 1.day).round(1)
    end

    def generate_test_variants(test_variables)
      # Generate variants based on test variables
      base_content = test_variables[:base_content] || "Default content"
      variable_combinations = test_variables[:variables] || {}

      variants = []

      # Generate combinations of variables
      if variable_combinations.any?
        variable_combinations.each_with_index do |(variable_name, values), index|
          values.each do |value|
            variants << {
              content: base_content.gsub("{{#{variable_name}}}", value.to_s),
              variables: { variable_name => value },
              variant_id: "#{variable_name}_#{value}",
              test_data: {}
            }
          end
        end
      else
        # Default single variant
        variants << {
          content: base_content,
          variables: {},
          variant_id: "control",
          test_data: {}
        }
      end

      variants
    end

    def extract_test_parameters(test_variables)
      {
        confidence_level: test_variables[:confidence_level] || 0.95,
        minimum_effect: test_variables[:minimum_effect] || 0.1,
        success_metrics: test_variables[:success_metrics] || [ "conversion" ],
        traffic_distribution: test_variables[:traffic_distribution],
        baseline_conversion_rate: test_variables[:baseline_rate] || 0.05
      }
    end
  end
end
