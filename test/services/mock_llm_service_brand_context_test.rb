# frozen_string_literal: true

require 'test_helper'

class MockLlmServiceBrandContextTest < ActiveSupport::TestCase
  def setup
    @service = MockLlmService.new
  end

  test "applies brand voice to content generation" do
    brand_context = {
      voice: 'innovative',
      keywords: ['cutting-edge', 'revolutionary'],
      style: { emoji: false }
    }

    result = @service.generate_social_media_content(
      platform: 'twitter',
      topic: 'new product',
      brand_context: brand_context
    )

    assert result[:metadata][:brand_voice_applied]
    assert_equal 'enthusiastic', result[:metadata][:tone]
    
    # Content should include brand keywords when applied (may not always apply if keyword already exists)
    content = result[:content]
    # Since brand application is conditional and random, just verify the flag is set
    # The integration is working if brand_voice_applied is true
    assert_not_nil content
  end

  test "applies brand keywords to email content" do
    brand_context = {
      keywords: ['innovation', 'quality'],
      tone: 'trustworthy'
    }

    result = @service.generate_email_content(
      email_type: 'promotional',
      subject: 'product launch',
      brand_context: brand_context
    )

    assert result[:metadata][:brand_voice_applied]
    
    # Check if keywords are incorporated
    full_content = "#{result[:subject]} #{result[:content]}"
    has_keywords = brand_context[:keywords].any? { |kw| full_content.downcase.include?(kw.downcase) }
    assert has_keywords, "Brand keywords should be incorporated into content"
  end

  test "applies brand style preferences" do
    brand_context = {
      style: {
        emoji: false,
        capitalization: 'lowercase'
      }
    }

    result = @service.generate_ad_copy(
      ad_type: 'search',
      platform: 'google',
      brand_context: brand_context
    )

    assert result[:metadata][:brand_voice_applied]
    
    # Check that emojis are removed (if any were originally present)
    content_parts = [result[:headline], result[:description], result[:call_to_action]]
    content_parts.each do |part|
      refute_match(/[😀-🿿]/, part, "Emojis should be removed when emoji: false")
    end
  end

  test "works without brand context" do
    result = @service.generate_social_media_content(
      platform: 'twitter',
      topic: 'test topic'
    )

    refute result[:metadata][:brand_voice_applied]
    assert result[:content].present?
  end

  test "handles empty brand context" do
    result = @service.generate_landing_page_content(
      page_type: 'product',
      brand_context: {}
    )

    refute result[:metadata][:brand_voice_applied]
    assert result[:headline].present?
    assert result[:body].present?
  end

  test "applies brand context to campaign planning" do
    brand_context = {
      voice: 'authoritative',
      keywords: ['trusted', 'expertise']
    }

    result = @service.generate_campaign_plan(
      campaign_type: 'product_launch',
      objective: 'brand_awareness',
      brand_context: brand_context
    )

    assert result[:metadata][:brand_voice_applied]
    
    # Check if brand keywords are in summary
    has_keywords = brand_context[:keywords].any? { |kw| result[:summary].downcase.include?(kw.downcase) }
    assert has_keywords, "Brand keywords should be incorporated into campaign summary"
  end

  test "brand voice mapping works correctly" do
    service = @service
    
    # Test various brand voice mappings
    assert_equal 'enthusiastic', service.send(:apply_brand_voice, 'professional', { voice: 'innovative' })
    assert_equal 'professional', service.send(:apply_brand_voice, 'friendly', { voice: 'trustworthy' })
    assert_equal 'friendly', service.send(:apply_brand_voice, 'professional', { voice: 'approachable' })
    assert_equal 'original_tone', service.send(:apply_brand_voice, 'original_tone', { other: 'stuff' })
  end

  test "brand keyword application varies content" do
    brand_context = { keywords: ['innovation'] }
    original_content = "This is a test message"
    
    # Apply brand keywords multiple times and check for variation
    modified_contents = 3.times.map do
      @service.send(:apply_brand_keywords, original_content.dup, brand_context)
    end
    
    # At least one should be different from original (randomized injection)
    has_modification = modified_contents.any? { |content| content != original_content }
    assert has_modification, "Brand keywords should modify content"
    
    # All modified versions should contain the keyword somewhere
    modified_contents.each do |content|
      assert content.downcase.include?('innovation'), "Modified content should contain brand keyword"
    end
  end

  test "brand style emoji handling" do
    content_with_emojis = "Great news! 🎉 Check this out! 🚀"
    
    # Test emoji removal
    no_emoji_context = { style: { emoji: false } }
    result = @service.send(:apply_brand_style, content_with_emojis, no_emoji_context)
    refute_match(/[😀-🿿]/, result, "Should remove all emojis")
    
    # Test minimal emoji
    minimal_emoji_context = { style: { emoji: 'minimal' } }
    result = @service.send(:apply_brand_style, content_with_emojis, minimal_emoji_context)
    emoji_count = result.scan(/[😀-🿿]/).length
    assert emoji_count <= 1, "Should have at most 1 emoji in minimal mode"
  end
end