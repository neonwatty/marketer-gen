class ResourceAllocationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_budget_allocation, only: [:show, :update, :destroy, :optimize, :predict_performance]
  before_action :set_campaign_plan, only: [:create, :optimize_campaign]

  def index
    authorize :budget_allocation
    
    @budget_allocations = current_user.budget_allocations
                                     .includes(:campaign_plan)
                                     .order(created_at: :desc)
    
    # Apply filters if provided
    @budget_allocations = @budget_allocations.by_channel(params[:channel]) if params[:channel].present?
    @budget_allocations = @budget_allocations.by_objective(params[:objective]) if params[:objective].present?
    @budget_allocations = @budget_allocations.where(status: params[:status]) if params[:status].present?
    
    # Paginate results
    @budget_allocations = @budget_allocations.limit(50).offset(params[:offset] || 0)
    
    # Calculate summary statistics
    @summary_stats = calculate_allocation_summary(@budget_allocations)
    
    respond_to do |format|
      format.json do
        render json: {
          allocations: @budget_allocations.as_json(include: :campaign_plan),
          summary: @summary_stats,
          pagination: {
            offset: params[:offset] || 0,
            limit: 50,
            total: current_user.budget_allocations.count
          }
        }
      end
      format.html
    end
  end

  def show
    authorize @budget_allocation
    
    # Get real-time performance metrics
    performance_data = ResourceAllocationService.call(
      user: current_user,
      allocation_params: {
        action: 'predict',
        allocation_ids: [@budget_allocation.id]
      }
    )
    
    respond_to do |format|
      format.json do
        render json: {
          allocation: @budget_allocation.as_json(include: :campaign_plan),
          performance_data: performance_data[:data] || {},
          optimization_suggestions: generate_optimization_suggestions(@budget_allocation)
        }
      end
      format.html
    end
  end

  def create
    authorize :budget_allocation
    
    result = ResourceAllocationService.call(
      user: current_user,
      campaign_plan: @campaign_plan,
      allocation_params: allocation_params.merge(action: 'create')
    )
    
    if result[:success]
      render json: {
        allocation: result[:data][:allocation],
        optimization_suggestions: result[:data][:optimization_suggestions]
      }, status: :created
    else
      render json: { 
        error: result[:error],
        details: result[:context] 
      }, status: :unprocessable_entity
    end
  end

  def update
    authorize @budget_allocation
    
    if @budget_allocation.update(allocation_update_params)
      # Recalculate performance predictions after update
      performance_data = ResourceAllocationService.call(
        user: current_user,
        allocation_params: {
          action: 'predict',
          allocation_ids: [@budget_allocation.id]
        }
      )
      
      render json: {
        allocation: @budget_allocation.as_json(include: :campaign_plan),
        performance_data: performance_data[:data] || {}
      }
    else
      render json: {
        error: 'Update failed',
        validation_errors: @budget_allocation.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @budget_allocation
    
    if @budget_allocation.destroy
      render json: { message: 'Budget allocation deleted successfully' }
    else
      render json: { 
        error: 'Failed to delete allocation',
        details: @budget_allocation.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  def optimize
    authorize @budget_allocation
    
    result = ResourceAllocationService.call(
      user: current_user,
      allocation_params: {
        action: 'optimize',
        total_budget: params[:total_budget] || @budget_allocation.total_budget,
        channels: params[:channels] || [@budget_allocation.channel_type],
        objectives: params[:objectives] || [@budget_allocation.optimization_objective],
        time_period: {
          start: params[:start_date] || @budget_allocation.time_period_start.to_s,
          end: params[:end_date] || @budget_allocation.time_period_end.to_s
        }
      }
    )
    
    if result[:success]
      render json: result[:data]
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def optimize_campaign
    authorize :budget_allocation
    
    # Get all existing allocations for the campaign
    existing_allocations = @campaign_plan.budget_allocations.active
    
    result = ResourceAllocationService.call(
      user: current_user,
      campaign_plan: @campaign_plan,
      allocation_params: {
        action: 'optimize',
        total_budget: params[:total_budget] || @campaign_plan.total_budget,
        channels: params[:channels] || existing_allocations.pluck(:channel_type).uniq,
        objectives: params[:objectives] || existing_allocations.pluck(:optimization_objective).uniq,
        time_period: {
          start: params[:start_date] || Date.current.to_s,
          end: params[:end_date] || (Date.current + 30.days).to_s
        }
      }
    )
    
    if result[:success]
      render json: result[:data]
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def predict_performance
    authorize @budget_allocation
    
    result = ResourceAllocationService.call(
      user: current_user,
      allocation_params: {
        action: 'predict'
      }
    )
    
    if result[:success]
      # Filter predictions for the specific allocation
      allocation_prediction = result[:data][:predictions].find do |pred|
        pred[:allocation_id] == @budget_allocation.id
      end
      
      render json: {
        allocation_id: @budget_allocation.id,
        prediction: allocation_prediction,
        aggregate_forecast: result[:data][:aggregate_forecast]
      }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def rebalance
    authorize :budget_allocation
    
    result = ResourceAllocationService.call(
      user: current_user,
      allocation_params: { action: 'rebalance' }
    )
    
    if result[:success]
      render json: result[:data]
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def dashboard_summary
    authorize :budget_allocation
    
    # Get summary statistics for dashboard
    active_allocations = current_user.budget_allocations.active
    total_allocated = active_allocations.sum(:allocated_amount)
    total_budget = active_allocations.sum(:total_budget)
    
    # Channel distribution
    channel_distribution = active_allocations.group(:channel_type)
                                           .sum(:allocated_amount)
    
    # Performance trends
    performance_trends = calculate_performance_trends(active_allocations)
    
    # Upcoming optimization opportunities
    optimization_opportunities = identify_optimization_opportunities(active_allocations)
    
    render json: {
      summary: {
        total_allocated: total_allocated,
        total_budget: total_budget,
        utilization_rate: total_budget > 0 ? (total_allocated / total_budget * 100).round(2) : 0,
        active_allocations_count: active_allocations.count
      },
      channel_distribution: channel_distribution,
      performance_trends: performance_trends,
      optimization_opportunities: optimization_opportunities
    }
  end

  private

  def set_budget_allocation
    @budget_allocation = current_user.budget_allocations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Budget allocation not found' }, status: :not_found
  end

  def set_campaign_plan
    if params[:campaign_plan_id].present?
      @campaign_plan = current_user.campaign_plans.find(params[:campaign_plan_id])
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Campaign plan not found' }, status: :not_found
  end

  def allocation_params
    params.require(:budget_allocation).permit(
      :name, :total_budget, :allocated_amount, :channel_type, 
      :time_period_start, :time_period_end, :optimization_objective,
      :enable_predictive_modeling, :status,
      predictive_model_data: {},
      performance_metrics: {},
      allocation_breakdown: {}
    )
  end

  def allocation_update_params
    params.require(:budget_allocation).permit(
      :name, :allocated_amount, :status,
      :time_period_start, :time_period_end, :optimization_objective,
      performance_metrics: {},
      allocation_breakdown: {}
    )
  end

  def calculate_allocation_summary(allocations)
    {
      total_allocations: allocations.count,
      total_allocated: allocations.sum(:allocated_amount),
      total_budget: allocations.sum(:total_budget),
      average_efficiency: allocations.average(:efficiency_score)&.round(2) || 0,
      status_distribution: allocations.group(:status).count,
      channel_distribution: allocations.group(:channel_type).count
    }
  end

  def generate_optimization_suggestions(allocation)
    suggestions = []
    
    # Budget utilization suggestions
    if allocation.allocation_percentage < 50
      suggestions << {
        type: 'budget_utilization',
        priority: 'medium',
        message: 'Consider increasing budget allocation for better performance',
        recommended_action: 'Increase allocated amount to at least 60% of total budget'
      }
    elsif allocation.allocation_percentage > 90
      suggestions << {
        type: 'budget_risk',
        priority: 'high',
        message: 'High budget concentration may increase risk',
        recommended_action: 'Consider diversifying across multiple allocations'
      }
    end
    
    # Duration suggestions
    if allocation.duration_days < 14
      suggestions << {
        type: 'duration',
        priority: 'medium',
        message: 'Short campaign duration may limit optimization opportunities',
        recommended_action: 'Extend campaign to at least 2-3 weeks for better results'
      }
    end
    
    # Channel-specific suggestions
    case allocation.channel_type
    when 'search'
      suggestions << {
        type: 'channel_optimization',
        priority: 'low',
        message: 'Search campaigns typically perform well with higher daily budgets',
        recommended_action: 'Consider increasing daily allocation if performance is strong'
      }
    when 'social_media'
      suggestions << {
        type: 'channel_optimization',
        priority: 'low',
        message: 'Social media campaigns benefit from consistent daily spend',
        recommended_action: 'Maintain steady daily budget distribution'
      }
    end
    
    suggestions
  end

  def calculate_performance_trends(allocations)
    # This would typically analyze historical performance data
    # For now, returning a simplified trend analysis
    {
      trend_direction: 'stable',
      performance_change: 0.0,
      period_comparison: '30_days',
      key_metrics: {
        average_efficiency: allocations.average(:efficiency_score)&.round(2) || 0,
        budget_utilization: allocations.sum(:allocated_amount) / allocations.sum(:total_budget) * 100
      }
    }
  end

  def identify_optimization_opportunities(allocations)
    opportunities = []
    
    # Identify underperforming allocations
    low_efficiency = allocations.where('efficiency_score < ?', 60)
    if low_efficiency.any?
      opportunities << {
        type: 'efficiency_improvement',
        count: low_efficiency.count,
        message: "#{low_efficiency.count} allocations have efficiency scores below 60%",
        action: 'Review and optimize underperforming allocations'
      }
    end
    
    # Identify budget reallocation opportunities
    channel_performance = allocations.group(:channel_type).average(:efficiency_score)
    best_channel = channel_performance.max_by(&:last)
    
    if best_channel && channel_performance.values.max - channel_performance.values.min > 20
      opportunities << {
        type: 'channel_reallocation',
        message: "#{best_channel.first} shows significantly better performance",
        action: "Consider reallocating budget to #{best_channel.first}"
      }
    end
    
    opportunities
  end

  def authenticate_user!
    unless current_user
      render json: { error: 'Authentication required' }, status: :unauthorized
    end
  end
end