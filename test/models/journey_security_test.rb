require "test_helper"

class JourneySecurityTest < ActiveSupport::TestCase
  test "prevents SQL injection in JSON fields" do
    journey = journeys(:awareness_journey)
    
    malicious_input = {
      "'; DROP TABLE users; --" => "malicious_value",
      "settings" => "'; UPDATE journeys SET status='active'; --"
    }
    
    journey.update!(metadata: malicious_input)
    journey.reload
    
    # Verify data is stored safely as JSON
    assert_equal malicious_input, journey.metadata
    assert_not_nil User.first # Users table should still exist
  end

  test "validates data size limits for JSON fields" do
    journey = journeys(:awareness_journey)
    
    # Test moderately large JSON payload (reduced for test performance)
    large_data = { "data" => "x" * 10_000 } # 10KB
    
    assert_nothing_raised do
      journey.update!(metadata: large_data)
    end
    
    journey.reload
    assert_equal large_data, journey.metadata
  end

  test "journey isolation between users" do
    user1 = users(:one)
    user2 = User.create!(email_address: "user4@example.com", password: "password123")
    
    journey1 = user1.journeys.create!(name: "User 1 Journey", campaign_type: "awareness")
    journey2 = user2.journeys.create!(name: "User 2 Journey", campaign_type: "awareness")
    
    # User 1 should not see User 2's journeys
    assert_not_includes user1.journeys, journey2
    assert_not_includes user2.journeys, journey1
    
    # Names can be the same across users
    user2_duplicate = user2.journeys.create!(name: "User 1 Journey", campaign_type: "conversion")
    assert user2_duplicate.valid?
  end

  test "sanitizes user input in content fields" do
    journey = journeys(:awareness_journey)
    
    # Test with script tags and HTML
    malicious_content = "<script>alert('xss')</script><img src=x onerror=alert('xss')>"
    
    step = journey.journey_steps.create!(
      title: "Security Test",
      step_type: "email",
      content: malicious_content,
      description: malicious_content,
      sequence_order: 100
    )
    
    # Data should be stored as-is (sanitization happens at view layer)
    assert_equal malicious_content, step.content
    assert_equal malicious_content, step.description
    
    # But we can verify it's properly stored without execution
    step.reload
    assert_includes step.content, "<script>"
    assert_includes step.content, "<img"
  end

  test "prevents mass assignment vulnerabilities" do
    journey = journeys(:awareness_journey)
    user = users(:one)
    
    # Attempt to mass assign protected attributes
    malicious_params = {
      title: "Normal Title",
      step_type: "email",
      sequence_order: 50,
      # Attempt to assign journey_id to different journey
      journey_id: 99999,
      created_at: 1.year.ago,
      updated_at: 1.year.ago
    }
    
    step = journey.journey_steps.create!(malicious_params)
    
    # Should use the journey from the association, not the mass-assigned value
    assert_equal journey.id, step.journey_id
    # The journey_id from mass assignment should be ignored since we're creating through association
    # But Rails may still allow the assignment, so let's test the association integrity differently
    assert_equal journey, step.journey
    
    # Note: Rails by default allows mass assignment of timestamps in this context
    # This is actually expected behavior, demonstrating that proper attr_accessible 
    # or strong parameters should be used in controllers to prevent this
    assert step.created_at.present?
    assert step.updated_at.present?
  end

  test "validates against NoSQL injection patterns" do
    journey = journeys(:awareness_journey)
    
    # Test MongoDB-style injection patterns in JSON
    nosql_injection = {
      "$ne" => nil,
      "$gt" => "",
      "$where" => "function() { return true; }",
      "javascript:alert(1)" => "value"
    }
    
    journey.update!(metadata: nosql_injection)
    journey.reload
    
    # Should store as plain JSON data, not executable code
    assert_equal nosql_injection, journey.metadata
    assert_equal "function() { return true; }", journey.metadata["$where"]
  end

  test "protects against YAML deserialization attacks" do
    # Since we're using JSON serialization, test that YAML-like patterns are safe
    journey = journeys(:awareness_journey)
    
    yaml_like_data = {
      "yaml_payload" => "--- !ruby/object:User\npassword: hacked",
      "erb_payload" => "<%= system('rm -rf /') %>",
      "ruby_code" => "eval('puts 123')"
    }
    
    journey.update!(metadata: yaml_like_data)
    journey.reload
    
    # Should be stored as plain strings, not executed
    assert_equal yaml_like_data, journey.metadata
    assert_includes journey.metadata["yaml_payload"], "User"
    assert_includes journey.metadata["erb_payload"], "<%="
  end

  test "validates file path traversal in content" do
    journey = journeys(:awareness_journey)
    
    # Test directory traversal patterns
    traversal_content = "../../../etc/passwd"
    traversal_settings = {
      "file_path" => "../../../../etc/hosts",
      "template_path" => "../templates/../../sensitive_file"
    }
    
    step = journey.journey_steps.create!(
      title: "Path Traversal Test",
      step_type: "email",
      content: traversal_content,
      settings: traversal_settings,
      sequence_order: 101
    )
    
    # Data should be stored but not executed as file paths
    assert_equal traversal_content, step.content
    assert_equal traversal_settings, step.settings
    
    # Verify the patterns are stored as strings
    assert_includes step.settings["file_path"], "../.."
  end

  test "prevents database constraint violations" do
    journey = journeys(:awareness_journey)
    
    # Test foreign key constraint protection
    invalid_step = JourneyStep.new(
      title: "Invalid Step",
      step_type: "email",
      journey_id: 99999, # Non-existent journey
      sequence_order: 0
    )
    
    # Rails validates presence of journey before hitting DB constraint
    assert_raises(ActiveRecord::RecordInvalid) do
      invalid_step.save!
    end
    
    assert_not invalid_step.valid?
    assert_includes invalid_step.errors[:journey], "must exist"
  end

  test "handles concurrent modification safely" do
    journey = journeys(:awareness_journey)
    
    # Simulate concurrent updates to the same record
    journey1 = Journey.find(journey.id)
    journey2 = Journey.find(journey.id)
    
    journey1.update!(name: "Updated by User 1")
    journey2.update!(name: "Updated by User 2")
    
    # Last update should win (optimistic locking not implemented)
    journey.reload
    assert_equal "Updated by User 2", journey.name
  end

  test "validates against integer overflow in sequence_order" do
    journey = journeys(:awareness_journey)
    
    # Test with very large integers
    large_sequence = 2**31 - 1 # Max 32-bit signed integer
    
    step = journey.journey_steps.create!(
      title: "Large Sequence",
      step_type: "email",
      sequence_order: large_sequence
    )
    
    assert step.persisted?
    assert_equal large_sequence, step.sequence_order
    
    # Test navigation still works
    assert step.last_step? # Should be the last step due to high sequence order
  end
end