class Journey < ApplicationRecord
  belongs_to :user
  has_many :journey_steps, dependent: :destroy
  has_many :touchpoints, dependent: :destroy
  has_many :attribution_models, dependent: :destroy

  CAMPAIGN_TYPES = %w[awareness consideration conversion retention upsell_cross_sell].freeze
  STATUSES = %w[draft active paused completed archived].freeze
  TEMPLATE_TYPES = %w[email social_media content webinar event custom].freeze

  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }
  validates :campaign_type, presence: true, inclusion: { in: CAMPAIGN_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :template_type, inclusion: { in: TEMPLATE_TYPES }, allow_blank: true

  validates :name, uniqueness: { scope: :user_id, message: "already exists for this user" }

  serialize :stages, coder: JSON
  serialize :metadata, coder: JSON

  scope :active, -> { where(status: 'active') }
  scope :by_campaign_type, ->(type) { where(campaign_type: type) }
  scope :by_template_type, ->(type) { where(template_type: type) }

  before_validation :set_default_stages, on: :create

  def active?
    status == 'active'
  end

  def draft?
    status == 'draft'
  end

  def total_steps
    journey_steps.count
  end

  def ordered_steps
    journey_steps.order(:sequence_order)
  end

  def completion_rate
    return 0 if total_steps.zero?
    completed_steps = journey_steps.where(status: 'completed').count
    (completed_steps.to_f / total_steps * 100).round(1)
  end

  def last_activity
    journey_steps.maximum(:updated_at) || updated_at
  end

  def duration_since_creation
    ((Time.current - created_at) / 1.day).round(1)
  end

  def can_be_duplicated?
    true
  end

  def can_be_archived?
    %w[completed draft].include?(status)
  end

  def analytics_summary
    {
      total_steps: total_steps,
      completion_rate: completion_rate,
      last_activity: last_activity,
      duration: duration_since_creation,
      status: status,
      campaign_type: campaign_type,
      template_type: template_type
    }
  end

  private

  def set_default_stages
    self.stages ||= default_stages_for_campaign_type
  end

  def default_stages_for_campaign_type
    case campaign_type
    when 'awareness'
      ['discovery', 'education', 'engagement']
    when 'consideration'
      ['research', 'evaluation', 'comparison']
    when 'conversion'
      ['decision', 'purchase', 'onboarding']
    when 'retention'
      ['usage', 'support', 'renewal']
    when 'upsell_cross_sell'
      ['opportunity_identification', 'presentation', 'closing']
    else
      ['stage_1', 'stage_2', 'stage_3']
    end
  end
end
