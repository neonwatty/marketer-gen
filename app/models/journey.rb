class Journey < ApplicationRecord
  # Associations
  belongs_to :campaign
  has_many :journey_stages, -> { order(:position) }, dependent: :destroy
  has_many :content_assets, as: :assetable, dependent: :destroy
  
  # Through associations
  has_one :brand_identity, through: :campaign

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :template_type, inclusion: { in: %w[lead_nurturing customer_retention product_launch brand_awareness sales_enablement], allow_blank: true }
  validates :purpose, length: { maximum: 500 }
  validates :goals, length: { maximum: 1000 }
  validates :timing, length: { maximum: 500 }
  validates :audience, length: { maximum: 1000 }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_template_type, ->(type) { where(template_type: type) }
  scope :ordered, -> { order(:position, :created_at) }
  scope :by_campaign, ->(campaign) { where(campaign: campaign) }

  # Stage Management Methods
  def add_stage(stage_attributes)
    stage_attributes = stage_attributes.merge(position: next_stage_position)
    journey_stages.create(stage_attributes)
  end

  def reorder_stages(stage_ids)
    return false unless stage_ids.is_a?(Array)
    
    stage_ids.each_with_index do |stage_id, index|
      journey_stages.find_by(id: stage_id)&.update(position: index)
    end
    
    true
  end

  def next_stage_position
    (journey_stages.maximum(:position) || -1) + 1
  end

  def stage_count
    journey_stages.count
  end

  def stages_by_type
    journey_stages.group(:stage_type).count
  end

  def total_duration_days
    journey_stages.where.not(duration_days: nil).sum(:duration_days)
  end

  def completion_percentage
    return 0 if stage_count.zero?
    
    completed_stages = journey_stages.where(status: ['completed', 'published']).count
    (completed_stages.to_f / stage_count * 100).round(1)
  end

  # Template Methods
  def from_template?
    template_type.present?
  end

  def template_name
    template_type&.humanize
  end

  # Status Methods
  def activate!
    update!(is_active: true)
  end

  def deactivate!
    update!(is_active: false)
  end

  def draft?
    journey_stages.where.not(status: 'draft').empty?
  end

  def published?
    journey_stages.where(status: 'published').any?
  end

  def status_summary
    stages_by_status = journey_stages.group(:status).count
    {
      total: stage_count,
      draft: stages_by_status['draft'] || 0,
      in_progress: stages_by_status['in_progress'] || 0,
      completed: stages_by_status['completed'] || 0,
      published: stages_by_status['published'] || 0
    }
  end

  private

  def set_defaults
    self.position ||= 0
    self.is_active = true if is_active.nil?
  end
end
