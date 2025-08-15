require "test_helper"

class TemplateWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    # Clear existing templates to avoid conflicts
    JourneyTemplate.delete_all
    # Load seeds fresh for each test
    Rails.application.load_seed
  end

  test "complete template customization workflow" do
    
    # Start with a seeded template
    original_template = JourneyTemplate.find_by(name: 'Product Launch Campaign')
    assert original_template.present?
    
    # Clone the template
    custom_template = original_template.clone_template(
      new_name: "Custom Product Launch",
      campaign_type: "conversion"
    )
    
    # Customize stages
    custom_stages = ["pre_launch", "launch", "post_launch"]
    custom_template.customize_stages(custom_stages)
    
    # Add a custom step
    custom_step = {
      "title" => "Custom Analytics Setup",
      "description" => "Set up tracking for launch metrics",
      "step_type" => "automation",
      "channel" => "website",
      "stage" => "pre_launch",
      "content" => { "type" => "technical" }
    }
    custom_template.add_step(custom_step, position: 0)
    
    # Substitute some content types
    custom_template.substitute_content_type("teaser_content", "announcement_content")
    
    # Update metadata
    custom_template.update_metadata({
      "timeline" => "8-10 weeks",
      "custom_metric" => "launch_success_score"
    })
    
    # Create a journey from the customized template
    journey = custom_template.create_journey_for_user(@user, name: "My Custom Launch")
    
    # Verify the complete workflow
    assert journey.persisted?
    assert_equal custom_stages, journey.stages
    assert_equal "conversion", journey.campaign_type
    assert_equal "8-10 weeks", custom_template.get_timeline
    
    # Verify custom step was added
    first_step = journey.journey_steps.order(:sequence_order).first
    assert_equal "Custom Analytics Setup", first_step.title
    
    # Verify content substitution worked
    announcement_steps = custom_template.template_data['steps'].select do |step|
      step.dig('content', 'type') == 'announcement_content'
    end
    assert announcement_steps.any?, "Content type substitution should have occurred"
  end

  test "template system supports multi-user scenarios" do
    
    # Create additional users
    user2 = User.create!(email_address: "template_user2@example.com", password: "password123")
    user3 = User.create!(email_address: "template_user3@example.com", password: "password123")
    
    template = JourneyTemplate.find_by(name: 'Lead Generation Campaign')
    
    # Multiple users create journeys from same template
    journey1 = template.create_journey_for_user(@user, name: "User 1 Campaign")
    journey2 = template.create_journey_for_user(user2, name: "User 2 Campaign")
    journey3 = template.create_journey_for_user(user3, name: "User 3 Campaign")
    
    assert_equal 3, [journey1, journey2, journey3].count(&:persisted?)
    
    # Verify isolation - each user has their own journey
    assert_equal @user, journey1.user
    assert_equal user2, journey2.user
    assert_equal user3, journey3.user
    
    # Verify steps were created independently
    [journey1, journey2, journey3].each do |journey|
      assert journey.journey_steps.count > 0
      assert journey.journey_steps.all? { |step| step.journey == journey }
    end
  end

  test "template system handles concurrent modifications" do
    template = JourneyTemplate.create!(
      name: "Concurrent Test Template",
      campaign_type: "awareness",
      template_data: {
        "stages" => ["stage1", "stage2"],
        "steps" => [{ "title" => "Original Step", "step_type" => "email" }],
        "metadata" => { "timeline" => "test" }
      }
    )
    
    # Simulate concurrent modifications
    threads = []
    results = []
    
    5.times do |i|
      threads << Thread.new do
        begin
          result = template.add_step({
            "title" => "Concurrent Step #{i}",
            "step_type" => "email",
            "channel" => "email",
            "stage" => "stage1"
          })
          results << result
        rescue => e
          results << false
        end
      end
    end
    
    threads.each(&:join)
    
    # Verify modifications were attempted (some may fail due to concurrency)
    template.reload
    steps = template.template_data['steps']
    assert steps.length >= 2, "Should have at least original step plus some concurrent steps"
    
    concurrent_steps = steps.select { |s| s['title']&.include?('Concurrent') }
    assert concurrent_steps.length >= 1, "At least some concurrent modifications should succeed"
  end

  test "end-to-end template-based campaign creation" do
    
    # Start with re-engagement template
    template = JourneyTemplate.find_by(name: 'Re-Engagement Campaign')
    
    # Customize for specific use case
    custom_template = template.clone_template(new_name: "Holiday Re-Engagement")
    
    # Add holiday-specific steps
    holiday_step = {
      "title" => "Holiday Special Offer",
      "description" => "Exclusive holiday discount for returning customers",
      "step_type" => "email",
      "channel" => "email",
      "stage" => "consideration",
      "content" => {
        "type" => "promotional",
        "format" => "holiday_themed",
        "messaging" => "Limited time holiday offer"
      },
      "settings" => {
        "send_date" => "holiday_schedule",
        "discount" => 25,
        "expiration" => "end_of_year"
      }
    }
    custom_template.add_step(holiday_step)
    
    # Update channels for omnichannel approach
    custom_template.substitute_channel("email", "sms")
    
    # Create campaigns for multiple customer segments
    segments = ["premium_customers", "standard_customers", "trial_users"]
    journeys = []
    
    segments.each do |segment|
      journey = custom_template.create_journey_for_user(
        @user, 
        name: "Holiday Re-Engagement - #{segment.humanize}",
        description: "Holiday campaign targeting #{segment.humanize.downcase}"
      )
      journeys << journey
    end
    
    # Verify all campaigns were created successfully
    assert_equal 3, journeys.count(&:persisted?)
    
    journeys.each do |journey|
      assert journey.journey_steps.count > 0
      assert journey.name.include?("Holiday Re-Engagement")
      
      # Verify holiday step was included
      holiday_steps = journey.journey_steps.where(title: "Holiday Special Offer")
      assert_equal 1, holiday_steps.count
      
      # Verify SMS substitution worked
      sms_steps = journey.journey_steps.where(channel: "sms")
      assert sms_steps.any?, "Should have SMS steps from channel substitution"
    end
  end

  test "template versioning and evolution workflow" do
    # Create initial template version
    v1_template = JourneyTemplate.create!(
      name: "Email Campaign v1",
      campaign_type: "awareness",
      template_data: {
        "stages" => ["awareness", "consideration"],
        "steps" => [
          {
            "title" => "Welcome Email",
            "step_type" => "email",
            "channel" => "email",
            "stage" => "awareness"
          }
        ],
        "metadata" => {
          "version" => "1.0",
          "timeline" => "4 weeks"
        }
      }
    )
    
    # Create evolved version with improvements
    v2_template = v1_template.clone_template(new_name: "Email Campaign v2")
    
    # Add new stage
    v2_template.customize_stages(["awareness", "consideration", "conversion"])
    
    # Add conversion step
    conversion_step = {
      "title" => "Conversion Offer",
      "description" => "Special offer to drive conversions",
      "step_type" => "email",
      "channel" => "email",
      "stage" => "conversion",
      "content" => { "type" => "promotional" }
    }
    v2_template.add_step(conversion_step)
    
    # Update metadata
    v2_template.update_metadata({
      "version" => "2.0",
      "timeline" => "6 weeks",
      "improvements" => ["Added conversion stage", "Improved targeting"]
    })
    
    # Test both versions work independently
    user1_journey = v1_template.create_journey_for_user(@user, name: "V1 Campaign")
    user2_journey = v2_template.create_journey_for_user(@user, name: "V2 Campaign")
    
    assert user1_journey.persisted?
    assert user2_journey.persisted?
    
    # Verify version differences
    assert_equal 2, user1_journey.stages.length
    assert_equal 3, user2_journey.stages.length
    
    assert_equal 1, user1_journey.journey_steps.count
    assert_equal 2, user2_journey.journey_steps.count
    
    assert_equal "1.0", v1_template.template_data["metadata"]["version"]
    assert_equal "2.0", v2_template.template_data["metadata"]["version"]
  end

  test "template error recovery and fallback scenarios" do
    # Create template with potential failure points
    unreliable_template = JourneyTemplate.create!(
      name: "Unreliable Template",
      campaign_type: "awareness",
      template_data: {
        "stages" => ["awareness"],
        "steps" => [
          {
            "title" => "Valid Step",
            "step_type" => "email",
            "channel" => "email",
            "stage" => "awareness"
          },
          {
            # Missing required fields - should fail gracefully
            "description" => "Step with missing title",
            "stage" => "awareness"
          },
          {
            "title" => "Another Valid Step",
            "step_type" => "social_post",
            "channel" => "social_media",
            "stage" => "awareness"
          }
        ],
        "metadata" => { "timeline" => "test" }
      }
    )
    
    # Attempt to create journey - should succeed despite invalid steps
    journey = unreliable_template.create_journey_for_user(@user, name: "Recovery Test")
    
    assert journey.persisted?, "Journey should be created despite template issues"
    
    # Should have created valid steps only
    valid_steps = journey.journey_steps.where.not(title: [nil, ""])
    assert valid_steps.count >= 1, "Should create at least some valid steps"
    
    # Test recovery through template modification
    unreliable_template.remove_step(1) # Remove problematic step
    
    # Create another journey - should work better now
    recovered_journey = unreliable_template.create_journey_for_user(@user, name: "Recovered Test")
    
    assert recovered_journey.persisted?
    assert recovered_journey.journey_steps.count > 0
  end
end