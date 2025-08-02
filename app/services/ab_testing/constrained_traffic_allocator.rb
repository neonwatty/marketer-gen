module AbTesting
  class ConstrainedTrafficAllocator
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def apply_constraints(current_allocation, desired_allocation, constraints)
      begin
        # Validate inputs
        validate_constraints(constraints)
        validate_allocations(current_allocation, desired_allocation)

        # Apply constraints step by step
        constrained_allocation = apply_all_constraints(current_allocation, desired_allocation, constraints)

        # Ensure final allocation sums to 100%
        final_allocation = normalize_allocation(constrained_allocation)

        # Calculate constraint violations
        violations = calculate_constraint_violations(desired_allocation, final_allocation, constraints)

        {
          success: true,
          final_allocation: final_allocation,
          constraint_violations: violations,
          adjustments_made: calculate_adjustments_made(desired_allocation, final_allocation),
          total_adjustment_magnitude: calculate_total_adjustment_magnitude(desired_allocation, final_allocation)
        }
      rescue => e
        {
          success: false,
          error: e.message
        }
      end
    end

    def validate_constraints(constraints)
      errors = []

      # Validate constraint ranges
      if constraints[:min_traffic_per_variant] && constraints[:max_traffic_per_variant]
        if constraints[:min_traffic_per_variant] > constraints[:max_traffic_per_variant]
          errors << "Minimum traffic per variant cannot exceed maximum"
        end
      end

      # Validate control constraints
      if constraints[:control_min_traffic] && constraints[:control_min_traffic] > 100
        errors << "Control minimum traffic cannot exceed 100%"
      end

      # Validate total traffic cap
      if constraints[:total_test_traffic_cap] && constraints[:total_test_traffic_cap] > 100
        errors << "Total test traffic cap cannot exceed 100%"
      end

      # Validate adjustment rate limit
      if constraints[:adjustment_rate_limit] && constraints[:adjustment_rate_limit] > 50
        errors << "Adjustment rate limit should not exceed 50% per adjustment"
      end

      {
        valid: errors.empty?,
        errors: errors
      }
    end

    def resolve_constraint_conflicts(constraints)
      resolved_constraints = constraints.dup
      conflicts = []

      # Check for mathematical impossibilities
      min_per_variant = constraints[:min_traffic_per_variant] || 0
      max_per_variant = constraints[:max_traffic_per_variant] || 100
      variant_count = @ab_test.ab_test_variants.count

      # If minimum per variant * count > 100, we have a conflict
      if min_per_variant * variant_count > 100
        conflicts << {
          type: "impossible_minimum",
          description: "Minimum traffic per variant (#{min_per_variant}%) × #{variant_count} variants exceeds 100%",
          resolution: "reduce_minimum_per_variant"
        }

        # Resolve by reducing minimum
        resolved_constraints[:min_traffic_per_variant] = (100.0 / variant_count * 0.8).round(1)
      end

      # Check control minimum vs other constraints
      control_min = constraints[:control_min_traffic] || 0
      remaining_traffic = 100 - control_min
      non_control_variants = variant_count - 1

      if non_control_variants > 0 && remaining_traffic < (min_per_variant * non_control_variants)
        conflicts << {
          type: "control_minimum_conflict",
          description: "Control minimum (#{control_min}%) leaves insufficient traffic for other variants",
          resolution: "reduce_control_minimum"
        }

        # Resolve by reducing control minimum
        needed_for_others = min_per_variant * non_control_variants
        resolved_constraints[:control_min_traffic] = [ 100 - needed_for_others - 5, 25 ].max.round(1)  # Leave 5% buffer, min 25%
      end

      # Check total traffic cap feasibility
      traffic_cap = constraints[:total_test_traffic_cap] || 100
      if traffic_cap < (min_per_variant * variant_count)
        conflicts << {
          type: "traffic_cap_too_low",
          description: "Traffic cap (#{traffic_cap}%) is less than minimum required for all variants",
          resolution: "increase_traffic_cap"
        }

        resolved_constraints[:total_test_traffic_cap] = min_per_variant * variant_count + 5
      end

      {
        original_constraints: constraints,
        resolved_constraints: resolved_constraints,
        conflicts_found: conflicts,
        resolution_applied: conflicts.any?
      }
    end

    def get_constraint_violations(current_allocation, constraints)
      violations = []

      current_allocation.each do |variant_id, traffic_percentage|
        variant = find_variant(variant_id)
        next unless variant

        # Check minimum traffic constraint
        min_traffic = constraints[:min_traffic_per_variant] || 0
        if traffic_percentage < min_traffic
          violations << {
            variant_id: variant_id,
            variant_name: variant.name,
            constraint_type: "minimum_traffic",
            current_value: traffic_percentage,
            constraint_value: min_traffic,
            violation_magnitude: min_traffic - traffic_percentage
          }
        end

        # Check maximum traffic constraint
        max_traffic = constraints[:max_traffic_per_variant] || 100
        if traffic_percentage > max_traffic
          violations << {
            variant_id: variant_id,
            variant_name: variant.name,
            constraint_type: "maximum_traffic",
            current_value: traffic_percentage,
            constraint_value: max_traffic,
            violation_magnitude: traffic_percentage - max_traffic
          }
        end

        # Check control minimum constraint
        if variant.is_control? && constraints[:control_min_traffic]
          control_min = constraints[:control_min_traffic]
          if traffic_percentage < control_min
            violations << {
              variant_id: variant_id,
              variant_name: variant.name,
              constraint_type: "control_minimum",
              current_value: traffic_percentage,
              constraint_value: control_min,
              violation_magnitude: control_min - traffic_percentage
            }
          end
        end
      end

      # Check total traffic cap
      total_traffic = current_allocation.values.sum
      if constraints[:total_test_traffic_cap] && total_traffic > constraints[:total_test_traffic_cap]
        violations << {
          constraint_type: "total_traffic_cap",
          current_value: total_traffic,
          constraint_value: constraints[:total_test_traffic_cap],
          violation_magnitude: total_traffic - constraints[:total_test_traffic_cap]
        }
      end

      violations
    end

    private

    def validate_allocations(current_allocation, desired_allocation)
      unless current_allocation.is_a?(Hash) && desired_allocation.is_a?(Hash)
        raise ArgumentError, "Allocations must be hashes with variant_id => percentage"
      end

      # Check that both allocations have the same variants
      current_variants = current_allocation.keys.sort
      desired_variants = desired_allocation.keys.sort

      unless current_variants == desired_variants
        raise ArgumentError, "Current and desired allocations must have the same variants"
      end

      # Check percentage ranges
      [ current_allocation, desired_allocation ].each do |allocation|
        allocation.each do |variant_id, percentage|
          unless (0..100).cover?(percentage)
            raise ArgumentError, "Traffic percentage for variant #{variant_id} must be between 0 and 100"
          end
        end
      end
    end

    def apply_all_constraints(current_allocation, desired_allocation, constraints)
      working_allocation = desired_allocation.dup

      # Step 1: Apply minimum traffic constraints
      working_allocation = apply_minimum_traffic_constraints(working_allocation, constraints)

      # Step 2: Apply maximum traffic constraints
      working_allocation = apply_maximum_traffic_constraints(working_allocation, constraints)

      # Step 3: Apply control-specific constraints
      working_allocation = apply_control_constraints(working_allocation, constraints)

      # Step 4: Apply adjustment rate limits
      working_allocation = apply_adjustment_rate_limits(current_allocation, working_allocation, constraints)

      # Step 5: Apply total traffic cap
      working_allocation = apply_total_traffic_cap(working_allocation, constraints)

      working_allocation
    end

    def apply_minimum_traffic_constraints(allocation, constraints)
      min_traffic = constraints[:min_traffic_per_variant]
      return allocation unless min_traffic

      constrained_allocation = allocation.dup

      constrained_allocation.each do |variant_id, traffic_percentage|
        if traffic_percentage < min_traffic
          constrained_allocation[variant_id] = min_traffic
        end
      end

      constrained_allocation
    end

    def apply_maximum_traffic_constraints(allocation, constraints)
      max_traffic = constraints[:max_traffic_per_variant]
      return allocation unless max_traffic

      constrained_allocation = allocation.dup

      constrained_allocation.each do |variant_id, traffic_percentage|
        if traffic_percentage > max_traffic
          constrained_allocation[variant_id] = max_traffic
        end
      end

      constrained_allocation
    end

    def apply_control_constraints(allocation, constraints)
      control_min = constraints[:control_min_traffic]
      return allocation unless control_min

      constrained_allocation = allocation.dup

      # Find control variant
      control_variant = @ab_test.ab_test_variants.find_by(is_control: true)
      return allocation unless control_variant

      control_traffic = constrained_allocation[control_variant.id] || 0
      if control_traffic < control_min
        constrained_allocation[control_variant.id] = control_min
      end

      constrained_allocation
    end

    def apply_adjustment_rate_limits(current_allocation, desired_allocation, constraints)
      rate_limit = constraints[:adjustment_rate_limit]
      return desired_allocation unless rate_limit

      constrained_allocation = {}

      current_allocation.each do |variant_id, current_traffic|
        desired_traffic = desired_allocation[variant_id] || current_traffic
        change = desired_traffic - current_traffic

        # Limit the change to the rate limit
        if change.abs > rate_limit
          limited_change = change > 0 ? rate_limit : -rate_limit
          constrained_allocation[variant_id] = current_traffic + limited_change
        else
          constrained_allocation[variant_id] = desired_traffic
        end
      end

      constrained_allocation
    end

    def apply_total_traffic_cap(allocation, constraints)
      traffic_cap = constraints[:total_test_traffic_cap]
      return allocation unless traffic_cap

      total_traffic = allocation.values.sum
      return allocation if total_traffic <= traffic_cap

      # Scale down proportionally to meet cap
      scale_factor = traffic_cap / total_traffic
      constrained_allocation = {}

      allocation.each do |variant_id, traffic_percentage|
        constrained_allocation[variant_id] = (traffic_percentage * scale_factor).round(2)
      end

      constrained_allocation
    end

    def normalize_allocation(allocation)
      total = allocation.values.sum
      return allocation if (99.5..100.5).cover?(total)  # Allow small rounding tolerance

      # Scale to exactly 100%
      scale_factor = 100.0 / total
      normalized_allocation = {}

      allocation.each do |variant_id, traffic_percentage|
        normalized_allocation[variant_id] = (traffic_percentage * scale_factor).round(2)
      end

      # Handle any remaining rounding errors
      actual_total = normalized_allocation.values.sum
      if actual_total != 100.0
        # Add/subtract the difference to/from the largest allocation
        largest_variant = normalized_allocation.max_by { |_, percentage| percentage }[0]
        normalized_allocation[largest_variant] += (100.0 - actual_total)
        normalized_allocation[largest_variant] = normalized_allocation[largest_variant].round(2)
      end

      normalized_allocation
    end

    def calculate_constraint_violations(desired_allocation, final_allocation, constraints)
      violations = []

      desired_allocation.each do |variant_id, desired_traffic|
        final_traffic = final_allocation[variant_id]
        difference = (final_traffic - desired_traffic).abs

        if difference > 0.1  # Significant difference
          variant = find_variant(variant_id)

          violations << {
            variant_id: variant_id,
            variant_name: variant&.name || "Unknown",
            desired_traffic: desired_traffic,
            final_traffic: final_traffic,
            adjustment_made: final_traffic - desired_traffic,
            reason: determine_violation_reason(variant_id, desired_traffic, final_traffic, constraints)
          }
        end
      end

      violations
    end

    def calculate_adjustments_made(desired_allocation, final_allocation)
      adjustments = {}

      desired_allocation.each do |variant_id, desired_traffic|
        final_traffic = final_allocation[variant_id]
        adjustment = final_traffic - desired_traffic

        if adjustment.abs > 0.01
          variant = find_variant(variant_id)
          adjustments[variant_id] = {
            variant_name: variant&.name || "Unknown",
            adjustment_amount: adjustment.round(2),
            adjustment_percentage: ((adjustment / desired_traffic) * 100).round(1)
          }
        end
      end

      adjustments
    end

    def calculate_total_adjustment_magnitude(desired_allocation, final_allocation)
      total_magnitude = 0

      desired_allocation.each do |variant_id, desired_traffic|
        final_traffic = final_allocation[variant_id]
        total_magnitude += (final_traffic - desired_traffic).abs
      end

      total_magnitude.round(2)
    end

    def determine_violation_reason(variant_id, desired_traffic, final_traffic, constraints)
      variant = find_variant(variant_id)
      reasons = []

      # Check which constraints likely caused the adjustment
      if final_traffic > desired_traffic
        # Traffic was increased
        min_traffic = constraints[:min_traffic_per_variant]
        control_min = constraints[:control_min_traffic]

        if min_traffic && final_traffic == min_traffic
          reasons << "minimum_traffic_constraint"
        end

        if variant&.is_control? && control_min && final_traffic == control_min
          reasons << "control_minimum_constraint"
        end
      else
        # Traffic was decreased
        max_traffic = constraints[:max_traffic_per_variant]
        rate_limit = constraints[:adjustment_rate_limit]

        if max_traffic && final_traffic == max_traffic
          reasons << "maximum_traffic_constraint"
        end

        if rate_limit && (desired_traffic - final_traffic).abs == rate_limit
          reasons << "adjustment_rate_limit"
        end
      end

      # Check for normalization adjustments
      if reasons.empty?
        reasons << "normalization_adjustment"
      end

      reasons.join(", ")
    end

    def find_variant(variant_id)
      @ab_test.ab_test_variants.find_by(id: variant_id)
    end
  end
end
