require "test_helper"

class JourneyBuilderBrandIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @brand = brands(:one)
    @brand.update!(user: @user)
    sign_in @user
    
    # Set up messaging framework with comprehensive rules
    @brand.messaging_framework.update!(
      banned_words: ["hey", "guys", "awesome", "totally", "like", "stuff"],
      approved_phrases: ["pleased to inform", "committed to excellence", "innovative solutions"],
      tone_attributes: {
        "style" => "professional",
        "formality" => "formal"
      }
    )
  end

  test "journey builder enforces brand compliance in real-time" do
    journey = @brand.journeys.create!(name: "Brand Compliant Marketing Journey", user: @user)
    
    # Create compliant step
    compliant_step = journey.journey_steps.create!(
      name: "Professional Welcome",
      content_type: "email",
      stage: "awareness",
      description: "We are pleased to inform you about our innovative solutions.",
      config: {
        subject: "Welcome to Our Platform",
        body: "We are committed to excellence in serving your needs."
      }
    )
    
    # Check compliance validation
    validation = @brand.messaging_framework.validate_journey_step(compliant_step)
    assert validation[:approved_for_journey], "Compliant content should be approved"
    assert validation[:validation_score] >= 0.7, "Score should be high for compliant content"
    
    # Create non-compliant step
    non_compliant_step = journey.journey_steps.build(
      name: "Casual Welcome", 
      content_type: "email",
      stage: "awareness",
      description: "Hey guys! This is totally awesome stuff!",
      config: {
        subject: "Hey there!",
        body: "This awesome stuff is like, totally amazing!"
      }
    )
    
    # Should fail validation
    assert_not non_compliant_step.valid?, "Non-compliant content should fail validation"
    
    # But should pass when compliance check is disabled
    non_compliant_step.metadata = { "test_skip_validation" => true }
    assert non_compliant_step.valid?, "Should pass when validation is skipped"
  end

  test "journey builder provides real-time compliance feedback" do
    journey = @brand.journeys.create!(name: "Feedback Journey", user: @user)
    
    # Test different content variations
    test_content = [
      {
        text: "We are pleased to inform you about our services.",
        expected_compliant: true
      },
      {
        text: "Hey guys! Check out this awesome stuff!",
        expected_compliant: false
      },
      {
        text: "Our innovative solutions deliver excellence.",
        expected_compliant: true
      }
    ]
    
    test_content.each do |test_case|
      result = @brand.messaging_framework.validate_message_realtime(test_case[:text])
      
      assert result[:validation_score].present?, "Should return validation score"
      assert result[:processing_time] < 2.0, "Should process quickly"
      
      if test_case[:expected_compliant]
        assert result[:validation_score] >= 0.7, "Expected compliant content: #{test_case[:text]}"
      else
        assert result[:validation_score] < 0.7, "Expected non-compliant content: #{test_case[:text]}"
      end
    end
  end

  test "journey steps inherit brand guidelines automatically" do
    # Add multiple brand guidelines
    @brand.brand_guidelines.create!(
      rule_type: "must",
      rule_content: "Always use professional language",
      category: "voice",
      priority: 10
    )
    
    @brand.brand_guidelines.create!(
      rule_type: "dont",
      rule_content: "Never use casual greetings",
      category: "messaging", 
      priority: 8
    )
    
    journey = @brand.journeys.create!(name: "Guideline Enforcement Journey", user: @user)
    
    # Create step that follows guidelines
    good_step = journey.journey_steps.create!(
      name: "Professional Communication",
      content_type: "email",
      stage: "consideration", 
      description: "We are pleased to provide you with comprehensive information about our professional services."
    )
    
    assert good_step.persisted?, "Good step should be saved successfully"
    
    # Create step that violates guidelines
    bad_step = journey.journey_steps.build(
      name: "Casual Communication",
      content_type: "email", 
      stage: "consideration",
      description: "Hey there! Hope you're doing awesome today!"
    )
    
    # Should fail due to brand compliance
    assert_not bad_step.valid?, "Step violating guidelines should not be valid"
  end

  test "journey builder integrates with brand asset processing" do
    # Create brand asset with guidelines
    brand_asset = @brand.brand_assets.build(
      asset_type: "brand_guidelines",
      processing_status: "completed", 
      original_filename: "brand_guide.pdf",
      content_type: "application/pdf",
      extracted_text: create_comprehensive_brand_content
    )
    brand_asset.skip_file_validation!
    brand_asset.save!
    
    # Process the asset to update brand analysis
    result = brand_asset.process_with_ai
    assert result[:success], "Brand asset processing should succeed"
    
    # Create journey after brand analysis
    journey = @brand.journeys.create!(name: "Post-Analysis Journey", user: @user)
    
    # Steps should now be validated against processed brand guidelines
    step = journey.journey_steps.create!(
      name: "Brand-Aligned Message",
      content_type: "blog_post",
      stage: "awareness",
      description: "Our commitment to innovation drives excellence in customer service."
    )
    
    assert step.persisted?, "Brand-aligned step should be created successfully"
    
    # Check that brand context is available
    brand_context = step.brand_context
    assert brand_context[:brand_id].present?, "Brand context should include brand ID"
    assert brand_context[:has_messaging_framework], "Should detect messaging framework"
  end

  test "journey builder validates content across multiple channels" do
    journey = @brand.journeys.create!(name: "Multi-Channel Journey", user: @user)
    
    # Test different channel types
    channels = [
      { type: "email", content: "We are pleased to announce our latest innovation." },
      { type: "social_post", content: "Innovation meets excellence in our platform." },
      { type: "blog_post", content: "Our comprehensive approach delivers measurable results." },
      { type: "advertisement", content: "Professional solutions for your business needs." }
    ]
    
    channels.each do |channel_data|
      step = journey.journey_steps.create!(
        name: "#{channel_data[:type].titleize} Step",
        content_type: channel_data[:type], 
        channel: channel_data[:type],
        stage: "awareness",
        description: channel_data[:content]
      )
      
      assert step.persisted?, "#{channel_data[:type]} step should be created"
      
      # Validate compliance for each channel
      validation = @brand.messaging_framework.validate_journey_step(step)
      assert validation[:approved_for_journey], "#{channel_data[:type]} content should be compliant"
    end
  end

  test "journey analytics include brand compliance metrics" do
    journey = @brand.journeys.create!(name: "Analytics Journey", user: @user)
    
    # Create steps with varying compliance levels
    high_compliance_step = journey.journey_steps.create!(
      name: "Highly Compliant",
      content_type: "email",
      stage: "awareness", 
      description: "We are committed to excellence and pleased to inform you of our innovative solutions."
    )
    
    medium_compliance_step = journey.journey_steps.create!(
      name: "Medium Compliant", 
      content_type: "email",
      stage: "consideration",
      description: "Our team provides great service and delivers good results."
    )
    
    # Check compliance scores
    high_score = high_compliance_step.quick_compliance_score
    medium_score = medium_compliance_step.quick_compliance_score
    
    assert high_score >= 0.8, "High compliance content should score well"
    assert medium_score >= 0.6, "Medium compliance content should score moderately"
    assert high_score > medium_score, "Higher compliance should score better"
    
    # Check that journey can report overall brand health
    brand_health = journey.overall_brand_health_score
    assert brand_health.present?, "Should calculate brand health score"
    assert brand_health >= 0.0 && brand_health <= 1.0, "Health score should be normalized"
  end

  private

  def sign_in(user)
    post session_path, params: {
      email_address: user.email_address,
      password: 'password'
    }
  end

  def create_comprehensive_brand_content
    <<~TEXT
      COMPREHENSIVE BRAND GUIDELINES
      
      BRAND VOICE & TONE:
      Voice: Professional, approachable, and authoritative
      Tone: Confident yet humble, helpful, innovative
      Personality: Trustworthy, forward-thinking, customer-centric
      
      COMMUNICATION GUIDELINES:
      DO:
      - Use active voice in all communications
      - Maintain professional tone while being approachable
      - Focus on customer benefits and value proposition
      - Use data-driven language when appropriate
      - Include clear calls-to-action
      - Use inclusive language
      
      DON'T:
      - Use overly casual language or slang
      - Make unsubstantiated claims
      - Use negative or fear-based messaging
      - Overuse technical jargon
      - Use outdated references or terminology
      
      MESSAGING PILLARS:
      1. Innovation Leadership: We lead through cutting-edge solutions
      2. Customer Success: Our customers' success is our primary goal  
      3. Reliable Partnership: We deliver consistent, dependable results
      4. Continuous Improvement: We evolve and adapt to serve better
    TEXT
  end
end