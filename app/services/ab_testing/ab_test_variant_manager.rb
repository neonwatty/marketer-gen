module AbTesting
  class AbTestVariantManager
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def create_variant(variant_params)
      begin
        validate_variant_params(variant_params)

        # Check traffic allocation doesn't exceed 100%
        if would_exceed_traffic_limit?(variant_params[:traffic_percentage])
          return {
            success: false,
            error: "Traffic allocation would exceed 100%",
            current_allocation: current_traffic_allocation
          }
        end

        variant = @ab_test.ab_test_variants.build(variant_params)

        if variant.save
          # Adjust other variant traffic if needed
          adjust_traffic_allocation_for_new_variant(variant)

          {
            success: true,
            variant_id: variant.id,
            variant: variant.attributes,
            message: "Variant '#{variant.name}' created successfully"
          }
        else
          {
            success: false,
            errors: variant.errors.full_messages
          }
        end
      rescue => e
        {
          success: false,
          error: e.message
        }
      end
    end

    def update_variant(variant_id, update_params)
      variant = find_variant(variant_id)
      return variant_not_found_error unless variant

      begin
        # Validate traffic percentage changes
        if update_params[:traffic_percentage]
          new_total = calculate_new_traffic_total(variant, update_params[:traffic_percentage])
          if new_total > 100.1  # Allow small rounding tolerance
            return {
              success: false,
              error: "Traffic allocation would exceed 100%",
              current_allocation: current_traffic_allocation
            }
          end
        end

        old_attributes = variant.attributes.dup

        if variant.update(update_params)
          # Log the change
          log_variant_change(variant, old_attributes, update_params)

          {
            success: true,
            variant_id: variant.id,
            variant: variant.reload.attributes,
            changes_made: calculate_changes(old_attributes, variant.attributes),
            message: "Variant '#{variant.name}' updated successfully"
          }
        else
          {
            success: false,
            errors: variant.errors.full_messages
          }
        end
      rescue => e
        {
          success: false,
          error: e.message
        }
      end
    end

    def pause_variant(variant_id, reason = nil)
      variant = find_variant(variant_id)
      return variant_not_found_error unless variant

      # Cannot pause if it's the only active variant
      active_variants = @ab_test.ab_test_variants.where.not(id: variant_id)
      if active_variants.empty?
        return {
          success: false,
          error: "Cannot pause the only remaining variant"
        }
      end

      begin
        old_traffic = variant.traffic_percentage
        variant.update!(
          traffic_percentage: 0.0,
          metadata: variant.metadata.merge(
            paused_at: Time.current,
            pause_reason: reason,
            original_traffic_percentage: old_traffic
          )
        )

        # Redistribute traffic to other variants
        redistribute_traffic_from_paused_variant(variant, old_traffic)

        {
          success: true,
          variant_id: variant.id,
          message: "Variant '#{variant.name}' paused successfully",
          reason: reason,
          redistributed_traffic: old_traffic
        }
      rescue => e
        {
          success: false,
          error: e.message
        }
      end
    end

    def resume_variant(variant_id)
      variant = find_variant(variant_id)
      return variant_not_found_error unless variant

      # Check if variant was previously paused
      unless variant.metadata["paused_at"]
        return {
          success: false,
          error: "Variant was not paused"
        }
      end

      begin
        original_traffic = variant.metadata["original_traffic_percentage"] || 25.0

        # Check if we can restore original traffic
        if can_restore_traffic?(original_traffic)
          restore_traffic = original_traffic
        else
          # Calculate maximum possible traffic
          restore_traffic = calculate_maximum_restorable_traffic
        end

        # Reduce other variants' traffic proportionally
        reduce_other_variants_traffic(variant, restore_traffic)

        variant.update!(
          traffic_percentage: restore_traffic,
          metadata: variant.metadata.merge(
            resumed_at: Time.current,
            paused_at: nil,
            pause_reason: nil
          )
        )

        {
          success: true,
          variant_id: variant.id,
          message: "Variant '#{variant.name}' resumed successfully",
          restored_traffic_percentage: restore_traffic
        }
      rescue => e
        {
          success: false,
          error: e.message
        }
      end
    end

    def archive_variant(variant_id, reason = nil)
      variant = find_variant(variant_id)
      return variant_not_found_error unless variant

      # Cannot archive control variant
      if variant.is_control?
        return {
          success: false,
          error: "Cannot archive control variant"
        }
      end

      # Must have at least 2 variants after archiving
      active_variants = @ab_test.ab_test_variants.where.not(id: variant_id)
      if active_variants.count < 1
        return {
          success: false,
          error: "Must have at least one other variant before archiving"
        }
      end

      begin
        old_traffic = variant.traffic_percentage

        variant.update!(
          traffic_percentage: 0.0,
          metadata: variant.metadata.merge(
            archived_at: Time.current,
            archive_reason: reason,
            final_metrics: capture_final_metrics(variant)
          )
        )

        # Redistribute traffic to remaining variants
        redistribute_traffic_from_archived_variant(variant, old_traffic)

        {
          success: true,
          variant_id: variant.id,
          message: "Variant '#{variant.name}' archived successfully",
          reason: reason,
          final_metrics: variant.metadata["final_metrics"]
        }
      rescue => e
        {
          success: false,
          error: e.message
        }
      end
    end

    def get_variant_status(variant_id)
      variant = find_variant(variant_id)
      return variant_not_found_error unless variant

      status = "active"

      if variant.traffic_percentage == 0.0
        if variant.metadata["archived_at"]
          status = "archived"
        elsif variant.metadata["paused_at"]
          status = "paused"
        else
          status = "inactive"
        end
      end

      {
        success: true,
        variant_id: variant.id,
        status: status,
        traffic_percentage: variant.traffic_percentage,
        is_control: variant.is_control?,
        performance_summary: variant.performance_summary,
        metadata: variant.metadata
      }
    end

    private

    def find_variant(variant_id)
      @ab_test.ab_test_variants.find_by(id: variant_id)
    end

    def variant_not_found_error
      {
        success: false,
        error: "Variant not found"
      }
    end

    def validate_variant_params(params)
      required_fields = [ :name, :traffic_percentage ]
      missing_fields = required_fields - params.keys

      if missing_fields.any?
        raise ArgumentError, "Missing required fields: #{missing_fields.join(', ')}"
      end

      if params[:traffic_percentage] <= 0 || params[:traffic_percentage] > 100
        raise ArgumentError, "Traffic percentage must be between 0 and 100"
      end

      if params[:is_control] && @ab_test.ab_test_variants.where(is_control: true).exists?
        raise ArgumentError, "Test already has a control variant"
      end
    end

    def would_exceed_traffic_limit?(new_traffic_percentage)
      current_total = @ab_test.ab_test_variants.sum(:traffic_percentage)
      (current_total + new_traffic_percentage) > 100.1  # Allow small rounding tolerance
    end

    def current_traffic_allocation
      @ab_test.ab_test_variants.pluck(:name, :traffic_percentage).to_h
    end

    def adjust_traffic_allocation_for_new_variant(new_variant)
      # If this is the first variant, it gets 100% traffic
      return if @ab_test.ab_test_variants.count == 1

      # Redistribute traffic evenly among all variants
      total_variants = @ab_test.ab_test_variants.count
      equal_percentage = (100.0 / total_variants).round(1)

      @ab_test.ab_test_variants.update_all(traffic_percentage: equal_percentage)

      # Handle rounding by giving the remainder to the first variant
      remainder = 100.0 - (equal_percentage * total_variants)
      if remainder > 0
        first_variant = @ab_test.ab_test_variants.first
        first_variant.update(traffic_percentage: first_variant.traffic_percentage + remainder)
      end
    end

    def calculate_new_traffic_total(variant_being_updated, new_traffic_percentage)
      current_total = @ab_test.ab_test_variants.where.not(id: variant_being_updated.id).sum(:traffic_percentage)
      current_total + new_traffic_percentage
    end

    def log_variant_change(variant, old_attributes, changes)
      change_log = {
        timestamp: Time.current,
        user_id: nil, # Would be set from current user context
        changes: calculate_changes(old_attributes, variant.attributes),
        reason: changes[:change_reason] || "Manual update"
      }

      variant.update(
        metadata: variant.metadata.merge(
          change_history: (variant.metadata["change_history"] || []) + [ change_log ]
        )
      )
    end

    def calculate_changes(old_attrs, new_attrs)
      changes = {}

      %w[name traffic_percentage variant_type].each do |attr|
        if old_attrs[attr] != new_attrs[attr]
          changes[attr] = {
            from: old_attrs[attr],
            to: new_attrs[attr]
          }
        end
      end

      changes
    end

    def redistribute_traffic_from_paused_variant(paused_variant, traffic_to_redistribute)
      active_variants = @ab_test.ab_test_variants.where.not(id: paused_variant.id)
      return if active_variants.empty?

      # Distribute proportionally based on current traffic allocation
      total_active_traffic = active_variants.sum(:traffic_percentage)

      active_variants.each do |variant|
        if total_active_traffic > 0
          proportion = variant.traffic_percentage / total_active_traffic
          additional_traffic = traffic_to_redistribute * proportion
          variant.update!(traffic_percentage: variant.traffic_percentage + additional_traffic)
        else
          # Equal distribution if no traffic currently allocated
          equal_share = traffic_to_redistribute / active_variants.count
          variant.update!(traffic_percentage: variant.traffic_percentage + equal_share)
        end
      end
    end

    def can_restore_traffic?(desired_traffic)
      other_variants_traffic = @ab_test.ab_test_variants.sum(:traffic_percentage)
      (other_variants_traffic + desired_traffic) <= 100.1
    end

    def calculate_maximum_restorable_traffic
      other_variants_traffic = @ab_test.ab_test_variants.sum(:traffic_percentage)
      [ 100.0 - other_variants_traffic, 0 ].max
    end

    def reduce_other_variants_traffic(resuming_variant, traffic_needed)
      other_variants = @ab_test.ab_test_variants.where.not(id: resuming_variant.id)
      total_other_traffic = other_variants.sum(:traffic_percentage)

      return if total_other_traffic == 0

      # Reduce proportionally
      reduction_factor = traffic_needed / total_other_traffic

      other_variants.each do |variant|
        reduction = variant.traffic_percentage * reduction_factor
        new_traffic = [ variant.traffic_percentage - reduction, 0 ].max
        variant.update!(traffic_percentage: new_traffic)
      end
    end

    def redistribute_traffic_from_archived_variant(archived_variant, traffic_to_redistribute)
      redistribute_traffic_from_paused_variant(archived_variant, traffic_to_redistribute)
    end

    def capture_final_metrics(variant)
      {
        final_traffic_percentage: variant.traffic_percentage,
        total_visitors: variant.total_visitors,
        conversions: variant.conversions,
        conversion_rate: variant.conversion_rate,
        confidence_interval: variant.confidence_interval,
        lift_vs_control: variant.lift_vs_control,
        significance_vs_control: variant.significance_vs_control,
        captured_at: Time.current
      }
    end
  end
end
