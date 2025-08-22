class JourneyTemplate < ApplicationRecord
  CAMPAIGN_TYPES = %w[awareness consideration conversion retention upsell_cross_sell].freeze
  CATEGORIES = %w[acquisition retention engagement conversion lifecycle nurturing].freeze
  INDUSTRIES = %w[technology healthcare finance retail ecommerce saas b2b b2c manufacturing education nonprofit general].freeze
  COMPLEXITY_LEVELS = %w[beginner intermediate advanced expert].freeze

  validates :name, presence: true, length: { maximum: 255 }, uniqueness: true
  validates :description, length: { maximum: 1000 }
  validates :campaign_type, presence: true, inclusion: { in: CAMPAIGN_TYPES }
  validates :template_data, presence: true
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validates :industry, inclusion: { in: INDUSTRIES }, allow_blank: true
  validates :complexity_level, inclusion: { in: COMPLEXITY_LEVELS }, allow_blank: true
  validates :prerequisites, length: { maximum: 2000 }

  serialize :template_data, coder: JSON

  scope :for_campaign_type, ->(type) { where(campaign_type: type) }
  scope :default_templates, -> { where(is_default: true) }
  scope :custom_templates, -> { where(is_default: false) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_industry, ->(industry) { where(industry: industry) }
  scope :by_complexity, ->(level) { where(complexity_level: level) }
  scope :for_beginner, -> { where(complexity_level: "beginner") }
  scope :for_advanced, -> { where(complexity_level: [ "advanced", "expert" ]) }
  scope :with_prerequisites, -> { where.not(prerequisites: [ nil, "" ]) }
  scope :without_prerequisites, -> { where(prerequisites: [ nil, "" ]) }

  validate :only_one_default_per_campaign_type

  def self.default_for_campaign_type(campaign_type)
    for_campaign_type(campaign_type).default_templates.first
  end

  def create_journey_for_user(user, journey_attributes = {})
    journey_data = template_data.deep_dup

    journey_params = {
      name: journey_attributes[:name] || "#{name} Journey",
      description: journey_attributes[:description] || description,
      campaign_type: campaign_type,
      template_type: journey_attributes[:template_type],
      stages: journey_data["stages"],
      metadata: journey_data["metadata"] || {}
    }.merge(journey_attributes.except(:steps))

    journey = user.journeys.build(journey_params)

    if journey.save
      create_steps_for_journey(journey, journey_data["steps"] || [])
    end

    journey
  end

  # Template customization methods
  def clone_template(new_name:, campaign_type: nil, is_default: false)
    cloned_data = template_data.deep_dup

    self.class.create!(
      name: new_name,
      description: description,
      campaign_type: campaign_type || self.campaign_type,
      template_data: cloned_data,
      is_default: is_default
    )
  end

  def customize_stages(new_stages)
    updated_data = template_data.deep_dup
    updated_data["stages"] = new_stages

    # Update step stages to match if they reference old stages
    if updated_data["steps"]
      updated_data["steps"].each do |step|
        if step["stage"] && !new_stages.include?(step["stage"])
          # Assign to first stage if current stage doesn't exist
          step["stage"] = new_stages.first
        end
      end
    end

    update!(template_data: updated_data)
  end

  def add_step(step_data, position: nil)
    updated_data = template_data.deep_dup
    updated_data["steps"] ||= []

    if position && position < updated_data["steps"].length
      updated_data["steps"].insert(position, step_data)
    else
      updated_data["steps"] << step_data
    end

    update!(template_data: updated_data)
  end

  def remove_step(step_index)
    updated_data = template_data.deep_dup
    return false unless updated_data["steps"] && step_index < updated_data["steps"].length

    updated_data["steps"].delete_at(step_index)
    update!(template_data: updated_data)
  end

  def reorder_steps(new_order)
    updated_data = template_data.deep_dup
    return false unless updated_data["steps"] && new_order.length == updated_data["steps"].length

    reordered_steps = new_order.map { |index| updated_data["steps"][index] }
    updated_data["steps"] = reordered_steps

    update!(template_data: updated_data)
  end

  def substitute_content_type(from_type, to_type)
    updated_data = template_data.deep_dup
    return false unless updated_data["steps"]

    updated_data["steps"].each do |step|
      if step.dig("content", "type") == from_type
        step["content"]["type"] = to_type
      end
    end

    update!(template_data: updated_data)
  end

  def substitute_channel(from_channel, to_channel)
    updated_data = template_data.deep_dup
    return false unless updated_data["steps"]

    updated_data["steps"].each do |step|
      if step["channel"] == from_channel
        step["channel"] = to_channel
      end
    end

    update!(template_data: updated_data)
  end

  def get_steps_by_stage(stage_name)
    return [] unless template_data["steps"]

    template_data["steps"].select { |step| step["stage"] == stage_name }
  end

  def get_timeline
    template_data.dig("metadata", "timeline")
  end

  def get_key_metrics
    template_data.dig("metadata", "key_metrics") || []
  end

  def get_target_audience
    template_data.dig("metadata", "target_audience")
  end

  def update_metadata(metadata_updates)
    updated_data = template_data.deep_dup
    updated_data["metadata"] ||= {}
    updated_data["metadata"].merge!(metadata_updates)

    update!(template_data: updated_data)
  end

  # Template filtering and search methods
  def self.filter_by_criteria(criteria = {})
    scope = all
    scope = scope.by_category(criteria[:category]) if criteria[:category].present?
    scope = scope.by_industry(criteria[:industry]) if criteria[:industry].present?
    scope = scope.by_complexity(criteria[:complexity_level]) if criteria[:complexity_level].present?
    scope = scope.for_campaign_type(criteria[:campaign_type]) if criteria[:campaign_type].present?
    scope = scope.with_prerequisites if criteria[:has_prerequisites] == true
    scope = scope.without_prerequisites if criteria[:has_prerequisites] == false
    scope
  end

  def self.search_by_metadata(query)
    return all if query.blank?

    where(
      "LOWER(name) LIKE LOWER(?) OR LOWER(description) LIKE LOWER(?) OR LOWER(prerequisites) LIKE LOWER(?)",
      "%#{query}%", "%#{query}%", "%#{query}%"
    )
  end

  def self.recommended_for_user(user_skill_level: "beginner", industry: nil, campaign_type: nil)
    scope = all
    scope = scope.by_complexity(user_skill_level) if user_skill_level.present?
    scope = scope.by_industry(industry) if industry.present?
    scope = scope.for_campaign_type(campaign_type) if campaign_type.present?
    scope.limit(10)
  end

  # Metadata summary methods
  def metadata_summary
    {
      category: category,
      industry: industry,
      complexity_level: complexity_level,
      has_prerequisites: prerequisites.present?,
      prerequisites_count: prerequisites.present? ? prerequisites.split(/[,\n]/).length : 0
    }
  end

  def suitable_for_beginner?
    complexity_level == "beginner" && prerequisites.blank?
  end

  def requires_prerequisites?
    prerequisites.present?
  end

  private

  def only_one_default_per_campaign_type
    if is_default? && self.class.where(campaign_type: campaign_type, is_default: true)
                              .where.not(id: id).exists?
      errors.add(:is_default, "can only have one default template per campaign type")
    end
  end

  def create_steps_for_journey(journey, steps_data)
    steps_data.each_with_index do |step_data, index|
      # Skip invalid step data gracefully
      next unless step_data["title"].present? && step_data["step_type"].present?

      journey.journey_steps.create!(
        title: step_data["title"],
        description: step_data["description"],
        step_type: step_data["step_type"],
        content: step_data["content"],
        channel: step_data["channel"],
        sequence_order: index,
        settings: step_data["settings"] || {}
      )
    end
  end
end
