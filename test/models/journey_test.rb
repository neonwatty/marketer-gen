require "test_helper"

class JourneyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email_address: "journey_test@example.com",
      password: "password123",
      role: "marketer"
    )
    
    @journey = Journey.create!(
      user: @user,
      name: "Test Journey",
      description: "A test journey for unit tests",
      status: "draft",
      campaign_type: "product_launch"
    )
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
    # Create some steps
    step1 = @journey.journey_steps.create!(
      name: "Step 1",
      stage: "awareness",
      position: 0
    )
    step2 = @journey.journey_steps.create!(
      name: "Step 2", 
      stage: "consideration",
      position: 1
    )
    
    duplicate = @journey.duplicate
    
    assert duplicate.persisted?
    assert_equal "#{@journey.name} (Copy)", duplicate.name
    assert_equal "draft", duplicate.status
    assert_nil duplicate.published_at
    assert_nil duplicate.archived_at
    assert_equal @journey.journey_steps.count, duplicate.journey_steps.count
    assert_equal step1.name, duplicate.journey_steps.first.name
  end
  
  test "should count total steps" do
    assert_equal 0, @journey.total_steps
    
    @journey.journey_steps.create!(name: "Step 1", stage: "awareness")
    @journey.journey_steps.create!(name: "Step 2", stage: "consideration")
    
    assert_equal 2, @journey.total_steps
  end
  
  test "should group steps by stage" do
    @journey.journey_steps.create!(name: "Step 1", stage: "awareness")
    @journey.journey_steps.create!(name: "Step 2", stage: "awareness")
    @journey.journey_steps.create!(name: "Step 3", stage: "consideration")
    
    stages = @journey.steps_by_stage
    
    assert_equal 2, stages["awareness"]
    assert_equal 1, stages["consideration"]
  end
  
  test "should export to json format" do
    step = @journey.journey_steps.create!(
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
    draft = Journey.create!(user: @user, name: "Draft", status: "draft")
    published = Journey.create!(user: @user, name: "Published", status: "published")
    archived = Journey.create!(user: @user, name: "Archived", status: "archived")
    
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
    journey = Journey.create!(user: @user, name: "Test")
    assert_equal({}, journey.metadata)
    assert_equal({}, journey.settings)
  end
end