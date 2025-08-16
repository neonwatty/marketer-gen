# frozen_string_literal: true

require 'test_helper'

class MockLlmServiceTest < ActiveSupport::TestCase
  setup do
    @service = MockLlmService.new
  end

  test "generates social media content" do
    params = {
      platform: 'twitter',
      tone: 'professional',
      topic: 'AI marketing',
      character_limit: 280
    }

    result = @service.generate_social_media_content(params)

    assert result[:content].present?
    assert result[:content].length <= 280
    assert_equal 'twitter', result[:metadata][:platform]
    assert_equal 'professional', result[:metadata][:tone]
    assert_equal 'mock', result[:metadata][:service]
  end

  test "generates email content" do
    params = {
      email_type: 'promotional',
      subject: 'new product launch',
      tone: 'professional'
    }

    result = @service.generate_email_content(params)

    assert result[:subject].present?
    assert result[:content].present?
    assert_equal 'promotional', result[:metadata][:email_type]
    assert_equal 'mock', result[:metadata][:service]
  end

  test "generates ad copy" do
    params = {
      ad_type: 'search',
      platform: 'google',
      objective: 'conversions'
    }

    result = @service.generate_ad_copy(params)

    assert result[:headline].present?
    assert result[:description].present?
    assert result[:call_to_action].present?
    assert_equal 'search', result[:metadata][:ad_type]
    assert_equal 'mock', result[:metadata][:service]
  end

  test "generates landing page content" do
    params = {
      page_type: 'product',
      objective: 'conversion',
      key_features: ['Feature 1', 'Feature 2']
    }

    result = @service.generate_landing_page_content(params)

    assert result[:headline].present?
    assert result[:subheadline].present?
    assert result[:body].present?
    assert result[:cta].present?
    assert result[:body].include?('Feature 1')
    assert_equal 'mock', result[:metadata][:service]
  end

  test "generates campaign plan" do
    params = {
      campaign_type: 'product_launch',
      objective: 'brand_awareness'
    }

    result = @service.generate_campaign_plan(params)

    assert result[:summary].present?
    assert result[:strategy].present?
    assert result[:timeline].present?
    assert result[:assets].present?
    assert_equal 'mock', result[:metadata][:service]
  end

  test "generates content variations" do
    params = {
      original_content: 'Test content',
      content_type: 'social_media',
      variant_count: 3
    }

    result = @service.generate_content_variations(params)

    assert_equal 3, result.length
    result.each_with_index do |variant, index|
      assert variant[:content].present?
      assert_equal index + 1, variant[:variant_number]
      assert variant[:strategy].present?
      assert_equal 'mock', variant[:metadata][:service]
    end
  end

  test "optimizes content" do
    params = {
      content: 'Original content to optimize',
      content_type: 'email'
    }

    result = @service.optimize_content(params)

    assert result[:optimized_content].present?
    assert result[:changes].present?
    assert result[:changes].is_a?(Array)
    assert_equal 'mock', result[:metadata][:service]
  end

  test "checks brand compliance" do
    params = {
      content: 'Sample content to check'
    }

    result = @service.check_brand_compliance(params)

    assert [true, false].include?(result[:compliant])
    assert result[:issues].is_a?(Array)
    assert result[:suggestions].is_a?(Array)
    assert_equal 'mock', result[:metadata][:service]
  end

  test "generates analytics insights" do
    params = {
      time_period: '30_days',
      metrics: ['impressions', 'clicks', 'conversions']
    }

    result = @service.generate_analytics_insights(params)

    assert result[:insights].present?
    assert result[:recommendations].present?
    assert result[:insights].is_a?(Array)
    assert result[:recommendations].is_a?(Array)
    assert_equal 'mock', result[:metadata][:service]
  end

  test "performs health check" do
    result = @service.health_check

    assert_equal 'healthy', result[:status]
    assert result[:response_time].present?
    assert result[:response_time].is_a?(Numeric)
    assert_equal 'mock', result[:metadata][:service]
  end

  test "respects character limits for social media" do
    params = {
      platform: 'twitter',
      topic: 'This is a very long topic that should be truncated if the generated content exceeds the character limit',
      character_limit: 50
    }

    result = @service.generate_social_media_content(params)

    assert result[:content].length <= 50
  end

  test "handles missing parameters gracefully" do
    # Test with minimal parameters
    result = @service.generate_social_media_content({})

    assert result[:content].present?
    assert result[:metadata].present?
    assert_equal 'mock', result[:metadata][:service]
  end
end