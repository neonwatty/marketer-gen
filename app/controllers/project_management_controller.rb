class ProjectManagementController < ApplicationController
  before_action :set_campaign_plan
  before_action :set_milestone, only: [:show, :update, :destroy, :complete, :assign_resources]
  before_action :authorize_project_access
  
  # GET /campaign_plans/:campaign_plan_id/project_management
  def index
    service = ProjectManagementService.new(@campaign_plan, current_user)
    result = service.call
    
    if result[:success]
      render json: {
        success: true,
        data: result[:data]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /campaign_plans/:campaign_plan_id/project_management/milestones
  def milestones
    milestones = @campaign_plan.project_milestones
                              .includes(:assigned_to, :completed_by, :created_by)
                              .by_due_date

    # Filter by status if provided
    milestones = milestones.by_status(params[:status]) if params[:status].present?
    
    # Filter by priority if provided
    milestones = milestones.by_priority(params[:priority]) if params[:priority].present?
    
    # Filter by milestone type if provided
    milestones = milestones.by_milestone_type(params[:milestone_type]) if params[:milestone_type].present?

    # Filter by assigned user if provided
    milestones = milestones.assigned_to_user(User.find(params[:assigned_to])) if params[:assigned_to].present?

    milestone_data = milestones.map(&:project_analytics)

    render json: {
      success: true,
      data: {
        milestones: milestone_data,
        summary: generate_milestone_summary(milestones),
        filters: {
          statuses: ProjectMilestone::STATUSES,
          priorities: ProjectMilestone::PRIORITIES,
          types: ProjectMilestone::MILESTONE_TYPES
        }
      }
    }
  rescue => e
    render json: {
      success: false,
      error: e.message
    }, status: :internal_server_error
  end

  # GET /campaign_plans/:campaign_plan_id/project_management/milestones/:id
  def show
    render json: {
      success: true,
      data: {
        milestone: @milestone.project_analytics,
        dependencies: parse_dependencies(@milestone),
        deliverables: parse_deliverables(@milestone),
        resources: parse_resources(@milestone),
        activity_history: generate_activity_history(@milestone)
      }
    }
  end

  # POST /campaign_plans/:campaign_plan_id/project_management/milestones
  def create_milestone
    service = ProjectManagementService.new(@campaign_plan, current_user)
    result = service.create_milestone(milestone_params)
    
    if result[:success]
      render json: {
        success: true,
        data: result[:data],
        message: 'Milestone created successfully'
      }, status: :created
    else
      render json: {
        success: false,
        error: result[:error],
        errors: result[:errors]
      }, status: :unprocessable_entity
    end
  end

  # PATCH /campaign_plans/:campaign_plan_id/project_management/milestones/:id
  def update
    service = ProjectManagementService.new(@campaign_plan, current_user)
    result = service.update_milestone(@milestone.id, milestone_params)
    
    if result[:success]
      render json: {
        success: true,
        data: result[:data],
        message: 'Milestone updated successfully'
      }
    else
      render json: {
        success: false,
        error: result[:error],
        errors: result[:errors]
      }, status: :unprocessable_entity
    end
  end

  # DELETE /campaign_plans/:campaign_plan_id/project_management/milestones/:id
  def destroy
    if @milestone.can_be_deleted?
      @milestone.destroy
      render json: {
        success: true,
        message: 'Milestone deleted successfully'
      }
    else
      render json: {
        success: false,
        error: 'Milestone cannot be deleted - it may have dependencies or be in progress'
      }, status: :unprocessable_entity
    end
  rescue => e
    render json: {
      success: false,
      error: e.message
    }, status: :internal_server_error
  end

  # PATCH /campaign_plans/:campaign_plan_id/project_management/milestones/:id/complete
  def complete
    service = ProjectManagementService.new(@campaign_plan, current_user)
    result = service.complete_milestone(@milestone.id)
    
    if result[:success]
      render json: {
        success: true,
        data: result[:data],
        message: 'Milestone completed successfully'
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # PATCH /campaign_plans/:campaign_plan_id/project_management/milestones/:id/assign_resources
  def assign_resources
    service = ProjectManagementService.new(@campaign_plan, current_user)
    result = service.assign_resources(@milestone.id, resource_params)
    
    if result[:success]
      render json: {
        success: true,
        data: result[:data],
        message: 'Resources assigned successfully'
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /campaign_plans/:campaign_plan_id/project_management/gantt
  def gantt_chart
    service = ProjectManagementService.new(@campaign_plan, current_user)
    result = service.generate_gantt_chart_data
    
    if result[:success]
      render json: {
        success: true,
        data: result[:data]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :internal_server_error
    end
  end

  # GET /campaign_plans/:campaign_plan_id/project_management/timeline
  def timeline
    service = ProjectManagementService.new(@campaign_plan, current_user)
    timeline_result = service.generate_gantt_chart_data
    
    if timeline_result[:success]
      # Generate additional timeline visualization data
      timeline_data = enhance_timeline_data(timeline_result[:data])
      
      render json: {
        success: true,
        data: timeline_data
      }
    else
      render json: {
        success: false,
        error: timeline_result[:error]
      }, status: :internal_server_error
    end
  end

  # GET /campaign_plans/:campaign_plan_id/project_management/team_performance
  def team_performance
    service = ProjectManagementService.new(@campaign_plan, current_user)
    result = service.calculate_team_performance
    
    if result[:success]
      render json: {
        success: true,
        data: result[:data]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :internal_server_error
    end
  end

  # GET /campaign_plans/:campaign_plan_id/project_management/resource_allocation
  def resource_allocation
    milestones = @campaign_plan.project_milestones.includes(:assigned_to)
    
    allocation_data = {
      by_milestone: milestones.map do |milestone|
        {
          milestone_id: milestone.id,
          milestone_name: milestone.name,
          assigned_to: milestone.assigned_to&.full_name,
          estimated_hours: milestone.estimated_hours,
          actual_hours: milestone.actual_hours,
          resources: parse_resources(milestone),
          status: milestone.status
        }
      end,
      summary: calculate_resource_summary(milestones),
      utilization: calculate_resource_utilization(milestones)
    }
    
    render json: {
      success: true,
      data: allocation_data
    }
  rescue => e
    render json: {
      success: false,
      error: e.message
    }, status: :internal_server_error
  end

  # POST /campaign_plans/:campaign_plan_id/project_management/sync_timeline
  def sync_timeline
    service = ProjectManagementService.new(@campaign_plan, current_user)
    result = service.sync_with_campaign_timeline
    
    if result[:success]
      render json: {
        success: true,
        data: result[:data],
        message: 'Project timeline synchronized successfully'
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /campaign_plans/:campaign_plan_id/project_management/dashboard
  def dashboard
    service = ProjectManagementService.new(@campaign_plan, current_user)
    project_data = service.call
    
    if project_data[:success]
      # Enhance dashboard with additional metrics
      dashboard_data = project_data[:data].merge({
        recent_activities: get_recent_project_activities,
        upcoming_deadlines: get_upcoming_deadlines,
        team_alerts: get_team_alerts,
        project_health: calculate_project_health
      })
      
      render json: {
        success: true,
        data: dashboard_data
      }
    else
      render json: {
        success: false,
        error: project_data[:error]
      }, status: :internal_server_error
    end
  end

  private

  def set_campaign_plan
    @campaign_plan = current_user.campaign_plans.find(params[:campaign_plan_id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: 'Campaign plan not found'
    }, status: :not_found
  end

  def set_milestone
    @milestone = @campaign_plan.project_milestones.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: 'Milestone not found'
    }, status: :not_found
  end

  def authorize_project_access
    unless current_user == @campaign_plan.user
      render json: {
        success: false,
        error: 'Unauthorized access'
      }, status: :forbidden
    end
  end

  def milestone_params
    params.require(:milestone).permit(
      :name, :description, :due_date, :priority, :milestone_type,
      :estimated_hours, :completion_percentage, :notes,
      :assigned_to_id, :resources_required, :deliverables, 
      :dependencies, :risk_factors
    )
  end

  def resource_params
    params.require(:resources).map do |resource|
      resource.permit(:id, :type, :name, :cost, :allocation_percentage, :availability)
    end
  end

  def generate_milestone_summary(milestones)
    {
      total: milestones.count,
      by_status: milestones.group(:status).count,
      by_priority: milestones.group(:priority).count,
      by_type: milestones.group(:milestone_type).count,
      completion_rate: calculate_completion_rate(milestones),
      overdue_count: milestones.overdue_items.count,
      due_this_week: milestones.due_soon.count
    }
  end

  def calculate_completion_rate(milestones)
    return 0 if milestones.empty?
    
    completed = milestones.completed.count
    total = milestones.count
    
    (completed.to_f / total * 100).round(1)
  end

  def parse_dependencies(milestone)
    return [] unless milestone.dependencies.present?
    
    JSON.parse(milestone.dependencies.to_s)
  rescue JSON::ParserError
    []
  end

  def parse_deliverables(milestone)
    return [] unless milestone.deliverables.present?
    
    JSON.parse(milestone.deliverables.to_s)
  rescue JSON::ParserError
    []
  end

  def parse_resources(milestone)
    return [] unless milestone.resources_required.present?
    
    JSON.parse(milestone.resources_required.to_s)
  rescue JSON::ParserError
    []
  end

  def generate_activity_history(milestone)
    # This would integrate with an activity tracking system
    # For now, return basic milestone history
    [
      {
        action: 'created',
        timestamp: milestone.created_at,
        user: milestone.created_by&.full_name,
        details: "Milestone created"
      },
      milestone.started_at ? {
        action: 'started',
        timestamp: milestone.started_at,
        user: milestone.assigned_to&.full_name,
        details: "Work started on milestone"
      } : nil,
      milestone.completed_at ? {
        action: 'completed',
        timestamp: milestone.completed_at,
        user: milestone.completed_by&.full_name,
        details: "Milestone completed"
      } : nil
    ].compact
  end

  def enhance_timeline_data(gantt_data)
    {
      gantt_chart: gantt_data[:gantt_data],
      project_timeline: gantt_data[:project_timeline],
      milestones_by_month: group_milestones_by_month,
      critical_path: identify_critical_path,
      timeline_health: assess_timeline_health
    }
  end

  def group_milestones_by_month
    milestones = @campaign_plan.project_milestones.by_due_date
    
    grouped = milestones.group_by { |m| m.due_date.beginning_of_month }
    
    grouped.transform_values do |month_milestones|
      {
        count: month_milestones.count,
        completed: month_milestones.count(&:completed?),
        overdue: month_milestones.count(&:overdue?),
        milestones: month_milestones.map { |m| 
          {
            id: m.id,
            name: m.name,
            status: m.status,
            due_date: m.due_date
          }
        }
      }
    end
  end

  def identify_critical_path
    # Simplified critical path identification
    critical_milestones = @campaign_plan.project_milestones
                                       .where(priority: %w[high critical])
                                       .or(@campaign_plan.project_milestones.where(milestone_type: 'launch'))
                                       .by_due_date
    
    critical_milestones.map do |milestone|
      {
        id: milestone.id,
        name: milestone.name,
        due_date: milestone.due_date,
        status: milestone.status,
        impact: assess_milestone_impact(milestone)
      }
    end
  end

  def assess_timeline_health
    milestones = @campaign_plan.project_milestones
    
    overdue_count = milestones.overdue_items.count
    due_soon_count = milestones.due_soon.count
    total_count = milestones.count
    
    health_score = if total_count.zero?
      100
    else
      pressure_score = (overdue_count * 30 + due_soon_count * 10)
      [100 - (pressure_score.to_f / total_count * 100).round(1), 0].max
    end
    
    {
      health_score: health_score,
      status: categorize_health(health_score),
      overdue_milestones: overdue_count,
      upcoming_milestones: due_soon_count,
      recommendations: generate_timeline_recommendations(health_score, overdue_count, due_soon_count)
    }
  end

  def assess_milestone_impact(milestone)
    # Assess impact based on type, dependencies, and priority
    impact_score = case milestone.priority
                   when 'critical' then 10
                   when 'high' then 7
                   when 'medium' then 4
                   else 2
                   end
    
    # Boost score for launch milestones
    impact_score += 5 if milestone.milestone_type == 'launch'
    
    # Check dependencies
    dependencies = parse_dependencies(milestone)
    impact_score += dependencies.count * 2
    
    case impact_score
    when 0..5 then 'low'
    when 6..12 then 'medium'
    when 13..20 then 'high'
    else 'critical'
    end
  end

  def categorize_health(health_score)
    case health_score
    when 80..100 then 'excellent'
    when 60..79 then 'good'
    when 40..59 then 'warning'
    when 20..39 then 'critical'
    else 'failing'
    end
  end

  def generate_timeline_recommendations(health_score, overdue_count, due_soon_count)
    recommendations = []
    
    recommendations << 'Address overdue milestones immediately' if overdue_count > 0
    recommendations << 'Review upcoming deadlines and resource allocation' if due_soon_count > 3
    recommendations << 'Consider timeline adjustments or scope reduction' if health_score < 40
    recommendations << 'Implement additional monitoring and alerts' if health_score < 60
    recommendations << 'Current timeline is on track' if health_score >= 80
    
    recommendations
  end

  def calculate_resource_summary(milestones)
    {
      total_estimated_hours: milestones.sum(:estimated_hours) || 0,
      total_actual_hours: milestones.sum(:actual_hours) || 0,
      assigned_milestones: milestones.where.not(assigned_to: nil).count,
      unassigned_milestones: milestones.where(assigned_to: nil).count,
      team_members: milestones.joins(:assigned_to).distinct.count('users.id')
    }
  end

  def calculate_resource_utilization(milestones)
    team_utilization = {}
    
    milestones.includes(:assigned_to).each do |milestone|
      next unless milestone.assigned_to
      
      user_id = milestone.assigned_to.id
      team_utilization[user_id] ||= {
        user: milestone.assigned_to.full_name,
        assigned_hours: 0,
        completed_hours: 0,
        milestones_count: 0
      }
      
      team_utilization[user_id][:assigned_hours] += milestone.estimated_hours || 0
      team_utilization[user_id][:completed_hours] += milestone.actual_hours || 0 if milestone.completed?
      team_utilization[user_id][:milestones_count] += 1
    end
    
    team_utilization.values
  end

  def get_recent_project_activities
    # This would connect to an activity tracking system
    # For now, return recent milestone changes
    recent_milestones = @campaign_plan.project_milestones.recent.limit(10)
    
    recent_milestones.map do |milestone|
      {
        type: 'milestone',
        action: determine_recent_action(milestone),
        milestone_name: milestone.name,
        user: milestone.assigned_to&.full_name || milestone.created_by&.full_name,
        timestamp: milestone.updated_at,
        status: milestone.status
      }
    end
  end

  def get_upcoming_deadlines
    @campaign_plan.project_milestones
                  .where(due_date: Date.current..1.week.from_now)
                  .where.not(status: %w[completed cancelled])
                  .by_due_date
                  .map do |milestone|
      {
        id: milestone.id,
        name: milestone.name,
        due_date: milestone.due_date,
        days_remaining: (milestone.due_date - Date.current).to_i,
        priority: milestone.priority,
        assigned_to: milestone.assigned_to&.full_name,
        status: milestone.status
      }
    end
  end

  def get_team_alerts
    alerts = []
    
    # Overdue milestones
    overdue_count = @campaign_plan.project_milestones.overdue_items.count
    if overdue_count > 0
      alerts << {
        type: 'overdue',
        severity: 'high',
        message: "#{overdue_count} milestone(s) overdue",
        count: overdue_count
      }
    end
    
    # High priority milestones due soon
    critical_due_soon = @campaign_plan.project_milestones
                                     .due_soon
                                     .high_priority
                                     .count
    if critical_due_soon > 0
      alerts << {
        type: 'critical_due_soon',
        severity: 'medium',
        message: "#{critical_due_soon} high-priority milestone(s) due within a week",
        count: critical_due_soon
      }
    end
    
    # Unassigned milestones
    unassigned_count = @campaign_plan.project_milestones
                                    .pending
                                    .where(assigned_to: nil)
                                    .count
    if unassigned_count > 0
      alerts << {
        type: 'unassigned',
        severity: 'low',
        message: "#{unassigned_count} milestone(s) need assignment",
        count: unassigned_count
      }
    end
    
    alerts
  end

  def calculate_project_health
    service = ProjectManagementService.new(@campaign_plan, current_user)
    result = service.call
    
    return { health_score: 0, status: 'unknown' } unless result[:success]
    
    data = result[:data]
    project_status = data[:project_status]
    risk_assessment = data[:risk_assessment]
    
    # Calculate composite health score
    progress_score = project_status[:progress] || 0
    risk_penalty = case risk_assessment[:overall_risk_level]
                   when 'low' then 0
                   when 'medium' then 10
                   when 'high' then 25
                   when 'critical' then 40
                   else 0
                   end
    
    health_score = [progress_score - risk_penalty, 0].max
    
    {
      health_score: health_score,
      status: categorize_health(health_score),
      progress: project_status[:progress],
      risk_level: risk_assessment[:overall_risk_level],
      recommendation: generate_health_recommendation(health_score)
    }
  end

  def determine_recent_action(milestone)
    if milestone.completed?
      'completed'
    elsif milestone.in_progress?
      'in_progress'
    elsif milestone.overdue?
      'overdue'
    else
      'created'
    end
  end

  def generate_health_recommendation(health_score)
    case health_score
    when 80..100 then 'Project is healthy and on track'
    when 60..79 then 'Monitor progress and address minor issues'
    when 40..59 then 'Take corrective action to improve project health'
    when 20..39 then 'Immediate intervention required'
    else 'Project requires major restructuring or timeline adjustment'
    end
  end
end