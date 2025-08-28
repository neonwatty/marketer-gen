require "test_helper"

class JourneyTemplatePerformanceTest < ActiveSupport::TestCase
  # Disable transaction isolation for performance tests
  self.use_transactional_tests = false
  
  def setup
    # Simple cleanup without database operations that might cause locks
    super
  end
  
  def teardown
    # Simple cleanup without database operations that might cause locks
    super
  end
  
  test "template cloning performance with large datasets" do
    # Create template with many steps
    large_steps = 100.times.map do |i|
      {
        "title" => "Step #{i}",
        "step_type" => "email",
        "content" => { "type" => "educational" },
        "settings" => { "delay" => "#{i} hours" },
        "stage" => "awareness",
        "channel" => "email"
      }
    end
    
    template = JourneyTemplate.create!(
      name: "Large Template",
      campaign_type: "awareness",
      template_data: { 
        "stages" => ["awareness", "consideration"],
        "steps" => large_steps,
        "metadata" => { "timeline" => "test" }
      }
    )
    
    # Test cloning performance
    start_time = Time.current
    cloned = template.clone_template(new_name: "Cloned Large Template")
    end_time = Time.current
    
    assert cloned.persisted?
    assert_equal 100, cloned.template_data['steps'].length
    assert (end_time - start_time) < 10.seconds, "Cloning should complete within 10 seconds"
  end

  test "step substitution performance with many steps" do
    steps = 50.times.map do |i|
      {
        "title" => "Step #{i}",
        "step_type" => "email",
        "content" => { "type" => i.even? ? "educational" : "promotional" },
        "channel" => i.odd? ? "email" : "social_media",
        "stage" => "awareness"
      }
    end
    
    template = JourneyTemplate.create!(
      name: "Performance Template",
      campaign_type: "awareness",
      template_data: { 
        "stages" => ["awareness"],
        "steps" => steps,
        "metadata" => { "timeline" => "test" }
      }
    )
    
    # Test content type substitution performance
    start_time = Time.current
    template.substitute_content_type("educational", "informational")
    end_time = Time.current
    
    assert (end_time - start_time) < 2.seconds, "Substitution should complete within 2 seconds"
    
    # Verify substitution worked
    educational_count = template.template_data['steps'].count { |s| s.dig('content', 'type') == 'educational' }
    assert_equal 0, educational_count
    
    informational_count = template.template_data['steps'].count { |s| s.dig('content', 'type') == 'informational' }
    assert informational_count > 0
  end

  test "journey creation from complex templates" do
    user = User.create!(
      email_address: "test@example.com",
      password_digest: "$2a$12$example_hash"
    )
    
    # Create complex template with realistic data (reduced from 20 to 10 steps)
    complex_steps = 10.times.map do |i|
      {
        "title" => "Complex Step #{i}",
        "description" => "Description for step #{i}",
        "step_type" => ["email", "content_piece", "automation"].sample,
        "channel" => ["email", "social_media", "website"].sample,
        "stage" => ["awareness", "consideration", "conversion"].sample,
        "content" => {
          "type" => ["educational", "promotional", "informational"].sample,
          "format" => ["text", "video", "image"].sample
        },
        "settings" => {
          "delay" => "#{i} hours",
          "priority" => ["high", "medium", "low"].sample,
          "tracking" => { "enabled" => true, "metrics" => ["opens", "clicks"] }
        }
      }
    end
    
    complex_template = JourneyTemplate.create!(
      name: "Complex Performance Template",
      campaign_type: "conversion",
      template_data: {
        "stages" => ["awareness", "consideration", "conversion", "retention"],
        "steps" => complex_steps,
        "metadata" => {
          "timeline" => "12 weeks",
          "key_metrics" => ["conversion_rate", "engagement"],
          "target_audience" => "B2B prospects"
        }
      }
    )
      
    start_time = Time.current
    journey = complex_template.create_journey_for_user(user, name: "Performance Test Journey")
    end_time = Time.current
    
    assert journey.persisted?
    assert_equal 10, journey.journey_steps.count
    assert (end_time - start_time) < 10.seconds, "Journey creation should complete within 10 seconds"
    
    # Verify data integrity
    assert_equal complex_template.template_data['stages'], journey.stages
    assert_equal complex_template.template_data['metadata'], journey.metadata
  end

  test "bulk operations performance" do
    template = JourneyTemplate.create!(
      name: "Bulk Test Template",
      campaign_type: "awareness",
      template_data: { 
        "stages" => ["discovery", "education", "engagement"], 
        "steps" => [] 
      }
    )
    
    # Test adding multiple steps rapidly using bulk method
    start_time = Time.current
    
    bulk_steps_data = 10.times.map do |i|
      {
        "title" => "Bulk Step #{i}",
        "step_type" => "email",
        "channel" => "email",
        "stage" => "awareness"
      }
    end
    
    template.add_steps_bulk(bulk_steps_data)
    
    end_time = Time.current
    
    assert (end_time - start_time) < 5.seconds, "Bulk step addition should complete within 5 seconds"
    
    template.reload
    bulk_steps = template.template_data['steps'].select { |s| s['title']&.include?('Bulk Step') }
    assert_equal 10, bulk_steps.length
  end

  test "memory usage with large template data" do
    # Create template with substantial data
    large_metadata = {
      "timeline" => "24 weeks",
      "detailed_metrics" => 50.times.map { |i| "metric_#{i}" },
      "audience_segments" => 20.times.map { |i| { "name" => "Segment #{i}", "criteria" => "criteria_#{i}" } },
      "campaign_history" => 30.times.map { |i| { "date" => "2024-#{i+1}-01", "performance" => rand(100) } }
    }
    
    template = JourneyTemplate.create!(
      name: "Memory Test Template",
      campaign_type: "awareness",
      template_data: {
        "stages" => ["awareness", "consideration", "conversion"],
        "steps" => [],
        "metadata" => large_metadata
      }
    )
    
    # Test memory efficient operations
    start_memory = GC.stat[:total_allocated_objects]
    
    cloned = template.clone_template(new_name: "Memory Cloned Template")
    template.update_metadata({ "new_field" => "test_value" })
    
    end_memory = GC.stat[:total_allocated_objects]
    memory_used = end_memory - start_memory
    
    assert cloned.persisted?
    assert memory_used < 100000, "Memory usage should be reasonable for large templates"
  end
end