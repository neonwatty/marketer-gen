# frozen_string_literal: true

require "test_helper"

module Webhooks
  class EmailPlatformsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @user = users(:one)
      @brand = brands(:acme_corp)
      @brand.update!(user: @user)
      
      @email_integration = EmailIntegration.create!(
        brand: @brand,
        platform: "mailchimp",
        status: "active",
        access_token: "test_token",
        webhook_secret: "test_webhook_secret"
      )
    end

    test "should handle mailchimp webhook with valid signature" do
      payload = {
        type: "subscribe",
        data: {
          id: "subscriber_123",
          email: "test@example.com",
          merges: {
            FNAME: "John",
            LNAME: "Doe"
          }
        }
      }.to_json

      # Mock signature verification
      @email_integration.expects(:verify_webhook_signature).returns(true)

      # Mock webhook processor
      processor = mock("EmailWebhookProcessorService")
      processor.expects(:process_subscriber_event).with("subscribed", anything)
      Analytics::EmailWebhookProcessorService.expects(:new).returns(processor)

      post "/webhooks/email/mailchimp/#{@email_integration.id}",
           params: payload,
           headers: {
             "Content-Type" => "application/json",
             "X-Mailchimp-Signature" => "valid_signature"
           }

      assert_response :ok
    end

    test "should reject webhook with invalid signature" do
      payload = { type: "subscribe", data: { email: "test@example.com" } }.to_json

      # Mock signature verification to fail
      @email_integration.expects(:verify_webhook_signature).returns(false)

      post "/webhooks/email/mailchimp/#{@email_integration.id}",
           params: payload,
           headers: {
             "Content-Type" => "application/json",
             "X-Mailchimp-Signature" => "invalid_signature"
           }

      assert_response :unauthorized
    end

    test "should handle sendgrid webhook with multiple events" do
      payload = [
        {
          event: "delivered",
          email: "test1@example.com",
          sg_campaign_id: "campaign_123",
          timestamp: Time.current.to_i
        },
        {
          event: "open",
          email: "test2@example.com", 
          sg_campaign_id: "campaign_123",
          timestamp: Time.current.to_i
        }
      ].to_json

      sendgrid_integration = EmailIntegration.create!(
        brand: @brand,
        platform: "sendgrid",
        status: "active",
        access_token: "sendgrid_token",
        webhook_secret: "sendgrid_secret"
      )

      # Mock signature verification
      sendgrid_integration.expects(:verify_webhook_signature).returns(true)

      # Mock webhook processor
      processor = mock("EmailWebhookProcessorService")
      processor.expects(:process_delivery_event).once
      processor.expects(:process_engagement_event).with("open", anything).once
      Analytics::EmailWebhookProcessorService.expects(:new).returns(processor)

      post "/webhooks/email/sendgrid/#{sendgrid_integration.id}",
           params: payload,
           headers: {
             "Content-Type" => "application/json",
             "X-Twilio-Email-Event-Webhook-Signature" => "valid_signature",
             "X-Twilio-Email-Event-Webhook-Timestamp" => Time.current.to_i.to_s
           }

      assert_response :ok
    end

    test "should handle klaviyo webhook events" do
      payload = {
        type: "email.opened",
        data: {
          id: "event_123",
          attributes: {
            campaign_id: "campaign_456",
            email: "user@example.com"
          }
        }
      }.to_json

      klaviyo_integration = EmailIntegration.create!(
        brand: @brand,
        platform: "klaviyo",
        status: "active",
        access_token: "klaviyo_token",
        webhook_secret: "klaviyo_secret"
      )

      # Mock signature verification
      klaviyo_integration.expects(:verify_webhook_signature).returns(true)

      # Mock webhook processor
      processor = mock("EmailWebhookProcessorService")
      processor.expects(:process_engagement_event).with("open", anything)
      Analytics::EmailWebhookProcessorService.expects(:new).returns(processor)

      post "/webhooks/email/klaviyo/#{klaviyo_integration.id}",
           params: payload,
           headers: {
             "Content-Type" => "application/json",
             "X-Klaviyo-Signature" => "valid_signature",
             "X-Klaviyo-Timestamp" => Time.current.to_i.to_s
           }

      assert_response :ok
    end

    test "should return 404 for non-existent integration" do
      payload = { type: "test" }.to_json

      post "/webhooks/email/mailchimp/999999",
           params: payload,
           headers: {
             "Content-Type" => "application/json"
           }

      assert_response :not_found
    end

    test "should return 400 for invalid JSON payload" do
      invalid_payload = "{ invalid json"

      post "/webhooks/email/mailchimp/#{@email_integration.id}",
           params: invalid_payload,
           headers: {
             "Content-Type" => "application/json",
             "X-Mailchimp-Signature" => "signature"
           }

      assert_response :bad_request
    end

    test "should return 422 for unsupported platform" do
      unsupported_integration = EmailIntegration.create!(
        brand: @brand,
        platform: "unsupported",
        status: "active",
        access_token: "token"
      )

      # Override platform validation to create unsupported platform
      unsupported_integration.update_column(:platform, "unsupported")

      payload = { type: "test" }.to_json

      post "/webhooks/email/unsupported/#{unsupported_integration.id}",
           params: payload,
           headers: {
             "Content-Type" => "application/json"
           }

      assert_response :unprocessable_entity
    end

    test "should handle webhook processing errors gracefully" do
      payload = {
        type: "subscribe",
        data: { email: "test@example.com" }
      }.to_json

      # Mock signature verification to pass
      @email_integration.expects(:verify_webhook_signature).returns(true)

      # Mock webhook processor to raise error
      processor = mock("EmailWebhookProcessorService")
      processor.expects(:process_subscriber_event).raises(StandardError.new("Processing failed"))
      Analytics::EmailWebhookProcessorService.expects(:new).returns(processor)

      post "/webhooks/email/mailchimp/#{@email_integration.id}",
           params: payload,
           headers: {
             "Content-Type" => "application/json",
             "X-Mailchimp-Signature" => "valid_signature"
           }

      assert_response :internal_server_error
    end

    test "should handle constant contact webhook events" do
      payload = [
        {
          event_type: "contact.created",
          data: {
            contact_id: "contact_123",
            email_address: "new@example.com",
            first_name: "Jane",
            last_name: "Smith"
          }
        }
      ].to_json

      cc_integration = EmailIntegration.create!(
        brand: @brand,
        platform: "constant_contact",
        status: "active",
        access_token: "cc_token",
        webhook_secret: "cc_secret"
      )

      # Mock signature verification
      cc_integration.expects(:verify_webhook_signature).returns(true)

      # Mock webhook processor
      processor = mock("EmailWebhookProcessorService")
      processor.expects(:process_subscriber_event).with("subscribed", anything)
      Analytics::EmailWebhookProcessorService.expects(:new).returns(processor)

      post "/webhooks/email/constant_contact/#{cc_integration.id}",
           params: payload,
           headers: {
             "Content-Type" => "application/json",
             "X-Constant-Contact-Signature" => "valid_signature"
           }

      assert_response :ok
    end

    test "should handle activecampaign webhook events" do
      payload = {
        type: "contact_add",
        contact: {
          id: "123",
          email: "subscriber@example.com",
          firstName: "Test",
          lastName: "User"
        }
      }.to_json

      ac_integration = EmailIntegration.create!(
        brand: @brand,
        platform: "activecampaign",
        status: "active",
        access_token: "ac_token",
        webhook_secret: "ac_secret"
      )

      # Mock signature verification
      ac_integration.expects(:verify_webhook_signature).returns(true)

      # Mock webhook processor
      processor = mock("EmailWebhookProcessorService")
      processor.expects(:process_subscriber_event).with("subscribed", anything)
      Analytics::EmailWebhookProcessorService.expects(:new).returns(processor)

      post "/webhooks/email/activecampaign/#{ac_integration.id}",
           params: payload,
           headers: {
             "Content-Type" => "application/json",
             "X-AC-Signature" => "valid_signature",
             "X-AC-Timestamp" => Time.current.to_i.to_s
           }

      assert_response :ok
    end

    test "should extract correct signature headers for each platform" do
      # Test that the controller extracts the right signature header for each platform
      platforms_and_headers = {
        "mailchimp" => "X-Mailchimp-Signature",
        "sendgrid" => "X-Twilio-Email-Event-Webhook-Signature", 
        "constant_contact" => "X-Constant-Contact-Signature",
        "campaign_monitor" => "X-CS-Signature",
        "activecampaign" => "X-AC-Signature",
        "klaviyo" => "X-Klaviyo-Signature"
      }

      platforms_and_headers.each do |platform, header_name|
        integration = EmailIntegration.create!(
          brand: @brand,
          platform: platform,
          status: "active",
          access_token: "token",
          webhook_secret: "secret"
        )

        payload = { type: "test" }.to_json

        # Mock signature verification to check if correct header is used
        integration.expects(:verify_webhook_signature).with(payload, "test_signature", anything).returns(true)

        # Mock webhook processor for each platform
        processor = mock("EmailWebhookProcessorService")
        case platform
        when "mailchimp"
          processor.expects(:process_subscriber_event).with("subscribed", anything)
        when "sendgrid"
          # SendGrid processes array of events, so expect once per event
          processor.expects(:process_delivery_event).once
        when "constant_contact"
          processor.expects(:process_subscriber_event).with("subscribed", anything)
        when "activecampaign"
          processor.expects(:process_subscriber_event).with("subscribed", anything)
        when "klaviyo"
          processor.expects(:process_subscriber_event).with("subscribed", anything)
        end
        Analytics::EmailWebhookProcessorService.expects(:new).returns(processor)

        headers = {
          "Content-Type" => "application/json",
          header_name => "test_signature"
        }

        # Add timestamp headers for platforms that need them
        if %w[sendgrid activecampaign klaviyo].include?(platform)
          timestamp_header = case platform
                            when "sendgrid" then "X-Twilio-Email-Event-Webhook-Timestamp"
                            when "activecampaign" then "X-AC-Timestamp"
                            when "klaviyo" then "X-Klaviyo-Timestamp"
                            end
          headers[timestamp_header] = Time.current.to_i.to_s
        end

        # Adjust payload for sendgrid (expects array) and other platforms
        if platform == "sendgrid"
          payload = [{ event: "delivered", email: "test@example.com" }].to_json
        elsif platform == "constant_contact"
          payload = [{ event_type: "contact.created", data: { email: "test@example.com" } }].to_json
        elsif platform == "activecampaign"
          payload = { type: "contact_add", contact: { email: "test@example.com" } }.to_json
        elsif platform == "klaviyo"
          payload = { type: "contact.subscribed", data: { email: "test@example.com" } }.to_json
        else
          payload = { type: "subscribe", data: { email: "test@example.com" } }.to_json
        end

        post "/webhooks/email/#{platform}/#{integration.id}",
             params: payload,
             headers: headers

        assert_response :ok, "Failed for platform: #{platform}"
      end
    end
  end
end