# frozen_string_literal: true

module Analytics
  class EmailWebhookProcessorService
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_accessor :integration

    def initialize(integration)
      @integration = integration
    end

    def process_subscriber_event(status, data)
      subscriber_id = extract_subscriber_id(data)
      email = extract_email(data)

      return unless subscriber_id && email

      subscriber = find_or_create_subscriber(subscriber_id, email)
      update_subscriber_status(subscriber, status, data)

      Rails.logger.info "Processed subscriber #{status} event for #{email}"
    rescue StandardError => e
      Rails.logger.error "Error processing subscriber event: #{e.message}"
    end

    def process_subscriber_update_event(data)
      subscriber_id = extract_subscriber_id(data)
      return unless subscriber_id

      subscriber = @integration.email_subscribers.find_by(platform_subscriber_id: subscriber_id)
      return unless subscriber

      update_subscriber_attributes(subscriber, data)

      Rails.logger.info "Updated subscriber #{subscriber.email}"
    rescue StandardError => e
      Rails.logger.error "Error processing subscriber update: #{e.message}"
    end

    def process_campaign_event(event_type, data)
      campaign_id = extract_campaign_id(data)
      return unless campaign_id

      campaign = find_or_create_campaign(campaign_id, data)

      case event_type
      when "sent"
        update_campaign_send_metrics(campaign, data)
      end

      Rails.logger.info "Processed campaign #{event_type} event for campaign #{campaign_id}"
    rescue StandardError => e
      Rails.logger.error "Error processing campaign event: #{e.message}"
    end

    def process_engagement_event(event_type, data)
      campaign_id = extract_campaign_id(data)
      return unless campaign_id

      campaign = @integration.email_campaigns.find_by(platform_campaign_id: campaign_id)
      return unless campaign

      update_engagement_metrics(campaign, event_type, data)

      Rails.logger.info "Processed #{event_type} event for campaign #{campaign_id}"
    rescue StandardError => e
      Rails.logger.error "Error processing engagement event: #{e.message}"
    end

    def process_delivery_event(data)
      campaign_id = extract_campaign_id(data)
      return unless campaign_id

      campaign = @integration.email_campaigns.find_by(platform_campaign_id: campaign_id)
      return unless campaign

      increment_metric(campaign, :delivered)

      Rails.logger.info "Processed delivery event for campaign #{campaign_id}"
    rescue StandardError => e
      Rails.logger.error "Error processing delivery event: #{e.message}"
    end

    def process_bounce_event(data)
      campaign_id = extract_campaign_id(data)
      subscriber_email = extract_email(data)

      if campaign_id
        campaign = @integration.email_campaigns.find_by(platform_campaign_id: campaign_id)
        increment_metric(campaign, :bounces) if campaign
      end

      if subscriber_email
        subscriber = @integration.email_subscribers.find_by(email: subscriber_email)
        if subscriber
          bounce_type = extract_bounce_type(data)
          if bounce_type == "hard" || should_mark_as_bounced?(data)
            subscriber.update!(status: "bounced")
          end
        end
      end

      Rails.logger.info "Processed bounce event"
    rescue StandardError => e
      Rails.logger.error "Error processing bounce event: #{e.message}"
    end

    def process_unsubscribe_event(data)
      subscriber_email = extract_email(data)
      return unless subscriber_email

      subscriber = @integration.email_subscribers.find_by(email: subscriber_email)
      if subscriber
        subscriber.update!(
          status: "unsubscribed",
          unsubscribed_at: Time.current
        )
      end

      # Also increment unsubscribe metric for campaign if available
      campaign_id = extract_campaign_id(data)
      if campaign_id
        campaign = @integration.email_campaigns.find_by(platform_campaign_id: campaign_id)
        increment_metric(campaign, :unsubscribes) if campaign
      end

      Rails.logger.info "Processed unsubscribe event for #{subscriber_email}"
    rescue StandardError => e
      Rails.logger.error "Error processing unsubscribe event: #{e.message}"
    end

    def process_spam_complaint_event(data)
      subscriber_email = extract_email(data)
      campaign_id = extract_campaign_id(data)

      if subscriber_email
        subscriber = @integration.email_subscribers.find_by(email: subscriber_email)
        subscriber&.update!(status: "cleaned")
      end

      if campaign_id
        campaign = @integration.email_campaigns.find_by(platform_campaign_id: campaign_id)
        increment_metric(campaign, :complaints) if campaign
      end

      Rails.logger.warn "Processed spam complaint event for #{subscriber_email}"
    rescue StandardError => e
      Rails.logger.error "Error processing spam complaint event: #{e.message}"
    end

    private

    def extract_subscriber_id(data)
      case @integration.platform
      when "mailchimp"
        data["id"] || data["email_id"]
      when "sendgrid"
        data["sg_user_id"] || data["email"]
      when "constant_contact"
        data["contact_id"] || data["id"]
      when "campaign_monitor"
        data["EmailAddress"]
      when "activecampaign"
        data["id"]
      when "klaviyo"
        data["id"] || data.dig("attributes", "id")
      end
    end

    def extract_email(data)
      case @integration.platform
      when "mailchimp"
        data["email"]
      when "sendgrid"
        data["email"]
      when "constant_contact"
        data["email_address"]
      when "campaign_monitor"
        data["EmailAddress"]
      when "activecampaign"
        data["email"]
      when "klaviyo"
        data["email"] || data.dig("attributes", "email")
      end
    end

    def extract_campaign_id(data)
      case @integration.platform
      when "mailchimp"
        data["campaign_id"] || data["cid"]
      when "sendgrid"
        data["sg_campaign_id"] || data["campaign_id"]
      when "constant_contact"
        data["campaign_activity_id"] || data["campaign_id"]
      when "campaign_monitor"
        data["CampaignID"]
      when "activecampaign"
        data["campaign_id"] || data["campaignid"]
      when "klaviyo"
        data["campaign_id"] || data.dig("attributes", "campaign_id")
      end
    end

    def extract_bounce_type(data)
      case @integration.platform
      when "sendgrid"
        data["type"] # "bounce" or "blocked"
      when "mailchimp"
        data["reason"] # "hard" or "soft"
      when "constant_contact"
        data["bounce_type"]
      else
        "hard" # Default to hard bounce
      end
    end

    def should_mark_as_bounced?(data)
      bounce_type = extract_bounce_type(data)
      bounce_reason = data["reason"] || data["bounce_reason"] || ""

      # Mark as bounced for hard bounces or certain soft bounce reasons
      bounce_type == "hard" ||
        bounce_reason.include?("blocked") ||
        bounce_reason.include?("invalid") ||
        bounce_reason.include?("unknown")
    end

    def find_or_create_subscriber(subscriber_id, email)
      @integration.email_subscribers.find_or_create_by(
        platform_subscriber_id: subscriber_id
      ) do |subscriber|
        subscriber.email = email
        subscriber.status = "pending"
      end
    end

    def update_subscriber_status(subscriber, status, data)
      updates = { status: status }

      case status
      when "subscribed"
        updates[:subscribed_at] = parse_timestamp(data) || Time.current
        updates[:unsubscribed_at] = nil
      when "unsubscribed"
        updates[:unsubscribed_at] = parse_timestamp(data) || Time.current
      end

      # Update additional attributes
      update_subscriber_attributes(subscriber, data, updates)
    end

    def update_subscriber_attributes(subscriber, data, initial_updates = {})
      updates = initial_updates.dup

      # Extract platform-specific attributes
      case @integration.platform
      when "mailchimp"
        updates[:first_name] = data["merges"]["FNAME"] if data.dig("merges", "FNAME")
        updates[:last_name] = data["merges"]["LNAME"] if data.dig("merges", "LNAME")
        updates[:location] = extract_mailchimp_location(data)
        updates[:tags] = data["tags"] if data["tags"]
      when "constant_contact"
        updates[:first_name] = data["first_name"] if data["first_name"]
        updates[:last_name] = data["last_name"] if data["last_name"]
        updates[:tags] = data["taggings"]&.map { |t| t["tag"] } if data["taggings"]
      when "klaviyo"
        attrs = data["attributes"] || data
        updates[:first_name] = attrs["first_name"] if attrs["first_name"]
        updates[:last_name] = attrs["last_name"] if attrs["last_name"]
        updates[:location] = attrs["location"] if attrs["location"]
      end

      subscriber.update!(updates) if updates.any?
    end

    def extract_mailchimp_location(data)
      location_data = {}
      if data["merges"]
        location_data["country"] = data["merges"]["COUNTRY"] if data["merges"]["COUNTRY"]
        location_data["state"] = data["merges"]["STATE"] if data["merges"]["STATE"]
        location_data["city"] = data["merges"]["CITY"] if data["merges"]["CITY"]
      end
      location_data.any? ? location_data : nil
    end

    def find_or_create_campaign(campaign_id, data)
      @integration.email_campaigns.find_or_create_by(
        platform_campaign_id: campaign_id
      ) do |campaign|
        campaign.name = extract_campaign_name(data) || "Campaign #{campaign_id}"
        campaign.status = "sent"
        campaign.campaign_type = "regular"
        campaign.subject = extract_campaign_subject(data)
      end
    end

    def extract_campaign_name(data)
      case @integration.platform
      when "mailchimp"
        data["campaign_title"] || data["title"]
      when "sendgrid"
        data["campaign_name"] || data["sg_campaign_name"]
      when "constant_contact"
        data["name"] || data["campaign_name"]
      when "campaign_monitor"
        data["Name"]
      when "activecampaign"
        data["name"]
      when "klaviyo"
        data["name"] || data.dig("attributes", "name")
      end
    end

    def extract_campaign_subject(data)
      case @integration.platform
      when "mailchimp"
        data["subject"]
      when "sendgrid"
        data["subject"]
      when "constant_contact"
        data["subject"]
      when "campaign_monitor"
        data["Subject"]
      when "activecampaign"
        data["subject"]
      when "klaviyo"
        data["subject"] || data.dig("attributes", "subject")
      end
    end

    def update_campaign_send_metrics(campaign, data)
      # Extract send count from webhook data
      sent_count = extract_sent_count(data)
      campaign.update!(total_recipients: sent_count) if sent_count

      # Create or update daily metrics
      today = Date.current
      metric = campaign.email_metrics.find_or_create_by(
        metric_type: "daily",
        metric_date: today
      )

      metric.update!(sent: sent_count) if sent_count
    end

    def extract_sent_count(data)
      case @integration.platform
      when "mailchimp"
        data["emails_sent"]
      when "sendgrid"
        1 # SendGrid sends individual events
      when "constant_contact"
        data["send_count"]
      when "campaign_monitor"
        data["TotalRecipients"]
      when "activecampaign"
        data["total_recipients"]
      when "klaviyo"
        data["recipients_count"]
      end
    end

    def update_engagement_metrics(campaign, event_type, data)
      today = Date.current
      metric = campaign.email_metrics.find_or_create_by(
        metric_type: "daily",
        metric_date: today
      )

      case event_type
      when "open"
        increment_metric_value(metric, :opens)
        increment_unique_metric(metric, :unique_opens, data)
      when "click"
        increment_metric_value(metric, :clicks)
        increment_unique_metric(metric, :unique_clicks, data)
      end

      metric.save!
    end

    def increment_metric(campaign, metric_type)
      return unless campaign

      today = Date.current
      metric = campaign.email_metrics.find_or_create_by(
        metric_type: "daily",
        metric_date: today
      )

      increment_metric_value(metric, metric_type)
      metric.save!
    end

    def increment_metric_value(metric, field)
      current_value = metric.send(field) || 0
      metric.send("#{field}=", current_value + 1)
    end

    def increment_unique_metric(metric, field, data)
      # For unique metrics, we'd need to track which subscribers have already
      # been counted. For now, we'll increment for each event.
      # In production, you'd want to maintain a cache or separate tracking.
      increment_metric_value(metric, field)
    end

    def parse_timestamp(data)
      timestamp = data["timestamp"] || data["event_time"] || data["occurred_at"]
      return nil unless timestamp

      case timestamp
      when String
        Time.parse(timestamp)
      when Integer
        Time.at(timestamp)
      else
        timestamp
      end
    rescue ArgumentError
      nil
    end
  end
end
