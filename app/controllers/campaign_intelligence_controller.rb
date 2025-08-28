# frozen_string_literal: true

class CampaignIntelligenceController < ApplicationController
  include Authentication
  
  before_action :require_authentication
  before_action :set_campaign_plan
  before_action :ensure_owner

  def index
    @insights = @campaign_plan.campaign_insights
      .includes(:campaign_plan)
      .recent
      .order(analysis_date: :desc)
    
    # Filter by insight type if specified
    @insights = @insights.by_type(params[:insight_type]) if params[:insight_type].present?
    
    # Filter by confidence level
    @insights = @insights.high_confidence if params[:high_confidence] == 'true'
    
    # Paginate results
    @insights = @insights.limit(params[:limit] || 20)
    
    @insight_types = CampaignInsight::INSIGHT_TYPES
    @insights_summary = generate_insights_summary

    respond_to do |format|
      format.html
      format.json { render json: insights_json_response }
    end
  end

  def show
    @insight = @campaign_plan.campaign_insights.find(params[:id])
    
    respond_to do |format|
      format.html
      format.json { render json: insight_json_response(@insight) }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Insight not found' }, status: :not_found
  end

  def generate
    service_result = CampaignIntelligenceService.call(@campaign_plan)
    
    if service_result[:success]
      @intelligence_data = service_result[:data]
      
      respond_to do |format|
        format.html { 
          flash[:notice] = 'Campaign intelligence generated successfully'
          redirect_to campaign_intelligence_index_path(@campaign_plan)
        }
        format.json { 
          render json: {
            success: true,
            message: 'Intelligence generated successfully',
            data: @intelligence_data
          }, status: :created
        }
      end
    else
      handle_generation_error(service_result)
    end
  end

  def regenerate
    # Clear existing insights for this campaign
    @campaign_plan.campaign_insights.destroy_all
    
    # Generate new intelligence
    service_result = CampaignIntelligenceService.call(@campaign_plan)
    
    if service_result[:success]
      @intelligence_data = service_result[:data]
      
      respond_to do |format|
        format.html { 
          flash[:notice] = 'Campaign intelligence regenerated successfully'
          redirect_to campaign_intelligence_index_path(@campaign_plan)
        }
        format.json { 
          render json: {
            success: true,
            message: 'Intelligence regenerated successfully',
            data: @intelligence_data
          }, status: :created
        }
      end
    else
      handle_generation_error(service_result)
    end
  end

  def analytics
    @insights_analytics = calculate_insights_analytics
    @trend_analysis = calculate_trend_analysis
    @confidence_distribution = calculate_confidence_distribution
    
    respond_to do |format|
      format.html
      format.json { 
        render json: {
          insights_analytics: @insights_analytics,
          trend_analysis: @trend_analysis,
          confidence_distribution: @confidence_distribution
        }
      }
    end
  end

  def export
    case params[:format]
    when 'json'
      export_json
    when 'csv'
      export_csv
    when 'pdf'
      export_pdf
    else
      render json: { error: 'Unsupported export format' }, status: :bad_request
    end
  end

  private

  def set_campaign_plan
    @campaign_plan = Current.user.campaign_plans.find(params[:campaign_plan_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Campaign plan not found' }, status: :not_found
  end

  def ensure_owner
    unless @campaign_plan&.user == Current.user
      render json: { error: 'Unauthorized access' }, status: :forbidden
    end
  end

  def generate_insights_summary
    insights = @campaign_plan.campaign_insights.recent
    
    {
      total_insights: insights.count,
      high_confidence_insights: insights.high_confidence.count,
      insights_by_type: insights.group(:insight_type).count,
      average_confidence: insights.average(:confidence_score)&.round(2) || 0.0,
      latest_analysis: insights.maximum(:analysis_date),
      insights_this_week: insights.where('analysis_date >= ?', 1.week.ago).count
    }
  end

  def insights_json_response
    {
      insights: @insights.map { |insight| insight_json_response(insight) },
      summary: @insights_summary,
      metadata: {
        total_count: @campaign_plan.campaign_insights.recent.count,
        filter_applied: {
          insight_type: params[:insight_type],
          high_confidence: params[:high_confidence]
        },
        available_filters: {
          insight_types: @insight_types,
          confidence_levels: ['all', 'high_confidence']
        }
      }
    }
  end

  def insight_json_response(insight)
    {
      id: insight.id,
      insight_type: insight.insight_type,
      insight_data: insight.formatted_insight_data,
      confidence_score: insight.confidence_score,
      analysis_date: insight.analysis_date,
      metadata: insight.metadata,
      high_confidence: insight.high_confidence?,
      recent_insight: insight.recent_insight?,
      created_at: insight.created_at,
      updated_at: insight.updated_at
    }
  end

  def handle_generation_error(service_result)
    error_message = service_result[:error] || 'Failed to generate intelligence'
    
    respond_to do |format|
      format.html { 
        flash[:alert] = error_message
        redirect_to campaign_plan_path(@campaign_plan)
      }
      format.json { 
        render json: {
          success: false,
          error: error_message,
          context: service_result[:context]
        }, status: :unprocessable_entity
      }
    end
  end

  def calculate_insights_analytics
    insights = @campaign_plan.campaign_insights.recent
    
    {
      total_insights: insights.count,
      insights_by_type: insights.group(:insight_type).count,
      confidence_stats: {
        average: insights.average(:confidence_score)&.round(3) || 0.0,
        minimum: insights.minimum(:confidence_score) || 0.0,
        maximum: insights.maximum(:confidence_score) || 0.0,
        high_confidence_count: insights.high_confidence.count
      },
      temporal_analysis: {
        insights_last_7_days: insights.where('analysis_date >= ?', 7.days.ago).count,
        insights_last_30_days: insights.where('analysis_date >= ?', 30.days.ago).count,
        latest_analysis_date: insights.maximum(:analysis_date),
        oldest_analysis_date: insights.minimum(:analysis_date)
      }
    }
  end

  def calculate_trend_analysis
    insights = @campaign_plan.campaign_insights.recent.order(:analysis_date)
    
    # Group insights by week for trend analysis
    weekly_data = insights.group_by_week(:analysis_date).count
    
    {
      weekly_insights: weekly_data,
      trend_direction: determine_trend_direction(weekly_data),
      most_active_insight_type: insights.group(:insight_type).count.max_by { |k, v| v }&.first,
      confidence_trend: calculate_confidence_trend(insights)
    }
  end

  def calculate_confidence_distribution
    insights = @campaign_plan.campaign_insights.recent
    
    # Create confidence score buckets
    buckets = {
      'very_high' => insights.where('confidence_score >= ?', 0.9).count,
      'high' => insights.where('confidence_score >= ? AND confidence_score < ?', 0.8, 0.9).count,
      'medium' => insights.where('confidence_score >= ? AND confidence_score < ?', 0.6, 0.8).count,
      'low' => insights.where('confidence_score < ?', 0.6).count
    }
    
    total = buckets.values.sum
    percentages = buckets.transform_values { |count| total > 0 ? (count.to_f / total * 100).round(1) : 0.0 }
    
    {
      distribution: buckets,
      percentages: percentages,
      total_insights: total
    }
  end

  def determine_trend_direction(weekly_data)
    return 'insufficient_data' if weekly_data.size < 2
    
    recent_weeks = weekly_data.values.last(3)
    return 'stable' if recent_weeks.size < 2
    
    if recent_weeks.last > recent_weeks.first
      'increasing'
    elsif recent_weeks.last < recent_weeks.first
      'decreasing'
    else
      'stable'
    end
  end

  def calculate_confidence_trend(insights)
    # Calculate rolling average of confidence scores
    confidence_by_week = insights.group_by_week(:analysis_date).average(:confidence_score)
    
    {
      weekly_confidence: confidence_by_week.transform_values { |v| v&.round(3) || 0.0 },
      trend: determine_confidence_trend(confidence_by_week.values.compact)
    }
  end

  def determine_confidence_trend(confidence_values)
    return 'insufficient_data' if confidence_values.size < 2
    
    recent_avg = confidence_values.last(3).sum / [confidence_values.last(3).size, 1].max
    older_avg = confidence_values.first([confidence_values.size - 3, 1].max).sum / [confidence_values.first([confidence_values.size - 3, 1].max).size, 1].max
    
    if recent_avg > older_avg + 0.05
      'improving'
    elsif recent_avg < older_avg - 0.05
      'declining'
    else
      'stable'
    end
  end

  def export_json
    insights = @campaign_plan.campaign_insights.recent.includes(:campaign_plan)
    
    export_data = {
      campaign_plan: {
        id: @campaign_plan.id,
        name: @campaign_plan.name,
        campaign_type: @campaign_plan.campaign_type,
        objective: @campaign_plan.objective
      },
      insights: insights.map { |insight| insight_json_response(insight) },
      summary: generate_insights_summary,
      exported_at: Time.current.iso8601
    }

    send_data export_data.to_json, 
              filename: "campaign_intelligence_#{@campaign_plan.id}_#{Time.current.strftime('%Y%m%d')}.json",
              type: 'application/json'
  end

  def export_csv
    require 'csv'
    
    insights = @campaign_plan.campaign_insights.recent.includes(:campaign_plan)
    
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['ID', 'Type', 'Confidence Score', 'Analysis Date', 'High Confidence', 'Data Summary']
      
      insights.each do |insight|
        data_summary = insight.insight_data.is_a?(Hash) ? insight.insight_data.keys.join(', ') : 'N/A'
        csv << [
          insight.id,
          insight.insight_type,
          insight.confidence_score,
          insight.analysis_date.strftime('%Y-%m-%d %H:%M'),
          insight.high_confidence?,
          data_summary
        ]
      end
    end

    send_data csv_data,
              filename: "campaign_intelligence_#{@campaign_plan.id}_#{Time.current.strftime('%Y%m%d')}.csv",
              type: 'text/csv'
  end

  def export_pdf
    # This would require a PDF generation library like Prawn
    # For now, return a simple response
    render json: { 
      message: 'PDF export not yet implemented',
      alternative: 'Use JSON or CSV export instead'
    }, status: :not_implemented
  end
end