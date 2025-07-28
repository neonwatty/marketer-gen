require "test_helper"

class CampaignAnalyticsServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:admin)
    @persona = Persona.create!(
      user: @user,
      name: "Test Persona",
      description: "Test persona description",
      demographics: { age_range: "25-35", location: "urban" },
      behaviors: { online_activity: "high" },
      preferences: { messaging_tone: "professional", channel_preferences: ["email", "social"] }
    )
    @campaign = Campaign.create!(
      user: @user,
      persona: @persona,
      name: "Test Campaign",
      description: "Test campaign description",
      campaign_type: "product_launch",
      status: "active",
      started_at: 30.days.ago,
      target_metrics: { revenue_per_conversion: 150 }
    )
    @journey = Journey.create!(
      user: @user,
      campaign: @campaign,
      name: "Test Journey",
      description: "Test journey description",
      status: "published"
    )
    @service = CampaignAnalyticsService.new(@campaign)
  end

  test "should initialize with campaign" do
    assert_equal @campaign, @service.instance_variable_get(:@campaign)
  end

  test "campaign_overview should provide campaign summary" do
    overview = @service.campaign_overview
    
    assert_equal @campaign.id, overview[:id]
    assert_equal @campaign.name, overview[:name]
    assert_equal @campaign.status, overview[:status]
    assert_equal @campaign.campaign_type, overview[:type]
    assert_equal @persona.name, overview[:persona]
    assert overview[:duration_days] > 0
    assert_equal @campaign.total_journeys, overview[:total_journeys]
    assert_equal @campaign.active_journeys, overview[:active_journeys]
    assert_includes overview, :progress_percentage
  end

  test "performance_summary should aggregate analytics data" do
    # Create some analytics data
    analytics = JourneyAnalytics.create!(
      journey: @journey,
      campaign: @campaign,
      user: @user,
      period_start: 7.days.ago,
      period_end: 6.days.ago,
      total_executions: 1000,
      completed_executions: 650,
      abandoned_executions: 200,
      conversion_rate: 8.5,
      engagement_score: 75.0,
      average_completion_time: 3600.0
    )
    
    summary = @service.performance_summary(30.days.ago, Time.current)
    
    assert_includes summary, :total_executions
    assert_includes summary, :completed_executions
    assert_includes summary, :abandoned_executions
    assert_includes summary, :overall_conversion_rate
    assert_includes summary, :overall_engagement_score
    assert_includes summary, :average_completion_time
    assert_includes summary, :trends
  end

  test "journey_performance_breakdown should analyze each journey" do
    # Create another journey for comparison
    second_journey = Journey.create!(
      user: @user,
      campaign: @campaign,
      name: "Second Journey",
      description: "Second journey description",
      status: "published"
    )
    
    breakdown = @service.journey_performance_breakdown('daily', 30)
    
    assert breakdown.is_a?(Array)
    assert_equal 2, breakdown.length
    
    journey_data = breakdown.first
    assert_includes journey_data, :journey_id
    assert_includes journey_data, :journey_name
    assert_includes journey_data, :status
    assert_includes journey_data, :performance_score
    assert_includes journey_data, :analytics
    assert_includes journey_data, :funnel_data
    assert_includes journey_data, :ab_test_status
  end

  test "conversion_analysis should analyze funnel data" do
    # Create some funnel data
    ConversionFunnel.create!(
      journey: @journey,
      campaign: @campaign,
      user: @user,
      funnel_name: "default",
      stage: "awareness",
      stage_order: 1,
      visitors: 1000,
      conversions: 800,
      period_start: 7.days.ago,
      period_end: Time.current
    )
    
    ConversionFunnel.create!(
      journey: @journey,
      campaign: @campaign,
      user: @user,
      funnel_name: "default",
      stage: "consideration",
      stage_order: 2,
      visitors: 800,
      conversions: 500,
      period_start: 7.days.ago,
      period_end: Time.current
    )
    
    analysis = @service.conversion_analysis(30.days.ago, Time.current)
    
    assert_includes analysis, :total_conversions
    assert_includes analysis, :conversions_by_stage
    assert_includes analysis, :funnel_efficiency
    assert_includes analysis, :bottlenecks
    
    assert analysis[:total_conversions] > 0
    assert analysis[:conversions_by_stage].is_a?(Hash)
  end

  test "persona_insights should provide persona analysis" do
    insights = @service.persona_insights
    
    assert_equal @persona.name, insights[:persona_name]
    assert_includes insights[:demographics_summary], "Age: 25-35"
    assert_includes insights[:behavior_summary], "Online: high"
    assert_includes insights, :campaign_alignment
    assert_includes insights, :performance_by_segment
    
    alignment = insights[:campaign_alignment]
    assert_includes alignment, :overall_score
    assert_includes alignment, :channel_alignment
    assert_includes alignment, :messaging_alignment
    assert_includes alignment, :suggestions
  end

  test "ab_test_results should return empty array when no tests" do
    results = @service.ab_test_results
    assert_equal [], results
  end

  test "ab_test_results should analyze existing tests" do
    # Create an A/B test
    ab_test = AbTest.create!(
      campaign: @campaign,
      user: @user,
      name: "Test A/B Test",
      hypothesis: "Test hypothesis",
      status: "completed",
      start_date: 10.days.ago,
      end_date: 3.days.ago
    )
    
    # Create variants
    control_variant = ab_test.ab_test_variants.create!(
      journey: @journey,
      name: "Control",
      is_control: true,
      traffic_percentage: 50.0,
      total_visitors: 500,
      conversions: 25
    )
    
    results = @service.ab_test_results
    
    assert_equal 1, results.length
    
    test_result = results.first
    assert_equal ab_test.name, test_result[:test_name]
    assert_equal ab_test.status, test_result[:status]
    assert_includes test_result, :duration_days
    assert_includes test_result, :statistical_significance
    assert_includes test_result, :results_summary
    assert_includes test_result, :variant_comparison
    assert_includes test_result, :recommendation
  end

  test "generate_recommendations should provide actionable insights" do
    # Create analytics that would trigger recommendations
    JourneyAnalytics.create!(
      journey: @journey,
      campaign: @campaign,
      user: @user,
      period_start: 7.days.ago,
      period_end: Time.current,
      total_executions: 1000,
      completed_executions: 30,  # Low conversion rate
      abandoned_executions: 800,
      conversion_rate: 3.0,  # Below 5% threshold
      engagement_score: 45.0  # Below 60% threshold
    )
    
    recommendations = @service.generate_recommendations
    
    assert recommendations.is_a?(Array)
    assert recommendations.length > 0
    
    # Should have recommendations for low conversion and engagement
    conversion_rec = recommendations.find { |r| r[:type] == 'conversion_optimization' }
    engagement_rec = recommendations.find { |r| r[:type] == 'engagement_improvement' }
    
    assert conversion_rec.present?
    assert engagement_rec.present?
    
    assert_includes conversion_rec, :priority
    assert_includes conversion_rec, :title
    assert_includes conversion_rec, :description
    assert_includes conversion_rec, :action_items
  end

  test "calculate_roi should calculate return on investment" do
    # Create some performance data
    JourneyAnalytics.create!(
      journey: @journey,
      campaign: @campaign,
      user: @user,
      period_start: 30.days.ago,
      period_end: Time.current,
      total_executions: 1000,
      completed_executions: 100,
      abandoned_executions: 200,
      conversion_rate: 10.0,
      engagement_score: 75.0
    )
    
    investment = 5000
    roi = @service.calculate_roi(investment)
    
    assert_includes roi, :investment
    assert_includes roi, :estimated_revenue
    assert_includes roi, :net_profit
    assert_includes roi, :roi_percentage
    assert_includes roi, :cost_per_conversion
    assert_includes roi, :conversion_value
    
    assert_equal investment, roi[:investment]
    assert roi[:estimated_revenue] > 0
    assert_equal 150, roi[:conversion_value]  # From target_metrics
  end

  test "calculate_roi should return empty hash without investment" do
    roi = @service.calculate_roi(nil)
    assert_equal({}, roi)
  end

  test "export_data should return data in requested format" do
    json_data = @service.export_data('json')
    assert json_data.is_a?(String)
    
    # Should be valid JSON
    parsed = JSON.parse(json_data)
    assert parsed.is_a?(Hash)
    assert_includes parsed, 'campaign_overview'
    assert_includes parsed, 'performance_summary'
  end

  test "export_data should handle CSV format" do
    csv_data = @service.export_data('csv')
    assert csv_data.is_a?(String)
    assert_includes csv_data, "CSV export functionality"
  end

  test "export_data should default to hash format" do
    data = @service.export_data('unknown_format')
    assert data.is_a?(Hash)
    assert_includes data, :campaign_overview
  end

  test "generate_comprehensive_report should include all sections" do
    report = @service.generate_comprehensive_report('daily', 30)
    
    assert_includes report, :campaign_overview
    assert_includes report, :performance_summary
    assert_includes report, :journey_performance
    assert_includes report, :conversion_analysis
    assert_includes report, :persona_insights
    assert_includes report, :ab_test_results
    assert_includes report, :recommendations
    assert_includes report, :period_info
    
    period_info = report[:period_info]
    assert_includes period_info, :start_date
    assert_includes period_info, :end_date
    assert_includes period_info, :period
    assert_includes period_info, :days
    assert_equal 30, period_info[:days]
    assert_equal 'daily', period_info[:period]
  end

  test "private methods should calculate trends correctly" do
    # Test calculate_trend_change method through performance_summary
    old_analytics = JourneyAnalytics.create!(
      journey: @journey,
      campaign: @campaign,
      user: @user,
      period_start: 14.days.ago,
      period_end: 8.days.ago,
      total_executions: 500,
      completed_executions: 250,
      abandoned_executions: 100,
      conversion_rate: 5.0,
      engagement_score: 60.0
    )
    
    new_analytics = JourneyAnalytics.create!(
      journey: @journey,
      campaign: @campaign,
      user: @user,
      period_start: 7.days.ago,
      period_end: Time.current,
      total_executions: 800,
      completed_executions: 480,
      abandoned_executions: 160,
      conversion_rate: 8.0,
      engagement_score: 75.0
    )
    
    summary = @service.performance_summary(30.days.ago, Time.current)
    trends = summary[:trends]
    
    assert_includes trends, :conversion_rate
    assert_includes trends, :engagement_score
    assert_includes trends, :total_executions
    
    # All metrics should show upward trends
    assert_equal 'up', trends[:conversion_rate][:trend]
    assert_equal 'up', trends[:engagement_score][:trend]
    assert trends[:conversion_rate][:change_percentage] > 0
  end
end