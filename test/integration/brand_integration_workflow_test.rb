require "test_helper"

class BrandIntegrationWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @brand = brands(:one)
    sign_in @user
  end

  # Complete Brand Integration Workflow Tests (FAILING - TDD RED PHASE)
  
  test "complete brand onboarding workflow with file upload" do
    # This test will fail until we implement the complete workflow
    
    # Step 1: Upload brand guidelines
    brand_files = [
      fixture_file_upload("test.pdf", "application/pdf"),
      fixture_file_upload("brand_logo.png", "image/png")
    ]
    
    post brand_brand_assets_path(@brand), params: {
      brand_asset: {
        files: brand_files,
        asset_types: ["brand_guidelines", "logo"]
      }
    }
    
    # Expect redirect after successful upload (normal Rails behavior)
    assert_response :redirect
    follow_redirect!
    assert_response :success
    
    # Check that assets were created - reload to get fresh count
    @brand.reload
    assert @brand.brand_assets.count >= 2
    
    # Step 2: Process files and extract brand characteristics
    @brand.brand_assets.each(&:process_with_ai)
    
    # Step 3: Verify brand analysis was created
    assert @brand.latest_analysis.present?
    assert @brand.latest_analysis.confidence_score >= 0.85
    
    # Step 4: Test real-time compliance checking
    test_content = "Hey there! This casual message might not match our professional brand."
    
    compliance_result = @brand.messaging_framework.validate_message_realtime(test_content)
    
    assert compliance_result[:validation_score].present?
    assert compliance_result[:rule_violations].present?
    
    # Step 5: Integrate with journey builder
    journey = @brand.journeys.create!(name: "Brand Compliant Journey", user: @user)
    journey_step = journey.journey_steps.create!(
      name: "Welcome Email",
      content_type: "email",
      stage: "awareness",
      description: "Professional welcome to our platform. We are pleased to welcome you to our professional service platform.",
      config: { 
        subject: "Professional welcome to our platform",
        body: "We are pleased to welcome you to our professional service platform."
      }
    )
    
    validation = @brand.messaging_framework.validate_journey_step(journey_step)
    assert validation[:approved_for_journey]
  end

  test "brand compliance prevents non-compliant content from being published" do
    # This test will fail until we implement compliance gates
    
    # Create brand guidelines with strict professional tone
    @brand.brand_guidelines.create!(
      rule_type: "dont",
      rule_content: "Never use casual language or slang",
      category: "voice",
      priority: 10
    )
    
    # Set up messaging framework with banned words and professional tone
    @brand.messaging_framework.update!(
      banned_words: ["hey", "guys", "totally", "awesome"],
      tone_attributes: {
        "style" => "professional",
        "formality" => "formal"
      }
    )
    
    journey = @brand.journeys.create!(name: "Gated Journey", user: @user)
    
    # Try to create non-compliant journey step
    non_compliant_step = journey.journey_steps.build(
      name: "Casual Email",
      content_type: "email",
      stage: "awareness",
      description: "Hey buddy! Check this out! What's up? This is totally awesome stuff you gotta see! 😎",
      config: {
        subject: "Hey buddy! Check this out!",
        body: "What's up? This is totally awesome stuff you gotta see! 😎"
      }
    )
    
    # Should fail validation
    assert_not non_compliant_step.valid?
    assert_includes non_compliant_step.errors[:content], "violates brand compliance rules"
    
    # Compliant version should pass
    compliant_step = journey.journey_steps.build(
      name: "Professional Email", 
      content_type: "email",
      stage: "awareness",
      description: "Important Update About Our Services. We are pleased to inform you about our latest service enhancements.",
      config: {
        subject: "Important Update About Our Services",
        body: "We are pleased to inform you about our latest service enhancements."
      }
    )
    
    assert compliant_step.valid?
  end

  test "brand analysis accuracy improves with more content" do
    # This test will fail until we implement accuracy tracking
    
    # Start with minimal content
    minimal_asset = @brand.brand_assets.build(
      asset_type: "document",
      original_filename: "minimal.pdf",
      content_type: "application/pdf",
      extracted_text: "Brand name: TestBrand. Professional tone."
    )
    minimal_asset.skip_file_validation!
    minimal_asset.save!
    
    minimal_result = minimal_asset.process_with_ai
    minimal_accuracy = minimal_result[:accuracy_score] || 0.0
    
    # Add comprehensive content
    comprehensive_asset = @brand.brand_assets.build(
      asset_type: "brand_guidelines",
      original_filename: "comprehensive.pdf", 
      content_type: "application/pdf",
      extracted_text: create_comprehensive_brand_content
    )
    comprehensive_asset.skip_file_validation!
    comprehensive_asset.save!
    
    comprehensive_result = comprehensive_asset.process_with_ai
    comprehensive_accuracy = comprehensive_result[:accuracy_score] || 0.0
    
    # Both should be successful processing
    assert minimal_result[:success]
    assert comprehensive_result[:success]
    
    # Comprehensive content should yield higher accuracy
    assert comprehensive_accuracy > minimal_accuracy
    assert comprehensive_accuracy >= 0.85  # More realistic threshold
  end

  test "real-time brand checking provides immediate feedback" do
    # This test will fail until we implement real-time checking
    
    # Set up brand with processed guidelines
    brand_asset = @brand.brand_assets.build(
      asset_type: "brand_guidelines",
      processing_status: "completed",
      extracted_text: create_comprehensive_brand_content
    )
    brand_asset.skip_file_validation!
    brand_asset.save!
    
    # Test various content types
    test_cases = [
      {
        content: "We are committed to excellence in customer service.",
        expected_score: 0.9 # High compliance
      },
      {
        content: "Hey guys! This is like, totally awesome! 🎉",
        expected_score: 0.4 # Low compliance - adjust expected range
      },
      {
        content: "Our innovative solutions deliver measurable results.",
        expected_score: 0.85 # Good compliance
      }
    ]
    
    test_cases.each do |test_case|
      result = @brand.messaging_framework.validate_message_realtime(test_case[:content])
      
      assert result[:validation_score].present?
      assert result[:processing_time] < 2.0 # Fast response
      
      # Score should be within reasonable range of expected
      score_diff = (result[:validation_score] - test_case[:expected_score]).abs
      assert score_diff < 0.3, "Score variance too high for: #{test_case[:content]} (expected: #{test_case[:expected_score]}, got: #{result[:validation_score]})"
    end
  end

  test "batch processing handles multiple brand assets efficiently" do
    # This test will fail until we implement efficient batch processing
    
    # Create multiple brand assets
    asset_data = [
      { filename: "brand_guide.pdf", content: create_comprehensive_brand_content },
      { filename: "style_guide.pdf", content: create_style_guide_content },
      { filename: "voice_guide.pdf", content: create_voice_guide_content },
      { filename: "logo_guide.pdf", content: create_logo_guide_content }
    ]
    
    assets = asset_data.map do |data|
      asset = @brand.brand_assets.build(
        asset_type: "document",
        original_filename: data[:filename],
        content_type: "application/pdf",
        extracted_text: data[:content]
      )
      asset.skip_file_validation!
      asset.save!
      asset
    end
    
    # Process all assets in batch
    start_time = Time.current
    batch_result = BrandAsset.process_batch(assets)
    processing_time = Time.current - start_time
    
    assert batch_result[:success]
    assert batch_result[:processed_count] == 4
    assert processing_time < 60.seconds # Should complete within 1 minute
    
    # Verify aggregated analysis
    analysis = @brand.latest_analysis
    assert analysis.present?
    assert analysis.confidence_score >= 0.9
    assert analysis.voice_attributes.present?
    assert analysis.brand_values.present?
  end

  test "brand compliance integrates with content generation pipeline" do
    # This test will fail until we implement content generation integration
    
    # Set up brand with compliance rules
    brand_asset = @brand.brand_assets.build(
      asset_type: "brand_guidelines",
      processing_status: "completed",
      extracted_text: create_comprehensive_brand_content
    )
    brand_asset.skip_file_validation!
    brand_asset.save!
    
    # Create journey with content generation
    journey = @brand.journeys.create!(name: "Content Generation Journey", user: @user)
    
    # Generate content that should be brand-compliant
    generation_request = {
      content_type: "email",
      audience: "enterprise_customers",
      objective: "product_announcement",
      brand_compliance: true
    }
    
    generated_content = journey.generate_brand_compliant_content(generation_request)
    
    assert generated_content[:success]
    assert generated_content[:compliance_score] >= 0.8
    assert generated_content[:content][:subject].present?
    assert generated_content[:content][:body].present?
    
    # Verify the generated content passes compliance check
    validation = @brand.messaging_framework.validate_message_realtime(
      generated_content[:content][:body]
    )
    
    assert validation[:validation_score] >= 0.8
  end

  test "performance testing with large brand asset files" do
    # This test will fail until we implement performance optimizations
    
    # Create large content simulation
    large_content = create_large_brand_content(10000) # 10k words
    
    large_asset = @brand.brand_assets.build(
      asset_type: "document",  # Use valid asset type
      original_filename: "large_guide.pdf",
      content_type: "application/pdf",
      extracted_text: large_content
    )
    large_asset.skip_file_validation!
    large_asset.save!
    
    # Process with performance tracking
    start_time = Time.current
    result = large_asset.process_with_ai
    processing_time = Time.current - start_time
    
    assert result[:success]
    assert processing_time < 45.seconds # Should handle large files efficiently
    assert result[:processing_chunks] > 1 # Should use chunking
    assert result[:accuracy_score] >= 0.9 # Should maintain accuracy
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
      
      VISUAL IDENTITY:
      Primary Brand Colors:
      - Navy Blue: #1a365d (Authority, Trust)
      - Bright Blue: #3182ce (Innovation, Progress)
      - Dark Gray: #2d3748 (Professional, Stable)
      
      MESSAGING PILLARS:
      1. Innovation Leadership: We lead through cutting-edge solutions
      2. Customer Success: Our customers' success is our primary goal  
      3. Reliable Partnership: We deliver consistent, dependable results
      4. Continuous Improvement: We evolve and adapt to serve better
    TEXT
  end

  def create_style_guide_content
    <<~TEXT
      STYLE GUIDE
      
      Typography:
      - Headlines: Roboto Bold, 28-48px
      - Body: Source Sans Pro Regular, 14-16px
      
      Color Palette:
      - Primary: #1a365d
      - Secondary: #3182ce
      - Accent: #38a169
      
      Logo Usage:
      - Minimum size: 32px height
      - Clear space: 2x logo height
    TEXT
  end

  def create_voice_guide_content
    <<~TEXT
      VOICE GUIDE
      
      Brand Personality: Professional, innovative, trustworthy
      Communication Style: Clear, confident, helpful
      Tone Variations:
      - Formal: For enterprise communications
      - Professional: For standard business content
      - Approachable: For customer support
    TEXT
  end

  def create_logo_guide_content
    <<~TEXT
      LOGO GUIDELINES
      
      Primary Logo: Use on light backgrounds
      Secondary Logo: Use on dark backgrounds
      Minimum Size: 32px height for web, 1 inch for print
      Clear Space: Maintain 2x logo height clear space
      Prohibited Uses: Never stretch, rotate, or modify colors
    TEXT
  end

  def create_large_brand_content(word_count)
    base_content = create_comprehensive_brand_content
    words = base_content.split
    
    # Repeat content to reach desired word count
    multiplier = (word_count / words.count.to_f).ceil
    (base_content * multiplier).split.first(word_count).join(' ')
  end
end