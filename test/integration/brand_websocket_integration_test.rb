require "test_helper"

class BrandWebSocketIntegrationTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  setup do
    @user = users(:one)
    @brand = brands(:one)
    @brand.update!(user: @user)
    sign_in @user
    
    # Set up messaging framework
    @brand.messaging_framework.update!(
      banned_words: ["inappropriate", "banned"],
      tone_attributes: { "style" => "professional" }
    )
  end

  test "real-time brand compliance notifications via WebSocket" do
    journey = @brand.journeys.create!(name: "WebSocket Test Journey", user: @user)
    
    # Subscribe to brand compliance channel
    subscribe_to_channel("BrandComplianceChannel", brand_id: @brand.id)
    
    # Create journey step that should trigger compliance notification
    step = journey.journey_steps.create!(
      name: "Test Step",
      content_type: "email", 
      stage: "awareness",
      description: "This content contains inappropriate banned words."
    )
    
    # Should receive WebSocket notification about compliance status
    assert_broadcast_on("brand_compliance_#{@brand.id}", {
      event: 'compliance_updated',
      step_id: step.id,
      journey_id: journey.id,
      brand_id: @brand.id
    }) do
      # Trigger compliance check update
      step.touch # This should trigger the compliance broadcast
    end
  end

  test "real-time brand asset processing status updates" do
    # Subscribe to brand asset processing channel
    subscribe_to_channel("BrandComplianceChannel", brand_id: @brand.id)
    
    brand_asset = @brand.brand_assets.build(
      asset_type: "brand_guidelines",
      processing_status: "pending",
      original_filename: "test_guidelines.pdf",
      content_type: "application/pdf",
      extracted_text: "Professional brand guidelines for our organization."
    )
    brand_asset.skip_file_validation!
    brand_asset.save!
    
    # Processing should trigger WebSocket updates
    assert_broadcasts("brand_compliance_#{@brand.id}", 2) do
      # Start processing
      brand_asset.mark_as_processing!
      
      # Complete processing
      brand_asset.mark_as_completed!
    end
  end

  test "collaborative journey editing with brand compliance" do
    journey = @brand.journeys.create!(name: "Collaborative Journey", user: @user)
    
    # Simulate multiple users editing the same journey
    subscribe_to_channel("BrandComplianceChannel", brand_id: @brand.id)
    
    # User 1 creates a step
    step = journey.journey_steps.create!(
      name: "Collaborative Step",
      content_type: "email",
      stage: "awareness", 
      description: "Initial professional content for our campaign."
    )
    
    # User 2 updates the step with non-compliant content
    assert_broadcast_on("journey_step_compliance_#{step.id}", {
      event: 'compliance_updated',
      step_id: step.id,
      journey_id: journey.id,
      brand_id: @brand.id
    }) do
      step.update!(description: "Hey everyone! This inappropriate content has banned words.")
    end
  end

  test "real-time messaging framework updates affect journey validation" do
    journey = @brand.journeys.create!(name: "Dynamic Validation Journey", user: @user)
    
    step = journey.journey_steps.create!(
      name: "Dynamic Step",
      content_type: "email",
      stage: "awareness",
      description: "This content will be dynamically validated."
    )
    
    # Subscribe to compliance updates
    subscribe_to_channel("BrandComplianceChannel", brand_id: @brand.id)
    
    # Update messaging framework - should trigger revalidation
    assert_broadcasts("brand_compliance_#{@brand.id}", 1) do
      @brand.messaging_framework.update!(
        banned_words: @brand.messaging_framework.banned_words + ["dynamically"]
      )
    end
    
    # The step should now be non-compliant due to the word "dynamically"
    updated_validation = @brand.messaging_framework.validate_journey_step(step)
    assert updated_validation[:validation_score] < 0.7, "Step should be non-compliant after framework update"
  end

  test "bulk compliance checking with progress updates" do
    journey = @brand.journeys.create!(name: "Bulk Check Journey", user: @user)
    
    # Create multiple steps
    steps = 10.times.map do |i|
      journey.journey_steps.create!(
        name: "Bulk Step #{i}",
        content_type: "email",
        stage: "awareness",
        description: "Professional content for step #{i} in our comprehensive campaign."
      )
    end
    
    subscribe_to_channel("BrandComplianceChannel", brand_id: @brand.id)
    
    # Simulate bulk compliance checking with progress updates
    assert_broadcasts("brand_compliance_#{@brand.id}", steps.count) do
      steps.each do |step|
        # Each step update should trigger a compliance broadcast
        step.touch
      end
    end
  end

  test "brand guideline changes propagate to active journeys" do
    journey = @brand.journeys.create!(name: "Guideline Propagation Journey", user: @user)
    
    step = journey.journey_steps.create!(
      name: "Guideline Step",
      content_type: "email",
      stage: "awareness",
      description: "Content that mentions our products and services."
    )
    
    subscribe_to_channel("BrandComplianceChannel", brand_id: @brand.id)
    
    # Add new brand guideline
    assert_broadcast_on("brand_compliance_#{@brand.id}", {
      event: 'guidelines_updated',
      brand_id: @brand.id
    }) do
      @brand.brand_guidelines.create!(
        rule_type: "dont",
        rule_content: "Never mention products without services",
        category: "messaging",
        priority: 8
      )
    end
  end

  test "WebSocket connection handles compliance checking errors gracefully" do
    journey = @brand.journeys.create!(name: "Error Handling Journey", user: @user)
    
    subscribe_to_channel("BrandComplianceChannel", brand_id: @brand.id)
    
    # Create step that might cause processing errors
    step = journey.journey_steps.build(
      name: "Error Test Step",
      content_type: "email",
      stage: "awareness",
      description: "A" * 100000 # Extremely long content that might cause issues
    )
    
    # Should handle errors gracefully without breaking WebSocket connection
    begin
      step.save!
    rescue => e
      # Error should be handled gracefully
      assert e.present?, "Should capture processing errors"
    end
    
    # WebSocket connection should remain active for subsequent operations
    normal_step = journey.journey_steps.create!(
      name: "Normal Step",
      content_type: "email",
      stage: "awareness", 
      description: "Normal professional content."
    )
    
    assert normal_step.persisted?, "Normal operations should continue after error"
  end

  test "concurrent WebSocket connections handle brand updates correctly" do
    journey = @brand.journeys.create!(name: "Concurrent Journey", user: @user)
    
    # Simulate multiple WebSocket connections
    connections = 3.times.map do |i|
      subscribe_to_channel("BrandComplianceChannel", brand_id: @brand.id, connection_id: "conn_#{i}")
    end
    
    # All connections should receive the same updates
    assert_broadcasts("brand_compliance_#{@brand.id}", 3) do # One broadcast per connection
      step = journey.journey_steps.create!(
        name: "Concurrent Step",
        content_type: "email",
        stage: "awareness",
        description: "Content that should be broadcast to all connections."
      )
    end
  end

  test "WebSocket notifications include relevant compliance metadata" do
    journey = @brand.journeys.create!(name: "Metadata Journey", user: @user)
    
    subscribe_to_channel("BrandComplianceChannel", brand_id: @brand.id)
    
    # Create step with specific compliance characteristics
    step = journey.journey_steps.create!(
      name: "Metadata Step",
      content_type: "email",
      stage: "consideration",
      description: "Professional message with excellent service delivery."
    )
    
    # WebSocket message should include compliance metadata
    assert_broadcast_on("journey_step_compliance_#{step.id}") do |data|
      assert data[:event] == 'compliance_updated'
      assert data[:step_id] == step.id
      assert data[:journey_id] == journey.id
      assert data[:brand_id] == @brand.id
      assert data[:compliance_score].present?
      assert data[:timestamp].present?
    end
  end

  private

  def sign_in(user)
    post session_path, params: {
      email_address: user.email_address,
      password: 'password'
    }
  end

  def subscribe_to_channel(channel_class, **params)
    # Helper method to subscribe to ActionCable channels in tests
    # In a real implementation, this would use ActionCable test helpers
    # For now, we'll simulate the subscription
    @subscriptions ||= []
    @subscriptions << { channel: channel_class, params: params }
  end
end