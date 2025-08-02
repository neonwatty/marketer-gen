module AbTesting
  class AbTestPatternRecognizer
    def identify_patterns(historical_tests)
      patterns = {
        campaign_type_patterns: analyze_campaign_type_patterns(historical_tests),
        audience_patterns: analyze_audience_patterns(historical_tests),
        variation_effectiveness: analyze_variation_effectiveness(historical_tests),
        seasonal_patterns: analyze_seasonal_patterns(historical_tests),
        success_factors: identify_success_factors(historical_tests)
      }

      patterns
    end

    def analyze_campaign_type_patterns(tests)
      campaign_patterns = {}

      # Group tests by campaign type
      grouped_tests = tests.group_by { |test| test[:campaign_type] }

      grouped_tests.each do |campaign_type, campaign_tests|
        successful_variations = []
        total_lift = 0
        win_count = 0

        campaign_tests.each do |test|
          if test[:winner] && test[:lift] > 0
            successful_variations.concat(test[:variations] || [])
            total_lift += test[:lift]
            win_count += 1
          end
        end

        campaign_patterns[campaign_type] = {
          total_tests: campaign_tests.length,
          successful_tests: win_count,
          success_rate: win_count.to_f / campaign_tests.length,
          average_lift: win_count > 0 ? (total_lift / win_count).round(2) : 0,
          successful_variations: successful_variations.tally.sort_by(&:last).reverse.to_h,
          common_winning_elements: identify_common_elements(campaign_tests.select { |t| t[:winner] })
        }
      end

      campaign_patterns
    end

    def analyze_audience_patterns(tests)
      audience_patterns = {}

      # Group by audience segment
      grouped_tests = tests.group_by { |test| test[:audience_segment] }

      grouped_tests.each do |audience, audience_tests|
        lifts = audience_tests.map { |test| test[:lift] || 0 }
        successful_tests = audience_tests.select { |test| test[:lift] && test[:lift] > 10 }

        audience_patterns[audience] = {
          total_tests: audience_tests.length,
          average_lift: lifts.sum.to_f / lifts.length,
          median_lift: calculate_median(lifts),
          success_rate: successful_tests.length.to_f / audience_tests.length,
          preferred_variations: extract_preferred_variations(successful_tests),
          response_characteristics: analyze_audience_response(audience_tests)
        }
      end

      audience_patterns
    end

    def calculate_variation_effectiveness(variations_data)
      effectiveness = {}

      variations_data.each do |variation_type, instances|
        wins = instances.count { |instance| instance[:won] }
        total_lift = instances.sum { |instance| instance[:lift] || 0 }

        effectiveness[variation_type] = {
          total_tests: instances.length,
          wins: wins,
          win_rate: wins.to_f / instances.length,
          average_lift: instances.length > 0 ? (total_lift / instances.length).round(2) : 0,
          confidence_score: calculate_confidence_score(wins, instances.length),
          recommendation: generate_variation_recommendation(wins, instances.length, total_lift)
        }
      end

      effectiveness
    end

    def analyze_variation_effectiveness(tests)
      variation_performance = {}

      tests.each do |test|
        variations = test[:variations] || []
        winner = test[:winner]

        variations.each do |variation|
          variation_performance[variation] ||= { tests: [], wins: 0, total_lift: 0 }
          variation_performance[variation][:tests] << test

          if variation == winner
            variation_performance[variation][:wins] += 1
            variation_performance[variation][:total_lift] += test[:lift] || 0
          end
        end
      end

      # Calculate effectiveness metrics
      effectiveness = {}
      variation_performance.each do |variation, data|
        total_tests = data[:tests].length
        wins = data[:wins]

        effectiveness[variation] = {
          total_tests: total_tests,
          wins: wins,
          win_rate: wins.to_f / total_tests,
          average_lift_when_winning: wins > 0 ? (data[:total_lift] / wins).round(2) : 0,
          confidence_level: calculate_variation_confidence(wins, total_tests),
          industries_successful: data[:tests].map { |t| t[:industry] }.uniq,
          recommended_contexts: identify_recommended_contexts(data[:tests], wins > 0)
        }
      end

      effectiveness
    end

    private

    def analyze_seasonal_patterns(tests)
      # Group tests by time periods
      seasonal_data = {
        monthly_performance: {},
        day_of_week_performance: {},
        quarterly_trends: {}
      }

      tests.each do |test|
        # Extract timing information (simplified)
        month = test[:month] || rand(1..12)  # Placeholder
        quarter = ((month - 1) / 3) + 1
        day_of_week = test[:day_of_week] || %w[Monday Tuesday Wednesday Thursday Friday].sample

        # Monthly patterns
        seasonal_data[:monthly_performance][month] ||= { tests: 0, avg_lift: 0, lifts: [] }
        seasonal_data[:monthly_performance][month][:tests] += 1
        seasonal_data[:monthly_performance][month][:lifts] << (test[:lift] || 0)

        # Day of week patterns
        seasonal_data[:day_of_week_performance][day_of_week] ||= { tests: 0, lifts: [] }
        seasonal_data[:day_of_week_performance][day_of_week][:tests] += 1
        seasonal_data[:day_of_week_performance][day_of_week][:lifts] << (test[:lift] || 0)

        # Quarterly trends
        seasonal_data[:quarterly_trends][quarter] ||= { tests: 0, lifts: [] }
        seasonal_data[:quarterly_trends][quarter][:tests] += 1
        seasonal_data[:quarterly_trends][quarter][:lifts] << (test[:lift] || 0)
      end

      # Calculate averages
      [ :monthly_performance, :day_of_week_performance, :quarterly_trends ].each do |period|
        seasonal_data[period].each do |key, data|
          data[:avg_lift] = data[:lifts].sum.to_f / data[:lifts].length if data[:lifts].any?
        end
      end

      seasonal_data
    end

    def identify_success_factors(tests)
      successful_tests = tests.select { |test| test[:lift] && test[:lift] > 15 }
      unsuccessful_tests = tests.select { |test| !test[:lift] || test[:lift] < 5 }

      success_factors = {
        high_impact_elements: identify_common_elements(successful_tests),
        low_impact_elements: identify_common_elements(unsuccessful_tests),
        critical_success_factors: [],
        avoid_factors: []
      }

      # Compare successful vs unsuccessful patterns
      successful_variations = successful_tests.flat_map { |test| test[:variations] || [] }.tally
      unsuccessful_variations = unsuccessful_tests.flat_map { |test| test[:variations] || [] }.tally

      # Identify variations that appear more in successful tests
      successful_variations.each do |variation, success_count|
        unsuccessful_count = unsuccessful_variations[variation] || 0
        success_rate = success_count.to_f / (success_count + unsuccessful_count)

        if success_rate > 0.7
          success_factors[:critical_success_factors] << {
            factor: variation,
            success_rate: success_rate.round(3),
            success_count: success_count
          }
        elsif success_rate < 0.3
          success_factors[:avoid_factors] << {
            factor: variation,
            failure_rate: (1 - success_rate).round(3),
            unsuccessful_count: unsuccessful_count
          }
        end
      end

      success_factors
    end

    def identify_common_elements(tests)
      return {} if tests.empty?

      # Extract common characteristics
      all_variations = tests.flat_map { |test| test[:variations] || [] }
      variation_frequency = all_variations.tally

      # Find elements that appear in more than 50% of successful tests
      threshold = tests.length * 0.5
      common_elements = variation_frequency.select { |variation, count| count >= threshold }

      common_elements
    end

    def calculate_median(array)
      return 0 if array.empty?

      sorted = array.sort
      length = sorted.length

      if length.odd?
        sorted[length / 2]
      else
        (sorted[length / 2 - 1] + sorted[length / 2]) / 2.0
      end
    end

    def extract_preferred_variations(successful_tests)
      variations = successful_tests.flat_map { |test| test[:variations] || [] }
      variations.tally.sort_by(&:last).reverse.take(5).to_h
    end

    def analyze_audience_response(tests)
      response_times = tests.map { |test| test[:response_time] || rand(1..30) }  # Days to significance
      conversion_lifts = tests.map { |test| test[:lift] || 0 }

      {
        average_response_time: response_times.sum.to_f / response_times.length,
        response_volatility: calculate_standard_deviation(conversion_lifts),
        typical_lift_range: {
          min: conversion_lifts.min,
          max: conversion_lifts.max,
          median: calculate_median(conversion_lifts)
        }
      }
    end

    def calculate_confidence_score(wins, total)
      return 0 if total == 0

      win_rate = wins.to_f / total

      # Confidence based on sample size and win rate
      sample_confidence = [ total / 10.0, 1.0 ].min  # More tests = higher confidence
      performance_confidence = win_rate

      (sample_confidence * performance_confidence).round(3)
    end

    def generate_variation_recommendation(wins, total, total_lift)
      return "insufficient_data" if total < 3

      win_rate = wins.to_f / total
      avg_lift = total > 0 ? total_lift / total : 0

      if win_rate > 0.7 && avg_lift > 15
        "highly_recommended"
      elsif win_rate > 0.5 && avg_lift > 10
        "recommended"
      elsif win_rate > 0.3
        "consider_with_caution"
      else
        "not_recommended"
      end
    end

    def calculate_variation_confidence(wins, total)
      return "low" if total < 5

      win_rate = wins.to_f / total

      case win_rate
      when 0.8..1.0 then "very_high"
      when 0.6..0.79 then "high"
      when 0.4..0.59 then "medium"
      when 0.2..0.39 then "low"
      else "very_low"
      end
    end

    def identify_recommended_contexts(tests, is_successful)
      contexts = {
        industries: tests.map { |test| test[:industry] }.uniq.compact,
        campaign_types: tests.map { |test| test[:campaign_type] }.uniq.compact,
        audience_segments: tests.map { |test| test[:audience_segment] }.uniq.compact
      }

      if is_successful
        contexts[:recommendation] = "Use in similar contexts for best results"
      else
        contexts[:recommendation] = "Avoid in these contexts"
      end

      contexts
    end

    def calculate_standard_deviation(array)
      return 0 if array.empty?

      mean = array.sum.to_f / array.length
      variance = array.sum { |value| (value - mean) ** 2 } / array.length
      Math.sqrt(variance).round(2)
    end
  end
end
