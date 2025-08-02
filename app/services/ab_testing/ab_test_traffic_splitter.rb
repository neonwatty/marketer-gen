module AbTesting
  class AbTestTrafficSplitter
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def configure_traffic_splitting(splitting_config)
      begin
        validate_splitting_config(splitting_config)

        allocation_strategy = splitting_config[:allocation_strategy] || "equal_split"
        variants = splitting_config[:variants] || []
        adjustment_rules = splitting_config[:adjustment_rules] || {}

        # Create traffic allocation configuration
        traffic_config = create_traffic_configuration(allocation_strategy, variants, adjustment_rules)

        # Apply the configuration to the test
        apply_traffic_configuration(traffic_config)

        # Store configuration for future adjustments
        store_traffic_configuration(traffic_config)

        {
          success: true,
          variant_allocations: traffic_config[:variant_allocations],
          allocation_strategy: allocation_strategy,
          adaptive_allocation_enabled: traffic_config[:adaptive_enabled],
          adjustment_rules: adjustment_rules
        }
      rescue => e
        {
          success: false,
          error: e.message
        }
      end
    end

    def validate_traffic_allocation(allocation_config)
      errors = []

      # Check total allocation sums to 100%
      total_allocation = allocation_config.sum { |config| config[:traffic_percentage] || 0 }
      unless (99.0..101.0).cover?(total_allocation)
        errors << "Total traffic allocation must sum to 100% (currently #{total_allocation}%)"
      end

      # Check individual allocations are valid
      allocation_config.each do |config|
        traffic_pct = config[:traffic_percentage] || 0
        if traffic_pct < 0 || traffic_pct > 100
          errors << "Traffic percentage for #{config[:variant_id]} must be between 0 and 100%"
        end

        if config[:max_traffic] && traffic_pct > config[:max_traffic]
          errors << "Traffic percentage for #{config[:variant_id]} exceeds maximum allowed (#{config[:max_traffic]}%)"
        end

        if config[:min_traffic] && traffic_pct < config[:min_traffic]
          errors << "Traffic percentage for #{config[:variant_id]} below minimum required (#{config[:min_traffic]}%)"
        end
      end

      {
        valid: errors.empty?,
        errors: errors
      }
    end

    def update_traffic_distribution(new_distribution)
      begin
        # Validate new distribution
        validation = validate_traffic_allocation(new_distribution)
        unless validation[:valid]
          return {
            success: false,
            errors: validation[:errors]
          }
        end

        # Apply new distribution to variants
        new_distribution.each do |config|
          variant = find_variant_by_id(config[:variant_id])
          next unless variant

          variant.update!(traffic_percentage: config[:traffic_percentage])
        end

        # Log the change
        log_traffic_distribution_change(new_distribution)

        {
          success: true,
          updated_allocation: get_current_allocation,
          message: "Traffic distribution updated successfully"
        }
      rescue => e
        {
          success: false,
          error: e.message
        }
      end
    end

    def get_current_allocation
      @ab_test.ab_test_variants.map do |variant|
        {
          variant_id: variant.id,
          variant_name: variant.name,
          traffic_percentage: variant.traffic_percentage,
          is_control: variant.is_control?,
          current_visitors: variant.total_visitors,
          current_conversions: variant.conversions
        }
      end
    end

    private

    def validate_splitting_config(config)
      unless config[:variants] && config[:variants].any?
        raise ArgumentError, "Must specify at least one variant"
      end

      # Validate allocation strategy
      valid_strategies = %w[equal_split weighted_performance manual_allocation bandit_allocation]
      strategy = config[:allocation_strategy]
      unless valid_strategies.include?(strategy)
        raise ArgumentError, "Invalid allocation strategy: #{strategy}"
      end

      # Validate variant configurations
      total_initial_traffic = config[:variants].sum { |v| v[:initial_traffic] || 0 }
      unless (99.0..101.0).cover?(total_initial_traffic)
        raise ArgumentError, "Initial traffic allocations must sum to 100%"
      end
    end

    def create_traffic_configuration(strategy, variants, adjustment_rules)
      case strategy
      when "equal_split"
        create_equal_split_config(variants, adjustment_rules)
      when "weighted_performance"
        create_weighted_performance_config(variants, adjustment_rules)
      when "manual_allocation"
        create_manual_allocation_config(variants, adjustment_rules)
      when "bandit_allocation"
        create_bandit_allocation_config(variants, adjustment_rules)
      else
        raise ArgumentError, "Unknown allocation strategy: #{strategy}"
      end
    end

    def create_equal_split_config(variants, adjustment_rules)
      variant_count = variants.length
      equal_percentage = (100.0 / variant_count).round(2)

      variant_allocations = variants.map.with_index do |variant, index|
        # Handle rounding by giving remainder to first variants
        percentage = equal_percentage
        if index < (100.0 % variant_count)
          percentage += 0.01
        end

        {
          variant_id: variant[:variant_id],
          traffic_percentage: percentage,
          min_traffic: variant[:min_traffic] || 5.0,
          max_traffic: variant[:max_traffic] || 100.0,
          allocation_reason: "equal_split"
        }
      end

      {
        strategy: "equal_split",
        variant_allocations: variant_allocations,
        adaptive_enabled: false,
        adjustment_rules: adjustment_rules
      }
    end

    def create_weighted_performance_config(variants, adjustment_rules)
      # Start with equal split, then adjust based on performance data
      base_config = create_equal_split_config(variants, adjustment_rules)

      # If we have performance data, adjust allocations
      if has_performance_data?
        variant_allocations = adjust_for_performance(base_config[:variant_allocations])
      else
        variant_allocations = base_config[:variant_allocations]
      end

      {
        strategy: "weighted_performance",
        variant_allocations: variant_allocations,
        adaptive_enabled: true,
        adjustment_rules: adjustment_rules
      }
    end

    def create_manual_allocation_config(variants, adjustment_rules)
      variant_allocations = variants.map do |variant|
        {
          variant_id: variant[:variant_id],
          traffic_percentage: variant[:initial_traffic],
          min_traffic: variant[:min_traffic] || 0.0,
          max_traffic: variant[:max_traffic] || 100.0,
          allocation_reason: "manual_specification"
        }
      end

      {
        strategy: "manual_allocation",
        variant_allocations: variant_allocations,
        adaptive_enabled: false,
        adjustment_rules: adjustment_rules
      }
    end

    def create_bandit_allocation_config(variants, adjustment_rules)
      # Multi-armed bandit approach - start conservative, then explore/exploit
      exploration_percentage = 20.0  # Reserve 20% for exploration
      exploitation_percentage = 80.0  # 80% for exploitation

      # Initial equal exploration phase
      exploration_per_variant = exploration_percentage / variants.length

      variant_allocations = variants.map do |variant|
        {
          variant_id: variant[:variant_id],
          traffic_percentage: exploration_per_variant + (exploitation_percentage / variants.length),
          min_traffic: variant[:min_traffic] || 5.0,
          max_traffic: variant[:max_traffic] || 70.0,
          exploration_allocation: exploration_per_variant,
          exploitation_allocation: exploitation_percentage / variants.length,
          allocation_reason: "bandit_initial"
        }
      end

      {
        strategy: "bandit_allocation",
        variant_allocations: variant_allocations,
        adaptive_enabled: true,
        adjustment_rules: adjustment_rules.merge(
          bandit_parameters: {
            exploration_rate: 0.1,
            confidence_threshold: 0.8,
            adjustment_frequency: "hourly"
          }
        )
      }
    end

    def has_performance_data?
      @ab_test.ab_test_variants.any? { |v| v.total_visitors > 0 }
    end

    def adjust_for_performance(base_allocations)
      # Get performance data for each variant
      performance_data = calculate_performance_scores

      # Adjust allocations based on performance
      total_performance_score = performance_data.values.sum
      return base_allocations if total_performance_score == 0

      base_allocations.map do |allocation|
        variant_id = allocation[:variant_id]
        performance_score = performance_data[variant_id] || 0

        # Calculate performance-weighted allocation
        performance_weight = performance_score / total_performance_score
        performance_adjusted_traffic = 100.0 * performance_weight

        # Blend with base allocation (70% performance, 30% base)
        blended_traffic = (performance_adjusted_traffic * 0.7) + (allocation[:traffic_percentage] * 0.3)

        # Respect min/max constraints
        final_traffic = [
          [ blended_traffic, allocation[:min_traffic] ].max,
          allocation[:max_traffic]
        ].min

        allocation.merge(
          traffic_percentage: final_traffic.round(2),
          allocation_reason: "performance_weighted",
          performance_score: performance_score
        )
      end
    end

    def calculate_performance_scores
      scores = {}

      @ab_test.ab_test_variants.each do |variant|
        # Composite performance score based on multiple factors
        conversion_score = variant.conversion_rate || 0
        confidence_score = variant.confidence_interval || 0
        sample_size_score = [ variant.total_visitors / 1000.0, 1.0 ].min  # Normalize to 0-1

        # Weighted composite score
        composite_score = (conversion_score * 0.6) + (confidence_score * 0.3) + (sample_size_score * 0.1)
        scores[variant.id] = composite_score
      end

      scores
    end

    def apply_traffic_configuration(config)
      config[:variant_allocations].each do |allocation|
        variant = find_variant_by_id(allocation[:variant_id])
        next unless variant

        variant.update!(
          traffic_percentage: allocation[:traffic_percentage],
          metadata: variant.metadata.merge(
            allocation_reason: allocation[:allocation_reason],
            min_traffic: allocation[:min_traffic],
            max_traffic: allocation[:max_traffic],
            last_allocation_update: Time.current
          )
        )
      end
    end

    def store_traffic_configuration(config)
      @ab_test.ab_test_configurations.create!(
        configuration_type: "traffic_allocation",
        settings: config,
        is_active: true
      )
    end

    def find_variant_by_id(variant_id)
      @ab_test.ab_test_variants.find_by(id: variant_id)
    end

    def log_traffic_distribution_change(new_distribution)
      change_log = {
        timestamp: Time.current,
        old_distribution: get_current_allocation,
        new_distribution: new_distribution,
        change_reason: "manual_update"
      }

      # Store in test metadata
      @ab_test.update!(
        metadata: @ab_test.metadata.merge(
          traffic_change_history: (@ab_test.metadata["traffic_change_history"] || []) + [ change_log ]
        )
      )
    end
  end
end
