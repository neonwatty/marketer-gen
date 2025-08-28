# frozen_string_literal: true

require 'net/http'

class WebhookProcessingJob < ApplicationJob
  queue_as :webhooks

  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  retry_on Timeout::Error, wait: 10.seconds, attempts: 5
  discard_on ActiveJob::DeserializationError
  discard_on ArgumentError

  def perform(payload, headers = {}, source_platform = nil)
    log_webhook_processing(payload, headers, source_platform)
    
    # Process webhook through service
    result = WebhookProcessingService.call(
      payload: payload,
      headers: headers,
      source_platform: source_platform
    )
    
    if result[:success]
      Rails.logger.info "Webhook processed successfully: #{result[:data]}"
      audit_log_success(payload, result[:data])
    else
      Rails.logger.error "Webhook processing failed: #{result[:error]}"
      audit_log_failure(payload, result[:error])
      raise StandardError, "Webhook processing failed: #{result[:error]}"
    end
  end

  private

  def log_webhook_processing(payload, headers, source_platform)
    Rails.logger.info "Processing webhook from #{source_platform || 'unknown'}"
    Rails.logger.debug "Webhook headers: #{headers.inspect}" if headers.present?
    Rails.logger.debug "Webhook payload size: #{payload.to_s.bytesize} bytes"
  end

  def audit_log_success(payload, data)
    # Create comprehensive audit log entry
    audit_entry = {
      event_type: 'webhook_processed',
      status: 'success',
      payload_hash: Digest::SHA256.hexdigest(payload.to_json),
      processed_at: Time.current,
      result_summary: data
    }
    
    Rails.logger.info "Webhook Audit Success: #{audit_entry}"
  end

  def audit_log_failure(payload, error_message)
    # Create comprehensive audit log entry for failures
    audit_entry = {
      event_type: 'webhook_failed',
      status: 'failed',
      payload_hash: Digest::SHA256.hexdigest(payload.to_json),
      failed_at: Time.current,
      error_message: error_message,
      retry_count: executions
    }
    
    Rails.logger.error "Webhook Audit Failure: #{audit_entry}"
  end
end