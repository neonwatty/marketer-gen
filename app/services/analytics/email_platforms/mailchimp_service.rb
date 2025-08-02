# frozen_string_literal: true

module Analytics
  module EmailPlatforms
    class MailchimpService
      include Analytics::RateLimitingService

      attr_accessor :integration

      def initialize(integration)
        @integration = integration
        @client = build_client
      end

      def sync_campaigns(limit: 100)
        with_rate_limiting("mailchimp_campaigns", user_id: @integration.brand.id) do
          response = @client.get("campaigns", {
            count: limit,
            status: "sent",
            sort_field: "send_time",
            sort_dir: "DESC"
          })

          if response.success?
            campaigns_data = JSON.parse(response.body)
            sync_campaigns_data(campaigns_data["campaigns"])
            ServiceResult.success(data: { synced_campaigns: campaigns_data["campaigns"].length })
          else
            ServiceResult.failure("Failed to fetch campaigns: #{response.body}")
          end
        end
      rescue StandardError => e
        ServiceResult.failure("Mailchimp sync error: #{e.message}")
      end

      def sync_campaign_stats(campaign_id)
        with_rate_limiting("mailchimp_stats", user_id: @integration.brand.id) do
          response = @client.get("reports/#{campaign_id}")

          if response.success?
            stats_data = JSON.parse(response.body)
            update_campaign_metrics(campaign_id, stats_data)
            ServiceResult.success(data: stats_data)
          else
            ServiceResult.failure("Failed to fetch campaign stats: #{response.body}")
          end
        end
      rescue StandardError => e
        ServiceResult.failure("Mailchimp stats sync error: #{e.message}")
      end

      def sync_lists(limit: 100)
        with_rate_limiting("mailchimp_lists", user_id: @integration.brand.id) do
          response = @client.get("lists", { count: limit })

          if response.success?
            lists_data = JSON.parse(response.body)
            sync_lists_data(lists_data["lists"])
            ServiceResult.success(data: { synced_lists: lists_data["lists"].length })
          else
            ServiceResult.failure("Failed to fetch lists: #{response.body}")
          end
        end
      rescue StandardError => e
        ServiceResult.failure("Mailchimp lists sync error: #{e.message}")
      end

      def sync_subscribers(list_id, limit: 1000)
        with_rate_limiting("mailchimp_subscribers", user_id: @integration.brand.id) do
          response = @client.get("lists/#{list_id}/members", {
            count: limit,
            sort_field: "timestamp_signup",
            sort_dir: "DESC"
          })

          if response.success?
            members_data = JSON.parse(response.body)
            sync_subscribers_data(list_id, members_data["members"])
            ServiceResult.success(data: { synced_subscribers: members_data["members"].length })
          else
            ServiceResult.failure("Failed to fetch subscribers: #{response.body}")
          end
        end
      rescue StandardError => e
        ServiceResult.failure("Mailchimp subscribers sync error: #{e.message}")
      end

      def sync_automations(limit: 100)
        with_rate_limiting("mailchimp_automations", user_id: @integration.brand.id) do
          response = @client.get("automations", { count: limit })

          if response.success?
            automations_data = JSON.parse(response.body)
            sync_automations_data(automations_data["automations"])
            ServiceResult.success(data: { synced_automations: automations_data["automations"].length })
          else
            ServiceResult.failure("Failed to fetch automations: #{response.body}")
          end
        end
      rescue StandardError => e
        ServiceResult.failure("Mailchimp automations sync error: #{e.message}")
      end

      def create_webhook(events: %w[subscribe unsubscribe cleaned campaign])
        webhook_url = @integration.webhook_endpoint_url
        @integration.generate_webhook_secret! unless @integration.webhook_secret

        with_rate_limiting("mailchimp_webhooks", user_id: @integration.brand.id) do
          # Get the first list to attach webhook to
          lists_response = @client.get("lists", { count: 1 })
          return ServiceResult.failure("No lists found") unless lists_response.success?

          lists_data = JSON.parse(lists_response.body)
          return ServiceResult.failure("No lists available") if lists_data["lists"].empty?

          list_id = lists_data["lists"].first["id"]

          webhook_data = {
            url: webhook_url,
            events: events.map { |event| [ event, true ] }.to_h,
            sources: {
              user: true,
              admin: true,
              api: true
            }
          }

          response = @client.post("lists/#{list_id}/webhooks", webhook_data)

          if response.success?
            webhook_response = JSON.parse(response.body)
            @integration.set_configuration_value("webhook_id", webhook_response["id"])
            @integration.set_configuration_value("list_id", list_id)
            ServiceResult.success(data: webhook_response)
          else
            ServiceResult.failure("Failed to create webhook: #{response.body}")
          end
        end
      rescue StandardError => e
        ServiceResult.failure("Mailchimp webhook creation error: #{e.message}")
      end

      def delete_webhook
        webhook_id = @integration.configuration_value("webhook_id")
        list_id = @integration.configuration_value("list_id")

        return ServiceResult.success(data: { message: "No webhook to delete" }) unless webhook_id && list_id

        with_rate_limiting("mailchimp_webhooks", user_id: @integration.brand.id) do
          response = @client.delete("lists/#{list_id}/webhooks/#{webhook_id}")

          if response.success?
            @integration.set_configuration_value("webhook_id", nil)
            ServiceResult.success(data: { message: "Webhook deleted successfully" })
          else
            ServiceResult.failure("Failed to delete webhook: #{response.body}")
          end
        end
      rescue StandardError => e
        ServiceResult.failure("Mailchimp webhook deletion error: #{e.message}")
      end

      def test_connection
        with_rate_limiting("mailchimp_ping", user_id: @integration.brand.id) do
          response = @client.get("ping")

          if response.success?
            data = JSON.parse(response.body)
            ServiceResult.success(data: { connected: true, health_status: data["health_status"] })
          else
            ServiceResult.failure("Connection test failed: #{response.body}")
          end
        end
      rescue StandardError => e
        ServiceResult.failure("Mailchimp connection test error: #{e.message}")
      end

      private

      def build_client
        raise "No API endpoint configured" unless @integration.api_endpoint

        Faraday.new(url: @integration.api_base_url) do |conn|
          conn.request :json
          conn.response :logger, Rails.logger, { headers: false, bodies: false } if Rails.env.development?
          conn.headers.merge!(@integration.api_headers)
        end
      end

      def sync_campaigns_data(campaigns)
        campaigns.each do |campaign_data|
          sync_single_campaign(campaign_data)
        end
      end

      def sync_single_campaign(campaign_data)
        campaign = @integration.email_campaigns.find_or_initialize_by(
          platform_campaign_id: campaign_data["id"]
        )

        campaign.assign_attributes(
          name: campaign_data["settings"]["title"],
          subject: campaign_data["settings"]["subject_line"],
          status: map_campaign_status(campaign_data["status"]),
          campaign_type: map_campaign_type(campaign_data["type"]),
          send_time: parse_time(campaign_data["send_time"]),
          total_recipients: campaign_data["recipients"]["recipient_count"],
          configuration: {
            list_id: campaign_data["recipients"]["list_id"],
            from_name: campaign_data["settings"]["from_name"],
            reply_to: campaign_data["settings"]["reply_to"],
            archive_url: campaign_data["archive_url"]
          }
        )

        campaign.save!

        # Sync campaign statistics if available
        if campaign_data["report_summary"]
          update_campaign_metrics_from_summary(campaign, campaign_data["report_summary"])
        end
      end

      def sync_lists_data(lists)
        lists.each do |list_data|
          # Store list information in integration configuration
          lists_config = @integration.configuration_value("lists") || {}
          lists_config[list_data["id"]] = {
            name: list_data["name"],
            member_count: list_data["stats"]["member_count"],
            unsubscribe_count: list_data["stats"]["unsubscribe_count"],
            cleaned_count: list_data["stats"]["cleaned_count"]
          }
          @integration.set_configuration_value("lists", lists_config)
        end
      end

      def sync_subscribers_data(list_id, members)
        members.each do |member_data|
          sync_single_subscriber(list_id, member_data)
        end
      end

      def sync_single_subscriber(list_id, member_data)
        subscriber = @integration.email_subscribers.find_or_initialize_by(
          platform_subscriber_id: member_data["id"]
        )

        subscriber.assign_attributes(
          email: member_data["email_address"],
          first_name: member_data.dig("merge_fields", "FNAME"),
          last_name: member_data.dig("merge_fields", "LNAME"),
          status: map_subscriber_status(member_data["status"]),
          subscribed_at: parse_time(member_data["timestamp_signup"]),
          tags: member_data["tags"]&.map { |tag| tag["name"] },
          location: extract_location_data(member_data),
          source: "mailchimp_list_#{list_id}"
        )

        subscriber.save!
      end

      def sync_automations_data(automations)
        automations.each do |automation_data|
          sync_single_automation(automation_data)
        end
      end

      def sync_single_automation(automation_data)
        automation = @integration.email_automations.find_or_initialize_by(
          platform_automation_id: automation_data["id"]
        )

        automation.assign_attributes(
          name: automation_data["settings"]["title"],
          automation_type: map_automation_type(automation_data["trigger_settings"]["workflow_type"]),
          status: map_automation_status(automation_data["status"]),
          trigger_type: "subscription", # Mailchimp automations are typically subscription-based
          total_subscribers: automation_data["recipients"]["list_size"],
          configuration: {
            list_id: automation_data["recipients"]["list_id"],
            trigger_settings: automation_data["trigger_settings"],
            emails_count: automation_data["emails"]&.length || 0
          }
        )

        automation.save!
      end

      def update_campaign_metrics(campaign_id, stats_data)
        campaign = @integration.email_campaigns.find_by(platform_campaign_id: campaign_id)
        return unless campaign

        update_campaign_metrics_from_summary(campaign, stats_data)
      end

      def update_campaign_metrics_from_summary(campaign, summary_data)
        today = Date.current
        metric = campaign.email_metrics.find_or_initialize_by(
          metric_type: "campaign",
          metric_date: today
        )

        metric.assign_attributes(
          opens: summary_data["opens"],
          unique_opens: summary_data["unique_opens"],
          clicks: summary_data["clicks"],
          unique_clicks: summary_data["subscriber_clicks"],
          unsubscribes: summary_data["unsubscribes"],
          bounces: summary_data["bounces"],
          sent: campaign.total_recipients,
          delivered: campaign.total_recipients - summary_data["bounces"]
        )

        metric.save!
      end

      def extract_location_data(member_data)
        location = {}
        location["country"] = member_data.dig("location", "country_code") if member_data.dig("location", "country_code")
        location["timezone"] = member_data.dig("location", "timezone") if member_data.dig("location", "timezone")
        location["latitude"] = member_data.dig("location", "latitude") if member_data.dig("location", "latitude")
        location["longitude"] = member_data.dig("location", "longitude") if member_data.dig("location", "longitude")
        location.any? ? location : nil
      end

      def map_campaign_status(mailchimp_status)
        case mailchimp_status
        when "save" then "draft"
        when "schedule" then "scheduled"
        when "sending" then "sending"
        when "sent" then "sent"
        when "canceled" then "canceled"
        else mailchimp_status
        end
      end

      def map_campaign_type(mailchimp_type)
        case mailchimp_type
        when "regular" then "regular"
        when "plaintext" then "regular"
        when "absplit" then "a_b_test"
        when "rss" then "rss"
        when "automation" then "automation"
        else "regular"
        end
      end

      def map_subscriber_status(mailchimp_status)
        case mailchimp_status
        when "subscribed" then "subscribed"
        when "unsubscribed" then "unsubscribed"
        when "pending" then "pending"
        when "cleaned" then "cleaned"
        else mailchimp_status
        end
      end

      def map_automation_status(mailchimp_status)
        case mailchimp_status
        when "save" then "draft"
        when "paused" then "paused"
        when "sending" then "active"
        else mailchimp_status
        end
      end

      def map_automation_type(workflow_type)
        case workflow_type
        when "emailSeries" then "drip"
        when "welcomeSeries" then "welcome"
        when "dateTriggered" then "date"
        when "apiTriggered" then "api"
        else "custom"
        end
      end

      def parse_time(time_string)
        return nil if time_string.blank?

        Time.parse(time_string)
      rescue ArgumentError
        nil
      end
    end
  end
end
