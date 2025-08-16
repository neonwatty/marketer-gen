# frozen_string_literal: true

module Api
  module V1
    # API Controller for LLM-powered content generation
    # Provides RESTful endpoints for different types of content creation
    class ContentGenerationController < ApplicationController
      include LlmServiceHelper
      
      # Skip the normal authentication and use API-specific authentication
      skip_before_action :require_authentication
      skip_before_action :verify_authenticity_token
      before_action :authenticate_api_user
      before_action :validate_request_format
      
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

      def authenticate_api_user
        # For API requests, check session cookie or implement token-based auth later
        unless resume_session
          render json: { 
            success: false, 
            error: 'Authentication required',
            message: 'Please sign in to access this API' 
          }, status: :unauthorized
          return false
        end
        true
      end

      def resume_session
        # Simplified session resumption for API - reuse existing logic
        Current.session ||= find_session_by_cookie
        Current.session&.active? || false
      end

      def find_session_by_cookie
        return nil unless cookies.signed[:session_id]
        
        session = Session.find_by(id: cookies.signed[:session_id])
        return nil unless session&.active?
        
        session
      end

      def validate_request_format
        unless request.format.json?
          render json: { 
            success: false, 
            error: 'Only JSON format is supported' 
          }, status: :not_acceptable
        end
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
                 when StandardError
                   :internal_server_error
                 else
                   :internal_server_error
                 end

        render json: error_response, status: status
      end

      # Parameter sanitization methods
      def social_media_params
        params.require(:content_generation).permit(
          :platform, :tone, :topic, :character_limit,
          brand_context: {},
          targeting: {}
        ).tap do |permitted|
          permitted[:brand_context] = parse_brand_context if params.dig(:content_generation, :brand_context)
        end
      end

      def email_params
        params.require(:content_generation).permit(
          :email_type, :subject, :tone,
          brand_context: {},
          personalization: []
        ).tap do |permitted|
          permitted[:brand_context] = parse_brand_context if params.dig(:content_generation, :brand_context)
        end
      end

      def ad_copy_params
        params.require(:content_generation).permit(
          :ad_type, :platform, :objective,
          brand_context: {},
          target_audience: {}
        ).tap do |permitted|
          permitted[:brand_context] = parse_brand_context if params.dig(:content_generation, :brand_context)
        end
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
        params.require(:content_generation).permit(
          :original_content, :content_type, :variant_count,
          variation_strategies: []
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