# frozen_string_literal: true

require "test_helper"

class WebhookProcessingServiceTest < ActiveSupport::TestCase
  def setup
    @valid_meta_payload = {
      "object" => "page",
      "entry" => [{
        "id" => "123456789",
        "messaging" => [{
          "type" => "message",
          "sender" => { "id" => "user123" }
        }]
      }]
    }
    
    @valid_linkedin_payload = {
      "eventType" => "LEAD_GENERATION",
      "data" => { "leadId" => "123456" }
    }
    
    @valid_google_ads_payload = {
      "eventType" => "CAMPAIGN_UPDATE", 
      "customerId" => "123-456-7890"
    }
    
    @valid_headers = {
      "x-hub-signature-256" => "sha256=test_signature"
    }
  end

  test "should successfully process valid meta webhook in test environment" do
    result = WebhookProcessingService.call(
      payload: @valid_meta_payload,
      headers: @valid_headers,
      source_platform: "meta"
    )
    
    assert result[:success], "Service should succeed with valid payload"
    assert_equal "meta", result[:data][:platform]
    assert result[:data].key?(:processed_at)
    assert result[:data].key?(:payload_hash)
  end

  test "should successfully process valid linkedin webhook" do
    linkedin_headers = { "linkedin-signature" => "sha1=test_signature" }
    
    result = WebhookProcessingService.call(
      payload: @valid_linkedin_payload,
      headers: linkedin_headers,
      source_platform: "linkedin"
    )
    
    assert result[:success], "Service should succeed with valid LinkedIn payload"
    assert_equal "linkedin", result[:data][:platform]
    assert_equal "LEAD_GENERATION", result[:data][:event_type]
  end

  test "should successfully process valid google ads webhook" do
    google_headers = { "google-webhook-signature" => "sha256=test_signature" }
    
    result = WebhookProcessingService.call(
      payload: @valid_google_ads_payload,
      headers: google_headers,
      source_platform: "google_ads"
    )
    
    assert result[:success], "Service should succeed with valid Google Ads payload"
    assert_equal "google_ads", result[:data][:platform]
    assert_equal "CAMPAIGN_UPDATE", result[:data][:event_type]
  end

  test "should reject empty payload" do
    result = WebhookProcessingService.call(
      payload: nil,
      headers: @valid_headers,
      source_platform: "meta"
    )
    
    assert_not result[:success], "Service should fail with empty payload"
    assert_includes result[:error], "Invalid payload"
  end

  test "should reject blank payload" do
    result = WebhookProcessingService.call(
      payload: "",
      headers: @valid_headers,
      source_platform: "meta"
    )
    
    assert_not result[:success], "Service should fail with blank payload"
    assert_includes result[:error], "Invalid payload"
  end

  test "should handle unsupported platform gracefully" do
    result = WebhookProcessingService.call(
      payload: { "test" => "data" },
      headers: {},
      source_platform: "unsupported_platform"
    )
    
    # Should still process as generic event since signature verification is skipped in test
    assert result[:success], "Service should handle unsupported platforms gracefully"
    assert_equal "unsupported_platform", result[:data][:platform]
  end

  test "should validate meta payload structure" do
    invalid_meta_payload = { "invalid" => "structure" }
    
    result = WebhookProcessingService.call(
      payload: invalid_meta_payload,
      headers: @valid_headers,
      source_platform: "meta"
    )
    
    assert_not result[:success], "Service should fail with invalid Meta payload structure"
    assert_includes result[:error], "Missing required fields"
  end

  test "should validate linkedin payload structure" do
    invalid_linkedin_payload = { "invalid" => "structure" }
    linkedin_headers = { "linkedin-signature" => "sha1=test_signature" }
    
    result = WebhookProcessingService.call(
      payload: invalid_linkedin_payload,
      headers: linkedin_headers,
      source_platform: "linkedin"
    )
    
    assert_not result[:success], "Service should fail with invalid LinkedIn payload structure"
    assert_includes result[:error], "Invalid LinkedIn webhook payload structure"
  end

  test "should validate google ads payload structure" do
    invalid_google_payload = { "invalid" => "structure" }
    google_headers = { "google-webhook-signature" => "sha256=test_signature" }
    
    result = WebhookProcessingService.call(
      payload: invalid_google_payload,
      headers: google_headers,
      source_platform: "google_ads"
    )
    
    assert_not result[:success], "Service should fail with invalid Google Ads payload structure"
    assert_includes result[:error], "Invalid Google Ads webhook payload structure"
  end

  test "should extract correct event types" do
    # Test Meta event type extraction
    result = WebhookProcessingService.call(
      payload: @valid_meta_payload,
      headers: @valid_headers,
      source_platform: "meta"
    )
    
    assert result[:success]
    assert_equal "message", result[:data][:event_type]
    
    # Test LinkedIn event type extraction
    result = WebhookProcessingService.call(
      payload: @valid_linkedin_payload,
      headers: { "linkedin-signature" => "sha1=test" },
      source_platform: "linkedin"
    )
    
    assert result[:success]
    assert_equal "LEAD_GENERATION", result[:data][:event_type]
  end

  test "should generate consistent payload hash" do
    result1 = WebhookProcessingService.call(
      payload: @valid_meta_payload,
      headers: @valid_headers,
      source_platform: "meta"
    )
    
    result2 = WebhookProcessingService.call(
      payload: @valid_meta_payload,
      headers: @valid_headers,
      source_platform: "meta"
    )
    
    assert result1[:success]
    assert result2[:success]
    assert_equal result1[:data][:payload_hash], result2[:data][:payload_hash]
  end

  test "should handle service exceptions gracefully" do
    # Mock a service method to raise an exception
    service = WebhookProcessingService.new(
      payload: @valid_meta_payload,
      headers: @valid_headers,
      source_platform: "meta"
    )
    
    service.stub(:process_webhook_event, -> { raise StandardError, "Test error" }) do
      result = service.call
      assert_not result[:success]
      assert_includes result[:error], "Test error"
    end
  end

  test "should handle different platform configurations" do
    platforms = %w[meta facebook instagram linkedin google_ads]
    
    platforms.each do |platform|
      payload = case platform
                when 'meta', 'facebook', 'instagram'
                  @valid_meta_payload
                when 'linkedin'
                  @valid_linkedin_payload
                when 'google_ads'
                  @valid_google_ads_payload
                end
      
      result = WebhookProcessingService.call(
        payload: payload,
        headers: {},
        source_platform: platform
      )
      
      assert result[:success], "Service should handle #{platform} platform"
      assert_equal platform, result[:data][:platform]
    end
  end

  test "should process generic payloads" do
    generic_payload = { "event_type" => "test_event", "data" => { "key" => "value" } }
    
    result = WebhookProcessingService.call(
      payload: generic_payload,
      headers: {},
      source_platform: "generic"
    )
    
    assert result[:success], "Service should process generic payloads"
    assert_equal "generic", result[:data][:platform]
    assert_equal "test_event", result[:data][:event_type]
  end

  test "should handle hash with indifferent access for headers" do
    string_headers = { "x-hub-signature-256" => "test" }
    symbol_headers = { :"x-hub-signature-256" => "test" }
    
    result1 = WebhookProcessingService.call(
      payload: @valid_meta_payload,
      headers: string_headers,
      source_platform: "meta"
    )
    
    result2 = WebhookProcessingService.call(
      payload: @valid_meta_payload,
      headers: symbol_headers,
      source_platform: "meta"
    )
    
    assert result1[:success]
    assert result2[:success]
  end
end