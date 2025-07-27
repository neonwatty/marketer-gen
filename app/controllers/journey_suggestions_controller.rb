class JourneySuggestionsController < ApplicationController
  before_action :set_journey
  before_action :set_current_step, only: [:index, :for_step]
  before_action :authorize_journey_access

  # GET /journeys/:journey_id/suggestions
  def index
    filters = build_filters_from_params
    
    begin
      engine = JourneySuggestionEngine.new(
        journey: @journey,
        user: current_user,
        current_step: @current_step,
        provider: suggestion_provider
      )
      
      @suggestions = engine.generate_suggestions(filters)
      @feedback_insights = engine.get_feedback_insights
      
      respond_to do |format|
        format.json {
          render json: {
            success: true,
            data: {
              suggestions: @suggestions,
              feedback_insights: @feedback_insights,
              journey_context: journey_context_summary,
              filters_applied: filters,
              provider: suggestion_provider,
              cached: Rails.cache.exist?(cache_key_for_request)
            },
            meta: {
              total_suggestions: @suggestions.length,
              generated_at: Time.current,
              expires_at: 1.hour.from_now
            }
          }
        }
        format.html { render :index }
      end
    rescue => e
      Rails.logger.error "Suggestion generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: {
        success: false,
        error: {
          message: "Failed to generate suggestions",
          details: Rails.env.development? ? e.message : "Internal server error"
        }
      }, status: :internal_server_error
    end
  end

  # GET /journeys/:journey_id/suggestions/for_stage/:stage
  def for_stage
    stage = params[:stage]
    
    unless Journey::STAGES.include?(stage)
      return render json: {
        success: false,
        error: { message: "Invalid stage: #{stage}" }
      }, status: :bad_request
    end

    filters = build_filters_from_params.merge(stage: stage)
    
    begin
      engine = JourneySuggestionEngine.new(
        journey: @journey,
        user: current_user,
        provider: suggestion_provider
      )
      
      @suggestions = engine.suggest_for_stage(stage, filters)
      
      render json: {
        success: true,
        data: {
          suggestions: @suggestions,
          stage: stage,
          filters_applied: filters,
          provider: suggestion_provider
        },
        meta: {
          total_suggestions: @suggestions.length,
          generated_at: Time.current
        }
      }
    rescue => e
      Rails.logger.error "Stage suggestion generation failed: #{e.message}"
      
      render json: {
        success: false,
        error: {
          message: "Failed to generate stage suggestions",
          details: Rails.env.development? ? e.message : "Internal server error"
        }
      }, status: :internal_server_error
    end
  end

  # GET /journeys/:journey_id/suggestions/for_step/:step_id
  def for_step
    step = @journey.journey_steps.find(params[:step_id])
    filters = build_filters_from_params
    
    begin
      engine = JourneySuggestionEngine.new(
        journey: @journey,
        user: current_user,
        current_step: step,
        provider: suggestion_provider
      )
      
      @suggestions = engine.generate_suggestions(filters)
      
      render json: {
        success: true,
        data: {
          suggestions: @suggestions,
          current_step: step.as_json(only: [:id, :name, :stage, :content_type, :channel]),
          filters_applied: filters,
          provider: suggestion_provider
        },
        meta: {
          total_suggestions: @suggestions.length,
          generated_at: Time.current
        }
      }
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        error: { message: "Journey step not found" }
      }, status: :not_found
    rescue => e
      Rails.logger.error "Step suggestion generation failed: #{e.message}"
      
      render json: {
        success: false,
        error: {
          message: "Failed to generate step suggestions",
          details: Rails.env.development? ? e.message : "Internal server error"
        }
      }, status: :internal_server_error
    end
  end

  # POST /journeys/:journey_id/suggestions/feedback
  def create_feedback
    suggestion_data = params.require(:suggestion)
    feedback_params = params.require(:feedback)
    
    begin
      engine = JourneySuggestionEngine.new(
        journey: @journey,
        user: current_user,
        current_step: @current_step,
        provider: suggestion_provider
      )
      
      feedback = engine.record_feedback(
        suggestion_data.to_h,
        feedback_params[:feedback_type],
        rating: feedback_params[:rating],
        selected: feedback_params[:selected],
        context: feedback_params[:context]
      )
      
      if feedback.persisted?
        render json: {
          success: true,
          data: {
            feedback_id: feedback.id,
            message: "Feedback recorded successfully"
          }
        }, status: :created
      else
        render json: {
          success: false,
          error: {
            message: "Failed to record feedback",
            details: feedback.errors.full_messages
          }
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Feedback recording failed: #{e.message}"
      
      render json: {
        success: false,
        error: {
          message: "Failed to record feedback",
          details: Rails.env.development? ? e.message : "Internal server error"
        }
      }, status: :internal_server_error
    end
  end

  # GET /journeys/:journey_id/suggestions/insights
  def insights
    @insights = @journey.journey_insights
                        .active
                        .order(calculated_at: :desc)
                        .limit(10)
    
    @feedback_analytics = calculate_feedback_analytics
    @suggestion_performance = calculate_suggestion_performance
    
    respond_to do |format|
      format.json {
        render json: {
          success: true,
          data: {
            insights: @insights.map(&:to_summary),
            feedback_analytics: @feedback_analytics,
            suggestion_performance: @suggestion_performance,
            journey_summary: journey_context_summary
          },
          meta: {
            total_insights: @insights.length,
            generated_at: Time.current
          }
        }
      }
      format.html { render :insights }
    end
  end

  # GET /journeys/:journey_id/suggestions/analytics
  def analytics
    date_range = params[:date_range] || '30_days'
    days = case date_range
           when '7_days' then 7
           when '30_days' then 30
           when '90_days' then 90
           else 30
           end

    @analytics = {
      feedback_trends: calculate_feedback_trends(days),
      selection_rates: calculate_selection_rates(days),
      performance_by_type: calculate_performance_by_type(days),
      ai_provider_comparison: calculate_provider_comparison(days),
      improvement_opportunities: identify_improvement_opportunities
    }

    render json: {
      success: true,
      data: @analytics,
      meta: {
        date_range: date_range,
        days_analyzed: days,
        generated_at: Time.current
      }
    }
  end

  # DELETE /journeys/:journey_id/suggestions/cache
  def clear_cache
    cache_pattern = "journey_suggestions:#{@journey.id}:*"
    Rails.cache.delete_matched(cache_pattern)
    
    render json: {
      success: true,
      message: "Cache cleared for journey suggestions"
    }
  end

  private

  def set_journey
    @journey = current_user.journeys.find(params[:journey_id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: { message: "Journey not found" }
    }, status: :not_found
  end

  def set_current_step
    return unless params[:current_step_id]
    
    @current_step = @journey.journey_steps.find(params[:current_step_id])
  rescue ActiveRecord::RecordNotFound
    @current_step = nil
  end

  def authorize_journey_access
    unless @journey && @journey.user == current_user
      render json: {
        success: false,
        error: { message: "Unauthorized access to journey" }
      }, status: :forbidden
    end
  end

  def build_filters_from_params
    filters = {}
    
    filters[:stage] = params[:stage] if params[:stage].present?
    filters[:content_type] = params[:content_type] if params[:content_type].present?
    filters[:channel] = params[:channel] if params[:channel].present?
    filters[:max_suggestions] = params[:max_suggestions].to_i if params[:max_suggestions].present?
    filters[:min_confidence] = params[:min_confidence].to_f if params[:min_confidence].present?
    
    filters
  end

  def suggestion_provider
    provider = params[:provider] || 'openai'
    provider.to_sym if JourneySuggestionEngine::PROVIDERS.key?(provider.to_sym)
  end

  def journey_context_summary
    {
      id: @journey.id,
      name: @journey.name,
      status: @journey.status,
      campaign_type: @journey.campaign_type,
      total_steps: @journey.total_steps,
      stages_coverage: @journey.steps_by_stage,
      current_step: @current_step&.as_json(only: [:id, :name, :stage, :position])
    }
  end

  def calculate_feedback_analytics
    return {} unless @journey.suggestion_feedbacks.any?

    {
      average_ratings: @journey.suggestion_feedbacks.average_rating_by_type,
      total_feedback_count: @journey.suggestion_feedbacks.count,
      selection_rate: calculate_overall_selection_rate,
      feedback_distribution: @journey.suggestion_feedbacks.group(:feedback_type).count,
      recent_trends: @journey.suggestion_feedbacks.feedback_trends(7)
    }
  end

  def calculate_suggestion_performance
    feedbacks = @journey.suggestion_feedbacks.includes(:journey_step)
    
    {
      top_performing_content_types: feedbacks.selection_rate_by_content_type,
      top_performing_stages: feedbacks.selection_rate_by_stage,
      most_selected_suggestions: feedbacks.top_performing_suggestions(5),
      provider_performance: calculate_provider_feedback_performance
    }
  end

  def calculate_overall_selection_rate
    total_feedbacks = @journey.suggestion_feedbacks.count
    return 0 if total_feedbacks.zero?
    
    selected_count = @journey.suggestion_feedbacks.selected.count
    (selected_count.to_f / total_feedbacks * 100).round(2)
  end

  def calculate_feedback_trends(days)
    @journey.suggestion_feedbacks
            .where('created_at >= ?', days.days.ago)
            .group_by_day(:created_at)
            .group(:feedback_type)
            .average(:rating)
  end

  def calculate_selection_rates(days)
    feedbacks = @journey.suggestion_feedbacks.where('created_at >= ?', days.days.ago)
    
    {
      overall: calculate_selection_rate_for_feedbacks(feedbacks),
      by_content_type: feedbacks.selection_rate_by_content_type,
      by_stage: feedbacks.selection_rate_by_stage
    }
  end

  def calculate_performance_by_type(days)
    feedbacks = @journey.suggestion_feedbacks.where('created_at >= ?', days.days.ago)
    
    JourneySuggestionEngine::FEEDBACK_TYPES.map do |feedback_type|
      type_feedbacks = feedbacks.by_feedback_type(feedback_type)
      {
        feedback_type: feedback_type,
        average_rating: type_feedbacks.average(:rating)&.round(2),
        total_count: type_feedbacks.count,
        positive_count: type_feedbacks.positive.count,
        negative_count: type_feedbacks.negative.count
      }
    end
  end

  def calculate_provider_comparison(days)
    feedbacks = @journey.suggestion_feedbacks.where('created_at >= ?', days.days.ago)
    
    provider_data = {}
    
    feedbacks.group_by { |f| f.ai_provider }.each do |provider, provider_feedbacks|
      provider_data[provider] = {
        total_suggestions: provider_feedbacks.count,
        average_rating: provider_feedbacks.map(&:rating).compact.sum.to_f / provider_feedbacks.count,
        selection_rate: calculate_selection_rate_for_feedbacks(provider_feedbacks),
        response_time: nil # Would be tracked separately
      }
    end
    
    provider_data
  end

  def identify_improvement_opportunities
    opportunities = []
    
    # Low-rated content types
    low_performing_content = @journey.suggestion_feedbacks
                                    .joins(:journey_step)
                                    .group('journey_steps.content_type')
                                    .having('AVG(rating) < ?', 3.0)
                                    .average(:rating)
    
    low_performing_content.each do |content_type, avg_rating|
      opportunities << {
        type: 'content_improvement',
        content_type: content_type,
        current_rating: avg_rating.round(2),
        recommendation: "Improve #{content_type} suggestions - currently underperforming"
      }
    end
    
    # Underrepresented stages
    stage_coverage = @journey.steps_by_stage
    total_steps = @journey.total_steps
    
    Journey::STAGES.each do |stage|
      stage_count = stage_coverage[stage] || 0
      if stage_count < (total_steps * 0.1) # Less than 10% representation
        opportunities << {
          type: 'stage_coverage',
          stage: stage,
          current_count: stage_count,
          recommendation: "Consider adding more #{stage} stage steps to balance the journey"
        }
      end
    end
    
    opportunities
  end

  def calculate_provider_feedback_performance
    @journey.suggestion_feedbacks
            .group_by { |f| f.ai_provider }
            .transform_values do |feedbacks|
              {
                count: feedbacks.length,
                avg_rating: feedbacks.map(&:rating).compact.sum.to_f / feedbacks.length,
                selection_rate: calculate_selection_rate_for_feedbacks(feedbacks)
              }
            end
  end

  def calculate_selection_rate_for_feedbacks(feedbacks)
    return 0 if feedbacks.empty?
    
    selected_count = feedbacks.count { |f| f.selected? }
    (selected_count.to_f / feedbacks.length * 100).round(2)
  end

  def cache_key_for_request
    filters = build_filters_from_params
    key_parts = [
      "journey_suggestions",
      @journey.id,
      @journey.updated_at.to_i,
      @current_step&.id,
      current_user.id,
      suggestion_provider,
      Digest::MD5.hexdigest(filters.to_json)
    ]
    
    key_parts.join(":")
  end
end