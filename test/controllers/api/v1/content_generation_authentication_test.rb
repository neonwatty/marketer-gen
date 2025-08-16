# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    class ContentGenerationAuthenticationTest < ActionDispatch::IntegrationTest
      def setup
        @user = users(:one)
      end

      test "should reject requests with expired sessions" do
        expired_session = @user.sessions.create!(
          user_agent: 'test',
          ip_address: '127.0.0.1',
          created_at: 2.days.ago
        )
        
        # Destroy the session to simulate expiration
        expired_session.destroy
        
        post api_v1_social_media_path, params: {
          content_generation: { platform: 'twitter' }
        }, as: :json
        
        assert_response :unauthorized
      end

      test "should handle missing session cookie gracefully" do
        post api_v1_social_media_path, params: {
          content_generation: { platform: 'twitter' }
        }, as: :json
        
        assert_response :unauthorized
        
        json_response = JSON.parse(response.body)
        assert_equal false, json_response['success']
        assert_equal 'Authentication required', json_response['error']
      end

      test "should handle corrupted session cookie" do
        cookies[:session_id] = "corrupted_data"
        
        post api_v1_social_media_path, params: {
          content_generation: { platform: 'twitter' }
        }, as: :json
        
        assert_response :unauthorized
      end

      test "should validate request format before authentication" do
        api_sign_in_as(@user)
        
        post api_v1_social_media_path, params: {
          content_generation: { platform: 'twitter' }
        }
        
        assert_response :not_acceptable
        
        json_response = JSON.parse(response.body)
        assert_equal 'Only JSON format is supported', json_response['error']
      end

      test "should handle session from different user" do
        other_user = users(:two)
        # Use the api_sign_in_as helper for other user
        api_sign_in_as(other_user)
        
        post api_v1_social_media_path, params: {
          content_generation: { platform: 'twitter' }
        }, as: :json
        
        # Should work - any valid session is acceptable for API
        assert_response :success
      end

      test "should handle malformed JSON requests" do
        api_sign_in_as(@user)
        
        # Send malformed JSON
        post api_v1_social_media_path, 
             params: '{"invalid": json}',
             headers: { 'Content-Type' => 'application/json' }
        
        assert_response :bad_request
      end

      test "should require authentication for all endpoints" do
        endpoints = [
          [:post, api_v1_social_media_path, { content_generation: { platform: 'twitter' } }],
          [:post, api_v1_email_path, { content_generation: { email_type: 'promotional' } }],
          [:post, api_v1_ad_copy_path, { content_generation: { ad_type: 'search' } }],
          [:post, api_v1_landing_page_path, { content_generation: { page_type: 'product' } }],
          [:post, api_v1_campaign_plan_path, { content_generation: { campaign_type: 'launch' } }],
          [:post, api_v1_variations_path, { content_generation: { original_content: 'test' } }],
          [:post, api_v1_optimize_path, { content_generation: { content: 'test' } }],
          [:post, api_v1_brand_compliance_path, { content_generation: { content: 'test' } }],
          [:post, api_v1_analytics_insights_path, { content_generation: { time_period: '30_days' } }],
          [:get, api_v1_health_path, {}]
        ]
        
        endpoints.each do |method, path, params|
          send(method, path, params: params, as: :json)
          assert_response :unauthorized, "#{method.upcase} #{path} should require authentication"
        end
      end

      test "should maintain session across multiple requests" do
        api_sign_in_as(@user)
        
        # First request
        post api_v1_social_media_path, params: {
          content_generation: { platform: 'twitter' }
        }, as: :json
        assert_response :success
        
        # Second request with same session
        post api_v1_email_path, params: {
          content_generation: { email_type: 'promotional' }
        }, as: :json
        assert_response :success
      end

      test "should handle concurrent authenticated requests" do
        api_sign_in_as(@user)
        
        # Test concurrent requests using the same session
        5.times do
          get api_v1_health_path, as: :json
          assert_response :success
        end
      end
    end
  end
end