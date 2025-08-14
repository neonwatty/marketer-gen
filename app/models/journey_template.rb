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
    updated_data['stages'] = new_stages
    
    # Update step stages to match if they reference old stages
    if updated_data['steps']
      updated_data['steps'].each do |step|
        if step['stage'] && !new_stages.include?(step['stage'])
          # Assign to first stage if current stage doesn't exist
          step['stage'] = new_stages.first
        end
      end
    end
    
    update!(template_data: updated_data)
  end

  def add_step(step_data, position: nil)
    updated_data = template_data.deep_dup
    updated_data['steps'] ||= []
    
    if position && position < updated_data['steps'].length
      updated_data['steps'].insert(position, step_data)
    else
      updated_data['steps'] << step_data
    end
    
    update!(template_data: updated_data)
  end

  def remove_step(step_index)
    updated_data = template_data.deep_dup
    return false unless updated_data['steps'] && step_index < updated_data['steps'].length
    
    updated_data['steps'].delete_at(step_index)
    update!(template_data: updated_data)
  end

  def reorder_steps(new_order)
    updated_data = template_data.deep_dup
    return false unless updated_data['steps'] && new_order.length == updated_data['steps'].length
    
    reordered_steps = new_order.map { |index| updated_data['steps'][index] }
    updated_data['steps'] = reordered_steps
    
    update!(template_data: updated_data)
  end

  def substitute_content_type(from_type, to_type)
    updated_data = template_data.deep_dup
    return false unless updated_data['steps']
    
    updated_data['steps'].each do |step|
      if step.dig('content', 'type') == from_type
        step['content']['type'] = to_type
      end
    end
    
    update!(template_data: updated_data)
  end

  def substitute_channel(from_channel, to_channel)
    updated_data = template_data.deep_dup
    return false unless updated_data['steps']
    
    updated_data['steps'].each do |step|
      if step['channel'] == from_channel
        step['channel'] = to_channel
      end
    end
    
    update!(template_data: updated_data)
  end

  def get_steps_by_stage(stage_name)
    return [] unless template_data['steps']
    
    template_data['steps'].select { |step| step['stage'] == stage_name }
  end

  def get_timeline
    template_data.dig('metadata', 'timeline')
  end

  def get_key_metrics
    template_data.dig('metadata', 'key_metrics') || []
  end

  def get_target_audience
    template_data.dig('metadata', 'target_audience')
  end

  def update_metadata(metadata_updates)
    updated_data = template_data.deep_dup
    updated_data['metadata'] ||= {}
    updated_data['metadata'].merge!(metadata_updates)
    
    update!(template_data: updated_data)
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
