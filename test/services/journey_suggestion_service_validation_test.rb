require 'test_helper'

class JourneySuggestionServiceValidationTest < ActiveSupport::TestCase
  test "handles nil campaign_type gracefully" do
    service = JourneySuggestionService.new(campaign_type: nil)
    suggestions = service.suggest_steps
    
    assert suggestions.is_a?(Array)
    assert_empty suggestions
  end

  test "handles empty string campaign_type" do
    service = JourneySuggestionService.new(campaign_type: "")
    suggestions = service.suggest_steps
    
    assert suggestions.is_a?(Array)
    assert_empty suggestions
  end

  test "handles invalid campaign_type values" do
    %w[invalid_type 123 !@#$%].each do |invalid_type|
      service = JourneySuggestionService.new(campaign_type: invalid_type)
      suggestions = service.suggest_steps
      
      assert suggestions.is_a?(Array)
      assert_empty suggestions, "Should return empty array for campaign_type: #{invalid_type}"
    end
  end

  test "handles malformed existing_steps parameter" do
    malformed_steps = [
      nil,
      "invalid",
      { invalid: "data" },
      { step_type: nil },
      { step_type: 123 }
    ]
    
    service = JourneySuggestionService.new(
      campaign_type: 'awareness',
      existing_steps: malformed_steps
    )
    
    assert_nothing_raised do
      suggestions = service.suggest_steps
      assert suggestions.is_a?(Array)
    end
  end

  test "suggest_channels_for_step handles invalid step_type" do
    service = JourneySuggestionService.new(campaign_type: 'awareness')
    
    [nil, "", "invalid_type", 123, {}, []].each do |invalid_step_type|
      channels = service.suggest_channels_for_step(invalid_step_type)
      assert channels.is_a?(Array), "Should return array for step_type: #{invalid_step_type.inspect}"
    end
  end

  test "suggest_content_for_step handles invalid parameters" do
    service = JourneySuggestionService.new(campaign_type: 'awareness')
    
    content = service.suggest_content_for_step(nil, nil)
    assert_empty content
    
    content = service.suggest_content_for_step("", "")
    assert_empty content
    
    content = service.suggest_content_for_step("invalid", "invalid_stage")
    assert_empty content
  end

  test "handles zero and negative limit values" do
    service = JourneySuggestionService.new(campaign_type: 'awareness')
    
    suggestions_zero = service.suggest_steps(limit: 0)
    assert_empty suggestions_zero
    
    suggestions_negative = service.suggest_steps(limit: -1)
    assert_empty suggestions_negative
  end

  test "handles extremely large limit values" do
    service = JourneySuggestionService.new(campaign_type: 'awareness')
    
    suggestions = service.suggest_steps(limit: 1000000)
    assert suggestions.length <= 50, "Should have reasonable upper bound on suggestions"
  end

  test "handles nil template_type gracefully" do
    service = JourneySuggestionService.new(
      campaign_type: 'awareness',
      template_type: nil
    )
    
    suggestions = service.suggest_steps
    assert suggestions.is_a?(Array)
  end

  test "handles invalid template_type values" do
    invalid_templates = ['invalid_template', 123, {}, [], true]
    
    invalid_templates.each do |invalid_template|
      service = JourneySuggestionService.new(
        campaign_type: 'awareness',
        template_type: invalid_template
      )
      
      suggestions = service.suggest_steps
      assert suggestions.is_a?(Array)
    end
  end

  test "handles nil current_stage gracefully" do
    service = JourneySuggestionService.new(
      campaign_type: 'awareness',
      current_stage: nil
    )
    
    suggestions = service.suggest_steps
    assert suggestions.is_a?(Array)
  end

  test "handles invalid current_stage values" do
    invalid_stages = [123, {}, [], true, false]
    
    invalid_stages.each do |invalid_stage|
      service = JourneySuggestionService.new(
        campaign_type: 'awareness',
        current_stage: invalid_stage
      )
      
      suggestions = service.suggest_steps
      assert suggestions.is_a?(Array)
    end
  end

  test "handles existing_steps as non-array values" do
    non_array_values = [nil, "string", 123, {}, true]
    
    non_array_values.each do |non_array|
      service = JourneySuggestionService.new(
        campaign_type: 'awareness',
        existing_steps: non_array
      )
      
      assert_nothing_raised do
        suggestions = service.suggest_steps
        assert suggestions.is_a?(Array)
      end
    end
  end

  test "handles existing_steps with mixed data types" do
    mixed_steps = [
      { step_type: "email" },          # Valid
      { step_type: nil },              # Nil step type
      { 'step_type' => 'social_post' }, # String key
      "invalid",                       # String instead of hash
      123,                             # Number
      nil,                             # Nil element
      {},                              # Empty hash
      { other_field: "value" }         # Missing step_type
    ]
    
    service = JourneySuggestionService.new(
      campaign_type: 'awareness',
      existing_steps: mixed_steps
    )
    
    assert_nothing_raised do
      suggestions = service.suggest_steps
      assert suggestions.is_a?(Array)
    end
  end

  test "suggest_channels_for_step handles unicode and special characters" do
    service = JourneySuggestionService.new(campaign_type: 'awareness')
    
    special_step_types = [
      "émáil",           # Unicode characters
      "step-type",       # Hyphen
      "step_type_123",   # Numbers
      "UPPERCASE",       # Uppercase
      "step type",       # Space
      "step\ntype",      # Newline
      "step\ttype",      # Tab
      "step/type",       # Slash
      "step\\type",      # Backslash
      "step.type"        # Dot
    ]
    
    special_step_types.each do |step_type|
      channels = service.suggest_channels_for_step(step_type)
      assert channels.is_a?(Array), "Should return array for step_type: #{step_type.inspect}"
    end
  end

  test "suggest_content_for_step handles unicode in stage parameter" do
    service = JourneySuggestionService.new(campaign_type: 'awareness')
    
    unicode_stages = [
      "découverte",      # French
      "教育",            # Chinese
      "образование",     # Russian
      "🚀discovery",     # Emoji
      "stage\u0000null"  # Null byte
    ]
    
    unicode_stages.each do |stage|
      content = service.suggest_content_for_step('email', stage)
      assert content.is_a?(Hash), "Should return hash for stage: #{stage.inspect}"
    end
  end

  test "service handles frozen string parameters" do
    frozen_campaign = 'awareness'.freeze
    frozen_template = 'email'.freeze
    frozen_stage = 'discovery'.freeze
    
    service = JourneySuggestionService.new(
      campaign_type: frozen_campaign,
      template_type: frozen_template,
      current_stage: frozen_stage
    )
    
    assert_nothing_raised do
      suggestions = service.suggest_steps
      assert suggestions.is_a?(Array)
    end
  end

  test "service handles very long string parameters" do
    long_string = "a" * 100000
    
    service = JourneySuggestionService.new(
      campaign_type: 'awareness',
      template_type: long_string,
      current_stage: long_string
    )
    
    assert_nothing_raised do
      suggestions = service.suggest_steps
      channels = service.suggest_channels_for_step(long_string)
      content = service.suggest_content_for_step(long_string, long_string)
      
      assert suggestions.is_a?(Array)
      assert channels.is_a?(Array)
      assert content.is_a?(Hash)
    end
  end

  test "service handles deeply nested existing_steps structure" do
    deeply_nested_steps = [
      {
        step_type: 'email',
        nested: {
          deeply: {
            nested: {
              structure: 'value'
            }
          }
        }
      }
    ]
    
    service = JourneySuggestionService.new(
      campaign_type: 'awareness',
      existing_steps: deeply_nested_steps
    )
    
    assert_nothing_raised do
      suggestions = service.suggest_steps
      assert suggestions.is_a?(Array)
    end
  end

  test "service methods return consistent data structures" do
    service = JourneySuggestionService.new(campaign_type: 'awareness')
    
    # Test suggest_steps structure
    suggestions = service.suggest_steps
    assert suggestions.is_a?(Array)
    
    unless suggestions.empty?
      suggestion = suggestions.first
      assert suggestion.is_a?(Hash)
      %i[step_type title description priority estimated_effort].each do |key|
        assert suggestion.key?(key), "Missing key: #{key}"
      end
    end
    
    # Test suggest_channels_for_step structure
    channels = service.suggest_channels_for_step('email')
    assert channels.is_a?(Array)
    channels.each { |channel| assert channel.is_a?(String) }
    
    # Test suggest_content_for_step structure
    content = service.suggest_content_for_step('email', 'discovery')
    assert content.is_a?(Hash)
  end

  test "service handles circular reference in existing_steps" do
    # Create circular reference
    circular_hash = { step_type: 'email' }
    circular_hash[:self_reference] = circular_hash
    
    service = JourneySuggestionService.new(
      campaign_type: 'awareness',
      existing_steps: [circular_hash]
    )
    
    # Should not cause infinite loops or stack overflow
    assert_nothing_raised do
      suggestions = service.suggest_steps
      assert suggestions.is_a?(Array)
    end
  end

  test "service accessor methods return expected values" do
    service = JourneySuggestionService.new(
      campaign_type: 'awareness',
      template_type: 'email',
      current_stage: 'discovery',
      existing_steps: [{ step_type: 'email' }]
    )
    
    assert_equal 'awareness', service.campaign_type
    assert_equal 'email', service.template_type
    assert_equal 'discovery', service.current_stage
    assert_equal [{ step_type: 'email' }], service.existing_steps
  end

  test "service handles modification of existing_steps after initialization" do
    existing_steps = [{ step_type: 'email' }]
    service = JourneySuggestionService.new(
      campaign_type: 'awareness',
      existing_steps: existing_steps
    )
    
    # Modify the original array
    existing_steps << { step_type: 'social_post' }
    
    # Service should not be affected by external modifications
    suggestions = service.suggest_steps
    assert suggestions.is_a?(Array)
  end
end