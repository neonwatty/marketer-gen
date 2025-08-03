# frozen_string_literal: true

module Analytics
  module Notifications
    # Service for delivering notifications through various channels
    class DeliveryService
      def initialize(options = {})
        @logger = Rails.logger
        @retry_on_failure = options.fetch(:retry_on_failure, true)
        @max_retry_attempts = options.fetch(:max_retry_attempts, 3)
      end

      # Deliver a single notification
      def deliver_notification(notification)
        @logger.debug "Delivering notification #{notification.id} via #{notification.channel}"

        return error("Notification is not pending") unless notification.pending?
        return error("Notification is scheduled for future") if notification.scheduled_for > Time.current

        begin
          # Mark as processing
          notification.mark_processing!

          # Render notification content
          content = notification.render_content

          # Deliver based on channel
          result = case notification.channel
          when "email"
                     deliver_email(notification, content)
          when "in_app"
                     deliver_in_app(notification, content)
          when "sms"
                     deliver_sms(notification, content)
          when "slack"
                     deliver_slack(notification, content)
          when "teams"
                     deliver_teams(notification, content)
          when "webhook"
                     deliver_webhook(notification, content)
          else
                     error("Unsupported notification channel: #{notification.channel}")
          end

          if result.success?
            # Mark as sent
            notification.mark_sent!(result.data[:external_id], result.data[:metadata])
            @logger.info "Notification #{notification.id} delivered successfully via #{notification.channel}"
            success(result.data)
          else
            # Mark as failed and potentially retry
            handle_delivery_failure(notification, result.error_message)
          end

        rescue StandardError => e
          @logger.error "Error delivering notification #{notification.id}: #{e.message}"
          handle_delivery_failure(notification, e.message)
        end
      end

      # Deliver multiple notifications in batch
      def deliver_batch(notifications)
        return error("No notifications to deliver") if notifications.empty?

        @logger.info "Delivering batch of #{notifications.count} notifications"

        results = {
          total: notifications.count,
          successful: 0,
          failed: 0,
          errors: []
        }

        # Group by channel for efficient batch delivery
        notifications.group_by(&:channel).each do |channel, channel_notifications|
          batch_result = deliver_channel_batch(channel, channel_notifications)

          results[:successful] += batch_result[:successful]
          results[:failed] += batch_result[:failed]
          results[:errors].concat(batch_result[:errors])
        end

        success(results)
      end

      # Process notification queue for a specific channel
      def process_channel_queue(channel, limit = 100)
        @logger.info "Processing #{channel} notification queue (limit: #{limit})"

        notifications = NotificationQueue.ready_to_send
                                         .for_channel(channel)
                                         .order(:priority, :scheduled_for)
                                         .limit(limit)

        return success({ processed: 0, message: "No notifications ready" }) if notifications.empty?

        # Check if this channel supports batching
        if supports_batching?(channel)
          batch_notifications = notifications.batchable.limit([ limit, batch_size_limit(channel) ].min)

          if batch_notifications.count > 1
            @logger.info "Batching #{batch_notifications.count} #{channel} notifications"
            return deliver_batch(batch_notifications)
          end
        end

        # Process individually
        results = { processed: 0, successful: 0, failed: 0, errors: [] }

        notifications.each do |notification|
          result = deliver_notification(notification)

          results[:processed] += 1
          if result.success?
            results[:successful] += 1
          else
            results[:failed] += 1
            results[:errors] << { id: notification.id, error: result.error_message }
          end
        end

        success(results)
      end

      # Check delivery status for external providers
      def check_delivery_status(notification)
        return error("No external ID available") unless notification.external_id.present?

        case notification.channel
        when "email"
          check_email_delivery_status(notification)
        when "sms"
          check_sms_delivery_status(notification)
        when "slack"
          check_slack_delivery_status(notification)
        when "teams"
          check_teams_delivery_status(notification)
        when "webhook"
          check_webhook_delivery_status(notification)
        else
          error("Status checking not supported for channel: #{notification.channel}")
        end
      end

      private

      def deliver_email(notification, content)
        begin
          # Use Rails ActionMailer or external email service
          mailer_result = Analytics::AlertMailer.performance_alert(
            recipient: notification.recipient_address,
            subject: content[:subject],
            message: content[:message],
            template_data: content[:template_data],
            alert_instance: notification.alert_instance
          ).deliver_now

          success({
            external_id: mailer_result.message_id,
            metadata: {
              provider: "rails_mailer",
              delivered_at: Time.current.iso8601
            }
          })

        rescue StandardError => e
          error("Email delivery failed: #{e.message}")
        end
      end

      def deliver_in_app(notification, content)
        begin
          # Create in-app notification record
          # This would integrate with your in-app notification system

          success({
            external_id: SecureRandom.uuid,
            metadata: {
              provider: "in_app",
              delivered_at: Time.current.iso8601,
              read_status: "unread"
            }
          })

        rescue StandardError => e
          error("In-app delivery failed: #{e.message}")
        end
      end

      def deliver_sms(notification, content)
        begin
          # Integrate with SMS service (Twilio, AWS SNS, etc.)
          return error("SMS provider not configured") unless sms_provider_configured?

          # Example Twilio integration
          client = Twilio::REST::Client.new(
            Rails.application.credentials.twilio[:account_sid],
            Rails.application.credentials.twilio[:auth_token]
          )

          message = client.messages.create(
            from: Rails.application.credentials.twilio[:phone_number],
            to: notification.recipient_address,
            body: content[:message]
          )

          success({
            external_id: message.sid,
            metadata: {
              provider: "twilio",
              delivered_at: Time.current.iso8601,
              cost: calculate_sms_cost(content[:message])
            }
          })

        rescue StandardError => e
          error("SMS delivery failed: #{e.message}")
        end
      end

      def deliver_slack(notification, content)
        begin
          return error("Slack webhook not configured") unless slack_webhook_configured?

          webhook_url = notification.channel_config["webhook_url"] ||
                       Rails.application.credentials.slack[:webhook_url]

          payload = {
            text: content[:subject],
            attachments: [
              {
                color: severity_to_color(notification.alert_instance.severity),
                fields: [
                  {
                    title: "Alert Details",
                    value: content[:message],
                    short: false
                  },
                  {
                    title: "Triggered At",
                    value: notification.alert_instance.triggered_at.strftime("%Y-%m-%d %H:%M:%S UTC"),
                    short: true
                  },
                  {
                    title: "Severity",
                    value: notification.alert_instance.severity.titleize,
                    short: true
                  }
                ],
                actions: [
                  {
                    type: "button",
                    text: "Acknowledge",
                    url: "#{Rails.application.routes.url_helpers.root_url}alerts/#{notification.alert_instance.id}/acknowledge"
                  },
                  {
                    type: "button",
                    text: "View Details",
                    url: "#{Rails.application.routes.url_helpers.root_url}alerts/#{notification.alert_instance.id}"
                  }
                ]
              }
            ]
          }

          response = HTTParty.post(
            webhook_url,
            body: payload.to_json,
            headers: { "Content-Type" => "application/json" }
          )

          if response.success?
            success({
              external_id: response.headers["x-slack-req-id"] || SecureRandom.uuid,
              metadata: {
                provider: "slack",
                delivered_at: Time.current.iso8601,
                response_code: response.code
              }
            })
          else
            error("Slack delivery failed: #{response.code} - #{response.body}")
          end

        rescue StandardError => e
          error("Slack delivery failed: #{e.message}")
        end
      end

      def deliver_teams(notification, content)
        begin
          return error("Teams webhook not configured") unless teams_webhook_configured?

          webhook_url = notification.channel_config["webhook_url"] ||
                       Rails.application.credentials.teams[:webhook_url]

          payload = {
            "@type" => "MessageCard",
            "@context" => "http://schema.org/extensions",
            "themeColor" => severity_to_color(notification.alert_instance.severity, :hex),
            "summary" => content[:subject],
            "sections" => [
              {
                "activityTitle" => content[:subject],
                "activitySubtitle" => "Alert from #{notification.alert_instance.performance_alert.metric_source.titleize}",
                "text" => content[:message],
                "facts" => [
                  { "name" => "Severity", "value" => notification.alert_instance.severity.titleize },
                  { "name" => "Triggered At", "value" => notification.alert_instance.triggered_at.strftime("%Y-%m-%d %H:%M:%S UTC") },
                  { "name" => "Metric Type", "value" => notification.alert_instance.performance_alert.metric_type.humanize }
                ]
              }
            ],
            "potentialAction" => [
              {
                "@type" => "OpenUri",
                "name" => "Acknowledge Alert",
                "targets" => [
                  { "os" => "default", "uri" => "#{Rails.application.routes.url_helpers.root_url}alerts/#{notification.alert_instance.id}/acknowledge" }
                ]
              },
              {
                "@type" => "OpenUri",
                "name" => "View Details",
                "targets" => [
                  { "os" => "default", "uri" => "#{Rails.application.routes.url_helpers.root_url}alerts/#{notification.alert_instance.id}" }
                ]
              }
            ]
          }

          response = HTTParty.post(
            webhook_url,
            body: payload.to_json,
            headers: { "Content-Type" => "application/json" }
          )

          if response.success?
            success({
              external_id: SecureRandom.uuid,
              metadata: {
                provider: "teams",
                delivered_at: Time.current.iso8601,
                response_code: response.code
              }
            })
          else
            error("Teams delivery failed: #{response.code} - #{response.body}")
          end

        rescue StandardError => e
          error("Teams delivery failed: #{e.message}")
        end
      end

      def deliver_webhook(notification, content)
        begin
          webhook_url = notification.channel_config["webhook_url"]
          return error("Webhook URL not configured") unless webhook_url.present?

          payload = {
            notification_id: notification.id,
            alert_instance_id: notification.alert_instance.id,
            alert_name: notification.alert_instance.performance_alert.name,
            severity: notification.alert_instance.severity,
            triggered_at: notification.alert_instance.triggered_at.iso8601,
            subject: content[:subject],
            message: content[:message],
            template_data: content[:template_data],
            metadata: notification.alert_instance.trigger_context
          }

          headers = {
            "Content-Type" => "application/json",
            "User-Agent" => "MarketerGen-Alerts/1.0"
          }

          # Add authentication headers if configured
          if notification.channel_config["auth_header"].present?
            headers["Authorization"] = notification.channel_config["auth_header"]
          end

          response = HTTParty.post(
            webhook_url,
            body: payload.to_json,
            headers: headers,
            timeout: 30
          )

          if response.success?
            success({
              external_id: response.headers["x-webhook-id"] || SecureRandom.uuid,
              metadata: {
                provider: "webhook",
                delivered_at: Time.current.iso8601,
                response_code: response.code,
                response_body: response.body[0..500] # Limit response body size
              }
            })
          else
            error("Webhook delivery failed: #{response.code} - #{response.body}")
          end

        rescue StandardError => e
          error("Webhook delivery failed: #{e.message}")
        end
      end

      def deliver_channel_batch(channel, notifications)
        results = { successful: 0, failed: 0, errors: [] }

        case channel
        when "email"
          # Email can be batched efficiently
          results = deliver_email_batch(notifications)
        when "slack"
          # Slack has rate limits, process individually but with delays
          results = deliver_slack_batch(notifications)
        else
          # Default to individual processing
          notifications.each do |notification|
            result = deliver_notification(notification)

            if result.success?
              results[:successful] += 1
            else
              results[:failed] += 1
              results[:errors] << { id: notification.id, error: result.error_message }
            end
          end
        end

        results
      end

      def deliver_email_batch(notifications)
        # Group emails by template and send in batches
        results = { successful: 0, failed: 0, errors: [] }

        notifications.group_by(&:template_name).each do |template, template_notifications|
          begin
            # Use bulk email service
            template_notifications.each do |notification|
              result = deliver_email(notification, notification.render_content)

              if result.success?
                results[:successful] += 1
              else
                results[:failed] += 1
                results[:errors] << { id: notification.id, error: result.error_message }
              end
            end

          rescue StandardError => e
            @logger.error "Error in email batch delivery: #{e.message}"
            template_notifications.each do |notification|
              results[:failed] += 1
              results[:errors] << { id: notification.id, error: e.message }
            end
          end
        end

        results
      end

      def deliver_slack_batch(notifications)
        results = { successful: 0, failed: 0, errors: [] }

        notifications.each_with_index do |notification, index|
          # Add delay to respect rate limits
          sleep(0.5) if index > 0

          result = deliver_notification(notification)

          if result.success?
            results[:successful] += 1
          else
            results[:failed] += 1
            results[:errors] << { id: notification.id, error: result.error_message }
          end
        end

        results
      end

      def handle_delivery_failure(notification, error_message)
        if @retry_on_failure && notification.can_retry?
          notification.mark_failed!(error_message)
          @logger.warn "Notification #{notification.id} failed, will retry: #{error_message}"

          # Schedule retry
          Analytics::Notifications::RetryJob.set(
            wait_until: notification.next_retry_at
          ).perform_later(notification)

          error("Delivery failed, retry scheduled: #{error_message}")
        else
          notification.mark_failed!(error_message)
          @logger.error "Notification #{notification.id} permanently failed: #{error_message}"

          error("Delivery permanently failed: #{error_message}")
        end
      end

      def supports_batching?(channel)
        %w[email].include?(channel)
      end

      def batch_size_limit(channel)
        NotificationQueue::BATCH_SIZE_LIMITS[channel] || 10
      end

      def severity_to_color(severity, format = :slack)
        colors = case format
        when :slack
                   {
                     "critical" => "danger",
                     "high" => "warning",
                     "medium" => "good",
                     "low" => "#439FE0"
                   }
        when :hex
                   {
                     "critical" => "#FF0000",
                     "high" => "#FFA500",
                     "medium" => "#FFFF00",
                     "low" => "#00FF00"
                   }
        end

        colors[severity] || colors["medium"]
      end

      def sms_provider_configured?
        Rails.application.credentials.twilio.present? &&
          Rails.application.credentials.twilio[:account_sid].present? &&
          Rails.application.credentials.twilio[:auth_token].present?
      end

      def slack_webhook_configured?
        Rails.application.credentials.slack.present? &&
          Rails.application.credentials.slack[:webhook_url].present?
      end

      def teams_webhook_configured?
        Rails.application.credentials.teams.present? &&
          Rails.application.credentials.teams[:webhook_url].present?
      end

      def calculate_sms_cost(message)
        # Calculate cost based on message length (160 chars = 1 SMS)
        segments = (message.length / 160.0).ceil
        segments * 0.05 # $0.05 per SMS segment
      end

      # Status checking methods
      def check_email_delivery_status(notification)
        # This would integrate with your email provider's API
        success({ status: "delivered", checked_at: Time.current })
      end

      def check_sms_delivery_status(notification)
        # This would integrate with Twilio's status API
        success({ status: "delivered", checked_at: Time.current })
      end

      def check_slack_delivery_status(notification)
        # Slack doesn't provide delivery confirmations for webhooks
        success({ status: "sent", checked_at: Time.current })
      end

      def check_teams_delivery_status(notification)
        # Teams doesn't provide delivery confirmations for webhooks
        success({ status: "sent", checked_at: Time.current })
      end

      def check_webhook_delivery_status(notification)
        # Could implement webhook delivery confirmation
        success({ status: "sent", checked_at: Time.current })
      end
    end
  end
end
