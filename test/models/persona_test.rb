require "test_helper"

class PersonaTest < ActiveSupport::TestCase
  def setup
    @user = users(:admin)
    @persona = Persona.new(
      user: @user,
      name: "Tech-Savvy Millennial",
      description: "Young professionals interested in technology and innovation",
      demographics: {
        age_range: "25-35",
        gender: "mixed",
        location: "urban",
        income_level: "middle_to_high",
        education_level: "college_graduate"
      },
      behaviors: {
        online_activity: "high",
        purchase_behavior: "research_driven",
        social_media_usage: "active"
      },
      preferences: {
        messaging_tone: "professional_friendly",
        channel_preferences: ["email", "social_media"],
        content_types: ["articles", "videos"]
      },
      psychographics: {
        values: ["innovation", "efficiency"],
        lifestyle: "busy_professional",
        motivations: ["career_growth", "work_life_balance"]
      }
    )
  end

  test "should be valid with all required attributes" do
    assert @persona.valid?
  end

  test "should require name" do
    @persona.name = nil
    assert_not @persona.valid?
    assert_includes @persona.errors[:name], "can't be blank"
  end

  test "should require description" do
    @persona.description = nil
    assert_not @persona.valid?
    assert_includes @persona.errors[:description], "can't be blank"
  end

  test "should require user" do
    @persona.user = nil
    assert_not @persona.valid?
    assert_includes @persona.errors[:user], "must exist"
  end

  test "should enforce uniqueness of name per user" do
    @persona.save!
    
    duplicate_persona = Persona.new(
      user: @user,
      name: "Tech-Savvy Millennial",
      description: "Another persona with same name"
    )
    
    assert_not duplicate_persona.valid?
    assert_includes duplicate_persona.errors[:name], "has already been taken"
  end

  test "should allow same name for different users" do
    @persona.save!
    
    other_user = User.create!(
      email_address: "other@example.com",
      password: "password123"
    )
    
    other_persona = Persona.new(
      user: other_user,
      name: "Tech-Savvy Millennial",
      description: "Same name, different user"
    )
    
    assert other_persona.valid?
  end

  test "should have default empty JSON fields" do
    persona = Persona.new(user: @user, name: "Test", description: "Test")
    assert_equal({}, persona.demographics)
    assert_equal({}, persona.behaviors)
    assert_equal({}, persona.preferences)
    assert_equal({}, persona.psychographics)
  end

  test "display_name should return name" do
    assert_equal "Tech-Savvy Millennial", @persona.display_name
  end

  test "age_range should return age range from demographics" do
    @persona.save!
    assert_equal "25-35", @persona.age_range
  end

  test "primary_channel should return first channel preference" do
    @persona.save!
    assert_equal "email", @persona.primary_channel
  end

  test "demographics_summary should format demographics nicely" do
    @persona.save!
    summary = @persona.demographics_summary
    
    assert_includes summary, "Age: 25-35"
    assert_includes summary, "Location: urban"
    assert_includes summary, "Income: middle_to_high"
  end

  test "demographics_summary should handle empty demographics" do
    @persona.demographics = {}
    @persona.save!
    
    assert_equal "No demographics data", @persona.demographics_summary
  end

  test "behavior_summary should format behaviors nicely" do
    @persona.save!
    summary = @persona.behavior_summary
    
    assert_includes summary, "Online: high"
    assert_includes summary, "Purchase: research_driven"
    assert_includes summary, "Social: active"
  end

  test "behavior_summary should handle empty behaviors" do
    @persona.behaviors = {}
    @persona.save!
    
    assert_equal "No behavior data", @persona.behavior_summary
  end

  test "to_campaign_context should provide context for campaigns" do
    @persona.save!
    context = @persona.to_campaign_context
    
    assert_equal "Tech-Savvy Millennial", context[:name]
    assert_equal @persona.description, context[:description]
    assert_includes context[:demographics], "Age: 25-35"
    assert_includes context[:behaviors], "Online: high"
    assert_equal "professional_friendly", context[:preferences]
    assert_equal ["email", "social_media"], context[:channels]
  end

  test "should have campaigns association" do
    @persona.save!
    
    campaign = Campaign.create!(
      user: @user,
      persona: @persona,
      name: "Test Campaign",
      description: "Test campaign description"
    )
    
    assert_includes @persona.campaigns, campaign
  end

  test "should have journeys through campaigns" do
    @persona.save!
    
    campaign = Campaign.create!(
      user: @user,
      persona: @persona,
      name: "Test Campaign",
      description: "Test campaign description"
    )
    
    journey = Journey.create!(
      user: @user,
      campaign: campaign,
      name: "Test Journey",
      description: "Test journey description"
    )
    
    assert_includes @persona.journeys, journey
  end

  test "active scope should return personas with active campaigns" do
    @persona.save!
    
    campaign = Campaign.create!(
      user: @user,
      persona: @persona,
      name: "Test Campaign",
      description: "Test campaign description",
      status: "active"
    )
    
    active_personas = Persona.active
    assert_includes active_personas, @persona
  end

  test "total_campaigns should count campaigns" do
    @persona.save!
    assert_equal 0, @persona.total_campaigns
    
    Campaign.create!(
      user: @user,
      persona: @persona,
      name: "Test Campaign 1",
      description: "Test campaign description"
    )
    
    Campaign.create!(
      user: @user,
      persona: @persona,
      name: "Test Campaign 2",
      description: "Test campaign description"
    )
    
    assert_equal 2, @persona.total_campaigns
  end

  test "active_campaigns should count active campaigns" do
    @persona.save!
    
    Campaign.create!(
      user: @user,
      persona: @persona,
      name: "Active Campaign",
      description: "Test campaign description",
      status: "active"
    )
    
    Campaign.create!(
      user: @user,
      persona: @persona,
      name: "Draft Campaign",
      description: "Test campaign description",
      status: "draft"
    )
    
    assert_equal 1, @persona.active_campaigns
  end
end