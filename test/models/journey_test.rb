require "test_helper"

class JourneyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @journey = create(:journey, user: @user)
  end
  
  test "should be valid with valid attributes" do
    assert @journey.valid?
  end
  
  test "should require a name" do
    @journey.name = nil
    assert_not @journey.valid?
    assert_includes @journey.errors[:name], "can't be blank"
  end
  
  test "should require a user" do
    journey = Journey.new(name: "Test", status: "draft")
    assert_not journey.valid?
    assert_includes journey.errors[:user], "must exist"
  end
  
  test "should have a default status of draft" do
    journey = Journey.new
    assert_equal "draft", journey.status
  end
  
  test "should only accept valid statuses" do
    Journey::STATUSES.each do |status|
      @journey.status = status
      assert @journey.valid?, "#{status} should be a valid status"
    end
    
    @journey.status = "invalid_status"
    assert_not @journey.valid?
  end
  
  test "should only accept valid campaign types" do
    Journey::CAMPAIGN_TYPES.each do |type|
      @journey.campaign_type = type
      assert @journey.valid?, "#{type} should be a valid campaign type"
    end
    
    @journey.campaign_type = "invalid_type"
    assert_not @journey.valid?
  end
  
  test "should publish journey" do
    assert_nil @journey.published_at
    @journey.publish!
    
    assert_equal "published", @journey.status
    assert_not_nil @journey.published_at
    assert @journey.published_at <= Time.current
  end
  
  test "should archive journey" do
    assert_nil @journey.archived_at
    @journey.archive!
    
    assert_equal "archived", @journey.status
    assert_not_nil @journey.archived_at
    assert @journey.archived_at <= Time.current
  end
  
  test "should duplicate journey with steps" do
    # Create some steps using factories
    step1 = create(:journey_step, journey: @journey, name: "Step 1", stage: "awareness", position: 0)
    step2 = create(:journey_step, journey: @journey, name: "Step 2", stage: "consideration", position: 1)
    
    duplicate = @journey.duplicate
    
    assert duplicate.persisted?
    assert_equal "#{@journey.name} (Copy)", duplicate.name
    assert_equal "draft", duplicate.status
    assert_nil duplicate.published_at
    assert_nil duplicate.archived_at
    assert_equal @journey.journey_steps.count, duplicate.journey_steps.count
    assert_equal step1.name, duplicate.journey_steps.order(:position).first.name
  end
  
  test "should count total steps" do
    assert_equal 0, @journey.total_steps
    
    create(:journey_step, journey: @journey, name: "Step 1", stage: "awareness")
    create(:journey_step, journey: @journey, name: "Step 2", stage: "consideration")
    
    assert_equal 2, @journey.total_steps
  end
  
  test "should group steps by stage" do
    create(:journey_step, journey: @journey, name: "Step 1", stage: "awareness")
    create(:journey_step, journey: @journey, name: "Step 2", stage: "awareness")
    create(:journey_step, journey: @journey, name: "Step 3", stage: "consideration")
    
    stages = @journey.steps_by_stage
    
    assert_equal 2, stages["awareness"]
    assert_equal 1, stages["consideration"]
  end
  
  test "should export to json format" do
    step = create(:journey_step, 
      journey: @journey,
      name: "Test Step",
      stage: "awareness",
      content_type: "email",
      channel: "email"
    )
    
    export = @journey.to_json_export
    
    assert_equal @journey.name, export[:name]
    assert_equal @journey.description, export[:description]
    assert_equal @journey.campaign_type, export[:campaign_type]
    assert_equal 1, export[:steps].size
    assert_equal step.name, export[:steps].first[:name]
  end
  
  test "should have proper scopes" do
    draft = create(:journey, user: @user, name: "Draft", status: "draft")
    published = create(:journey, user: @user, name: "Published", status: "published")
    archived = create(:journey, user: @user, name: "Archived", status: "archived")
    
    assert_includes Journey.draft, draft
    assert_not_includes Journey.draft, published
    
    assert_includes Journey.published, published
    assert_not_includes Journey.published, draft
    
    assert_includes Journey.archived, archived
    assert_not_includes Journey.archived, draft
    
    assert_includes Journey.active, draft
    assert_includes Journey.active, published
    assert_not_includes Journey.active, archived
  end
  
  test "metadata and settings should default to empty hash" do
    journey = create(:journey, user: @user, name: "Test", metadata: {}, settings: {})
    assert_equal({}, journey.metadata)
    assert_equal({}, journey.settings)
  end
  
  test "should calculate analytics summary" do
    # Create some analytics data with campaign
    campaign = @journey.campaign || create(:campaign, user: @user)
    @journey.update!(campaign: campaign) unless @journey.campaign
    
    create(:journey_analytics, 
      journey: @journey, 
      campaign: campaign,
      user: @user,
      total_executions: 100, 
      completed_executions: 80,
      abandoned_executions: 10
    )
    create(:journey_analytics, 
      journey: @journey, 
      campaign: campaign,
      user: @user,
      total_executions: 150, 
      completed_executions: 120,
      abandoned_executions: 20
    )
    
    summary = @journey.analytics_summary(30)
    
    assert_equal 250, summary[:total_executions]
    assert_equal 200, summary[:completed_executions]
    assert_equal 30, summary[:period_days]
  end
  
  test "should calculate performance score" do
    campaign = @journey.campaign || create(:campaign, user: @user)
    @journey.update!(campaign: campaign) unless @journey.campaign
    
    create(:journey_analytics, 
      journey: @journey, 
      campaign: campaign,
      user: @user,
      conversion_rate: 75.0, 
      engagement_score: 85.0,
      total_executions: 100,
      completed_executions: 90,
      abandoned_executions: 5
    )
    
    score = @journey.latest_performance_score
    assert score > 0
    assert score <= 100
  end
end