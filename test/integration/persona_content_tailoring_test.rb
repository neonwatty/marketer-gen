require "test_helper"

class PersonaContentTailoringTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    # Create a campaign for the test user
    @campaign = CampaignPlan.create!(
      user: @user,
      name: "Test Campaign",
      description: "Test campaign for integration testing",
      campaign_type: "product_launch", 
      objective: "brand_awareness",
      target_audience: "Test audience",
      status: "draft"
    )
    @content = generated_contents(:one)
    @persona = personas(:professional_marketer)
  end

  test "complete persona-based content tailoring workflow" do
    # Step 1: Verify user has personas
    assert @user.has_personas?, "User should have active personas"
    assert @user.active_personas.include?(@persona), "User should have professional marketer persona"

    # Step 2: Test persona matching with user profile
    user_profile = {
      'demographics' => { 
        'age_group' => '26-40', 
        'location' => 'urban', 
        'industry' => 'marketing' 
      },
      'behavioral_traits' => { 
        'attention_span' => 'medium', 
        'urgency_sensitive' => true 
      },
      'goals' => ['increase_productivity', 'improve_roi']
    }

    matching_personas = @user.find_matching_personas(user_profile)
    assert matching_personas.any?, "Should find matching personas for the user profile"

    best_persona = @user.best_matching_persona(user_profile)
    assert_not_nil best_persona, "Should find best matching persona"

    # Step 3: Test persona content adaptation
    original_content = @content.body_content
    assert_not_nil original_content, "Content should have body content"

    # Generate persona adaptations
    adaptations = @content.generate_persona_adaptations_for_user(@user)
    assert adaptations.any?, "Should generate persona adaptations"

    # Verify adaptation was created
    persona_content = @content.persona_contents.find_by(persona: best_persona)
    if persona_content.nil?
      # Create adaptation manually if not generated automatically
      persona_content = PersonaContent.create_adaptation(
        best_persona,
        @content,
        'tone_adaptation',
        { primary: true }
      )
    end

    assert_not_nil persona_content, "Should create persona content adaptation"
    assert_not_equal original_content, persona_content.adapted_content, "Adapted content should be different"

    # Step 4: Test content retrieval for user profile
    tailored_content = PersonaTailoringService.tailor_content_for_user_profile(
      @content,
      user_profile,
      @user
    )

    assert_not_nil tailored_content, "Should return tailored content"
    # Content might be original or adapted depending on matching logic
    assert [original_content, persona_content.adapted_content].include?(tailored_content), 
           "Tailored content should be either original or adapted content"

    # Step 5: Test effectiveness tracking
    persona_content.update!(effectiveness_score: 8.5)
    assert persona_content.effective?, "Content should be effective with high score"

    # Step 6: Test performance analytics
    performance_summary = @content.persona_adaptation_summary
    assert_kind_of Hash, performance_summary
    assert performance_summary[:total_adaptations] > 0, "Should track adaptations"

    persona_performance = @persona.content_performance_summary
    assert_kind_of Hash, persona_performance
    assert persona_performance[:total_adaptations] > 0, "Persona should track adaptations"

    # Step 7: Test user persona analytics
    user_performance = @user.persona_performance_summary
    assert_kind_of Hash, user_performance
    assert user_performance[:active_personas] > 0, "User should have active personas"
    assert user_performance[:total_adaptations] > 0, "User should have adaptations tracked"

    # Step 8: Test service-level analytics
    service_analysis = PersonaTailoringService.analyze_persona_effectiveness(@user, 30.days)
    assert_kind_of Hash, service_analysis
    assert service_analysis.key?(@persona.id), "Analysis should include our persona"

    persona_analysis = service_analysis[@persona.id]
    assert_equal @persona.name, persona_analysis[:persona_name]
    assert persona_analysis[:total_adaptations] > 0

    # Step 9: Test recommendations generation
    recommendations = PersonaTailoringService.recommend_persona_improvements(@user)
    assert_kind_of Array, recommendations
    # Recommendations may be empty if performance is good

    # Step 10: Test batch processing
    all_contents = @user.created_contents.limit(3)
    if all_contents.count < 2
      # Create additional content for batch testing
      additional_content = GeneratedContent.create!(
        campaign_plan: @campaign,
        created_by: @user,
        title: "Additional Test Content",
        body_content: "This is additional comprehensive content for batch testing persona adaptations. It includes sufficient text to meet the minimum character requirements for validation purposes and provides meaningful content for testing the persona adaptation system functionality across multiple content pieces.",
        content_type: 'email',
        format_variant: 'standard',
        status: 'draft',
        version_number: 1
      )
      all_contents = [@content, additional_content]
    end

    batch_results = PersonaTailoringService.batch_create_adaptations(@user, all_contents)
    assert_kind_of Array, batch_results
    assert_equal all_contents.size, batch_results.size, "Should process all contents in batch"

    batch_results.each do |result|
      assert_includes result, :content_id
      assert_includes result, :result
      assert_kind_of Hash, result[:result]
    end

    # Step 11: Test adaptation type selection
    different_personas = @user.active_personas
    different_personas.each do |persona|
      adaptation_type = @content.send(:determine_best_adaptation_type, persona)
      assert_includes PersonaContent::ADAPTATION_TYPES, adaptation_type, 
                     "Should select valid adaptation type for #{persona.name}"
    end

    # Step 12: Test content performance comparison
    if @content.has_persona_adaptations?
      primary_adaptation = @content.primary_persona_adaptation
      if primary_adaptation
        impact_analysis = primary_adaptation.adaptation_impact_analysis
        assert_kind_of Hash, impact_analysis
        assert_includes impact_analysis, :effectiveness_score
      end
    end

    # Step 13: Test persona activation/deactivation effects
    original_active_count = @user.active_personas.count
    @persona.deactivate!
    
    assert_equal original_active_count - 1, @user.reload.active_personas.count
    
    # Test that deactivated persona doesn't match
    new_matching_personas = @user.find_matching_personas(user_profile)
    assert_not_includes new_matching_personas, @persona, "Deactivated persona should not match"

    # Reactivate for cleanup
    @persona.activate!
    assert_equal original_active_count, @user.reload.active_personas.count

    # Step 14: Test edge cases
    
    # Test with empty user profile
    empty_profile_content = PersonaTailoringService.tailor_content_for_user_profile(
      @content, {}, @user
    )
    assert_equal @content.body_content, empty_profile_content, 
                "Should return original content for empty profile"

    # Test with nil user profile  
    nil_profile_content = PersonaTailoringService.tailor_content_for_user_profile(
      @content, nil, @user
    )
    assert_equal @content.body_content, nil_profile_content,
                "Should return original content for nil profile"

    # Test persona matching rules
    rules = @persona.parsed_matching_rules
    assert_kind_of Hash, rules
    assert rules['match_threshold'] > 0, "Should have match threshold configured"
  end

  test "persona content adaptation handles various content types" do
    content_types = ['email', 'social_post', 'blog_article', 'ad_copy', 'landing_page']
    
    content_types.each do |content_type|
      test_content = GeneratedContent.create!(
        campaign_plan: @campaign,
        created_by: @user,
        title: "Test #{content_type.humanize} Content",
        body_content: "This is comprehensive test content for #{content_type} adaptation testing that meets the minimum character requirements for validation purposes and provides sufficient content for meaningful persona-based adaptations.",
        content_type: content_type,
        format_variant: 'standard',
        status: 'draft',
        version_number: 1
      )

      # Test adaptation for this content type
      adaptation = test_content.create_persona_adaptation(
        @persona,
        'tone_adaptation',
        { rationale: "Testing #{content_type} adaptation" }
      )

      assert_not_nil adaptation, "Should create adaptation for #{content_type}"
      assert_equal content_type, adaptation.generated_content.content_type
      assert_not_equal test_content.body_content, adaptation.adapted_content,
                      "Adapted #{content_type} content should be different from original"

      # Clean up
      test_content.destroy
    end
  end

  test "persona system handles multiple personas per user" do
    # Create additional personas for the user
    additional_persona = Persona.create!(
      user: @user,
      name: "Test Secondary Persona",
      description: "Secondary persona for multi-persona testing",
      characteristics: "Technical, analytical",
      demographics: '{"age_group": "30-45", "role": "technical"}',
      goals: '["technical_efficiency", "data_accuracy"]',
      pain_points: '["complex_integrations", "data_quality"]',
      preferred_channels: '["documentation", "webinar"]',
      content_preferences: '{"tone": "technical", "format": "detailed"}',
      behavioral_traits: '{"attention_span": "long", "detail_oriented": true}',
      priority: 2
    )

    # Test that user has multiple active personas
    active_personas = @user.active_personas
    assert active_personas.count >= 2, "User should have multiple active personas"
    assert_includes active_personas, @persona, "Should include original persona"
    assert_includes active_personas, additional_persona, "Should include additional persona"

    # Test adaptation creation for multiple personas
    # Calculate expected adaptations BEFORE generating them
    expected_adaptations = active_personas.reject { |p| @content.persona_contents.exists?(persona: p) }
    
    adaptations = @content.generate_persona_adaptations_for_user(@user)
    
    # Should create adaptations for active personas that don't have existing adaptations
    assert adaptations.count <= expected_adaptations.count, 
           "Should create adaptations for personas without existing ones"

    # Test persona priority ordering
    priority_ordered = @user.active_personas.by_priority
    assert priority_ordered.first.priority <= priority_ordered.second.priority,
           "Personas should be ordered by priority"

    # Clean up
    additional_persona.destroy
  end

  test "persona content effectiveness tracking and optimization" do
    # Create multiple adaptations with different effectiveness scores
    adaptations_data = [
      { type: 'tone_adaptation', score: 8.5 },
      { type: 'length_adaptation', score: 6.2 },
      { type: 'channel_optimization', score: 9.1 },
      { type: 'goal_alignment', score: 7.8 }
    ]

    adaptations_data.each_with_index do |data, index|
      content = GeneratedContent.create!(
        campaign_plan: @campaign,
        created_by: @user,
        title: "Test Content #{index + 1}",
        body_content: "This is comprehensive content for effectiveness testing #{index + 1} that meets the minimum character requirements for validation purposes and provides sufficient content for meaningful persona-based adaptations and analytics.",
        content_type: 'email',
        format_variant: 'standard',
        status: 'draft',
        version_number: 1
      )

      PersonaContent.create!(
        persona: @persona,
        generated_content: content,
        adaptation_type: data[:type],
        adapted_content: "Adapted content for #{data[:type]}",
        effectiveness_score: data[:score]
      )
    end

    # Test effectiveness analytics
    analytics = PersonaContent.effectiveness_analytics
    assert analytics[:total_adaptations] >= 4, "Should track multiple adaptations"
    assert analytics[:average_effectiveness] > 0, "Should calculate average effectiveness"
    
    most_effective_type = analytics[:most_effective_type]
    assert_equal 'channel_optimization', most_effective_type, 
                "Should identify most effective adaptation type"

    # Test persona performance tracking
    persona_performance = @persona.content_performance_summary
    assert persona_performance[:total_adaptations] >= 4, "Persona should track all adaptations"
    assert persona_performance[:average_effectiveness] > 7, "Should have good average effectiveness"

    # Test service-level recommendations
    service_recommendations = PersonaTailoringService.recommend_persona_improvements(@user)
    assert_kind_of Array, service_recommendations, "Should generate recommendations array"

    # Test effectiveness filtering
    effective_adaptations = @persona.persona_contents.effective
    high_scoring_adaptations = effective_adaptations.select { |pc| pc.effectiveness_score >= 7.0 }
    assert high_scoring_adaptations.count >= 3, "Should have multiple effective adaptations"

    # Clean up created content
    @user.created_contents.where("title LIKE ?", "Test Content %").destroy_all
  end

  private

  def assert_persona_content_valid(persona_content)
    assert persona_content.valid?, "Persona content should be valid: #{persona_content.errors.full_messages}"
    assert_not_nil persona_content.adapted_content, "Should have adapted content"
    assert_includes PersonaContent::ADAPTATION_TYPES, persona_content.adaptation_type, 
           "Should have valid adaptation type"
  end
end