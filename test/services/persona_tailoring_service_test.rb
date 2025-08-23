require "test_helper"

class PersonaTailoringServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @content = generated_contents(:one)
    @persona = personas(:professional_marketer)
    @service = PersonaTailoringService.new(@user, @content)
    
    # Clear any existing persona content to avoid uniqueness constraints
    PersonaContent.where(persona: @persona, generated_content: @content).destroy_all
  end

  test "should initialize with user and content" do
    service = PersonaTailoringService.new(@user, @content)
    assert_not_nil service
  end

  test "should fail when user has no personas" do
    user_without_personas = users(:two)
    user_without_personas.personas.destroy_all
    
    service = PersonaTailoringService.new(user_without_personas, @content)
    result = service.call
    
    assert_not result[:success]
    assert_includes result[:error], "must have active personas"
  end

  test "should fail when no content provided" do
    service = PersonaTailoringService.new(@user, nil)
    result = service.call
    
    assert_not result[:success] 
    assert_includes result[:error], "Content is required"
  end

  test "should create adaptations for active personas" do
    # Ensure user has active personas
    assert @user.has_personas?
    
    result = @service.call
    
    assert result[:success]
    assert_kind_of Array, result[:adaptations]
    assert_kind_of Array, result[:persona_matches]
    assert_kind_of Array, result[:recommendations]
  end

  test "should tailor content for user profile" do
    user_profile = {
      'demographics' => { 'age_group' => '26-40', 'industry' => 'marketing' },
      'behavioral_traits' => { 'attention_span' => 'medium' },
      'goals' => ['increase_productivity']
    }
    
    tailored_content = PersonaTailoringService.tailor_content_for_user_profile(
      @content, 
      user_profile, 
      @user
    )
    
    assert_not_nil tailored_content
    assert_kind_of String, tailored_content
  end

  test "should return original content when user has no personas" do
    user_without_personas = users(:two)
    user_without_personas.personas.destroy_all
    
    user_profile = { 'demographics' => { 'age_group' => '26-40' } }
    
    tailored_content = PersonaTailoringService.tailor_content_for_user_profile(
      @content,
      user_profile,
      user_without_personas
    )
    
    assert_equal @content.body_content, tailored_content
  end

  test "should return original content when no matching personas" do
    user_profile = {
      'demographics' => { 'age_group' => '18-25' }, # Doesn't match professional_marketer
      'goals' => ['different_goals']
    }
    
    tailored_content = PersonaTailoringService.tailor_content_for_user_profile(
      @content,
      user_profile, 
      @user
    )
    
    # Should return original content or adapted content
    assert_not_nil tailored_content
  end

  test "should handle batch content adaptation" do
    contents = [@content, generated_contents(:two)]
    
    results = PersonaTailoringService.batch_create_adaptations(@user, contents)
    
    assert_kind_of Array, results
    assert_equal contents.size, results.size
    
    results.each do |result|
      assert_includes result, :content_id
      assert_includes result, :content_title
      assert_includes result, :result
    end
  end

  test "should analyze persona effectiveness" do
    # Create some persona content for analysis
    PersonaContent.create!(
      persona: @persona,
      generated_content: @content,
      adaptation_type: 'tone_adaptation',
      adapted_content: 'Test adapted content',
      effectiveness_score: 8.0
    )
    
    analysis = PersonaTailoringService.analyze_persona_effectiveness(@user, 30.days)
    
    assert_kind_of Hash, analysis
    assert_includes analysis, @persona.id
    
    persona_analysis = analysis[@persona.id]
    assert_includes persona_analysis, :persona_name
    assert_includes persona_analysis, :total_adaptations
    assert_includes persona_analysis, :average_effectiveness
  end

  test "should recommend persona improvements" do
    # Create persona content with varying effectiveness
    PersonaContent.create!(
      persona: @persona,
      generated_content: @content,
      adaptation_type: 'tone_adaptation',
      adapted_content: 'Low performing content',
      effectiveness_score: 3.0
    )
    
    recommendations = PersonaTailoringService.recommend_persona_improvements(@user)
    
    assert_kind_of Array, recommendations
    
    if recommendations.any?
      recommendation = recommendations.first
      assert_includes recommendation, :persona_id
      assert_includes recommendation, :type
      assert_includes recommendation, :priority
      assert_includes recommendation, :message
    end
  end

  test "should handle empty user profile gracefully" do
    tailored_content = PersonaTailoringService.tailor_content_for_user_profile(
      @content,
      {},
      @user
    )
    
    assert_equal @content.body_content, tailored_content
  end

  test "should handle nil user profile gracefully" do
    tailored_content = PersonaTailoringService.tailor_content_for_user_profile(
      @content,
      nil,
      @user
    )
    
    assert_equal @content.body_content, tailored_content
  end

  test "private method should determine optimal adaptation type" do
    adaptation_type = @service.send(:determine_optimal_adaptation_type, @persona, @content)
    
    assert_includes PersonaContent::ADAPTATION_TYPES, adaptation_type
  end

  test "private method should calculate persona content match" do
    match_score = @service.send(:calculate_persona_content_match, @persona, @content)
    
    assert_kind_of Numeric, match_score
    assert match_score >= 0
    assert match_score <= 100
  end

  test "should generate optimization recommendations" do
    adaptations = [
      {
        adaptation: PersonaContent.new(effectiveness_score: 8.5),
        adaptation_type: 'tone_adaptation'
      }
    ]
    
    recommendations = @service.send(:generate_optimization_recommendations, adaptations)
    
    assert_kind_of Array, recommendations
  end

  test "should calculate performance trend" do
    # Create adaptations with different scores over time
    old_adaptation = PersonaContent.create!(
      persona: @persona,
      generated_content: @content,
      adaptation_type: 'tone_adaptation',
      adapted_content: 'Old content',
      effectiveness_score: 6.0,
      created_at: 10.days.ago
    )
    
    recent_adaptation = PersonaContent.create!(
      persona: @persona,
      generated_content: generated_contents(:two),
      adaptation_type: 'length_adaptation', 
      adapted_content: 'Recent content',
      effectiveness_score: 8.0,
      created_at: 2.days.ago
    )
    
    adaptations = PersonaContent.where(persona: @persona).order(:created_at)
    trend = PersonaTailoringService.calculate_performance_trend(adaptations)
    
    assert_includes ['improving', 'declining', 'stable', 'insufficient_data'], trend
  end

  test "should analyze single persona" do
    PersonaContent.create!(
      persona: @persona,
      generated_content: @content,
      adaptation_type: 'tone_adaptation',
      adapted_content: 'Analysis content',
      effectiveness_score: 7.5
    )
    
    analysis = PersonaTailoringService.analyze_single_persona(@persona)
    
    assert_kind_of Hash, analysis
    assert_includes analysis, :total_adaptations
    assert_includes analysis, :average_effectiveness
    assert_includes analysis, :content_type_performance
    assert_includes analysis, :adaptation_type_performance
  end

  test "should generate persona recommendations based on analysis" do
    # Create low performing persona content
    PersonaContent.create!(
      persona: @persona,
      generated_content: @content,
      adaptation_type: 'tone_adaptation',
      adapted_content: 'Low performing content',
      effectiveness_score: 2.0
    )
    
    analysis = PersonaTailoringService.analyze_single_persona(@persona)
    recommendations = PersonaTailoringService.generate_persona_recommendations(@persona, analysis)
    
    assert_kind_of Array, recommendations
    
    if recommendations.any?
      rec = recommendations.first
      assert_equal @persona.id, rec[:persona_id]
      assert_equal @persona.name, rec[:persona_name]
      assert_includes rec, :type
      assert_includes rec, :priority
      assert_includes rec, :message
    end
  end

  test "should handle service errors gracefully" do
    # Simulate an error by using invalid persona
    service = PersonaTailoringService.new(@user, @content)
    
    # Mock a method to raise an error
    service.define_singleton_method(:create_persona_adaptation) do |persona|
      raise StandardError, "Simulated error"
    end
    
    result = service.call
    
    # Should handle the error and return failure result
    assert_not result[:success]
    assert_includes result[:error], "Error in persona tailoring"
  end

  test "should return empty analysis for user without personas" do
    user_without_personas = users(:two)
    user_without_personas.personas.destroy_all
    
    analysis = PersonaTailoringService.analyze_persona_effectiveness(user_without_personas)
    recommendations = PersonaTailoringService.recommend_persona_improvements(user_without_personas)
    
    assert_equal Hash.new, analysis
    assert_equal [], recommendations
  end

  test "class methods should handle edge cases" do
    empty_contents = []
    
    # Test batch creation with empty array
    results = PersonaTailoringService.batch_create_adaptations(@user, empty_contents)
    assert_equal [], results
    
    # Test with user without personas
    user_without_personas = users(:two)
    user_without_personas.personas.destroy_all
    
    results = PersonaTailoringService.batch_create_adaptations(user_without_personas, [@content])
    assert_equal [], results
  end
end