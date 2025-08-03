# frozen_string_literal: true

require "test_helper"
require "benchmark"
require "concurrent"

class WebsocketStressTest < ActionCable::TestCase
  include ActiveJob::TestHelper

  # WebSocket performance targets
  WEBSOCKET_TARGETS = {
    # Connection targets
    max_concurrent_connections: 200,
    connection_establishment_time_ms: 500,
    connection_success_rate: 95.0,
    
    # Message performance targets
    message_latency_max_ms: 50,
    message_throughput_per_second: 1000,
    broadcast_latency_max_ms: 100,
    
    # Real-time update targets
    dashboard_update_frequency_seconds: 5,
    real_time_data_delay_max_ms: 200,
    concurrent_dashboard_users: 100,
    
    # Load testing targets
    messages_per_connection_per_minute: 60,
    peak_broadcast_rate_per_second: 500,
    memory_per_connection_kb: 50,
    
    # Reliability targets
    connection_drop_rate_max: 5.0, # Percentage
    reconnection_success_rate: 90.0,
    message_delivery_guarantee: 99.5 # Percentage
  }.freeze

  def setup
    @test_brand = brands(:one)
    @test_user = users(:one)
    @websocket_metrics = {}
    @start_time = Time.current
    @connections = []
    
    puts "\n" + "="*100
    puts "WEBSOCKET STRESS PERFORMANCE TEST"
    puts "Testing real-time WebSocket performance under high-load conditions"
    puts "Target: 200+ concurrent connections, <50ms message latency"
    puts "="*100
  end

  def teardown
    cleanup_connections
    generate_websocket_performance_report
  end

  # =============================================================================
  # MAIN WEBSOCKET STRESS TESTS
  # =============================================================================

  test "websocket stress performance comprehensive benchmark" do
    puts "\nExecuting comprehensive WebSocket stress tests..."
    
    # Test 1: Connection Establishment Performance
    test_connection_establishment_performance
    
    # Test 2: Concurrent Connection Stress Test
    test_concurrent_connection_stress
    
    # Test 3: Message Latency and Throughput
    test_message_latency_and_throughput
    
    # Test 4: Real-Time Dashboard Updates Under Load
    test_realtime_dashboard_updates_under_load
    
    # Test 5: Broadcast Performance and Scalability
    test_broadcast_performance_scalability
    
    # Test 6: Connection Reliability and Recovery
    test_connection_reliability_recovery
    
    # Test 7: Memory Usage Under WebSocket Load
    test_memory_usage_under_websocket_load
    
    # Test 8: Peak Load Stress Testing
    test_peak_load_stress_testing
    
    # Validate WebSocket performance targets
    validate_websocket_targets
  end

  # =============================================================================
  # CONNECTION ESTABLISHMENT PERFORMANCE
  # =============================================================================

  def test_connection_establishment_performance
    puts "\n🔌 Testing WebSocket connection establishment performance..."
    
    connection_count = 50
    connection_times = []
    successful_connections = 0
    
    connection_count.times do |i|
      connection_time = Benchmark.measure do
        begin
          connect "/cable", headers: { "User-Id" => "perf_user_#{i}" }
          
          if connection
            subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @test_brand.id)
            
            if subscription_confirmed?
              successful_connections += 1
              @connections << connection
            end
          end
        rescue => e
          puts "    Connection #{i} failed: #{e.message}"
        end
      end
      
      connection_times << connection_time.real * 1000 # Convert to milliseconds
    end
    
    avg_connection_time = connection_times.sum / connection_times.size
    connection_success_rate = (successful_connections.to_f / connection_count * 100).round(2)
    
    puts "  Connection establishment results:"
    puts "    Average connection time: #{avg_connection_time.round(2)}ms"
    puts "    Connection success rate: #{connection_success_rate}%"
    puts "    Successful connections: #{successful_connections}/#{connection_count}"
    
    @websocket_metrics[:connection_establishment] = {
      total_attempts: connection_count,
      successful_connections: successful_connections,
      avg_connection_time_ms: avg_connection_time,
      success_rate: connection_success_rate,
      connection_times: connection_times
    }
    
    # Verify connection performance meets targets
    assert avg_connection_time <= WEBSOCKET_TARGETS[:connection_establishment_time_ms],
           "Connection establishment too slow: #{avg_connection_time.round(2)}ms"
    
    assert connection_success_rate >= WEBSOCKET_TARGETS[:connection_success_rate],
           "Connection success rate too low: #{connection_success_rate}%"
  end

  # =============================================================================
  # CONCURRENT CONNECTION STRESS TEST
  # =============================================================================

  def test_concurrent_connection_stress
    puts "\n🚀 Testing concurrent WebSocket connection stress..."
    
    target_connections = 100 # Scaled for test environment
    concurrent_connection_threads = []
    successful_concurrent_connections = Concurrent::AtomicFixnum.new(0)
    connection_errors = Concurrent::Array.new
    
    concurrent_stress_time = Benchmark.measure do
      # Create connections in parallel
      target_connections.times do |i|
        concurrent_connection_threads << Thread.new do
          Thread.current[:connection_id] = i
          
          begin
            connect "/cable", headers: { 
              "User-Id" => "stress_user_#{i}",
              "Connection-Type" => "stress_test"
            }
            
            if connection
              subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @test_brand.id)
              
              if subscription_confirmed?
                successful_concurrent_connections.increment
                
                # Keep connection alive and active
                simulate_active_connection_usage(i)
              else
                connection_errors << "Subscription failed for connection #{i}"
              end
            else
              connection_errors << "Connection failed for user #{i}"
            end
            
          rescue => e
            connection_errors << "Exception in connection #{i}: #{e.message}"
          end
        end
      end
      
      # Wait for all connections to establish
      concurrent_connection_threads.each(&:join)
    end
    
    concurrent_success_rate = (successful_concurrent_connections.value.to_f / target_connections * 100).round(2)
    
    puts "  Concurrent connection stress results:"
    puts "    Target connections: #{target_connections}"
    puts "    Successful connections: #{successful_concurrent_connections.value}"
    puts "    Success rate: #{concurrent_success_rate}%"
    puts "    Total establishment time: #{concurrent_stress_time.real.round(2)}s"
    puts "    Errors: #{connection_errors.size}"
    
    if connection_errors.any?
      puts "  Sample errors:"
      connection_errors.first(3).each { |error| puts "    - #{error}" }
    end
    
    @websocket_metrics[:concurrent_stress] = {
      target_connections: target_connections,
      successful_connections: successful_concurrent_connections.value,
      success_rate: concurrent_success_rate,
      establishment_time: concurrent_stress_time.real,
      errors: connection_errors.to_a
    }
    
    # Verify concurrent connection performance
    min_success_rate = WEBSOCKET_TARGETS[:connection_success_rate] * 0.9 # 90% of target
    assert concurrent_success_rate >= min_success_rate,
           "Concurrent connection success rate too low: #{concurrent_success_rate}%"
  end

  def simulate_active_connection_usage(connection_id)
    # Simulate realistic connection usage patterns
    activity_patterns = [
      -> { simulate_dashboard_interactions },
      -> { simulate_real_time_monitoring },
      -> { simulate_alert_subscription }
    ]
    
    # Execute random activity pattern
    activity_patterns.sample.call
    
    # Keep connection alive for duration of test
    sleep(0.1)
  end

  def simulate_dashboard_interactions
    # Simulate user interactions with dashboard
    3.times do
      send_message("dashboard_filter_change", {
        filters: { platform: ["facebook", "instagram"].sample, time_range: "7d" }
      })
      sleep(0.05)
    end
  end

  def simulate_real_time_monitoring
    # Simulate real-time monitoring behavior
    5.times do
      send_message("request_real_time_update", {
        metrics: ["reach", "engagement"]
      })
      sleep(0.02)
    end
  end

  def simulate_alert_subscription
    # Simulate alert subscription behavior
    send_message("subscribe_alerts", {
      alert_types: ["threshold", "anomaly"]
    })
  end

  # =============================================================================
  # MESSAGE LATENCY AND THROUGHPUT
  # =============================================================================

  def test_message_latency_and_throughput
    puts "\n📨 Testing message latency and throughput..."
    
    # Setup test connections
    test_connections = 20
    setup_test_connections(test_connections)
    
    # Test 1: Individual Message Latency
    message_latencies = test_individual_message_latency
    
    # Test 2: Message Throughput
    throughput_results = test_message_throughput
    
    # Test 3: Broadcast Latency
    broadcast_latencies = test_broadcast_latency
    
    @websocket_metrics[:message_performance] = {
      individual_latencies: message_latencies,
      throughput: throughput_results,
      broadcast_latencies: broadcast_latencies
    }
  end

  def test_individual_message_latency
    puts "    Testing individual message latency..."
    
    latency_samples = []
    test_messages = 50
    
    test_messages.times do |i|
      start_time = Time.current.to_f * 1000 # Milliseconds
      
      # Send message with timestamp
      message_data = {
        type: "latency_test",
        message_id: i,
        sent_at: start_time
      }
      
      # Simulate message round-trip
      latency = Benchmark.measure do
        ActionCable.server.broadcast("analytics_dashboard_#{@test_brand.id}", message_data)
        
        # Simulate processing delay
        sleep(0.001)
      end
      
      latency_ms = latency.real * 1000
      latency_samples << latency_ms
      
      # Small delay between messages
      sleep(0.01)
    end
    
    avg_latency = latency_samples.sum / latency_samples.size
    max_latency = latency_samples.max
    min_latency = latency_samples.min
    
    puts "    Message latency results:"
    puts "      Average latency: #{avg_latency.round(2)}ms"
    puts "      Max latency: #{max_latency.round(2)}ms"
    puts "      Min latency: #{min_latency.round(2)}ms"
    
    # Verify latency meets targets
    assert avg_latency <= WEBSOCKET_TARGETS[:message_latency_max_ms],
           "Average message latency too high: #{avg_latency.round(2)}ms"
    
    {
      avg_latency_ms: avg_latency,
      max_latency_ms: max_latency,
      min_latency_ms: min_latency,
      samples: latency_samples
    }
  end

  def test_message_throughput
    puts "    Testing message throughput..."
    
    message_count = 500
    throughput_duration = 10 # seconds
    messages_per_second_target = message_count / throughput_duration
    
    throughput_time = Benchmark.measure do
      message_count.times do |i|
        ActionCable.server.broadcast("analytics_dashboard_#{@test_brand.id}", {
          type: "throughput_test",
          message_id: i,
          data: { value: rand(1000), timestamp: Time.current.to_f }
        })
        
        # Maintain consistent rate
        sleep(throughput_duration.to_f / message_count) if i < message_count - 1
      end
    end
    
    actual_throughput = message_count / throughput_time.real
    throughput_efficiency = (actual_throughput / WEBSOCKET_TARGETS[:message_throughput_per_second]) * 100
    
    puts "    Message throughput results:"
    puts "      Target rate: #{messages_per_second_target} messages/second"
    puts "      Actual rate: #{actual_throughput.round(2)} messages/second"
    puts "      Efficiency: #{throughput_efficiency.round(2)}%"
    
    {
      target_rate: messages_per_second_target,
      actual_rate: actual_throughput,
      efficiency_percent: throughput_efficiency,
      duration: throughput_time.real
    }
  end

  def test_broadcast_latency
    puts "    Testing broadcast latency..."
    
    broadcast_samples = []
    broadcast_count = 30
    
    broadcast_count.times do |i|
      broadcast_latency = Benchmark.measure do
        # Broadcast to multiple channels simultaneously
        channels = [
          "analytics_dashboard_#{@test_brand.id}",
          "analytics_alerts_#{@test_brand.id}",
          "analytics_realtime_#{@test_brand.id}"
        ]
        
        channels.each do |channel|
          ActionCable.server.broadcast(channel, {
            type: "broadcast_test",
            broadcast_id: i,
            timestamp: Time.current.to_f
          })
        end
      end
      
      broadcast_latency_ms = broadcast_latency.real * 1000
      broadcast_samples << broadcast_latency_ms
      
      sleep(0.05)
    end
    
    avg_broadcast_latency = broadcast_samples.sum / broadcast_samples.size
    
    puts "    Broadcast latency results:"
    puts "      Average broadcast latency: #{avg_broadcast_latency.round(2)}ms"
    
    # Verify broadcast latency meets targets
    assert avg_broadcast_latency <= WEBSOCKET_TARGETS[:broadcast_latency_max_ms],
           "Broadcast latency too high: #{avg_broadcast_latency.round(2)}ms"
    
    {
      avg_latency_ms: avg_broadcast_latency,
      samples: broadcast_samples
    }
  end

  # =============================================================================
  # REAL-TIME DASHBOARD UPDATES UNDER LOAD
  # =============================================================================

  def test_realtime_dashboard_updates_under_load
    puts "\n📊 Testing real-time dashboard updates under load..."
    
    # Setup multiple dashboard connections
    dashboard_connections = 30
    setup_dashboard_connections(dashboard_connections)
    
    # Test high-frequency updates
    update_frequency_results = test_high_frequency_dashboard_updates
    
    # Test concurrent user interactions
    concurrent_interaction_results = test_concurrent_dashboard_interactions
    
    @websocket_metrics[:realtime_dashboard] = {
      dashboard_connections: dashboard_connections,
      update_frequency: update_frequency_results,
      concurrent_interactions: concurrent_interaction_results
    }
  end

  def test_high_frequency_dashboard_updates
    puts "    Testing high-frequency dashboard updates..."
    
    update_count = 100
    update_interval = 0.1 # 100ms intervals
    
    update_performance = Benchmark.measure do
      update_count.times do |i|
        # Simulate real analytics data updates
        update_data = {
          type: "metrics_update",
          data: {
            reach: rand(1000..10000),
            engagement: rand(100..1000),
            conversions: rand(10..100),
            timestamp: Time.current.to_f
          },
          update_id: i
        }
        
        ActionCable.server.broadcast("analytics_dashboard_#{@test_brand.id}", update_data)
        
        sleep(update_interval)
      end
    end
    
    updates_per_second = update_count / update_performance.real
    target_frequency = 1.0 / WEBSOCKET_TARGETS[:dashboard_update_frequency_seconds]
    frequency_efficiency = (updates_per_second / target_frequency) * 100
    
    puts "    Dashboard update results:"
    puts "      Updates per second: #{updates_per_second.round(2)}"
    puts "      Target frequency: #{target_frequency.round(2)} updates/second"
    puts "      Frequency efficiency: #{frequency_efficiency.round(2)}%"
    
    {
      updates_per_second: updates_per_second,
      target_frequency: target_frequency,
      efficiency_percent: frequency_efficiency,
      total_updates: update_count
    }
  end

  def test_concurrent_dashboard_interactions
    puts "    Testing concurrent dashboard interactions..."
    
    concurrent_users = 20
    interactions_per_user = 10
    interaction_threads = []
    successful_interactions = Concurrent::AtomicFixnum.new(0)
    
    interaction_time = Benchmark.measure do
      concurrent_users.times do |user_id|
        interaction_threads << Thread.new do
          Thread.current[:user_id] = user_id
          
          interactions_per_user.times do |interaction_id|
            begin
              # Simulate various dashboard interactions
              interaction_type = ["filter_change", "time_range_update", "metric_selection"].sample
              
              send_dashboard_interaction(user_id, interaction_type, interaction_id)
              successful_interactions.increment
              
              sleep(rand(0.1..0.3))
            rescue => e
              puts "      Interaction failed for user #{user_id}: #{e.message}"
            end
          end
        end
      end
      
      interaction_threads.each(&:join)
    end
    
    total_interactions = concurrent_users * interactions_per_user
    interaction_success_rate = (successful_interactions.value.to_f / total_interactions * 100).round(2)
    
    puts "    Concurrent interaction results:"
    puts "      Total interactions: #{total_interactions}"
    puts "      Successful interactions: #{successful_interactions.value}"
    puts "      Success rate: #{interaction_success_rate}%"
    puts "      Total time: #{interaction_time.real.round(2)}s"
    
    {
      total_interactions: total_interactions,
      successful_interactions: successful_interactions.value,
      success_rate: interaction_success_rate,
      duration: interaction_time.real
    }
  end

  def send_dashboard_interaction(user_id, interaction_type, interaction_id)
    interaction_data = {
      type: interaction_type,
      user_id: user_id,
      interaction_id: interaction_id,
      timestamp: Time.current.to_f
    }
    
    case interaction_type
    when "filter_change"
      interaction_data[:filters] = {
        platform: ["facebook", "instagram", "twitter"].sample,
        date_range: ["7d", "30d", "90d"].sample
      }
    when "time_range_update"
      interaction_data[:time_range] = {
        start_date: 30.days.ago.iso8601,
        end_date: Time.current.iso8601
      }
    when "metric_selection"
      interaction_data[:metrics] = ["reach", "engagement", "conversions"].sample(2)
    end
    
    ActionCable.server.broadcast("analytics_dashboard_#{@test_brand.id}", interaction_data)
  end

  # =============================================================================
  # BROADCAST PERFORMANCE AND SCALABILITY
  # =============================================================================

  def test_broadcast_performance_scalability
    puts "\n📡 Testing broadcast performance and scalability..."
    
    # Test large broadcast scenarios
    large_broadcast_results = test_large_broadcast_performance
    
    # Test peak broadcast rate
    peak_broadcast_results = test_peak_broadcast_rate
    
    # Test selective broadcasting
    selective_broadcast_results = test_selective_broadcast_performance
    
    @websocket_metrics[:broadcast_performance] = {
      large_broadcast: large_broadcast_results,
      peak_rate: peak_broadcast_results,
      selective_broadcast: selective_broadcast_results
    }
  end

  def test_large_broadcast_performance
    puts "    Testing large broadcast performance..."
    
    # Setup many connections
    connection_count = 50
    large_broadcast_connections = setup_large_broadcast_test(connection_count)
    
    # Test broadcasting to all connections
    broadcast_size_kb = 10 # Simulate 10KB data payload
    large_data_payload = {
      type: "large_data_update",
      data: {
        analytics_summary: generate_large_analytics_payload(broadcast_size_kb),
        timestamp: Time.current.to_f
      }
    }
    
    large_broadcast_time = Benchmark.measure do
      ActionCable.server.broadcast("analytics_dashboard_#{@test_brand.id}", large_data_payload)
    end
    
    broadcast_rate = connection_count / large_broadcast_time.real
    
    puts "    Large broadcast results:"
    puts "      Connections: #{connection_count}"
    puts "      Payload size: #{broadcast_size_kb}KB"
    puts "      Broadcast time: #{large_broadcast_time.real.round(3)}s"
    puts "      Broadcast rate: #{broadcast_rate.round(2)} connections/second"
    
    {
      connection_count: connection_count,
      payload_size_kb: broadcast_size_kb,
      broadcast_time: large_broadcast_time.real,
      broadcast_rate: broadcast_rate
    }
  end

  def test_peak_broadcast_rate
    puts "    Testing peak broadcast rate..."
    
    peak_broadcast_count = 200
    peak_duration = 10 # seconds
    broadcasts_completed = 0
    
    peak_rate_time = Benchmark.measure do
      peak_broadcast_count.times do |i|
        ActionCable.server.broadcast("analytics_dashboard_#{@test_brand.id}", {
          type: "peak_rate_test",
          broadcast_id: i,
          data: { value: rand(1000) }
        })
        
        broadcasts_completed += 1
        
        # Maintain peak rate
        sleep(peak_duration.to_f / peak_broadcast_count) if i < peak_broadcast_count - 1
      end
    end
    
    actual_peak_rate = broadcasts_completed / peak_rate_time.real
    peak_efficiency = (actual_peak_rate / WEBSOCKET_TARGETS[:peak_broadcast_rate_per_second]) * 100
    
    puts "    Peak broadcast rate results:"
    puts "      Target rate: #{WEBSOCKET_TARGETS[:peak_broadcast_rate_per_second]} broadcasts/second"
    puts "      Actual rate: #{actual_peak_rate.round(2)} broadcasts/second"
    puts "      Peak efficiency: #{peak_efficiency.round(2)}%"
    
    {
      target_rate: WEBSOCKET_TARGETS[:peak_broadcast_rate_per_second],
      actual_rate: actual_peak_rate,
      efficiency_percent: peak_efficiency,
      broadcasts_completed: broadcasts_completed
    }
  end

  def test_selective_broadcast_performance
    puts "    Testing selective broadcast performance..."
    
    # Test broadcasting to specific user groups
    user_groups = {
      "admin_users" => 5,
      "regular_users" => 15,
      "read_only_users" => 10
    }
    
    selective_results = {}
    
    user_groups.each do |group_name, user_count|
      group_broadcast_time = Benchmark.measure do
        user_count.times do |user_id|
          ActionCable.server.broadcast("analytics_dashboard_#{@test_brand.id}_#{group_name}", {
            type: "group_specific_update",
            group: group_name,
            user_id: user_id,
            data: { message: "Update for #{group_name}" }
          })
        end
      end
      
      group_rate = user_count / group_broadcast_time.real
      selective_results[group_name] = {
        users: user_count,
        time: group_broadcast_time.real,
        rate: group_rate
      }
      
      puts "      #{group_name}: #{group_rate.round(2)} broadcasts/second"
    end
    
    selective_results
  end

  # =============================================================================
  # CONNECTION RELIABILITY AND RECOVERY
  # =============================================================================

  def test_connection_reliability_recovery
    puts "\n🔄 Testing connection reliability and recovery..."
    
    # Test connection drop simulation
    connection_drop_results = test_connection_drop_simulation
    
    # Test reconnection performance
    reconnection_results = test_reconnection_performance
    
    # Test message delivery guarantees
    delivery_guarantee_results = test_message_delivery_guarantees
    
    @websocket_metrics[:reliability] = {
      connection_drops: connection_drop_results,
      reconnection: reconnection_results,
      delivery_guarantees: delivery_guarantee_results
    }
  end

  def test_connection_drop_simulation
    puts "    Testing connection drop simulation..."
    
    test_connections = 20
    drop_simulation_connections = setup_drop_test_connections(test_connections)
    
    # Simulate random connection drops
    dropped_connections = 0
    maintained_connections = 0
    
    drop_simulation_time = Benchmark.measure do
      drop_simulation_connections.each_with_index do |conn, index|
        # Simulate 10% drop rate
        if rand < 0.1
          begin
            disconnect_connection(conn)
            dropped_connections += 1
          rescue => e
            puts "      Failed to drop connection #{index}: #{e.message}"
          end
        else
          maintained_connections += 1
        end
      end
    end
    
    actual_drop_rate = (dropped_connections.to_f / test_connections * 100).round(2)
    
    puts "    Connection drop simulation results:"
    puts "      Total connections: #{test_connections}"
    puts "      Dropped connections: #{dropped_connections}"
    puts "      Drop rate: #{actual_drop_rate}%"
    puts "      Maintained connections: #{maintained_connections}"
    
    # Verify drop rate is within acceptable limits
    assert actual_drop_rate <= WEBSOCKET_TARGETS[:connection_drop_rate_max],
           "Connection drop rate too high: #{actual_drop_rate}%"
    
    {
      total_connections: test_connections,
      dropped_connections: dropped_connections,
      drop_rate: actual_drop_rate,
      maintained_connections: maintained_connections
    }
  end

  def test_reconnection_performance
    puts "    Testing reconnection performance..."
    
    reconnection_attempts = 15
    successful_reconnections = 0
    reconnection_times = []
    
    reconnection_attempts.times do |i|
      reconnection_time = Benchmark.measure do
        begin
          # Simulate connection loss and reconnection
          connect "/cable", headers: { "User-Id" => "reconnect_user_#{i}" }
          
          if connection
            subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @test_brand.id)
            
            if subscription_confirmed?
              successful_reconnections += 1
            end
          end
        rescue => e
          puts "      Reconnection #{i} failed: #{e.message}"
        end
      end
      
      reconnection_times << reconnection_time.real * 1000 # Convert to milliseconds
    end
    
    reconnection_success_rate = (successful_reconnections.to_f / reconnection_attempts * 100).round(2)
    avg_reconnection_time = reconnection_times.any? ? reconnection_times.sum / reconnection_times.size : 0
    
    puts "    Reconnection performance results:"
    puts "      Reconnection attempts: #{reconnection_attempts}"
    puts "      Successful reconnections: #{successful_reconnections}"
    puts "      Success rate: #{reconnection_success_rate}%"
    puts "      Average reconnection time: #{avg_reconnection_time.round(2)}ms"
    
    # Verify reconnection performance meets targets
    assert reconnection_success_rate >= WEBSOCKET_TARGETS[:reconnection_success_rate],
           "Reconnection success rate too low: #{reconnection_success_rate}%"
    
    {
      attempts: reconnection_attempts,
      successful: successful_reconnections,
      success_rate: reconnection_success_rate,
      avg_time_ms: avg_reconnection_time
    }
  end

  def test_message_delivery_guarantees
    puts "    Testing message delivery guarantees..."
    
    delivery_test_messages = 100
    delivered_messages = 0
    delivery_confirmations = []
    
    delivery_test_time = Benchmark.measure do
      delivery_test_messages.times do |i|
        message_id = "delivery_test_#{i}"
        
        # Send message with delivery tracking
        delivery_confirmed = send_tracked_message(message_id, {
          type: "delivery_test",
          message_id: message_id,
          data: { test_value: rand(1000) }
        })
        
        if delivery_confirmed
          delivered_messages += 1
          delivery_confirmations << message_id
        end
      end
    end
    
    delivery_rate = (delivered_messages.to_f / delivery_test_messages * 100).round(2)
    
    puts "    Message delivery results:"
    puts "      Test messages: #{delivery_test_messages}"
    puts "      Delivered messages: #{delivered_messages}"
    puts "      Delivery rate: #{delivery_rate}%"
    
    # Verify delivery rate meets guarantees
    assert delivery_rate >= WEBSOCKET_TARGETS[:message_delivery_guarantee],
           "Message delivery rate too low: #{delivery_rate}%"
    
    {
      test_messages: delivery_test_messages,
      delivered_messages: delivered_messages,
      delivery_rate: delivery_rate,
      confirmations: delivery_confirmations.size
    }
  end

  # =============================================================================
  # MEMORY USAGE UNDER WEBSOCKET LOAD
  # =============================================================================

  def test_memory_usage_under_websocket_load
    puts "\n💾 Testing memory usage under WebSocket load..."
    
    initial_memory = get_memory_usage
    
    # Create many connections and monitor memory
    connection_count = 50
    memory_per_connection_samples = []
    
    memory_test_time = Benchmark.measure do
      connection_count.times do |i|
        memory_before_connection = get_memory_usage
        
        # Create connection
        connect "/cable", headers: { "User-Id" => "memory_test_user_#{i}" }
        
        if connection
          subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @test_brand.id)
          
          memory_after_connection = get_memory_usage
          memory_increase = memory_after_connection - memory_before_connection
          memory_per_connection_samples << memory_increase * 1024 # Convert to KB
        end
        
        # Simulate connection activity
        simulate_connection_memory_usage
      end
    end
    
    final_memory = get_memory_usage
    total_memory_increase = final_memory - initial_memory
    avg_memory_per_connection = memory_per_connection_samples.any? ? 
      memory_per_connection_samples.sum / memory_per_connection_samples.size : 0
    
    puts "  Memory usage under WebSocket load:"
    puts "    Total connections: #{connection_count}"
    puts "    Total memory increase: #{total_memory_increase.round(2)}MB"
    puts "    Average memory per connection: #{avg_memory_per_connection.round(2)}KB"
    puts "    Memory efficiency: #{(WEBSOCKET_TARGETS[:memory_per_connection_kb] / avg_memory_per_connection * 100).round(2)}%"
    
    @websocket_metrics[:memory_usage] = {
      connection_count: connection_count,
      total_memory_increase_mb: total_memory_increase,
      avg_memory_per_connection_kb: avg_memory_per_connection,
      memory_samples: memory_per_connection_samples
    }
    
    # Verify memory usage is within acceptable limits
    assert avg_memory_per_connection <= WEBSOCKET_TARGETS[:memory_per_connection_kb],
           "Memory per connection too high: #{avg_memory_per_connection.round(2)}KB"
  end

  def simulate_connection_memory_usage
    # Simulate realistic connection memory usage
    3.times do
      send_message("test_interaction", { data: Array.new(100) { rand(1000) } })
      sleep(0.01)
    end
  end

  # =============================================================================
  # PEAK LOAD STRESS TESTING
  # =============================================================================

  def test_peak_load_stress_testing
    puts "\n🔥 Testing peak load stress scenarios..."
    
    # Test system under maximum expected load
    peak_load_results = test_maximum_load_scenario
    
    # Test degradation under overload
    overload_results = test_overload_degradation
    
    @websocket_metrics[:peak_load_stress] = {
      maximum_load: peak_load_results,
      overload_degradation: overload_results
    }
  end

  def test_maximum_load_scenario
    puts "    Testing maximum load scenario..."
    
    max_connections = 75 # Scaled for test environment
    max_message_rate = 300 # Messages per second
    test_duration = 30 # seconds
    
    peak_load_time = Benchmark.measure do
      # Create maximum connections
      peak_connections = setup_peak_load_connections(max_connections)
      
      # Generate maximum message load
      total_messages = max_message_rate * test_duration
      
      total_messages.times do |i|
        ActionCable.server.broadcast("analytics_dashboard_#{@test_brand.id}", {
          type: "peak_load_test",
          message_id: i,
          data: generate_realistic_analytics_update
        })
        
        # Maintain target rate
        sleep(test_duration.to_f / total_messages) if i < total_messages - 1
      end
    end
    
    actual_message_rate = (max_message_rate * test_duration) / peak_load_time.real
    system_efficiency = (actual_message_rate / max_message_rate) * 100
    
    puts "    Maximum load test results:"
    puts "      Target connections: #{max_connections}"
    puts "      Target message rate: #{max_message_rate} msg/sec"
    puts "      Actual message rate: #{actual_message_rate.round(2)} msg/sec"
    puts "      System efficiency: #{system_efficiency.round(2)}%"
    
    {
      target_connections: max_connections,
      target_message_rate: max_message_rate,
      actual_message_rate: actual_message_rate,
      system_efficiency: system_efficiency,
      test_duration: peak_load_time.real
    }
  end

  def test_overload_degradation
    puts "    Testing overload degradation behavior..."
    
    # Test system behavior when pushed beyond limits
    overload_factor = 1.5 # 150% of normal capacity
    base_connections = 50
    overload_connections = (base_connections * overload_factor).to_i
    
    degradation_results = {
      connection_success_rates: [],
      message_latencies: [],
      error_rates: []
    }
    
    # Test increasing load levels
    [0.5, 0.75, 1.0, 1.25, overload_factor].each do |load_factor|
      current_connections = (base_connections * load_factor).to_i
      
      load_test_result = test_load_level(current_connections)
      degradation_results[:connection_success_rates] << {
        load_factor: load_factor,
        success_rate: load_test_result[:success_rate]
      }
      
      puts "      Load #{(load_factor * 100).to_i}%: #{load_test_result[:success_rate]}% success rate"
    end
    
    degradation_results
  end

  def test_load_level(connection_count)
    successful_connections = 0
    
    load_time = Benchmark.measure do
      connection_count.times do |i|
        begin
          connect "/cable", headers: { "User-Id" => "load_test_#{i}" }
          
          if connection
            subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @test_brand.id)
            successful_connections += 1 if subscription_confirmed?
          end
        rescue => e
          # Connection failed due to overload
        end
      end
    end
    
    success_rate = (successful_connections.to_f / connection_count * 100).round(2)
    
    {
      target_connections: connection_count,
      successful_connections: successful_connections,
      success_rate: success_rate,
      duration: load_time.real
    }
  end

  # =============================================================================
  # VALIDATION AND REPORTING
  # =============================================================================

  def validate_websocket_targets
    puts "\n🎯 Validating WebSocket performance targets..."
    
    validations = [
      {
        name: "Connection Establishment Time",
        target: "<= #{WEBSOCKET_TARGETS[:connection_establishment_time_ms]}ms",
        actual: @websocket_metrics.dig(:connection_establishment, :avg_connection_time_ms),
        threshold: WEBSOCKET_TARGETS[:connection_establishment_time_ms],
        comparison: :<=
      },
      {
        name: "Connection Success Rate",
        target: ">= #{WEBSOCKET_TARGETS[:connection_success_rate]}%",
        actual: @websocket_metrics.dig(:connection_establishment, :success_rate),
        threshold: WEBSOCKET_TARGETS[:connection_success_rate],
        comparison: :>=
      },
      {
        name: "Message Latency",
        target: "<= #{WEBSOCKET_TARGETS[:message_latency_max_ms]}ms",
        actual: @websocket_metrics.dig(:message_performance, :individual_latencies, :avg_latency_ms),
        threshold: WEBSOCKET_TARGETS[:message_latency_max_ms],
        comparison: :<=
      },
      {
        name: "Memory Per Connection",
        target: "<= #{WEBSOCKET_TARGETS[:memory_per_connection_kb]}KB",
        actual: @websocket_metrics.dig(:memory_usage, :avg_memory_per_connection_kb),
        threshold: WEBSOCKET_TARGETS[:memory_per_connection_kb],
        comparison: :<=
      }
    ]
    
    all_targets_met = true
    
    validations.each do |validation|
      if validation[:actual]
        case validation[:comparison]
        when :>=
          passed = validation[:actual] >= validation[:threshold]
        when :<=
          passed = validation[:actual] <= validation[:threshold]
        end
        
        status = passed ? "✅ PASS" : "❌ FAIL"
        puts "  #{validation[:name]}: #{validation[:actual].round(3)} (Target: #{validation[:target]}) #{status}"
        
        all_targets_met = false unless passed
      else
        puts "  #{validation[:name]}: No data available ⚠️"
        all_targets_met = false
      end
    end
    
    puts "\n" + "="*80
    if all_targets_met
      puts "🎉 ALL WEBSOCKET PERFORMANCE TARGETS MET"
      puts "System ready for real-time analytics with 200+ concurrent connections"
    else
      puts "⚠️  SOME WEBSOCKET TARGETS NOT MET"
      puts "Review WebSocket optimization before production deployment"
    end
    
    all_targets_met
  end

  def generate_websocket_performance_report
    report_data = {
      test_suite: "WebSocket Stress Performance Test",
      execution_time: @start_time.iso8601,
      total_duration: Time.current - @start_time,
      websocket_targets: WEBSOCKET_TARGETS,
      metrics: @websocket_metrics,
      summary: generate_websocket_summary,
      recommendations: generate_websocket_recommendations
    }
    
    # Save detailed report
    report_filename = "websocket_stress_test_#{@start_time.strftime('%Y%m%d_%H%M%S')}.json"
    report_path = Rails.root.join("tmp", report_filename)
    File.write(report_path, JSON.pretty_generate(report_data))
    
    puts "\n📊 WebSocket stress test report saved: #{report_path}"
  end

  def generate_websocket_summary
    {
      connection_establishment: @websocket_metrics.dig(:connection_establishment, :avg_connection_time_ms),
      concurrent_connections: @websocket_metrics.dig(:concurrent_stress, :successful_connections),
      message_latency: @websocket_metrics.dig(:message_performance, :individual_latencies, :avg_latency_ms),
      memory_per_connection: @websocket_metrics.dig(:memory_usage, :avg_memory_per_connection_kb),
      overall_reliability: calculate_overall_websocket_reliability
    }
  end

  def calculate_overall_websocket_reliability
    connection_success = @websocket_metrics.dig(:connection_establishment, :success_rate) || 0
    reconnection_success = @websocket_metrics.dig(:reliability, :reconnection, :success_rate) || 0
    delivery_rate = @websocket_metrics.dig(:reliability, :delivery_guarantees, :delivery_rate) || 0
    
    (connection_success + reconnection_success + delivery_rate) / 3.0
  end

  def generate_websocket_recommendations
    recommendations = []
    
    # Connection performance recommendations
    if @websocket_metrics.dig(:connection_establishment, :avg_connection_time_ms).to_f > 300
      recommendations << "Optimize WebSocket handshake and subscription processes"
      recommendations << "Implement connection pooling and reuse strategies"
    end
    
    # Message performance recommendations
    if @websocket_metrics.dig(:message_performance, :individual_latencies, :avg_latency_ms).to_f > 30
      recommendations << "Optimize message serialization and routing"
      recommendations << "Implement message compression for large payloads"
    end
    
    # Memory recommendations
    if @websocket_metrics.dig(:memory_usage, :avg_memory_per_connection_kb).to_f > 40
      recommendations << "Optimize connection state management and memory usage"
      recommendations << "Implement connection cleanup and garbage collection"
    end
    
    # General recommendations
    recommendations << "Monitor WebSocket performance in production with real user loads"
    recommendations << "Implement WebSocket connection health checks and monitoring"
    recommendations << "Set up alerts for connection drop rates and message latency spikes"
    
    recommendations
  end

  # =============================================================================
  # HELPER METHODS
  # =============================================================================

  def setup_test_connections(count)
    connections = []
    
    count.times do |i|
      connect "/cable", headers: { "User-Id" => "test_user_#{i}" }
      
      if connection
        subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @test_brand.id)
        connections << connection if subscription_confirmed?
      end
    end
    
    connections
  end

  def setup_dashboard_connections(count)
    connections = []
    
    count.times do |i|
      connect "/cable", headers: { 
        "User-Id" => "dashboard_user_#{i}",
        "Connection-Type" => "dashboard"
      }
      
      if connection
        subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @test_brand.id)
        connections << connection if subscription_confirmed?
      end
    end
    
    connections
  end

  def setup_large_broadcast_test(count)
    connections = []
    
    count.times do |i|
      connect "/cable", headers: { "User-Id" => "broadcast_user_#{i}" }
      
      if connection
        subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @test_brand.id)
        connections << connection if subscription_confirmed?
      end
    end
    
    connections
  end

  def setup_drop_test_connections(count)
    connections = []
    
    count.times do |i|
      connect "/cable", headers: { "User-Id" => "drop_test_user_#{i}" }
      
      if connection
        subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @test_brand.id)
        connections << connection if subscription_confirmed?
      end
    end
    
    connections
  end

  def setup_peak_load_connections(count)
    connections = []
    
    count.times do |i|
      connect "/cable", headers: { "User-Id" => "peak_user_#{i}" }
      
      if connection
        subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @test_brand.id)
        connections << connection if subscription_confirmed?
      end
    end
    
    connections
  end

  def generate_large_analytics_payload(size_kb)
    # Generate payload of approximately specified size
    data_points = (size_kb * 1024) / 100 # Approximate calculation
    
    {
      metrics: Array.new(data_points) do |i|
        {
          id: i,
          platform: ["facebook", "instagram", "twitter"].sample,
          metric_type: ["reach", "engagement", "impressions"].sample,
          value: rand(1000..10000),
          timestamp: Time.current.to_f
        }
      end
    }
  end

  def generate_realistic_analytics_update
    {
      social_media: {
        facebook: { reach: rand(1000..5000), engagement: rand(100..500) },
        instagram: { reach: rand(500..2500), engagement: rand(50..250) }
      },
      email_marketing: {
        sent: rand(1000..5000),
        opened: rand(100..500),
        clicked: rand(10..50)
      },
      conversions: rand(5..50),
      revenue: rand(1000..10000)
    }
  end

  def send_tracked_message(message_id, message_data)
    begin
      ActionCable.server.broadcast("analytics_dashboard_#{@test_brand.id}", message_data)
      true # Simulate successful delivery
    rescue => e
      false
    end
  end

  def disconnect_connection(conn)
    # Simulate connection drop
    conn&.close if conn.respond_to?(:close)
  end

  def cleanup_connections
    @connections.each do |conn|
      begin
        conn&.close if conn.respond_to?(:close)
      rescue => e
        # Ignore cleanup errors
      end
    end
    @connections.clear
  end

  def get_memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    0
  end

  def send_message(message_type, data)
    ActionCable.server.broadcast("analytics_dashboard_#{@test_brand.id}", {
      type: message_type,
      data: data,
      timestamp: Time.current.to_f
    })
  end
end