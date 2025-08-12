require "test_helper"

class AiAlertingServiceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  setup do
    @service = AiAlertingService.instance
    @service.cleanup_alert_history(0) # Clear any existing alerts
  end

  test "sends valid alert" do
    result = @service.send_alert(:provider_failure, {
      provider: "test",
      error: "Connection timeout"
    })

    assert result, "Alert should be sent successfully"
    assert_equal 1, @service.alert_history.count
    
    alert = @service.alert_history.first
    assert_equal :provider_failure, alert[:type]
    assert_equal :medium, alert[:severity]
    assert_equal "test", alert[:data][:provider]
  end

  test "respects cooldown periods" do
    # Send first alert
    @service.send_alert(:rate_limit_exceeded, { provider: "test" })
    assert_equal 1, @service.alert_history.count

    # Try to send another alert immediately (should be blocked by cooldown)
    result = @service.send_alert(:rate_limit_exceeded, { provider: "test" })
    assert_not result, "Second alert should be blocked by cooldown"
    assert_equal 1, @service.alert_history.count
  end

  test "escalation logic" do
    alert_type = :circuit_breaker_open
    config = AiAlertingService::ALERT_TYPES[alert_type]
    
    # Send alerts below escalation threshold
    (config[:escalation_threshold] - 1).times do
      @service.send_alert(alert_type, { provider: "test" })
    end
    
    # None should be escalated yet
    escalated_alerts = @service.alert_history.select { |a| a[:escalated] }
    assert_equal 0, escalated_alerts.count

    # This one should trigger escalation
    @service.send_alert(alert_type, { provider: "test" })
    
    escalated_alerts = @service.alert_history.select { |a| a[:escalated] }
    assert escalated_alerts.count > 0, "Should have escalated alerts"
  end

  test "alert statistics calculation" do
    # Send various alerts
    @service.send_alert(:provider_failure, { provider: "test1" })
    @service.send_alert(:rate_limit_exceeded, { provider: "test2" })
    @service.send_alert(:provider_failure, { provider: "test1" }) # Duplicate type

    stats = @service.alert_statistics(1.hour)

    assert_equal 3, stats[:total_alerts]
    assert_equal 2, stats[:alerts_by_type][:provider_failure]
    assert_equal 1, stats[:alerts_by_type][:rate_limit_exceeded]
    assert_equal :provider_failure, stats[:most_frequent_alert]
    assert stats[:alert_rate] > 0
  end

  test "service alert status" do
    provider = "test_provider"
    
    # No alerts - should be healthy
    status = @service.service_alert_status(provider)
    assert_equal :healthy, status[:status]
    assert_empty status[:alerts]

    # Send a critical alert
    @service.send_alert(:fallback_exhausted, { provider: provider })
    
    status = @service.service_alert_status(provider)
    assert_equal :critical, status[:status]
    assert_equal 1, status[:alerts].count
  end

  test "recovery alert sending" do
    provider = "test_provider"
    
    result = @service.send_recovery_alert(provider, { 
      recovery_method: "circuit_breaker_closed" 
    })

    assert result, "Recovery alert should be sent"
    
    alert = @service.alert_history.first
    assert_equal :service_recovery, alert[:type]
    assert_equal provider, alert[:data][:provider]
    assert_equal "circuit_breaker_closed", alert[:data][:recovery_method]
  end

  test "alert history cleanup" do
    # Create old alerts by manipulating timestamps
    old_time = 10.days.ago
    
    # Send some alerts and manually adjust their timestamps
    @service.send_alert(:provider_failure, { provider: "test" })
    @service.send_alert(:rate_limit_exceeded, { provider: "test" })
    
    # Manually set old timestamps
    @service.alert_history[0][:timestamp] = old_time
    
    assert_equal 2, @service.alert_history.count
    
    # Cleanup alerts older than 5 days
    cleaned_count = @service.cleanup_alert_history(5.days)
    
    assert_equal 1, cleaned_count
    assert_equal 1, @service.alert_history.count
  end

  test "invalid alert types are rejected" do
    result = @service.send_alert(:invalid_alert_type, { provider: "test" })
    
    assert_not result, "Invalid alert type should be rejected"
    assert_empty @service.alert_history
  end

  test "alert message generation" do
    test_cases = [
      {
        type: :provider_failure,
        data: { provider: "anthropic", error: "API timeout" },
        expected: "Provider anthropic failed: API timeout"
      },
      {
        type: :rate_limit_exceeded,
        data: { provider: "openai", limit: 100, period: "minute" },
        expected: "Rate limit exceeded for openai. 100 requests per minute"
      },
      {
        type: :manual_override,
        data: { provider: "test", reason: "maintenance" },
        expected: "Manual override activated for test: maintenance"
      }
    ]

    test_cases.each do |test_case|
      message = @service.send(:generate_alert_message, test_case[:type], test_case[:data])
      assert_equal test_case[:expected], message
    end
  end

  test "alert severity levels" do
    AiAlertingService::ALERT_TYPES.each do |type, config|
      severity = config[:severity]
      assert AiAlertingService::SEVERITY_LEVELS.key?(severity), 
        "Alert type #{type} has invalid severity: #{severity}"
    end
  end

  test "alert channel determination" do
    test_cases = [
      { severity: :low, escalated: false, expected: [:rails_log] },
      { severity: :critical, escalated: true, expected: [:rails_log, :console, :email, :slack] }
    ]

    test_cases.each do |test_case|
      channels = @service.send(:determine_alert_channels, test_case[:severity], test_case[:escalated])
      test_case[:expected].each do |expected_channel|
        assert channels.include?(expected_channel), 
          "Expected channel #{expected_channel} for severity #{test_case[:severity]}, escalated: #{test_case[:escalated]}"
      end
    end
  end

  test "slack payload formatting" do
    alert_data = {
      id: "test-123",
      type: :provider_failure,
      severity: :high,
      title: "Provider failure",
      description: "Test provider failed",
      timestamp: Time.current,
      data: { provider: "test" },
      environment: "test"
    }

    payload = @service.send(:build_slack_payload, alert_data, true)

    assert_equal ":exclamation:", payload[:icon_emoji]
    assert payload[:text].include?("[ESCALATED]")
    assert payload[:attachments].first[:color] == "danger"
    
    fields = payload[:attachments].first[:fields]
    provider_field = fields.find { |f| f[:title] == "Provider" }
    assert_equal "test", provider_field[:value]
  end
end