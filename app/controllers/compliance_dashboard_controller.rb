class ComplianceDashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :set_compliance_requirement, only: [:show, :update, :destroy, :assess, :generate_report]
  
  def index
    @compliance_requirements = current_user.compliance_requirements
                                          .includes(:compliance_assessments, :compliance_reports)
    
    # Apply filters
    @compliance_requirements = apply_filters(@compliance_requirements)
    
    # Paginate results
    @compliance_requirements = @compliance_requirements.page(params[:page]).per(20)
    
    # Dashboard metrics
    @dashboard_metrics = calculate_dashboard_metrics
    
    respond_to do |format|
      format.html
      format.json { render json: dashboard_json_response }
    end
  end

  def show
    @assessment_history = @compliance_requirement.compliance_assessments
                                                .order(created_at: :desc)
                                                .limit(10)
    
    @related_requirements = current_user.compliance_requirements
                                       .where(compliance_type: @compliance_requirement.compliance_type)
                                       .where.not(id: @compliance_requirement.id)
                                       .limit(5)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          requirement: @compliance_requirement.as_json(include: [:compliance_assessments, :compliance_reports]),
          assessment_history: @assessment_history.as_json,
          related_requirements: @related_requirements.as_json,
          metrics: requirement_specific_metrics(@compliance_requirement)
        }
      end
    end
  end

  def new
    @compliance_requirement = current_user.compliance_requirements.build
    
    respond_to do |format|
      format.html
      format.json { render json: { requirement: @compliance_requirement } }
    end
  end

  def create
    service_result = ComplianceManagementService.call(
      user: current_user,
      params: { action: 'create_requirement', requirement: compliance_requirement_params }
    )

    if service_result[:success]
      @compliance_requirement = service_result[:data][:requirement]
      
      respond_to do |format|
        format.html do
          redirect_to compliance_dashboard_path(@compliance_requirement),
                      notice: 'Compliance requirement was successfully created.'
        end
        format.json do
          render json: {
            success: true,
            requirement: @compliance_requirement.as_json,
            next_actions: service_result[:data][:next_actions],
            message: service_result[:data][:message]
          }, status: :created
        end
      end
    else
      @compliance_requirement = current_user.compliance_requirements.build(compliance_requirement_params)
      
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json do
          render json: {
            success: false,
            errors: service_result[:validation_errors] || [service_result[:error]],
            requirement: @compliance_requirement.as_json
          }, status: :unprocessable_entity
        end
      end
    end
  end

  def update
    if @compliance_requirement.update(compliance_requirement_params)
      respond_to do |format|
        format.html do
          redirect_to compliance_dashboard_path(@compliance_requirement),
                      notice: 'Compliance requirement was successfully updated.'
        end
        format.json do
          render json: {
            success: true,
            requirement: @compliance_requirement.as_json,
            message: 'Requirement updated successfully'
          }
        end
      end
    else
      respond_to do |format|
        format.html { render :show, status: :unprocessable_entity }
        format.json do
          render json: {
            success: false,
            errors: @compliance_requirement.errors.full_messages,
            requirement: @compliance_requirement.as_json
          }, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    @compliance_requirement.destroy
    
    respond_to do |format|
      format.html do
        redirect_to compliance_dashboard_index_path,
                    notice: 'Compliance requirement was successfully deleted.'
      end
      format.json do
        render json: {
          success: true,
          message: 'Requirement deleted successfully'
        }
      end
    end
  end

  def assess
    service_result = ComplianceManagementService.call(
      user: current_user,
      params: {
        action: 'assess_compliance',
        requirement_id: @compliance_requirement.id
      }
    )

    respond_to do |format|
      format.html do
        if service_result[:success]
          redirect_to compliance_dashboard_path(@compliance_requirement),
                      notice: 'Compliance assessment completed successfully.'
        else
          redirect_to compliance_dashboard_path(@compliance_requirement),
                      alert: "Assessment failed: #{service_result[:error]}"
        end
      end
      format.json { render json: service_result }
    end
  end

  def generate_report
    service_result = ComplianceManagementService.call(
      user: current_user,
      params: {
        action: 'generate_report',
        requirement_id: @compliance_requirement.id,
        format: params[:format] || 'json'
      }
    )

    respond_to do |format|
      format.html do
        if service_result[:success]
          redirect_to compliance_dashboard_path(@compliance_requirement),
                      notice: 'Compliance report generated successfully.'
        else
          redirect_to compliance_dashboard_path(@compliance_requirement),
                      alert: "Report generation failed: #{service_result[:error]}"
        end
      end
      format.json { render json: service_result }
      format.pdf do
        if service_result[:success] && service_result[:data][:pdf_path]
          send_file service_result[:data][:pdf_path],
                    filename: "compliance_report_#{@compliance_requirement.id}.pdf",
                    type: 'application/pdf',
                    disposition: 'attachment'
        else
          render json: { error: 'PDF generation failed' }, status: :unprocessable_entity
        end
      end
    end
  end

  def risk_analysis
    service_result = ComplianceManagementService.call(
      user: current_user,
      params: {
        action: 'risk_analysis',
        scope: params[:scope] || 'all'
      }
    )

    @risk_analysis = service_result[:data] if service_result[:success]

    respond_to do |format|
      format.html
      format.json { render json: service_result }
    end
  end

  def monitoring
    service_result = ComplianceManagementService.call(
      user: current_user,
      params: { action: 'monitoring_check' }
    )

    @monitoring_results = service_result[:data] if service_result[:success]

    respond_to do |format|
      format.html
      format.json { render json: service_result }
    end
  end

  def bulk_update
    service_result = ComplianceManagementService.call(
      user: current_user,
      params: {
        action: 'bulk_update',
        requirements: params[:requirements]
      }
    )

    respond_to do |format|
      format.json { render json: service_result }
    end
  end

  def export
    @compliance_requirements = current_user.compliance_requirements
                                          .includes(:compliance_assessments, :compliance_reports)

    # Apply any filters
    @compliance_requirements = apply_filters(@compliance_requirements)

    respond_to do |format|
      format.csv do
        send_data generate_csv_export(@compliance_requirements),
                  filename: "compliance_requirements_#{Date.current}.csv",
                  type: 'text/csv'
      end
      format.json do
        render json: {
          requirements: @compliance_requirements.as_json(
            include: [:compliance_assessments, :compliance_reports]
          ),
          export_timestamp: Time.current,
          total_count: @compliance_requirements.count
        }
      end
    end
  end

  def analytics
    @analytics_data = {
      compliance_trends: calculate_compliance_trends,
      risk_distribution: calculate_risk_distribution,
      deadline_analysis: analyze_upcoming_deadlines,
      type_breakdown: analyze_compliance_types,
      performance_metrics: calculate_performance_metrics
    }

    respond_to do |format|
      format.html
      format.json { render json: @analytics_data }
    end
  end

  private

  def set_compliance_requirement
    @compliance_requirement = current_user.compliance_requirements.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html do
        redirect_to compliance_dashboard_index_path,
                    alert: 'Compliance requirement not found.'
      end
      format.json do
        render json: { error: 'Requirement not found' }, status: :not_found
      end
    end
  end

  def compliance_requirement_params
    params.require(:compliance_requirement).permit(
      :name, :compliance_type, :description, :risk_level, :status,
      :implementation_deadline, :next_review_date, :responsible_party,
      :regulatory_reference, :monitoring_frequency,
      custom_rules: {},
      evidence_requirements: [],
      monitoring_criteria: {}
    )
  end

  def apply_filters(requirements)
    requirements = requirements.where(status: params[:status]) if params[:status].present?
    requirements = requirements.where(risk_level: params[:risk_level]) if params[:risk_level].present?
    requirements = requirements.where(compliance_type: params[:compliance_type]) if params[:compliance_type].present?
    
    if params[:overdue] == 'true'
      requirements = requirements.overdue
    elsif params[:due_soon] == 'true'
      requirements = requirements.due_soon
    end

    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      requirements = requirements.where(
        'LOWER(name) LIKE ? OR LOWER(description) LIKE ? OR LOWER(responsible_party) LIKE ?',
        search_term, search_term, search_term
      )
    end

    requirements
  end

  def calculate_dashboard_metrics
    requirements = current_user.compliance_requirements
    
    {
      total_requirements: requirements.count,
      compliant_count: requirements.where(status: 'compliant').count,
      non_compliant_count: requirements.where(status: 'non_compliant').count,
      overdue_count: requirements.overdue.count,
      due_soon_count: requirements.due_soon.count,
      high_risk_count: requirements.high_risk.count,
      average_compliance_score: calculate_average_compliance_score(requirements),
      overall_risk_score: calculate_overall_risk_score(requirements)
    }
  end

  def dashboard_json_response
    {
      requirements: @compliance_requirements.as_json(
        include: {
          compliance_assessments: { only: [:id, :status, :created_at] },
          compliance_reports: { only: [:id, :report_type, :created_at] }
        }
      ),
      metrics: @dashboard_metrics,
      filters: {
        statuses: ComplianceRequirement::STATUSES,
        risk_levels: ComplianceRequirement::RISK_LEVELS,
        compliance_types: ComplianceRequirement::COMPLIANCE_TYPES,
        frequencies: ComplianceRequirement::FREQUENCIES
      },
      pagination: {
        current_page: @compliance_requirements.current_page,
        total_pages: @compliance_requirements.total_pages,
        total_count: @compliance_requirements.total_count
      }
    }
  end

  def requirement_specific_metrics(requirement)
    {
      compliance_percentage: requirement.compliance_percentage,
      risk_score: requirement.risk_score,
      days_until_deadline: (requirement.implementation_deadline.to_date - Date.current).to_i,
      assessment_count: requirement.compliance_assessments.count,
      last_assessment_date: requirement.compliance_assessments.last&.created_at,
      is_overdue: requirement.overdue?,
      needs_review: requirement.needs_review?
    }
  end

  def calculate_average_compliance_score(requirements)
    scores = requirements.map(&:compliance_percentage).compact
    return 0 if scores.empty?
    
    (scores.sum.to_f / scores.length).round(2)
  end

  def calculate_overall_risk_score(requirements)
    return 0 if requirements.empty?
    
    risk_scores = requirements.map(&:risk_score)
    (risk_scores.sum.to_f / risk_scores.length).round(2)
  end

  def generate_csv_export(requirements)
    CSV.generate(headers: true) do |csv|
      csv << [
        'ID', 'Name', 'Type', 'Status', 'Risk Level', 'Compliance %',
        'Implementation Deadline', 'Responsible Party', 'Next Review Date',
        'Created At', 'Updated At'
      ]

      requirements.find_each do |req|
        csv << [
          req.id,
          req.name,
          req.compliance_type,
          req.status,
          req.risk_level,
          req.compliance_percentage,
          req.implementation_deadline.strftime('%Y-%m-%d'),
          req.responsible_party,
          req.next_review_date.strftime('%Y-%m-%d'),
          req.created_at.strftime('%Y-%m-%d %H:%M:%S'),
          req.updated_at.strftime('%Y-%m-%d %H:%M:%S')
        ]
      end
    end
  end

  def calculate_compliance_trends
    # Calculate monthly compliance trends over the last 12 months
    12.downto(0).map do |months_ago|
      date = months_ago.months.ago.beginning_of_month
      end_date = date.end_of_month
      
      requirements_at_date = current_user.compliance_requirements
                                        .where('created_at <= ?', end_date)
      
      {
        month: date.strftime('%Y-%m'),
        total: requirements_at_date.count,
        compliant: requirements_at_date.where(status: 'compliant').count,
        non_compliant: requirements_at_date.where(status: 'non_compliant').count,
        average_score: calculate_average_compliance_score(requirements_at_date)
      }
    end
  end

  def calculate_risk_distribution
    requirements = current_user.compliance_requirements
    
    ComplianceRequirement::RISK_LEVELS.map do |level|
      count = requirements.where(risk_level: level).count
      {
        risk_level: level,
        count: count,
        percentage: requirements.count > 0 ? (count.to_f / requirements.count * 100).round(2) : 0
      }
    end
  end

  def analyze_upcoming_deadlines
    next_30_days = current_user.compliance_requirements
                              .where(implementation_deadline: Time.current..30.days.from_now)
                              .order(:implementation_deadline)

    next_60_days = current_user.compliance_requirements
                              .where(implementation_deadline: 30.days.from_now..60.days.from_now)
                              .order(:implementation_deadline)

    {
      next_30_days: next_30_days.map { |r| 
        { 
          id: r.id, 
          name: r.name, 
          deadline: r.implementation_deadline.strftime('%Y-%m-%d'),
          risk_level: r.risk_level,
          days_remaining: (r.implementation_deadline.to_date - Date.current).to_i
        }
      },
      next_60_days: next_60_days.map { |r| 
        { 
          id: r.id, 
          name: r.name, 
          deadline: r.implementation_deadline.strftime('%Y-%m-%d'),
          risk_level: r.risk_level,
          days_remaining: (r.implementation_deadline.to_date - Date.current).to_i
        }
      }
    }
  end

  def analyze_compliance_types
    requirements = current_user.compliance_requirements
    
    ComplianceRequirement::COMPLIANCE_TYPES.map do |type|
      type_requirements = requirements.where(compliance_type: type)
      count = type_requirements.count
      
      {
        compliance_type: type,
        count: count,
        percentage: requirements.count > 0 ? (count.to_f / requirements.count * 100).round(2) : 0,
        compliant_count: type_requirements.where(status: 'compliant').count,
        average_risk_score: type_requirements.empty? ? 0 : type_requirements.average('(CASE 
          WHEN risk_level = "critical" THEN 100 
          WHEN risk_level = "high" THEN 75 
          WHEN risk_level = "medium" THEN 50 
          WHEN risk_level = "low" THEN 25 
          ELSE 0 END)')&.round(2) || 0
      }
    end
  end

  def calculate_performance_metrics
    requirements = current_user.compliance_requirements
    
    {
      total_requirements: requirements.count,
      compliance_rate: requirements.count > 0 ? (requirements.where(status: 'compliant').count.to_f / requirements.count * 100).round(2) : 0,
      average_implementation_time: calculate_average_implementation_time,
      on_time_completion_rate: calculate_on_time_completion_rate,
      high_risk_resolution_rate: calculate_high_risk_resolution_rate
    }
  end

  def calculate_average_implementation_time
    completed_requirements = current_user.compliance_requirements
                                        .where(status: 'compliant')
                                        .where.not(updated_at: nil)
    
    return 0 if completed_requirements.empty?
    
    total_days = completed_requirements.sum do |req|
      (req.updated_at.to_date - req.created_at.to_date).to_i
    end
    
    (total_days.to_f / completed_requirements.count).round(2)
  end

  def calculate_on_time_completion_rate
    completed_requirements = current_user.compliance_requirements
                                        .where(status: 'compliant')
    
    return 0 if completed_requirements.empty?
    
    on_time_count = completed_requirements.count do |req|
      req.updated_at <= req.implementation_deadline
    end
    
    (on_time_count.to_f / completed_requirements.count * 100).round(2)
  end

  def calculate_high_risk_resolution_rate
    high_risk_requirements = current_user.compliance_requirements.high_risk
    
    return 0 if high_risk_requirements.empty?
    
    resolved_count = high_risk_requirements.where(status: 'compliant').count
    (resolved_count.to_f / high_risk_requirements.count * 100).round(2)
  end
end