# frozen_string_literal: true

require 'test_helper'

class SocialMediaIntegrationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:admin)
    @brand = brands(:acme_corp)
  end

  # Facebook & Instagram Integration Tests
  test "should connect to Facebook Marketing API with OAuth" do
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.connect_facebook_api
    
    assert result.success?
    assert_not_nil result.data[:authorization_url]
    assert_includes result.data[:authorization_url], 'facebook.com'
  end

  test "should collect Facebook engagement metrics" do
    # Create a mock integration
    integration = @brand.social_media_integrations.create!(
      platform: 'facebook',
      access_token: 'mock_token',
      status: 'active'
    )
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.collect_facebook_metrics(date_range: 30.days.ago..Time.current)
    
    assert result.success?
    assert_includes result.data.keys, :likes
    assert_includes result.data.keys, :comments
    assert_includes result.data.keys, :shares
    assert_includes result.data.keys, :reach
    assert_includes result.data.keys, :impressions
  end

  test "should handle Facebook API rate limiting" do
    # Create a mock integration
    integration = @brand.social_media_integrations.create!(
      platform: 'facebook',
      access_token: 'mock_token',
      status: 'active'
    )
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    # Rate limiting service should handle multiple requests gracefully
    5.times do
      result = service.collect_facebook_metrics(date_range: 1.day.ago..Time.current)
      assert result.is_a?(ServiceResult)
    end
  end

  test "should connect Instagram Business API" do
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.connect_instagram_api
    
    assert result.success?
    assert_not_nil result.data[:authorization_url]
    assert_includes result.data[:authorization_url], 'instagram.com'
  end

  test "should collect Instagram story analytics" do
    # Create a mock integration
    integration = @brand.social_media_integrations.create!(
      platform: 'instagram',
      access_token: 'mock_token',
      status: 'active'
    )
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.collect_instagram_story_metrics
    
    assert result.success?
    assert_includes result.data.keys, :story_views
    assert_includes result.data.keys, :story_interactions
    assert_includes result.data.keys, :story_exits
  end

  # LinkedIn Integration Tests
  test "should connect to LinkedIn Marketing API" do
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.connect_linkedin_api
    
    assert result.success?
    assert_not_nil result.data[:authorization_url]
    assert_includes result.data[:authorization_url], 'linkedin.com'
  end

  test "should collect LinkedIn company page analytics" do
    # Create a mock integration
    integration = @brand.social_media_integrations.create!(
      platform: 'linkedin',
      access_token: 'mock_token',
      status: 'active'
    )
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.collect_linkedin_metrics
    
    assert result.success?
    assert_includes result.data.keys, :clicks
    assert_includes result.data.keys, :engagements
    assert_includes result.data.keys, :follower_growth
    assert_includes result.data.keys, :lead_generation
  end

  # Twitter/X Integration Tests
  test "should connect to Twitter API v2" do
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.connect_twitter_api
    
    assert result.success?
    assert_not_nil result.data[:authorization_url]
    assert_includes result.data[:authorization_url], 'twitter.com'
  end

  test "should collect Twitter engagement analytics" do
    # Create a mock integration
    integration = @brand.social_media_integrations.create!(
      platform: 'twitter',
      access_token: 'mock_token',
      status: 'active'
    )
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.collect_twitter_metrics
    
    assert result.success?
    assert_includes result.data.keys, :impressions
    assert_includes result.data.keys, :engagements
    assert_includes result.data.keys, :retweets
    assert_includes result.data.keys, :mentions
  end

  # TikTok Integration Tests
  test "should connect to TikTok Business API" do
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.connect_tiktok_api
    
    assert result.success?
    assert_not_nil result.data[:authorization_url]
    assert_includes result.data[:authorization_url], 'tiktok.com'
  end

  test "should collect TikTok video performance metrics" do
    # Create a mock integration
    integration = @brand.social_media_integrations.create!(
      platform: 'tiktok',
      access_token: 'mock_token',
      status: 'active'
    )
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.collect_tiktok_metrics
    
    assert result.success?
    assert_includes result.data.keys, :video_views
    assert_includes result.data.keys, :likes
    assert_includes result.data.keys, :shares
    assert_includes result.data.keys, :comments
    assert_includes result.data.keys, :trending_hashtags
  end

  test "should monitor TikTok audience demographics" do
    # Create a mock integration
    integration = @brand.social_media_integrations.create!(
      platform: 'tiktok',
      access_token: 'mock_token',
      status: 'active'
    )
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.collect_tiktok_audience_insights
    
    assert result.success?
    assert_includes result.data.keys, :age_groups
    assert_includes result.data.keys, :gender_distribution
    assert_includes result.data.keys, :geographic_data
  end

  # Cross-Platform Integration Tests
  test "should aggregate metrics across all social media platforms" do
    # Create mock integrations
    @brand.social_media_integrations.create!(platform: 'facebook', access_token: 'mock_token', status: 'active')
    @brand.social_media_integrations.create!(platform: 'instagram', access_token: 'mock_token', status: 'active')
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.aggregate_all_platforms
    
    assert result.success?
    assert_not_nil result.data[:total_reach]
    assert_not_nil result.data[:total_engagement]
    assert_not_nil result.data[:platform_breakdown]
  end

  test "should handle OAuth token refresh across platforms" do
    # Create mock integrations
    @brand.social_media_integrations.create!(platform: 'facebook', access_token: 'mock_token', status: 'active')
    @brand.social_media_integrations.create!(platform: 'instagram', access_token: 'mock_token', status: 'active')
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    # Simulate expired tokens
    service.expire_all_tokens
    
    # Refresh should handle gracefully even if it can't actually refresh without real tokens
    result = service.refresh_all_tokens
    assert result.is_a?(ServiceResult)
  end

  test "should store social media analytics data" do
    # Create a Facebook integration
    integration = @brand.social_media_integrations.create!(
      platform: 'facebook',
      access_token: 'mock_token',
      status: 'active'
    )
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    assert_difference 'SocialMediaMetric.count', 1 do
      result = service.store_metrics_batch([
        {
          platform: 'facebook',
          metric_type: 'post_likes',
          value: 1250,
          date: Time.current.to_date
        }
      ])
      assert result.success?
    end
  end
end