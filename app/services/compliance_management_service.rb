class ComplianceManagementService < ApplicationService
  def initialize(user:, params: {})
    @user = user
    @params = params
    log_service_call('ComplianceManagementService', { user_id: user&.id, action: @params[:action] })
  end

  def call
    raise ArgumentError, "User cannot be nil" if @user.nil?
    
    case @params[:action]
    when 'create_requirement'
      create_compliance_requirement
    when 'assess_compliance'
      assess_compliance_status
    when 'generate_report'
      generate_compliance_report
    when 'risk_analysis'
      perform_risk_analysis
    when 'monitoring_check'
      perform_monitoring_check
    when 'bulk_update'
      bulk_update_requirements
    else
      handle_service_error(ArgumentError.new("Unknown action: #{@params[:action]}"))
    end
  rescue StandardError => e
    handle_service_error(e, { action: @params[:action], user_id: @user&.id })
  end

  private

  def create_compliance_requirement
    requirement = @user.compliance_requirements.build(requirement_params)
    
    if requirement.save
      schedule_initial_assessment(requirement)
      schedule_monitoring(requirement)
      success_response({
        requirement: requirement,
        message: 'Compliance requirement created successfully',
        next_actions: suggested_next_actions(requirement)
      })
    else
      {
        success: false,
        error: 'Failed to create compliance requirement',
        validation_errors: requirement.errors.full_messages
      }
    end
  end

  def assess_compliance_status
    requirement = find_requirement(@params[:requirement_id])
    return requirement_not_found_error unless requirement

    assessment_result = ComplianceAssessmentEngine.new(requirement).perform_assessment

    if assessment_result[:success]
      update_requirement_status(requirement, assessment_result)
      success_response({
        assessment: assessment_result,
        requirement: requirement.reload,
        recommendations: generate_recommendations(requirement, assessment_result)
      })
    else
      {
        success: false,
        error: 'Assessment failed',
        details: assessment_result[:error]
      }
    end
  end

  def generate_compliance_report
    requirement = find_requirement(@params[:requirement_id])
    return requirement_not_found_error unless requirement

    report_data = compile_compliance_report(requirement)
    
    if @params[:format] == 'pdf'
      pdf_path = generate_pdf_report(requirement, report_data)
      success_response({
        report_data: report_data,
        pdf_path: pdf_path,
        download_url: "/compliance/reports/#{requirement.id}/download"
      })
    else
      success_response({
        report_data: report_data,
        format: 'json'
      })
    end
  end

  def perform_risk_analysis
    requirements = scope_requirements_for_analysis
    
    risk_matrix = calculate_risk_matrix(requirements)
    critical_risks = identify_critical_risks(requirements)
    mitigation_strategies = recommend_mitigation_strategies(critical_risks)
    
    success_response({
      risk_matrix: risk_matrix,
      critical_risks: critical_risks,
      mitigation_strategies: mitigation_strategies,
      overall_risk_score: calculate_overall_risk_score(requirements),
      trends: analyze_risk_trends(requirements)
    })
  end

  def perform_monitoring_check
    due_requirements = @user.compliance_requirements.needs_review
    overdue_requirements = @user.compliance_requirements.overdue
    
    monitoring_results = []
    
    due_requirements.each do |requirement|
      check_result = perform_individual_monitoring_check(requirement)
      monitoring_results << check_result
      
      if check_result[:requires_attention]
        send_compliance_alert(requirement, check_result)
      end
    end
    
    success_response({
      total_checked: due_requirements.count,
      overdue_count: overdue_requirements.count,
      monitoring_results: monitoring_results,
      alerts_sent: monitoring_results.count { |r| r[:requires_attention] }
    })
  end

  def bulk_update_requirements
    requirement_updates = @params[:requirements] || []
    results = []
    
    requirement_updates.each do |update_data|
      requirement = find_requirement(update_data[:id])
      next unless requirement
      
      if requirement.update(update_data[:attributes])
        results << { id: requirement.id, status: 'updated', requirement: requirement }
      else
        results << { id: requirement.id, status: 'failed', errors: requirement.errors.full_messages }
      end
    end
    
    success_response({
      updated_count: results.count { |r| r[:status] == 'updated' },
      failed_count: results.count { |r| r[:status] == 'failed' },
      results: results
    })
  end

  # Assessment Engine - embedded class for complex compliance evaluation
  class ComplianceAssessmentEngine
    def initialize(requirement)
      @requirement = requirement
    end

    def perform_assessment
      {
        success: true,
        compliance_score: calculate_compliance_score,
        status: determine_compliance_status,
        evidence_review: review_evidence,
        gap_analysis: perform_gap_analysis,
        next_review_date: calculate_next_review_date,
        timestamp: Time.current
      }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    private

    def calculate_compliance_score
      # Complex scoring algorithm based on multiple factors
      base_score = 50
      
      # Factor in evidence completeness
      evidence_score = (@requirement.evidence_requirements&.length || 0) > 0 ? 30 : 0
      
      # Factor in monitoring criteria fulfillment
      monitoring_score = (@requirement.monitoring_criteria&.any? || false) ? 20 : 0
      
      # Factor in custom rules compliance
      custom_rules_score = assess_custom_rules_compliance
      
      total_score = base_score + evidence_score + monitoring_score + custom_rules_score
      [total_score, 100].min
    end

    def determine_compliance_status
      score = calculate_compliance_score
      
      case score
      when 90..100 then 'compliant'
      when 70..89 then 'monitoring'
      when 50..69 then 'active'
      else 'non_compliant'
      end
    end

    def review_evidence
      evidence_items = @requirement.evidence_requirements || []
      
      evidence_items.map do |item|
        {
          name: item['name'],
          type: item['type'],
          status: item['status'] || 'pending',
          last_updated: item['last_updated'],
          completeness: assess_evidence_completeness(item)
        }
      end
    end

    def perform_gap_analysis
      required_criteria = @requirement.monitoring_criteria || {}
      current_implementation = assess_current_implementation
      
      gaps = []
      required_criteria.each do |criterion, requirements|
        implementation = current_implementation[criterion]
        if !implementation || !meets_requirements?(implementation, requirements)
          gaps << {
            criterion: criterion,
            required: requirements,
            current: implementation,
            severity: calculate_gap_severity(requirements)
          }
        end
      end
      
      gaps
    end

    def calculate_next_review_date
      case @requirement.monitoring_frequency
      when 'daily' then 1.day.from_now
      when 'weekly' then 1.week.from_now
      when 'monthly' then 1.month.from_now
      when 'quarterly' then 3.months.from_now
      when 'annual' then 1.year.from_now
      else 1.month.from_now
      end
    end

    def assess_custom_rules_compliance
      return 0 unless @requirement.custom_rules.present?
      
      total_rules = @requirement.custom_rules.count
      compliant_rules = @requirement.custom_rules.count { |_, config| config['compliant'] == true }
      
      return 0 if total_rules.zero?
      
      (compliant_rules.to_f / total_rules) * 30
    end

    def assess_evidence_completeness(evidence_item)
      # Simple completeness check - could be enhanced with more sophisticated logic
      return 100 if evidence_item['status'] == 'complete'
      return 50 if evidence_item['status'] == 'partial'
      0
    end

    def assess_current_implementation
      # Placeholder for actual implementation assessment
      # This would integrate with actual system monitoring and data collection
      {}
    end

    def meets_requirements?(implementation, requirements)
      # Simplified requirements checking - would be more complex in practice
      implementation.present? && implementation['status'] == 'compliant'
    end

    def calculate_gap_severity(requirements)
      return 'critical' if requirements['critical'] == true
      return 'high' if requirements['priority'] == 'high'
      'medium'
    end
  end

  def requirement_params
    req_params = @params[:requirement]
    return {} if req_params.blank?
    
    # Handle both ActionController::Parameters and Hash
    if req_params.respond_to?(:permit)
      req_params.permit(
        :name, :compliance_type, :description, :risk_level, :status,
        :implementation_deadline, :next_review_date, :responsible_party,
        :regulatory_reference, :monitoring_frequency,
        custom_rules: {},
        evidence_requirements: [],
        monitoring_criteria: {}
      )
    else
      # For plain hash parameters (in tests)
      req_params.slice(
        :name, :compliance_type, :description, :risk_level, :status,
        :implementation_deadline, :next_review_date, :responsible_party,
        :regulatory_reference, :monitoring_frequency, :custom_rules,
        :evidence_requirements, :monitoring_criteria
      ).with_indifferent_access
    end
  end

  def find_requirement(id)
    @user.compliance_requirements.find_by(id: id)
  end

  def requirement_not_found_error
    {
      success: false,
      error: 'Compliance requirement not found',
      code: 'REQUIREMENT_NOT_FOUND'
    }
  end

  def schedule_initial_assessment(requirement)
    ComplianceAssessmentJob.set(wait: 1.hour).perform_later(requirement.id)
  end

  def schedule_monitoring(requirement)
    case requirement.monitoring_frequency
    when 'daily'
      DailyComplianceCheckJob.set(wait: 1.day).perform_later(requirement.id)
    when 'weekly'
      WeeklyComplianceCheckJob.set(wait: 1.week).perform_later(requirement.id)
    when 'monthly'
      MonthlyComplianceCheckJob.set(wait: 1.month).perform_later(requirement.id)
    end
  end

  def suggested_next_actions(requirement)
    actions = []
    
    actions << 'Upload evidence documents' if requirement.evidence_requirements.present?
    actions << 'Configure monitoring criteria' if requirement.monitoring_criteria&.empty?
    actions << 'Set up automated alerts' if requirement.high_risk?
    actions << 'Schedule team training' if requirement.compliance_type.in?(%w[gdpr hipaa])
    
    actions
  end

  def update_requirement_status(requirement, assessment_result)
    requirement.update!(
      status: assessment_result[:status],
      next_review_date: assessment_result[:next_review_date]
    )
  end

  def generate_recommendations(requirement, assessment_result)
    recommendations = []
    
    if assessment_result[:compliance_score] && assessment_result[:compliance_score] < 70
      recommendations << 'Immediate action required to improve compliance score'
    end
    
    assessment_result[:gap_analysis]&.each do |gap|
      if gap[:severity] == 'critical'
        recommendations << "Critical gap in #{gap[:criterion]} - requires immediate attention"
      end
    end
    
    if requirement.overdue?
      recommendations << 'Implementation deadline has passed - escalation may be required'
    end
    
    recommendations
  end

  def compile_compliance_report(requirement)
    {
      requirement: requirement,
      assessments: requirement.compliance_assessments.recent.limit(10),
      current_status: {
        compliance_percentage: requirement.compliance_percentage,
        risk_score: requirement.risk_score,
        status: requirement.status,
        last_assessed: requirement.compliance_assessments.last&.created_at
      },
      timeline: compile_compliance_timeline(requirement),
      recommendations: generate_recommendations(requirement, {})
    }
  end

  def compile_compliance_timeline(requirement)
    events = []
    
    # Add key requirement events
    events << {
      date: requirement.created_at,
      type: 'created',
      description: 'Compliance requirement created'
    }
    
    # Add assessment events
    requirement.compliance_assessments.order(:created_at).each do |assessment|
      events << {
        date: assessment.created_at,
        type: 'assessment',
        description: "Assessment completed - #{assessment.status}"
      }
    end
    
    events.sort_by { |event| event[:date] }.reverse
  end

  def generate_pdf_report(requirement, report_data)
    # Placeholder for PDF generation logic
    # Would integrate with a PDF library like Prawn
    "/tmp/compliance_report_#{requirement.id}_#{Time.current.to_i}.pdf"
  end

  def scope_requirements_for_analysis
    case @params[:scope]
    when 'high_risk'
      @user.compliance_requirements.high_risk
    when 'overdue'
      @user.compliance_requirements.overdue
    when 'active'
      @user.compliance_requirements.active
    else
      @user.compliance_requirements
    end
  end

  def calculate_risk_matrix(requirements)
    matrix = { 'low' => [], 'medium' => [], 'high' => [], 'critical' => [] }
    
    requirements.each do |req|
      matrix[req.risk_level] << {
        id: req.id,
        name: req.name,
        risk_score: req.risk_score,
        status: req.status
      }
    end
    
    matrix
  end

  def identify_critical_risks(requirements)
    requirements.select(&:high_risk?).map do |req|
      {
        requirement: req,
        risk_factors: analyze_risk_factors(req),
        impact_assessment: assess_potential_impact(req),
        urgency_score: calculate_urgency_score(req)
      }
    end.sort_by { |risk| -risk[:urgency_score] }
  end

  def recommend_mitigation_strategies(critical_risks)
    critical_risks.map do |risk|
      {
        requirement_id: risk[:requirement].id,
        strategies: generate_mitigation_strategies(risk[:requirement]),
        timeline: suggest_mitigation_timeline(risk[:requirement]),
        resources_needed: identify_required_resources(risk[:requirement])
      }
    end
  end

  def calculate_overall_risk_score(requirements)
    return 0 if requirements.empty?
    
    total_score = requirements.sum(&:risk_score)
    average_score = total_score.to_f / requirements.count
    
    # Weight by criticality
    critical_count = requirements.count { |r| r.risk_level == 'critical' }
    critical_weight = critical_count > 0 ? (critical_count.to_f / requirements.count) * 1.5 : 1.0
    
    (average_score * critical_weight).round(2)
  end

  def analyze_risk_trends(requirements)
    # Placeholder for trend analysis
    # Would analyze historical data to identify patterns
    {
      trend_direction: 'stable',
      high_risk_change: 0,
      compliance_trend: 'improving'
    }
  end

  def perform_individual_monitoring_check(requirement)
    {
      requirement_id: requirement.id,
      last_check: Time.current,
      status: requirement.status,
      requires_attention: requirement.overdue? || requirement.needs_review?,
      next_action: determine_next_monitoring_action(requirement)
    }
  end

  def send_compliance_alert(requirement, check_result)
    ComplianceAlertJob.perform_later(
      requirement.id,
      check_result[:next_action],
      @user.id
    )
  end

  def determine_next_monitoring_action(requirement)
    return 'immediate_review' if requirement.overdue?
    return 'schedule_assessment' if requirement.needs_review?
    return 'update_evidence' if requirement.compliance_percentage < 50
    'monitor'
  end

  def analyze_risk_factors(requirement)
    factors = []
    factors << 'overdue_deadline' if requirement.overdue?
    factors << 'high_risk_classification' if requirement.high_risk?
    factors << 'low_compliance_score' if requirement.compliance_percentage < 50
    factors << 'regulatory_scrutiny' if requirement.compliance_type.in?(%w[gdpr hipaa sox])
    factors
  end

  def assess_potential_impact(requirement)
    base_impact = case requirement.risk_level
                  when 'critical' then 'severe'
                  when 'high' then 'significant'
                  when 'medium' then 'moderate'
                  else 'minor'
                  end
    
    {
      level: base_impact,
      financial: estimate_financial_impact(requirement),
      operational: estimate_operational_impact(requirement),
      reputational: estimate_reputational_impact(requirement)
    }
  end

  def calculate_urgency_score(requirement)
    score = 0
    score += 40 if requirement.overdue?
    score += 30 if requirement.high_risk?
    score += 20 if requirement.due_soon?
    score += 10 if requirement.compliance_percentage < 50
    score
  end

  def generate_mitigation_strategies(requirement)
    strategies = []
    
    if requirement.overdue?
      strategies << 'Immediate escalation to senior management'
      strategies << 'Emergency compliance team formation'
    end
    
    if requirement.compliance_percentage < 50
      strategies << 'Comprehensive gap analysis'
      strategies << 'Resource reallocation'
    end
    
    strategies << 'Enhanced monitoring and reporting'
    strategies << 'Staff training and awareness programs'
    
    strategies
  end

  def suggest_mitigation_timeline(requirement)
    if requirement.overdue?
      'Immediate (24-48 hours)'
    elsif requirement.due_soon?
      'Short-term (1-2 weeks)'
    else
      'Medium-term (1-3 months)'
    end
  end

  def identify_required_resources(requirement)
    resources = ['Compliance officer time']
    
    resources << 'Legal consultation' if requirement.compliance_type.in?(%w[gdpr ccpa hipaa])
    resources << 'IT security expertise' if requirement.compliance_type.in?(%w[iso_27001 pci_dss])
    resources << 'Financial audit support' if requirement.compliance_type == 'sox'
    resources << 'Training budget' if requirement.high_risk?
    
    resources
  end

  def estimate_financial_impact(requirement)
    # Simplified impact estimation
    case requirement.compliance_type
    when 'gdpr', 'ccpa' then 'High - potential regulatory fines'
    when 'hipaa' then 'Very High - healthcare penalties'
    when 'sox' then 'Critical - SEC enforcement actions'
    else 'Medium - operational disruption costs'
    end
  end

  def estimate_operational_impact(requirement)
    requirement.high_risk? ? 'Significant business disruption possible' : 'Limited operational impact'
  end

  def estimate_reputational_impact(requirement)
    public_facing_types = %w[gdpr ccpa hipaa]
    public_facing_types.include?(requirement.compliance_type) ? 'High - public trust issues' : 'Low - internal process impact'
  end
end