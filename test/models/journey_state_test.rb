require "test_helper"

class JourneyStateTest < ActiveSupport::TestCase
  test "journey status transitions" do
    journey = journeys(:awareness_journey)
    
    # Draft to Active
    assert journey.draft?
    journey.update!(status: "active")
    assert journey.active?
    assert_not journey.draft?
    
    # Active to Paused
    journey.update!(status: "paused")
    assert_not journey.active?
    assert_equal "paused", journey.status
    
    # Paused to Completed
    journey.update!(status: "completed")
    assert_equal "completed", journey.status
    assert_not journey.active?
    assert_not journey.draft?
    
    # Completed to Archived
    journey.update!(status: "archived")
    assert_equal "archived", journey.status
  end

  test "journey step navigation edge cases" do
    journey = journeys(:awareness_journey)
    
    # Clear existing steps
    journey.journey_steps.destroy_all
    
    # Single step journey
    single_step = journey.journey_steps.create!(
      title: "Only Step",
      step_type: "email",
      sequence_order: 0
    )
    
    assert single_step.first_step?
    assert single_step.last_step?
    assert_nil single_step.next_step
    assert_nil single_step.previous_step
  end

  test "journey scope filtering by status" do
    user = users(:one)
    
    # Create journeys with different statuses
    draft_journey = user.journeys.create!(name: "Draft Journey", campaign_type: "awareness", status: "draft")
    active_journey = user.journeys.create!(name: "Active Journey", campaign_type: "awareness", status: "active")
    paused_journey = user.journeys.create!(name: "Paused Journey", campaign_type: "awareness", status: "paused")
    completed_journey = user.journeys.create!(name: "Completed Journey", campaign_type: "awareness", status: "completed")
    
    # Test active scope
    active_journeys = Journey.active
    assert_includes active_journeys, active_journey
    assert_not_includes active_journeys, draft_journey
    assert_not_includes active_journeys, paused_journey
    assert_not_includes active_journeys, completed_journey
  end

  test "journey step state changes affect navigation" do
    journey = journeys(:awareness_journey)
    journey.journey_steps.destroy_all
    
    # Create a sequence of steps
    step1 = journey.journey_steps.create!(title: "Step 1", step_type: "email", sequence_order: 0)
    step2 = journey.journey_steps.create!(title: "Step 2", step_type: "email", sequence_order: 1)
    step3 = journey.journey_steps.create!(title: "Step 3", step_type: "email", sequence_order: 2)
    
    # Verify initial navigation
    assert_equal step2, step1.next_step
    assert_equal step3, step2.next_step
    assert_nil step3.next_step
    
    # Delete middle step
    step2.destroy!
    
    # Navigation should update
    step1.reload
    step3.reload
    assert_equal step3, step1.next_step
    assert_equal step1, step3.previous_step
  end

  test "journey campaign type affects default stages" do
    user = users(:one)
    
    # Test each campaign type gets correct default stages
    awareness_journey = user.journeys.create!(name: "Awareness", campaign_type: "awareness")
    assert_equal ["discovery", "education", "engagement"], awareness_journey.stages
    
    consideration_journey = user.journeys.create!(name: "Consideration", campaign_type: "consideration")
    assert_equal ["research", "evaluation", "comparison"], consideration_journey.stages
    
    conversion_journey = user.journeys.create!(name: "Conversion", campaign_type: "conversion")
    assert_equal ["decision", "purchase", "onboarding"], conversion_journey.stages
    
    retention_journey = user.journeys.create!(name: "Retention", campaign_type: "retention")
    assert_equal ["usage", "support", "renewal"], retention_journey.stages
    
    upsell_journey = user.journeys.create!(name: "Upsell", campaign_type: "upsell_cross_sell")
    assert_equal ["opportunity_identification", "presentation", "closing"], upsell_journey.stages
  end

  test "journey step type and channel validation states" do
    journey = journeys(:awareness_journey)
    
    # Test all valid step types
    valid_step_types = ["email", "social_post", "content_piece", "webinar", "event", "landing_page", "automation", "custom"]
    
    valid_step_types.each_with_index do |step_type, index|
      step = journey.journey_steps.create!(
        title: "#{step_type.capitalize} Step",
        step_type: step_type,
        sequence_order: index + 100
      )
      assert step.valid?, "Step type #{step_type} should be valid"
    end
    
    # Test all valid channels
    valid_channels = ["email", "social_media", "website", "blog", "video", "podcast", "webinar", "event", "sms", "push_notification"]
    
    valid_channels.each_with_index do |channel, index|
      step = journey.journey_steps.create!(
        title: "#{channel.capitalize} Channel Step",
        step_type: "email",
        channel: channel,
        sequence_order: index + 200
      )
      assert step.valid?, "Channel #{channel} should be valid"
    end
  end

  test "journey template type validation and states" do
    journey = journeys(:awareness_journey)
    
    # Test all valid template types
    valid_template_types = ["email", "social_media", "content", "webinar", "event", "custom"]
    
    valid_template_types.each do |template_type|
      journey.template_type = template_type
      assert journey.valid?, "Template type #{template_type} should be valid"
    end
    
    # Test nil template type (should be allowed)
    journey.template_type = nil
    assert journey.valid?, "Nil template type should be valid"
    
    # Test blank template type (should be allowed)
    journey.template_type = ""
    assert journey.valid?, "Blank template type should be valid"
  end

  test "journey state consistency with steps" do
    journey = journeys(:awareness_journey)
    
    # Journey with no steps
    journey.journey_steps.destroy_all
    assert_equal 0, journey.total_steps
    assert_equal [], journey.ordered_steps.to_a
    
    # Add steps and verify count updates
    step1 = journey.journey_steps.create!(title: "Step 1", step_type: "email", sequence_order: 0)
    assert_equal 1, journey.total_steps
    
    step2 = journey.journey_steps.create!(title: "Step 2", step_type: "email", sequence_order: 1)
    assert_equal 2, journey.total_steps
    
    # Verify ordered steps are correct
    ordered_titles = journey.ordered_steps.pluck(:title)
    assert_equal ["Step 1", "Step 2"], ordered_titles
  end

  test "journey user association integrity" do
    user1 = users(:one)
    user2 = User.create!(email_address: "test2@example.com", password: "password123")
    
    journey = user1.journeys.create!(name: "User 1 Journey", campaign_type: "awareness")
    
    # Journey should belong to correct user
    assert_equal user1, journey.user
    assert_includes user1.journeys, journey
    assert_not_includes user2.journeys, journey
    
    # User deletion should cascade to journeys
    user_id = user2.id
    test_journey = user2.journeys.create!(name: "Test Journey", campaign_type: "awareness")
    test_journey_id = test_journey.id
    
    user2.destroy!
    
    # Journey should be deleted when user is deleted
    assert_not Journey.exists?(test_journey_id)
  end

  test "journey metadata state preservation" do
    journey = journeys(:awareness_journey)
    
    original_metadata = {
      "version" => "1.0",
      "created_by" => "system",
      "tags" => ["marketing", "email"]
    }
    
    journey.update!(metadata: original_metadata)
    
    # Update other fields, metadata should be preserved
    journey.update!(name: "Updated Name", description: "Updated Description")
    journey.reload
    
    assert_equal original_metadata, journey.metadata
    assert_equal "Updated Name", journey.name
    assert_equal "Updated Description", journey.description
  end
end