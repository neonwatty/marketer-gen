module LlmIntegration
  class ContentOptimizationResult < ApplicationRecord
    self.table_name = "content_optimization_results"

    # Constants
    OPTIMIZATION_TYPES = %i[
      quality_improvement brand_alignment performance_optimization
      audience_targeting readability_enhancement seo_optimization
    ].freeze

    # Associations
    belongs_to :original_content, class_name: "LlmIntegration::GeneratedContent"
    belongs_to :brand, optional: true

    # Validations
    validates :optimized_content, presence: true
    validates :optimization_type, presence: true, inclusion: {
      in: OPTIMIZATION_TYPES.map(&:to_s),
      message: "%{value} is not a valid optimization type"
    }
    validates :optimization_strategy, presence: true
    validates :performance_improvement, presence: true
    validates :applied_techniques, presence: true
    validates :optimization_time, presence: true,
              numericality: { greater_than: 0 }
    validates :human_approved, inclusion: { in: [ true, false ] }
    validate :performance_improvement_structure

    # Serialization
    serialize :performance_improvement, coder: JSON
    serialize :applied_techniques, coder: JSON

    # Enums
    enum optimization_type: OPTIMIZATION_TYPES.each_with_object({}) { |type, hash| hash[type] = type.to_s }

    # Scopes
    scope :approved, -> { where(human_approved: true) }
    scope :pending_approval, -> { where(human_approved: false) }
    scope :by_type, ->(type) { where(optimization_type: type) }
    scope :with_positive_improvement, -> { where("(performance_improvement->>'quality_score_delta')::float > 0") }
    scope :recent, -> { order(created_at: :desc) }

    # Instance methods
    def quality_improvement
      performance_improvement.dig("quality_score_delta") || 0.0
    end

    def brand_compliance_improvement
      performance_improvement.dig("brand_compliance_delta") || 0.0
    end

    def engagement_lift
      performance_improvement.dig("predicted_engagement_lift") || 0.0
    end

    def overall_improvement_score
      (quality_improvement * 0.4) +
      (brand_compliance_improvement * 0.4) +
      (engagement_lift * 0.2)
    end

    def improvement_percentage
      (overall_improvement_score * 100).round(2)
    end

    def optimization_summary
      {
        type: optimization_type,
        strategy: optimization_strategy,
        techniques: applied_techniques,
        quality_delta: quality_improvement,
        compliance_delta: brand_compliance_improvement,
        engagement_lift: engagement_lift,
        overall_score: overall_improvement_score,
        time_taken: optimization_time,
        approved: human_approved
      }
    end

    def word_count_change
      original_words = original_content.content.split.length
      optimized_words = optimized_content.split.length
      optimized_words - original_words
    end

    def character_count_change
      optimized_content.length - original_content.content.length
    end

    def readability_improvement
      # Calculate readability improvement (placeholder for actual implementation)
      performance_improvement.dig("readability_score_delta") || 0.0
    end

    def seo_improvement
      # Calculate SEO improvement (placeholder for actual implementation)
      performance_improvement.dig("seo_score_delta") || 0.0
    end

    def approve!(approver = nil)
      update!(
        human_approved: true,
        approved_at: Time.current,
        approved_by: approver&.id
      )
    end

    def reject!(reason = nil)
      update!(
        human_approved: false,
        rejected_at: Time.current,
        rejection_reason: reason
      )
    end

    def is_significant_improvement?
      overall_improvement_score >= 0.1 # 10% improvement threshold
    end

    def technique_effectiveness
      return {} unless applied_techniques.any?

      # This would typically be calculated based on historical data
      # For now, return placeholder data
      applied_techniques.each_with_object({}) do |technique, hash|
        hash[technique] = {
          usage_count: 1,
          avg_improvement: overall_improvement_score,
          success_rate: human_approved ? 100.0 : 0.0
        }
      end
    end

    def optimization_cost
      # Calculate the cost of optimization based on time and resources
      base_cost_per_minute = 0.10 # $0.10 per minute
      optimization_time * base_cost_per_minute
    end

    def roi_estimate
      return 0.0 unless engagement_lift > 0

      # Estimate ROI based on engagement lift and typical conversion rates
      estimated_additional_conversions = engagement_lift * 1000 # Assuming 1000 impressions
      estimated_revenue = estimated_additional_conversions * 5.0 # $5 per conversion
      optimization_cost_total = optimization_cost

      return 0.0 if optimization_cost_total.zero?

      ((estimated_revenue - optimization_cost_total) / optimization_cost_total * 100).round(2)
    end

    def create_variant
      original_content.create_variant(
        content: optimized_content,
        type: optimization_type,
        strategy: optimization_strategy,
        predicted_lift: overall_improvement_score
      )
    end

    private

    def performance_improvement_structure
      return unless performance_improvement.present?

      unless performance_improvement.is_a?(Hash)
        errors.add(:performance_improvement, "must be a hash")
        return
      end

      required_keys = %w[quality_score_delta brand_compliance_delta predicted_engagement_lift]

      required_keys.each do |key|
        unless performance_improvement.key?(key)
          errors.add(:performance_improvement, "must include #{key}")
        end

        value = performance_improvement[key]
        unless value.is_a?(Numeric)
          errors.add(:performance_improvement, "#{key} must be numeric")
        end
      end
    end
  end
end
