# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    class ContentGenerationValidationTest < ActionDispatch::IntegrationTest
      def setup
        @user = users(:one)
        api_sign_in_as(@user)
      end

      test "should validate social media parameters" do
        # Test with oversized character limit
        post api_v1_social_media_path, params: {
          content_generation: {
            platform: 'twitter',
            character_limit: 100000
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert json_response['data']['content'].length <= 100000
      end

      test "should handle invalid platform gracefully" do
        post api_v1_social_media_path, params: {
          content_generation: {
            platform: 'invalid_platform',
            topic: 'test'
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert json_response['data']['metadata']['platform'] == 'invalid_platform'
      end

      test "should handle nested brand context parameters" do
        complex_brand_context = {
          voice: 'innovative',
          keywords: ['tech', 'innovation'],
          style: {
            emoji: false,
            capitalization: 'lowercase'
          },
          guidelines: {
            avoid_words: ['amazing', 'incredible'],
            preferred_terms: ['excellent', 'outstanding']
          }
        }
        
        post api_v1_social_media_path, params: {
          content_generation: {
            platform: 'linkedin',
            topic: 'product launch',
            brand_context: complex_brand_context
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert json_response['data']['metadata']['brand_voice_applied']
      end

      test "should validate array parameters" do
        post api_v1_landing_page_path, params: {
          content_generation: {
            page_type: 'product',
            key_features: ['Feature 1', 'Feature 2', 'Feature 3']
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert_equal 3, json_response['data']['metadata']['feature_count']
      end

      test "should handle empty parameters gracefully" do
        post api_v1_social_media_path, params: {
          content_generation: {
            platform: 'twitter'  # Provide minimal required parameter
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert json_response['data']['content'].present?
      end

      test "should validate email parameters" do
        post api_v1_email_path, params: {
          content_generation: {
            email_type: 'newsletter',
            subject: 'monthly update',
            tone: 'casual',
            personalization: ['first_name', 'company']
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert json_response['data']['subject'].present?
        assert json_response['data']['content'].present?
      end

      test "should handle large text inputs" do
        large_topic = 'A' * 10000
        
        post api_v1_social_media_path, params: {
          content_generation: {
            platform: 'linkedin',
            topic: large_topic
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert json_response['data']['content'].present?
      end

      test "should validate ad copy parameters with target audience" do
        post api_v1_ad_copy_path, params: {
          content_generation: {
            ad_type: 'display',
            platform: 'facebook',
            objective: 'brand_awareness',
            target_audience: {
              age_range: '25-45',
              interests: ['technology', 'innovation'],
              demographics: ['professionals']
            }
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert json_response['data']['headline'].present?
        assert json_response['data']['description'].present?
        assert json_response['data']['call_to_action'].present?
      end

      test "should handle campaign plan with budget and timeline" do
        post api_v1_campaign_plan_path, params: {
          content_generation: {
            campaign_type: 'product_launch',
            objective: 'lead_generation',
            target_audience: {
              segments: ['early_adopters', 'enterprise']
            },
            budget_timeline: {
              total_budget: 50000,
              duration_weeks: 8,
              budget_allocation: {
                'social_media' => 40,
                'email' => 30,
                'content' => 30
              }
            }
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert json_response['data']['summary'].present?
        assert json_response['data']['strategy'].present?
      end

      test "should validate content variations parameters" do
        post api_v1_variations_path, params: {
          content_generation: {
            original_content: 'Original social media post about our new product',
            content_type: 'social_media',
            variant_count: 5,
            variation_strategies: ['tone_shift', 'length_variation', 'cta_change']
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert_equal 5, json_response['data'].length
        
        json_response['data'].each do |variation|
          assert variation['content'].present?
          assert variation['variant_number'].present?
        end
      end

      test "should handle optimization parameters with performance data" do
        post api_v1_optimize_path, params: {
          content_generation: {
            content: 'Current email subject line that needs improvement',
            content_type: 'email_subject',
            performance_data: {
              open_rate: 0.15,
              click_rate: 0.03,
              conversion_rate: 0.01
            },
            optimization_goals: {
              target_open_rate: 0.25,
              target_click_rate: 0.05
            }
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert json_response['data']['optimized_content'].present?
        assert json_response['data']['changes'].present?
      end

      test "should validate brand compliance parameters" do
        post api_v1_brand_compliance_path, params: {
          content_generation: {
            content: 'Check this content for brand compliance issues',
            brand_guidelines: {
              voice: 'professional',
              prohibited_words: ['awesome', 'amazing'],
              required_elements: ['call_to_action'],
              tone_requirements: ['formal', 'trustworthy']
            }
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert json_response['data'].key?('compliant')
        assert json_response['data'].key?('issues')
        assert json_response['data'].key?('suggestions')
      end

      test "should handle analytics insights with metrics" do
        post api_v1_analytics_insights_path, params: {
          content_generation: {
            time_period: '90_days',
            performance_data: {
              campaigns: [
                { name: 'Campaign A', impressions: 10000, clicks: 500, conversions: 25 },
                { name: 'Campaign B', impressions: 8000, clicks: 400, conversions: 30 }
              ]
            },
            metrics: ['impressions', 'clicks', 'conversions', 'ctr', 'conversion_rate']
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert json_response['data']['insights'].present?
        assert json_response['data']['recommendations'].present?
      end

      test "should handle special characters in content" do
        special_content = "Content with émojis 🚀, spëcial chars & symbols @#$%"
        
        post api_v1_brand_compliance_path, params: {
          content_generation: {
            content: special_content
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        assert json_response['success']
      end

      test "should validate maximum variant count" do
        post api_v1_variations_path, params: {
          content_generation: {
            original_content: 'Test content',
            content_type: 'social_media',
            variant_count: 15  # Over the max of 10
          }
        }, as: :json
        
        assert_response :success
        json_response = JSON.parse(response.body)
        # Should be capped at 10
        assert json_response['data'].length <= 10
      end
    end
  end
end