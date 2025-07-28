class Journey < ApplicationRecord
  belongs_to :user
  belongs_to :campaign, optional: true
  has_one :persona, through: :campaign
  has_many :journey_steps, dependent: :destroy
  has_many :step_transitions, through: :journey_steps
  has_many :journey_executions, dependent: :destroy
  has_many :suggestion_feedbacks, dependent: :destroy
  has_many :journey_insights, dependent: :destroy
  has_many :journey_analytics, class_name: 'JourneyAnalytics', dependent: :destroy
  has_many :conversion_funnels, dependent: :destroy
  has_many :journey_metrics, dependent: :destroy
  has_many :ab_test_variants, dependent: :destroy
  has_many :ab_tests, through: :ab_test_variants
  
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
  
  def published?
    status == 'published'
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
  
  # Analytics methods
  def current_analytics(period = 'daily')
    journey_analytics.order(period_start: :desc).first
  end
  
  def analytics_summary(days = 30)
    start_date = days.days.ago
    end_date = Time.current
    
    analytics = journey_analytics.where(period_start: start_date..end_date)
    
    return {} if analytics.empty?
    
    {
      total_executions: analytics.sum(:total_executions),
      completed_executions: analytics.sum(:completed_executions),
      abandoned_executions: analytics.sum(:abandoned_executions),
      average_conversion_rate: analytics.average(:conversion_rate)&.round(2) || 0,
      average_engagement_score: analytics.average(:engagement_score)&.round(2) || 0,
      period_days: days
    }
  end
  
  def funnel_performance(funnel_name = 'default', days = 7)
    start_date = days.days.ago
    end_date = Time.current
    
    ConversionFunnel.funnel_overview(id, funnel_name, start_date, end_date)
  end
  
  def compare_with_journey(other_journey_id, metrics = JourneyMetrics::CORE_METRICS)
    JourneyMetrics.compare_journey_metrics(id, other_journey_id, metrics)
  end
  
  def performance_trends(periods = 7)
    JourneyAnalytics.calculate_trends(id, periods)
  end
  
  def is_ab_test_variant?
    ab_test_variants.any?
  end
  
  def ab_test_status
    return 'not_in_test' unless is_ab_test_variant?
    
    test = ab_tests.active.first
    return 'no_active_test' unless test
    
    variant = ab_test_variants.joins(:ab_test).where(ab_tests: { id: test.id }).first
    return 'unknown_variant' unless variant
    
    {
      test_name: test.name,
      variant_name: variant.name,
      is_control: variant.is_control?,
      test_status: test.status,
      traffic_percentage: variant.traffic_percentage
    }
  end
  
  def persona_context
    return {} unless campaign&.persona
    
    campaign.persona.to_campaign_context
  end
  
  def campaign_context
    return {} unless campaign
    
    campaign.to_analytics_context
  end
  
  def calculate_metrics!(period = 'daily')
    JourneyMetrics.calculate_and_store_metrics(self, period)
  end
  
  def create_conversion_funnel!(period_start = 1.week.ago, period_end = Time.current, funnel_name = 'default')
    ConversionFunnel.create_journey_funnel(self, period_start, period_end, funnel_name)
    ConversionFunnel.calculate_funnel_metrics(id, funnel_name, period_start, period_end)
  end
  
  def latest_performance_score
    latest_analytics = current_analytics
    return 0 unless latest_analytics
    
    # Weighted performance score
    conversion_weight = 0.4
    engagement_weight = 0.3
    completion_weight = 0.3
    
    (latest_analytics.conversion_rate * conversion_weight +
     latest_analytics.engagement_score * engagement_weight +
     (latest_analytics.completed_executions.to_f / [latest_analytics.total_executions, 1].max * 100) * completion_weight).round(1)
  end
end
