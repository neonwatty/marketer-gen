require "test_helper"

class JourneyManagementTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
  end

  test "user can create complete journey with steps" do
    journey = @user.journeys.create!(
      name: "Complete Campaign Journey",
      campaign_type: "conversion",
      description: "Full customer conversion journey"
    )

    # Add multiple steps in sequence
    step1 = journey.journey_steps.create!(
      title: "Welcome Email",
      step_type: "email",
      sequence_order: 0
    )

    step2 = journey.journey_steps.create!(
      title: "Product Demo",
      step_type: "webinar",
      sequence_order: 1
    )

    assert_equal 2, journey.total_steps
    assert_equal step1, step2.previous_step
    assert_equal step2, step1.next_step
    assert journey.active? == false # should be draft by default
  end

  test "journey deletion cascades to steps" do
    journey = @user.journeys.create!(name: "Test Journey", campaign_type: "awareness")
    journey.journey_steps.create!(title: "Step 1", step_type: "email", sequence_order: 0)
    journey.journey_steps.create!(title: "Step 2", step_type: "email", sequence_order: 1)

    step_count_before = JourneyStep.count
    journey.destroy!
    
    assert_equal step_count_before - 2, JourneyStep.count
  end

  test "user can create journey from template" do
    template = JourneyTemplate.create!(
      name: "Email Campaign Template",
      campaign_type: "awareness",
      template_data: {
        "stages" => ["discovery", "education", "engagement"],
        "steps" => [
          {
            "title" => "Welcome Email",
            "step_type" => "email",
            "content" => "Welcome!",
            "channel" => "email"
          }
        ]
      }
    )

    journey = template.create_journey_for_user(@user, name: "My Campaign")
    
    assert journey.persisted?
    assert_equal "My Campaign", journey.name
    assert_equal 1, journey.journey_steps.count
    assert_equal "Welcome Email", journey.journey_steps.first.title
  end

  test "multiple users can have journeys with same name" do
    user2 = User.create!(email_address: "user2@example.com", password: "password123")
    
    journey1 = @user.journeys.create!(name: "Same Name", campaign_type: "awareness")
    journey2 = user2.journeys.create!(name: "Same Name", campaign_type: "conversion")
    
    assert journey1.valid?
    assert journey2.valid?
    assert_not_equal journey1.user, journey2.user
  end

  test "journey step sequence ordering works correctly" do
    journey = @user.journeys.create!(name: "Sequence Test", campaign_type: "awareness")
    
    # Create steps out of order
    step3 = journey.journey_steps.create!(title: "Step 3", step_type: "email", sequence_order: 2)
    step1 = journey.journey_steps.create!(title: "Step 1", step_type: "email", sequence_order: 0)
    step2 = journey.journey_steps.create!(title: "Step 2", step_type: "email", sequence_order: 1)
    
    ordered_titles = journey.ordered_steps.pluck(:title)
    assert_equal ["Step 1", "Step 2", "Step 3"], ordered_titles
    
    # Test navigation
    assert_equal step2, step1.next_step
    assert_equal step3, step2.next_step
    assert_nil step3.next_step
    
    assert_nil step1.previous_step
    assert_equal step1, step2.previous_step
    assert_equal step2, step3.previous_step
  end
end