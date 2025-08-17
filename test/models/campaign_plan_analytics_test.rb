require "test_helper"

class CampaignPlanAnalyticsTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:completed_plan)
    @campaign_plan.update!(
      analytics_enabled: true,
      engagement_metrics: { collaboration_score: 85, views: 150 }.to_json,
      performance_data: { quality_metrics: { content_completeness: 92 } }.to_json,
      roi_tracking: { actual_roi: 25.5, projected_roi: 20.0 }.to_json
    )
  end

  test "analytics_enabled scope returns only enabled plans" do
    enabled_plan = @campaign_plan
    disabled_plan = campaign_plans(:draft_plan)
    disabled_plan.update!(analytics_enabled: false)

    enabled_plans = CampaignPlan.analytics_enabled
    
    assert_includes enabled_plans, enabled_plan
    assert_not_includes enabled_plans, disabled_plan
  end

  test "with_analytics_data scope returns plans with analytics data" do
    plan_with_data = @campaign_plan
    plan_without_data = campaign_plans(:draft_plan)

    plans_with_data = CampaignPlan.with_analytics_data
    
    assert_includes plans_with_data, plan_with_data
    assert_not_includes plans_with_data, plan_without_data
  end

  test "execution_started scope returns plans with execution started" do
    @campaign_plan.update!(plan_execution_started_at: 1.day.ago)
    
    started_plans = CampaignPlan.execution_started
    
    assert_includes started_plans, @campaign_plan
  end

  test "execution_completed scope returns plans with execution completed" do
    @campaign_plan.update!(
      plan_execution_started_at: 2.days.ago,
      plan_execution_completed_at: 1.day.ago
    )
    
    completed_plans = CampaignPlan.execution_completed
    
    assert_includes completed_plans, @campaign_plan
  end

  test "analytics_summary returns comprehensive analytics data" do
    summary = @campaign_plan.analytics_summary
    
    assert_not_nil summary[:basic_analytics]
    assert_not_nil summary[:engagement_data]
    assert_not_nil summary[:performance_data]
    assert_not_nil summary[:roi_data]
    assert_not_nil summary[:execution_status]
  end

  test "parsed_engagement_metrics returns parsed JSON data" do
    metrics = @campaign_plan.parsed_engagement_metrics
    
    assert_equal 85, metrics['collaboration_score']
    assert_equal 150, metrics['views']
  end

  test "parsed_performance_data returns parsed JSON data" do
    data = @campaign_plan.parsed_performance_data
    
    assert_equal 92, data.dig('quality_metrics', 'content_completeness')
  end

  test "parsed_roi_tracking returns parsed JSON data" do
    roi = @campaign_plan.parsed_roi_tracking
    
    assert_equal 25.5, roi['actual_roi']
    assert_equal 20.0, roi['projected_roi']
  end

  test "execution_analytics_summary returns execution status" do
    @campaign_plan.update!(plan_execution_started_at: 1.day.ago)
    
    summary = @campaign_plan.execution_analytics_summary
    
    assert summary[:execution_started]
    assert_not summary[:execution_completed]
    assert_equal 1.0, summary[:execution_duration_days]
    assert_operator summary[:execution_progress_percentage], :>, 0
  end

  test "calculate_execution_duration_days returns correct duration" do
    @campaign_plan.update!(plan_execution_started_at: 3.days.ago)
    
    duration = @campaign_plan.calculate_execution_duration_days
    
    assert_in_delta 3.0, duration, 0.1
  end

  test "calculate_execution_progress_percentage returns progress" do
    @campaign_plan.update!(plan_execution_started_at: 1.day.ago)
    
    progress = @campaign_plan.calculate_execution_progress_percentage
    
    assert_operator progress, :>=, 0
    assert_operator progress, :<=, 100
  end

  test "has_analytics_data? returns true when data present" do
    assert @campaign_plan.has_analytics_data?
  end

  test "has_analytics_data? returns false when no data" do
    plan = campaign_plans(:draft_plan)
    
    assert_not plan.has_analytics_data?
  end

  test "analytics_stale? returns true when data is old" do
    @campaign_plan.update!(analytics_last_updated_at: 2.days.ago)
    
    assert @campaign_plan.analytics_stale?
  end

  test "analytics_stale? returns false when data is recent" do
    @campaign_plan.update!(analytics_last_updated_at: 1.hour.ago)
    
    assert_not @campaign_plan.analytics_stale?
  end

  test "start_execution! sets execution start time" do
    assert_nil @campaign_plan.plan_execution_started_at
    
    result = @campaign_plan.start_execution!
    
    assert result
    assert_not_nil @campaign_plan.plan_execution_started_at
  end

  test "start_execution! fails if already started" do
    @campaign_plan.update!(plan_execution_started_at: 1.day.ago)
    
    result = @campaign_plan.start_execution!
    
    assert_not result
  end

  test "complete_execution! sets completion time" do
    @campaign_plan.update!(plan_execution_started_at: 1.day.ago)
    
    result = @campaign_plan.complete_execution!
    
    assert result
    assert_not_nil @campaign_plan.plan_execution_completed_at
  end

  test "complete_execution! fails if not started" do
    result = @campaign_plan.complete_execution!
    
    assert_not result
  end

  test "execution_in_progress? returns correct status" do
    assert_not @campaign_plan.execution_in_progress?
    
    @campaign_plan.update!(plan_execution_started_at: 1.day.ago)
    assert @campaign_plan.execution_in_progress?
    
    @campaign_plan.update!(plan_execution_completed_at: Time.current)
    assert_not @campaign_plan.execution_in_progress?
  end

  test "execution_completed? returns correct status" do
    assert_not @campaign_plan.execution_completed?
    
    @campaign_plan.update!(plan_execution_started_at: 1.day.ago)
    assert_not @campaign_plan.execution_completed?
    
    @campaign_plan.update!(plan_execution_completed_at: Time.current)
    assert @campaign_plan.execution_completed?
  end

  test "current_roi returns ROI value" do
    roi = @campaign_plan.current_roi
    
    assert_equal 25.5, roi
  end

  test "projected_roi returns projected value" do
    roi = @campaign_plan.projected_roi
    
    assert_equal 20.0, roi
  end

  test "engagement_score returns engagement value" do
    score = @campaign_plan.engagement_score
    
    assert_equal 85, score
  end

  test "performance_score returns performance value" do
    score = @campaign_plan.performance_score
    
    assert_equal 92, score
  end

  test "content_performance_summary returns content metrics" do
    summary = @campaign_plan.content_performance_summary
    
    assert_respond_to summary, :[]
    assert_not_nil summary[:total_content_pieces]
    assert_not_nil summary[:channel_performance]
  end

  test "timeline_performance_summary returns timeline metrics" do
    summary = @campaign_plan.timeline_performance_summary
    
    assert_respond_to summary, :[]
    assert_not_nil summary[:overall_progress]
    assert_not_nil summary[:timeline_adherence]
  end

  test "safe_parse_json_field handles valid JSON" do
    @campaign_plan.engagement_metrics = { test: "value" }.to_json
    
    result = @campaign_plan.send(:safe_parse_json_field, :engagement_metrics)
    
    assert_equal "value", result["test"]
  end

  test "safe_parse_json_field handles invalid JSON" do
    @campaign_plan.engagement_metrics = "invalid json{"
    
    result = @campaign_plan.send(:safe_parse_json_field, :engagement_metrics)
    
    assert_equal({}, result)
  end

  test "extract_planned_duration returns default for empty timeline" do
    duration = @campaign_plan.send(:extract_planned_duration, {})
    
    assert_equal 30, duration
  end

  test "extract_planned_duration extracts duration from timeline data" do
    timeline_data = { duration_days: 45 }
    
    duration = @campaign_plan.send(:extract_planned_duration, timeline_data)
    
    assert_equal 45, duration
  end

  test "calculate_timeline_duration_from_phases sums phase durations" do
    timeline_data = {
      phases: [
        { duration: 10 },
        { days: 15 },
        { duration: 5 }
      ]
    }
    
    duration = @campaign_plan.send(:calculate_timeline_duration_from_phases, timeline_data)
    
    assert_equal 30, duration
  end

  test "disabled analytics prevents analytics operations" do
    @campaign_plan.update!(analytics_enabled: false)
    
    assert_equal({}, @campaign_plan.analytics_summary)
    assert_not @campaign_plan.refresh_analytics!
    
    result = @campaign_plan.generate_analytics_report
    assert_not result[:success]
    assert_equal 'Analytics not enabled', result[:error]
  end
end