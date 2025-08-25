# frozen_string_literal: true

require 'test_helper'

class BrandAdaptationServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @other_user = users(:team_member_user) 
    @brand_identity = brand_identities(:marketer_brand)
    @persona = personas(:professional_marketer)
    @content = "This is test content for brand adaptation. It contains enough text to be meaningfully adapted for different audiences and channels."
    
    # Brand identity is already active in fixture, but ensure it has the expected attributes
    @brand_identity.update!(
      tone_guidelines: "Professional, friendly, and helpful tone",
      messaging_framework: "Focus on quality, reliability, and innovation",
      restrictions: "Avoid: cheap, basic, simple"
    )
    
    # Set up default adaptation parameters
    @adaptation_params = {
      persona_id: @persona.id,
      adaptation_type: 'demographic_targeting',
      channel: 'email'
    }
  end

  def teardown
    Current.session = nil if Current.respond_to?(:session=)
  end

  # Initialization tests
  test "should initialize service with valid parameters" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      adaptation_params: @adaptation_params
    )
    
    assert_equal @user, service.user
    assert_equal @brand_identity, service.brand_identity
    assert_equal @content, service.content
    assert_equal @adaptation_params.with_indifferent_access, service.adaptation_params
  end

  test "should log service call on initialization" do
    Rails.logger.expects(:info).with(regexp_matches(/Service Call: BrandAdaptationService/))
    
    BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      adaptation_params: @adaptation_params
    )
  end

  # Validation tests
  test "should raise error when user is missing" do
    service = BrandAdaptationService.new(
      user: nil,
      brand_identity: @brand_identity,
      content: @content
    )
    
    result = service.call
    assert_not result[:success]
    assert_includes result[:error], "User is required"
  end

  test "should raise error when brand_identity is missing" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: nil,
      content: @content
    )
    
    result = service.call
    assert_not result[:success]
    assert_includes result[:error], "Brand identity is required"
  end

  test "should raise error when content is missing" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: ""
    )
    
    result = service.call
    assert_not result[:success]
    assert_includes result[:error], "Content is required"
  end

  test "should raise error when user doesn't own brand identity" do
    service = BrandAdaptationService.new(
      user: @other_user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    result = service.call
    assert_not result[:success]
    assert_includes result[:error], "User does not own this brand identity"
  end

  test "should raise error when brand identity is not active" do
    @brand_identity.update!(status: 'draft', is_active: false)
    
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    result = service.call
    assert_not result[:success]
    assert_includes result[:error], "Brand identity must be active"
  end

  # Core functionality tests
  test "should successfully adapt content with persona targeting" do
    result = BrandAdaptationService.call(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      adaptation_params: @adaptation_params
    )
    
    assert result[:success], "Expected adaptation to succeed but got: #{result[:error]}"
    assert_not_nil result[:data][:adapted_content]
    assert_not_nil result[:data][:brand_variant]
    assert_equal 'demographic_targeting', result[:data][:adaptation_type]
    assert_not_equal @content, result[:data][:adapted_content]
    assert_equal @content, result[:data][:original_content]
  end

  test "should create new brand variant when none exists" do
    assert_difference 'BrandVariant.count', 1 do
      result = BrandAdaptationService.call(
        user: @user,
        brand_identity: @brand_identity,
        content: @content,
        adaptation_params: @adaptation_params
      )
      
      assert result[:success], "Expected success but got error: #{result[:error]}"
    end
  end

  test "should use existing brand variant when suitable match found" do
    # Create an existing variant
    existing_variant = @brand_identity.brand_variants.create!(
      user: @user,
      persona: @persona,
      name: "Existing Professional Variant",
      description: "For professional audience",
      adaptation_context: "audience_segment",
      adaptation_type: "demographic_targeting",
      status: "active",
      audience_targeting: {
        "professional_audience" => { "demographic_adaptations" => { "age_group" => "25-50" } }
      }
    )
    
    assert_no_difference 'BrandVariant.count' do
      result = BrandAdaptationService.call(
        user: @user,
        brand_identity: @brand_identity,
        content: @content,
        adaptation_params: @adaptation_params
      )
      
      assert result[:success]
      assert_equal existing_variant.id, result[:data][:brand_variant].id
    end
  end

  test "should track usage when adapting content" do
    result = BrandAdaptationService.call(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      adaptation_params: @adaptation_params
    )
    
    assert result[:success]
    brand_variant = result[:data][:brand_variant]
    
    assert brand_variant.usage_count > 0
    assert_not_nil brand_variant.last_used_at
  end

  test "should include performance metrics in response" do
    result = BrandAdaptationService.call(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      adaptation_params: @adaptation_params
    )
    
    assert result[:success]
    assert_not_nil result[:data][:performance_metrics]
    assert_includes result[:data][:performance_metrics], :usage_count
    assert_includes result[:data][:performance_metrics], :effectiveness_score
    assert_includes result[:data][:performance_metrics], :performance_trend
  end

  # Context extraction tests
  test "should extract temporal context automatically" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    context = service.send(:extract_adaptation_context)
    
    assert_not_nil context[:temporal_context]
    assert context[:temporal_context].include?('season_')
    assert context[:temporal_context].include?('time_')
    assert context[:temporal_context].include?('day_')
  end

  test "should use provided temporal context over auto-detected" do
    params = { temporal_context: "holiday_season" }
    
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      adaptation_params: params
    )
    
    context = service.send(:extract_adaptation_context)
    assert_equal "holiday_season", context[:temporal_context]
  end

  # Adaptation type determination tests
  test "should auto-determine adaptation type based on context" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      adaptation_params: { channel: 'social_media' }
    )
    
    context = service.send(:extract_adaptation_context)
    persona = service.send(:find_target_persona)
    adaptation_type = service.send(:determine_adaptation_type, context, persona)
    
    assert_equal 'channel_optimization', adaptation_type
  end

  test "should use explicit adaptation type when provided" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      adaptation_params: { adaptation_type: 'tone_adaptation' }
    )
    
    context = service.send(:extract_adaptation_context)
    persona = service.send(:find_target_persona)
    adaptation_type = service.send(:determine_adaptation_type, context, persona)
    
    assert_equal 'tone_adaptation', adaptation_type
  end

  test "should determine persona-based adaptation when persona provided" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      adaptation_params: { persona_id: @persona.id }
    )
    
    context = service.send(:extract_adaptation_context)
    persona = service.send(:find_target_persona)
    adaptation_type = service.send(:determine_adaptation_type, context, persona)
    
    assert_includes ['demographic_targeting', 'behavioral_targeting'], adaptation_type
  end

  # Brand variant creation tests
  test "should generate appropriate variant name" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      adaptation_params: { 
        persona_id: @persona.id,
        channel: 'email',
        audience_segment: 'professionals'
      }
    )
    
    context = { channel: 'email', audience_segment: 'professionals' }
    name = service.send(:generate_variant_name, 'demographic_targeting', context, @persona)
    
    assert_includes name, @persona.name
    assert_includes name, 'Email'
    assert_includes name, 'Professionals'
    assert_includes name, 'Demographic Targeting'
  end

  test "should generate comprehensive variant description" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    context = { channel: 'linkedin', audience_segment: 'executives' }
    description = service.send(:generate_variant_description, 'behavioral_targeting', context, @persona)
    
    assert_includes description.downcase, 'behavioral targeting'
    assert_includes description.downcase, 'linkedin'
    assert_includes description.downcase, 'executives'
    assert_includes description, @persona.name
  end

  test "should calculate appropriate variant priority" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    context = { persona_id: @persona.id, channel: 'email' }
    priority = service.send(:calculate_variant_priority, 'demographic_targeting', context)
    
    assert priority > 10 # Should be high priority due to persona and channel
  end

  # Adaptation rules generation tests
  test "should generate temporal rules from context" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    context = { temporal_context: "season_winter,time_morning,day_weekday" }
    rules = service.send(:generate_adaptation_rules, context)
    
    assert_not_nil rules['temporal_rules']
    temporal_rules = rules['temporal_rules']
    assert temporal_rules['seasonal_adaptations']
    assert temporal_rules['time_adaptations']
    assert temporal_rules['day_adaptations']
  end

  test "should generate campaign rules for different contexts" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    context = { campaign_context: 'launch' }
    rules = service.send(:generate_adaptation_rules, context)
    
    assert_not_nil rules['campaign_rules']
    campaign_rules = rules['campaign_rules']
    assert_equal 'launch', campaign_rules['campaign_type']
    assert_equal 'excitement_and_newness', campaign_rules['messaging_focus']
    assert_equal 'enthusiastic', campaign_rules['tone_adjustments']
  end

  test "should generate consistency rules based on brand guidelines" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    context = {}
    rules = service.send(:generate_adaptation_rules, context)
    
    assert_not_nil rules['consistency_rules']
    consistency_rules = rules['consistency_rules']
    assert consistency_rules['maintain_brand_voice']
    assert consistency_rules['preserve_core_messaging']
    assert consistency_rules['follow_messaging_framework']
  end

  # Voice adjustments tests
  test "should extract tone from brand guidelines" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    tone = service.send(:extract_tone_from_guidelines)
    assert_equal 'professional', tone
  end

  test "should determine persona tone shift" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    persona_prefs = { 'tone' => 'casual' }
    shift = service.send(:determine_persona_tone_shift, persona_prefs)
    
    assert_equal 'more_casual', shift
  end

  test "should generate voice adjustments for persona and context" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    context = { channel: 'social_media', campaign_context: 'launch' }
    adjustments = service.send(:generate_voice_adjustments, context, @persona)
    
    assert_not_nil adjustments['base_tone']
    assert_not_nil adjustments['channel_tone']
    assert_not_nil adjustments['campaign_tone']
    assert adjustments['personality_traits'].is_a?(Array)
  end

  # Messaging variations tests
  test "should extract key messages from brand messaging framework" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    context = {}
    messages = service.send(:extract_key_messages_for_context, context)
    
    assert messages.is_a?(Array)
    assert messages.any?
  end

  test "should generate value propositions for persona goals" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    # Mock persona goals
    @persona.expects(:parse_goals_data).returns(['save_time', 'increase_productivity'])
    @persona.expects(:parse_pain_points_data).returns(['lack_of_time'])
    
    value_props = service.send(:determine_value_props_for_persona, @persona)
    
    assert_includes value_props, 'Time-saving benefits'
    assert_includes value_props, 'Productivity enhancement'
    assert_includes value_props, 'Quick and efficient'
  end

  test "should generate CTA variations for different channels" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    email_ctas = service.send(:generate_cta_variations_for_channel, 'email')
    assert email_ctas['Learn More'] != 'Learn More'
    assert_equal 'Discover the Details', email_ctas['Learn More']
    
    social_ctas = service.send(:generate_cta_variations_for_channel, 'social_media')
    assert social_ctas['Learn More'].include?('👆')
  end

  # Channel specifications tests
  test "should generate appropriate channel specifications" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    context = { channel: 'email' }
    specs = service.send(:generate_channel_specifications, context)
    
    email_specs = specs['email']
    assert_equal 500, email_specs['max_length']
    assert_equal 'paragraph', email_specs['format_style']
    assert email_specs['personalization']
    assert email_specs['channel_elements']['signature']
  end

  test "should generate Twitter-specific specifications" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    context = { channel: 'twitter' }
    specs = service.send(:generate_channel_specifications, context)
    
    twitter_specs = specs['twitter']
    assert_equal 280, twitter_specs['max_length']
    assert_equal 'concise', twitter_specs['format_style']
    assert twitter_specs['thread_optimization']
    assert twitter_specs['channel_elements']['hashtags']
  end

  # Content adaptation tests
  test "should apply tone adjustments correctly" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    casual_content = "Hey there! This is awesome!"
    formal_content = service.send(:adjust_tone, casual_content, "more_formal", {})
    
    assert_not_equal casual_content, formal_content
    assert_not formal_content.include?("Hey")
    assert_not formal_content.include?("awesome")
  end

  test "should apply formality adjustments" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    content = "You can't succeed because you won't try."
    high_formality = service.send(:adjust_formality, content, "high")
    
    assert_equal "You cannot succeed because you will not try.", high_formality
  end

  test "should add engagement elements" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    original = "This is basic content."
    engaging = service.send(:add_engagement_elements, original)
    
    assert_not_equal original, engaging
    assert engaging.include?("What do you think?")
  end

  test "should improve content clarity" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    complex_content = "We utilize advanced methods to facilitate optimal outcomes and demonstrate superior results."
    clear_content = service.send(:improve_content_clarity, complex_content)
    
    assert clear_content.include?("use")
    assert clear_content.include?("help")
    assert clear_content.include?("show")
    assert_not clear_content.include?("utilize")
  end

  # Brand consistency tests
  test "should remove restricted terms" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    content_with_restrictions = "This cheap and basic solution is simple to use."
    restricted_terms = service.send(:extract_restricted_terms, @brand_identity.restrictions)
    cleaned = service.send(:remove_restricted_terms, content_with_restrictions, restricted_terms)
    
    assert_not cleaned.include?("cheap")
    assert_not cleaned.include?("basic")
    assert_not cleaned.include?("simple")
  end

  test "should align content with brand voice" do
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    original = "This is plain content."
    aligned = service.send(:align_with_brand_voice, original)
    
    # Should incorporate brand voice keywords
    assert_not_equal original, aligned
  end

  # Class method tests
  test "should provide convenience method for persona adaptation" do
    result = BrandAdaptationService.adapt_content_for_persona(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      persona: @persona
    )
    
    assert result[:success], "Expected success but got error: #{result[:error]}"
    assert_not_nil result[:data][:adapted_content]
    assert_equal 'demographic_targeting', result[:data][:adaptation_type]
  end

  test "should provide convenience method for channel adaptation" do
    result = BrandAdaptationService.adapt_content_for_channel(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      channel: 'linkedin'
    )
    
    assert result[:success]
    assert_not_nil result[:data][:adapted_content]
    assert_equal 'channel_optimization', result[:data][:adaptation_type]
  end

  test "should provide convenience method for audience adaptation" do
    result = BrandAdaptationService.adapt_content_for_audience(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      audience_segment: 'young_professionals'
    )
    
    assert result[:success]
    assert_not_nil result[:data][:adapted_content]
    assert_equal 'demographic_targeting', result[:data][:adaptation_type]
  end

  test "should create brand variant only without content adaptation" do
    result = BrandAdaptationService.create_brand_variant(
      user: @user,
      brand_identity: @brand_identity,
      variant_params: {
        name: 'Test Variant',
        adaptation_type: 'tone_adaptation',
        adaptation_context: 'audience_segment'
      }
    )
    
    assert result[:success]
    assert_not_nil result[:data][:brand_variant]
    assert_equal 'tone_adaptation', result[:data][:adaptation_type]
  end

  # Brand consistency analysis tests
  test "should analyze brand consistency across content samples" do
    content_samples = [
      "Professional content with quality focus and reliable delivery.",
      "We provide professional, quality solutions with reliable results.",
      "Our professional approach ensures quality and reliable outcomes."
    ]
    
    result = BrandAdaptationService.analyze_brand_consistency(
      user: @user,
      brand_identity: @brand_identity,
      content_samples: content_samples
    )
    
    assert result[:success]
    assert_not_nil result[:data][:consistency_analysis]
    analysis = result[:data][:consistency_analysis]
    
    assert_includes analysis, :overall_score
    assert_includes analysis, :tone_consistency
    assert_includes analysis, :voice_consistency
    assert_includes analysis, :messaging_consistency
    assert_includes analysis, :brand_alignment
    assert_includes analysis, :recommendations
    assert_equal 3, analysis[:analyzed_samples]
  end

  test "should provide consistency recommendations" do
    # Use inconsistent content samples
    content_samples = [
      "Hey! This is awesome and super cool!",
      "We provide professional enterprise solutions.",
      "Check out this basic cheap option."
    ]
    
    result = BrandAdaptationService.analyze_brand_consistency(
      user: @user,
      brand_identity: @brand_identity,
      content_samples: content_samples
    )
    
    assert result[:success]
    recommendations = result[:data][:consistency_analysis][:recommendations]
    
    assert recommendations.any?
    # Should have compliance recommendation due to "cheap" and "basic"
    compliance_rec = recommendations.find { |r| r[:type] == 'compliance' }
    assert_not_nil compliance_rec
    assert_equal 'critical', compliance_rec[:priority]
  end

  # Error handling tests
  test "should handle service errors gracefully" do
    # Force an error by making brand_identity nil after initialization
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    # Mock a method to raise an error
    service.stubs(:validate_inputs!).raises(StandardError.new("Test error"))
    
    result = service.call
    
    assert_not result[:success]
    assert_equal "Test error", result[:error]
    assert_includes result[:context], :user_id
  end

  test "should log errors appropriately" do
    Rails.logger.expects(:error).with(regexp_matches(/Service Error in BrandAdaptationService/))
    Rails.logger.expects(:error).with(regexp_matches(/Context:/))
    
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    service.stubs(:validate_inputs!).raises(StandardError.new("Test error"))
    service.call
  end

  # Performance and optimization tests
  test "should efficiently find matching brand variants" do
    # Create multiple variants with different contexts
    variants = []
    5.times do |i|
      variants << @brand_identity.brand_variants.create!(
        user: @user,
        name: "Variant #{i}",
        description: "Test variant #{i}",
        adaptation_context: "audience_segment",
        adaptation_type: "demographic_targeting",
        status: "active",
        channel_specifications: { "email" => { "max_length" => 500 } }
      )
    end
    
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      adaptation_params: { channel: 'email', adaptation_type: 'demographic_targeting' }
    )
    
    context = { channel: 'email' }
    match = service.send(:find_matching_brand_variant, 'demographic_targeting', context, nil)
    
    assert_not_nil match
    assert_equal 'demographic_targeting', match.adaptation_type
  end

  test "should calculate context match scores accurately" do
    variant = @brand_identity.brand_variants.create!(
      user: @user,
      name: "Email Variant",
      description: "For email marketing",
      adaptation_context: "channel_specific",
      adaptation_type: "channel_optimization",
      status: "active",
      channel_specifications: { "email" => { "max_length" => 500 } }
    )
    
    service = BrandAdaptationService.new(
      user: @user,
      brand_identity: @brand_identity,
      content: @content
    )
    
    # Perfect match context
    perfect_context = { channel: 'email' }
    perfect_score = service.send(:calculate_context_match_score, variant, perfect_context)
    assert perfect_score > 0.9
    
    # No match context
    no_match_context = { channel: 'sms' }
    no_match_score = service.send(:calculate_context_match_score, variant, no_match_context)
    assert no_match_score == 0.0
  end

  # Integration tests
  test "should integrate properly with existing brand variant" do
    # Create an existing variant that should be reused
    existing_variant = @brand_identity.brand_variants.create!(
      user: @user,
      persona: @persona,
      name: "Existing Professional Email Variant",
      description: "For professional email communications",
      adaptation_context: "channel_specific",
      adaptation_type: "channel_optimization",
      status: "active",
      channel_specifications: { 
        "email" => { 
          "max_length" => 500,
          "format_style" => "professional"
        }
      }
    )
    
    result = BrandAdaptationService.call(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      adaptation_params: {
        persona_id: @persona.id,
        channel: 'email',
        adaptation_type: 'channel_optimization'
      }
    )
    
    assert result[:success]
    assert_equal existing_variant.id, result[:data][:brand_variant].id
    
    # Verify usage was tracked
    existing_variant.reload
    assert existing_variant.usage_count > 0
  end

  test "should handle complex adaptation scenarios" do
    result = BrandAdaptationService.call(
      user: @user,
      brand_identity: @brand_identity,
      content: @content,
      adaptation_params: {
        persona_id: @persona.id,
        channel: 'linkedin',
        audience_segment: 'executives',
        campaign_context: 'thought_leadership',
        adaptation_goals: ['increase_engagement', 'enhance_persuasion'],
        geographical_context: 'north_america'
      }
    )
    
    assert result[:success]
    assert_not_nil result[:data][:adapted_content]
    assert_not_nil result[:data][:brand_variant]
    assert_not_nil result[:data][:context]
    
    # Verify the brand variant has comprehensive configuration
    variant = result[:data][:brand_variant]
    assert_not_nil variant.parsed_channel_specifications
    assert_not_nil variant.parsed_audience_targeting
    assert_not_nil variant.parsed_adaptation_rules
  end
end