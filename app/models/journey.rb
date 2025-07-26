class Journey < ApplicationRecord
  belongs_to :user
  has_many :journey_steps, dependent: :destroy
  has_many :step_transitions, through: :journey_steps
  
  STATUSES = %w[draft published archived].freeze
  CAMPAIGN_TYPES = %w[
    product_launch
    brand_awareness
    lead_generation
    customer_retention
    seasonal_promotion
    content_marketing
    email_nurture
    social_media
    event_promotion
    custom
  ].freeze
  
  STAGES = %w[awareness consideration conversion retention advocacy].freeze
  
  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :campaign_type, inclusion: { in: CAMPAIGN_TYPES }, allow_blank: true
  
  scope :draft, -> { where(status: 'draft') }
  scope :published, -> { where(status: 'published') }
  scope :archived, -> { where(status: 'archived') }
  scope :active, -> { where(status: %w[draft published]) }
  
  def publish!
    update!(status: 'published', published_at: Time.current)
  end
  
  def archive!
    update!(status: 'archived', archived_at: Time.current)
  end
  
  def duplicate
    dup.tap do |new_journey|
      new_journey.name = "#{name} (Copy)"
      new_journey.status = 'draft'
      new_journey.published_at = nil
      new_journey.archived_at = nil
      new_journey.save!
      
      journey_steps.each do |step|
        new_step = step.dup
        new_step.journey = new_journey
        new_step.save!
      end
    end
  end
  
  def total_steps
    journey_steps.count
  end
  
  def steps_by_stage
    journey_steps.group(:stage).count
  end
  
  def to_json_export
    {
      name: name,
      description: description,
      campaign_type: campaign_type,
      target_audience: target_audience,
      goals: goals,
      metadata: metadata,
      settings: settings,
      steps: journey_steps.includes(:transitions_from, :transitions_to).map(&:to_json_export)
    }
  end
end
