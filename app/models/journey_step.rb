class JourneyStep < ApplicationRecord
  belongs_to :journey
  has_many :transitions_from, class_name: 'StepTransition', foreign_key: 'from_step_id', dependent: :destroy
  has_many :transitions_to, class_name: 'StepTransition', foreign_key: 'to_step_id', dependent: :destroy
  has_many :next_steps, through: :transitions_from, source: :to_step
  has_many :previous_steps, through: :transitions_to, source: :from_step
  
  STEP_TYPES = %w[
    blog_post
    email_sequence
    social_media
    lead_magnet
    webinar
    case_study
    sales_call
    demo
    trial_offer
    onboarding
    newsletter
    feedback_survey
  ].freeze
  
  CONTENT_TYPES = %w[
    email
    blog_post
    social_post
    landing_page
    video
    webinar
    ebook
    case_study
    whitepaper
    infographic
    podcast
    advertisement
    survey
    demo
    consultation
  ].freeze
  
  CHANNELS = %w[
    email
    website
    facebook
    instagram
    twitter
    linkedin
    youtube
    google_ads
    display_ads
    sms
    push_notification
    direct_mail
    event
    sales_call
  ].freeze
  
  validates :name, presence: true
  validates :stage, inclusion: { in: Journey::STAGES }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :content_type, inclusion: { in: CONTENT_TYPES }, allow_blank: true
  validates :channel, inclusion: { in: CHANNELS }, allow_blank: true
  validates :duration_days, numericality: { greater_than: 0 }, allow_blank: true
  
  scope :by_position, -> { order(:position) }
  scope :by_stage, ->(stage) { where(stage: stage) }
  scope :entry_points, -> { where(is_entry_point: true) }
  scope :exit_points, -> { where(is_exit_point: true) }
  
  before_create :set_position
  after_destroy :reorder_positions
  
  def move_to_position(new_position)
    return if new_position == position
    
    transaction do
      if new_position < position
        journey.journey_steps
          .where(position: new_position...position)
          .update_all('position = position + 1')
      else
        journey.journey_steps
          .where(position: (position + 1)..new_position)
          .update_all('position = position - 1')
      end
      
      update!(position: new_position)
    end
  end
  
  def add_transition_to(to_step, conditions = {})
    transition_type = conditions.present? ? 'conditional' : 'sequential'
    transitions_from.create!(
      to_step: to_step,
      conditions: conditions,
      transition_type: transition_type
    )
  end
  
  def remove_transition_to(to_step)
    transitions_from.where(to_step: to_step).destroy_all
  end
  
  def can_transition_to?(step)
    next_steps.include?(step)
  end
  
  def evaluate_conditions(context = {})
    return true if conditions.blank?
    
    conditions.all? do |key, value|
      case key
      when 'min_engagement_score'
        context['engagement_score'].to_i >= value.to_i
      when 'completed_action'
        context['completed_actions']&.include?(value)
      when 'time_since_last_action'
        context['time_since_last_action'].to_i >= value.to_i
      else
        true
      end
    end
  end
  
  def to_json_export
    {
      name: name,
      description: description,
      stage: stage,
      position: position,
      content_type: content_type,
      channel: channel,
      duration_days: duration_days,
      config: config,
      conditions: conditions,
      metadata: metadata,
      is_entry_point: is_entry_point,
      is_exit_point: is_exit_point,
      transitions: transitions_from.map { |t| { to: t.to_step.name, conditions: t.conditions } }
    }
  end
  
  private
  
  def set_position
    if position.nil? || position == 0
      max_position = journey.journey_steps.where.not(id: id).maximum(:position) || -1
      self.position = max_position + 1
    end
  end
  
  def reorder_positions
    journey.journey_steps.where('position > ?', position).update_all('position = position - 1')
  end
end
