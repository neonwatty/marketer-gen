# frozen_string_literal: true

# Helper module for accessing the LLM service in controllers
# Provides a consistent interface to get the configured LLM service
module LlmServiceHelper
  extend ActiveSupport::Concern

  private

  def llm_service
    @llm_service ||= LlmServiceContainer.get_service
  end
end