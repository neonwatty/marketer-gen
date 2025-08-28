require 'test_helper'

class ComplianceRequirementTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @compliance_requirement = compliance_requirements(:gdpr_requirement)
  end

  test "should be valid with valid attributes" do
    requirement = @user.compliance_requirements.build(
      name: "GDPR Data Protection",
      compliance_type: "gdpr",
      description: "Implement GDPR data protection measures",
      risk_level: "high",
      implementation_deadline: 3.months.from_now,
      next_review_date: 6.months.from_now,
      responsible_party: "Data Protection Officer"
    )
    assert requirement.valid?
  end

  test "should require name" do
    requirement = @user.compliance_requirements.build(
      compliance_type: "gdpr",
      description: "Test requirement"
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:name], "can't be blank"
  end

  test "should require description" do
    requirement = @user.compliance_requirements.build(
      name: "Test Requirement",
      compliance_type: "gdpr"
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:description], "can't be blank"
  end

  test "should validate compliance_type inclusion" do
    requirement = @user.compliance_requirements.build(
      name: "Test",
      description: "Test",
      compliance_type: "invalid_type"
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:compliance_type], "is not included in the list"
  end

  test "should validate risk_level inclusion" do
    requirement = @user.compliance_requirements.build(
      name: "Test",
      description: "Test",
      risk_level: "invalid_level"
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:risk_level], "is not included in the list"
  end

  test "should validate status inclusion" do
    requirement = @user.compliance_requirements.build(
      name: "Test",
      description: "Test",
      status: "invalid_status"
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:status], "is not included in the list"
  end

  test "should validate monitoring_frequency inclusion" do
    requirement = @user.compliance_requirements.build(
      name: "Test",
      description: "Test",
      monitoring_frequency: "invalid_frequency"
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:monitoring_frequency], "is not included in the list"
  end

  test "should require implementation_deadline" do
    requirement = @user.compliance_requirements.build(
      name: "Test",
      description: "Test",
      implementation_deadline: nil
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:implementation_deadline], "can't be blank"
  end

  test "should require next_review_date" do
    requirement = ComplianceRequirement.new(
      user: @user,
      name: "Test",
      compliance_type: "gdpr",
      description: "Test",
      implementation_deadline: 1.month.from_now,
      responsible_party: "Test",
      next_review_date: nil
    )
    # Prevent the set_defaults callback from setting the value
    requirement.define_singleton_method(:set_defaults) { }
    assert_not requirement.valid?
    assert_includes requirement.errors[:next_review_date], "can't be blank"
  end

  test "should require responsible_party" do
    requirement = @user.compliance_requirements.build(
      name: "Test",
      description: "Test",
      responsible_party: nil
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:responsible_party], "can't be blank"
  end

  test "should validate name length" do
    requirement = @user.compliance_requirements.build(
      name: "a" * 201,
      description: "Test"
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:name], "is too long (maximum is 200 characters)"
  end

  test "should validate description length" do
    requirement = @user.compliance_requirements.build(
      name: "Test",
      description: "a" * 2001
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:description], "is too long (maximum is 2000 characters)"
  end

  test "should validate regulatory_reference length" do
    requirement = @user.compliance_requirements.build(
      name: "Test",
      description: "Test",
      regulatory_reference: "a" * 501
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:regulatory_reference], "is too long (maximum is 500 characters)"
  end

  test "should validate responsible_party length" do
    requirement = @user.compliance_requirements.build(
      name: "Test",
      description: "Test",
      responsible_party: "a" * 201
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:responsible_party], "is too long (maximum is 200 characters)"
  end

  test "should validate implementation_deadline is future for draft requirements" do
    requirement = @user.compliance_requirements.build(
      name: "Test",
      description: "Test",
      status: "draft",
      implementation_deadline: 1.day.ago,
      next_review_date: 1.month.from_now,
      responsible_party: "Test"
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:implementation_deadline], "must be in the future for draft requirements"
  end

  test "should validate next_review_date is after implementation_deadline" do
    deadline = 1.month.from_now
    requirement = @user.compliance_requirements.build(
      name: "Test",
      description: "Test",
      implementation_deadline: deadline,
      next_review_date: deadline - 1.day,
      responsible_party: "Test"
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:next_review_date], "must be after implementation deadline"
  end

  test "should set default values" do
    requirement = @user.compliance_requirements.build(
      name: "Test",
      description: "Test"
    )
    requirement.valid? # Trigger validations and callbacks
    
    assert_equal "draft", requirement.status
    assert_equal "medium", requirement.risk_level
    assert_equal "monthly", requirement.monitoring_frequency
    assert_not_nil requirement.next_review_date
    assert_equal({}, requirement.custom_rules)
    assert_equal([], requirement.evidence_requirements)
    assert_equal({}, requirement.monitoring_criteria)
  end

  test "should identify overdue requirements" do
    @compliance_requirement.update(
      implementation_deadline: 1.day.ago,
      status: "active"
    )
    assert @compliance_requirement.overdue?
  end

  test "should identify requirements due soon" do
    @compliance_requirement.update(
      implementation_deadline: 2.weeks.from_now
    )
    assert @compliance_requirement.due_soon?
  end

  test "should identify compliant requirements" do
    @compliance_requirement.update(status: "compliant")
    assert @compliance_requirement.compliant?
  end

  test "should identify non-compliant requirements" do
    @compliance_requirement.update(status: "non_compliant")
    assert @compliance_requirement.non_compliant?
  end

  test "should identify high risk requirements" do
    @compliance_requirement.update(risk_level: "high")
    assert @compliance_requirement.high_risk?
    
    @compliance_requirement.update(risk_level: "critical")
    assert @compliance_requirement.high_risk?
    
    @compliance_requirement.update(risk_level: "medium")
    assert_not @compliance_requirement.high_risk?
  end

  test "should identify requirements needing review" do
    @compliance_requirement.update(next_review_date: 1.day.ago)
    assert @compliance_requirement.needs_review?
  end

  test "should calculate risk score correctly" do
    # Test critical risk level with non-compliant status and overdue
    @compliance_requirement.update(
      risk_level: "critical",
      status: "non_compliant",
      implementation_deadline: 1.day.ago
    )
    expected_score = (100 * 2.0 * 2.0).round # base * status_multiplier * deadline_multiplier
    assert_equal expected_score, @compliance_requirement.risk_score

    # Test low risk level with compliant status
    @compliance_requirement.update(
      risk_level: "low",
      status: "compliant",
      implementation_deadline: 1.year.from_now
    )
    expected_score = (25 * 0.5 * 1.0).round
    assert_equal expected_score, @compliance_requirement.risk_score
  end

  test "should calculate compliance percentage" do
    # Create a fresh requirement for isolated testing
    requirement = @user.compliance_requirements.create!(
      name: "Test Requirement",
      compliance_type: "gdpr",
      description: "Test",
      implementation_deadline: 1.month.from_now,
      next_review_date: 2.months.from_now,
      responsible_party: "Test"
    )
    
    # Create mock compliance assessments
    assessment1 = requirement.compliance_assessments.create(
      total_criteria: 10,
      met_criteria: 8,
      assessment_date: Date.current
    )
    assessment2 = requirement.compliance_assessments.create(
      total_criteria: 5,
      met_criteria: 3,
      assessment_date: Date.current
    )
    
    # Expected: (8 + 3) / (10 + 5) * 100 = 73.33%
    expected_percentage = ((8 + 3).to_f / (10 + 5) * 100).round(2)
    assert_equal expected_percentage, requirement.compliance_percentage
  end

  test "should return zero compliance percentage when no assessments exist" do
    # Create a fresh requirement for isolated testing
    requirement = @user.compliance_requirements.create!(
      name: "Test Requirement",
      compliance_type: "gdpr",
      description: "Test",
      implementation_deadline: 1.month.from_now,
      next_review_date: 2.months.from_now,
      responsible_party: "Test"
    )
    
    assert_equal 0, requirement.compliance_percentage
  end

  test "should validate custom rules structure" do
    # Test valid custom rules
    requirement = @user.compliance_requirements.build(
      name: "Test",
      compliance_type: "gdpr",
      description: "Test",
      implementation_deadline: 1.month.from_now,
      next_review_date: 2.months.from_now,
      responsible_party: "Test",
      custom_rules: {
        "data_retention_period" => {
          "enabled" => true,
          "max_retention_days" => 365
        }
      }
    )
    assert requirement.valid?

    # Test invalid data retention rule
    requirement.custom_rules = {
      "data_retention_period" => {
        "enabled" => true,
        "max_retention_days" => -1
      }
    }
    assert_not requirement.valid?
    assert_includes requirement.errors[:custom_rules], "data retention period must be a positive integer"
  end

  test "should validate access control custom rules" do
    requirement = @user.compliance_requirements.build(
      name: "Test",
      compliance_type: "gdpr",
      description: "Test",
      custom_rules: {
        "access_control_requirements" => {
          "enabled" => true,
          "required_roles" => "invalid_format"
        }
      }
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:custom_rules], "access control roles must be an array"
  end

  test "should validate audit trail custom rules" do
    requirement = @user.compliance_requirements.build(
      name: "Test",
      compliance_type: "gdpr",
      description: "Test",
      custom_rules: {
        "audit_trail_requirements" => {
          "enabled" => true,
          "audit_retention_years" => -5
        }
      }
    )
    assert_not requirement.valid?
    assert_includes requirement.errors[:custom_rules], "audit retention period must be a positive integer"
  end

  test "scopes should work correctly" do
    # Create test requirements with different statuses and risk levels
    active_req = @user.compliance_requirements.create!(
      name: "Active Requirement",
      description: "Test",
      compliance_type: "gdpr",
      status: "active",
      risk_level: "high",
      implementation_deadline: 1.month.from_now,
      next_review_date: 2.months.from_now,
      responsible_party: "Test"
    )
    
    overdue_req = @user.compliance_requirements.create!(
      name: "Overdue Requirement",
      description: "Test",
      compliance_type: "hipaa",
      status: "active",
      risk_level: "critical",
      implementation_deadline: 1.day.ago,
      next_review_date: 2.months.from_now,
      responsible_party: "Test"
    )
    
    # Test scopes
    assert_includes ComplianceRequirement.active, active_req
    assert_includes ComplianceRequirement.high_risk, active_req
    assert_includes ComplianceRequirement.high_risk, overdue_req
    assert_includes ComplianceRequirement.overdue, overdue_req
    assert_includes ComplianceRequirement.by_type("gdpr"), @compliance_requirement
  end

  test "should log status changes" do
    # Capture log output
    log_output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = Logger.new(log_output)
    
    @compliance_requirement.update(status: "compliant")
    
    Rails.logger = original_logger
    log_content = log_output.string
    
    assert_includes log_content, "status changed from"
    assert_includes log_content, "to compliant"
  end

  test "should generate compliance report job" do
    assert_enqueued_with(job: ComplianceReportGenerationJob, args: [@compliance_requirement]) do
      @compliance_requirement.generate_compliance_report
    end
  end

  test "should belong to user" do
    assert_respond_to @compliance_requirement, :user
    assert_equal @user, @compliance_requirement.user
  end

  test "should have many compliance assessments" do
    assert_respond_to @compliance_requirement, :compliance_assessments
  end

  test "should have many compliance reports" do
    assert_respond_to @compliance_requirement, :compliance_reports
  end

  test "should destroy dependent assessments and reports" do
    assessment = @compliance_requirement.compliance_assessments.create(
      total_criteria: 10,
      met_criteria: 5,
      assessment_date: Date.current
    )
    
    report = @compliance_requirement.compliance_reports.create(
      report_type: "compliance_summary",
      generated_at: Time.current
    )
    
    assessment_id = assessment.id
    report_id = report.id
    
    @compliance_requirement.destroy
    
    assert_not ComplianceAssessment.exists?(assessment_id)
    assert_not ComplianceReport.exists?(report_id)
  end
end