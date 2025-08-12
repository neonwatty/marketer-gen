require "test_helper"

class AiMonitoringIntegrationTest < ActiveSupport::TestCase
  def setup
    # Clear any existing monitoring data
    AiMonitoringService.instance.cleanup_metrics(0)
    AiCostTracker.instance.cleanup_metrics(0)
    AiAlertingService.instance.cleanup_alert_history(0)
  end

  test "monitoring service tracks AI requests" do
    service = create_mock_ai_service
    
    # Simulate an AI request
    result = AiMonitoringService.track_request('test_operation', 'anthropic', 'claude-3-5-haiku-20241022') do
      { content: "Test response", usage: { input_tokens: 100, output_tokens: 50, total_tokens: 150 } }
    end
    
    assert_not_nil result
    assert_equal "Test response", result[:content]
    
    # Check metrics were recorded
    metrics = AiMonitoringService.get_metrics(1.hour)
    assert metrics[:summary][:total_requests] > 0
    assert metrics[:summary][:successful_requests] > 0
    assert metrics[:costs][:total_cost] >= 0
  end

  test "cost tracker calculates costs correctly" do
    usage_data = {
      input_tokens: 1000,
      output_tokens: 500,
      total_tokens: 1500
    }
    
    context = {
      operation_type: 'test_operation',
      operation_id: 'test-123',
      user_id: 'user-456'
    }
    
    cost_result = AiCostTracker.track_cost('anthropic', 'claude-3-5-haiku-20241022', usage_data, context)
    
    assert cost_result[:total] > 0
    assert_equal 'USD', cost_result[:currency]
    assert_equal 1000, cost_result[:tokens_used][:input]
    assert_equal 500, cost_result[:tokens_used][:output]
    
    # Check cost analysis
    analysis = AiCostTracker.cost_analysis(1.hour)
    assert analysis[:summary][:total_cost] > 0
    assert analysis[:by_provider]['anthropic'] > 0
    assert analysis[:by_operation]['test_operation'] > 0
  end

  test "alerting service sends alerts for failures" do
    initial_alert_count = AiAlertingService.instance.alert_history.size
    
    AiAlertingService.send_alert(:provider_failure, {
      provider: 'test_provider',
      error: 'Connection timeout'
    })
    
    assert_equal initial_alert_count + 1, AiAlertingService.instance.alert_history.size
    
    latest_alert = AiAlertingService.instance.alert_history.last
    assert_equal :provider_failure, latest_alert[:type]
    assert_equal 'test_provider', latest_alert[:data][:provider]
  end

  test "monitoring service provides health status" do
    health = AiMonitoringService.health_status
    
    assert_not_nil health[:overall]
    assert_not_nil health[:timestamp]
    assert_not_nil health[:providers]
    assert_not_nil health[:alerts]
    assert_not_nil health[:metrics]
    
    assert health[:metrics].key?(:requests_per_minute)
    assert health[:metrics].key?(:average_response_time)
    assert health[:metrics].key?(:error_rate)
  end

  test "structured logging includes required fields" do
    service = create_mock_ai_service_with_logging
    
    log_entry = service.log_ai_operation(:info, :test_event, { test_data: 'value' })
    
    assert_not_nil log_entry[:timestamp]
    assert_not_nil log_entry[:operation_id]
    assert_equal 'test_event', log_entry[:event_type]
    assert_equal 'ai_service', log_entry[:component]
    assert_equal 'INFO', log_entry[:level]
    assert_equal 'value', log_entry[:test_data]
  end

  test "cost tracker respects budget limits" do
    # Set a low daily budget
    AiCostTracker.set_budget(:daily, 0.01) # $0.01 daily budget
    
    # Track a cost that should trigger an alert
    usage_data = { input_tokens: 10000, output_tokens: 5000, total_tokens: 15000 }
    
    initial_alert_count = AiAlertingService.instance.alert_history.size
    
    AiCostTracker.track_cost('anthropic', 'claude-3-5-sonnet-20241022', usage_data, {
      operation_type: 'expensive_operation'
    })
    
    # Should have triggered a budget alert
    budget_alerts = AiAlertingService.instance.alert_history.select { |a| a[:type] == :budget_threshold }
    assert budget_alerts.size > 0, "Expected budget alert to be sent"
  end

  test "monitoring service exports metrics in different formats" do
    # Add some test metrics
    AiMonitoringService.track_request('test_export', 'anthropic', 'claude-3-5-haiku-20241022') do
      { content: "Test", usage: { total_tokens: 100 } }
    end
    
    # Test Prometheus export
    prometheus_export = AiMonitoringService.export_metrics(:prometheus)
    assert prometheus_export.include?("ai_requests_total")
    assert prometheus_export.include?("ai_cost_usd_total")
    
    # Test JSON export
    json_export = AiMonitoringService.export_metrics(:json)
    parsed_json = JSON.parse(json_export)
    assert parsed_json.key?('summary')
    assert parsed_json.key?('performance')
    assert parsed_json.key?('costs')
  end

  test "performance analysis identifies bottlenecks" do
    # Simulate slow requests
    3.times do
      AiMonitoringService.track_request('slow_operation', 'test_provider', 'test_model') do
        sleep(0.1) # Simulate slow response
        { content: "Slow response" }
      end
    end
    
    performance_analysis = AiMonitoringService.performance_analysis(1.hour)
    
    assert performance_analysis.key?(:response_time_analysis)
    assert performance_analysis.key?(:bottlenecks)
    assert performance_analysis.key?(:recommendations)
    
    # Should detect slow responses
    bottlenecks = performance_analysis[:bottlenecks]
    assert bottlenecks.any?, "Should identify performance bottlenecks"
  end

  private

  def create_mock_ai_service
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include AiStructuredLogging
      
      attribute :provider_name, :string, default: "test"
      attribute :model_name, :string, default: "test-model"
      
      def initialize
        super
      end
    end.new
  end

  def create_mock_ai_service_with_logging
    service = create_mock_ai_service
    service
  end
end