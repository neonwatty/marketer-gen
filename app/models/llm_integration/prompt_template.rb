module LlmIntegration
  class PromptTemplate < ApplicationRecord
    self.table_name = "prompt_templates"

    # Associations
    belongs_to :brand, optional: true
    has_many :content_generation_requests, foreign_key: :prompt_template_id

    # Validations
    validates :name, presence: true, uniqueness: { scope: :brand_id }
    validates :content_type, presence: true, inclusion: {
      in: ContentGenerationRequest::CONTENT_TYPES.map(&:to_s),
      message: "%{value} is not a valid content type"
    }
    validates :template_content, presence: true
    validates :variables, presence: true
    validates :performance_rating, presence: true,
              numericality: {
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 5,
                message: "must be between 0 and 5"
              }
    validates :usage_count, presence: true,
              numericality: { greater_than_or_equal_to: 0 }
    validates :active, inclusion: { in: [ true, false ] }
    validate :variables_structure_valid
    validate :template_content_references_variables

    # Serialization
    serialize :variables, coder: JSON
    serialize :performance_metrics, coder: JSON

    # Scopes
    scope :active, -> { where(active: true) }
    scope :for_brand, ->(brand) { where(brand: brand) }
    scope :by_content_type, ->(type) { where(content_type: type) }
    scope :by_category, ->(category) { where(category: category) }
    scope :high_performance, -> { where("performance_rating >= ?", 4.0) }
    scope :frequently_used, -> { where("usage_count > ?", 10) }
    scope :recent, -> { order(created_at: :desc) }

    # Callbacks
    before_validation :set_defaults, on: :create
    after_update :track_performance_changes

    # Class methods
    def self.top_performing(limit = 5)
      active.order(performance_rating: :desc).limit(limit)
    end

    def self.for_content_type(content_type, brand = nil)
      scope = by_content_type(content_type).active
      scope = scope.for_brand(brand) if brand
      scope.order(performance_rating: :desc)
    end

    # Instance methods
    def render(prompt_variables = {})
      rendered = template_content.dup

      # Validate that all required variables are provided
      missing_vars = required_variables - prompt_variables.keys.map(&:to_s)
      if missing_vars.any?
        raise ArgumentError, "Missing required variables: #{missing_vars.join(', ')}"
      end

      # Replace variables in template
      prompt_variables.each do |key, value|
        rendered.gsub!("{{#{key}}}", value.to_s)
      end

      rendered
    end

    def required_variables
      variables.select { |_, config| config["required"] }.keys
    end

    def optional_variables
      variables.reject { |_, config| config["required"] }.keys
    end

    def variable_config(variable_name)
      variables[variable_name.to_s] || {}
    end

    def increment_usage!
      increment!(:usage_count)
      update_performance_metrics
    end

    def update_performance_rating(new_rating)
      old_rating = performance_rating
      update!(performance_rating: new_rating)

      # Track rating history
      performance_metrics["rating_history"] ||= []
      performance_metrics["rating_history"] << {
        old_rating: old_rating,
        new_rating: new_rating,
        updated_at: Time.current.iso8601
      }

      save!
    end

    def add_performance_data(data)
      performance_metrics.merge!(data)
      save!
    end

    def average_content_quality
      performance_metrics.dig("content_quality", "average") || 0.0
    end

    def average_brand_compliance
      performance_metrics.dig("brand_compliance", "average") || 0.0
    end

    def success_rate
      total_uses = performance_metrics.dig("usage_stats", "total") || 0
      successful_uses = performance_metrics.dig("usage_stats", "successful") || 0

      return 0.0 if total_uses.zero?
      (successful_uses.to_f / total_uses * 100).round(2)
    end

    def clone_for_brand(target_brand)
      cloned = self.dup
      cloned.brand = target_brand
      cloned.name = "#{name} (Copy)"
      cloned.usage_count = 0
      cloned.performance_rating = 0.0
      cloned.performance_metrics = {}
      cloned.save!
      cloned
    end

    def is_brand_specific?
      brand_id.present?
    end

    def is_global?
      brand_id.nil?
    end

    private

    def set_defaults
      self.usage_count ||= 0
      self.performance_rating ||= 0.0
      self.active = true if active.nil?
      self.performance_metrics ||= {}
    end

    def variables_structure_valid
      return unless variables.present?

      unless variables.is_a?(Hash)
        errors.add(:variables, "must be a hash")
        return
      end

      variables.each do |var_name, config|
        unless config.is_a?(Hash)
          errors.add(:variables, "#{var_name} configuration must be a hash")
          next
        end

        unless config.key?("type")
          errors.add(:variables, "must define type for each variable")
        end

        unless %w[string number boolean array object].include?(config["type"])
          errors.add(:variables, "#{var_name} has invalid type: #{config['type']}")
        end
      end
    end

    def template_content_references_variables
      return unless template_content.present? && variables.present?

      # Extract variable references from template
      template_vars = template_content.scan(/\{\{(\w+)\}\}/).flatten.uniq
      defined_vars = variables.keys

      # Check if all referenced variables are defined
      undefined_vars = template_vars - defined_vars
      if undefined_vars.any?
        errors.add(:template_content, "references undefined variables: #{undefined_vars.join(', ')}")
      end

      # Check if all required variables are referenced
      required_vars = required_variables
      unreferenced_required = required_vars - template_vars
      if unreferenced_required.any?
        errors.add(:template_content, "must reference all defined variables")
      end
    end

    def track_performance_changes
      if saved_change_to_performance_rating?
        performance_metrics["last_rating_update"] = Time.current.iso8601
        save! if changed?
      end
    end

    def update_performance_metrics
      performance_metrics["usage_stats"] ||= {}
      performance_metrics["usage_stats"]["total"] = usage_count
      performance_metrics["last_used"] = Time.current.iso8601
      save!
    end
  end
end
