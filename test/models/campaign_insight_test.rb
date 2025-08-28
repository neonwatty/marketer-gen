# frozen_string_literal: true

require "test_helper"

class CampaignInsightTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @campaign_plan = campaign_plans(:one)
    @insight = campaign_insights(:one)
  end

  test "should be valid with valid attributes" do
    insight = CampaignInsight.new(
      campaign_plan: @campaign_plan,
      insight_type: 'competitive_analysis',
      insight_data: { "analysis" => "test data" },
      confidence_score: 0.85,
      analysis_date: Time.current
    )
    assert insight.valid?
  end

  test "should require campaign_plan" do
    insight = CampaignInsight.new(
      insight_type: 'competitive_analysis',
      insight_data: { "analysis" => "test data" },
      confidence_score: 0.85,
      analysis_date: Time.current
    )
    assert_not insight.valid?
    assert_includes insight.errors[:campaign_plan_id], "can't be blank"
  end

  test "should require insight_type" do
    insight = CampaignInsight.new(
      campaign_plan: @campaign_plan,
      insight_data: { "analysis" => "test data" },
      confidence_score: 0.85,
      analysis_date: Time.current
    )
    assert_not insight.valid?
    assert_includes insight.errors[:insight_type], "can't be blank"
  end

  test "should validate insight_type inclusion" do
    insight = CampaignInsight.new(
      campaign_plan: @campaign_plan,
      insight_type: 'invalid_type',
      insight_data: { "analysis" => "test data" },
      confidence_score: 0.85,
      analysis_date: Time.current
    )
    assert_not insight.valid?
    assert_includes insight.errors[:insight_type], "is not included in the list"
  end

  test "should require insight_data" do
    insight = CampaignInsight.new(
      campaign_plan: @campaign_plan,
      insight_type: 'competitive_analysis',
      confidence_score: 0.85,
      analysis_date: Time.current
    )
    assert_not insight.valid?
    assert_includes insight.errors[:insight_data], "can't be blank"
  end

  test "should require confidence_score" do
    insight = CampaignInsight.new(
      campaign_plan: @campaign_plan,
      insight_type: 'competitive_analysis',
      insight_data: { "analysis" => "test data" },
      analysis_date: Time.current
    )
    assert_not insight.valid?
    assert_includes insight.errors[:confidence_score], "can't be blank"
  end

  test "should validate confidence_score range" do
    insight = CampaignInsight.new(
      campaign_plan: @campaign_plan,
      insight_type: 'competitive_analysis',
      insight_data: { "analysis" => "test data" },
      confidence_score: 1.5,
      analysis_date: Time.current
    )
    assert_not insight.valid?
    assert_includes insight.errors[:confidence_score], "must be less than or equal to 1.0"

    insight.confidence_score = -0.1
    assert_not insight.valid?
    assert_includes insight.errors[:confidence_score], "must be greater than or equal to 0.0"
  end

  test "should require analysis_date" do
    insight = CampaignInsight.new(
      campaign_plan: @campaign_plan,
      insight_type: 'competitive_analysis',
      insight_data: { "analysis" => "test data" },
      confidence_score: 0.85
    )
    assert_not insight.valid?
    assert_includes insight.errors[:analysis_date], "can't be blank"
  end

  test "should serialize insight_data as JSON" do
    insight_data = { "competitive_advantages" => ["advantage1", "advantage2"], "threats" => ["threat1"] }
    insight = CampaignInsight.create!(
      campaign_plan: @campaign_plan,
      insight_type: 'competitive_analysis',
      insight_data: insight_data,
      confidence_score: 0.85,
      analysis_date: Time.current
    )
    
    insight.reload
    assert_equal insight_data, insight.insight_data
    assert_instance_of Hash, insight.insight_data
  end

  test "should serialize metadata as JSON" do
    metadata = { "source" => "LLM", "version" => "1.0" }
    insight = CampaignInsight.create!(
      campaign_plan: @campaign_plan,
      insight_type: 'competitive_analysis',
      insight_data: { "test" => "data" },
      confidence_score: 0.85,
      analysis_date: Time.current,
      metadata: metadata
    )
    
    insight.reload
    assert_equal metadata, insight.metadata
    assert_instance_of Hash, insight.metadata
  end

  test "recent scope should return insights from last 30 days" do
    old_insight = CampaignInsight.create!(
      campaign_plan: @campaign_plan,
      insight_type: 'competitive_analysis',
      insight_data: { "test" => "data" },
      confidence_score: 0.85,
      analysis_date: 35.days.ago
    )
    
    recent_insight = CampaignInsight.create!(
      campaign_plan: @campaign_plan,
      insight_type: 'market_trends',
      insight_data: { "test" => "data" },
      confidence_score: 0.75,
      analysis_date: 10.days.ago
    )
    
    recent_insights = CampaignInsight.recent
    assert_includes recent_insights, recent_insight
    assert_not_includes recent_insights, old_insight
  end

  test "by_type scope should filter by insight type" do
    competitive_insight = CampaignInsight.create!(
      campaign_plan: @campaign_plan,
      insight_type: 'competitive_analysis',
      insight_data: { "test" => "data" },
      confidence_score: 0.85,
      analysis_date: Time.current
    )
    
    trend_insight = CampaignInsight.create!(
      campaign_plan: @campaign_plan,
      insight_type: 'market_trends',
      insight_data: { "test" => "data" },
      confidence_score: 0.75,
      analysis_date: Time.current
    )
    
    competitive_insights = CampaignInsight.by_type('competitive_analysis')
    assert_includes competitive_insights, competitive_insight
    assert_not_includes competitive_insights, trend_insight
  end

  test "high_confidence scope should return insights with confidence >= 0.8" do
    high_confidence_insight = CampaignInsight.create!(
      campaign_plan: @campaign_plan,
      insight_type: 'competitive_analysis',
      insight_data: { "test" => "data" },
      confidence_score: 0.85,
      analysis_date: Time.current
    )
    
    low_confidence_insight = CampaignInsight.create!(
      campaign_plan: @campaign_plan,
      insight_type: 'market_trends',
      insight_data: { "test" => "data" },
      confidence_score: 0.65,
      analysis_date: Time.current
    )
    
    high_confidence_insights = CampaignInsight.high_confidence
    assert_includes high_confidence_insights, high_confidence_insight
    assert_not_includes high_confidence_insights, low_confidence_insight
  end

  test "for_campaign scope should return insights for specific campaign" do
    other_campaign = campaign_plans(:draft_plan)
    other_insight = CampaignInsight.create!(
      campaign_plan: other_campaign,
      insight_type: 'competitive_analysis',
      insight_data: { "test" => "data" },
      confidence_score: 0.85,
      analysis_date: Time.current
    )
    
    my_insight = CampaignInsight.create!(
      campaign_plan: @campaign_plan,
      insight_type: 'market_trends',
      insight_data: { "test" => "data" },
      confidence_score: 0.75,
      analysis_date: Time.current
    )
    
    campaign_insights = CampaignInsight.for_campaign(@campaign_plan.id)
    assert_includes campaign_insights, my_insight
    assert_not_includes campaign_insights, other_insight
  end

  test "latest_insights_for_campaign should return recent insights with limit" do
    5.times do |i|
      CampaignInsight.create!(
        campaign_plan: @campaign_plan,
        insight_type: 'competitive_analysis',
        insight_data: { "test" => "data#{i}" },
        confidence_score: 0.8,
        analysis_date: i.days.ago
      )
    end
    
    latest_insights = CampaignInsight.latest_insights_for_campaign(@campaign_plan.id, limit: 3)
    assert_equal 3, latest_insights.count
    
    # Should be ordered by analysis_date desc (most recent first)
    dates = latest_insights.map(&:analysis_date)
    assert_equal dates.sort.reverse, dates
  end

  test "insights_by_type_for_campaign should return specific type insights for campaign" do
    # Count existing competitive_analysis insights for this campaign
    initial_count = CampaignInsight.insights_by_type_for_campaign(@campaign_plan.id, 'competitive_analysis').count
    
    CampaignInsight.create!(
      campaign_plan: @campaign_plan,
      insight_type: 'competitive_analysis',
      insight_data: { "test" => "data" },
      confidence_score: 0.85,
      analysis_date: Time.current
    )
    
    CampaignInsight.create!(
      campaign_plan: @campaign_plan,
      insight_type: 'market_trends',
      insight_data: { "test" => "data" },
      confidence_score: 0.75,
      analysis_date: Time.current
    )
    
    competitive_insights = CampaignInsight.insights_by_type_for_campaign(@campaign_plan.id, 'competitive_analysis')
    assert_equal initial_count + 1, competitive_insights.count
    assert competitive_insights.all? { |insight| insight.insight_type == 'competitive_analysis' }
  end

  test "high_confidence? should return true for confidence >= 0.8" do
    high_insight = CampaignInsight.new(confidence_score: 0.85)
    low_insight = CampaignInsight.new(confidence_score: 0.75)
    
    assert high_insight.high_confidence?
    assert_not low_insight.high_confidence?
  end

  test "recent_insight? should return true for insights within 7 days" do
    recent_insight = CampaignInsight.new(analysis_date: 3.days.ago)
    old_insight = CampaignInsight.new(analysis_date: 10.days.ago)
    
    assert recent_insight.recent_insight?
    assert_not old_insight.recent_insight?
  end

  test "formatted_insight_data should return hash for valid JSON" do
    insight = CampaignInsight.new(insight_data: { "key" => "value" })
    assert_instance_of Hash, insight.formatted_insight_data
    assert_equal({ "key" => "value" }, insight.formatted_insight_data)
  end

  test "formatted_insight_data should return empty hash for non-hash data" do
    insight = CampaignInsight.new(insight_data: "invalid json")
    assert_instance_of Hash, insight.formatted_insight_data
    assert_equal({}, insight.formatted_insight_data)
  end

  test "should belong to campaign_plan" do
    assert_respond_to @insight, :campaign_plan
    assert_instance_of CampaignPlan, @insight.campaign_plan
  end

  test "should include all required INSIGHT_TYPES" do
    expected_types = %w[
      competitive_analysis
      market_trends
      performance_prediction
      strategic_recommendation
      trend_monitoring
      audience_intelligence
      budget_optimization
    ]
    
    assert_equal expected_types.sort, CampaignInsight::INSIGHT_TYPES.sort
  end
end