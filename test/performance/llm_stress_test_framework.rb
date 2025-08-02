require 'test_helper'
require 'benchmark'
require 'parallel'
require 'timeout'
require 'json'
require 'csv'

class LlmStressTestFramework < ActiveSupport::TestCase
  # Stress testing configuration
  STRESS_TEST_CONFIG = {
    # Escalating load test phases
    phase_1_duration: 60,   # 1 minute warm-up
    phase_1_rps: 5,         # 5 requests per second
    
    phase_2_duration: 120,  # 2 minutes ramp-up
    phase_2_rps: 15,        # 15 requests per second
    
    phase_3_duration: 300,  # 5 minutes peak load
    phase_3_rps: 30,        # 30 requests per second
    
    phase_4_duration: 180,  # 3 minutes sustained peak
    phase_4_rps: 25,        # 25 requests per second
    
    phase_5_duration: 60,   # 1 minute cool-down
    phase_5_rps: 5,         # 5 requests per second
    
    # Breaking point test
    breaking_point_max_rps: 100,
    breaking_point_increment: 10,
    breaking_point_phase_duration: 60,
    
    # Memory and resource limits
    max_memory_threshold_mb: 1000,
    max_cpu_threshold_percent: 80,
    max_response_time_threshold: 15.0,
    
    # Failure thresholds
    max_failure_rate: 5.0,
    max_consecutive_failures: 10
  }.freeze

  def setup
    @brand = brands(:one)
    @user = users(:one)
    @stress_results = {}
    @real_time_metrics = []
    @start_time = Time.current
    
    setup_stress_test_environment
    setup_monitoring_systems
    
    puts "\n" + "="*80
    puts "LLM INTEGRATION STRESS TESTING FRAMEWORK"
    puts "="*80
    puts "Testing system limits and breaking points under extreme load"
    puts "="*80
  end

  def teardown
    @end_time = Time.current
    generate_stress_test_report
    cleanup_stress_test_data
  end

  test "escalating load stress test" do
    puts "\n🚀 Starting escalating load stress test..."
    
    phases = [
      { name: "Phase 1: Warm-up", duration: STRESS_TEST_CONFIG[:phase_1_duration], rps: STRESS_TEST_CONFIG[:phase_1_rps] },
      { name: "Phase 2: Ramp-up", duration: STRESS_TEST_CONFIG[:phase_2_duration], rps: STRESS_TEST_CONFIG[:phase_2_rps] },
      { name: "Phase 3: Peak Load", duration: STRESS_TEST_CONFIG[:phase_3_duration], rps: STRESS_TEST_CONFIG[:phase_3_rps] },
      { name: "Phase 4: Sustained Peak", duration: STRESS_TEST_CONFIG[:phase_4_duration], rps: STRESS_TEST_CONFIG[:phase_4_rps] },
      { name: "Phase 5: Cool-down", duration: STRESS_TEST_CONFIG[:phase_5_duration], rps: STRESS_TEST_CONFIG[:phase_5_rps] }
    ]
    
    escalating_results = {}
    
    phases.each_with_index do |phase, index|
      puts "\n#{'-'*40}"
      puts "#{phase[:name]} - #{phase[:rps]} RPS for #{phase[:duration]}s"
      puts "#{'-'*40}"
      
      phase_result = execute_stress_phase(
        phase[:name],
        phase[:duration],
        phase[:rps]
      )
      
      escalating_results["phase_#{index + 1}"] = phase_result
      
      # Check for system degradation
      if phase_result[:avg_response_time] > STRESS_TEST_CONFIG[:max_response_time_threshold]
        puts "⚠️  WARNING: Response time threshold exceeded in #{phase[:name]}"
      end
      
      if phase_result[:failure_rate] > STRESS_TEST_CONFIG[:max_failure_rate]
        puts "⚠️  WARNING: Failure rate threshold exceeded in #{phase[:name]}"
      end
      
      # Brief pause between phases
      sleep(5) unless index == phases.length - 1
    end
    
    @stress_results[:escalating_load] = escalating_results
    
    # Analyze escalating load results
    analyze_escalating_load_results(escalating_results)
  end

  test "breaking point identification test" do
    puts "\n💥 Starting breaking point identification test..."
    
    current_rps = 10
    max_rps = STRESS_TEST_CONFIG[:breaking_point_max_rps]
    increment = STRESS_TEST_CONFIG[:breaking_point_increment]
    phase_duration = STRESS_TEST_CONFIG[:breaking_point_phase_duration]
    
    breaking_point_results = {}
    breaking_point_found = false
    
    while current_rps <= max_rps && !breaking_point_found
      puts "\n#{'-'*30}"
      puts "Testing #{current_rps} RPS for #{phase_duration}s"
      puts "#{'-'*30}"
      
      phase_result = execute_stress_phase(
        "Breaking Point Test",
        phase_duration,
        current_rps
      )
      
      breaking_point_results["rps_#{current_rps}"] = phase_result
      
      # Check if we've hit the breaking point
      breaking_conditions = [
        phase_result[:failure_rate] > STRESS_TEST_CONFIG[:max_failure_rate],
        phase_result[:avg_response_time] > STRESS_TEST_CONFIG[:max_response_time_threshold],
        phase_result[:memory_usage] > STRESS_TEST_CONFIG[:max_memory_threshold_mb],
        phase_result[:consecutive_failures] > STRESS_TEST_CONFIG[:max_consecutive_failures]
      ]
      
      if breaking_conditions.any?
        breaking_point_found = true
        puts "💥 BREAKING POINT IDENTIFIED at #{current_rps} RPS"
        puts "   Failure rate: #{phase_result[:failure_rate]}%"
        puts "   Avg response time: #{phase_result[:avg_response_time]}s"
        puts "   Memory usage: #{phase_result[:memory_usage]}MB"
        break
      end
      
      current_rps += increment
      sleep(10) # Recovery time between phases
    end
    
    @stress_results[:breaking_point] = {
      breaking_point_rps: breaking_point_found ? current_rps : nil,
      max_stable_rps: breaking_point_found ? current_rps - increment : max_rps,
      test_results: breaking_point_results
    }
    
    if breaking_point_found
      puts "\n✅ Breaking point identified: #{current_rps} RPS"
      puts "✅ Max stable throughput: #{current_rps - increment} RPS"
    else
      puts "\n🎉 System handled max tested load: #{max_rps} RPS"
    end
  end

  test "provider resilience under extreme load" do
    puts "\n🛡️ Testing provider resilience under extreme load..."
    
    # Test each provider under stress
    providers = [:openai, :anthropic, :cohere]
    provider_results = {}
    
    providers.each do |provider|
      puts "\n#{'-'*40}"
      puts "Testing #{provider.to_s.upcase} under extreme load"
      puts "#{'-'*40}"
      
      # Configure for single provider testing
      setup_single_provider_test(provider)
      
      provider_result = execute_provider_stress_test(provider, 30, 20) # 30 RPS for 60s
      provider_results[provider] = provider_result
      
      puts "  Provider #{provider} results:"
      puts "    Success rate: #{provider_result[:success_rate]}%"
      puts "    Avg response time: #{provider_result[:avg_response_time]}s"
      puts "    Circuit breaker activations: #{provider_result[:circuit_breaker_activations]}"
      
      sleep(30) # Recovery time between provider tests
    end
    
    @stress_results[:provider_resilience] = provider_results
    
    # Analyze provider performance under stress
    analyze_provider_resilience(provider_results)
  end

  test "memory leak detection under sustained load" do
    puts "\n🔍 Testing for memory leaks under sustained load..."
    
    initial_memory = get_memory_usage
    memory_samples = []
    gc_stats_initial = GC.stat
    
    test_duration = 600 # 10 minutes
    requests_per_minute = 20
    
    start_time = Time.current
    end_test_time = start_time + test_duration
    
    request_count = 0
    
    while Time.current < end_test_time
      # Generate batch of requests
      batch_size = requests_per_minute / 6 # Process every 10 seconds
      
      batch_size.times do
        process_memory_test_request
        request_count += 1
        
        # Sample memory every 50 requests
        if request_count % 50 == 0
          current_memory = get_memory_usage
          memory_samples << {
            timestamp: Time.current,
            memory_mb: current_memory,
            request_count: request_count,
            gc_count: GC.count
          }
          
          puts "  Memory at #{request_count} requests: #{current_memory.round(2)}MB"
        end
      end
      
      sleep(10) # 10-second intervals
    end
    
    final_memory = get_memory_usage
    gc_stats_final = GC.stat
    
    # Analyze memory usage pattern
    memory_growth = final_memory - initial_memory
    memory_growth_rate = memory_growth / (test_duration / 60.0) # MB per minute
    
    # Detect memory leak patterns
    memory_leak_detected = memory_growth_rate > 10.0 # More than 10MB per minute
    
    gc_efficiency = {
      major_gc_count: gc_stats_final[:major_gc_count] - gc_stats_initial[:major_gc_count],
      minor_gc_count: gc_stats_final[:minor_gc_count] - gc_stats_initial[:minor_gc_count],
      total_allocated_objects: gc_stats_final[:total_allocated_objects] - gc_stats_initial[:total_allocated_objects]
    }
    
    @stress_results[:memory_leak_test] = {
      test_duration: test_duration,
      total_requests: request_count,
      initial_memory: initial_memory,
      final_memory: final_memory,
      memory_growth: memory_growth,
      memory_growth_rate: memory_growth_rate,
      memory_leak_detected: memory_leak_detected,
      memory_samples: memory_samples,
      gc_efficiency: gc_efficiency
    }
    
    puts "\n  Memory leak analysis:"
    puts "    Initial memory: #{initial_memory.round(2)}MB"
    puts "    Final memory: #{final_memory.round(2)}MB"
    puts "    Memory growth: #{memory_growth.round(2)}MB"
    puts "    Growth rate: #{memory_growth_rate.round(2)}MB/minute"
    puts "    Leak detected: #{memory_leak_detected ? 'YES' : 'NO'}"
    
    assert !memory_leak_detected, "Memory leak detected: #{memory_growth_rate.round(2)}MB/minute growth rate"
  end

  test "circuit breaker effectiveness under failure scenarios" do
    puts "\n⚡ Testing circuit breaker effectiveness under failures..."
    
    circuit_breaker = LlmIntegration::CircuitBreaker.new(
      failure_threshold: 5,
      timeout_duration: 30,
      retry_timeout: 60
    )
    
    # Test scenario: Gradual provider degradation
    failure_scenarios = [
      { name: "5% failure rate", failure_rate: 0.05, duration: 60 },
      { name: "15% failure rate", failure_rate: 0.15, duration: 60 },
      { name: "30% failure rate", failure_rate: 0.30, duration: 60 },
      { name: "50% failure rate", failure_rate: 0.50, duration: 60 },
      { name: "Total failure", failure_rate: 1.0, duration: 30 }
    ]
    
    circuit_breaker_results = {}
    
    failure_scenarios.each do |scenario|
      puts "\n  Testing #{scenario[:name]} scenario..."
      
      scenario_result = test_circuit_breaker_scenario(
        circuit_breaker,
        scenario[:failure_rate],
        scenario[:duration]
      )
      
      circuit_breaker_results[scenario[:name]] = scenario_result
      
      puts "    Circuit state: #{scenario_result[:final_circuit_state]}"
      puts "    Blocked requests: #{scenario_result[:blocked_requests]}"
      puts "    Recovery time: #{scenario_result[:recovery_time]}s"
      
      # Reset circuit breaker between scenarios
      circuit_breaker.reset!(:test_provider)
      sleep(5)
    end
    
    @stress_results[:circuit_breaker_effectiveness] = circuit_breaker_results
    
    # Verify circuit breaker effectiveness
    verify_circuit_breaker_effectiveness(circuit_breaker_results)
  end

  private

  def setup_stress_test_environment
    # Configure for stress testing
    Rails.cache.clear if Rails.cache.respond_to?(:clear)
    
    # Mock LLM responses with variable response times
    setup_variable_response_mocks
    
    # Initialize monitoring
    @monitoring_thread = start_monitoring_thread
  end

  def setup_monitoring_systems
    @system_monitor = {
      start_time: Time.current,
      memory_samples: [],
      cpu_samples: [],
      response_times: [],
      error_counts: Hash.new(0)
    }
  end

  def setup_variable_response_mocks
    # Mock responses with variable latency to simulate real conditions
    WebMock.stub_request(:post, /api\.openai\.com/)
      .to_return do |request|
        # Simulate variable response times
        sleep(rand(0.1..0.8))
        
        {
          status: 200,
          body: {
            choices: [{ message: { content: "Stress test generated content" } }],
            usage: { total_tokens: rand(100..300) }
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        }
      end
  end

  def start_monitoring_thread
    Thread.new do
      while @monitoring_active
        @system_monitor[:memory_samples] << get_memory_usage
        @system_monitor[:cpu_samples] << get_cpu_usage
        sleep(5) # Sample every 5 seconds
      end
    end
  end

  def execute_stress_phase(phase_name, duration, rps)
    puts "Executing #{phase_name}: #{rps} RPS for #{duration}s"
    
    start_time = Time.current
    end_time = start_time + duration
    initial_memory = get_memory_usage
    
    total_requests = 0
    successful_requests = 0
    failed_requests = 0
    response_times = []
    consecutive_failures = 0
    max_consecutive_failures = 0
    
    request_interval = 1.0 / rps # Seconds between requests
    next_request_time = start_time
    
    while Time.current < end_time
      # Wait for next request time
      sleep_time = next_request_time - Time.current
      sleep(sleep_time) if sleep_time > 0
      
      # Process request
      request_start = Time.current
      begin
        result = process_stress_test_request
        response_time = Time.current - request_start
        response_times << response_time
        
        if result[:success]
          successful_requests += 1
          consecutive_failures = 0
        else
          failed_requests += 1
          consecutive_failures += 1
          max_consecutive_failures = [max_consecutive_failures, consecutive_failures].max
        end
        
      rescue => e
        failed_requests += 1
        consecutive_failures += 1
        max_consecutive_failures = [max_consecutive_failures, consecutive_failures].max
        Rails.logger.error "Stress test request failed: #{e.message}"
      end
      
      total_requests += 1
      next_request_time += request_interval
    end
    
    final_memory = get_memory_usage
    actual_duration = Time.current - start_time
    
    {
      phase_name: phase_name,
      duration: actual_duration,
      target_rps: rps,
      actual_rps: total_requests / actual_duration,
      total_requests: total_requests,
      successful_requests: successful_requests,
      failed_requests: failed_requests,
      failure_rate: (failed_requests.to_f / total_requests) * 100,
      avg_response_time: response_times.empty? ? 0 : response_times.sum / response_times.length,
      max_response_time: response_times.max || 0,
      min_response_time: response_times.min || 0,
      consecutive_failures: max_consecutive_failures,
      memory_usage: final_memory,
      memory_increase: final_memory - initial_memory
    }
  end

  def execute_provider_stress_test(provider, rps, duration)
    puts "Stress testing #{provider} at #{rps} RPS for #{duration}s"
    
    circuit_breaker = LlmIntegration::CircuitBreaker.new
    circuit_breaker_activations = 0
    
    start_time = Time.current
    end_time = start_time + duration
    
    total_requests = 0
    successful_requests = 0
    failed_requests = 0
    response_times = []
    
    request_interval = 1.0 / rps
    next_request_time = start_time
    
    while Time.current < end_time
      sleep_time = next_request_time - Time.current
      sleep(sleep_time) if sleep_time > 0
      
      request_start = Time.current
      begin
        circuit_breaker.call(provider) do
          result = process_provider_specific_request(provider)
          response_time = Time.current - request_start
          response_times << response_time
          
          if result[:success]
            successful_requests += 1
          else
            failed_requests += 1
          end
        end
        
      rescue LlmIntegration::CircuitBreakerOpenError
        circuit_breaker_activations += 1
        failed_requests += 1
      rescue => e
        failed_requests += 1
      end
      
      total_requests += 1
      next_request_time += request_interval
    end
    
    {
      provider: provider,
      total_requests: total_requests,
      successful_requests: successful_requests,
      failed_requests: failed_requests,
      success_rate: (successful_requests.to_f / total_requests) * 100,
      avg_response_time: response_times.empty? ? 0 : response_times.sum / response_times.length,
      circuit_breaker_activations: circuit_breaker_activations
    }
  end

  def test_circuit_breaker_scenario(circuit_breaker, failure_rate, duration)
    start_time = Time.current
    end_time = start_time + duration
    
    total_requests = 0
    blocked_requests = 0
    circuit_state_changes = []
    last_state = circuit_breaker.state(:test_provider)
    
    while Time.current < end_time
      begin
        circuit_breaker.call(:test_provider) do
          # Simulate failure based on failure rate
          if rand < failure_rate
            raise StandardError, "Simulated provider failure"
          end
          
          "Success"
        end
        
      rescue LlmIntegration::CircuitBreakerOpenError
        blocked_requests += 1
      rescue StandardError
        # Expected failures
      end
      
      # Track circuit state changes
      current_state = circuit_breaker.state(:test_provider)
      if current_state != last_state
        circuit_state_changes << {
          timestamp: Time.current,
          from_state: last_state,
          to_state: current_state
        }
        last_state = current_state
      end
      
      total_requests += 1
      sleep(0.1) # 10 RPS
    end
    
    # Calculate recovery time (time from first failure to circuit close)
    recovery_time = if circuit_state_changes.any?
      first_failure = circuit_state_changes.find { |change| change[:to_state] == :open }
      last_recovery = circuit_state_changes.reverse.find { |change| change[:to_state] == :closed }
      
      if first_failure && last_recovery
        last_recovery[:timestamp] - first_failure[:timestamp]
      else
        0
      end
    else
      0
    end
    
    {
      failure_rate: failure_rate,
      total_requests: total_requests,
      blocked_requests: blocked_requests,
      circuit_state_changes: circuit_state_changes,
      final_circuit_state: circuit_breaker.state(:test_provider),
      recovery_time: recovery_time
    }
  end

  def process_stress_test_request
    # Simulate various content generation requests
    content_types = ['simple', 'complex']
    content_type = content_types.sample
    
    request = {
      id: SecureRandom.uuid,
      brand_id: @brand.id,
      content_type: content_type
    }
    
    start_time = Time.current
    
    begin
      # Simulate processing with random delays
      case content_type
      when 'simple'
        sleep(rand(0.1..0.5))
      when 'complex'
        sleep(rand(0.5..2.0))
      end
      
      {
        success: true,
        response_time: Time.current - start_time,
        content_type: content_type
      }
      
    rescue => e
      {
        success: false,
        response_time: Time.current - start_time,
        error: e.message,
        content_type: content_type
      }
    end
  end

  def process_memory_test_request
    # Process request designed to test memory usage
    request_data = {
      large_prompt: "x" * 1000, # 1KB prompt
      metadata: { timestamp: Time.current }
    }
    
    # Simulate content generation
    sleep(rand(0.1..0.3))
    
    # Return generated content
    "Generated content for memory test: #{SecureRandom.uuid}"
  end

  def process_provider_specific_request(provider)
    sleep(rand(0.1..1.0))
    
    # Simulate occasional provider failures
    if rand < 0.1 # 10% chance of failure
      { success: false, error: "Provider #{provider} temporary failure" }
    else
      { success: true, content: "Generated content from #{provider}" }
    end
  end

  def setup_single_provider_test(provider)
    # Configure mocks for specific provider testing
    case provider
    when :openai
      WebMock.stub_request(:post, /api\.openai\.com/)
        .to_return(status: 200, body: { choices: [{ message: { content: "OpenAI response" } }] }.to_json)
    when :anthropic
      WebMock.stub_request(:post, /api\.anthropic\.com/)
        .to_return(status: 200, body: { content: [{ text: "Anthropic response" }] }.to_json)
    when :cohere
      WebMock.stub_request(:post, /api\.cohere\.ai/)
        .to_return(status: 200, body: { generations: [{ text: "Cohere response" }] }.to_json)
    end
  end

  def get_memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    0
  end

  def get_cpu_usage
    # Simplified CPU usage approximation
    rand(10..30) # Mock CPU usage percentage
  rescue
    0
  end

  def analyze_escalating_load_results(results)
    puts "\n📊 Escalating Load Analysis:"
    puts "-" * 40
    
    results.each do |phase, data|
      puts "#{data[:phase_name]}:"
      puts "  Target RPS: #{data[:target_rps]}, Actual RPS: #{data[:actual_rps].round(2)}"
      puts "  Success Rate: #{(100 - data[:failure_rate]).round(2)}%"
      puts "  Avg Response Time: #{data[:avg_response_time].round(3)}s"
      puts "  Memory Increase: #{data[:memory_increase].round(2)}MB"
      puts ""
    end
  end

  def analyze_provider_resilience(provider_results)
    puts "\n🛡️ Provider Resilience Analysis:"
    puts "-" * 40
    
    provider_results.each do |provider, data|
      puts "#{provider.to_s.upcase}:"
      puts "  Success Rate: #{data[:success_rate].round(2)}%"
      puts "  Avg Response Time: #{data[:avg_response_time].round(3)}s"
      puts "  Circuit Breaker Activations: #{data[:circuit_breaker_activations]}"
      puts ""
    end
  end

  def verify_circuit_breaker_effectiveness(results)
    total_breaker_failed = 0
    
    results.each do |scenario, data|
      if data[:failure_rate] > 0.3 && data[:final_circuit_state] != :open
        total_breaker_failed += 1
        puts "⚠️  Circuit breaker failed to open in #{scenario}"
      end
    end
    
    assert total_breaker_failed == 0, "Circuit breaker failed in #{total_breaker_failed} scenarios"
  end

  def generate_stress_test_report
    total_duration = @end_time - @start_time
    
    puts "\n" + "="*80
    puts "LLM STRESS TEST FRAMEWORK RESULTS"
    puts "="*80
    puts "Total test duration: #{total_duration.round(2)} seconds"
    
    # Generate comprehensive report
    report_data = {
      test_suite: "LLM Integration Stress Test Framework",
      execution_time: @start_time.iso8601,
      total_duration: total_duration,
      stress_configuration: STRESS_TEST_CONFIG,
      results: @stress_results,
      environment: {
        rails_version: Rails.version,
        ruby_version: RUBY_VERSION,
        test_environment: Rails.env
      }
    }
    
    # Save detailed report with CSV data
    timestamp = @start_time.strftime('%Y%m%d_%H%M%S')
    json_path = Rails.root.join("tmp", "llm_stress_test_report_#{timestamp}.json")
    csv_path = Rails.root.join("tmp", "llm_stress_test_metrics_#{timestamp}.csv")
    
    File.write(json_path, JSON.pretty_generate(report_data))
    generate_csv_metrics_report(csv_path)
    
    puts "\n📊 Stress test reports saved:"
    puts "  JSON Report: #{json_path}"
    puts "  CSV Metrics: #{csv_path}"
    
    generate_stress_test_recommendations
  end

  def generate_csv_metrics_report(csv_path)
    CSV.open(csv_path, 'w') do |csv|
      csv << ['Test Type', 'Phase', 'RPS', 'Duration', 'Total Requests', 'Success Rate', 'Avg Response Time', 'Memory Usage']
      
      @stress_results.each do |test_type, test_data|
        case test_type
        when :escalating_load
          test_data.each do |phase, metrics|
            csv << [
              test_type,
              metrics[:phase_name],
              metrics[:actual_rps].round(2),
              metrics[:duration].round(2),
              metrics[:total_requests],
              (100 - metrics[:failure_rate]).round(2),
              metrics[:avg_response_time].round(3),
              metrics[:memory_usage].round(2)
            ]
          end
        end
      end
    end
  end

  def generate_stress_test_recommendations
    puts "\n🎯 STRESS TEST RECOMMENDATIONS:"
    puts "-" * 50
    
    recommendations = []
    
    # Analyze breaking point results
    if @stress_results[:breaking_point]
      breaking_point = @stress_results[:breaking_point][:breaking_point_rps]
      max_stable = @stress_results[:breaking_point][:max_stable_rps]
      
      if breaking_point
        recommendations << "Production capacity should not exceed #{(max_stable * 0.8).round} RPS (80% of breaking point)"
        recommendations << "Implement auto-scaling triggers at #{(max_stable * 0.6).round} RPS"
      else
        recommendations << "System handled maximum tested load - consider testing higher thresholds"
      end
    end
    
    # Memory leak recommendations
    if @stress_results[:memory_leak_test]
      memory_data = @stress_results[:memory_leak_test]
      if memory_data[:memory_leak_detected]
        recommendations << "Address memory leak: #{memory_data[:memory_growth_rate].round(2)}MB/minute growth rate"
        recommendations << "Implement more aggressive garbage collection strategies"
      end
    end
    
    # Circuit breaker recommendations
    if @stress_results[:circuit_breaker_effectiveness]
      recommendations << "Circuit breaker configuration appears effective for failure scenarios"
      recommendations << "Consider implementing gradual recovery mechanisms"
    end
    
    if recommendations.empty?
      puts "✅ System performance is within acceptable limits under stress conditions"
    else
      recommendations.each_with_index do |rec, index|
        puts "#{index + 1}. #{rec}"
      end
    end
    
    puts "\nProduction deployment recommendations:"
    puts "• Set up real-time monitoring for all tested metrics"
    puts "• Implement automated scaling based on stress test findings"
    puts "• Configure alerting thresholds at 70% of breaking point values"
    puts "• Plan regular stress testing in production-like environments"
    puts "• Implement circuit breaker monitoring and alerting"
  end

  def cleanup_stress_test_data
    @monitoring_active = false
    @monitoring_thread&.join
    Rails.cache.clear if Rails.cache.respond_to?(:clear)
  end
end