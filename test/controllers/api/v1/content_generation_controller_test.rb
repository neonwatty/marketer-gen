# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    class ContentGenerationControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:one)
      end

      test "generates social media content successfully" do
        # Sign in by posting to session path
        post session_path, params: { 
          email_address: @user.email_address, 
          password: "password" 
        }
        
        params = {
          content_generation: {
            platform: 'twitter',
            tone: 'professional',
            topic: 'AI marketing',
            character_limit: 280
          }
        }

        post api_v1_social_media_path, params: params, as: :json

        assert_response :success
        
        json_response = JSON.parse(response.body)
        assert json_response['success']
        assert json_response['data']['content'].present?
        assert json_response['data']['metadata']['platform'] == 'twitter'
      end

      test "generates email content successfully" do
        # Sign in by posting to session path
        post session_path, params: { 
          email_address: @user.email_address, 
          password: "password" 
        }
        
        params = {
          content_generation: {
            email_type: 'promotional',
            subject: 'new product launch',
            tone: 'professional'
          }
        }

        post api_v1_email_path, params: params, as: :json

        assert_response :success
        
        json_response = JSON.parse(response.body)
        assert json_response['success']
        assert json_response['data']['subject'].present?
        assert json_response['data']['content'].present?
      end

      test "generates ad copy successfully" do
        # Sign in by posting to session path
        post session_path, params: { 
          email_address: @user.email_address, 
          password: "password" 
        }
        
        params = {
          content_generation: {
            ad_type: 'search',
            platform: 'google',
            objective: 'conversions'
          }
        }

        post api_v1_ad_copy_path, params: params, as: :json

        assert_response :success
        
        json_response = JSON.parse(response.body)
        assert json_response['success']
        assert json_response['data']['headline'].present?
        assert json_response['data']['description'].present?
        assert json_response['data']['call_to_action'].present?
      end

      test "generates landing page content successfully" do
        # Sign in by posting to session path
        post session_path, params: { 
          email_address: @user.email_address, 
          password: "password" 
        }
        
        params = {
          content_generation: {
            page_type: 'product',
            objective: 'conversion',
            key_features: ['Feature 1', 'Feature 2']
          }
        }

        post api_v1_landing_page_path, params: params, as: :json

        assert_response :success
        
        json_response = JSON.parse(response.body)
        assert json_response['success']
        assert json_response['data']['headline'].present?
        assert json_response['data']['body'].present?
      end

      test "generates campaign plan successfully" do
        # Sign in by posting to session path
        post session_path, params: { 
          email_address: @user.email_address, 
          password: "password" 
        }
        
        params = {
          content_generation: {
            campaign_type: 'product_launch',
            objective: 'brand_awareness'
          }
        }

        post api_v1_campaign_plan_path, params: params, as: :json

        assert_response :success
        
        json_response = JSON.parse(response.body)
        assert json_response['success']
        assert json_response['data']['summary'].present?
        assert json_response['data']['strategy'].present?
      end

      test "generates content variations successfully" do
        # Sign in by posting to session path
        post session_path, params: { 
          email_address: @user.email_address, 
          password: "password" 
        }
        
        params = {
          content_generation: {
            original_content: 'Test content',
            content_type: 'social_media',
            variant_count: 3
          }
        }

        post api_v1_variations_path, params: params, as: :json

        assert_response :success
        
        json_response = JSON.parse(response.body)
        assert json_response['success']
        assert_equal 3, json_response['data'].length
      end

      test "optimizes content successfully" do
        # Sign in by posting to session path
        post session_path, params: { 
          email_address: @user.email_address, 
          password: "password" 
        }
        
        params = {
          content_generation: {
            content: 'Original content to optimize',
            content_type: 'email'
          }
        }

        post api_v1_optimize_path, params: params, as: :json

        assert_response :success
        
        json_response = JSON.parse(response.body)
        assert json_response['success']
        assert json_response['data']['optimized_content'].present?
        assert json_response['data']['changes'].present?
      end

      test "checks brand compliance successfully" do
        # Sign in by posting to session path
        post session_path, params: { 
          email_address: @user.email_address, 
          password: "password" 
        }
        
        params = {
          content_generation: {
            content: 'Sample content to check'
          }
        }

        post api_v1_brand_compliance_path, params: params, as: :json

        assert_response :success
        
        json_response = JSON.parse(response.body)
        assert json_response['success']
        assert json_response['data'].key?('compliant')
        assert json_response['data'].key?('issues')
        assert json_response['data'].key?('suggestions')
      end

      test "generates analytics insights successfully" do
        # Sign in by posting to session path
        post session_path, params: { 
          email_address: @user.email_address, 
          password: "password" 
        }
        
        params = {
          content_generation: {
            time_period: '30_days',
            metrics: ['impressions', 'clicks', 'conversions']
          }
        }

        post api_v1_analytics_insights_path, params: params, as: :json

        assert_response :success
        
        json_response = JSON.parse(response.body)
        assert json_response['success']
        assert json_response['data']['insights'].present?
        assert json_response['data']['recommendations'].present?
      end

      test "performs health check successfully" do
        # Sign in by posting to session path
        post session_path, params: { 
          email_address: @user.email_address, 
          password: "password" 
        }
        
        get api_v1_health_path, as: :json

        assert_response :success
        
        json_response = JSON.parse(response.body)
        assert json_response['success']
        assert_equal 'healthy', json_response['data']['status']
      end

      test "requires authentication" do
        sign_out

        post api_v1_social_media_path, params: {
          content_generation: { platform: 'twitter' }
        }, as: :json

        assert_response :unauthorized
        
        json_response = JSON.parse(response.body)
        assert_equal false, json_response['success']
        assert_equal 'Authentication required', json_response['error']
      end

      test "requires JSON format" do
        post api_v1_social_media_path, params: {
          content_generation: { platform: 'twitter' }
        }

        assert_response :not_acceptable
        
        json_response = JSON.parse(response.body)
        assert_equal false, json_response['success']
        assert_equal 'Only JSON format is supported', json_response['error']
      end

      test "handles missing required parameters" do
        # Sign in by posting to session path
        post session_path, params: { 
          email_address: @user.email_address, 
          password: "password" 
        }
        
        post api_v1_social_media_path, params: {}, as: :json

        assert_response :bad_request
        
        json_response = JSON.parse(response.body)
        assert_equal false, json_response['success']
      end

      test "handles LLM service errors gracefully" do
        # Sign in by posting to session path
        post session_path, params: { 
          email_address: @user.email_address, 
          password: "password" 
        }
        
        # Stub the LLM service to raise an error
        MockLlmService.any_instance.stubs(:generate_social_media_content).raises(StandardError, "Service unavailable")

        params = {
          content_generation: {
            platform: 'twitter',
            topic: 'test'
          }
        }

        post api_v1_social_media_path, params: params, as: :json

        assert_response :internal_server_error
        
        json_response = JSON.parse(response.body)
        assert_equal false, json_response['success']
        assert_equal 'Content generation failed', json_response['error']
      end

      test "handles brand context parameters" do
        # Sign in by posting to session path
        post session_path, params: { 
          email_address: @user.email_address, 
          password: "password" 
        }
        
        params = {
          content_generation: {
            platform: 'twitter',
            topic: 'test',
            brand_context: {
              voice: 'professional',
              tone: 'friendly',
              keywords: ['innovation', 'quality']
            }
          }
        }

        post api_v1_social_media_path, params: params, as: :json

        assert_response :success
        
        json_response = JSON.parse(response.body)
        assert json_response['success']
      end

      private

      def sign_out
        # Use the integration test sign out method for proper session handling
        super
      end
    end
  end
end