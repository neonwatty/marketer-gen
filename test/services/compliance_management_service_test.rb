require 'test_helper'

class ComplianceManagementServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @compliance_requirement = compliance_requirements(:gdpr_requirement)
    @service = ComplianceManagementService
  end

  test "should create compliance requirement successfully" do
    requirement_params = {
      name: "CCPA Compliance",
      compliance_type: "ccpa",
      description: "California Consumer Privacy Act compliance",
      risk_level: "high",
      implementation_deadline: 3.months.from_now,
      next_review_date: 6.months.from_now,
      responsible_party: "Privacy Officer"
    }

    result = @service.call(
      user: @user,
      params: { action: 'create_requirement', requirement: requirement_params }
    )

    assert result[:success]
    assert_not_nil result[:data][:requirement]
    assert_equal "CCPA Compliance", result[:data][:requirement].name
    assert_includes result[:data][:message], "created successfully"
    assert result[:data][:next_actions].is_a?(Array)
  end

  test "should fail to create invalid compliance requirement" do
    invalid_params = {
      name: "", # Invalid: blank name
      compliance_type: "ccpa",
      description: "Test"
    }

    result = @service.call(
      user: @user,
      params: { action: 'create_requirement', requirement: invalid_params }
    )

    assert_not result[:success]
    assert_equal "Failed to create compliance requirement", result[:error]
    assert result[:validation_errors].is_a?(Array)
  end

  test "should assess compliance status successfully" do
    # Mock the ComplianceAssessmentEngine
    ComplianceManagementService::ComplianceAssessmentEngine.any_instance
      .expects(:perform_assessment)
      .returns({
        success: true,
        compliance_score: 85,
        status: 'monitoring',
        evidence_review: [],
        gap_analysis: [],
        next_review_date: 4.months.from_now
      })

    result = @service.call(
      user: @user,
      params: {
        action: 'assess_compliance',
        requirement_id: @compliance_requirement.id
      }
    )

    assert result[:success]
    assert_not_nil result[:data][:assessment]
    assert_equal 85, result[:data][:assessment][:compliance_score]
    assert_not_nil result[:data][:requirement]
    assert result[:data][:recommendations].is_a?(Array)
  end

  test "should handle assessment failure" do
    ComplianceManagementService::ComplianceAssessmentEngine.any_instance
      .expects(:perform_assessment)
      .returns({ success: false, error: "Assessment engine failure" })

    result = @service.call(
      user: @user,
      params: {
        action: 'assess_compliance',
        requirement_id: @compliance_requirement.id
      }
    )

    assert_not result[:success]
    assert_equal "Assessment failed", result[:error]
    assert_equal "Assessment engine failure", result[:details]
  end

  test "should return error for non-existent requirement" do
    result = @service.call(
      user: @user,
      params: {
        action: 'assess_compliance',
        requirement_id: 99999
      }
    )

    assert_not result[:success]
    assert_equal "Compliance requirement not found", result[:error]
    assert_equal "REQUIREMENT_NOT_FOUND", result[:code]
  end

  test "should generate compliance report in JSON format" do
    result = @service.call(
      user: @user,
      params: {
        action: 'generate_report',
        requirement_id: @compliance_requirement.id,
        format: 'json'
      }
    )

    assert result[:success]
    assert_not_nil result[:data][:report_data]
    assert_equal 'json', result[:data][:format]
    assert_not_nil result[:data][:report_data][:requirement]
    assert_not_nil result[:data][:report_data][:current_status]
    assert result[:data][:report_data][:timeline].is_a?(Array)
  end

  test "should generate compliance report in PDF format" do
    result = @service.call(
      user: @user,
      params: {
        action: 'generate_report',
        requirement_id: @compliance_requirement.id,
        format: 'pdf'
      }
    )

    assert result[:success]
    assert_not_nil result[:data][:pdf_path]
    assert_includes result[:data][:download_url], "/compliance/reports/#{@compliance_requirement.id}/download"
  end

  test "should perform risk analysis" do
    # Create additional requirements for comprehensive risk analysis
    high_risk_req = @user.compliance_requirements.create!(
      name: "High Risk Requirement",
      compliance_type: "gdpr",
      description: "Test high risk requirement",
      risk_level: "high",
      status: "non_compliant",
      implementation_deadline: 1.day.ago,
      next_review_date: 1.month.from_now,
      responsible_party: "Risk Manager"
    )

    result = @service.call(
      user: @user,
      params: {
        action: 'risk_analysis',
        scope: 'all'
      }
    )

    assert result[:success]
    assert_not_nil result[:data][:risk_matrix]
    assert result[:data][:critical_risks].is_a?(Array)
    assert result[:data][:mitigation_strategies].is_a?(Array)
    assert result[:data][:overall_risk_score].is_a?(Numeric)
    assert_not_nil result[:data][:trends]
  end

  test "should perform monitoring check" do
    # Create overdue and due requirements
    overdue_req = @user.compliance_requirements.create!(
      name: "Overdue Requirement",
      compliance_type: "gdpr",
      description: "Test overdue requirement",
      status: "active",
      implementation_deadline: 1.month.from_now,
      next_review_date: 2.months.from_now,
      responsible_party: "Monitor"
    )

    due_req = @user.compliance_requirements.create!(
      name: "Due Requirement",
      compliance_type: "ccpa",
      description: "Test due requirement",
      status: "active",
      implementation_deadline: 1.month.from_now,
      next_review_date: 2.months.from_now,
      responsible_party: "Monitor"
    )
    
    # Update next_review_date after creation to bypass validation
    overdue_req.update_column(:next_review_date, 1.day.ago)
    due_req.update_column(:next_review_date, 1.day.ago)

    result = @service.call(
      user: @user,
      params: { action: 'monitoring_check' }
    )

    assert result[:success]
    assert result[:data][:total_checked] >= 0
    assert result[:data][:overdue_count] >= 1
    assert result[:data][:monitoring_results].is_a?(Array)
    assert result[:data][:alerts_sent] >= 0
  end

  test "should perform bulk update" do
    req1 = @user.compliance_requirements.create!(
      name: "Requirement 1",
      compliance_type: "gdpr",
      description: "Test requirement 1",
      implementation_deadline: 1.month.from_now,
      next_review_date: 2.months.from_now,
      responsible_party: "Manager 1"
    )

    req2 = @user.compliance_requirements.create!(
      name: "Requirement 2",
      compliance_type: "ccpa",
      description: "Test requirement 2",
      implementation_deadline: 1.month.from_now,
      next_review_date: 2.months.from_now,
      responsible_party: "Manager 2"
    )

    update_data = [
      {
        id: req1.id,
        attributes: { status: "compliant", risk_level: "low" }
      },
      {
        id: req2.id,
        attributes: { status: "monitoring", risk_level: "medium" }
      }
    ]

    result = @service.call(
      user: @user,
      params: {
        action: 'bulk_update',
        requirements: update_data
      }
    )

    assert result[:success]
    assert_equal 2, result[:data][:updated_count]
    assert_equal 0, result[:data][:failed_count]
    assert_equal 2, result[:data][:results].length

    # Verify updates were applied
    req1.reload
    req2.reload
    assert_equal "compliant", req1.status
    assert_equal "low", req1.risk_level
    assert_equal "monitoring", req2.status
    assert_equal "medium", req2.risk_level
  end

  test "should handle bulk update with some failures" do
    req1 = @user.compliance_requirements.create!(
      name: "Requirement 1",
      compliance_type: "gdpr",
      description: "Test requirement 1",
      implementation_deadline: 1.month.from_now,
      next_review_date: 2.months.from_now,
      responsible_party: "Manager 1"
    )

    update_data = [
      {
        id: req1.id,
        attributes: { status: "compliant" }
      },
      {
        id: req1.id,
        attributes: { name: "" } # This will fail validation
      }
    ]

    result = @service.call(
      user: @user,
      params: {
        action: 'bulk_update',
        requirements: update_data
      }
    )

    assert result[:success]
    assert_equal 1, result[:data][:updated_count]
    assert_equal 1, result[:data][:failed_count]
  end

  test "should handle unknown action" do
    result = @service.call(
      user: @user,
      params: { action: 'unknown_action' }
    )

    assert_not result[:success]
    assert_includes result[:error], "Unknown action"
  end

  test "should handle service errors gracefully" do
    # Simulate an error by passing invalid user
    result = @service.call(
      user: nil,
      params: { action: 'create_requirement', requirement: {} }
    )

    assert_not result[:success]
    assert result[:error].present?
    assert result[:context].present?
  end

  # Test ComplianceAssessmentEngine separately
  test "ComplianceAssessmentEngine should calculate compliance score correctly" do
    engine = ComplianceManagementService::ComplianceAssessmentEngine.new(@compliance_requirement)
    
    # Mock the requirement's attributes for testing
    @compliance_requirement.stubs(:evidence_requirements).returns([{ 'name' => 'test' }])
    @compliance_requirement.stubs(:monitoring_criteria).returns({ 'test' => 'criteria' })
    
    result = engine.perform_assessment
    
    assert result[:success]
    assert result[:compliance_score].is_a?(Numeric)
    assert result[:compliance_score] >= 0
    assert result[:compliance_score] <= 100
  end

  test "ComplianceAssessmentEngine should determine compliance status based on score" do
    engine = ComplianceManagementService::ComplianceAssessmentEngine.new(@compliance_requirement)
    
    # Test different score ranges
    engine.stubs(:calculate_compliance_score).returns(95)
    result = engine.perform_assessment
    assert_equal 'compliant', result[:status]
    
    engine.stubs(:calculate_compliance_score).returns(80)
    result = engine.perform_assessment
    assert_equal 'monitoring', result[:status]
    
    engine.stubs(:calculate_compliance_score).returns(60)
    result = engine.perform_assessment
    assert_equal 'active', result[:status]
    
    engine.stubs(:calculate_compliance_score).returns(30)
    result = engine.perform_assessment
    assert_equal 'non_compliant', result[:status]
  end

  test "ComplianceAssessmentEngine should calculate next review date based on frequency" do
    engine = ComplianceManagementService::ComplianceAssessmentEngine.new(@compliance_requirement)
    
    @compliance_requirement.monitoring_frequency = 'daily'
    result = engine.perform_assessment
    expected_date = 1.day.from_now.to_date
    assert_equal expected_date, result[:next_review_date].to_date
    
    @compliance_requirement.monitoring_frequency = 'weekly'
    result = engine.perform_assessment
    expected_date = 1.week.from_now.to_date
    assert_equal expected_date, result[:next_review_date].to_date
    
    @compliance_requirement.monitoring_frequency = 'monthly'
    result = engine.perform_assessment
    expected_date = 1.month.from_now.to_date
    assert_equal expected_date, result[:next_review_date].to_date
  end

  test "should schedule initial assessment job after requirement creation" do
    requirement_params = {
      name: "Test Requirement",
      compliance_type: "gdpr",
      description: "Test description",
      risk_level: "medium",
      implementation_deadline: 1.month.from_now,
      next_review_date: 2.months.from_now,
      responsible_party: "Test Manager"
    }

    assert_enqueued_jobs 2 do
      result = @service.call(
        user: @user,
        params: { action: 'create_requirement', requirement: requirement_params }
      )
      assert result[:success]
    end
  end

  test "should schedule appropriate monitoring jobs based on frequency" do
    daily_req = @user.compliance_requirements.create!(
      name: "Daily Requirement",
      compliance_type: "gdpr",
      description: "Daily monitoring requirement",
      monitoring_frequency: "daily",
      implementation_deadline: 1.month.from_now,
      next_review_date: 2.months.from_now,
      responsible_party: "Daily Manager"
    )

    weekly_req = @user.compliance_requirements.create!(
      name: "Weekly Requirement",
      compliance_type: "ccpa",
      description: "Weekly monitoring requirement",
      monitoring_frequency: "weekly",
      implementation_deadline: 1.month.from_now,
      next_review_date: 2.months.from_now,
      responsible_party: "Weekly Manager"
    )

    # Test daily monitoring
    assert_enqueued_with(job: DailyComplianceCheckJob, args: [daily_req.id]) do
      service = ComplianceManagementService.new(user: @user, params: {})
      service.send(:schedule_monitoring, daily_req)
    end

    # Test weekly monitoring
    assert_enqueued_with(job: WeeklyComplianceCheckJob, args: [weekly_req.id]) do
      service = ComplianceManagementService.new(user: @user, params: {})
      service.send(:schedule_monitoring, weekly_req)
    end
  end

  test "should suggest appropriate next actions based on requirement attributes" do
    service = ComplianceManagementService.new(user: @user, params: {})
    
    # Requirement with evidence requirements
    req_with_evidence = @user.compliance_requirements.build(
      evidence_requirements: [{ 'name' => 'test evidence' }]
    )
    actions = service.send(:suggested_next_actions, req_with_evidence)
    assert_includes actions, 'Upload evidence documents'
    
    # High risk requirement
    req_high_risk = @user.compliance_requirements.build(risk_level: 'critical')
    actions = service.send(:suggested_next_actions, req_high_risk)
    assert_includes actions, 'Set up automated alerts'
    
    # GDPR requirement
    req_gdpr = @user.compliance_requirements.build(compliance_type: 'gdpr')
    actions = service.send(:suggested_next_actions, req_gdpr)
    assert_includes actions, 'Schedule team training'
  end

  private

  def create_mock_assessment(requirement, total_criteria:, met_criteria:)
    requirement.compliance_assessments.create(
      total_criteria: total_criteria,
      met_criteria: met_criteria,
      assessment_date: Date.current,
      status: 'completed'
    )
  end
end