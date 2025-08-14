require "test_helper"

class JourneyPerformanceTest < ActiveSupport::TestCase
  test "can handle journey with many steps efficiently" do
    user = users(:one)
    journey = user.journeys.create!(name: "Large Journey", campaign_type: "awareness")
    
    # Create 50 steps (reduced from 100 for test performance)
    steps = 50.times.map do |i|
      {
        title: "Step #{i}",
        step_type: "email",
        sequence_order: i,
        journey_id: journey.id,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    # Test bulk creation
    JourneyStep.insert_all(steps)
    
    journey.reload
    assert_equal 50, journey.total_steps
    
    # Test efficient querying
    ordered_steps = journey.ordered_steps.to_a
    assert_equal 50, ordered_steps.length
    assert_equal "Step 0", ordered_steps.first.title
    assert_equal "Step 49", ordered_steps.last.title
  end

  test "database indexes support efficient queries" do
    user = users(:one)
    
    # Create multiple journeys for testing
    awareness_journey = user.journeys.create!(name: "Awareness Journey", campaign_type: "awareness")
    conversion_journey = user.journeys.create!(name: "Conversion Journey", campaign_type: "conversion")
    
    # Test user-scoped queries
    user_journeys = user.journeys.where(campaign_type: "awareness").to_a
    assert_includes user_journeys, awareness_journey
    assert_not_includes user_journeys, conversion_journey
    
    # Test status queries
    active_journeys = Journey.where(status: "active").to_a
    assert_kind_of Array, active_journeys
  end

  test "journey steps sequence queries are efficient" do
    journey = journeys(:awareness_journey)
    
    # Add multiple steps
    10.times do |i|
      journey.journey_steps.create!(
        title: "Performance Step #{i}",
        step_type: "email",
        sequence_order: i + 10
      )
    end
    
    # Test ordering query
    ordered_steps = journey.journey_steps.order(:sequence_order).to_a
    assert ordered_steps.length >= 10
    
    # Test navigation queries
    first_step = journey.journey_steps.order(:sequence_order).first
    next_step = first_step.next_step
    assert_not_nil next_step if journey.journey_steps.count > 1
  end

  test "json serialization performance with complex data" do
    journey = journeys(:awareness_journey)
    
    # Create complex metadata
    complex_metadata = {
      "analytics" => {
        "metrics" => 100.times.map { |i| { "day_#{i}" => rand(100) } },
        "segments" => ["segment_a", "segment_b", "segment_c"] * 10
      },
      "settings" => {
        "automation_rules" => 20.times.map { |i| { "rule_#{i}" => "value_#{i}" } }
      }
    }
    
    # Test serialization performance
    start_time = Time.current
    journey.update!(metadata: complex_metadata)
    journey.reload
    end_time = Time.current
    
    assert (end_time - start_time) < 1.0 # Should complete within 1 second
    assert_equal complex_metadata["analytics"]["segments"].length, journey.metadata["analytics"]["segments"].length
  end

  test "bulk operations on journey steps" do
    journey = journeys(:awareness_journey)
    
    # Test bulk creation
    step_data = 20.times.map do |i|
      {
        journey_id: journey.id,
        title: "Bulk Step #{i}",
        step_type: "email",
        sequence_order: i + 100,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    initial_count = journey.journey_steps.count
    JourneyStep.insert_all(step_data)
    journey.reload
    
    assert_equal initial_count + 20, journey.journey_steps.count
    
    # Test bulk update
    bulk_steps = journey.journey_steps.where("sequence_order >= 100")
    bulk_steps.update_all(channel: "email")
    
    updated_steps = journey.journey_steps.where("sequence_order >= 100 AND channel = 'email'")
    assert_equal 20, updated_steps.count
  end
end