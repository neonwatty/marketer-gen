class Campaign < ApplicationRecord
  belongs_to :user
  belongs_to :persona
  has_many :journeys, dependent: :destroy
  has_many :journey_analytics, through: :journeys, class_name: 'JourneyAnalytics'
  has_many :campaign_analytics, dependent: :destroy
  has_many :ab_tests, dependent: :destroy
  has_many :campaign_plans, dependent: :destroy
  
  STATUSES = %w[draft active paused completed archived].freeze
  CAMPAIGN_TYPES = %w[
    product_launch brand_awareness lead_generation customer_retention
    seasonal_promotion content_marketing email_nurture social_media
    event_promotion customer_onboarding re_engagement cross_sell
    upsell referral awareness consideration conversion advocacy
  ].freeze
  
  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :status, inclusion: { in: STATUSES }
  validates :campaign_type, inclusion: { in: CAMPAIGN_TYPES }, allow_blank: true
  validates :persona, presence: true
  
  scope :active, -> { where(status: 'active') }
  scope :draft, -> { where(status: 'draft') }
  scope :completed, -> { where(status: 'completed') }
  scope :by_type, ->(type) { where(campaign_type: type) if type.present? }
  scope :for_persona, ->(persona_id) { where(persona_id: persona_id) if persona_id.present? }
  scope :running, -> { where(status: ['active', 'paused']) }
  
  def activate!
    update!(status: 'active', started_at: Time.current)
  end
  
  def pause!
    update!(status: 'paused')
  end
  
  def complete!
    update!(status: 'completed', ended_at: Time.current)
  end
  
  def archive!
    update!(status: 'archived')
  end
  
  def active?
    status == 'active'
  end
  
  def running?
    %w[active paused].include?(status)
  end
  
  def completed?
    status == 'completed'
  end
  
  def duration_days
    return 0 unless started_at
    
    end_date = ended_at || Time.current
    ((end_date - started_at) / 1.day).round
  end
  
  def total_journeys
    journeys.count
  end
  
  def active_journeys
    journeys.published.count
  end
  
  def performance_summary
    return {} unless running? || completed?
    
    {
      total_executions: journey_executions_count,
      completion_rate: completion_rate,
      average_duration: average_journey_duration,
      conversion_rate: conversion_rate,
      engagement_score: engagement_score
    }
  end
  
  def journey_executions_count
    journeys.joins(:journey_executions).count
  end
  
  def completion_rate
    total = journey_executions_count
    return 0 if total == 0
    
    completed = journeys.joins(:journey_executions)
                       .where(journey_executions: { status: 'completed' })
                       .count
    
    (completed.to_f / total * 100).round(1)
  end
  
  def conversion_rate
    # This would be calculated based on conversion goals
    # For now, return completion rate as a proxy
    completion_rate
  end
  
  def engagement_score
    # Calculate based on step engagement, feedback, etc.
    # For now, return a placeholder calculation
    return 0 unless journey_executions_count > 0
    
    # Use completion rate and feedback as basis
    base_score = completion_rate
    feedback_bonus = positive_feedback_percentage * 0.3
    
    [base_score + feedback_bonus, 100].min.round(1)
  end
  
  def average_journey_duration
    executions = journeys.joins(:journey_executions)
                        .where(journey_executions: { status: 'completed' })
                        .where.not(journey_executions: { completed_at: nil })
    
    return 0 if executions.count == 0
    
    total_duration = executions.sum do |journey|
      journey.journey_executions.completed.sum do |execution|
        execution.completed_at - execution.started_at
      end
    end
    
    (total_duration / executions.count / 1.day).round(1)
  end
  
  def positive_feedback_percentage
    total_feedback = journeys.joins(:suggestion_feedbacks).count
    return 0 if total_feedback == 0
    
    positive_feedback = journeys.joins(:suggestion_feedbacks)
                               .where(suggestion_feedbacks: { rating: 4..5 })
                               .count
    
    (positive_feedback.to_f / total_feedback * 100).round(1)
  end
  
  def target_audience_context
    persona.to_campaign_context
  end
  
  def progress_percentage
    return 0 unless total_journeys > 0
    
    (active_journeys.to_f / total_journeys * 100).round
  end
  
  def to_analytics_context
    {
      id: id,
      name: name,
      type: campaign_type,
      persona: persona.name,
      status: status,
      duration_days: duration_days,
      performance: performance_summary,
      journeys_count: total_journeys
    }
  end
end