class AiServicesController < ApplicationController
  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token
  
  before_action :ensure_context7_available, only: [:documentation_lookup, :batch_documentation_lookup]
  
  # GET /ai_services/status
  # Returns the status of AI services and Context7 integration
  def status
    context7_service = Context7IntegrationService.new
    
    render json: {
      context7: {
        available: context7_service.available?,
        cache_stats: context7_service.cache_stats
      },
      last_query: context7_service.last_query,
      timestamp: Time.current.iso8601
    }
  end

  # POST /ai_services/documentation_lookup
  # Look up documentation for a specific library/framework
  # Parameters:
  #   - library_name: Name of the library (e.g., "rails", "react")
  #   - topic: Optional topic to focus on (e.g., "services", "hooks")
  #   - tokens: Optional maximum tokens (default: 10000)
  #   - with_context: Optional user query for contextualized results
  def documentation_lookup
    library_name = params[:library_name]
    topic = params[:topic]
    tokens = params[:tokens]&.to_i
    user_query = params[:with_context]

    if library_name.blank?
      render json: { error: "library_name parameter is required" }, status: :bad_request
      return
    end

    context7_service = Context7IntegrationService.new

    begin
      if user_query.present?
        result = context7_service.lookup_with_context(library_name, user_query, topic: topic)
      else
        result = context7_service.lookup_documentation(library_name, topic: topic, tokens: tokens)
      end

      if result
        render json: {
          success: true,
          library: library_name,
          topic: topic,
          documentation: result,
          cached: result[:cached] || false,
          timestamp: Time.current.iso8601
        }
      else
        render json: {
          success: false,
          error: "Documentation not found for #{library_name}",
          errors: context7_service.errors
        }, status: :not_found
      end
    rescue => e
      Rails.logger.error "AI Services documentation lookup failed: #{e.message}"
      render json: {
        success: false,
        error: "Documentation lookup failed",
        message: e.message
      }, status: :internal_server_error
    end
  end

  # POST /ai_services/batch_documentation_lookup
  # Look up documentation for multiple libraries at once
  # Parameters:
  #   - libraries: Array of library names
  #   - topic: Optional topic to focus on for all libraries
  def batch_documentation_lookup
    libraries = params[:libraries]
    topic = params[:topic]

    if libraries.blank? || !libraries.is_a?(Array)
      render json: { error: "libraries parameter must be an array of library names" }, status: :bad_request
      return
    end

    context7_service = Context7IntegrationService.new

    begin
      results = context7_service.batch_lookup(libraries, topic: topic)
      
      render json: {
        success: true,
        topic: topic,
        results: results,
        summary: {
          total_libraries: libraries.size,
          successful_lookups: results.count { |_, result| result.present? },
          failed_lookups: results.count { |_, result| result.nil? }
        },
        timestamp: Time.current.iso8601
      }
    rescue => e
      Rails.logger.error "AI Services batch documentation lookup failed: #{e.message}"
      render json: {
        success: false,
        error: "Batch documentation lookup failed",
        message: e.message
      }, status: :internal_server_error
    end
  end

  # POST /ai_services/suggest_libraries
  # Get library suggestions based on technology keywords
  # Parameters:
  #   - keywords: Array of technology keywords
  def suggest_libraries
    keywords = params[:keywords]

    if keywords.blank? || !keywords.is_a?(Array)
      render json: { error: "keywords parameter must be an array of technology keywords" }, status: :bad_request
      return
    end

    context7_service = Context7IntegrationService.new
    suggestions = context7_service.suggest_libraries(keywords)

    render json: {
      success: true,
      keywords: keywords,
      suggestions: suggestions,
      count: suggestions.size,
      timestamp: Time.current.iso8601
    }
  end

  # DELETE /ai_services/clear_cache
  # Clear the Context7 documentation cache
  def clear_cache
    context7_service = Context7IntegrationService.new
    context7_service.clear_cache

    render json: {
      success: true,
      message: "Documentation cache cleared successfully",
      timestamp: Time.current.iso8601
    }
  end

  # GET /ai_services/rate_limit_status
  # Returns the current rate limit status for AI providers
  def rate_limit_status
    begin
      # Get rate limit status for different providers
      provider_status = {}
      
      # Get rate limit status from a sample AI service instance
      ai_service = AiServiceFactory.create(
        provider: :anthropic,
        model: "claude-3-5-sonnet-20241022"
      )
      
      provider_status[:anthropic] = ai_service.rate_limit_status

      render json: {
        success: true,
        providers: provider_status,
        global_settings: {
          rate_limiting_enabled: Rails.application.config.ai_service.rate_limiting_enabled,
          requests_per_minute: Rails.application.config.ai_service.rate_limit_requests_per_minute,
          requests_per_hour: Rails.application.config.ai_service.rate_limit_requests_per_hour,
          requests_per_day: Rails.application.config.ai_service.rate_limit_requests_per_day,
          tokens_per_minute: Rails.application.config.ai_service.rate_limit_tokens_per_minute
        },
        timestamp: Time.current.iso8601
      }
    rescue => e
      Rails.logger.error "Rate limit status check failed: #{e.message}"
      render json: {
        success: false,
        error: "Rate limit status check failed",
        message: e.message
      }, status: :internal_server_error
    end
  end

  # GET /ai_services/cache_statistics
  # Returns detailed cache statistics for AI responses
  def cache_statistics
    begin
      # Get cache statistics from a sample AI service instance
      ai_service = AiServiceFactory.create(
        provider: :anthropic,
        model: "claude-3-5-sonnet-20241022"
      )
      
      cache_stats = ai_service.cache_statistics

      render json: {
        success: true,
        cache_statistics: cache_stats,
        global_settings: {
          caching_enabled: Rails.application.config.ai_service.enable_caching,
          cache_duration: Rails.application.config.ai_service.cache_duration,
          similar_prompts_caching: Rails.application.config.ai_service.cache_similar_prompts,
          similarity_threshold: Rails.application.config.ai_service.cache_similarity_threshold
        },
        timestamp: Time.current.iso8601
      }
    rescue => e
      Rails.logger.error "Cache statistics retrieval failed: #{e.message}"
      render json: {
        success: false,
        error: "Cache statistics retrieval failed",
        message: e.message
      }, status: :internal_server_error
    end
  end

  # DELETE /ai_services/clear_ai_cache
  # Clear the AI response cache
  def clear_ai_cache
    begin
      # Clear AI response cache using a sample service instance
      ai_service = AiServiceFactory.create(
        provider: :anthropic,
        model: "claude-3-5-sonnet-20241022"
      )
      
      cleared_count = ai_service.invalidate_cache

      render json: {
        success: true,
        message: "AI response cache cleared successfully",
        entries_cleared: cleared_count,
        timestamp: Time.current.iso8601
      }
    rescue => e
      Rails.logger.error "AI cache clearing failed: #{e.message}"
      render json: {
        success: false,
        error: "AI cache clearing failed",
        message: e.message
      }, status: :internal_server_error
    end
  end

  private

  def ensure_context7_available
    context7_service = Context7IntegrationService.new
    
    unless context7_service.available?
      render json: {
        success: false,
        error: "Context7 integration is not available",
        message: "Please check the Context7 MCP server configuration"
      }, status: :service_unavailable
    end
  end
end