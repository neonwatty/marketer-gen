module LlmIntegration
  class LlmProvider < ApplicationRecord
    self.table_name = "llm_providers"

    # Validations
    validates :name, presence: true, uniqueness: true
    validates :provider_type, presence: true, inclusion: {
      in: %w[openai anthropic cohere huggingface],
      message: "is not included in the list"
    }
    validates :api_endpoint, presence: true, format: URI::DEFAULT_PARSER.make_regexp
    validates :supported_models, presence: true
    validates :rate_limits, presence: true
    validate :rate_limits_structure
    validates :active, inclusion: { in: [ true, false ] }

    # Serialization
    serialize :supported_models, coder: JSON
    serialize :rate_limits, coder: JSON

    # Scopes
    scope :active, -> { where(active: true) }
    scope :by_type, ->(type) { where(provider_type: type) }

    # Instance methods
    def supports_model?(model_name)
      supported_models.include?(model_name)
    end

    def within_rate_limits?(current_usage)
      return true unless rate_limits.present?

      rate_limits.all? do |limit_type, limit_value|
        current_usage.fetch(limit_type, 0) < limit_value
      end
    end

    def display_name
      name.titleize
    end

    private

    def rate_limits_structure
      return unless rate_limits.present?

      required_keys = %w[requests_per_minute]

      unless rate_limits.is_a?(Hash)
        errors.add(:rate_limits, "must be a hash")
        return
      end

      required_keys.each do |key|
        unless rate_limits.key?(key)
          errors.add(:rate_limits, "must include #{key}")
          return
        end

        value = rate_limits[key]
        unless value.is_a?(Numeric) && value > 0
          errors.add(:rate_limits, "#{key} must be positive")
        end
      end
    end
  end
end
