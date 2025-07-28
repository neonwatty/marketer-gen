require "test_helper"

class JourneyAnalyticsTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @persona = create(:persona, user: @user)
    @campaign = create(:campaign, user: @user, persona: @persona)
    @journey = create(:journey, user: @user, campaign: @campaign)
    @analytics = build(:journey_analytics, 
      journey: @journey,
      total_executions: 1000,
      completed_executions: 650,
      conversion_rate: 65.0
    )
  end

  test "should be valid with all required attributes" do
    assert @analytics.valid?
  end

  test "should require period_start" do
    @analytics.period_start = nil
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:period_start], "can't be blank"
  end

  test "should require period_end" do
    @analytics.period_end = nil
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:period_end], "can't be blank"
  end

  test "should require journey" do
    @analytics.journey = nil
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:journey], "must exist"
  end

  test "should require campaign" do
    @analytics.campaign = nil
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:campaign], "must exist"
  end

  test "should require user" do
    @analytics.user = nil
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:user], "must exist"
  end

  test "should validate total_executions is non-negative" do
    @analytics.total_executions = -1
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:total_executions], "must be greater than or equal to 0"
  end

  test "should validate completed_executions is non-negative" do
    @analytics.completed_executions = -1
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:completed_executions], "must be greater than or equal to 0"
  end

  test "should validate abandoned_executions is non-negative" do
    @analytics.abandoned_executions = -1
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:abandoned_executions], "must be greater than or equal to 0"
  end

  test "should validate conversion_rate range" do
    @analytics.conversion_rate = -1
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:conversion_rate], "must be greater than or equal to 0"
    
    @analytics.conversion_rate = 101
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:conversion_rate], "must be less than or equal to 100"
    
    @analytics.conversion_rate = 50
    assert @analytics.valid?
  end

  test "should validate engagement_score range" do
    @analytics.engagement_score = -1
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:engagement_score], "must be greater than or equal to 0"
    
    @analytics.engagement_score = 101
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:engagement_score], "must be less than or equal to 100"
    
    @analytics.engagement_score = 75
    assert @analytics.valid?
  end

  test "should validate period_end_after_start" do
    @analytics.period_start = Time.current
    @analytics.period_end = 1.day.ago
    
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:period_end], "must be after period start"
  end

  test "should validate executions_consistency" do
    @analytics.total_executions = 100
    @analytics.completed_executions = 60
    @analytics.abandoned_executions = 50  # 60 + 50 = 110 > 100
    
    assert_not @analytics.valid?
    assert_includes @analytics.errors[:base], "Completed and abandoned executions cannot exceed total executions"
  end

  test "should have default values" do
    analytics = JourneyAnalytics.new
    assert_equal 0, analytics.total_executions
    assert_equal 0, analytics.completed_executions
    assert_equal 0, analytics.abandoned_executions
    assert_equal 0.0, analytics.average_completion_time
    assert_equal 0.0, analytics.conversion_rate
    assert_equal 0.0, analytics.engagement_score
    assert_equal({}, analytics.metrics)
    assert_equal({}, analytics.metadata)
  end

  test "period_duration_days should calculate correctly" do
    @analytics.period_start = 5.days.ago
    @analytics.period_end = Time.current
    
    assert_equal 5.0, @analytics.period_duration_days
  end

  test "completion_rate should calculate correctly" do
    @analytics.total_executions = 1000
    @analytics.completed_executions = 650
    
    assert_equal 65.0, @analytics.completion_rate
  end

  test "completion_rate should return 0 when no executions" do
    @analytics.total_executions = 0
    @analytics.completed_executions = 0
    
    assert_equal 0.0, @analytics.completion_rate
  end

  test "abandonment_rate should calculate correctly" do
    @analytics.total_executions = 1000
    @analytics.abandoned_executions = 200
    
    assert_equal 20.0, @analytics.abandonment_rate
  end

  test "abandonment_rate should return 0 when no executions" do
    @analytics.total_executions = 0
    @analytics.abandoned_executions = 0
    
    assert_equal 0.0, @analytics.abandonment_rate
  end

  test "average_completion_time_formatted should format time correctly" do
    @analytics.average_completion_time = 7320.0  # 2 hours 2 minutes
    assert_equal "2h 2m", @analytics.average_completion_time_formatted
    
    @analytics.average_completion_time = 300.0   # 5 minutes
    assert_equal "5m", @analytics.average_completion_time_formatted
    
    @analytics.average_completion_time = 0.0
    assert_equal "N/A", @analytics.average_completion_time_formatted
  end

  test "performance_grade should assign correct grades" do
    grades = [
      [85, 'A'], [75, 'B'], [55, 'C'], [40, 'D'], [20, 'F']
    ]
    
    grades.each do |score, expected_grade|
      @analytics.conversion_rate = score
      @analytics.engagement_score = score
      
      assert_equal expected_grade, @analytics.performance_grade
    end
  end

  test "aggregate_for_period should aggregate data correctly" do
    @analytics.save!
    
    # Create additional analytics records
    JourneyAnalytics.create!(
      journey: @journey,
      campaign: @campaign,
      user: @user,
      period_start: 2.days.ago,
      period_end: 1.day.ago,
      total_executions: 500,
      completed_executions: 300,
      abandoned_executions: 100,
      conversion_rate: 10.0,
      engagement_score: 80.0
    )
    
    start_date = 3.days.ago
    end_date = Time.current
    
    aggregated = JourneyAnalytics.aggregate_for_period(@journey.id, start_date, end_date)
    
    assert_equal 1500, aggregated[:total_executions]
    assert_equal 950, aggregated[:completed_executions]
    assert_equal 300, aggregated[:abandoned_executions]
    assert aggregated[:average_conversion_rate] > 0
    assert aggregated[:average_engagement_score] > 0
    assert_equal 2, aggregated[:data_points]
  end

  test "calculate_trends should identify trends correctly" do
    @analytics.save!
    
    # Create trend data
    4.times do |i|
      JourneyAnalytics.create!(
        journey: @journey,
        campaign: @campaign,
        user: @user,
        period_start: (i + 2).days.ago,
        period_end: (i + 1).days.ago,
        total_executions: 1000,
        completed_executions: 600,
        abandoned_executions: 200,
        conversion_rate: 5.0 + i,  # Increasing trend
        engagement_score: 70.0 + i,
        average_completion_time: 3600.0
      )
    end
    
    trends = JourneyAnalytics.calculate_trends(@journey.id, 4)
    
    assert_includes trends, :conversion_rate
    assert_includes trends, :engagement_score
    assert_includes trends, :total_executions
    
    # Should detect upward trend
    assert_equal :up, trends[:conversion_rate][:trend]
    assert trends[:conversion_rate][:change_percentage] > 0
  end

  test "compare_with_previous_period should compare correctly" do
    # Create previous period analytics
    previous_analytics = JourneyAnalytics.create!(
      journey: @journey,
      campaign: @campaign,
      user: @user,
      period_start: 3.days.ago,
      period_end: 2.days.ago,
      total_executions: 800,
      completed_executions: 500,
      abandoned_executions: 150,
      conversion_rate: 7.0,
      engagement_score: 70.0
    )
    
    @analytics.save!
    
    comparison = @analytics.compare_with_previous_period
    
    assert_equal 1.5, comparison[:conversion_rate_change]  # 8.5 - 7.0
    assert_equal 5.2, comparison[:engagement_score_change]  # 75.2 - 70.0
    assert_equal 200, comparison[:execution_change]  # 1000 - 800
    assert comparison[:completion_rate_change] > 0
  end

  test "to_chart_data should format data for charts" do
    @analytics.save!
    
    chart_data = @analytics.to_chart_data
    
    assert_includes chart_data, :period
    assert_includes chart_data, :conversion_rate
    assert_includes chart_data, :engagement_score
    assert_includes chart_data, :total_executions
    assert_includes chart_data, :completion_rate
    assert_includes chart_data, :abandonment_rate
    
    assert_equal @analytics.conversion_rate, chart_data[:conversion_rate]
    assert_equal @analytics.engagement_score, chart_data[:engagement_score]
  end

  test "scopes should work correctly" do
    @analytics.save!
    
    # Test for_period scope
    period_analytics = JourneyAnalytics.for_period(2.days.ago, Time.current)
    assert_includes period_analytics, @analytics
    
    # Test recent scope
    recent_analytics = JourneyAnalytics.recent
    assert_includes recent_analytics, @analytics
    
    # Test high_conversion scope
    @analytics.update!(conversion_rate: 15.0)
    high_conversion = JourneyAnalytics.high_conversion
    assert_includes high_conversion, @analytics
    
    # Test low_engagement scope
    @analytics.update!(engagement_score: 40.0)
    low_engagement = JourneyAnalytics.low_engagement
    assert_includes low_engagement, @analytics
  end

  test "daily, weekly, monthly scopes should filter by duration" do
    # Create analytics with different durations
    daily_analytics = JourneyAnalytics.create!(
      journey: @journey,
      campaign: @campaign,
      user: @user,
      period_start: Time.current - 23.hours,  # Just under 1 day
      period_end: Time.current,
      total_executions: 100,
      completed_executions: 65,
      abandoned_executions: 20
    )
    
    weekly_analytics = JourneyAnalytics.create!(
      journey: @journey,
      campaign: @campaign,
      user: @user,
      period_start: Time.current - 6.days,  # Just under 1 week  
      period_end: Time.current,
      total_executions: 700,
      completed_executions: 455,
      abandoned_executions: 140
    )
    
    monthly_analytics = JourneyAnalytics.create!(
      journey: @journey,
      campaign: @campaign,
      user: @user,
      period_start: Time.current - 25.days,  # About 3.5 weeks
      period_end: Time.current,
      total_executions: 2000,
      completed_executions: 1200,
      abandoned_executions: 400
    )
    
    daily_scope = JourneyAnalytics.daily
    weekly_scope = JourneyAnalytics.weekly
    monthly_scope = JourneyAnalytics.monthly
    
    assert_includes daily_scope, daily_analytics
    assert_not_includes daily_scope, weekly_analytics
    assert_not_includes daily_scope, monthly_analytics
    
    assert_includes weekly_scope, weekly_analytics
    assert_includes weekly_scope, daily_analytics  # Daily is also <= 1 week
    assert_not_includes weekly_scope, monthly_analytics
    
    assert_includes monthly_scope, monthly_analytics
    assert_includes monthly_scope, weekly_analytics  # Weekly is also <= 1 month
    assert_includes monthly_scope, daily_analytics   # Daily is also <= 1 month
  end
end