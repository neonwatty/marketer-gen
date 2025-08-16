class CampaignPlan < ApplicationRecord
  belongs_to :user
  
  CAMPAIGN_TYPES = %w[product_launch brand_awareness lead_generation customer_retention sales_promotion event_marketing].freeze
  OBJECTIVES = %w[brand_awareness lead_generation customer_acquisition customer_retention sales_growth market_expansion].freeze
  STATUSES = %w[draft generating completed failed archived].freeze
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :user_id, message: "already exists for this user" }
  validates :description, length: { maximum: 2000 }
  validates :campaign_type, presence: true, inclusion: { in: CAMPAIGN_TYPES }
  validates :objective, presence: true, inclusion: { in: OBJECTIVES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :target_audience, length: { maximum: 1000 }
  validates :budget_constraints, length: { maximum: 1000 }
  validates :timeline_constraints, length: { maximum: 1000 }
  
  serialize :metadata, coder: JSON
  serialize :generated_strategy, coder: JSON
  serialize :generated_timeline, coder: JSON
  serialize :generated_assets, coder: JSON
  
  scope :by_campaign_type, ->(type) { where(campaign_type: type) }
  scope :by_objective, ->(objective) { where(objective: objective) }
  scope :by_status, ->(status) { where(status: status) }
  scope :completed, -> { where(status: 'completed') }
  scope :recent, -> { order(created_at: :desc) }
  
  before_validation :set_default_metadata, on: :create
  
  def draft?
    status == 'draft'
  end
  
  def generating?
    status == 'generating'
  end
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def archived?
    status == 'archived'
  end
  
  def ready_for_generation?
    draft? && name.present? && campaign_type.present? && objective.present?
  end
  
  def has_generated_content?
    generated_summary.present? || generated_strategy.present? || 
    generated_timeline.present? || generated_assets.present?
  end
  
  def generation_progress
    return 0 unless generating? || completed?
    
    completed_sections = [
      generated_summary.present?,
      generated_strategy.present?,
      generated_timeline.present?,
      generated_assets.present?
    ].count(true)
    
    (completed_sections.to_f / 4 * 100).round(0)
  end
  
  def brand_context_summary
    return {} unless brand_context.present?
    
    begin
      JSON.parse(brand_context)
    rescue JSON::ParserError
      { raw_context: brand_context }
    end
  end
  
  def budget_summary
    return {} unless budget_constraints.present?
    
    begin
      JSON.parse(budget_constraints)
    rescue JSON::ParserError
      { raw_budget: budget_constraints }
    end
  end
  
  def timeline_summary
    return {} unless timeline_constraints.present?
    
    begin
      JSON.parse(timeline_constraints)
    rescue JSON::ParserError
      { raw_timeline: timeline_constraints }
    end
  end
  
  def target_audience_summary
    return {} unless target_audience.present?
    
    begin
      JSON.parse(target_audience)
    rescue JSON::ParserError
      { raw_audience: target_audience }
    end
  end
  
  def plan_analytics
    {
      campaign_type: campaign_type,
      objective: objective,
      status: status,
      has_content: has_generated_content?,
      generation_progress: generation_progress,
      created_days_ago: ((Time.current - created_at) / 1.day).round(1),
      last_updated: updated_at,
      content_sections: {
        summary: generated_summary.present?,
        strategy: generated_strategy.present?,
        timeline: generated_timeline.present?,
        assets: generated_assets.present?
      }
    }
  end
  
  def can_be_archived?
    %w[completed failed].include?(status)
  end
  
  def can_be_regenerated?
    %w[completed failed archived].include?(status)
  end
  
  def archive!
    return false unless can_be_archived?
    update!(status: 'archived')
  end
  
  def mark_generation_started!
    update!(status: 'generating', metadata: (metadata || {}).merge(generation_started_at: Time.current))
  end
  
  def mark_generation_completed!
    update!(
      status: 'completed',
      metadata: (metadata || {}).merge(
        generation_completed_at: Time.current,
        generation_duration: metadata&.dig('generation_started_at') ? 
          Time.current - Time.parse(metadata['generation_started_at'].to_s) : nil
      )
    )
  end
  
  def mark_generation_failed!(error_message = nil)
    update!(
      status: 'failed',
      metadata: (metadata || {}).merge(
        generation_failed_at: Time.current,
        error_message: error_message
      )
    )
  end
  
  private
  
  def set_default_metadata
    self.metadata ||= {
      created_via: 'campaign_plan_generator',
      version: '1.0'
    }
  end
end