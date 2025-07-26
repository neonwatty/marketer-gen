class JourneyTemplate < ApplicationRecord
  has_many :journeys
  
  CATEGORIES = %w[
    b2b
    b2c
    ecommerce
    saas
    nonprofit
    education
    healthcare
    financial_services
    real_estate
    hospitality
  ].freeze
  
  DIFFICULTY_LEVELS = %w[beginner intermediate advanced].freeze
  
  validates :name, presence: true, uniqueness: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :campaign_type, inclusion: { in: Journey::CAMPAIGN_TYPES }, allow_blank: true
  validates :difficulty_level, inclusion: { in: DIFFICULTY_LEVELS }, allow_blank: true
  validates :estimated_duration_days, numericality: { greater_than: 0 }, allow_blank: true
  
  scope :active, -> { where(is_active: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_campaign_type, ->(type) { where(campaign_type: type) }
  scope :popular, -> { order(usage_count: :desc) }
  scope :recent, -> { order(created_at: :desc) }
  
  def create_journey_for_user(user, journey_params = {})
    journey = user.journeys.build(
      name: journey_params[:name] || "#{name} - #{Date.current}",
      description: journey_params[:description] || description,
      campaign_type: campaign_type,
      target_audience: journey_params[:target_audience],
      goals: journey_params[:goals],
      brand_id: journey_params[:brand_id],
      metadata: {
        template_id: id,
        template_name: name,
        created_from_template: true
      }
    )
    
    if journey.save
      create_steps_for_journey(journey)
      increment!(:usage_count)
      journey
    else
      journey
    end
  end
  
  def preview_steps
    template_data['steps'] || []
  end
  
  def step_count
    preview_steps.size
  end
  
  def stages_covered
    preview_steps.map { |step| step['stage'] }.uniq
  end
  
  def channels_used
    preview_steps.map { |step| step['channel'] }.uniq.compact
  end
  
  def content_types_included
    preview_steps.map { |step| step['content_type'] }.uniq.compact
  end
  
  private
  
  def create_steps_for_journey(journey)
    return unless template_data['steps'].present?
    
    step_mapping = {}
    
    # First pass: create all steps
    template_data['steps'].each_with_index do |step_data, index|
      step = journey.journey_steps.create!(
        name: step_data['name'],
        description: step_data['description'],
        stage: step_data['stage'],
        position: index,
        content_type: step_data['content_type'],
        channel: step_data['channel'],
        duration_days: step_data['duration_days'] || 1,
        config: step_data['config'] || {},
        conditions: step_data['conditions'] || {},
        metadata: step_data['metadata'] || {},
        is_entry_point: step_data['is_entry_point'] || (index == 0),
        is_exit_point: step_data['is_exit_point'] || false
      )
      
      step_mapping[step_data['id']] = step if step_data['id']
    end
    
    # Second pass: create transitions
    template_data['transitions']&.each do |transition_data|
      from_step = step_mapping[transition_data['from_step_id']]
      to_step = step_mapping[transition_data['to_step_id']]
      
      if from_step && to_step
        StepTransition.create!(
          from_step: from_step,
          to_step: to_step,
          transition_type: transition_data['transition_type'] || 'sequential',
          conditions: transition_data['conditions'] || {},
          priority: transition_data['priority'] || 0,
          metadata: transition_data['metadata'] || {}
        )
      end
    end
  end
end
