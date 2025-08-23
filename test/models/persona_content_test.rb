require "test_helper"

class PersonaContentTest < ActiveSupport::TestCase
  def setup
    @persona = personas(:professional_marketer)
    @content = generated_contents(:one)
    
    # Clear any existing persona content to avoid uniqueness constraint
    PersonaContent.where(persona: @persona, generated_content: @content).destroy_all
    
    @persona_content = PersonaContent.create!(
      persona: @persona,
      generated_content: @content,
      adaptation_type: 'tone_adaptation',
      adapted_content: 'Professionally adapted content for marketing professionals',
      effectiveness_score: 8.5
    )
  end

  test "should be valid with valid attributes" do
    persona_content = PersonaContent.new(
      persona: @persona,
      generated_content: @content,
      adaptation_type: 'length_adaptation',
      adapted_content: 'Shortened content',
      effectiveness_score: 7.0
    )
    
    # Skip uniqueness constraint for this test
    @persona_content.destroy
    assert persona_content.valid?
  end

  test "should require adaptation_type" do
    persona_content = PersonaContent.new(
      persona: @persona,
      generated_content: @content,
      adapted_content: 'Test content'
    )
    
    persona_content.valid?
    assert_includes persona_content.errors[:adaptation_type], "can't be blank"
  end

  test "should validate adaptation_type inclusion" do
    persona_content = PersonaContent.new(
      persona: @persona,
      generated_content: @content,
      adaptation_type: 'invalid_type',
      adapted_content: 'Test content'
    )
    
    persona_content.valid?
    assert_includes persona_content.errors[:adaptation_type], "is not included in the list"
  end

  test "should validate effectiveness_score range" do
    persona_content = PersonaContent.new(
      persona: @persona,
      generated_content: @content,
      adaptation_type: 'tone_adaptation',
      adapted_content: 'Test content',
      effectiveness_score: 11.0
    )
    
    persona_content.valid?
    assert_includes persona_content.errors[:effectiveness_score], "must be in 0.0..10.0"
  end

  test "should enforce uniqueness of persona per content" do
    duplicate_content = PersonaContent.new(
      persona: @persona,
      generated_content: @content,
      adaptation_type: 'length_adaptation',
      adapted_content: 'Duplicate content'
    )
    
    duplicate_content.valid?
    assert_includes duplicate_content.errors[:persona_id], "has already been taken"
  end

  test "should determine if effective" do
    effective_content = PersonaContent.new(effectiveness_score: 8.0)
    ineffective_content = PersonaContent.new(effectiveness_score: 5.0)
    no_score_content = PersonaContent.new(effectiveness_score: nil)
    
    assert effective_content.effective?
    assert_not ineffective_content.effective?
    assert_not no_score_content.effective?
  end

  test "should identify primary and secondary adaptations" do
    primary_adaptation = PersonaContent.new(is_primary_adaptation: true)
    secondary_adaptation = PersonaContent.new(is_primary_adaptation: false)
    
    assert primary_adaptation.primary_adaptation?
    assert_not primary_adaptation.secondary_adaptation?
    assert_not secondary_adaptation.primary_adaptation?
    assert secondary_adaptation.secondary_adaptation?
  end

  test "should set as primary and update others" do
    other_content = generated_contents(:two)
    other_adaptation = PersonaContent.create!(
      persona: @persona,
      generated_content: other_content,
      adaptation_type: 'goal_alignment',
      adapted_content: 'Goal aligned content',
      is_primary_adaptation: true
    )
    
    @persona_content.set_as_primary!
    
    assert @persona_content.reload.primary_adaptation?
    # other_adaptation should remain primary as it's for different content
    assert other_adaptation.reload.primary_adaptation?
  end

  test "should parse metadata" do
    metadata = { 'test_key' => 'test_value', 'nested' => { 'inner' => 'value' } }
    @persona_content.update!(adaptation_metadata: metadata)
    
    parsed = @persona_content.parsed_metadata
    assert_equal 'test_value', parsed['test_key']
    assert_equal 'value', parsed.dig('nested', 'inner')
  end

  test "should update metadata" do
    initial_metadata = { 'existing' => 'value' }
    @persona_content.update!(adaptation_metadata: initial_metadata)
    
    new_metadata = { 'new_key' => 'new_value' }
    @persona_content.update_metadata(new_metadata)
    
    updated = @persona_content.reload.parsed_metadata
    assert_equal 'value', updated['existing']
    assert_equal 'new_value', updated['new_key']
  end

  test "should provide performance summary" do
    summary = @persona_content.performance_summary
    
    assert_kind_of Hash, summary
    assert_equal 'tone_adaptation', summary[:adaptation_type]
    assert_equal 8.5, summary[:effectiveness_score]
    assert_equal @persona.name, summary[:persona_name]
    assert_equal @content.content_type, summary[:content_type]
  end

  test "should calculate content length change" do
    @content.update!(body_content: 'Original content with specific length that meets the minimum requirements for standard format validation rules which require at least 100 characters.')
    @persona_content.update!(adapted_content: 'Shorter content.')
    
    length_change = @persona_content.content_length_change
    
    assert_kind_of Hash, length_change
    assert length_change[:original] > length_change[:adapted]
    assert_kind_of Numeric, length_change[:percentage_change]
  end

  test "should calculate word count change" do
    @content.update!(body_content: 'This is the original content with many words that meet the minimum character requirements for content validation in the standard format which needs at least one hundred characters total.')
    @persona_content.update!(adapted_content: 'Short content.')
    
    word_change = @persona_content.word_count_change
    
    assert_kind_of Hash, word_change
    assert word_change[:original] > word_change[:adapted]
    assert word_change[:change] < 0 # Fewer words
  end

  test "should provide adaptation impact analysis" do
    analysis = @persona_content.adaptation_impact_analysis
    
    assert_kind_of Hash, analysis
    assert_includes analysis, :effectiveness_score
    assert_includes analysis, :adaptation_rationale
  end

  test "scopes should work correctly" do
    # Test by_adaptation_type scope
    tone_adaptations = PersonaContent.by_adaptation_type('tone_adaptation')
    assert tone_adaptations.all? { |pc| pc.adaptation_type == 'tone_adaptation' }
    
    # Test primary_adaptations scope
    primary_count = PersonaContent.primary_adaptations.count
    assert_kind_of Integer, primary_count
    
    # Test effective scope
    effective_adaptations = PersonaContent.effective
    assert effective_adaptations.all? { |pc| pc.effective? }
  end

  test "should calculate effectiveness analytics" do
    # Create additional persona content for analytics
    PersonaContent.create!(
      persona: @persona,
      generated_content: generated_contents(:two),
      adaptation_type: 'length_adaptation',
      adapted_content: 'Length adapted content',
      effectiveness_score: 6.5
    )
    
    analytics = PersonaContent.effectiveness_analytics
    
    assert_kind_of Hash, analytics
    assert_includes analytics, :total_adaptations
    assert_includes analytics, :average_effectiveness
    assert_includes analytics, :effectiveness_by_type
    assert analytics[:total_adaptations] >= 2
  end

  test "should create adaptation with class method" do
    other_content = generated_contents(:two) 
    other_persona = personas(:startup_founder)
    
    # Clear any existing persona content to avoid uniqueness constraint
    PersonaContent.where(persona: other_persona, generated_content: other_content).destroy_all
    
    adaptation = PersonaContent.create_adaptation(
      other_persona, 
      other_content, 
      'behavioral_trigger',
      { rationale: 'Custom rationale', primary: true }
    )
    
    assert_not_nil adaptation
    assert_equal other_persona, adaptation.persona
    assert_equal other_content, adaptation.generated_content
    assert_equal 'behavioral_trigger', adaptation.adaptation_type
    assert adaptation.primary_adaptation?
  end

  test "should build adaptation metadata" do
    metadata = PersonaContent.build_adaptation_metadata(
      @persona, 
      @content, 
      'tone_adaptation',
      { custom_param: 'value' }
    )
    
    assert_kind_of Hash, metadata
    assert_includes metadata, :original_content_type
    assert_includes metadata, :persona_characteristics
    assert_includes metadata, :adaptation_context
    assert_includes metadata, :performance_tracking
    
    assert_equal @content.content_type, metadata[:original_content_type]
    assert_equal 'value', metadata.dig(:adaptation_context, :custom_parameters, :custom_param)
  end

  test "should calculate engagement prediction" do
    prediction = PersonaContent.calculate_engagement_prediction(@persona, @content)
    
    assert_kind_of Numeric, prediction
    assert prediction >= 0
    assert prediction <= 100
  end

  test "should calculate conversion likelihood" do
    likelihood = PersonaContent.calculate_conversion_likelihood(@persona, @content)
    
    assert_kind_of Numeric, likelihood
    assert likelihood >= 0
    assert likelihood <= 100
  end

  test "should set default metadata on creation" do
    new_content = PersonaContent.new(
      persona: @persona,
      generated_content: generated_contents(:two),
      adaptation_type: 'goal_alignment'
    )
    
    new_content.send(:set_default_metadata)
    
    metadata = new_content.adaptation_metadata
    assert_kind_of Hash, metadata
    assert_includes metadata, 'adaptation_version'
  end

  test "adaptation types constant should be defined" do
    assert_not_empty PersonaContent::ADAPTATION_TYPES
    assert_includes PersonaContent::ADAPTATION_TYPES, 'tone_adaptation'
    assert_includes PersonaContent::ADAPTATION_TYPES, 'length_adaptation'
    assert_includes PersonaContent::ADAPTATION_TYPES, 'channel_optimization'
  end
end
