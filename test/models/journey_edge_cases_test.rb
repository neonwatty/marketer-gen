require "test_helper"

class JourneyEdgeCasesTest < ActiveSupport::TestCase
  test "handles JSON serialization edge cases" do
    journey = journeys(:awareness_journey)
    
    # Test with complex nested JSON
    complex_metadata = {
      "settings" => {
        "automation" => true,
        "triggers" => ["signup", "purchase"],
        "delays" => { "email" => "1 day", "sms" => "2 hours" }
      },
      "analytics" => {
        "conversion_rate" => 0.15,
        "engagement_score" => nil
      }
    }
    
    journey.update!(metadata: complex_metadata)
    journey.reload
    
    assert_equal complex_metadata, journey.metadata
    assert journey.metadata["analytics"]["engagement_score"].nil?
  end

  test "handles very long content in steps" do
    journey = journeys(:awareness_journey)
    long_content = "A" * 5000 # 5KB of content (reduced for test performance)
    
    step = journey.journey_steps.create!(
      title: "Long Content Step",
      step_type: "email",
      content: long_content,
      sequence_order: 99
    )
    
    assert_equal long_content, step.content
    assert step.valid?
  end

  test "validates sequence order gaps and reordering" do
    journey = journeys(:awareness_journey)
    
    # Clear existing steps to avoid conflicts
    journey.journey_steps.destroy_all
    
    # Create steps with gaps
    step1 = journey.journey_steps.create!(title: "Step 1", step_type: "email", sequence_order: 0)
    step3 = journey.journey_steps.create!(title: "Step 3", step_type: "email", sequence_order: 10)
    step2 = journey.journey_steps.create!(title: "Step 2", step_type: "email", sequence_order: 5)
    
    ordered = journey.ordered_steps.pluck(:title)
    assert_equal ["Step 1", "Step 2", "Step 3"], ordered
  end

  test "handles empty and nil JSON fields gracefully" do
    journey = journeys(:awareness_journey)
    
    # Test empty JSON objects
    journey.update!(metadata: {}, stages: [])
    journey.reload
    
    assert_equal({}, journey.metadata)
    assert_equal([], journey.stages)
    
    # Test nil values (should use defaults)
    journey.update!(metadata: nil, stages: nil)
    journey.reload
    
    # Should handle nil gracefully
    assert journey.metadata.nil? || journey.metadata == {}
    assert journey.stages.nil? || journey.stages == []
  end

  test "handles unicode and special characters in content" do
    journey = journeys(:awareness_journey)
    
    unicode_content = "Welcome 🎉 to our journey! Special chars: àáâãäåæçèéêë 中文 العربية"
    
    step = journey.journey_steps.create!(
      title: "Unicode Test 📧",
      step_type: "email",
      content: unicode_content,
      description: "Testing unicode: 🚀🎯💎",
      sequence_order: 50
    )
    
    step.reload
    assert_equal "Unicode Test 📧", step.title
    assert_equal unicode_content, step.content
    assert_includes step.description, "🚀🎯💎"
  end

  test "validates maximum length constraints" do
    journey = journeys(:awareness_journey)
    
    # Test name length validation
    long_name = "A" * 300 # Exceeds 255 character limit
    journey.name = long_name
    assert_not journey.valid?
    assert_includes journey.errors[:name], "is too long (maximum is 255 characters)"
    
    # Test description length validation  
    long_description = "A" * 1100 # Exceeds 1000 character limit
    journey.description = long_description
    assert_not journey.valid?
    assert_includes journey.errors[:description], "is too long (maximum is 1000 characters)"
  end

  test "handles concurrent step creation with unique sequence orders" do
    journey = journeys(:awareness_journey)
    max_order = journey.journey_steps.maximum(:sequence_order) || -1
    
    # Simulate concurrent creation attempts with same sequence order
    step1 = journey.journey_steps.build(
      title: "Concurrent Step 1",
      step_type: "email",
      sequence_order: max_order + 1
    )
    
    step2 = journey.journey_steps.build(
      title: "Concurrent Step 2", 
      step_type: "email",
      sequence_order: max_order + 1
    )
    
    step1.save!
    
    assert_not step2.valid?
    assert_includes step2.errors[:sequence_order], "must be unique within the journey"
  end

  test "handles step deletion and sequence order gaps" do
    journey = journeys(:awareness_journey)
    journey.journey_steps.destroy_all
    
    # Create sequential steps
    step1 = journey.journey_steps.create!(title: "Step 1", step_type: "email", sequence_order: 0)
    step2 = journey.journey_steps.create!(title: "Step 2", step_type: "email", sequence_order: 1)
    step3 = journey.journey_steps.create!(title: "Step 3", step_type: "email", sequence_order: 2)
    
    # Delete middle step
    step2.destroy!
    
    # Navigation should still work
    journey.reload
    assert_equal step3, step1.next_step
    assert_equal step1, step3.previous_step
    
    # Ordered steps should exclude deleted step
    remaining_titles = journey.ordered_steps.pluck(:title)
    assert_equal ["Step 1", "Step 3"], remaining_titles
  end

  test "handles malformed JSON gracefully" do
    journey = journeys(:awareness_journey)
    
    # Test with valid JSON that becomes invalid when modified
    valid_metadata = { "test" => "value" }
    journey.update!(metadata: valid_metadata)
    
    # Manually corrupt the serialized data would be database-level
    # Instead test edge case JSON structures
    edge_case_json = {
      "deeply" => {
        "nested" => {
          "structure" => {
            "with" => {
              "many" => {
                "levels" => "value"
              }
            }
          }
        }
      },
      "array_with_mixed_types" => [1, "string", true, nil, { "nested" => "object" }]
    }
    
    journey.update!(metadata: edge_case_json)
    journey.reload
    
    assert_equal "value", journey.metadata["deeply"]["nested"]["structure"]["with"]["many"]["levels"]
    assert_equal 5, journey.metadata["array_with_mixed_types"].length
  end
end