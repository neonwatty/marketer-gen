require "test_helper"

class DemoAnalyticTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @demo_analytic = DemoAnalytic.new(
      workflow_key: 'social-content',
      user: @user,
      started_at: Time.current,
      total_steps: 5,
      steps_completed: 3,
      user_agent: 'Test Browser',
      ip_address: '127.0.0.1'
    )
  end

  test "should be valid with valid attributes" do
    assert @demo_analytic.valid?
  end

  test "should require workflow_key" do
    @demo_analytic.workflow_key = nil
    assert_not @demo_analytic.valid?
    assert_includes @demo_analytic.errors[:workflow_key], "can't be blank"
  end

  test "should validate workflow_key is in allowed list" do
    @demo_analytic.workflow_key = 'invalid-workflow'
    assert_not @demo_analytic.valid?
    assert_includes @demo_analytic.errors[:workflow_key], "is not included in the list"
  end

  test "should calculate completion_rate before save" do
    @demo_analytic.save!
    assert_equal 0.6, @demo_analytic.completion_rate
  end

  test "should calculate duration if completed_at is set" do
    @demo_analytic.completed_at = @demo_analytic.started_at + 120.seconds
    @demo_analytic.save!
    assert_equal 120, @demo_analytic.duration
  end

  test "should return correct completion_percentage" do
    assert_equal 60.0, @demo_analytic.completion_percentage
  end

  test "should identify completed demos" do
    @demo_analytic.completed_at = Time.current
    @demo_analytic.save!
    
    assert @demo_analytic.completed?
    assert_includes DemoAnalytic.completed, @demo_analytic
  end

  test "should allow anonymous users" do
    @demo_analytic.user = nil
    assert @demo_analytic.valid?
  end
end
