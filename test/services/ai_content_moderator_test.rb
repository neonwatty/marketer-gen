require "test_helper"

class AiContentModeratorTest < ActiveSupport::TestCase
  def setup
    @moderator = AiContentModerator.new
  end

  # Configuration tests
  test "should initialize with default settings" do
    moderator = AiContentModerator.new
    assert_equal AiContentModerator::MODERATION_CATEGORIES, moderator.enabled_categories
    assert_equal 'medium', moderator.strictness_level
    assert_equal 80, moderator.auto_block_threshold
    assert_equal 60, moderator.flag_threshold
    assert_equal true, moderator.redact_personal_info
  end

  test "should validate configuration on initialization" do
    assert_nothing_raised do
      AiContentModerator.new(enabled_categories: ['profanity', 'spam'])
    end

    assert_raises AiContentModerator::InvalidConfigurationError do
      AiContentModerator.new(enabled_categories: ['invalid_category'])
    end

    assert_raises AiContentModerator::InvalidConfigurationError do
      AiContentModerator.new(strictness_level: 'invalid_level')
    end

    assert_raises AiContentModerator::InvalidConfigurationError do
      AiContentModerator.new(auto_block_threshold: 50, flag_threshold: 70)  # Invalid: block < flag
    end
  end

  # Profanity detection tests
  test "should detect profanity in content" do
    moderator = AiContentModerator.new(enabled_categories: ['profanity'])
    
    profane_content = "This is damn annoying and shit quality content"
    result = moderator.moderate(profane_content)

    assert result[:moderation_results].any? { |r| r[:category] == 'profanity' }
    profanity_result = result[:moderation_results].find { |r| r[:category] == 'profanity' }
    assert profanity_result[:matches].length > 0
    assert ['flag', 'block'].include?(profanity_result[:action])
  end

  test "should not flag clean content for profanity" do
    moderator = AiContentModerator.new(enabled_categories: ['profanity'])
    
    clean_content = "This is a wonderful product that brings joy and happiness to customers"
    result = moderator.moderate(clean_content)

    profanity_results = result[:moderation_results].select { |r| r[:category] == 'profanity' }
    assert profanity_results.empty?
  end

  test "should redact profanity when enabled" do
    moderator = AiContentModerator.new(
      enabled_categories: ['profanity'],
      redact_personal_info: true
    )
    
    profane_content = "This damn product is shit quality"
    result = moderator.moderate(profane_content)

    filtered_content = moderator.filtered_content
    refute_equal profane_content, filtered_content
    assert_includes filtered_content, 'd***'  # Redacted version
  end

  # Spam detection tests
  test "should detect spam patterns" do
    moderator = AiContentModerator.new(enabled_categories: ['spam'])
    
    spam_content = <<~TEXT
      BUY NOW!!! LIMITED TIME ONLY!!! 100% GUARANTEED!!! 
      FREE MONEY!!! CLICK HERE!!! ACT NOW!!! DON'T WAIT!!!
      URGENT!!! CALL NOW!!!
    TEXT

    result = moderator.moderate(spam_content)

    spam_result = result[:moderation_results].find { |r| r[:category] == 'spam' }
    assert spam_result
    assert spam_result[:confidence] > 50
    assert ['flag', 'block'].include?(spam_result[:action])
    assert_includes spam_result[:message], 'spam indicators'
  end

  test "should not flag normal promotional content as spam" do
    moderator = AiContentModerator.new(enabled_categories: ['spam'])
    
    normal_content = "Take advantage of our seasonal sale with 20% off selected items. Visit our website to learn more."
    result = moderator.moderate(normal_content)

    spam_results = result[:moderation_results].select { |r| r[:category] == 'spam' }
    assert spam_results.empty?
  end

  test "should detect excessive word repetition as spam" do
    moderator = AiContentModerator.new(enabled_categories: ['spam'])
    
    repetitive_content = "buy buy buy buy buy buy buy now now now now now excellent excellent excellent product product product"
    result = moderator.moderate(repetitive_content)

    spam_result = result[:moderation_results].find { |r| r[:category] == 'spam' }
    assert spam_result
    assert_includes spam_result[:message], 'repetition'
  end

  # Adult content detection tests
  test "should detect adult content" do
    moderator = AiContentModerator.new(enabled_categories: ['adult_content'])
    
    adult_content = "Sexy singles are looking for nude dating in your area"
    result = moderator.moderate(adult_content)

    adult_result = result[:moderation_results].find { |r| r[:category] == 'adult_content' }
    assert adult_result
    assert adult_result[:confidence] > 50
    assert ['flag', 'block'].include?(adult_result[:action])
  end

  test "should detect gambling content as adult content" do
    moderator = AiContentModerator.new(enabled_categories: ['adult_content'])
    
    gambling_content = "Join our online casino and poker games to win big at the lottery"
    result = moderator.moderate(gambling_content)

    adult_result = result[:moderation_results].find { |r| r[:category] == 'adult_content' }
    assert adult_result
    assert adult_result[:matches].length > 0
  end

  # Violence detection tests
  test "should detect violent content" do
    moderator = AiContentModerator.new(enabled_categories: ['violence'])
    
    violent_content = "The weapon will kill and destroy all enemies in battle"
    result = moderator.moderate(violent_content)

    violence_result = result[:moderation_results].find { |r| r[:category] == 'violence' }
    assert violence_result
    assert violence_result[:confidence] > 50
    assert ['flag', 'block'].include?(violence_result[:action])
  end

  test "should not flag mild competitive language as violence" do
    moderator = AiContentModerator.new(enabled_categories: ['violence'])
    
    competitive_content = "Our team fights for excellence and wins through determination"
    result = moderator.moderate(competitive_content)

    # Might detect due to "fights" but should have low confidence
    violence_results = result[:moderation_results].select { |r| r[:category] == 'violence' }
    if violence_results.any?
      violence_result = violence_results.first
      assert violence_result[:confidence] < 70  # Should be low confidence
    end
  end

  # Personal information detection tests
  test "should detect and redact personal information" do
    moderator = AiContentModerator.new(
      enabled_categories: ['personal_info'],
      redact_personal_info: true
    )
    
    pii_content = "Contact John at john.doe@email.com or call 555-123-4567. His SSN is 123-45-6789."
    result = moderator.moderate(pii_content)

    pii_result = result[:moderation_results].find { |r| r[:category] == 'personal_info' }
    assert pii_result
    assert pii_result[:redaction_applied]
    
    filtered_content = moderator.filtered_content
    refute_equal pii_content, filtered_content
    assert_includes filtered_content, '[Email REDACTED]'
    assert_includes filtered_content, '[Phone Number REDACTED]'
    assert_includes filtered_content, '[SSN REDACTED]'
  end

  test "should detect various types of PII" do
    moderator = AiContentModerator.new(enabled_categories: ['personal_info'])
    
    various_pii = <<~TEXT
      Email me at test@example.com or call 555-123-4567.
      My credit card is 1234-5678-9012-3456.
      I live at 123 Main Street, Anytown.
      My SSN is 987-65-4321.
    TEXT

    result = moderator.moderate(various_pii)

    pii_result = result[:moderation_results].find { |r| r[:category] == 'personal_info' }
    assert pii_result
    
    pii_types = pii_result[:matches].map { |match| match[:type] }
    assert_includes pii_types, 'Email'
    assert_includes pii_types, 'Phone Number'
    assert_includes pii_types, 'Credit Card'
    assert_includes pii_types, 'Address'
    assert_includes pii_types, 'SSN'
  end

  # Custom term filtering tests
  test "should block custom blocked terms" do
    moderator = AiContentModerator.new(
      custom_blocked_terms: ['competitor', 'inferior', 'lawsuit']
    )
    
    blocked_content = "Our competitor has inferior products and faces lawsuit issues"
    result = moderator.moderate(blocked_content)

    custom_blocked_result = result[:moderation_results].find { |r| r[:category] == 'custom_blocked' }
    assert custom_blocked_result
    assert_equal 'block', custom_blocked_result[:action]
    assert custom_blocked_result[:matches].length > 0
  end

  test "should flag custom flagged terms" do
    moderator = AiContentModerator.new(
      custom_flagged_terms: ['budget', 'deadline', 'urgent']
    )
    
    flagged_content = "This urgent project has budget constraints and tight deadline"
    result = moderator.moderate(flagged_content)

    custom_flagged_result = result[:moderation_results].find { |r| r[:category] == 'custom_flagged' }
    assert custom_flagged_result
    assert_equal 'flag', custom_flagged_result[:action]
    assert custom_flagged_result[:matches].length > 0
  end

  # Whitelist protection tests
  test "should protect whitelisted terms from moderation" do
    moderator = AiContentModerator.new(
      enabled_categories: ['profanity'],
      whitelist_terms: ['hell', 'damn'],  # Normally flagged as profanity
      custom_blocked_terms: ['hell']
    )
    
    whitelisted_content = "This damn good product is heaven, not hell on earth"
    result = moderator.moderate(whitelisted_content)

    # Should reduce confidence or prevent flagging of whitelisted terms
    results_with_whitelist = result[:moderation_results].select { |r| r[:whitelist_protected] }
    assert results_with_whitelist.any?
  end

  # Strictness level tests
  test "should apply different strictness levels correctly" do
    low_strictness = AiContentModerator.new(strictness_level: 'low')
    high_strictness = AiContentModerator.new(strictness_level: 'high')
    
    borderline_content = "This content has some damn issues but might be acceptable"
    
    low_result = low_strictness.moderate(borderline_content)
    high_result = high_strictness.moderate(borderline_content)

    # High strictness should be more likely to flag or block
    assert low_result[:overall_risk_score] <= high_result[:overall_risk_score]
  end

  # Overall risk scoring tests
  test "should calculate overall risk score correctly" do
    moderator = AiContentModerator.new(
      enabled_categories: ['profanity', 'spam', 'adult_content']
    )
    
    risky_content = "This damn sexy content is FREE!!! BUY NOW!!!"
    result = moderator.moderate(risky_content)

    assert moderator.overall_risk_score > 0
    assert moderator.overall_risk_score <= 100
  end

  test "should determine blocking based on risk score" do
    moderator = AiContentModerator.new(auto_block_threshold: 50)
    
    high_risk_content = "This damn shit content has sexy nude gambling content BUY NOW!!!"
    result = moderator.moderate(high_risk_content)

    # Should be blocked due to high risk
    assert moderator.blocked?
    assert_equal 'block', result[:overall_action]
  end

  test "should determine flagging based on risk score" do
    moderator = AiContentModerator.new(
      flag_threshold: 30,
      auto_block_threshold: 90
    )
    
    moderate_risk_content = "This content is damn annoying but not terrible"
    result = moderator.moderate(moderate_risk_content)

    # Should be flagged but not blocked
    assert moderator.flagged?
    refute moderator.blocked?
    assert_equal 'flag', result[:overall_action]
  end

  # Batch moderation tests
  test "should moderate batch content correctly" do
    contents = [
      "Clean professional content",
      "This damn content has profanity",
      "BUY NOW!!! FREE MONEY!!! URGENT!!!"
    ]

    results = contents.map { |content| @moderator.moderate(content) }

    assert_equal 3, results.length
    assert_equal 'allow', results[0][:overall_action]
    assert ['flag', 'block'].include?(results[1][:overall_action])
    assert ['flag', 'block'].include?(results[2][:overall_action])
  end

  # Content modification tests
  test "should preserve original content when no modifications needed" do
    moderator = AiContentModerator.new(enabled_categories: ['profanity'])
    
    clean_content = "This is perfectly clean and professional content"
    result = moderator.moderate(clean_content)

    assert_equal clean_content, moderator.filtered_content
    refute result[:content_modified]
  end

  test "should modify content when redactions applied" do
    moderator = AiContentModerator.new(
      enabled_categories: ['personal_info'],
      redact_personal_info: true
    )
    
    pii_content = "Contact me at test@example.com for more information"
    result = moderator.moderate(pii_content)

    refute_equal pii_content, moderator.filtered_content
    assert result[:content_modified]
  end

  # Moderation summary tests
  test "should provide comprehensive moderation summary" do
    moderator = AiContentModerator.new
    
    mixed_content = "This damn product costs $500. Email me at test@example.com. BUY NOW!!!"
    result = moderator.moderate(mixed_content)
    
    summary = moderator.moderation_summary

    assert summary.key?(:overall_action)
    assert summary.key?(:overall_risk_score)
    assert summary.key?(:blocked)
    assert summary.key?(:flagged)
    assert summary.key?(:categories_flagged)
    assert summary.key?(:total_issues)
    assert summary.key?(:content_modified)
    assert summary.key?(:moderation_results)
    assert summary.key?(:timestamp)
  end

  # Error handling tests
  test "should handle empty content gracefully" do
    result = @moderator.moderate("")

    assert_equal 'error', result[:overall_action]
    assert result[:error]
  end

  test "should handle nil content gracefully" do
    result = @moderator.moderate(nil)

    assert_equal 'error', result[:overall_action]
    assert result[:error]
  end

  test "should handle moderation errors gracefully" do
    # This should not raise an exception even with problematic content
    assert_nothing_raised do
      @moderator.moderate("Content with unicode: 🎉💖✨ and special chars: @#$%^&*()")
    end
  end

  test "should handle moderation check failures" do
    # Simulate an error by using invalid configuration that might cause issues internally
    moderator = AiContentModerator.new(enabled_categories: ['profanity'])
    
    # Even if internal checks fail, should not crash
    result = moderator.moderate("test content")
    
    # Should either succeed or fail gracefully with error results
    assert result.is_a?(Hash)
    assert result.key?(:overall_action)
  end

  # Edge cases tests
  test "should handle very long content" do
    long_content = "This is a test sentence. " * 1000  # Very long content
    
    assert_nothing_raised do
      result = @moderator.moderate(long_content)
      assert result.is_a?(Hash)
    end
  end

  test "should handle content with special characters" do
    special_content = "Content with émojis 🎉, àccents, and spëcial chars: @#$%^&*()[]{}|\\:;\"'<>,.?/~`"
    
    assert_nothing_raised do
      result = @moderator.moderate(special_content)
      assert result.is_a?(Hash)
    end
  end

  test "should handle multilingual content gracefully" do
    multilingual_content = "Hello world. Bonjour monde. Hola mundo. こんにちは世界。"
    
    assert_nothing_raised do
      result = @moderator.moderate(multilingual_content)
      assert result.is_a?(Hash)
    end
  end

  # Configuration edge cases
  test "should handle empty custom terms lists" do
    moderator = AiContentModerator.new(
      custom_blocked_terms: [],
      custom_flagged_terms: [],
      whitelist_terms: []
    )
    
    assert_nothing_raised do
      result = moderator.moderate("test content")
      assert result.is_a?(Hash)
    end
  end

  test "should handle extreme threshold values" do
    # Very low thresholds
    strict_moderator = AiContentModerator.new(
      flag_threshold: 1,
      auto_block_threshold: 2
    )
    
    # Very high thresholds  
    lenient_moderator = AiContentModerator.new(
      flag_threshold: 99,
      auto_block_threshold: 100
    )
    
    test_content = "This content might have some issues"
    
    assert_nothing_raised do
      strict_result = strict_moderator.moderate(test_content)
      lenient_result = lenient_moderator.moderate(test_content)
      
      assert strict_result.is_a?(Hash)
      assert lenient_result.is_a?(Hash)
    end
  end

  private

  def sample_clean_content
    "Our professional services help businesses grow through innovative solutions and excellent customer support."
  end

  def sample_problematic_content
    "This damn product is shit quality. Contact us at test@example.com or call 555-123-4567. BUY NOW!!! FREE MONEY!!! Sexy singles in your area want to meet you!"
  end

  def sample_borderline_content
    "This product might have some issues but could be acceptable with minor improvements."
  end
end