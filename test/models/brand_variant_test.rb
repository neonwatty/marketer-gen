require "test_helper"

class BrandVariantTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @brand_identity = brand_identities(:valid_brand)
    @persona = personas(:professional_marketer)
    
    @valid_attributes = {
      user: @user,
      brand_identity: @brand_identity,
      persona: @persona,
      name: "Test Brand Variant",
      description: "A test brand variant for professional audience",
      adaptation_context: "audience_segment",
      adaptation_type: "demographic_targeting",
      priority: 5
    }
  end

  # Basic validations
  test "should be valid with valid attributes" do
    brand_variant = BrandVariant.new(@valid_attributes)
    assert brand_variant.valid?, "Expected brand variant to be valid, but got errors: #{brand_variant.errors.full_messages}"
  end

  test "should require user" do
    brand_variant = BrandVariant.new(@valid_attributes.except(:user))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:user], "must exist"
  end

  test "should require brand_identity" do
    brand_variant = BrandVariant.new(@valid_attributes.except(:brand_identity))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:brand_identity], "must exist"
  end

  test "should require name" do
    brand_variant = BrandVariant.new(@valid_attributes.except(:name))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:name], "can't be blank"
  end

  test "should require description" do
    brand_variant = BrandVariant.new(@valid_attributes.except(:description))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:description], "can't be blank"
  end

  test "should require adaptation_context" do
    brand_variant = BrandVariant.new(@valid_attributes.except(:adaptation_context))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:adaptation_context], "can't be blank"
  end

  test "should require adaptation_type" do
    brand_variant = BrandVariant.new(@valid_attributes.except(:adaptation_type))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:adaptation_type], "can't be blank"
  end

  test "should validate name uniqueness per user and brand identity" do
    BrandVariant.create!(@valid_attributes)
    duplicate = BrandVariant.new(@valid_attributes)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should allow same name for different brand identities" do
    brand_identity2 = BrandIdentity.create!(user: @user, name: "Another Brand")
    BrandVariant.create!(@valid_attributes)
    variant2 = BrandVariant.new(@valid_attributes.merge(brand_identity: brand_identity2))
    assert variant2.valid?
  end

  test "should validate adaptation_context inclusion" do
    brand_variant = BrandVariant.new(@valid_attributes.merge(adaptation_context: "invalid_context"))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:adaptation_context], "is not included in the list"
  end

  test "should validate adaptation_type inclusion" do
    brand_variant = BrandVariant.new(@valid_attributes.merge(adaptation_type: "invalid_type"))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:adaptation_type], "is not included in the list"
  end

  test "should validate status inclusion" do
    brand_variant = BrandVariant.new(@valid_attributes.merge(status: "invalid_status"))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:status], "is not included in the list"
  end

  test "should validate effectiveness_score range" do
    brand_variant = BrandVariant.new(@valid_attributes.merge(effectiveness_score: -1.0))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:effectiveness_score], "must be greater than or equal to 0.0"

    brand_variant = BrandVariant.new(@valid_attributes.merge(effectiveness_score: 11.0))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:effectiveness_score], "must be less than or equal to 10.0"

    brand_variant = BrandVariant.new(@valid_attributes.merge(effectiveness_score: 5.0))
    assert brand_variant.valid?
  end

  test "should validate usage_count is non-negative" do
    brand_variant = BrandVariant.new(@valid_attributes.merge(usage_count: -1))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:usage_count], "must be greater than or equal to 0"
  end

  test "should validate priority is non-negative" do
    brand_variant = BrandVariant.new(@valid_attributes.merge(priority: -1))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:priority], "must be greater than or equal to 0"
  end

  test "should validate name length" do
    brand_variant = BrandVariant.new(@valid_attributes.merge(name: "a" * 256))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:name], "is too long (maximum is 255 characters)"
  end

  test "should validate description length" do
    brand_variant = BrandVariant.new(@valid_attributes.merge(description: "a" * 2001))
    assert_not brand_variant.valid?
    assert_includes brand_variant.errors[:description], "is too long (maximum is 2000 characters)"
  end

  # Default values
  test "should set default values on creation" do
    brand_variant = BrandVariant.new(@valid_attributes.except(:priority))
    brand_variant.valid? # Trigger callbacks
    
    assert_equal "draft", brand_variant.status
    assert_equal 0, brand_variant.usage_count
    assert_equal 0, brand_variant.priority
    assert_equal({}, brand_variant.parsed_adaptation_rules)
    assert_equal({}, brand_variant.parsed_brand_voice_adjustments)
  end

  # Status methods
  test "status helper methods should work correctly" do
    brand_variant = BrandVariant.new(@valid_attributes)
    
    # Test draft status (default)
    assert brand_variant.draft?
    assert_not brand_variant.active?
    assert_not brand_variant.archived?
    assert_not brand_variant.testing?
    
    # Test active status
    brand_variant.status = 'active'
    assert brand_variant.active?
    assert_not brand_variant.draft?
    
    # Test archived status
    brand_variant.status = 'archived'
    assert brand_variant.archived?
    assert_not brand_variant.active?
    
    # Test testing status
    brand_variant.status = 'testing'
    assert brand_variant.testing?
    assert_not brand_variant.draft?
  end

  # Status change methods
  test "activate! should set status to active and update timestamp" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    
    brand_variant.activate!
    
    assert_equal "active", brand_variant.status
    assert_not_nil brand_variant.activated_at
  end

  test "deactivate! should set status to draft and clear timestamp" do
    brand_variant = BrandVariant.create!(@valid_attributes.merge(status: 'active', activated_at: Time.current))
    
    brand_variant.deactivate!
    
    assert_equal "draft", brand_variant.status
    assert_nil brand_variant.activated_at
  end

  test "archive! should set status to archived and update timestamp" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    
    brand_variant.archive!
    
    assert_equal "archived", brand_variant.status
    assert_not_nil brand_variant.archived_at
  end

  test "start_testing! should set status to testing and update timestamp" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    
    brand_variant.start_testing!
    
    assert_equal "testing", brand_variant.status
    assert_not_nil brand_variant.testing_started_at
  end

  # Usage tracking
  test "increment_usage! should increment usage count and update timestamp" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    initial_count = brand_variant.usage_count
    
    brand_variant.increment_usage!
    
    assert_equal initial_count + 1, brand_variant.usage_count
    assert_not_nil brand_variant.last_used_at
  end

  test "update_effectiveness! should update score and timestamp" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    
    brand_variant.update_effectiveness!(8.5)
    
    assert_equal 8.5, brand_variant.effectiveness_score
    assert_not_nil brand_variant.last_measured_at
  end

  # Scopes
  test "active scope should return only active variants" do
    active_variant = BrandVariant.create!(@valid_attributes.merge(status: 'active', name: 'Active Variant'))
    draft_variant = BrandVariant.create!(@valid_attributes.merge(status: 'draft', name: 'Draft Variant'))
    
    active_results = BrandVariant.active
    assert_includes active_results, active_variant
    assert_not_includes active_results, draft_variant
  end

  test "by_context scope should filter by adaptation context" do
    audience_variant = BrandVariant.create!(@valid_attributes.merge(adaptation_context: 'audience_segment', name: 'Audience Variant'))
    channel_variant = BrandVariant.create!(@valid_attributes.merge(adaptation_context: 'channel_specific', name: 'Channel Variant'))
    
    audience_results = BrandVariant.by_context('audience_segment')
    assert_includes audience_results, audience_variant
    assert_not_includes audience_results, channel_variant
  end

  test "by_type scope should filter by adaptation type" do
    demo_variant = BrandVariant.create!(@valid_attributes.merge(adaptation_type: 'demographic_targeting', name: 'Demo Variant'))
    tone_variant = BrandVariant.create!(@valid_attributes.merge(adaptation_type: 'tone_adaptation', name: 'Tone Variant'))
    
    demo_results = BrandVariant.by_type('demographic_targeting')
    assert_includes demo_results, demo_variant
    assert_not_includes demo_results, tone_variant
  end

  test "effective scope should return variants with high effectiveness scores" do
    effective_variant = BrandVariant.create!(@valid_attributes.merge(effectiveness_score: 8.0, name: 'Effective Variant'))
    poor_variant = BrandVariant.create!(@valid_attributes.merge(effectiveness_score: 5.0, name: 'Poor Variant'))
    
    effective_results = BrandVariant.effective
    assert_includes effective_results, effective_variant
    assert_not_includes effective_results, poor_variant
  end

  test "by_priority scope should order by priority" do
    high_priority = BrandVariant.create!(@valid_attributes.merge(priority: 10, name: 'High Priority'))
    low_priority = BrandVariant.create!(@valid_attributes.merge(priority: 1, name: 'Low Priority'))
    
    priority_results = BrandVariant.by_priority.to_a
    assert_equal low_priority, priority_results.first
    assert_equal high_priority, priority_results.last
  end

  # JSON parsing methods
  test "should parse JSON fields correctly" do
    rules = { "temporal_rules" => { "season_summer" => true } }
    adjustments = { "tone_shift" => "more_casual" }
    
    brand_variant = BrandVariant.create!(@valid_attributes.merge(
      adaptation_rules: rules,
      brand_voice_adjustments: adjustments
    ))
    
    assert_equal rules, brand_variant.parsed_adaptation_rules
    assert_equal adjustments, brand_variant.parsed_brand_voice_adjustments
  end

  test "should handle invalid JSON gracefully" do
    brand_variant = BrandVariant.new(@valid_attributes)
    brand_variant.adaptation_rules = "invalid json"
    brand_variant.save!
    
    # Test the parsed method handles invalid JSON
    assert_equal({}, brand_variant.parsed_adaptation_rules)
  end

  test "should convert string JSON to hash" do
    brand_variant = BrandVariant.new(@valid_attributes)
    brand_variant.adaptation_rules = '{"test": "value"}'
    brand_variant.save!
    
    # Test the parsed method converts string JSON
    assert_equal({ "test" => "value" }, brand_variant.parsed_adaptation_rules)
  end

  # Brand adaptation functionality
  test "apply_brand_adaptation should process content" do
    brand_variant = BrandVariant.create!(@valid_attributes.merge(
      brand_voice_adjustments: { "tone_shift" => "more_casual" }
    ))
    
    original_content = "This is professional content."
    context = { channel: "social_media" }
    
    adapted_content = brand_variant.apply_brand_adaptation(original_content, context)
    
    assert_not_equal original_content, adapted_content
    assert brand_variant.reload.usage_count > 0
    assert_not_nil brand_variant.last_used_at
  end

  test "generate_variant should use brand adaptation" do
    brand_variant = BrandVariant.create!(@valid_attributes.merge(
      brand_voice_adjustments: { "tone_shift" => "more_casual" }
    ))
    
    base_content = "This is professional content."
    variant_params = { channel: "email" }
    
    result = brand_variant.generate_variant(base_content, variant_params)
    
    assert_not_nil result
    # Should process content through brand adaptation
    assert result.is_a?(String)
  end

  # Compatibility scoring
  test "compatibility_score_with should calculate score for persona" do
    brand_variant = BrandVariant.create!(@valid_attributes.merge(
      audience_targeting: {
        "demographics" => { "age_group" => "25-40" },
        "persona_targeting" => {
          "demographic_adaptations" => { "age_group" => "younger" }
        }
      }
    ))
    
    score = brand_variant.compatibility_score_with(@persona)
    
    assert score.is_a?(Numeric)
    assert score >= 0.0
    assert score <= 1.0
  end

  test "compatibility_score_with should return 0 for nil persona" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    score = brand_variant.compatibility_score_with(nil)
    assert_equal 0.0, score
  end

  # Performance summary
  test "performance_summary should return comprehensive data" do
    brand_variant = BrandVariant.create!(@valid_attributes.merge(
      status: 'active',
      effectiveness_score: 7.5,
      usage_count: 10,
      last_used_at: 1.hour.ago
    ))
    
    summary = brand_variant.performance_summary
    
    assert_equal 7.5, summary[:effectiveness_score]
    assert_equal 10, summary[:usage_count]
    assert_equal brand_variant.last_used_at, summary[:last_used]
    assert_equal "active", summary[:status]
    assert_equal "demographic_targeting", summary[:adaptation_type]
    assert_equal "audience_segment", summary[:adaptation_context]
    assert_includes %w[improving declining stable], summary[:performance_trend]
  end

  # Performance tracking callbacks
  test "should update performance metrics when effectiveness score changes" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    
    brand_variant.update!(effectiveness_score: 8.0)
    
    metrics = brand_variant.parsed_performance_metrics
    history = metrics['effectiveness_history']
    
    assert_not_nil history
    assert history.is_a?(Array)
    assert_equal 1, history.length
    assert_equal 8.0, history.first['score'].to_f
  end

  test "should limit effectiveness history to 50 entries" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    
    # Create initial history with 50 entries
    initial_history = (1..50).map do |i|
      { 'score' => i.to_f, 'measured_at' => i.hours.ago.iso8601, 'context' => 'test' }
    end
    
    brand_variant.update!(performance_metrics: { 'effectiveness_history' => initial_history })
    
    # Add one more entry
    brand_variant.update!(effectiveness_score: 9.0)
    
    history = brand_variant.parsed_performance_metrics['effectiveness_history']
    assert_equal 50, history.length
    assert_equal 9.0, history.last['score'].to_f # Most recent should be at the end
  end

  # Content adaptation methods
  test "should apply tone adjustments" do
    brand_variant = BrandVariant.create!(@valid_attributes.merge(
      brand_voice_adjustments: { "tone_shift" => "more_formal" }
    ))
    
    content = "Hey there! This is awesome!"
    adapted = brand_variant.send(:adjust_tone, content, "more_formal", {})
    
    assert_not_equal content, adapted
    assert_not adapted.include?("Hey")
  end

  test "should apply formality adjustments" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    
    content = "You can't do this because you won't succeed."
    high_formality = brand_variant.send(:adjust_formality, content, "high")
    
    assert_equal "You cannot do this because you will not succeed.", high_formality
  end

  test "should format content for different channels" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    
    content = "This is sentence one. This is sentence two. This is sentence three."
    
    bullet_format = brand_variant.send(:format_for_channel, content, "bullet_points")
    assert bullet_format.include?("•")
    
    numbered_format = brand_variant.send(:format_for_channel, content, "numbered_list")
    assert numbered_format.include?("1.")
  end

  # Edge cases and error handling
  test "should handle empty JSON fields gracefully" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    
    # Test with nil values
    brand_variant.update!(adaptation_rules: nil)
    
    assert_equal({}, brand_variant.parsed_adaptation_rules)
  end

  test "should handle non-hash JSON values" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    brand_variant.update!(adaptation_rules: "not a hash")
    
    # Test the parsed method handles non-hash values
    assert_equal({}, brand_variant.parsed_adaptation_rules)
  end

  test "should calculate trend slope correctly" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    
    # Test improving trend
    improving_scores = [5.0, 6.0, 7.0, 8.0, 9.0]
    slope = brand_variant.send(:calculate_trend_slope, improving_scores)
    assert slope > 0.2
    
    # Test declining trend
    declining_scores = [9.0, 8.0, 7.0, 6.0, 5.0]
    slope = brand_variant.send(:calculate_trend_slope, declining_scores)
    assert slope < -0.2
    
    # Test stable trend
    stable_scores = [7.0, 7.1, 6.9, 7.0, 7.1]
    slope = brand_variant.send(:calculate_trend_slope, stable_scores)
    assert slope.abs < 0.2
  end

  # Association tests
  test "should belong to user" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    assert_equal @user, brand_variant.user
  end

  test "should belong to brand_identity" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    assert_equal @brand_identity, brand_variant.brand_identity
  end

  test "should optionally belong to persona" do
    brand_variant = BrandVariant.create!(@valid_attributes)
    assert_equal @persona, brand_variant.persona
    
    # Should work without persona too
    brand_variant_no_persona = BrandVariant.create!(@valid_attributes.except(:persona).merge(name: "No Persona Variant"))
    assert_nil brand_variant_no_persona.persona
  end

  # Integration with brand identity
  test "should respect brand identity restrictions" do
    @brand_identity.update!(restrictions: "avoid: bad, terrible, awful")
    brand_variant = BrandVariant.create!(@valid_attributes)
    
    content_with_restrictions = "This is a terrible and awful experience."
    restricted_terms = brand_variant.send(:extract_restricted_terms, @brand_identity.restrictions)
    
    assert_includes restricted_terms, "terrible"
    assert_includes restricted_terms, "awful"
    
    cleaned_content = brand_variant.send(:remove_restricted_terms, content_with_restrictions, restricted_terms)
    assert_not cleaned_content.include?("terrible")
    assert_not cleaned_content.include?("awful")
  end

  test "should align with brand voice" do
    @brand_identity.update!(brand_voice: "We are innovative, professional, and reliable leaders in technology solutions")
    brand_variant = BrandVariant.create!(@valid_attributes)
    
    content = "This is basic content that is long enough to meet the minimum requirements for incorporating brand voice keywords into the messaging."
    aligned_content = brand_variant.align_with_brand_voice(content)
    
    # Should incorporate brand voice elements when content is long enough
    assert_not_equal content, aligned_content
    assert aligned_content.include?("approach")
  end

  # Constants validation
  test "should have correct adaptation types" do
    expected_types = %w[
      tone_adaptation
      messaging_adaptation
      visual_adaptation
      channel_optimization
      demographic_targeting
      behavioral_targeting
      contextual_adaptation
    ]
    
    assert_equal expected_types, BrandVariant::ADAPTATION_TYPES
  end

  test "should have correct adaptation contexts" do
    expected_contexts = %w[
      audience_segment
      channel_specific
      campaign_context
      temporal_context
      geographical_context
      competitive_context
    ]
    
    assert_equal expected_contexts, BrandVariant::ADAPTATION_CONTEXTS
  end

  test "should have correct statuses" do
    expected_statuses = %w[draft active archived testing]
    assert_equal expected_statuses, BrandVariant::STATUSES
  end
end