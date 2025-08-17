require "test_helper"

class PlanAnalyticsServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:completed_plan)
    @campaign_plan.update!(
      analytics_enabled: true,
      budget_constraints: { total_budget: 10000, spent_budget: 3000 }.to_json,
      content_strategy: { content_pieces: [{ title: "Blog Post 1" }, { title: "Social Media" }] }.to_json,
      generated_timeline: { phases: [{ name: "Phase 1", duration: 14 }, { name: "Phase 2", duration: 21 }] }.to_json
    )
    @service = PlanAnalyticsService.new(@campaign_plan)
  end

  test "initializes with campaign plan" do
    assert_equal @campaign_plan, @service.instance_variable_get(:@campaign_plan)
    assert_equal @user, @service.instance_variable_get(:@user)
  end

  test "call method delegates to gather_and_process_analytics" do
    result = @service.call
    
    assert result[:success]
    assert_not_nil result[:data]
  end

  test "gather_analytics_data returns structured data" do
    result = @service.gather_analytics_data
    
    assert result[:success]
    
    data = result[:data]
    assert_not_nil data[:engagement_metrics]
    assert_not_nil data[:performance_data]
    assert_not_nil data[:roi_tracking]
    assert_not_nil data[:execution_progress]
    assert_not_nil data[:content_performance]
    assert_not_nil data[:timeline_adherence]
  end

  test "gather_and_process_analytics stores data in database" do
    result = @service.gather_and_process_analytics
    
    # Debug output
    puts "Result: #{result.inspect}" if result[:success] == false
    
    assert result[:success]
    
    @campaign_plan.reload
    assert_not_nil @campaign_plan.engagement_metrics
    assert_not_nil @campaign_plan.performance_data
    assert_not_nil @campaign_plan.roi_tracking
    assert_not_nil @campaign_plan.analytics_last_updated_at
  end

  test "calculate_roi_metrics returns comprehensive ROI data" do
    roi_data = @service.calculate_roi_metrics
    
    assert_not_nil roi_data[:total_investment]
    assert_not_nil roi_data[:cost_per_engagement]
    assert_not_nil roi_data[:projected_roi]
    assert_not_nil roi_data[:actual_roi]
    assert_not_nil roi_data[:cost_efficiency]
    assert_not_nil roi_data[:budget_utilization]
    assert_not_nil roi_data[:last_calculated]
  end

  test "analyze_content_performance returns content metrics" do
    content_data = @service.analyze_content_performance
    
    assert_not_nil content_data[:content_pieces_count]
    assert_not_nil content_data[:channel_performance]
    assert_not_nil content_data[:content_engagement_rates]
    assert_not_nil content_data[:best_performing_content]
    assert_not_nil content_data[:content_completion_rate]
    assert_not_nil content_data[:last_analyzed]
  end

  test "calculate_execution_progress returns execution metrics" do
    timeline_data = { phases: [{ name: "Phase 1", duration: 14 }] }
    @campaign_plan.update!(generated_timeline: timeline_data.to_json)
    
    progress_data = @service.calculate_execution_progress
    
    assert_not_nil progress_data[:overall_progress]
    assert_not_nil progress_data[:milestone_completion]
    assert_not_nil progress_data[:timeline_adherence]
    assert_not_nil progress_data[:upcoming_milestones]
    assert_not_nil progress_data[:overdue_items]
    assert_not_nil progress_data[:estimated_completion]
    assert_not_nil progress_data[:last_updated]
  end

  test "generate_analytics_report creates comprehensive report" do
    result = @service.generate_analytics_report
    
    assert result[:success]
    
    report = result[:data]
    assert_not_nil report[:plan_overview]
    assert_not_nil report[:performance_summary]
    assert_not_nil report[:engagement_analysis]
    assert_not_nil report[:roi_analysis]
    assert_not_nil report[:content_analysis]
    assert_not_nil report[:timeline_analysis]
    assert_not_nil report[:recommendations]
    assert_not_nil report[:generated_at]
  end

  test "sync_with_external_platforms returns sync results" do
    result = @service.sync_with_external_platforms
    
    assert result[:success]
    assert_not_nil result[:data]
  end

  test "gather_engagement_metrics includes base metrics" do
    metrics = @service.send(:gather_engagement_metrics)
    
    assert_not_nil metrics[:views]
    assert_not_nil metrics[:shares]
    assert_not_nil metrics[:feedback_engagement]
    assert_not_nil metrics[:collaboration_score]
    assert_not_nil metrics[:last_updated]
  end

  test "gather_performance_data includes all performance categories" do
    data = @service.send(:gather_performance_data)
    
    assert_not_nil data[:generation_metrics]
    assert_not_nil data[:approval_metrics]
    assert_not_nil data[:execution_metrics]
    assert_not_nil data[:quality_metrics]
    assert_not_nil data[:efficiency_metrics]
    assert_not_nil data[:last_updated]
  end

  test "parse_budget_constraints extracts budget information" do
    budget_data = @service.send(:parse_budget_constraints)
    
    assert_not_nil budget_data[:total_budget]
    assert_not_nil budget_data[:allocated_budget]
    assert_not_nil budget_data[:spent_budget]
    assert_not_nil budget_data[:remaining_budget]
  end

  test "current_performance_metrics calculates performance indicators" do
    metrics = @service.send(:current_performance_metrics)
    
    assert_not_nil metrics[:total_engagements]
    assert_not_nil metrics[:conversion_rate]
    assert_not_nil metrics[:reach]
    assert_not_nil metrics[:impressions]
  end

  test "ROI calculation methods return numeric values" do
    budget_data = { total_budget: 10000, spent_budget: 3000 }
    performance_metrics = { total_engagements: 150, conversion_rate: 0.05 }
    
    cost_per_engagement = @service.send(:calculate_cost_per_engagement, budget_data, performance_metrics)
    projected_roi = @service.send(:calculate_projected_roi, budget_data, performance_metrics)
    actual_roi = @service.send(:calculate_actual_roi, budget_data, performance_metrics)
    cost_efficiency = @service.send(:calculate_cost_efficiency, budget_data, performance_metrics)
    budget_utilization = @service.send(:calculate_budget_utilization, budget_data)
    
    assert_instance_of Float, cost_per_engagement
    assert_instance_of Float, projected_roi
    assert_instance_of Float, actual_roi
    assert_instance_of Float, cost_efficiency
    assert_instance_of Float, budget_utilization
    
    assert_operator cost_per_engagement, :>=, 0
    assert_operator projected_roi, :>=, 0
    assert_operator cost_efficiency, :>=, 0
    assert_equal 30.0, budget_utilization # 3000/10000 * 100
  end

  test "analyze_timeline_adherence returns timeline metrics" do
    timeline_data = { phases: [{ name: "Phase 1", completed: true }, { name: "Phase 2", completed: false }] }
    @campaign_plan.update!(generated_timeline: timeline_data.to_json)
    
    adherence_data = @service.send(:analyze_timeline_adherence)
    
    assert_not_nil adherence_data[:on_schedule_percentage]
    assert_not_nil adherence_data[:delayed_tasks]
    assert_not_nil adherence_data[:completed_milestones]
    assert_not_nil adherence_data[:upcoming_deadlines]
    assert_not_nil adherence_data[:average_completion_time]
  end

  test "content analysis methods handle empty data gracefully" do
    @campaign_plan.update!(content_strategy: nil, content_mapping: nil)
    
    content_pieces = @service.send(:count_content_pieces, {}, {})
    channel_performance = @service.send(:analyze_channel_performance, {})
    
    assert_equal 0, content_pieces
    assert_equal [], channel_performance
  end

  test "external platform integration methods return mock data" do
    assert @service.send(:google_analytics_enabled?)
    assert @service.send(:social_media_tracking_enabled?)
    assert @service.send(:email_marketing_enabled?)
    
    ga_data = @service.send(:sync_google_analytics)
    social_data = @service.send(:sync_social_media_metrics)
    email_data = @service.send(:sync_email_metrics)
    
    assert_not_nil ga_data[:page_views]
    assert_not_nil ga_data[:unique_visitors]
    assert_instance_of Array, social_data
    assert_not_nil email_data[:subscribers]
  end

  test "safe_parse_json handles various input types" do
    # Valid JSON string
    result1 = @service.send(:safe_parse_json, '{"key": "value"}')
    assert_equal "value", result1["key"]
    
    # Already parsed hash
    result2 = @service.send(:safe_parse_json, { key: "value" })
    assert_equal "value", result2[:key]
    
    # Invalid JSON
    result3 = @service.send(:safe_parse_json, "invalid json")
    assert_equal({}, result3)
    
    # Nil input
    result4 = @service.send(:safe_parse_json, nil)
    assert_equal({}, result4)
  end

  test "plan overview generation includes essential plan information" do
    overview = @service.send(:generate_plan_overview)
    
    assert_equal @campaign_plan.id, overview[:plan_id]
    assert_equal @campaign_plan.name, overview[:plan_name]
    assert_equal @campaign_plan.campaign_type, overview[:campaign_type]
    assert_equal @campaign_plan.objective, overview[:objective]
    assert_equal @campaign_plan.status, overview[:status]
    assert_not_nil overview[:created_at]
    assert_not_nil overview[:days_active]
    assert_not_nil overview[:completion_percentage]
  end

  test "mock calculation methods return appropriate data types" do
    plan_views = @service.send(:calculate_plan_views)
    plan_shares = @service.send(:calculate_plan_shares)
    feedback_engagement = @service.send(:calculate_feedback_engagement)
    collaboration_score = @service.send(:calculate_collaboration_score)
    
    assert_instance_of Integer, plan_views
    assert_instance_of Integer, plan_shares
    assert_instance_of Integer, feedback_engagement
    assert_instance_of Integer, collaboration_score
    
    assert_operator plan_views, :>=, 0
    assert_operator plan_shares, :>=, 0
    assert_operator feedback_engagement, :>=, 0
    assert_operator collaboration_score, :>=, 0
    assert_operator collaboration_score, :<=, 100
  end

  test "performance analysis methods return structured data" do
    generation_metrics = @service.send(:analyze_generation_performance)
    approval_metrics = @service.send(:analyze_approval_performance)
    execution_metrics = @service.send(:analyze_execution_performance)
    quality_metrics = @service.send(:analyze_quality_metrics)
    efficiency_metrics = @service.send(:analyze_efficiency_metrics)
    
    assert_not_nil generation_metrics[:generation_duration]
    assert_not_nil generation_metrics[:success_rate]
    assert_not_nil approval_metrics[:approval_status]
    assert_not_nil execution_metrics[:execution_started]
    assert_not_nil quality_metrics[:content_completeness]
    assert_not_nil efficiency_metrics[:time_to_completion]
  end

  test "recommendation generation provides actionable insights" do
    # Set up conditions that would trigger recommendations
    performance_data = { efficiency_metrics: { resource_utilization: 60 } }
    roi_data = { actual_roi: 15, projected_roi: 25 }
    content_data = { content_completion_rate: 70 }
    
    data = {
      performance_data: performance_data,
      roi_tracking: roi_data,
      content_performance: content_data
    }
    
    recommendations = @service.send(:generate_recommendations, data)
    
    assert_instance_of Array, recommendations
    
    if recommendations.any?
      recommendation = recommendations.first
      assert_not_nil recommendation[:type]
      assert_not_nil recommendation[:priority]
      assert_not_nil recommendation[:title]
      assert_not_nil recommendation[:description]
      assert_not_nil recommendation[:impact]
    end
  end

  test "error handling in gather_analytics_data" do
    # Force an error by making the campaign plan invalid
    @service.instance_variable_set(:@campaign_plan, nil)
    
    result = @service.gather_analytics_data
    
    assert_not result[:success]
    assert_not_nil result[:error]
  end

  test "analytics timestamp is updated" do
    original_timestamp = @campaign_plan.analytics_last_updated_at
    
    @service.send(:update_analytics_timestamp)
    @campaign_plan.reload
    
    assert_operator @campaign_plan.analytics_last_updated_at, :>, original_timestamp if original_timestamp
  end
end