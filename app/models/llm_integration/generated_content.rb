module LlmIntegration
  class GeneratedContent < ApplicationRecord
    self.table_name = "generated_contents"

    # Associations
    belongs_to :brand
    belongs_to :content_generation_request, optional: true
    has_many :content_variants, dependent: :destroy, foreign_key: :base_content_id
    has_many :content_performance_metrics, dependent: :destroy
    has_many :content_optimization_results, foreign_key: :original_content_id, dependent: :destroy

    # Validations
    validates :content, presence: true
    validates :provider_used, presence: true, inclusion: {
      in: %w[openai anthropic cohere huggingface],
      message: "%{value} is not a valid provider"
    }
    validates :model_used, presence: true
    validates :tokens_used, presence: true, numericality: { greater_than: 0 }
    validates :generation_time, presence: true, numericality: { greater_than: 0 }
    validates :brand_compliance_score, presence: true,
              numericality: {
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 1,
                message: "must be between 0 and 1"
              }
    validates :quality_score, presence: true,
              numericality: {
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 1,
                message: "must be between 0 and 1"
              }
    validate :metadata_is_valid_json

    # Serialization
    serialize :metadata, coder: JSON

    # Scopes
    scope :for_brand, ->(brand) { where(brand: brand) }
    scope :high_compliance, -> { where("brand_compliance_score >= ?", 0.9) }
    scope :high_quality, -> { where("quality_score >= ?", 0.8) }
    scope :by_provider, ->(provider) { where(provider_used: provider) }
    scope :recent, -> { order(created_at: :desc) }

    # Callbacks
    before_save :calculate_derived_metrics
    after_create :trigger_performance_tracking

    # Instance methods
    def compliance_grade
      case brand_compliance_score
      when 0.95..1.0 then "A+"
      when 0.90..0.94 then "A"
      when 0.85..0.89 then "B+"
      when 0.80..0.84 then "B"
      when 0.75..0.79 then "C+"
      when 0.70..0.74 then "C"
      else "D"
      end
    end

    def quality_grade
      case quality_score
      when 0.95..1.0 then "A+"
      when 0.90..0.94 then "A"
      when 0.85..0.89 then "B+"
      when 0.80..0.84 then "B"
      when 0.75..0.79 then "C+"
      when 0.70..0.74 then "C"
      else "D"
      end
    end

    def overall_score
      (brand_compliance_score * 0.6) + (quality_score * 0.4)
    end

    def word_count
      content.split.length
    end

    def character_count
      content.length
    end

    def estimated_cost
      # Rough estimation based on tokens and provider
      case provider_used.to_sym
      when :openai
        (tokens_used / 1000.0) * 0.03 # $0.03 per 1K tokens (approximate)
      when :anthropic
        (tokens_used / 1000.0) * 0.015 # Claude pricing
      when :cohere
        (tokens_used / 1000.0) * 0.002 # Cohere pricing
      when :huggingface
        0.0 # Often free tier available
      else
        0.0
      end
    end

    def has_variants?
      content_variants.exists?
    end

    def performance_summary
      return {} unless content_performance_metrics.exists?

      metrics = content_performance_metrics.group(:metric_type).average(:metric_value)
      {
        avg_engagement: metrics["engagement_rate"] || 0,
        avg_conversion: metrics["conversion_rate"] || 0,
        total_impressions: content_performance_metrics.sum(:sample_size)
      }
    end

    def create_variant(options = {})
      content_variants.create!(
        variant_content: options[:content],
        variant_type: options[:type] || :optimization,
        optimization_strategy: options[:strategy],
        predicted_performance_lift: options[:predicted_lift] || 0
      )
    end

    private

    def metadata_is_valid_json
      return unless metadata.present?

      unless metadata.is_a?(Hash)
        errors.add(:metadata, "must be valid JSON")
      end
    rescue JSON::ParserError
      errors.add(:metadata, "must be valid JSON")
    end

    def calculate_derived_metrics
      # Calculate any derived metrics from content
      self.word_count_cache = word_count
      self.character_count_cache = character_count

      # Set content hash for duplicate detection
      self.content_hash = Digest::SHA256.hexdigest(content.strip.downcase)
    end

    def trigger_performance_tracking
      # Trigger async performance tracking job
      ContentPerformanceTrackingJob.perform_later(self) if defined?(ContentPerformanceTrackingJob)
    end
  end
end
