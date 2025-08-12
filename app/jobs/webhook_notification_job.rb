require 'net/http'

class WebhookNotificationJob < ApplicationJob
  queue_as :webhooks
  
  # Configure retries for webhook delivery
  retry_on Timeout::Error, wait: 5.seconds, attempts: 3
  retry_on Faraday::TimeoutError, wait: 5.seconds, attempts: 3
  retry_on Net::HTTPServerException, wait: 30.seconds, attempts: 2
  
  # Discard webhooks that return client errors (4xx)
  discard_on Net::HTTPClientException

  def perform(webhook_url, payload)
    Rails.logger.info "Sending webhook notification to #{webhook_url}"
    
    response = Faraday.post(webhook_url) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['User-Agent'] = 'MarketerGen-Webhooks/1.0'
      req.headers['X-Webhook-Source'] = 'marketer-gen'
      req.body = payload.to_json
      req.options.timeout = 30
      req.options.open_timeout = 10
    end
    
    if response.success?
      Rails.logger.info "Webhook notification sent successfully to #{webhook_url}"
    else
      Rails.logger.error "Webhook notification failed: #{response.status} - #{response.body}"
      raise Net::HTTPServerException, "Webhook failed with status #{response.status}"
    end
    
  rescue Faraday::ConnectionFailed => error
    Rails.logger.error "Webhook connection failed to #{webhook_url}: #{error.message}"
    raise Net::TimeoutError, "Connection failed: #{error.message}"
  rescue => error
    Rails.logger.error "Webhook notification error to #{webhook_url}: #{error.message}"
    raise error
  end
end