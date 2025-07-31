require 'test_helper'

class JourneyInsightTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email_address: 'test@example.com',
      password: 'password123'
    )
    @journey = Journey.create!(
      name: 'Test Journey',
      user: @user,
      status: 'draft'
    )
    @insight = JourneyInsight.new(
      journey: @journey,
      insights_type: 'ai_suggestions',
      data: { 
        'suggestions' => [{ 
          'name' => 'Test Suggestion',
          'description' => 'Test suggestion description',
          'stage' => 'awareness',
          'content_type' => 'email',
          'channel' => 'email'
        }] 
      },
      calculated_at: Time.current
    )
  end

  test "should be valid with valid attributes" do
    assert @insight.valid?
  end

  test "should require journey" do
    @insight.journey = nil
    assert_not @insight.valid?
    assert_includes @insight.errors[:journey], "must exist"
  end

  test "should require insights_type" do
    @insight.insights_type = nil
    assert_not @insight.valid?
    assert_includes @insight.errors[:insights_type], "is not included in the list"
  end

  test "should validate insights_type inclusion" do
    @insight.insights_type = 'invalid_type'
    assert_not @insight.valid?
    assert_includes @insight.errors[:insights_type], "is not included in the list"
  end

  test "should require calculated_at" do
    @insight.calculated_at = nil
    assert_not @insight.valid?
    assert_includes @insight.errors[:calculated_at], "can't be blank"
  end

  test "should have default values" do
    insight = JourneyInsight.new(
      journey: @journey,
      insights_type: 'ai_suggestions',
      calculated_at: Time.current
    )
    
    assert_equal({}, insight.data)
    assert_equal({}, insight.metadata)
  end

  test "should set default expires_at for ai_suggestions before save" do
    @insight.save!
    
    assert @insight.expires_at.present?
    assert @insight.expires_at > Time.current
    assert @insight.expires_at <= 24.hours.from_now
  end

  test "should not set expires_at for other insight types" do
    @insight.insights_type = 'performance_metrics'
    @insight.save!
    
    assert_nil @insight.expires_at
  end

  test "expired? should return true when past expires_at" do
    @insight.expires_at = 1.hour.ago
    assert @insight.expired?
    
    @insight.expires_at = 1.hour.from_now
    assert_not @insight.expired?
    
    @insight.expires_at = nil
    assert_not @insight.expired?
  end

  test "active? should be opposite of expired?" do
    @insight.expires_at = 1.hour.ago
    assert_not @insight.active?
    
    @insight.expires_at = 1.hour.from_now
    assert @insight.active?
  end

  test "should calculate age in hours" do
    @insight.calculated_at = 3.hours.ago
    age = @insight.age_in_hours
    
    assert age >= 3.0
    assert age < 3.1 # Allow for small time differences
  end

  test "should calculate age in days" do
    @insight.calculated_at = 2.days.ago
    age = @insight.age_in_days
    
    assert age >= 2.0
    assert age < 2.1
  end

  test "should calculate time to expiry" do
    @insight.expires_at = 25.hours.from_now
    time_to_expiry = @insight.time_to_expiry
    
    # Should have approximately 1 day and 1 hour
    total_hours = time_to_expiry[:days] * 24 + time_to_expiry[:hours]
    assert total_hours >= 24 && total_hours <= 25, "Expected ~25 hours, got #{total_hours}"
    assert time_to_expiry[:minutes] >= 0
  end

  test "should return nil for time_to_expiry when no expires_at" do
    @insight.expires_at = nil
    assert_nil @insight.time_to_expiry
  end

  test "should return 0 for time_to_expiry when already expired" do
    @insight.expires_at = 1.hour.ago
    time_to_expiry = @insight.time_to_expiry
    
    assert_equal 0, time_to_expiry
  end

  test "should scope active insights" do
    @insight.expires_at = 1.hour.from_now
    @insight.save!
    
    expired_insight = JourneyInsight.create!(
      journey: @journey,
      insights_type: 'performance_metrics',
      calculated_at: Time.current,
      expires_at: 1.hour.ago
    )
    
    active_insights = JourneyInsight.active
    assert_includes active_insights, @insight
    assert_not_includes active_insights, expired_insight
  end

  test "should scope expired insights" do
    @insight.expires_at = 1.hour.ago
    @insight.save!
    
    active_insight = JourneyInsight.create!(
      journey: @journey,
      insights_type: 'performance_metrics',
      calculated_at: Time.current,
      expires_at: 1.hour.from_now
    )
    
    expired_insights = JourneyInsight.expired
    assert_includes expired_insights, @insight
    assert_not_includes expired_insights, active_insight
  end

  test "should scope by type" do
    @insight.save!
    
    performance_insight = JourneyInsight.create!(
      journey: @journey,
      insights_type: 'performance_metrics',
      calculated_at: Time.current
    )
    
    ai_insights = JourneyInsight.by_type('ai_suggestions')
    assert_includes ai_insights, @insight
    assert_not_includes ai_insights, performance_insight
  end

  test "should scope recent insights" do
    @insight.calculated_at = 5.days.ago
    @insight.save!
    
    recent_insight = JourneyInsight.create!(
      journey: @journey,
      insights_type: 'performance_metrics',
      calculated_at: Time.current
    )
    
    recent_insights = JourneyInsight.recent(7)
    assert_includes recent_insights, recent_insight
    assert_includes recent_insights, @insight # 5 days ago is within 7 days
    
    recent_insights_3_days = JourneyInsight.recent(3)
    assert_includes recent_insights_3_days, recent_insight
    assert_not_includes recent_insights_3_days, @insight # 5 days ago is not within 3 days
  end

  test "should find latest for journey" do
    @insight.save!
    
    newer_insight = JourneyInsight.create!(
      journey: @journey,
      insights_type: 'ai_suggestions',
      calculated_at: 1.hour.from_now
    )
    
    latest = JourneyInsight.latest_for_journey(@journey.id)
    assert_equal newer_insight, latest
  end

  test "should find latest for journey by type" do
    @insight.save!
    
    performance_insight = JourneyInsight.create!(
      journey: @journey,
      insights_type: 'performance_metrics',
      calculated_at: 1.hour.from_now
    )
    
    latest_ai = JourneyInsight.latest_for_journey(@journey.id, 'ai_suggestions')
    latest_performance = JourneyInsight.latest_for_journey(@journey.id, 'performance_metrics')
    
    assert_equal @insight, latest_ai
    assert_equal performance_insight, latest_performance
  end

  test "should cleanup expired insights" do
    @insight.expires_at = 1.hour.ago
    @insight.save!
    
    active_insight = JourneyInsight.create!(
      journey: @journey,
      insights_type: 'performance_metrics',
      calculated_at: Time.current,
      expires_at: 1.hour.from_now
    )
    
    initial_count = JourneyInsight.count
    JourneyInsight.cleanup_expired
    
    assert_equal initial_count - 1, JourneyInsight.count
    assert_not JourneyInsight.exists?(@insight.id)
    assert JourneyInsight.exists?(active_insight.id)
  end

  test "should access suggestions_data for ai_suggestions type" do
    suggestions = [{ 'name' => 'Test Suggestion', 'stage' => 'awareness' }]
    @insight.data = { 'suggestions' => suggestions }
    
    assert_equal suggestions, @insight.suggestions_data
  end

  test "should return empty array for suggestions_data when not ai_suggestions type" do
    @insight.insights_type = 'performance_metrics'
    @insight.data = { 'suggestions' => [{ 'name' => 'Test' }] }
    
    assert_equal({}, @insight.suggestions_data)
  end

  test "should access performance_data for performance_metrics type" do
    metrics = { 'completion_rate' => 85.5, 'engagement_score' => 7.2 }
    @insight.insights_type = 'performance_metrics'
    @insight.data = { 'metrics' => metrics }
    
    assert_equal metrics, @insight.performance_data
  end

  test "should validate suggestions data structure" do
    @insight.data = {
      'suggestions' => [
        { 'name' => 'Valid Suggestion', 'description' => 'Test', 'stage' => 'awareness', 'content_type' => 'email', 'channel' => 'email' },
        { 'name' => 'Invalid Suggestion' } # Missing required fields
      ]
    }
    
    assert_not @insight.valid?
    assert @insight.errors[:data].any? { |error| error.include?('missing keys') }
  end

  test "should validate performance data structure" do
    @insight.insights_type = 'performance_metrics'
    @insight.data = { 'metrics' => 'not a hash' }
    
    assert_not @insight.valid?
    assert_includes @insight.errors[:data], 'performance metrics must be a hash'
  end

  test "should generate summary" do
    @insight.save!
    summary = @insight.to_summary
    
    assert_equal @insight.id, summary[:id]
    assert_equal @journey.id, summary[:journey_id]
    assert_equal 'ai_suggestions', summary[:insights_type]
    assert summary[:calculated_at].present?
    assert summary[:active]
    assert_equal ['suggestions'], summary[:data_keys]
  end

  test "should export insight data" do
    @insight.save!
    export = @insight.to_export
    
    assert_equal 'ai_suggestions', export[:insights_type]
    assert export[:data].present?
    assert export[:calculated_at].present?
    assert_equal @journey.id, export[:journey_context][:journey_id]
    assert_equal @journey.name, export[:journey_context][:journey_name]
  end

  test "should associate with journey" do
    @insight.save!
    
    assert_equal @journey, @insight.journey
    assert_includes @journey.journey_insights, @insight
  end
end