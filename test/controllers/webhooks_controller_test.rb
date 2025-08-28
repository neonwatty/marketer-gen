# frozen_string_literal: true

require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  def setup
    @valid_meta_payload = {
      "object" => "page",
      "entry" => [{
        "id" => "123456789",
        "time" => 1234567890,
        "messaging" => [{
          "type" => "message",
          "sender" => { "id" => "user123" },
          "recipient" => { "id" => "page123" },
          "timestamp" => 1234567890,
          "message" => { "text" => "Hello!" }
        }]
      }]
    }.freeze
    
    @valid_linkedin_payload = {
      "eventType" => "LEAD_GENERATION",
      "data" => {
        "leadId" => "123456",
        "campaignId" => "789012"
      }
    }.freeze
    
    @valid_google_ads_payload = {
      "eventType" => "CAMPAIGN_UPDATE",
      "customerId" => "123-456-7890",
      "data" => {
        "campaignId" => "987654321"
      }
    }.freeze
  end

  test "should accept valid meta webhook with proper headers" do
    post webhooks_meta_path, params: @valid_meta_payload.to_json, headers: {
      "CONTENT_TYPE" => "application/json",
      "X-Hub-Signature-256" => "sha256=test_signature"
    }
    
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_equal "received", response_body["status"]
    assert_equal "meta", response_body["platform"]
  end

  test "should accept valid linkedin webhook" do
    post webhooks_linkedin_path, params: @valid_linkedin_payload.to_json, headers: {
      "CONTENT_TYPE" => "application/json",
      "LinkedIn-Signature" => "sha1=test_signature"
    }
    
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_equal "received", response_body["status"]
    assert_equal "linkedin", response_body["platform"]
  end

  test "should accept valid google ads webhook" do
    post webhooks_google_ads_path, params: @valid_google_ads_payload.to_json, headers: {
      "CONTENT_TYPE" => "application/json",
      "Google-Webhook-Signature" => "sha256=test_signature"
    }
    
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_equal "received", response_body["status"]
    assert_equal "google_ads", response_body["platform"]
  end

  test "should reject webhook with invalid content type" do
    post webhooks_meta_path, params: @valid_meta_payload.to_json, headers: {
      "CONTENT_TYPE" => "text/plain"
    }
    
    assert_response :unsupported_media_type
    response_body = JSON.parse(@response.body)
    assert_equal "Unsupported content type", response_body["error"]
  end

  test "should reject webhook with empty payload" do
    post webhooks_meta_path, params: "", headers: {
      "CONTENT_TYPE" => "application/json"
    }
    
    assert_response :bad_request
    response_body = JSON.parse(@response.body)
    assert_equal "Invalid JSON payload", response_body["error"]
  end

  test "should reject webhook with invalid JSON" do
    post webhooks_meta_path, params: "invalid json", headers: {
      "CONTENT_TYPE" => "application/json"
    }
    
    assert_response :bad_request
    response_body = JSON.parse(@response.body)
    assert_equal "Invalid JSON payload", response_body["error"]
  end

  test "should handle generic webhook with custom platform" do
    post webhooks_path("custom_platform"), params: { "event" => "test" }.to_json, headers: {
      "CONTENT_TYPE" => "application/json"
    }
    
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_equal "received", response_body["status"]
    assert_equal "custom_platform", response_body["platform"]
  end

  test "should verify meta webhook with correct challenge" do
    ENV["META_WEBHOOK_VERIFY_TOKEN"] = "test_token"
    
    get webhooks_verify_path("meta"), params: {
      "hub.mode" => "subscribe",
      "hub.challenge" => "test_challenge",
      "hub.verify_token" => "test_token"
    }
    
    assert_response :success
    assert_equal "test_challenge", @response.body
  end

  test "should reject meta webhook verification with wrong token" do
    ENV["META_WEBHOOK_VERIFY_TOKEN"] = "correct_token"
    
    get webhooks_verify_path("meta"), params: {
      "hub.mode" => "subscribe",
      "hub.challenge" => "test_challenge", 
      "hub.verify_token" => "wrong_token"
    }
    
    assert_response :forbidden
    assert_equal "Forbidden", @response.body
  end

  test "should verify linkedin webhook with challenge" do
    get webhooks_verify_path("linkedin"), params: {
      "challenge" => "linkedin_challenge"
    }
    
    assert_response :success
    assert_equal "linkedin_challenge", @response.body
  end

  test "should verify google ads webhook with correct authorization" do
    ENV["GOOGLE_ADS_WEBHOOK_VERIFY_TOKEN"] = "test_token"
    
    get webhooks_verify_path("google_ads"), headers: {
      "Authorization" => "Bearer test_token"
    }
    
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_equal "verified", response_body["status"]
  end

  test "should reject google ads webhook verification with wrong auth" do
    ENV["GOOGLE_ADS_WEBHOOK_VERIFY_TOKEN"] = "correct_token"
    
    get webhooks_verify_path("google_ads"), headers: {
      "Authorization" => "Bearer wrong_token"
    }
    
    assert_response :unauthorized
    response_body = JSON.parse(@response.body)
    assert_equal "Unauthorized", response_body["error"]
  end

  test "should enqueue webhook processing job" do
    assert_enqueued_with(job: WebhookProcessingJob, args: [@valid_meta_payload, {"http_x_hub_signature_256" => "sha256=test_signature"}, "meta"]) do
      post webhooks_meta_path, params: @valid_meta_payload.to_json, headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Hub-Signature-256" => "sha256=test_signature"
      }
    end
  end

  test "should handle form encoded webhook data" do
    post webhooks_meta_path, params: @valid_meta_payload, headers: {
      "CONTENT_TYPE" => "application/x-www-form-urlencoded"
    }
    
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_equal "received", response_body["status"]
  end

  test "should respect webhook rate limiting" do
    # Mock Rails.env.test? to return false for this test
    Rails.stub(:env, ActiveSupport::StringInquirer.new('production')) do
      # Set up cache to simulate rate limit reached
      client_ip = '127.0.0.1'
      cache_key = "webhook_rate_limit:#{client_ip}"
      Rails.cache.write(cache_key, 500, expires_in: 1.minute)
      
      post webhooks_meta_path, params: @valid_meta_payload.to_json, headers: {
        "CONTENT_TYPE" => "application/json",
        "REMOTE_ADDR" => client_ip
      }
      
      assert_response :too_many_requests
      response_body = JSON.parse(@response.body)
      assert_equal "Rate limit exceeded", response_body["error"]
      
      # Clean up
      Rails.cache.delete(cache_key)
    end
  end

  private

  def webhooks_meta_path
    "/webhooks/meta"
  end

  def webhooks_linkedin_path
    "/webhooks/linkedin"
  end

  def webhooks_google_ads_path
    "/webhooks/google_ads"
  end

  def webhooks_path(platform)
    "/webhooks/#{platform}"
  end

  def webhooks_verify_path(platform)
    "/webhooks/#{platform}/verify"
  end
end