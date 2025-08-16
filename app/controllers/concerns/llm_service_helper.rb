# frozen_string_literal: true

# Helper module for accessing the LLM service in controllers
# Provides a consistent interface to get the configured LLM service
module LlmServiceHelper
  extend ActiveSupport::Concern

  private

  def llm_service
    service_type = Rails.application.config.llm_service_type
    LlmServiceContainer.get(service_type)
  rescue ArgumentError => e
    Rails.logger.error "LLM Service Error: #{e.message}"
    # Fallback to mock service if configured service is not available
    if service_type != :mock && LlmServiceContainer.registered?(:mock)
      Rails.logger.warn "Falling back to mock LLM service"
      LlmServiceContainer.get(:mock)
    else
      raise e
    end
  end
end