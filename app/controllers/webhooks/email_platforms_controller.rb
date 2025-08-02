# frozen_string_literal: true

module Webhooks
  class EmailPlatformsController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!, if: :devise_configured?

    before_action :find_integration
    before_action :verify_webhook_signature
    before_action :parse_webhook_payload

    # Handle webhooks from all email marketing platforms
    def receive
      case @integration.platform
      when "mailchimp"
        handle_mailchimp_webhook
      when "sendgrid"
        handle_sendgrid_webhook
      when "constant_contact"
        handle_constant_contact_webhook
      when "campaign_monitor"
        handle_campaign_monitor_webhook
      when "activecampaign"
        handle_activecampaign_webhook
      when "klaviyo"
        handle_klaviyo_webhook
      else
        head :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "Webhook processing error for #{@integration.platform}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      head :internal_server_error
    end

    private

    def find_integration
      @integration = EmailIntegration.find_by(
        id: params[:integration_id],
        platform: params[:platform]
      )

      head :not_found unless @integration
    end

    def verify_webhook_signature
      return head :unauthorized unless @integration

      payload = request.raw_post
      signature = extract_signature_from_headers
      timestamp = extract_timestamp_from_headers

      unless @integration.verify_webhook_signature(payload, signature, timestamp)
        Rails.logger.warn "Invalid webhook signature for integration #{@integration.id}"
        head :unauthorized
      end
    end

    def parse_webhook_payload
      @payload = JSON.parse(request.raw_post)
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in webhook payload: #{e.message}"
      head :bad_request
    end

    def extract_signature_from_headers
      case @integration.platform
      when "mailchimp"
        request.headers["X-Mailchimp-Signature"]
      when "sendgrid"
        request.headers["X-Twilio-Email-Event-Webhook-Signature"]
      when "constant_contact"
        request.headers["X-Constant-Contact-Signature"]
      when "campaign_monitor"
        request.headers["X-CS-Signature"]
      when "activecampaign"
        request.headers["X-AC-Signature"]
      when "klaviyo"
        request.headers["X-Klaviyo-Signature"]
      end
    end

    def extract_timestamp_from_headers
      case @integration.platform
      when "sendgrid"
        request.headers["X-Twilio-Email-Event-Webhook-Timestamp"]
      when "activecampaign"
        request.headers["X-AC-Timestamp"]
      when "klaviyo"
        request.headers["X-Klaviyo-Timestamp"]
      end
    end

    def handle_mailchimp_webhook
      case @payload["type"]
      when "subscribe"
        process_subscriber_event("subscribed", @payload["data"])
      when "unsubscribe"
        process_subscriber_event("unsubscribed", @payload["data"])
      when "cleaned"
        process_subscriber_event("cleaned", @payload["data"])
      when "campaign_sent"
        process_campaign_event("sent", @payload["data"])
      when "campaign_open"
        process_engagement_event("open", @payload["data"])
      when "campaign_click"
        process_engagement_event("click", @payload["data"])
      end

      head :ok
    end

    def handle_sendgrid_webhook
      @payload.each do |event|
        case event["event"]
        when "delivered"
          process_delivery_event(event)
        when "open"
          process_engagement_event("open", event)
        when "click"
          process_engagement_event("click", event)
        when "bounce"
          process_bounce_event(event)
        when "dropped"
          process_bounce_event(event)
        when "unsubscribe"
          process_unsubscribe_event(event)
        when "spamreport"
          process_spam_complaint_event(event)
        end
      end

      head :ok
    end

    def handle_constant_contact_webhook
      @payload.each do |event|
        case event["event_type"]
        when "contact.created"
          process_subscriber_event("subscribed", event["data"])
        when "contact.updated"
          process_subscriber_update_event(event["data"])
        when "contact.deleted"
          process_subscriber_event("unsubscribed", event["data"])
        when "campaign.sent"
          process_campaign_event("sent", event["data"])
        when "campaign.opened"
          process_engagement_event("open", event["data"])
        when "campaign.clicked"
          process_engagement_event("click", event["data"])
        end
      end

      head :ok
    end

    def handle_campaign_monitor_webhook
      case @payload["Type"]
      when "Subscribe"
        process_subscriber_event("subscribed", @payload)
      when "Unsubscribe"
        process_subscriber_event("unsubscribed", @payload)
      when "Bounce"
        process_bounce_event(@payload)
      when "SpamComplaint"
        process_spam_complaint_event(@payload)
      end

      head :ok
    end

    def handle_activecampaign_webhook
      case @payload["type"]
      when "contact_add"
        process_subscriber_event("subscribed", @payload["contact"])
      when "contact_update"
        process_subscriber_update_event(@payload["contact"])
      when "unsubscribe"
        process_subscriber_event("unsubscribed", @payload["contact"])
      when "sent"
        process_campaign_event("sent", @payload)
      when "open"
        process_engagement_event("open", @payload)
      when "click"
        process_engagement_event("click", @payload)
      end

      head :ok
    end

    def handle_klaviyo_webhook
      case @payload["type"]
      when "contact.subscribed"
        process_subscriber_event("subscribed", @payload["data"])
      when "contact.unsubscribed"
        process_subscriber_event("unsubscribed", @payload["data"])
      when "email.sent"
        process_campaign_event("sent", @payload["data"])
      when "email.opened"
        process_engagement_event("open", @payload["data"])
      when "email.clicked"
        process_engagement_event("click", @payload["data"])
      when "email.bounced"
        process_bounce_event(@payload["data"])
      end

      head :ok
    end

    # Event processing methods
    def process_subscriber_event(status, data)
      Analytics::EmailWebhookProcessorService.new(@integration).process_subscriber_event(status, data)
    end

    def process_subscriber_update_event(data)
      Analytics::EmailWebhookProcessorService.new(@integration).process_subscriber_update_event(data)
    end

    def process_campaign_event(event_type, data)
      Analytics::EmailWebhookProcessorService.new(@integration).process_campaign_event(event_type, data)
    end

    def process_engagement_event(event_type, data)
      Analytics::EmailWebhookProcessorService.new(@integration).process_engagement_event(event_type, data)
    end

    def process_delivery_event(data)
      Analytics::EmailWebhookProcessorService.new(@integration).process_delivery_event(data)
    end

    def process_bounce_event(data)
      Analytics::EmailWebhookProcessorService.new(@integration).process_bounce_event(data)
    end

    def process_unsubscribe_event(data)
      Analytics::EmailWebhookProcessorService.new(@integration).process_unsubscribe_event(data)
    end

    def process_spam_complaint_event(data)
      Analytics::EmailWebhookProcessorService.new(@integration).process_spam_complaint_event(data)
    end

    def devise_configured?
      defined?(Devise)
    end
  end
end
