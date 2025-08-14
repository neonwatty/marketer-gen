class JourneyTemplate < ApplicationRecord
  CAMPAIGN_TYPES = %w[awareness consideration conversion retention upsell_cross_sell].freeze

  validates :name, presence: true, length: { maximum: 255 }, uniqueness: true
  validates :description, length: { maximum: 1000 }
  validates :campaign_type, presence: true, inclusion: { in: CAMPAIGN_TYPES }
  validates :template_data, presence: true

  serialize :template_data, coder: JSON

  scope :for_campaign_type, ->(type) { where(campaign_type: type) }
  scope :default_templates, -> { where(is_default: true) }
  scope :custom_templates, -> { where(is_default: false) }

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
      stages: journey_data['stages'],
      metadata: journey_data['metadata'] || {}
    }.merge(journey_attributes.except(:steps))

    journey = user.journeys.build(journey_params)
    
    if journey.save
      create_steps_for_journey(journey, journey_data['steps'] || [])
    end
    
    journey
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
      next unless step_data['title'].present? && step_data['step_type'].present?
      
      journey.journey_steps.create!(
        title: step_data['title'],
        description: step_data['description'],
        step_type: step_data['step_type'],
        content: step_data['content'],
        channel: step_data['channel'],
        sequence_order: index,
        settings: step_data['settings'] || {}
      )
    end
  end
end
