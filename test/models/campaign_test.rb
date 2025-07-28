require "test_helper"

class CampaignTest < ActiveSupport::TestCase
  def setup
    @user = users(:admin)
    @persona = Persona.create!(
      user: @user,
      name: "Test Persona",
      description: "Test persona description"
    )
    @campaign = Campaign.new(
      user: @user,
      persona: @persona,
      name: "Summer Product Launch",
      description: "Launch campaign for new summer product line",
      campaign_type: "product_launch",
      goals: "Increase brand awareness and drive sales",
      target_metrics: {
        conversion_rate: 5.0,
        engagement_rate: 15.0
      }
    )
  end

  test "should be valid with all required attributes" do
    assert @campaign.valid?
  end

  test "should require name" do
    @campaign.name = nil
    assert_not @campaign.valid?
    assert_includes @campaign.errors[:name], "can't be blank"
  end

  test "should require user" do
    @campaign.user = nil
    assert_not @campaign.valid?
    assert_includes @campaign.errors[:user], "must exist"
  end

  test "should require persona" do
    @campaign.persona = nil
    assert_not @campaign.valid?
    assert_includes @campaign.errors[:persona], "can't be blank"
  end

  test "should enforce uniqueness of name per user" do
    @campaign.save!
    
    duplicate_campaign = Campaign.new(
      user: @user,
      persona: @persona,
      name: "Summer Product Launch",
      description: "Another campaign with same name"
    )
    
    assert_not duplicate_campaign.valid?
    assert_includes duplicate_campaign.errors[:name], "has already been taken"
  end

  test "should allow same name for different users" do
    @campaign.save!
    
    other_user = User.create!(
      email_address: "other@example.com",
      password: "password123"
    )
    
    other_persona = Persona.create!(
      user: other_user,
      name: "Other Persona",
      description: "Test persona"
    )
    
    other_campaign = Campaign.new(
      user: other_user,
      persona: other_persona,
      name: "Summer Product Launch",
      description: "Same name, different user"
    )
    
    assert other_campaign.valid?
  end

  test "should have default status of draft" do
    assert_equal "draft", @campaign.status
  end

  test "should validate status inclusion" do
    @campaign.status = "invalid_status"
    assert_not @campaign.valid?
    assert_includes @campaign.errors[:status], "is not included in the list"
  end

  test "should validate campaign_type inclusion when present" do
    @campaign.campaign_type = "invalid_type"
    assert_not @campaign.valid?
    assert_includes @campaign.errors[:campaign_type], "is not included in the list"
  end

  test "should allow blank campaign_type" do
    @campaign.campaign_type = nil
    assert @campaign.valid?
  end

  test "should have default empty JSON fields" do
    campaign = Campaign.new(user: @user, persona: @persona, name: "Test")
    assert_equal({}, campaign.target_metrics)
    assert_equal({}, campaign.metadata)
    assert_equal({}, campaign.settings)
  end

  test "activate! should change status to active and set started_at" do
    @campaign.save!
    travel_to Time.zone.local(2025, 1, 1, 12, 0, 0) do
      @campaign.activate!
      
      assert_equal "active", @campaign.status
      assert_equal Time.current, @campaign.started_at
    end
  end

  test "pause! should change status to paused" do
    @campaign.save!
    @campaign.activate!
    @campaign.pause!
    
    assert_equal "paused", @campaign.status
  end

  test "complete! should change status to completed and set ended_at" do
    @campaign.save!
    @campaign.activate!
    
    travel_to Time.zone.local(2025, 2, 1, 12, 0, 0) do
      @campaign.complete!
      
      assert_equal "completed", @campaign.status
      assert_equal Time.current, @campaign.ended_at
    end
  end

  test "archive! should change status to archived" do
    @campaign.save!
    @campaign.archive!
    
    assert_equal "archived", @campaign.status
  end

  test "active? should return true when status is active" do
    @campaign.status = "active"
    assert @campaign.active?
    
    @campaign.status = "draft"
    assert_not @campaign.active?
  end

  test "running? should return true for active or paused status" do
    @campaign.status = "active"
    assert @campaign.running?
    
    @campaign.status = "paused"
    assert @campaign.running?
    
    @campaign.status = "draft"
    assert_not @campaign.running?
  end

  test "completed? should return true when status is completed" do
    @campaign.status = "completed"
    assert @campaign.completed?
    
    @campaign.status = "active"
    assert_not @campaign.completed?
  end

  test "duration_days should calculate duration correctly" do
    @campaign.save!
    
    start_time = Time.zone.local(2025, 1, 1, 12, 0, 0)
    end_time = Time.zone.local(2025, 1, 15, 12, 0, 0)
    
    @campaign.update!(started_at: start_time, ended_at: end_time)
    
    assert_equal 14, @campaign.duration_days
  end

  test "duration_days should use current time when campaign is running" do
    @campaign.save!
    
    travel_to Time.zone.local(2025, 1, 15, 12, 0, 0) do
      @campaign.update!(started_at: 7.days.ago)
      
      assert_equal 7, @campaign.duration_days
    end
  end

  test "duration_days should return 0 when not started" do
    @campaign.save!
    assert_equal 0, @campaign.duration_days
  end

  test "total_journeys should count associated journeys" do
    @campaign.save!
    assert_equal 0, @campaign.total_journeys
    
    Journey.create!(
      user: @user,
      campaign: @campaign,
      name: "Journey 1",
      description: "Test journey"
    )
    
    Journey.create!(
      user: @user,
      campaign: @campaign,
      name: "Journey 2",
      description: "Test journey"
    )
    
    assert_equal 2, @campaign.total_journeys
  end

  test "active_journeys should count published journeys" do
    @campaign.save!
    
    Journey.create!(
      user: @user,
      campaign: @campaign,
      name: "Published Journey",
      description: "Test journey",
      status: "published"
    )
    
    Journey.create!(
      user: @user,
      campaign: @campaign,
      name: "Draft Journey",
      description: "Test journey",
      status: "draft"
    )
    
    assert_equal 1, @campaign.active_journeys
  end

  test "progress_percentage should calculate progress correctly" do
    @campaign.save!
    
    # Create total journeys
    5.times do |i|
      Journey.create!(
        user: @user,
        campaign: @campaign,
        name: "Journey #{i + 1}",
        description: "Test journey"
      )
    end
    
    # Publish 2 journeys
    @campaign.journeys.limit(2).update_all(status: "published")
    
    assert_equal 40, @campaign.progress_percentage # 2/5 * 100
  end

  test "target_audience_context should return persona context" do
    @campaign.save!
    context = @campaign.target_audience_context
    
    assert_equal @persona.to_campaign_context, context
  end

  test "to_analytics_context should provide analytics context" do
    @campaign.save!
    @campaign.update!(started_at: 10.days.ago)
    
    context = @campaign.to_analytics_context
    
    assert_equal @campaign.id, context[:id]
    assert_equal @campaign.name, context[:name]
    assert_equal @campaign.campaign_type, context[:type]
    assert_equal @persona.name, context[:persona]
    assert_equal @campaign.status, context[:status]
    assert_equal 10, context[:duration_days]
    assert_includes context, :performance
    assert_includes context, :journeys_count
  end

  test "scopes should work correctly" do
    @campaign.save!
    
    # Test draft scope
    assert_includes Campaign.draft, @campaign
    
    @campaign.activate!
    
    # Test active scope
    assert_includes Campaign.active, @campaign
    assert_not_includes Campaign.draft, @campaign
    
    @campaign.complete!
    
    # Test completed scope
    assert_includes Campaign.completed, @campaign
    assert_not_includes Campaign.active, @campaign
  end

  test "by_type scope should filter by campaign type" do
    @campaign.save!
    
    other_campaign = Campaign.create!(
      user: @user,
      persona: @persona,
      name: "Brand Campaign",
      campaign_type: "brand_awareness"
    )
    
    product_campaigns = Campaign.by_type("product_launch")
    brand_campaigns = Campaign.by_type("brand_awareness")
    
    assert_includes product_campaigns, @campaign
    assert_not_includes product_campaigns, other_campaign
    
    assert_includes brand_campaigns, other_campaign
    assert_not_includes brand_campaigns, @campaign
  end

  test "for_persona scope should filter by persona" do
    @campaign.save!
    
    other_persona = Persona.create!(
      user: @user,
      name: "Other Persona",
      description: "Other persona description"
    )
    
    other_campaign = Campaign.create!(
      user: @user,
      persona: other_persona,
      name: "Other Campaign"
    )
    
    persona_campaigns = Campaign.for_persona(@persona.id)
    
    assert_includes persona_campaigns, @campaign
    assert_not_includes persona_campaigns, other_campaign
  end

  test "should have proper associations" do
    @campaign.save!
    
    # Test journey association
    journey = Journey.create!(
      user: @user,
      campaign: @campaign,
      name: "Test Journey",
      description: "Test journey description"
    )
    
    assert_includes @campaign.journeys, journey
    
    # Test ab_tests association
    ab_test = AbTest.create!(
      campaign: @campaign,
      user: @user,
      name: "Test A/B Test",
      hypothesis: "Test hypothesis"
    )
    
    assert_includes @campaign.ab_tests, ab_test
  end
end