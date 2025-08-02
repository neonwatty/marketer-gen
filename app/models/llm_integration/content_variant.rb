module LlmIntegration
  class ContentVariant < ApplicationRecord
    self.table_name = "content_variants"

    # Constants
    VARIANT_TYPES = %i[
      headline_optimization tone_adjustment length_optimization
      cta_optimization style_variation audience_targeting
    ].freeze

    # Associations
    belongs_to :base_content, class_name: "LlmIntegration::GeneratedContent"
    has_many :content_performance_metrics, as: :content, dependent: :destroy

    # Validations
    validates :variant_content, presence: true
    validates :variant_type, presence: true, inclusion: {
      in: VARIANT_TYPES.map(&:to_s),
      message: "%{value} is not a valid variant type"
    }
    validates :optimization_strategy, presence: true
    validates :predicted_performance_lift, presence: true,
              numericality: {
                greater_than_or_equal_to: -1,
                less_than_or_equal_to: 1,
                message: "must be between -1 and 1"
              }
    validates :variant_letter, presence: true, format: { with: /\A[A-Z]\z/ }
    validates :ab_test_id, uniqueness: { scope: :variant_letter }, allow_blank: true

    # Enums
    enum variant_type: VARIANT_TYPES.each_with_object({}) { |type, hash| hash[type] = type.to_s }

    # Scopes
    scope :for_base_content, ->(content) { where(base_content: content) }
    scope :by_type, ->(type) { where(variant_type: type) }
    scope :with_positive_lift, -> { where("predicted_performance_lift > 0") }
    scope :ab_test_ready, -> { where.not(ab_test_id: nil) }

    # Callbacks
    before_validation :assign_variant_letter, on: :create
    after_create :setup_ab_test_tracking

    # Instance methods
    def performance_lift_percentage
      (predicted_performance_lift * 100).round(2)
    end

    def is_control_variant?
      variant_letter == "A"
    end

    def brand_compliance_score
      # Calculate compliance score for variant content
      return @brand_compliance_score if defined?(@brand_compliance_score)

      compliance_service = LlmIntegration::BrandComplianceChecker.new
      @brand_compliance_score = compliance_service.check_compliance(
        variant_content,
        base_content.brand
      )[:overall_score]
    end

    def quality_score
      # Calculate quality score for variant content
      return @quality_score if defined?(@quality_score)

      quality_service = LlmIntegration::ContentQualityAnalyzer.new
      @quality_score = quality_service.analyze_quality(variant_content)[:overall_score]
    end

    def word_count
      variant_content.split.length
    end

    def character_count
      variant_content.length
    end

    def optimization_details
      {
        strategy: optimization_strategy,
        type: variant_type,
        predicted_lift: predicted_performance_lift,
        word_count_change: word_count - base_content.word_count,
        character_count_change: character_count - base_content.character_count
      }
    end

    def performance_comparison
      return {} unless content_performance_metrics.exists?

      base_metrics = base_content.performance_summary
      variant_metrics = content_performance_metrics.group(:metric_type).average(:metric_value)

      comparison = {}
      variant_metrics.each do |metric_type, value|
        base_value = base_metrics[metric_type.to_sym] || 0
        lift = base_value > 0 ? ((value - base_value) / base_value) : 0
        comparison[metric_type] = {
          base: base_value,
          variant: value,
          lift: lift,
          lift_percentage: (lift * 100).round(2)
        }
      end

      comparison
    end

    def create_ab_test(test_params = {})
      return ab_test_id if ab_test_id.present?

      test_id = "test_#{SecureRandom.alphanumeric(8)}"

      update!(
        ab_test_id: test_id,
        ab_test_start_date: test_params[:start_date] || Time.current,
        ab_test_end_date: test_params[:end_date] || 30.days.from_now
      )

      test_id
    end

    private

    def assign_variant_letter
      return if variant_letter.present?

      existing_variants = base_content.content_variants.pluck(:variant_letter)

      # Start with 'B' since 'A' is typically the control (original content)
      next_letter = ("B".."Z").find { |letter| !existing_variants.include?(letter) }

      self.variant_letter = next_letter || "Z"
    end

    def setup_ab_test_tracking
      # Setup tracking for A/B test if needed
      return unless ab_test_id.present?

      AbTestTrackingJob.perform_later(self) if defined?(AbTestTrackingJob)
    end
  end
end
