require "test_helper"

class CampaignTest < ActiveSupport::TestCase
  def setup
    @campaign = campaigns(:summer_launch)
    @brand_identity = brand_identities(:acme_corp)
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @campaign.valid?
  end

  test "should require name" do
    @campaign.name = nil
    assert_not @campaign.valid?
    assert_includes @campaign.errors[:name], "can't be blank"
  end

  test "should require name with minimum length" do
    @campaign.name = "ab"
    assert_not @campaign.valid?
    assert_includes @campaign.errors[:name], "is too short (minimum is 3 characters)"
  end

  test "should reject name that is too long" do
    @campaign.name = "a" * 101
    assert_not @campaign.valid?
    assert_includes @campaign.errors[:name], "is too long (maximum is 100 characters)"
  end

  test "should require purpose" do
    @campaign.purpose = nil
    assert_not @campaign.valid?
    assert_includes @campaign.errors[:purpose], "can't be blank"
  end

  test "should require purpose with minimum length" do
    @campaign.purpose = "short"
    assert_not @campaign.valid?
    assert_includes @campaign.errors[:purpose], "is too short (minimum is 10 characters)"
  end

  test "should validate budget_cents is non-negative when present" do
    @campaign.budget_cents = -100
    assert_not @campaign.valid?
    assert_includes @campaign.errors[:budget_cents], "must be greater than or equal to 0"

    @campaign.budget_cents = 0
    assert @campaign.valid?
    
    @campaign.budget_cents = 10000
    assert @campaign.valid?
  end

  test "should allow nil budget_cents" do
    @campaign.budget_cents = nil
    assert @campaign.valid?
  end

  test "should validate start_date is before end_date when both present" do
    @campaign.start_date = Date.today
    @campaign.end_date = Date.yesterday
    assert_not @campaign.valid?
    assert_includes @campaign.errors[:end_date], "must be after start date"
  end

  test "should allow same start_date and end_date" do
    same_date = Date.today
    @campaign.start_date = same_date
    @campaign.end_date = same_date
    assert @campaign.valid?
  end

  # Status and State Machine Tests
  test "should have default status of draft" do
    campaign = Campaign.new(name: "Test Campaign", purpose: "Test campaign purpose for testing")
    assert_equal "draft", campaign.status
  end

  test "should allow valid status transitions" do
    campaign = Campaign.create!(
      name: "Test Campaign", 
      purpose: "Test campaign purpose for testing",
      start_date: Date.current,
      end_date: 1.month.from_now.to_date
    )
    
    # Check initial state
    assert_equal "draft", campaign.status
    assert campaign.may_activate?
    
    # Activate campaign
    result = campaign.activate!
    assert result, "Activation should succeed"
    assert_equal "active", campaign.status
    
    # Pause campaign
    assert campaign.may_pause?
    campaign.pause!
    assert_equal "paused", campaign.status
    
    # Reactivate and complete
    campaign.activate!
    assert_equal "active", campaign.status
    assert campaign.may_complete?
    campaign.complete!
    assert_equal "completed", campaign.status
  end

  # Association Tests
  test "should optionally belong to brand identity" do
    campaign = Campaign.new(name: "Test Campaign", purpose: "Test campaign purpose for testing")
    assert campaign.valid? # should be valid without brand_identity
    
    campaign.brand_identity = @brand_identity
    assert_equal @brand_identity, campaign.brand_identity
  end

  test "should have many customer journeys" do
    assert_respond_to @campaign, :customer_journeys
    assert_includes @campaign.customer_journeys, customer_journeys(:awareness_to_purchase)
  end

  test "should have many content assets through customer journeys" do
    assert_respond_to @campaign, :content_assets
    journey = customer_journeys(:awareness_to_purchase)
    assert_includes @campaign.content_assets, content_assets(:welcome_email)
  end

  test "should destroy associated customer journeys when campaign is deleted" do
    campaign = campaigns(:summer_launch)
    journey_count = campaign.customer_journeys.count
    
    assert_difference 'CustomerJourney.count', -journey_count do
      campaign.destroy!
    end
  end

  # Scope Tests
  test "active scope should return only active campaigns" do
    active_campaigns = Campaign.active
    active_campaigns.each do |campaign|
      assert_equal "active", campaign.status
    end
    assert_includes active_campaigns, campaigns(:summer_launch)
  end

  test "by_status scope should filter by status" do
    planning_campaigns = Campaign.by_status("planning")
    planning_campaigns.each do |campaign|
      assert_equal "planning", campaign.status
    end
    assert_includes planning_campaigns, campaigns(:holiday_campaign)
  end

  test "with_budget scope should return campaigns with budget_cents set" do
    campaigns_with_budget = Campaign.with_budget
    campaigns_with_budget.each do |campaign|
      assert_not_nil campaign.budget_cents
      assert campaign.budget_cents >= 0
    end
  end

  # Custom Method Tests
  test "duration_days should calculate days between start and end dates" do
    campaign = campaigns(:startup_awareness)
    expected_duration = (campaign.end_date - campaign.start_date).to_i + 1
    assert_equal expected_duration, campaign.duration_days
  end

  test "duration_days should return nil when dates are missing" do
    @campaign.start_date = nil
    @campaign.end_date = nil
    assert_nil @campaign.duration_days
  end

  test "days_remaining should calculate days until end date for active campaigns" do
    campaign = Campaign.new(status: "active")
    campaign.end_date = 5.days.from_now.to_date
    assert_equal 5, campaign.days_remaining
  end

  test "days_remaining should return nil for non-active campaigns" do
    campaign = Campaign.new(status: "draft")
    campaign.end_date = 5.days.from_now.to_date
    assert_nil campaign.days_remaining
  end

  test "days_remaining should return nil when end_date is nil" do
    campaign = Campaign.new(status: "active")
    assert_nil campaign.days_remaining
  end

  test "budget getter should convert budget_cents to dollars" do
    @campaign.budget_cents = 10000  # $100.00
    assert_equal 100.0, @campaign.budget
  end

  test "budget getter should return nil when budget_cents is nil" do
    @campaign.budget_cents = nil
    assert_nil @campaign.budget
  end

  test "budget setter should convert dollar amount to cents" do
    @campaign.budget = 150.50
    assert_equal 15050, @campaign.budget_cents
  end

  test "progress_percentage should calculate campaign progress" do
    campaign = Campaign.new(status: "active")
    campaign.start_date = 10.days.ago.to_date
    campaign.end_date = 10.days.from_now.to_date
    expected_progress = 50.0  # halfway through
    assert_equal expected_progress, campaign.progress_percentage
  end

  # Counter Cache Tests
  test "should update customer_journeys_count when journeys are added" do
    campaign = campaigns(:paused_campaign)
    initial_count = campaign.customer_journeys.count
    
    journey = campaign.customer_journeys.create!(
      name: "Test Journey",
      description: "Test journey for counter cache",
      stages: [],
      touchpoints: {},
      content_types: ["email"],
      metrics: {}
    )
    
    assert_equal initial_count + 1, campaign.customer_journeys.count
  end

  # Status Method Tests
  test "should provide status color helper" do
    @campaign.status = "active"
    assert_equal 'bg-green-100 text-green-800', @campaign.status_color
    
    @campaign.status = "draft"
    assert_equal 'bg-gray-100 text-gray-600', @campaign.status_color
  end

  test "can_be_activated? should check dates and status" do
    campaign = Campaign.new(status: "draft")
    assert_not campaign.can_be_activated?
    
    campaign.start_date = Date.current
    campaign.end_date = 1.month.from_now.to_date
    assert campaign.can_be_activated?
  end

  test "overdue? should check if active campaign past end date" do
    campaign = Campaign.new(status: "active", end_date: 1.day.ago.to_date)
    assert campaign.overdue?
    
    campaign.end_date = 1.day.from_now.to_date
    assert_not campaign.overdue?
  end
end
