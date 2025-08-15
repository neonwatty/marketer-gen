require 'test_helper'

class JourneySuggestionServiceTest < ActiveSupport::TestCase
  def setup
    @awareness_service = JourneySuggestionService.new(
      campaign_type: 'awareness',
      template_type: 'social_media',
      current_stage: 'discovery'
    )

    @conversion_service = JourneySuggestionService.new(
      campaign_type: 'conversion',
      template_type: 'email',
      current_stage: 'decision',
      existing_steps: [{ step_type: 'email' }]
    )
  end

  class SuggestStepsTest < JourneySuggestionServiceTest
    test "returns suggestions for awareness campaign" do
      suggestions = @awareness_service.suggest_steps
      
      assert_not_empty suggestions
      assert suggestions.length <= 5
      
      # Check structure of first suggestion
      suggestion = suggestions.first
      assert suggestion.key?(:step_type)
      assert suggestion.key?(:title)
      assert suggestion.key?(:description)
      assert suggestion.key?(:priority)
      assert suggestion.key?(:estimated_effort)
    end

    test "returns suggestions for conversion campaign" do
      suggestions = @conversion_service.suggest_steps
      
      assert_not_empty suggestions
      assert suggestions.length <= 5
      
      # Should suggest conversion-focused steps
      suggested_types = suggestions.map { |s| s[:step_type] }
      conversion_types = %w[landing_page automation]
      assert (suggested_types & conversion_types).any?, 
             "Should suggest conversion-focused step types"
    end

    test "filters out existing step types" do
      # Service initialized with existing email step
      suggestions = @conversion_service.suggest_steps
      
      suggested_types = suggestions.map { |s| s[:step_type] }
      refute_includes suggested_types, 'email', 
                      "Should not suggest already existing step types"
    end

    test "respects limit parameter" do
      suggestions = @awareness_service.suggest_steps(limit: 3)
      
      assert suggestions.length <= 3
    end

    test "returns appropriate suggestions for different campaign types" do
      # Test awareness campaign
      awareness_suggestions = @awareness_service.suggest_steps
      awareness_types = awareness_suggestions.map { |s| s[:step_type] }
      
      # Should include awareness-focused step types
      expected_awareness_types = %w[social_post content_piece email]
      assert (awareness_types & expected_awareness_types).any?
      
      # Test retention campaign
      retention_service = JourneySuggestionService.new(campaign_type: 'retention')
      retention_suggestions = retention_service.suggest_steps
      retention_types = retention_suggestions.map { |s| s[:step_type] }
      
      # Should include retention-focused step types
      expected_retention_types = %w[email content_piece automation]
      assert (retention_types & expected_retention_types).any?
    end

    test "handles unknown campaign type gracefully" do
      unknown_service = JourneySuggestionService.new(campaign_type: 'unknown')
      suggestions = unknown_service.suggest_steps
      
      # Should return empty array for unknown campaign type
      assert_empty suggestions
    end
  end

  class SuggestChannelsForStepTest < JourneySuggestionServiceTest
    test "suggests appropriate channels for email step type" do
      channels = @awareness_service.suggest_channels_for_step('email')
      
      assert_includes channels, 'email'
      assert channels.is_a?(Array)
    end

    test "suggests appropriate channels for social_post step type" do
      channels = @awareness_service.suggest_channels_for_step('social_post')
      
      assert_includes channels, 'social_media'
    end

    test "includes campaign-specific channel recommendations" do
      # Awareness campaign should suggest social media
      channels = @awareness_service.suggest_channels_for_step('content_piece')
      awareness_channels = %w[social_media blog video]
      
      assert (channels & awareness_channels).any?
      
      # Conversion campaign should suggest email and website
      conversion_channels = @conversion_service.suggest_channels_for_step('content_piece')
      expected_conversion_channels = %w[email website]
      
      assert (conversion_channels & expected_conversion_channels).any?
    end

    test "handles unknown step type gracefully" do
      channels = @awareness_service.suggest_channels_for_step('unknown_type')
      
      # Should still return campaign-specific recommendations
      assert channels.is_a?(Array)
      refute_empty channels
    end
  end

  class SuggestContentForStepTest < JourneySuggestionServiceTest
    test "suggests content for email step type" do
      content = @awareness_service.suggest_content_for_step('email', 'discovery')
      
      assert content.key?(:subject_line_ideas)
      assert content.key?(:content_structure)
      assert content.key?(:call_to_action)
      
      assert content[:subject_line_ideas].is_a?(Array)
      assert_not_empty content[:subject_line_ideas]
    end

    test "suggests content for social_post step type" do
      content = @awareness_service.suggest_content_for_step('social_post', 'education')
      
      assert content.key?(:post_types)
      assert content.key?(:hashtag_suggestions)
      assert content.key?(:content_themes)
    end

    test "suggests content for webinar step type" do
      content = @awareness_service.suggest_content_for_step('webinar', 'evaluation')
      
      assert content.key?(:format)
      assert content.key?(:duration)
      assert content.key?(:follow_up_strategy)
    end

    test "returns empty hash for unknown step type" do
      content = @awareness_service.suggest_content_for_step('unknown_type', 'discovery')
      
      assert_empty content
    end
  end

  class StageSpecificSuggestionsTest < JourneySuggestionServiceTest
    test "provides stage-specific suggestions for discovery stage" do
      service = JourneySuggestionService.new(
        campaign_type: 'awareness',
        current_stage: 'discovery'
      )
      
      suggestions = service.suggest_steps
      
      # Should include discovery-focused suggestions
      titles = suggestions.map { |s| s[:title] }
      assert titles.any? { |title| title.include?('Problem') || title.include?('Discovery') }
    end

    test "provides stage-specific suggestions for decision stage" do
      service = JourneySuggestionService.new(
        campaign_type: 'conversion',
        current_stage: 'decision'
      )
      
      suggestions = service.suggest_steps
      
      # Should include decision-focused suggestions
      descriptions = suggestions.map { |s| s[:description] }
      decision_keywords = %w[decision final support reassurance]
      
      assert descriptions.any? { |desc| 
        decision_keywords.any? { |keyword| desc.downcase.include?(keyword) }
      }
    end
  end

  class TemplateSpecificSuggestionsTest < JourneySuggestionServiceTest
    test "provides template-specific suggestions for email template" do
      email_service = JourneySuggestionService.new(
        campaign_type: 'awareness',
        template_type: 'email'
      )
      
      suggestions = email_service.suggest_steps
      
      # Should include email-specific suggestions
      suggested_types = suggestions.map { |s| s[:step_type] }
      assert_includes suggested_types, 'automation'
    end

    test "provides template-specific suggestions for webinar template" do
      webinar_service = JourneySuggestionService.new(
        campaign_type: 'consideration',
        template_type: 'webinar'
      )
      
      suggestions = webinar_service.suggest_steps
      
      # Should include webinar-related suggestions
      suggested_types = suggestions.map { |s| s[:step_type] }
      assert_includes suggested_types, 'landing_page'
    end
  end

  class ContentSuggestionDetailsTest < JourneySuggestionServiceTest
    test "generates appropriate subject lines for different stages" do
      # Test discovery stage
      discovery_content = @awareness_service.suggest_content_for_step('email', 'discovery')
      discovery_subjects = discovery_content[:subject_line_ideas]
      
      assert discovery_subjects.any? { |subject| subject.include?('struggling') || subject.include?('problem') }
      
      # Test decision stage
      decision_content = @conversion_service.suggest_content_for_step('email', 'decision')
      decision_subjects = decision_content[:subject_line_ideas]
      
      assert decision_subjects.any? { |subject| subject.include?('Ready') || subject.include?('next steps') }
    end

    test "generates campaign-specific hashtags" do
      awareness_content = @awareness_service.suggest_content_for_step('social_post', 'discovery')
      awareness_hashtags = awareness_content[:hashtag_suggestions]
      
      assert_includes awareness_hashtags, '#brandawareness'
      
      conversion_content = @conversion_service.suggest_content_for_step('social_post', 'decision')
      conversion_hashtags = conversion_content[:hashtag_suggestions]
      
      assert_includes conversion_hashtags, '#offer'
    end

    test "provides appropriate content length recommendations" do
      education_content = @awareness_service.suggest_content_for_step('content_piece', 'education')
      
      # Education stage should recommend longer content
      assert education_content[:target_length].include?('medium') || education_content[:target_length].include?('long')
      
      decision_content = @conversion_service.suggest_content_for_step('content_piece', 'decision')
      
      # Decision stage should have focused length recommendations
      refute_nil decision_content[:target_length]
    end
  end

  class EdgeCasesTest < JourneySuggestionServiceTest
    test "handles nil values gracefully" do
      service = JourneySuggestionService.new(
        campaign_type: 'awareness',
        template_type: nil,
        current_stage: nil
      )
      
      suggestions = service.suggest_steps
      assert_not_empty suggestions
    end

    test "handles empty existing steps array" do
      service = JourneySuggestionService.new(
        campaign_type: 'awareness',
        existing_steps: []
      )
      
      suggestions = service.suggest_steps
      assert_not_empty suggestions
    end

    test "handles existing steps with string keys" do
      service = JourneySuggestionService.new(
        campaign_type: 'awareness',
        existing_steps: [{ 'step_type' => 'email' }]
      )
      
      suggestions = service.suggest_steps
      suggested_types = suggestions.map { |s| s[:step_type] }
      
      refute_includes suggested_types, 'email'
    end
  end
end