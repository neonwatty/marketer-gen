class AbTestTemplate < ApplicationRecord
  belongs_to :user

  TEMPLATE_TYPES = %w[
    conversion_optimization engagement_boost retention_test
    onboarding_flow checkout_optimization email_campaign
    landing_page_test cta_optimization pricing_test
  ].freeze

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :template_type, presence: true, inclusion: { in: TEMPLATE_TYPES }
  validates :configuration, presence: true
  validate :validate_template_configuration

  scope :by_type, ->(type) { where(template_type: type) }
  scope :recent, -> { order(created_at: :desc) }
  scope :public_templates, -> { where(is_public: true) }

  def apply_to_test(ab_test)
    # Apply template configuration to an existing A/B test
    configuration.each do |config_type, settings|
      ab_test.ab_test_configurations.create!(
        configuration_type: config_type,
        settings: settings,
        is_active: true
      )
    end

    # Apply any metadata settings to the test itself
    if configuration["test_settings"].present?
      ab_test.update!(configuration["test_settings"].slice(
        "confidence_level", "significance_threshold", "minimum_sample_size"
      ))
    end
  end

  def create_test_from_template(campaign, name, control_journey, treatment_journey)
    # Create a new A/B test based on this template
    test = AbTest.create!(
      campaign: campaign,
      user: campaign.user,
      name: name,
      test_type: infer_test_type,
      hypothesis: generate_hypothesis,
      confidence_level: configuration.dig("test_settings", "confidence_level") || 95.0,
      significance_threshold: configuration.dig("test_settings", "significance_threshold") || 5.0
    )

    # Create variants based on template
    create_variants_from_template(test, control_journey, treatment_journey)

    # Apply configurations
    apply_to_test(test)

    test
  end

  def preview_configuration
    {
      template_name: name,
      template_type: template_type,
      estimated_duration: calculate_estimated_duration,
      required_sample_size: calculate_required_sample_size,
      key_metrics: extract_key_metrics,
      traffic_allocation: extract_traffic_allocation,
      statistical_settings: extract_statistical_settings
    }
  end

  def clone_for_user(target_user, new_name = nil)
    cloned_template = self.class.create!(
      user: target_user,
      name: new_name || "#{name} (Copy)",
      description: description,
      template_type: template_type,
      configuration: configuration.deep_dup
    )

    cloned_template
  end

  private

  def validate_template_configuration
    return unless configuration.present?

    # Ensure configuration has required sections
    required_sections = %w[test_settings variant_configuration metrics_tracking]
    missing_sections = required_sections - configuration.keys

    if missing_sections.any?
      errors.add(:configuration, "missing required sections: #{missing_sections.join(', ')}")
    end

    # Validate test settings
    if configuration["test_settings"].present?
      test_settings = configuration["test_settings"]

      if test_settings["confidence_level"] &&
         !test_settings["confidence_level"].between?(50, 99.9)
        errors.add(:configuration, "confidence_level must be between 50 and 99.9")
      end

      if test_settings["significance_threshold"] &&
         !test_settings["significance_threshold"].between?(0.1, 20)
        errors.add(:configuration, "significance_threshold must be between 0.1 and 20")
      end
    end

    # Validate variant configuration
    if configuration["variant_configuration"].present?
      variants = configuration["variant_configuration"]["variants"] || []
      if variants.empty?
        errors.add(:configuration, "must specify at least one variant configuration")
      end

      total_traffic = variants.sum { |v| v["traffic_percentage"] || 0 }
      unless (99.0..101.0).cover?(total_traffic)
        errors.add(:configuration, "variant traffic percentages must sum to 100%")
      end
    end
  end

  def infer_test_type
    case template_type
    when "conversion_optimization", "checkout_optimization", "cta_optimization"
      "conversion"
    when "engagement_boost"
      "engagement"
    when "retention_test"
      "retention"
    else
      "conversion"
    end
  end

  def generate_hypothesis
    base_hypothesis = configuration.dig("test_settings", "hypothesis")
    return base_hypothesis if base_hypothesis.present?

    case template_type
    when "conversion_optimization"
      "Treatment variant will increase conversion rate by at least 10%"
    when "engagement_boost"
      "Treatment variant will increase user engagement by at least 15%"
    when "retention_test"
      "Treatment variant will improve user retention by at least 20%"
    else
      "Treatment variant will outperform control variant"
    end
  end

  def create_variants_from_template(test, control_journey, treatment_journey)
    variant_config = configuration["variant_configuration"]["variants"]

    # Create control variant
    control_config = variant_config.find { |v| v["is_control"] } || variant_config.first
    test.ab_test_variants.create!(
      journey: control_journey,
      name: control_config["name"] || "Control",
      is_control: true,
      traffic_percentage: control_config["traffic_percentage"] || 50.0,
      variant_type: "control"
    )

    # Create treatment variants
    treatment_configs = variant_config.select { |v| !v["is_control"] }
    treatment_configs.each_with_index do |config, index|
      test.ab_test_variants.create!(
        journey: treatment_journey,
        name: config["name"] || "Treatment #{index + 1}",
        is_control: false,
        traffic_percentage: config["traffic_percentage"] || 50.0,
        variant_type: "treatment"
      )
    end
  end

  def calculate_estimated_duration
    sample_size = calculate_required_sample_size
    daily_traffic = configuration.dig("test_settings", "expected_daily_traffic") || 1000

    (sample_size / daily_traffic).ceil
  end

  def calculate_required_sample_size
    baseline_rate = configuration.dig("test_settings", "baseline_conversion_rate") || 0.05
    minimum_effect = configuration.dig("test_settings", "minimum_detectable_effect") || 0.20
    power = configuration.dig("test_settings", "statistical_power") || 0.8
    alpha = (100 - (configuration.dig("test_settings", "confidence_level") || 95)) / 100.0

    # Simplified sample size calculation
    # In practice, would use more sophisticated statistical methods
    effect_size = baseline_rate * minimum_effect
    estimated_sample_size = (2 * (1.96 + 0.84)**2 * baseline_rate * (1 - baseline_rate)) / (effect_size**2)

    estimated_sample_size.round
  end

  def extract_key_metrics
    configuration.dig("metrics_tracking", "primary_metrics") || [ "conversion_rate" ]
  end

  def extract_traffic_allocation
    variant_config = configuration.dig("variant_configuration", "variants") || []
    variant_config.map { |v| { name: v["name"], traffic_percentage: v["traffic_percentage"] } }
  end

  def extract_statistical_settings
    configuration["test_settings"]&.slice(
      "confidence_level", "significance_threshold", "statistical_power"
    ) || {}
  end
end
