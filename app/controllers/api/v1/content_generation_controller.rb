# frozen_string_literal: true

module Api
  module V1
    # API Controller for LLM-powered content generation
    # Provides RESTful endpoints for different types of content creation
    class ContentGenerationController < ApplicationController
      include LlmServiceHelper
      
      # Skip CSRF token verification for API requests and standard auth  
      skip_before_action :require_authentication
      skip_before_action :verify_authenticity_token
      before_action :validate_request_format
      before_action :authenticate_api_user
      before_action :check_rate_limit, except: [:health]
      
      rescue_from JSON::ParserError, with: :handle_json_parse_error
      rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
      
      # Generate social media content
      # POST /api/v1/content_generation/social_media
      def social_media
        begin
          result = llm_service.generate_social_media_content(social_media_params)
          render json: { success: true, data: result }, status: :ok
        rescue StandardError => e
          handle_generation_error(e, 'social_media')
        end
      end

      # Generate email content
      # POST /api/v1/content_generation/email
      def email
        begin
          result = llm_service.generate_email_content(email_params)
          render json: { success: true, data: result }, status: :ok
        rescue StandardError => e
          handle_generation_error(e, 'email')
        end
      end

      # Generate ad copy
      # POST /api/v1/content_generation/ad_copy
      def ad_copy
        begin
          result = llm_service.generate_ad_copy(ad_copy_params)
          render json: { success: true, data: result }, status: :ok
        rescue StandardError => e
          handle_generation_error(e, 'ad_copy')
        end
      end

      # Generate landing page content
      # POST /api/v1/content_generation/landing_page
      def landing_page
        begin
          result = llm_service.generate_landing_page_content(landing_page_params)
          render json: { success: true, data: result }, status: :ok
        rescue StandardError => e
          handle_generation_error(e, 'landing_page')
        end
      end

      # Generate campaign plan
      # POST /api/v1/content_generation/campaign_plan
      def campaign_plan
        begin
          result = llm_service.generate_campaign_plan(campaign_plan_params)
          render json: { success: true, data: result }, status: :ok
        rescue StandardError => e
          handle_generation_error(e, 'campaign_plan')
        end
      end

      # Generate content variations for A/B testing
      # POST /api/v1/content_generation/variations
      def variations
        begin
          result = llm_service.generate_content_variations(variations_params)
          render json: { success: true, data: result }, status: :ok
        rescue StandardError => e
          handle_generation_error(e, 'variations')
        end
      end

      # Optimize existing content
      # POST /api/v1/content_generation/optimize
      def optimize
        begin
          result = llm_service.optimize_content(optimization_params)
          render json: { success: true, data: result }, status: :ok
        rescue StandardError => e
          handle_generation_error(e, 'optimize')
        end
      end

      # Check brand compliance
      # POST /api/v1/content_generation/brand_compliance
      def brand_compliance
        begin
          result = llm_service.check_brand_compliance(compliance_params)
          render json: { success: true, data: result }, status: :ok
        rescue StandardError => e
          handle_generation_error(e, 'brand_compliance')
        end
      end

      # Generate analytics insights
      # POST /api/v1/content_generation/analytics_insights
      def analytics_insights
        begin
          result = llm_service.generate_analytics_insights(analytics_params)
          render json: { success: true, data: result }, status: :ok
        rescue StandardError => e
          handle_generation_error(e, 'analytics_insights')
        end
      end

      # Health check for LLM service
      # GET /api/v1/content_generation/health
      def health
        begin
          result = llm_service.health_check
          render json: { success: true, data: result }, status: :ok
        rescue StandardError => e
          handle_generation_error(e, 'health_check')
        end
      end

      private

      def check_rate_limit
        begin
          @rate_limiter = ApiRateLimitingService.new(
            platform: 'content_generation_api',
            endpoint: action_name,
            customer_id: current_user.id,
            strategy: :balanced
          )
          
          # Execute rate limit check without actual API call
          @rate_limiter.execute_request { true }
        rescue ApiRateLimitingService::RateLimitExceeded => e
          render json: {
            success: false,
            error: 'Rate limit exceeded',
            message: e.message,
            retry_after: 60
          }, status: :too_many_requests
          return false
        rescue ApiRateLimitingService::QuotaExceeded => e
          render json: {
            success: false,
            error: 'API quota exceeded',
            message: e.message
          }, status: :too_many_requests
          return false
        end
        true
      end

      def authenticate_api_user
        # Use the standard authentication but return JSON error instead of redirect
        unless authenticated?
          render json: { 
            success: false, 
            error: 'Authentication required',
            message: 'Please sign in to access this API' 
          }, status: :unauthorized
          return false
        end
        true
      end

      def validate_request_format
        unless request.format.json?
          render json: { 
            success: false, 
            error: 'Only JSON format is supported',
            message: 'Please set Content-Type: application/json header'
          }, status: :not_acceptable
          return false
        end
        true
      end

      def handle_generation_error(error, operation)
        Rails.logger.error "Content generation error in #{operation}: #{error.message}"
        Rails.logger.error error.backtrace.join("\n") if Rails.env.development?

        error_response = {
          success: false,
          error: 'Content generation failed',
          details: error.message,
          operation: operation
        }

        status = case error
                 when ArgumentError, ActionController::ParameterMissing
                   :bad_request
                 when ActionController::UnpermittedParameters
                   :unprocessable_entity
                 when StandardError
                   :internal_server_error
                 else
                   :internal_server_error
                 end

        render json: error_response, status: status
      end
      
      def handle_json_parse_error(error)
        render json: {
          success: false,
          error: 'Invalid JSON format',
          message: 'Request body contains malformed JSON'
        }, status: :bad_request
      end
      
      def handle_parameter_missing(error)
        render json: {
          success: false,
          error: 'Missing required parameter',
          message: error.message,
          details: 'content_generation parameter is required'
        }, status: :unprocessable_entity
      end

      # Parameter sanitization methods
      def social_media_params
        content_generation_params = params[:content_generation]
        raise ActionController::ParameterMissing.new('content_generation') unless content_generation_params
        
        permitted = content_generation_params.permit(
          :platform, :tone, :topic, :character_limit,
          brand_context: {},
          targeting: {}
        )
        
        permitted[:brand_context] = parse_brand_context if content_generation_params[:brand_context]
        permitted
      end

      def email_params
        content_generation_params = params[:content_generation]
        raise ActionController::ParameterMissing.new('content_generation') unless content_generation_params
        
        permitted = content_generation_params.permit(
          :email_type, :subject, :tone,
          brand_context: {},
          personalization: []
        )
        
        permitted[:brand_context] = parse_brand_context if content_generation_params[:brand_context]
        permitted
      end

      def ad_copy_params
        content_generation_params = params[:content_generation]
        raise ActionController::ParameterMissing.new('content_generation') unless content_generation_params
        
        permitted = content_generation_params.permit(
          :ad_type, :platform, :objective,
          brand_context: {},
          target_audience: {}
        )
        
        permitted[:brand_context] = parse_brand_context if content_generation_params[:brand_context]
        permitted
      end

      def landing_page_params
        params.require(:content_generation).permit(
          :page_type, :objective,
          brand_context: {},
          key_features: []
        ).tap do |permitted|
          permitted[:brand_context] = parse_brand_context if params.dig(:content_generation, :brand_context)
        end
      end

      def campaign_plan_params
        params.require(:content_generation).permit(
          :campaign_type, :objective,
          brand_context: {},
          target_audience: {},
          budget_timeline: {}
        ).tap do |permitted|
          permitted[:brand_context] = parse_brand_context if params.dig(:content_generation, :brand_context)
        end
      end

      def variations_params
        content_generation_params = params[:content_generation]
        raise ActionController::ParameterMissing.new('content_generation') unless content_generation_params
        
        content_generation_params.permit(
          :base_content, :original_content, :content_type, :variant_count,
          platforms: [], variation_strategies: []
        )
      end

      def optimization_params
        params.require(:content_generation).permit(
          :content, :content_type,
          performance_data: {},
          optimization_goals: {}
        )
      end

      def compliance_params
        params.require(:content_generation).permit(
          :content,
          brand_guidelines: {}
        )
      end

      def analytics_params
        params.require(:content_generation).permit(
          :time_period,
          performance_data: {},
          metrics: []
        )
      end

      def parse_brand_context
        brand_context = params.dig(:content_generation, :brand_context)
        return {} unless brand_context

        # Allow nested hashes for brand context
        brand_context.permit!.to_h
      end
    end
  end
end