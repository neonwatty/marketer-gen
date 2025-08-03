# frozen_string_literal: true

require "test_helper"
require "benchmark"
require "concurrent"

class HighVolumeDataProcessingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # High-volume processing targets
  VOLUME_TARGETS = {
    # Daily processing targets (1M+ data points)
    daily_data_points: 1_000_000,
    peak_processing_rate: 50_000, # Records per second during peak
    sustained_processing_rate: 12, # Records per second sustained (1M/24h/3600s)
    
    # Batch processing targets
    batch_size_optimal: 5_000,
    batch_processing_time_max: 30, # Seconds per batch
    
    # Memory efficiency targets
    memory_per_million_records_mb: 500,
    gc_frequency_max_per_hour: 60,
    
    # Pipeline throughput targets
    social_media_records_per_hour: 100_000,
    email_metrics_records_per_hour: 50_000,
    analytics_records_per_hour: 200_000,
    crm_records_per_hour: 25_000,
    
    # Error tolerance
    processing_error_rate_max: 0.1, # 0.1% error rate maximum
    retry_success_rate_min: 95.0
  }.freeze

  def setup
    @test_brand = brands(:one)
    @test_user = users(:one)
    @performance_metrics = {}
    @start_time = Time.current
    
    setup_high_volume_integrations
    setup_monitoring
    
    puts "\n" + "="*100
    puts "HIGH-VOLUME DATA PROCESSING PERFORMANCE TEST"
    puts "Target: Process 1M+ data points daily with optimal performance"
    puts "="*100
  end

  def teardown
    cleanup_test_data
    generate_high_volume_performance_report
  end

  # =============================================================================
  # MAIN HIGH-VOLUME PROCESSING TESTS
  # =============================================================================

  test "high volume data processing comprehensive benchmark" do
    puts "\nExecuting high-volume data processing performance tests..."
    
    # Test 1: Sustained High-Volume Processing
    test_sustained_high_volume_processing
    
    # Test 2: Peak Load Processing
    test_peak_load_processing
    
    # Test 3: Multi-Platform Concurrent Processing
    test_multi_platform_concurrent_processing
    
    # Test 4: Memory Efficiency Under Load
    test_memory_efficiency_under_load
    
    # Test 5: Error Handling and Recovery at Scale
    test_error_handling_at_scale
    
    # Test 6: Pipeline Throughput Analysis
    test_pipeline_throughput_analysis
    
    # Validate performance against targets
    validate_high_volume_targets
  end

  # =============================================================================
  # SUSTAINED HIGH-VOLUME PROCESSING
  # =============================================================================

  def test_sustained_high_volume_processing
    puts "\n📈 Testing sustained high-volume processing..."
    
    # Simulate 24-hour data processing in accelerated time
    total_records = 100_000 # Scaled down for test environment
    processing_duration_target = total_records / VOLUME_TARGETS[:sustained_processing_rate]
    
    puts "  Processing #{total_records} records (simulating daily 1M+ load)..."
    
    processing_time = Benchmark.measure do
      process_large_dataset_in_batches(total_records)
    end
    
    actual_rate = total_records / processing_time.real
    efficiency = (actual_rate / VOLUME_TARGETS[:sustained_processing_rate]) * 100
    
    puts "  Sustained processing rate: #{actual_rate.round(2)} records/second"
    puts "  Efficiency vs target: #{efficiency.round(2)}%"
    puts "  Processing time: #{processing_time.real.round(2)}s"
    
    @performance_metrics[:sustained_processing] = {
      records_processed: total_records,
      processing_time: processing_time.real,
      processing_rate: actual_rate,
      efficiency_percent: efficiency,
      target_rate: VOLUME_TARGETS[:sustained_processing_rate]
    }
    
    # Verify sustained processing meets minimum requirements
    min_acceptable_rate = VOLUME_TARGETS[:sustained_processing_rate] * 0.8 # 80% of target
    assert actual_rate >= min_acceptable_rate,
           "Sustained processing rate too low: #{actual_rate.round(2)} records/second (minimum: #{min_acceptable_rate})"
  end

  def process_large_dataset_in_batches(total_records)
    batch_size = VOLUME_TARGETS[:batch_size_optimal]
    num_batches = (total_records.to_f / batch_size).ceil
    
    processed_batches = 0
    
    num_batches.times do |batch_index|
      current_batch_size = [batch_size, total_records - (batch_index * batch_size)].min
      
      # Process different types of data in this batch
      batch_start_time = Time.current
      
      process_social_media_batch(current_batch_size / 4)
      process_email_metrics_batch(current_batch_size / 4)
      process_analytics_batch(current_batch_size / 4)
      process_crm_batch(current_batch_size / 4)
      
      batch_end_time = Time.current
      batch_processing_time = batch_end_time - batch_start_time
      
      # Verify batch processing time is within target
      if batch_processing_time > VOLUME_TARGETS[:batch_processing_time_max]
        puts "    ⚠️  Batch #{batch_index + 1} processing time exceeded target: #{batch_processing_time.round(2)}s"
      end
      
      processed_batches += 1
      
      # Log progress every 10 batches
      if (batch_index + 1) % 10 == 0
        progress = ((batch_index + 1).to_f / num_batches * 100).round(2)
        puts "    Progress: #{progress}% (#{batch_index + 1}/#{num_batches} batches)"
      end
    end
    
    puts "  Completed #{processed_batches} batches successfully"
  end

  # =============================================================================
  # PEAK LOAD PROCESSING
  # =============================================================================

  def test_peak_load_processing
    puts "\n🚀 Testing peak load processing capabilities..."
    
    # Simulate peak traffic conditions
    peak_records = 25_000 # Simulating peak load
    peak_duration_seconds = 30
    
    puts "  Processing #{peak_records} records in #{peak_duration_seconds}s (peak load simulation)..."
    
    peak_processing_time = Benchmark.measure do
      # Process high volume in parallel threads
      threads = []
      records_per_thread = peak_records / 4
      
      4.times do |thread_index|
        threads << Thread.new do
          Thread.current[:thread_id] = thread_index
          process_peak_load_batch(records_per_thread, thread_index)
        end
      end
      
      threads.each(&:join)
    end
    
    peak_rate = peak_records / peak_processing_time.real
    peak_efficiency = (peak_rate / VOLUME_TARGETS[:peak_processing_rate]) * 100
    
    puts "  Peak processing rate: #{peak_rate.round(2)} records/second"
    puts "  Peak efficiency: #{peak_efficiency.round(2)}%"
    puts "  Peak processing time: #{peak_processing_time.real.round(2)}s"
    
    @performance_metrics[:peak_processing] = {
      records_processed: peak_records,
      processing_time: peak_processing_time.real,
      peak_rate: peak_rate,
      efficiency_percent: peak_efficiency,
      target_peak_rate: VOLUME_TARGETS[:peak_processing_rate]
    }
    
    # Verify peak processing meets requirements
    min_peak_rate = VOLUME_TARGETS[:peak_processing_rate] * 0.5 # 50% of peak target
    assert peak_rate >= min_peak_rate,
           "Peak processing rate too low: #{peak_rate.round(2)} records/second (minimum: #{min_peak_rate})"
  end

  def process_peak_load_batch(record_count, thread_id)
    # Simulate high-intensity data processing
    batch_data = []
    
    (record_count / 4).times do |i|
      batch_data << create_social_media_record(thread_id, i)
      batch_data << create_email_metric_record(thread_id, i)
      batch_data << create_analytics_record(thread_id, i)
      batch_data << create_crm_record(thread_id, i)
    end
    
    # Insert in larger batches for peak performance
    insert_batch_data(batch_data)
  end

  # =============================================================================
  # MULTI-PLATFORM CONCURRENT PROCESSING
  # =============================================================================

  def test_multi_platform_concurrent_processing
    puts "\n🔄 Testing multi-platform concurrent processing..."
    
    platforms = [
      { name: "social_media", records: 15_000, processor: method(:process_social_media_batch) },
      { name: "email_marketing", records: 10_000, processor: method(:process_email_metrics_batch) },
      { name: "google_analytics", records: 20_000, processor: method(:process_analytics_batch) },
      { name: "crm_systems", records: 5_000, processor: method(:process_crm_batch) }
    ]
    
    concurrent_processing_time = Benchmark.measure do
      threads = []
      
      platforms.each do |platform|
        threads << Thread.new do
          Thread.current[:platform] = platform[:name]
          puts "    Starting #{platform[:name]} processing (#{platform[:records]} records)..."
          
          platform_start_time = Time.current
          platform[:processor].call(platform[:records])
          platform_end_time = Time.current
          
          platform_time = platform_end_time - platform_start_time
          platform_rate = platform[:records] / platform_time
          
          puts "    #{platform[:name]} completed: #{platform_rate.round(2)} records/second"
          
          Thread.current[:results] = {
            platform: platform[:name],
            records: platform[:records],
            time: platform_time,
            rate: platform_rate
          }
        end
      end
      
      threads.each(&:join)
      
      # Collect results from threads
      @platform_results = threads.map { |t| t[:results] }.compact
    end
    
    total_records = platforms.sum { |p| p[:records] }
    overall_rate = total_records / concurrent_processing_time.real
    
    puts "  Concurrent processing results:"
    @platform_results.each do |result|
      puts "    #{result[:platform]}: #{result[:rate].round(2)} records/second"
    end
    puts "  Overall concurrent rate: #{overall_rate.round(2)} records/second"
    puts "  Total concurrent time: #{concurrent_processing_time.real.round(2)}s"
    
    @performance_metrics[:concurrent_processing] = {
      total_records: total_records,
      processing_time: concurrent_processing_time.real,
      overall_rate: overall_rate,
      platform_results: @platform_results
    }
    
    # Verify concurrent processing efficiency
    expected_minimum_rate = total_records / 120 # Should process in under 2 minutes
    assert overall_rate >= expected_minimum_rate,
           "Concurrent processing too slow: #{overall_rate.round(2)} records/second"
  end

  # =============================================================================
  # MEMORY EFFICIENCY UNDER LOAD
  # =============================================================================

  def test_memory_efficiency_under_load
    puts "\n💾 Testing memory efficiency under high-volume load..."
    
    initial_memory = get_memory_usage
    gc_count_before = GC.count
    
    # Process a large dataset while monitoring memory
    test_records = 50_000
    memory_samples = []
    
    memory_monitoring_time = Benchmark.measure do
      batches = 10
      records_per_batch = test_records / batches
      
      batches.times do |batch_index|
        batch_start_memory = get_memory_usage
        
        # Process batch
        process_memory_test_batch(records_per_batch)
        
        batch_end_memory = get_memory_usage
        memory_increase = batch_end_memory - batch_start_memory
        
        memory_samples << {
          batch: batch_index + 1,
          start_memory: batch_start_memory,
          end_memory: batch_end_memory,
          increase: memory_increase
        }
        
        puts "    Batch #{batch_index + 1}: +#{memory_increase.round(2)}MB"
        
        # Force garbage collection every few batches
        if (batch_index + 1) % 3 == 0
          GC.start
          puts "    Triggered GC after batch #{batch_index + 1}"
        end
      end
    end
    
    final_memory = get_memory_usage
    total_memory_increase = final_memory - initial_memory
    gc_count_after = GC.count
    gc_frequency = gc_count_after - gc_count_before
    
    # Calculate memory efficiency metrics
    memory_per_record = total_memory_increase / test_records * 1000 # MB per 1000 records
    memory_efficiency = (VOLUME_TARGETS[:memory_per_million_records_mb] / total_memory_increase) * 100
    
    puts "  Memory efficiency results:"
    puts "    Total memory increase: #{total_memory_increase.round(2)}MB"
    puts "    Memory per 1000 records: #{memory_per_record.round(2)}MB"
    puts "    GC frequency: #{gc_frequency} collections"
    puts "    Memory efficiency: #{memory_efficiency.round(2)}%"
    
    @performance_metrics[:memory_efficiency] = {
      test_records: test_records,
      total_memory_increase: total_memory_increase,
      memory_per_record: memory_per_record,
      gc_frequency: gc_frequency,
      memory_samples: memory_samples,
      efficiency_percent: memory_efficiency
    }
    
    # Verify memory usage is within acceptable limits
    max_acceptable_memory = VOLUME_TARGETS[:memory_per_million_records_mb] * (test_records / 1_000_000.0)
    assert total_memory_increase <= max_acceptable_memory,
           "Memory usage too high: #{total_memory_increase.round(2)}MB (max: #{max_acceptable_memory.round(2)}MB)"
  end

  def process_memory_test_batch(record_count)
    # Create data structures that simulate real processing memory usage
    batch_data = []
    
    record_count.times do |i|
      # Simulate complex data structures
      record = {
        id: i,
        platform: ["facebook", "instagram", "twitter"].sample,
        metrics: {
          reach: rand(1000..10000),
          engagement: rand(100..1000),
          impressions: rand(5000..50000),
          clicks: rand(50..500)
        },
        metadata: {
          timestamp: Time.current.iso8601,
          source: "api",
          processed: false,
          tags: Array.new(rand(5..15)) { "tag_#{rand(1000)}" }
        }
      }
      batch_data << record
    end
    
    # Process the batch (simulate real work)
    processed_records = batch_data.map do |record|
      record[:metadata][:processed] = true
      record[:processed_at] = Time.current
      record
    end
    
    # Simulate database insertion
    insert_processed_records(processed_records)
    
    # Clear local variables to allow GC
    batch_data = nil
    processed_records = nil
  end

  # =============================================================================
  # ERROR HANDLING AND RECOVERY AT SCALE
  # =============================================================================

  def test_error_handling_at_scale
    puts "\n🛡️  Testing error handling and recovery at scale..."
    
    total_records = 20_000
    error_injection_rate = 0.05 # 5% error rate
    
    error_handling_time = Benchmark.measure do
      successful_records = 0
      failed_records = 0
      retry_attempts = 0
      
      batch_size = 1_000
      num_batches = total_records / batch_size
      
      num_batches.times do |batch_index|
        batch_success, batch_failures, batch_retries = process_error_test_batch(
          batch_size, 
          error_injection_rate,
          batch_index
        )
        
        successful_records += batch_success
        failed_records += batch_failures
        retry_attempts += batch_retries
      end
      
      @error_handling_results = {
        total_records: total_records,
        successful_records: successful_records,
        failed_records: failed_records,
        retry_attempts: retry_attempts,
        error_rate: (failed_records.to_f / total_records * 100).round(3),
        success_rate: (successful_records.to_f / total_records * 100).round(3),
        retry_success_rate: retry_attempts > 0 ? ((retry_attempts - failed_records).to_f / retry_attempts * 100).round(3) : 0
      }
    end
    
    puts "  Error handling results:"
    puts "    Total records processed: #{@error_handling_results[:total_records]}"
    puts "    Successful records: #{@error_handling_results[:successful_records]}"
    puts "    Failed records: #{@error_handling_results[:failed_records]}"
    puts "    Error rate: #{@error_handling_results[:error_rate]}%"
    puts "    Success rate: #{@error_handling_results[:success_rate]}%"
    puts "    Retry success rate: #{@error_handling_results[:retry_success_rate]}%"
    
    @performance_metrics[:error_handling] = @error_handling_results
    
    # Verify error handling meets requirements
    assert @error_handling_results[:error_rate] <= VOLUME_TARGETS[:processing_error_rate_max],
           "Error rate too high: #{@error_handling_results[:error_rate]}%"
    
    assert @error_handling_results[:retry_success_rate] >= VOLUME_TARGETS[:retry_success_rate_min],
           "Retry success rate too low: #{@error_handling_results[:retry_success_rate]}%"
  end

  def process_error_test_batch(batch_size, error_rate, batch_index)
    successful = 0
    failed = 0
    retries = 0
    
    batch_size.times do |record_index|
      # Simulate processing with potential errors
      should_error = rand < error_rate
      
      if should_error
        # Simulate error and retry logic
        retry_count = 0
        max_retries = 3
        
        while retry_count < max_retries
          retries += 1
          retry_count += 1
          
          # Simulate retry success (80% chance after first retry)
          if retry_count > 1 && rand < 0.8
            successful += 1
            break
          elsif retry_count == max_retries
            failed += 1
          end
        end
      else
        successful += 1
      end
    end
    
    [successful, failed, retries]
  end

  # =============================================================================
  # PIPELINE THROUGHPUT ANALYSIS
  # =============================================================================

  def test_pipeline_throughput_analysis
    puts "\n⚡ Testing pipeline throughput analysis..."
    
    # Test individual pipeline components
    pipelines = {
      social_media: {
        target_per_hour: VOLUME_TARGETS[:social_media_records_per_hour],
        test_records: 5_000
      },
      email_metrics: {
        target_per_hour: VOLUME_TARGETS[:email_metrics_records_per_hour],
        test_records: 2_500
      },
      analytics: {
        target_per_hour: VOLUME_TARGETS[:analytics_records_per_hour],
        test_records: 10_000
      },
      crm: {
        target_per_hour: VOLUME_TARGETS[:crm_records_per_hour],
        test_records: 1_250
      }
    }
    
    pipeline_results = {}
    
    pipelines.each do |pipeline_name, config|
      puts "  Testing #{pipeline_name} pipeline throughput..."
      
      pipeline_time = Benchmark.measure do
        case pipeline_name
        when :social_media
          process_social_media_batch(config[:test_records])
        when :email_metrics
          process_email_metrics_batch(config[:test_records])
        when :analytics
          process_analytics_batch(config[:test_records])
        when :crm
          process_crm_batch(config[:test_records])
        end
      end
      
      records_per_second = config[:test_records] / pipeline_time.real
      records_per_hour = records_per_second * 3600
      throughput_efficiency = (records_per_hour / config[:target_per_hour]) * 100
      
      pipeline_results[pipeline_name] = {
        test_records: config[:test_records],
        processing_time: pipeline_time.real,
        records_per_second: records_per_second,
        records_per_hour: records_per_hour,
        target_per_hour: config[:target_per_hour],
        efficiency_percent: throughput_efficiency
      }
      
      puts "    #{pipeline_name}: #{records_per_hour.round(0)} records/hour (#{throughput_efficiency.round(2)}% efficiency)"
    end
    
    @performance_metrics[:pipeline_throughput] = pipeline_results
    
    # Verify each pipeline meets minimum throughput requirements
    pipelines.each do |pipeline_name, config|
      result = pipeline_results[pipeline_name]
      min_acceptable_throughput = config[:target_per_hour] * 0.7 # 70% of target
      
      assert result[:records_per_hour] >= min_acceptable_throughput,
             "#{pipeline_name} throughput too low: #{result[:records_per_hour].round(0)} records/hour (minimum: #{min_acceptable_throughput.round(0)})"
    end
  end

  # =============================================================================
  # VALIDATION AND REPORTING
  # =============================================================================

  def validate_high_volume_targets
    puts "\n🎯 Validating high-volume processing targets..."
    
    validations = [
      {
        name: "Sustained Processing Rate",
        target: ">= #{VOLUME_TARGETS[:sustained_processing_rate]} records/second",
        actual: @performance_metrics.dig(:sustained_processing, :processing_rate),
        threshold: VOLUME_TARGETS[:sustained_processing_rate],
        comparison: :>=
      },
      {
        name: "Peak Processing Rate",
        target: ">= #{VOLUME_TARGETS[:peak_processing_rate] * 0.5} records/second",
        actual: @performance_metrics.dig(:peak_processing, :peak_rate),
        threshold: VOLUME_TARGETS[:peak_processing_rate] * 0.5,
        comparison: :>=
      },
      {
        name: "Memory Efficiency",
        target: "<= #{VOLUME_TARGETS[:memory_per_million_records_mb]}MB per 1M records",
        actual: @performance_metrics.dig(:memory_efficiency, :total_memory_increase),
        threshold: VOLUME_TARGETS[:memory_per_million_records_mb] * 0.05, # Scaled for test size
        comparison: :<=
      },
      {
        name: "Error Rate",
        target: "<= #{VOLUME_TARGETS[:processing_error_rate_max]}%",
        actual: @performance_metrics.dig(:error_handling, :error_rate),
        threshold: VOLUME_TARGETS[:processing_error_rate_max],
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
        else
          passed = false
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
      puts "🎉 ALL HIGH-VOLUME PROCESSING TARGETS MET"
      puts "System capable of processing 1M+ data points daily with optimal performance"
    else
      puts "⚠️  SOME HIGH-VOLUME TARGETS NOT MET"
      puts "Review performance optimizations before handling enterprise-scale loads"
    end
    
    all_targets_met
  end

  def generate_high_volume_performance_report
    report_data = {
      test_suite: "High-Volume Data Processing Performance Test",
      execution_time: @start_time.iso8601,
      total_duration: Time.current - @start_time,
      volume_targets: VOLUME_TARGETS,
      performance_metrics: @performance_metrics,
      summary: {
        sustained_processing_rate: @performance_metrics.dig(:sustained_processing, :processing_rate),
        peak_processing_rate: @performance_metrics.dig(:peak_processing, :peak_rate),
        memory_efficiency: @performance_metrics.dig(:memory_efficiency, :efficiency_percent),
        error_rate: @performance_metrics.dig(:error_handling, :error_rate),
        overall_throughput: calculate_overall_throughput
      },
      recommendations: generate_volume_recommendations
    }
    
    # Save detailed report
    report_filename = "high_volume_processing_test_#{@start_time.strftime('%Y%m%d_%H%M%S')}.json"
    report_path = Rails.root.join("tmp", report_filename)
    File.write(report_path, JSON.pretty_generate(report_data))
    
    puts "\n📊 High-volume processing report saved: #{report_path}"
  end

  def calculate_overall_throughput
    if @performance_metrics[:concurrent_processing]
      @performance_metrics[:concurrent_processing][:overall_rate]
    else
      0
    end
  end

  def generate_volume_recommendations
    recommendations = []
    
    # Analyze sustained processing
    if @performance_metrics[:sustained_processing]
      efficiency = @performance_metrics[:sustained_processing][:efficiency_percent]
      if efficiency < 80
        recommendations << "Optimize batch processing algorithms for better sustained throughput"
        recommendations << "Consider implementing parallel processing pipelines"
      end
    end
    
    # Analyze memory efficiency
    if @performance_metrics[:memory_efficiency]
      memory_efficiency = @performance_metrics[:memory_efficiency][:efficiency_percent]
      if memory_efficiency < 70
        recommendations << "Implement memory pooling and object reuse patterns"
        recommendations << "Optimize data structures for high-volume processing"
      end
    end
    
    # Analyze error handling
    if @performance_metrics[:error_handling]
      error_rate = @performance_metrics[:error_handling][:error_rate]
      if error_rate > 0.05
        recommendations << "Improve error detection and prevention mechanisms"
        recommendations << "Implement more robust retry logic with exponential backoff"
      end
    end
    
    recommendations << "Monitor production performance with real data volumes"
    recommendations << "Implement auto-scaling based on processing queue depth"
    recommendations << "Set up comprehensive alerting for processing rate degradation"
    
    recommendations
  end

  # =============================================================================
  # DATA PROCESSING HELPER METHODS
  # =============================================================================

  def process_social_media_batch(record_count)
    batch_data = []
    
    record_count.times do |i|
      batch_data << {
        social_media_integration_id: @social_integration.id,
        platform: ["facebook", "instagram", "twitter", "linkedin"].sample,
        metric_type: ["reach", "engagement", "impressions", "clicks"].sample,
        value: rand(100..50000),
        date: rand(30.days).seconds.ago.to_date,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    SocialMediaMetric.insert_all(batch_data) if batch_data.any?
  end

  def process_email_metrics_batch(record_count)
    batch_data = []
    
    record_count.times do |i|
      batch_data << {
        email_campaign_id: @email_campaign.id,
        metric_type: ["sent", "delivered", "opened", "clicked", "bounced"].sample,
        value: rand(10..5000),
        date: rand(30.days).seconds.ago.to_date,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    EmailMetric.insert_all(batch_data) if batch_data.any?
  end

  def process_analytics_batch(record_count)
    batch_data = []
    
    record_count.times do |i|
      batch_data << {
        brand_id: @test_brand.id,
        metric_name: ["sessions", "pageviews", "users", "bounce_rate", "conversion_rate"].sample,
        metric_value: rand(1..10000).to_f,
        date: rand(30.days).seconds.ago.to_date,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    GoogleAnalyticsMetric.insert_all(batch_data) if batch_data.any?
  end

  def process_crm_batch(record_count)
    batch_data = []
    
    record_count.times do |i|
      batch_data << {
        crm_integration_id: @crm_integration.id,
        external_id: "high_vol_lead_#{i}_#{rand(100000)}",
        email: "hvtest_#{i}_#{rand(10000)}@example.com",
        status: ["new", "qualified", "converted", "lost"].sample,
        source: ["website", "social", "email", "referral", "direct"].sample,
        score: rand(0..100),
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    CrmLead.insert_all(batch_data) if batch_data.any?
  end

  def create_social_media_record(thread_id, index)
    {
      social_media_integration_id: @social_integration.id,
      platform: "facebook",
      metric_type: "reach",
      value: rand(1000..10000),
      date: Date.current,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def create_email_metric_record(thread_id, index)
    {
      email_campaign_id: @email_campaign.id,
      metric_type: "opened",
      value: rand(100..1000),
      date: Date.current,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def create_analytics_record(thread_id, index)
    {
      brand_id: @test_brand.id,
      metric_name: "sessions",
      metric_value: rand(100..1000).to_f,
      date: Date.current,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def create_crm_record(thread_id, index)
    {
      crm_integration_id: @crm_integration.id,
      external_id: "peak_lead_#{thread_id}_#{index}",
      email: "peak_#{thread_id}_#{index}@example.com",
      status: "new",
      source: "website",
      score: rand(0..100),
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def insert_batch_data(batch_data)
    # Group by type and insert
    social_media_data = batch_data.select { |r| r.key?(:platform) }
    email_data = batch_data.select { |r| r.key?(:metric_type) && r.key?(:email_campaign_id) }
    analytics_data = batch_data.select { |r| r.key?(:metric_name) }
    crm_data = batch_data.select { |r| r.key?(:external_id) }
    
    SocialMediaMetric.insert_all(social_media_data) if social_media_data.any?
    EmailMetric.insert_all(email_data) if email_data.any?
    GoogleAnalyticsMetric.insert_all(analytics_data) if analytics_data.any?
    CrmLead.insert_all(crm_data) if crm_data.any?
  end

  def insert_processed_records(processed_records)
    # Simulate database insertion with realistic processing
    processed_records.each_slice(100) do |batch|
      # Simulate batch insertion time
      sleep(0.001)
    end
  end

  # =============================================================================
  # SETUP AND CLEANUP
  # =============================================================================

  def setup_high_volume_integrations
    @social_integration = SocialMediaIntegration.create!(
      brand: @test_brand,
      platform: "facebook",
      access_token: "high_volume_test_token",
      status: "active",
      platform_account_id: "hv_test_account"
    )
    
    @email_campaign = EmailCampaign.create!(
      brand: @test_brand,
      name: "High Volume Test Campaign",
      platform: "mailchimp",
      campaign_id: "hv_test_campaign"
    )
    
    @crm_integration = CrmIntegration.create!(
      brand: @test_brand,
      platform: "salesforce",
      access_token: "hv_crm_token",
      status: "active"
    )
  end

  def setup_monitoring
    # Setup performance monitoring
    @initial_memory = get_memory_usage
    @initial_gc_count = GC.count
  end

  def cleanup_test_data
    # Clean up test data to prevent interference with other tests
    SocialMediaMetric.where("created_at > ?", @start_time).delete_all
    EmailMetric.where("created_at > ?", @start_time).delete_all
    GoogleAnalyticsMetric.where("created_at > ?", @start_time).delete_all
    CrmLead.where("created_at > ?", @start_time).delete_all
  end

  def get_memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    0
  end
end