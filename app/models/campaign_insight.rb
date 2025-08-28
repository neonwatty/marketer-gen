# frozen_string_literal: true

class CampaignInsight < ApplicationRecord
  belongs_to :campaign_plan

  INSIGHT_TYPES = %w[
    competitive_analysis
    market_trends
    performance_prediction
    strategic_recommendation
    trend_monitoring
    audience_intelligence
    budget_optimization
  ].freeze

  validates :campaign_plan_id, presence: true
  validates :insight_type, presence: true, inclusion: { in: INSIGHT_TYPES }
  validates :insight_data, presence: true
  validates :confidence_score, presence: true, 
            numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
  validates :analysis_date, presence: true

  serialize :insight_data, coder: JSON
  serialize :metadata, coder: JSON

  scope :recent, -> { where('analysis_date >= ?', 30.days.ago) }
  scope :by_type, ->(type) { where(insight_type: type) }
  scope :high_confidence, -> { where('confidence_score >= ?', 0.8) }
  scope :for_campaign, ->(campaign_id) { where(campaign_plan_id: campaign_id) }

  def self.latest_insights_for_campaign(campaign_id, limit: 10)
    for_campaign(campaign_id)
      .recent
      .order(analysis_date: :desc)
      .limit(limit)
  end

  def self.insights_by_type_for_campaign(campaign_id, insight_type)
    for_campaign(campaign_id)
      .by_type(insight_type)
      .recent
      .order(analysis_date: :desc)
  end

  def high_confidence?
    confidence_score >= 0.8
  end

  def recent_insight?
    analysis_date >= 7.days.ago
  end

  def formatted_insight_data
    insight_data.is_a?(Hash) ? insight_data : {}
  end
end