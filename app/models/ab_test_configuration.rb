class AbTestConfiguration < ApplicationRecord
  belongs_to :ab_test

  CONFIGURATION_TYPES = %w[
    traffic_allocation statistical_settings early_stopping
    sample_size minimum_effect_size confidence_interval
    bayesian_priors custom_metrics
  ].freeze

  validates :configuration_type, presence: true, inclusion: { in: CONFIGURATION_TYPES }
  validates :settings, presence: true
  validate :validate_configuration_settings

  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(configuration_type: type) }

  def activate!
    # Deactivate other configurations of the same type
    ab_test.ab_test_configurations
           .where(configuration_type: configuration_type)
           .where.not(id: id)
           .update_all(is_active: false)

    update!(is_active: true)
  end

  def deactivate!
    update!(is_active: false)
  end

  def merge_settings(new_settings)
    merged = settings.deep_merge(new_settings.stringify_keys)
    update!(settings: merged)
  end

  def get_setting(key, default = nil)
    settings.dig(*key.to_s.split(".")) || default
  end

  def set_setting(key, value)
    keys = key.to_s.split(".")
    updated_settings = settings.dup

    # Navigate to the nested hash location
    current_level = updated_settings
    keys[0..-2].each do |k|
      current_level[k] ||= {}
      current_level = current_level[k]
    end

    # Set the value
    current_level[keys.last] = value

    update!(settings: updated_settings)
  end

  private

  def validate_configuration_settings
    return unless settings.present?

    case configuration_type
    when "traffic_allocation"
      validate_traffic_allocation_settings
    when "statistical_settings"
      validate_statistical_settings
    when "early_stopping"
      validate_early_stopping_settings
    when "sample_size"
      validate_sample_size_settings
    end
  end

  def validate_traffic_allocation_settings
    unless settings["allocation_strategy"].present?
      errors.add(:settings, "must include allocation_strategy")
    end

    if settings["variants"].present?
      total_percentage = settings["variants"].sum { |v| v["traffic_percentage"] || 0 }
      unless (99.0..101.0).cover?(total_percentage)
        errors.add(:settings, "variant traffic percentages must sum to 100%")
      end
    end
  end

  def validate_statistical_settings
    unless settings["confidence_level"].present? &&
           settings["confidence_level"].between?(50, 99.9)
      errors.add(:settings, "confidence_level must be between 50 and 99.9")
    end

    unless settings["significance_threshold"].present? &&
           settings["significance_threshold"].between?(0.1, 20)
      errors.add(:settings, "significance_threshold must be between 0.1 and 20")
    end
  end

  def validate_early_stopping_settings
    unless settings["alpha_spending_function"].present?
      errors.add(:settings, "must include alpha_spending_function")
    end

    unless settings["minimum_sample_size"].present? &&
           settings["minimum_sample_size"] > 0
      errors.add(:settings, "minimum_sample_size must be positive")
    end
  end

  def validate_sample_size_settings
    unless settings["target_sample_size"].present? &&
           settings["target_sample_size"] > 0
      errors.add(:settings, "target_sample_size must be positive")
    end

    unless settings["power"].present? &&
           settings["power"].between?(0.5, 0.99)
      errors.add(:settings, "power must be between 0.5 and 0.99")
    end
  end
end
