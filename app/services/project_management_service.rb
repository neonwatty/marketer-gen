class ProjectManagementService < ApplicationService
  attr_reader :campaign_plan, :current_user

  def initialize(campaign_plan, current_user = nil)
    @campaign_plan = campaign_plan
    @current_user = current_user
  end

  def call
    log_service_call('ProjectManagementService', { campaign_plan_id: campaign_plan.id })
    
    {
      success: true,
      data: {
        project_status: calculate_project_status,
        milestone_summary: generate_milestone_summary,
        resource_allocation: calculate_resource_allocation,
        timeline_visualization: generate_timeline_data,
        risk_assessment: calculate_project_risks,
        team_workload: calculate_team_workload
      }
    }
  rescue => e
    handle_service_error(e, { campaign_plan_id: campaign_plan.id })
  end

  def create_milestone(milestone_params)
    log_service_call('create_milestone', milestone_params)
    
    # Set default status if not provided
    milestone_params_with_defaults = milestone_params.reverse_merge(status: 'pending')
    
    milestone = campaign_plan.project_milestones.build(milestone_params_with_defaults)
    milestone.created_by = current_user if current_user
    
    if milestone.save
      success_response({ milestone: milestone, project_status: calculate_project_status })
    else
      {
        success: false,
        error: 'Failed to create milestone',
        errors: milestone.errors.full_messages
      }
    end
  rescue => e
    handle_service_error(e, { milestone_params: milestone_params })
  end

  def update_milestone(milestone_id, milestone_params)
    log_service_call('update_milestone', { milestone_id: milestone_id, params: milestone_params })
    
    milestone = campaign_plan.project_milestones.find(milestone_id)
    
    if milestone.update(milestone_params)
      # Check if status changed to trigger additional logic
      if milestone.saved_change_to_status?
        handle_milestone_status_change(milestone)
      end
      
      success_response({ milestone: milestone, project_status: calculate_project_status })
    else
      {
        success: false,
        error: 'Failed to update milestone',
        errors: milestone.errors.full_messages
      }
    end
  rescue ActiveRecord::RecordNotFound => e
    { success: false, error: 'Milestone not found' }
  rescue => e
    handle_service_error(e, { milestone_id: milestone_id, params: milestone_params })
  end

  def complete_milestone(milestone_id)
    log_service_call('complete_milestone', { milestone_id: milestone_id })
    
    milestone = campaign_plan.project_milestones.find(milestone_id)
    
    if milestone.complete!(current_user)
      # Handle milestone completion logic
      handle_milestone_status_change(milestone)
      
      # Update project timeline if milestone affects campaign dates
      update_campaign_timeline_if_needed(milestone)
      
      success_response({ 
        milestone: milestone, 
        project_status: calculate_project_status,
        next_milestones: get_next_available_milestones 
      })
    else
      { success: false, error: 'Cannot complete milestone - requirements not met' }
    end
  rescue ActiveRecord::RecordNotFound => e
    { success: false, error: 'Milestone not found' }
  rescue => e
    handle_service_error(e, { milestone_id: milestone_id })
  end

  def assign_resources(milestone_id, resource_allocation)
    log_service_call('assign_resources', { milestone_id: milestone_id, resources: resource_allocation })
    
    milestone = campaign_plan.project_milestones.find(milestone_id)
    current_resources = parse_json_field(milestone.resources_required) || []
    
    updated_resources = merge_resource_allocations(current_resources, resource_allocation)
    
    if milestone.update(resources_required: updated_resources.to_json)
      success_response({ 
        milestone: milestone, 
        resource_summary: calculate_resource_allocation 
      })
    else
      { success: false, error: 'Failed to assign resources', errors: milestone.errors.full_messages }
    end
  rescue ActiveRecord::RecordNotFound => e
    { success: false, error: 'Milestone not found' }
  rescue => e
    handle_service_error(e, { milestone_id: milestone_id, resources: resource_allocation })
  end

  def generate_gantt_chart_data
    log_service_call('generate_gantt_chart_data')
    
    milestones = campaign_plan.project_milestones.by_due_date.includes(:assigned_to, :completed_by)
    
    gantt_data = milestones.map do |milestone|
      begin
        dependencies = parse_json_field(milestone.dependencies) || []
      rescue => dep_error
        Rails.logger.error "Error parsing dependencies for milestone #{milestone.id}: #{dep_error.message}"
        dependencies = []
      end
      
      begin
        duration_days = calculate_milestone_duration(milestone)
      rescue => duration_error
        Rails.logger.error "Error calculating duration for milestone #{milestone.id}: #{duration_error.message}"
        duration_days = 1
      end
      
      begin
        overdue_status = milestone.overdue?
      rescue => overdue_error
        Rails.logger.error "Error checking overdue status for milestone #{milestone.id}: #{overdue_error.message}"
        overdue_status = false
      end
      
      {
        id: milestone.id,
        name: milestone.name,
        start_date: milestone.started_at || milestone.created_at,
        due_date: milestone.due_date,
        completed_date: milestone.completed_at,
        status: milestone.status,
        priority: milestone.priority,
        assigned_to: milestone.assigned_to&.full_name,
        progress: milestone.completion_percentage,
        dependencies: dependencies,
        type: milestone.milestone_type,
        duration_days: duration_days,
        overdue: overdue_status
      }
    end
    
    begin
      project_timeline = calculate_project_timeline
    rescue => timeline_error
      Rails.logger.error "Error calculating project timeline: #{timeline_error.message}"
      project_timeline = {}
    end
    
    success_response({ gantt_data: gantt_data, project_timeline: project_timeline })
  rescue => e
    handle_service_error(e)
  end

  def calculate_team_performance
    log_service_call('calculate_team_performance')
    
    milestones = campaign_plan.project_milestones.includes(:assigned_to, :completed_by)
    
    team_stats = {}
    milestones.each do |milestone|
      next unless milestone.assigned_to
      
      user_id = milestone.assigned_to.id
      team_stats[user_id] ||= {
        user: milestone.assigned_to,
        total_assigned: 0,
        completed: 0,
        overdue: 0,
        in_progress: 0,
        estimated_hours: 0,
        actual_hours: 0,
        efficiency_score: 0
      }
      
      stats = team_stats[user_id]
      stats[:total_assigned] += 1
      stats[:completed] += 1 if milestone.completed?
      stats[:overdue] += 1 if milestone.overdue?
      stats[:in_progress] += 1 if milestone.in_progress?
      stats[:estimated_hours] += milestone.estimated_hours || 0
      stats[:actual_hours] += milestone.actual_hours || 0
    end
    
    # Calculate efficiency scores
    team_stats.each do |user_id, stats|
      completion_rate = stats[:total_assigned] > 0 ? (stats[:completed].to_f / stats[:total_assigned]) : 0
      time_efficiency = if stats[:estimated_hours] > 0 && stats[:actual_hours] > 0
        [stats[:estimated_hours].to_f / stats[:actual_hours], 1.0].min
      else
        1.0
      end
      
      stats[:efficiency_score] = ((completion_rate * 0.7) + (time_efficiency * 0.3) * 100).round(1)
    end
    
    success_response({ team_performance: team_stats.values })
  rescue => e
    handle_service_error(e)
  end

  def sync_with_campaign_timeline
    log_service_call('sync_with_campaign_timeline')
    
    campaign_timeline = parse_timeline_json(campaign_plan.generated_timeline)
    
    if campaign_timeline.present?
      sync_results = sync_milestones_with_timeline(campaign_timeline)
      success_response({ 
        sync_results: sync_results, 
        updated_milestones: sync_results[:updated_count] 
      })
    else
      { success: false, error: 'No campaign timeline available for sync' }
    end
  rescue => e
    handle_service_error(e)
  end

  private

  def calculate_project_status
    milestones = campaign_plan.project_milestones
    
    return { status: 'not_started', progress: 0 } if milestones.empty?
    
    total_milestones = milestones.count
    completed_milestones = milestones.completed.count
    overdue_milestones = milestones.overdue_items.count
    in_progress_milestones = milestones.in_progress.count
    
    overall_progress = (completed_milestones.to_f / total_milestones * 100).round(1)
    
    status = if completed_milestones == total_milestones
      'completed'
    elsif overdue_milestones > 0
      'at_risk'
    elsif in_progress_milestones > 0
      'in_progress'
    else
      'not_started'
    end
    
    {
      status: status,
      progress: overall_progress,
      total_milestones: total_milestones,
      completed: completed_milestones,
      in_progress: in_progress_milestones,
      overdue: overdue_milestones,
      upcoming: milestones.due_soon.count
    }
  end

  def generate_milestone_summary
    milestones = campaign_plan.project_milestones.includes(:assigned_to)
    
    {
      by_status: milestones.group(:status).count,
      by_priority: milestones.group(:priority).count,
      by_type: milestones.group(:milestone_type).count,
      overdue_critical: milestones.overdue_items.high_priority.count,
      due_this_week: milestones.due_soon.count,
      recent_completed: milestones.completed.recent.limit(5).map(&:project_analytics)
    }
  end

  def calculate_resource_allocation
    milestones = campaign_plan.project_milestones
    total_estimated_hours = milestones.sum(:estimated_hours) || 0
    total_actual_hours = milestones.sum(:actual_hours) || 0
    
    resource_by_type = {}
    total_cost = 0
    
    milestones.each do |milestone|
      resources = parse_json_field(milestone.resources_required) || []
      resources.each do |resource|
        type = resource['type'] || 'unspecified'
        resource_by_type[type] ||= { count: 0, cost: 0 }
        resource_by_type[type][:count] += 1
        resource_by_type[type][:cost] += resource['cost'].to_f
        total_cost += resource['cost'].to_f
      end
    end
    
    {
      total_estimated_hours: total_estimated_hours,
      total_actual_hours: total_actual_hours,
      hour_variance: total_actual_hours - total_estimated_hours,
      by_resource_type: resource_by_type,
      total_estimated_cost: total_cost,
      resource_utilization: calculate_resource_utilization(resource_by_type)
    }
  end

  def generate_timeline_data
    milestones = campaign_plan.project_milestones.by_due_date
    
    timeline_events = milestones.map do |milestone|
      {
        id: milestone.id,
        title: milestone.name,
        start: milestone.started_at || milestone.created_at,
        end: milestone.due_date,
        completed: milestone.completed_at,
        status: milestone.status,
        priority: milestone.priority,
        type: milestone.milestone_type,
        progress: milestone.completion_percentage
      }
    end
    
    {
      events: timeline_events,
      project_start: milestones.minimum(:created_at),
      project_end: milestones.maximum(:due_date),
      critical_path: calculate_critical_path(milestones)
    }
  end

  def calculate_project_risks
    milestones = campaign_plan.project_milestones
    
    risk_factors = {
      overdue_milestones: milestones.overdue_items.count,
      high_priority_pending: milestones.pending.high_priority.count,
      resource_conflicts: detect_resource_conflicts,
      dependency_issues: detect_dependency_issues(milestones),
      timeline_compression: calculate_timeline_pressure
    }
    
    overall_risk = calculate_overall_risk_score(risk_factors)
    
    {
      overall_risk_level: overall_risk[:level],
      risk_score: overall_risk[:score],
      risk_factors: risk_factors,
      mitigation_suggestions: generate_risk_mitigation_suggestions(risk_factors)
    }
  end

  def calculate_team_workload
    return {} unless current_user
    
    team_members = User.joins(:assigned_milestones).where(
      project_milestones: { campaign_plan: campaign_plan }
    ).distinct
    
    workload_data = team_members.map do |member|
      member_milestones = campaign_plan.project_milestones.assigned_to_user(member)
      
      {
        user: member,
        assigned_count: member_milestones.count,
        in_progress_count: member_milestones.in_progress.count,
        overdue_count: member_milestones.overdue_items.count,
        estimated_hours: member_milestones.sum(:estimated_hours) || 0,
        completion_rate: calculate_user_completion_rate(member_milestones),
        workload_level: assess_workload_level(member_milestones)
      }
    end
    
    { team_workload: workload_data, workload_balance: assess_team_balance(workload_data) }
  end

  def handle_milestone_status_change(milestone)
    case milestone.status
    when 'completed'
      # Check if this completion unlocks other milestones
      unlock_dependent_milestones(milestone)
      # Update campaign plan progress if needed
      update_campaign_progress
    when 'overdue'
      # Alert stakeholders about overdue milestone
      log_overdue_milestone(milestone)
    end
  end

  def update_campaign_timeline_if_needed(milestone)
    return unless milestone.milestone_type == 'launch'
    
    # If a launch milestone is completed, it might affect the campaign timeline
    if campaign_plan.generated_timeline.present?
      timeline_data = parse_json_field(campaign_plan.generated_timeline)
      # Update timeline logic would go here
    end
  end

  def get_next_available_milestones
    campaign_plan.project_milestones.pending
                 .select { |m| m.can_be_started? }
                 .sort_by(&:due_date)
                 .first(3)
                 .map(&:project_analytics)
  end

  def merge_resource_allocations(current_resources, new_allocation)
    updated_resources = current_resources.dup
    
    new_allocation.each do |resource|
      existing_index = updated_resources.find_index { |r| r['id'] == resource['id'] }
      
      if existing_index
        updated_resources[existing_index].merge!(resource)
      else
        updated_resources << resource
      end
    end
    
    updated_resources
  end

  def calculate_milestone_duration(milestone)
    if milestone.completed_at && milestone.started_at
      ((milestone.completed_at - milestone.started_at) / 1.day).ceil
    elsif milestone.started_at
      ((Date.current - milestone.started_at.to_date)).to_i
    else
      milestone.estimated_hours ? (milestone.estimated_hours / 8.0).ceil : 1
    end
  end

  def calculate_project_timeline
    milestones = campaign_plan.project_milestones.by_due_date
    
    return {} if milestones.empty?
    
    {
      start_date: milestones.minimum(:created_at),
      end_date: milestones.maximum(:due_date),
      duration_days: calculate_total_project_duration,
      phases: group_milestones_by_phase(milestones)
    }
  end

  def sync_milestones_with_timeline(timeline_data)
    updated_count = 0
    
    # Extract timeline phases and match with milestones
    phases = timeline_data['phases'] || timeline_data[:phases] || []
    
    phases.each do |phase|
      matching_milestones = find_matching_milestones(phase)
      matching_milestones.each do |milestone|
        if update_milestone_from_timeline_phase(milestone, phase)
          updated_count += 1
        end
      end
    end
    
    { updated_count: updated_count, total_phases: phases.count }
  end

  def calculate_resource_utilization(resource_by_type)
    return {} if resource_by_type.empty?
    
    total_resources = resource_by_type.values.sum { |r| r[:count] }
    
    resource_by_type.transform_values do |resource_data|
      {
        count: resource_data[:count],
        cost: resource_data[:cost],
        utilization_percentage: (resource_data[:count].to_f / total_resources * 100).round(1)
      }
    end
  end

  def calculate_critical_path(milestones)
    # Simplified critical path calculation
    critical_milestones = milestones.select { |m| m.high_priority? || m.milestone_type == 'launch' }
    
    critical_milestones.sort_by(&:due_date).map do |milestone|
      {
        id: milestone.id,
        name: milestone.name,
        due_date: milestone.due_date,
        status: milestone.status,
        dependencies: parse_json_field(milestone.dependencies) || []
      }
    end
  end

  def detect_resource_conflicts
    # Logic to detect resource conflicts between milestones
    0 # Placeholder - would implement actual conflict detection
  end

  def detect_dependency_issues(milestones)
    issues = []
    
    milestones.each do |milestone|
      deps = parse_json_field(milestone.dependencies) || []
      deps.each do |dep|
        if dep['required'] && !dep['completed']
          issues << {
            milestone_id: milestone.id,
            dependency: dep['name'],
            issue: 'blocking_dependency'
          }
        end
      end
    end
    
    issues.count
  end

  def calculate_timeline_pressure
    milestones = campaign_plan.project_milestones
    overdue_count = milestones.overdue_items.count
    due_soon_count = milestones.due_soon.count
    
    total_pressure = overdue_count * 3 + due_soon_count
    total_milestones = milestones.count
    
    return 0 if total_milestones.zero?
    
    (total_pressure.to_f / total_milestones * 100).round(1)
  end

  def calculate_overall_risk_score(risk_factors)
    score = (risk_factors[:overdue_milestones] * 10) +
            (risk_factors[:high_priority_pending] * 5) +
            (risk_factors[:resource_conflicts] * 7) +
            (risk_factors[:dependency_issues] * 6) +
            (risk_factors[:timeline_compression] * 0.2)
    
    level = case score
           when 0..20 then 'low'
           when 21..50 then 'medium'
           when 51..80 then 'high'
           else 'critical'
           end
    
    { score: score.round(1), level: level }
  end

  def generate_risk_mitigation_suggestions(risk_factors)
    suggestions = []
    
    suggestions << 'Address overdue milestones immediately' if risk_factors[:overdue_milestones] > 0
    suggestions << 'Prioritize high-priority pending tasks' if risk_factors[:high_priority_pending] > 0
    suggestions << 'Resolve resource conflicts through reallocation' if risk_factors[:resource_conflicts] > 0
    suggestions << 'Clear dependency blockers to unblock progress' if risk_factors[:dependency_issues] > 0
    suggestions << 'Consider timeline extension or scope reduction' if risk_factors[:timeline_compression] > 50
    
    suggestions
  end

  def calculate_user_completion_rate(user_milestones)
    total = user_milestones.count
    completed = user_milestones.completed.count
    
    return 0 if total.zero?
    (completed.to_f / total * 100).round(1)
  end

  def assess_workload_level(user_milestones)
    in_progress = user_milestones.in_progress.count
    estimated_hours = user_milestones.in_progress.sum(:estimated_hours) || 0
    
    case
    when estimated_hours > 60 then 'overloaded'
    when estimated_hours > 40 then 'heavy'
    when estimated_hours > 20 then 'moderate'
    else 'light'
    end
  end

  def assess_team_balance(workload_data)
    return 'balanced' if workload_data.empty?
    
    workload_levels = workload_data.map { |w| w[:estimated_hours] }
    avg_workload = workload_levels.sum.to_f / workload_levels.count
    variance = workload_levels.map { |w| (w - avg_workload) ** 2 }.sum / workload_levels.count
    
    case Math.sqrt(variance)
    when 0..10 then 'balanced'
    when 11..25 then 'slightly_unbalanced'
    else 'unbalanced'
    end
  end

  def unlock_dependent_milestones(completed_milestone)
    # Find milestones that depend on this completed milestone
    dependent_milestones = campaign_plan.project_milestones
    
    dependent_milestones.each do |milestone|
      next if milestone.dependencies.blank?
      
      dependencies = parse_json_field(milestone.dependencies) || []
      updated = false
      dependencies.each do |dep|
        # Handle both string and integer milestone_id
        dep_milestone_id = dep['milestone_id'].respond_to?(:to_i) ? dep['milestone_id'].to_i : dep['milestone_id']
        if dep_milestone_id == completed_milestone.id
          dep['completed'] = true
          updated = true
        end
      end
      
      if updated
        milestone.update(dependencies: dependencies.to_json)
      end
    end
  end

  def update_campaign_progress
    # Update the campaign plan's overall progress based on milestone completion
    project_status = calculate_project_status
    
    # Update campaign metadata with project progress
    metadata = campaign_plan.metadata || {}
    metadata['project_progress'] = project_status[:progress]
    metadata['project_status'] = project_status[:status]
    
    campaign_plan.update(metadata: metadata)
  end

  def log_overdue_milestone(milestone)
    Rails.logger.warn "Milestone overdue: #{milestone.name} (ID: #{milestone.id}) for Campaign: #{campaign_plan.name}"
  end

  def calculate_total_project_duration
    milestones = campaign_plan.project_milestones.by_due_date
    return 0 if milestones.empty?
    
    start_date = milestones.minimum(:created_at)&.to_date
    end_date = milestones.maximum(:due_date)
    
    return 0 unless start_date && end_date
    
    (end_date - start_date).to_i
  end

  def group_milestones_by_phase(milestones)
    phases = {}
    
    milestones.each do |milestone|
      phase = milestone.milestone_type
      phases[phase] ||= {
        name: phase.humanize,
        milestones: [],
        progress: 0
      }
      phases[phase][:milestones] << milestone.project_analytics
    end
    
    # Calculate progress for each phase
    phases.each do |phase_name, phase_data|
      total = phase_data[:milestones].count
      completed = phase_data[:milestones].count { |m| m[:status] == 'completed' }
      phase_data[:progress] = total > 0 ? (completed.to_f / total * 100).round(1) : 0
    end
    
    phases.values
  end

  def find_matching_milestones(phase)
    phase_name = phase['name'] || phase[:name]
    return [] unless phase_name
    
    # Match milestones by type or name similarity (use LIKE for SQLite compatibility)
    campaign_plan.project_milestones.where(milestone_type: phase_name.downcase)
                 .or(campaign_plan.project_milestones.where('name LIKE ?', "%#{phase_name}%"))
  end

  def update_milestone_from_timeline_phase(milestone, phase)
    updates = {}
    
    if phase['due_date'] || phase[:due_date]
      new_due_date = Date.parse((phase['due_date'] || phase[:due_date]).to_s)
      updates[:due_date] = new_due_date if new_due_date != milestone.due_date
    end
    
    if phase['estimated_hours'] || phase[:estimated_hours]
      new_hours = (phase['estimated_hours'] || phase[:estimated_hours]).to_f
      updates[:estimated_hours] = new_hours if new_hours != milestone.estimated_hours
    end
    
    return false if updates.empty?
    
    milestone.update(updates)
  end

  def parse_json_field(field)
    return [] if field.blank?
    
    begin
      if field.is_a?(String)
        parsed = JSON.parse(field)
        # For dependencies, always return an array. If it's a valid Hash but not the expected format, return empty array
        if parsed.is_a?(Array)
          parsed
        elsif parsed.is_a?(Hash) && parsed.key?('milestone_id')
          # If it's a single dependency object, wrap it in an array
          [parsed]
        else
          # Otherwise return empty array for dependencies
          []
        end
      else
        # If it's already parsed, ensure we return an array for dependencies
        if field.is_a?(Array)
          field
        elsif field.is_a?(Hash) && field.key?('milestone_id')
          [field]
        else
          []
        end
      end
    rescue JSON::ParserError, TypeError, NoMethodError => e
      # Return empty array for any parsing errors
      []
    end
  end

  def parse_timeline_json(field)
    return {} if field.blank?
    
    begin
      if field.is_a?(String)
        JSON.parse(field)
      elsif field.is_a?(Hash)
        field
      else
        {}
      end
    rescue JSON::ParserError, TypeError, NoMethodError => e
      # Return empty hash for any parsing errors
      {}
    end
  end

  # Helper method for handling service errors
  def handle_service_error(error, context = {})
    Rails.logger.error "Service Error in #{self.class}: #{error.message}"
    Rails.logger.error "Context: #{context.inspect}" if context.any?
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
    
    # Return a structured error response
    {
      success: false,
      error: error.message,
      context: context
    }
  end

  # Helper method for successful service responses
  def success_response(data = {})
    {
      success: true,
      data: data
    }
  end

  # Helper method for logging service calls
  def log_service_call(service_name, params = {})
    Rails.logger.info "Service Call: #{service_name} with params: #{params.inspect}"
  end
end