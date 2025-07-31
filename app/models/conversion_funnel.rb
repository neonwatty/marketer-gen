class ConversionFunnel < ApplicationRecord
  belongs_to :journey
  belongs_to :campaign
  belongs_to :user
  
  validates :funnel_name, presence: true
  validates :stage, presence: true
  validates :stage_order, presence: true, uniqueness: { scope: [:journey_id, :funnel_name, :period_start] }
  validates :visitors, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :conversions, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :conversion_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :drop_off_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :period_start, presence: true
  validates :period_end, presence: true
  
  validate :period_end_after_start
  validate :conversions_not_exceed_visitors
  
  # Use metadata for additional data storage
  store_accessor :metadata, :funnel_data, :total_users, :final_conversions, :overall_conversion_rate
  
  scope :by_funnel, ->(funnel_name) { where(funnel_name: funnel_name) }
  scope :by_stage, ->(stage) { where(stage: stage) }
  scope :ordered_by_stage, -> { order(:stage_order) }
  scope :for_period, ->(start_date, end_date) { where(period_start: start_date..end_date) }
  scope :recent, -> { order(period_start: :desc) }
  scope :high_conversion, -> { where('conversion_rate > ?', 20.0) }
  scope :high_drop_off, -> { where('drop_off_rate > ?', 50.0) }
  
  # Common funnel stages for marketing journeys
  AWARENESS_STAGES = %w[impression reach view].freeze
  CONSIDERATION_STAGES = %w[click engage explore read].freeze
  CONVERSION_STAGES = %w[signup purchase subscribe convert].freeze
  RETENTION_STAGES = %w[login return repeat_purchase loyalty].freeze
  ADVOCACY_STAGES = %w[share recommend review refer].freeze
  
  ALL_STAGES = (AWARENESS_STAGES + CONSIDERATION_STAGES + 
                CONVERSION_STAGES + RETENTION_STAGES + ADVOCACY_STAGES).freeze
  
  def self.create_journey_funnel(journey, period_start, period_end, funnel_name = 'default')
    # Create funnel stages based on journey steps
    journey.journey_steps.order(:position).each_with_index do |step, index|
      create!(
        journey: journey,
        campaign: journey.campaign,
        user: journey.user,
        funnel_name: funnel_name,
        stage: step.stage,
        stage_order: index + 1,
        period_start: period_start,
        period_end: period_end
      )
    end
  end
  
  def self.calculate_funnel_metrics(journey_id, funnel_name, period_start, period_end)
    funnel_stages = where(journey_id: journey_id, funnel_name: funnel_name)
                   .where(period_start: period_start, period_end: period_end)
                   .ordered_by_stage
    
    return [] if funnel_stages.empty?
    
    # Calculate visitors and conversions for each stage
    funnel_stages.each_with_index do |stage, index|
      if index == 0
        # First stage - visitors are the total who entered the journey
        stage.update!(
          visitors: calculate_stage_visitors(stage),
          conversions: calculate_stage_conversions(stage)
        )
      else
        # Subsequent stages - visitors are conversions from previous stage
        previous_stage = funnel_stages[index - 1]
        stage.update!(
          visitors: previous_stage.conversions,
          conversions: calculate_stage_conversions(stage)
        )
      end
      
      # Calculate rates
      stage.update!(
        conversion_rate: stage.visitors > 0 ? (stage.conversions.to_f / stage.visitors * 100).round(2) : 0,
        drop_off_rate: stage.visitors > 0 ? ((stage.visitors - stage.conversions).to_f / stage.visitors * 100).round(2) : 0
      )
    end
    
    funnel_stages.reload
  end
  
  def self.funnel_overview(journey_id, funnel_name, period_start, period_end)
    stages = by_funnel(funnel_name)
            .where(journey_id: journey_id)
            .where(period_start: period_start, period_end: period_end)
            .ordered_by_stage
    
    return {} if stages.empty?
    
    total_visitors = stages.first.visitors
    final_conversions = stages.last.conversions
    overall_conversion_rate = total_visitors > 0 ? (final_conversions.to_f / total_visitors * 100).round(2) : 0
    
    {
      funnel_name: funnel_name,
      total_visitors: total_visitors,
      final_conversions: final_conversions,
      overall_conversion_rate: overall_conversion_rate,
      total_stages: stages.count,
      biggest_drop_off_stage: stages.max_by(&:drop_off_rate)&.stage,
      best_converting_stage: stages.max_by(&:conversion_rate)&.stage,
      stages: stages.map(&:to_funnel_data)
    }
  end
  
  def self.compare_funnels(journey_id, period1_start, period1_end, period2_start, period2_end, funnel_name = 'default')
    period1_data = funnel_overview(journey_id, funnel_name, period1_start, period1_end)
    period2_data = funnel_overview(journey_id, funnel_name, period2_start, period2_end)
    
    return {} if period1_data.empty? || period2_data.empty?
    
    {
      period1: period1_data,
      period2: period2_data,
      comparison: {
        visitor_change: period2_data[:total_visitors] - period1_data[:total_visitors],
        conversion_change: period2_data[:final_conversions] - period1_data[:final_conversions],
        rate_change: period2_data[:overall_conversion_rate] - period1_data[:overall_conversion_rate]
      }
    }
  end
  
  def to_funnel_data
    {
      stage: stage,
      stage_order: stage_order,
      visitors: visitors,
      conversions: conversions,
      conversion_rate: conversion_rate,
      drop_off_rate: drop_off_rate,
      drop_off_count: visitors - conversions
    }
  end
  
  def next_stage
    self.class.where(journey_id: journey_id, funnel_name: funnel_name, period_start: period_start)
             .where(stage_order: stage_order + 1)
             .first
  end
  
  def previous_stage
    self.class.where(journey_id: journey_id, funnel_name: funnel_name, period_start: period_start)
             .where(stage_order: stage_order - 1)
             .first
  end
  
  def optimization_suggestions
    suggestions = []
    
    if drop_off_rate > 70
      suggestions << "High drop-off rate (#{drop_off_rate}%) - consider improving #{stage} experience"
    end
    
    if conversion_rate < 10 && stage_order > 1
      suggestions << "Low conversion rate (#{conversion_rate}%) - optimize #{stage} messaging or incentives"
    end
    
    if next_stage && next_stage.visitors < (conversions * 0.8)
      suggestions << "Significant visitor loss between #{stage} and #{next_stage.stage} - check journey flow"
    end
    
    suggestions.empty? ? ["Performance looks good for #{stage} stage"] : suggestions
  end
  
  private
  
  def period_end_after_start
    return unless period_start && period_end
    
    errors.add(:period_end, 'must be after period start') if period_end <= period_start
  end
  
  def conversions_not_exceed_visitors
    return unless visitors && conversions
    
    errors.add(:conversions, 'cannot exceed visitors') if conversions > visitors
  end
  
  def self.calculate_stage_visitors(stage)
    # This would integrate with actual execution data
    # For now, return a placeholder calculation based on journey executions
    journey = stage.journey
    
    executions_in_period = journey.journey_executions
                                 .where(created_at: stage.period_start..stage.period_end)
    
    # Count executions that reached this stage
    stage_step = journey.journey_steps.find_by(stage: stage.stage)
    return 0 unless stage_step
    
    executions_in_period.joins(:step_executions)
                       .where(step_executions: { journey_step_id: stage_step.id })
                       .distinct
                       .count
  end
  
  def self.calculate_stage_conversions(stage)
    # This would integrate with actual execution data
    # For now, return a placeholder calculation based on completed step executions
    journey = stage.journey
    
    executions_in_period = journey.journey_executions
                                 .where(created_at: stage.period_start..stage.period_end)
    
    # Count executions that completed this stage
    stage_step = journey.journey_steps.find_by(stage: stage.stage)
    return 0 unless stage_step
    
    executions_in_period.joins(:step_executions)
                       .where(step_executions: { 
                         journey_step_id: stage_step.id, 
                         status: 'completed' 
                       })
                       .distinct
                       .count
  end
  
  def self.funnel_step_breakdown(journey_id, funnel_name, period_start, period_end)
    stages = by_funnel(funnel_name)
            .where(journey_id: journey_id)
            .where(period_start: period_start, period_end: period_end)
            .ordered_by_stage
    
    stages.map do |stage|
      {
        stage: stage.stage,
        stage_order: stage.stage_order,
        visitors: stage.visitors,
        conversions: stage.conversions,
        conversion_rate: stage.conversion_rate,
        drop_off_rate: stage.drop_off_rate
      }
    end
  end
  
  def self.funnel_trends(journey_id, funnel_name, period_start, period_end)
    # Return basic trend data - could be enhanced with historical comparisons
    stages = by_funnel(funnel_name)
            .where(journey_id: journey_id)
            .where(period_start: period_start, period_end: period_end)
            .ordered_by_stage
    
    return [] if stages.empty?
    
    {
      overall_trend: "stable", # placeholder - could calculate based on historical data
      conversion_trend: stages.average(:conversion_rate).to_f.round(2),
      drop_off_trend: stages.average(:drop_off_rate).to_f.round(2),
      period: {
        start: period_start,
        end: period_end
      }
    }
  end
end