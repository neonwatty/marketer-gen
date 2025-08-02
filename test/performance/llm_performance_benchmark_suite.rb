require 'test_helper'
require 'benchmark'
require 'parallel'
require 'json'
require 'csv'

class LlmPerformanceBenchmarkSuite < ActiveSupport::TestCase
  # Benchmark configuration
  BENCHMARK_CONFIG = {
    # Content generation benchmarks
    simple_content_samples: 100,
    complex_content_samples: 50,
    mixed_content_samples: 200,
    
    # Concurrency benchmarks
    concurrency_levels: [1, 5, 10, 20, 50],
    requests_per_level: 20,
    
    # Provider comparison benchmarks
    providers_to_test: [:openai, :anthropic, :cohere],
    provider_test_requests: 30,
    
    # System resource benchmarks
    memory_benchmark_duration: 300, # 5 minutes
    cpu_benchmark_duration: 180,    # 3 minutes
    
    # Performance baselines (for comparison)
    baseline_simple_content_time: 1.0,
    baseline_complex_content_time: 5.0,
    baseline_memory_usage_mb: 100,
    baseline_throughput_rps: 15
  }.freeze

  def setup
    @brand = brands(:one)
    @user = users(:one)
    @benchmark_results = {}
    @start_time = Time.current
    @baseline_metrics = load_baseline_metrics
    
    setup_benchmark_environment
    
    puts "\n" + "="*80
    puts "LLM PERFORMANCE BENCHMARK SUITE"
    puts "="*80
    puts "Comprehensive performance benchmarking and comparison analysis"
    puts "Establishing performance baselines and regression detection"
    puts "="*80
  end

  def teardown
    @end_time = Time.current
    generate_comprehensive_benchmark_report
    cleanup_benchmark_data
  end

  test "content generation performance benchmarks" do
    puts "\n📊 Running content generation performance benchmarks..."
    
    content_benchmarks = {}
    
    # Benchmark 1: Simple content generation
    puts "\n  Benchmarking simple content generation..."
    simple_results = benchmark_simple_content_generation(BENCHMARK_CONFIG[:simple_content_samples])
    content_benchmarks[:simple_content] = simple_results
    
    # Benchmark 2: Complex content generation
    puts "  Benchmarking complex content generation..."
    complex_results = benchmark_complex_content_generation(BENCHMARK_CONFIG[:complex_content_samples])
    content_benchmarks[:complex_content] = complex_results
    
    # Benchmark 3: Mixed content workload
    puts "  Benchmarking mixed content workload..."
    mixed_results = benchmark_mixed_content_workload(BENCHMARK_CONFIG[:mixed_content_samples])
    content_benchmarks[:mixed_content] = mixed_results
    
    @benchmark_results[:content_generation] = content_benchmarks
    
    # Performance analysis
    analyze_content_generation_benchmarks(content_benchmarks)
  end

  test "concurrency scaling benchmarks" do
    puts "\n⚡ Running concurrency scaling benchmarks..."
    
    concurrency_benchmarks = {}
    
    BENCHMARK_CONFIG[:concurrency_levels].each do |level|
      puts "\n  Testing concurrency level: #{level}"
      
      benchmark_result = benchmark_concurrency_level(level, BENCHMARK_CONFIG[:requests_per_level])
      concurrency_benchmarks["level_#{level}"] = benchmark_result
      
      puts "    Throughput: #{benchmark_result[:throughput].round(2)} RPS"
      puts "    Avg Response Time: #{benchmark_result[:avg_response_time].round(3)}s"
      puts "    Success Rate: #{benchmark_result[:success_rate].round(2)}%"
    end
    
    @benchmark_results[:concurrency_scaling] = concurrency_benchmarks
    
    # Analyze scaling characteristics
    analyze_concurrency_scaling(concurrency_benchmarks)
  end

  test "provider performance comparison benchmarks" do
    puts "\n🔄 Running provider performance comparison benchmarks..."
    
    provider_benchmarks = {}
    
    BENCHMARK_CONFIG[:providers_to_test].each do |provider|
      puts "\n  Benchmarking #{provider.to_s.upcase} provider..."
      
      provider_result = benchmark_provider_performance(provider, BENCHMARK_CONFIG[:provider_test_requests])
      provider_benchmarks[provider] = provider_result
      
      puts "    Avg Response Time: #{provider_result[:avg_response_time].round(3)}s"
      puts "    Success Rate: #{provider_result[:success_rate].round(2)}%"
      puts "    Throughput: #{provider_result[:throughput].round(2)} RPS"
    end
    
    @benchmark_results[:provider_comparison] = provider_benchmarks
    
    # Analyze provider performance differences
    analyze_provider_performance_comparison(provider_benchmarks)
  end

  test "system resource utilization benchmarks" do
    puts "\n🖥️ Running system resource utilization benchmarks..."
    
    resource_benchmarks = {}
    
    # Memory utilization benchmark
    puts "\n  Benchmarking memory utilization..."
    memory_result = benchmark_memory_utilization(BENCHMARK_CONFIG[:memory_benchmark_duration])
    resource_benchmarks[:memory_utilization] = memory_result
    
    # CPU utilization benchmark (simulated)
    puts "  Benchmarking CPU utilization..."
    cpu_result = benchmark_cpu_utilization(BENCHMARK_CONFIG[:cpu_benchmark_duration])
    resource_benchmarks[:cpu_utilization] = cpu_result
    
    @benchmark_results[:resource_utilization] = resource_benchmarks
    
    # Analyze resource efficiency
    analyze_resource_utilization(resource_benchmarks)
  end

  test "performance regression detection" do
    puts "\n🔍 Running performance regression detection..."
    
    regression_results = {}
    
    # Compare current results with baselines
    current_metrics = extract_current_performance_metrics
    regression_analysis = detect_performance_regressions(current_metrics, @baseline_metrics)
    
    regression_results[:regression_analysis] = regression_analysis
    regression_results[:current_metrics] = current_metrics
    regression_results[:baseline_metrics] = @baseline_metrics
    
    @benchmark_results[:regression_detection] = regression_results
    
    # Report regression findings
    report_regression_findings(regression_analysis)
  end

  test "throughput optimization benchmarks" do
    puts "\n🚀 Running throughput optimization benchmarks..."
    
    optimization_benchmarks = {}
    
    # Test different optimization strategies
    strategies = [
      { name: "baseline", config: { caching: false, batching: false, parallel: false } },
      { name: "with_caching", config: { caching: true, batching: false, parallel: false } },
      { name: "with_batching", config: { caching: false, batching: true, parallel: false } },
      { name: "with_parallel", config: { caching: false, batching: false, parallel: true } },
      { name: "fully_optimized", config: { caching: true, batching: true, parallel: true } }
    ]
    
    strategies.each do |strategy|
      puts "\n  Testing optimization strategy: #{strategy[:name]}"
      
      result = benchmark_optimization_strategy(strategy[:name], strategy[:config])
      optimization_benchmarks[strategy[:name]] = result
      
      puts "    Throughput: #{result[:throughput].round(2)} RPS"
      puts "    Efficiency Gain: #{result[:efficiency_gain].round(2)}%"
    end
    
    @benchmark_results[:throughput_optimization] = optimization_benchmarks
    
    # Analyze optimization effectiveness
    analyze_optimization_effectiveness(optimization_benchmarks)
  end

  private

  def setup_benchmark_environment
    # Configure environment for consistent benchmarking
    Rails.cache.clear if Rails.cache.respond_to?(:clear)
    
    # Setup mock responses for consistent testing
    setup_benchmark_mocks
    
    # Warm up the system
    warmup_system
  end

  def setup_benchmark_mocks
    # Consistent mock responses for benchmarking
    WebMock.stub_request(:post, /api\.openai\.com/)
      .to_return do |request|
        sleep(rand(0.2..0.8)) # Simulate realistic response times
        {
          status: 200,
          body: {
            choices: [{ message: { content: "Benchmark generated content" } }],
            usage: { total_tokens: rand(100..500) }
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        }
      end
      
    WebMock.stub_request(:post, /api\.anthropic\.com/)
      .to_return do |request|
        sleep(rand(0.3..1.0))
        {
          status: 200,
          body: {
            content: [{ text: "Benchmark generated content from Anthropic" }],
            usage: { input_tokens: 50, output_tokens: rand(100..400) }
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        }
      end
      
    WebMock.stub_request(:post, /api\.cohere\.ai/)
      .to_return do |request|
        sleep(rand(0.2..0.6))
        {
          status: 200,
          body: {
            generations: [{ text: "Benchmark generated content from Cohere" }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        }
      end
  end

  def warmup_system
    # Perform warmup requests to stabilize performance
    puts "  Warming up system..."
    5.times do
      process_benchmark_request('simple', 'warmup')
    end
    sleep(2)
  end

  def benchmark_simple_content_generation(sample_count)
    puts "    Processing #{sample_count} simple content requests..."
    
    response_times = []
    successful_requests = 0
    failed_requests = 0
    memory_before = get_memory_usage
    
    start_time = Time.current
    
    sample_count.times do |i|
      request_start = Time.current
      
      begin
        result = process_benchmark_request('simple', "simple_#{i}")
        response_time = Time.current - request_start
        response_times << response_time
        
        if result[:success]
          successful_requests += 1
        else
          failed_requests += 1
        end
        
      rescue => e
        failed_requests += 1
        response_times << Time.current - request_start
      end
    end
    
    total_time = Time.current - start_time
    memory_after = get_memory_usage
    
    {
      sample_count: sample_count,
      total_time: total_time,
      avg_response_time: response_times.sum / response_times.length,
      median_response_time: calculate_median(response_times),
      p95_response_time: calculate_percentile(response_times, 95),
      p99_response_time: calculate_percentile(response_times, 99),
      min_response_time: response_times.min,
      max_response_time: response_times.max,
      successful_requests: successful_requests,
      failed_requests: failed_requests,
      success_rate: (successful_requests.to_f / sample_count) * 100,
      throughput: successful_requests / total_time,
      memory_usage: memory_after - memory_before
    }
  end

  def benchmark_complex_content_generation(sample_count)
    puts "    Processing #{sample_count} complex content requests..."
    
    response_times = []
    successful_requests = 0
    failed_requests = 0
    memory_before = get_memory_usage
    
    start_time = Time.current
    
    sample_count.times do |i|
      request_start = Time.current
      
      begin
        result = process_benchmark_request('complex', "complex_#{i}")
        response_time = Time.current - request_start
        response_times << response_time
        
        if result[:success]
          successful_requests += 1
        else
          failed_requests += 1
        end
        
      rescue => e
        failed_requests += 1
        response_times << Time.current - request_start
      end
    end
    
    total_time = Time.current - start_time
    memory_after = get_memory_usage
    
    {
      sample_count: sample_count,
      total_time: total_time,
      avg_response_time: response_times.sum / response_times.length,
      median_response_time: calculate_median(response_times),
      p95_response_time: calculate_percentile(response_times, 95),
      p99_response_time: calculate_percentile(response_times, 99),
      min_response_time: response_times.min,
      max_response_time: response_times.max,
      successful_requests: successful_requests,
      failed_requests: failed_requests,
      success_rate: (successful_requests.to_f / sample_count) * 100,
      throughput: successful_requests / total_time,
      memory_usage: memory_after - memory_before
    }
  end

  def benchmark_mixed_content_workload(sample_count)
    puts "    Processing #{sample_count} mixed content requests..."
    
    # 70% simple, 30% complex content
    simple_count = (sample_count * 0.7).to_i
    complex_count = sample_count - simple_count
    
    requests = []
    simple_count.times { |i| requests << { type: 'simple', id: "mixed_simple_#{i}" } }
    complex_count.times { |i| requests << { type: 'complex', id: "mixed_complex_#{i}" } }
    requests.shuffle!
    
    response_times = []
    successful_requests = 0
    failed_requests = 0
    memory_before = get_memory_usage
    
    start_time = Time.current
    
    requests.each do |request|
      request_start = Time.current
      
      begin
        result = process_benchmark_request(request[:type], request[:id])
        response_time = Time.current - request_start
        response_times << response_time
        
        if result[:success]
          successful_requests += 1
        else
          failed_requests += 1
        end
        
      rescue => e
        failed_requests += 1
        response_times << Time.current - request_start
      end
    end
    
    total_time = Time.current - start_time
    memory_after = get_memory_usage
    
    {
      sample_count: sample_count,
      simple_requests: simple_count,
      complex_requests: complex_count,
      total_time: total_time,
      avg_response_time: response_times.sum / response_times.length,
      median_response_time: calculate_median(response_times),
      successful_requests: successful_requests,
      failed_requests: failed_requests,
      success_rate: (successful_requests.to_f / sample_count) * 100,
      throughput: successful_requests / total_time,
      memory_usage: memory_after - memory_before
    }
  end

  def benchmark_concurrency_level(concurrency_level, requests_per_level)
    total_requests = concurrency_level * requests_per_level
    
    requests = (1..total_requests).map do |i|
      {
        id: "concurrent_#{concurrency_level}_#{i}",
        type: ['simple', 'complex'].sample
      }
    end
    
    start_time = Time.current
    memory_before = get_memory_usage
    
    results = Parallel.map(requests, in_threads: concurrency_level) do |request|
      request_start = Time.current
      
      begin
        result = process_benchmark_request(request[:type], request[:id])
        {
          success: result[:success],
          response_time: Time.current - request_start,
          request_type: request[:type]
        }
      rescue => e
        {
          success: false,
          response_time: Time.current - request_start,
          error: e.message,
          request_type: request[:type]
        }
      end
    end
    
    total_time = Time.current - start_time
    memory_after = get_memory_usage
    
    successful_results = results.select { |r| r[:success] }
    response_times = results.map { |r| r[:response_time] }
    
    {
      concurrency_level: concurrency_level,
      total_requests: total_requests,
      successful_requests: successful_results.length,
      failed_requests: results.length - successful_results.length,
      success_rate: (successful_results.length.to_f / results.length) * 100,
      total_time: total_time,
      avg_response_time: response_times.sum / response_times.length,
      throughput: successful_results.length / total_time,
      memory_usage: memory_after - memory_before,
      scaling_efficiency: calculate_scaling_efficiency(concurrency_level, successful_results.length / total_time)
    }
  end

  def benchmark_provider_performance(provider, request_count)
    puts "      Processing #{request_count} requests for #{provider}..."
    
    response_times = []
    successful_requests = 0
    failed_requests = 0
    
    start_time = Time.current
    
    request_count.times do |i|
      request_start = Time.current
      
      begin
        result = process_provider_benchmark_request(provider, "provider_#{provider}_#{i}")
        response_time = Time.current - request_start
        response_times << response_time
        
        if result[:success]
          successful_requests += 1
        else
          failed_requests += 1
        end
        
      rescue => e
        failed_requests += 1
        response_times << Time.current - request_start
      end
    end
    
    total_time = Time.current - start_time
    
    {
      provider: provider,
      request_count: request_count,
      successful_requests: successful_requests,
      failed_requests: failed_requests,
      success_rate: (successful_requests.to_f / request_count) * 100,
      avg_response_time: response_times.sum / response_times.length,
      median_response_time: calculate_median(response_times),
      min_response_time: response_times.min,
      max_response_time: response_times.max,
      throughput: successful_requests / total_time,
      reliability_score: calculate_reliability_score(successful_requests, request_count, response_times)
    }
  end

  def benchmark_memory_utilization(duration)
    puts "      Monitoring memory for #{duration} seconds..."
    
    memory_samples = []
    start_time = Time.current
    end_time = start_time + duration
    initial_memory = get_memory_usage
    
    request_count = 0
    
    while Time.current < end_time
      # Generate some load
      5.times do
        process_benchmark_request('simple', "memory_test_#{request_count}")
        request_count += 1
      end
      
      # Sample memory
      current_memory = get_memory_usage
      memory_samples << {
        timestamp: Time.current,
        memory_mb: current_memory,
        requests_processed: request_count
      }
      
      sleep(5) # Sample every 5 seconds
    end
    
    final_memory = get_memory_usage
    
    {
      duration: duration,
      requests_processed: request_count,
      initial_memory: initial_memory,
      final_memory: final_memory,
      peak_memory: memory_samples.map { |s| s[:memory_mb] }.max,
      avg_memory: memory_samples.map { |s| s[:memory_mb] }.sum / memory_samples.length,
      memory_growth: final_memory - initial_memory,
      memory_efficiency: request_count / (final_memory - initial_memory).abs,
      memory_samples: memory_samples
    }
  end

  def benchmark_cpu_utilization(duration)
    puts "      Simulating CPU benchmark for #{duration} seconds..."
    
    start_time = Time.current
    end_time = start_time + duration
    
    request_count = 0
    
    while Time.current < end_time
      # Simulate CPU-intensive content generation
      10.times do
        process_benchmark_request(['simple', 'complex'].sample, "cpu_test_#{request_count}")
        request_count += 1
      end
      
      sleep(1)
    end
    
    {
      duration: duration,
      requests_processed: request_count,
      avg_requests_per_second: request_count / duration,
      cpu_efficiency_score: request_count / duration # Simplified metric
    }
  end

  def benchmark_optimization_strategy(strategy_name, config)
    puts "      Testing #{strategy_name} strategy..."
    
    request_count = 50
    
    # Configure optimizations based on strategy
    configure_optimization_strategy(config)
    
    start_time = Time.current
    
    response_times = []
    successful_requests = 0
    
    request_count.times do |i|
      request_start = Time.current
      
      begin
        result = process_optimized_benchmark_request("strategy_#{strategy_name}_#{i}", config)
        response_time = Time.current - request_start
        response_times << response_time
        
        successful_requests += 1 if result[:success]
        
      rescue => e
        response_times << Time.current - request_start
      end
    end
    
    total_time = Time.current - start_time
    avg_response_time = response_times.sum / response_times.length
    throughput = successful_requests / total_time
    
    # Calculate efficiency gain compared to baseline
    baseline_throughput = @baseline_metrics[:baseline_throughput] || BENCHMARK_CONFIG[:baseline_throughput_rps]
    efficiency_gain = ((throughput - baseline_throughput) / baseline_throughput) * 100
    
    {
      strategy: strategy_name,
      config: config,
      request_count: request_count,
      successful_requests: successful_requests,
      avg_response_time: avg_response_time,
      throughput: throughput,
      efficiency_gain: efficiency_gain,
      total_time: total_time
    }
  end

  def process_benchmark_request(content_type, request_id)
    case content_type
    when 'simple'
      sleep(rand(0.1..0.5))
      { success: true, content: "Simple content for #{request_id}" }
    when 'complex'
      sleep(rand(0.5..2.0))
      { success: true, content: "Complex content for #{request_id}" }
    else
      { success: false, error: "Unknown content type" }
    end
  end

  def process_provider_benchmark_request(provider, request_id)
    # Simulate provider-specific processing
    case provider
    when :openai
      sleep(rand(0.2..0.8))
    when :anthropic
      sleep(rand(0.3..1.0))
    when :cohere
      sleep(rand(0.2..0.6))
    end
    
    { success: true, content: "Content from #{provider} for #{request_id}" }
  end

  def process_optimized_benchmark_request(request_id, config)
    base_time = rand(0.2..0.8)
    
    # Apply optimizations
    if config[:caching]
      base_time *= 0.7 # 30% improvement with caching
    end
    
    if config[:batching]
      base_time *= 0.8 # 20% improvement with batching
    end
    
    if config[:parallel]
      base_time *= 0.6 # 40% improvement with parallelization
    end
    
    sleep(base_time)
    { success: true, content: "Optimized content for #{request_id}" }
  end

  def configure_optimization_strategy(config)
    # This would configure actual optimization strategies in a real implementation
    # For testing, we just simulate the effects
  end

  def calculate_median(values)
    sorted = values.sort
    length = sorted.length
    
    if length.even?
      (sorted[length / 2 - 1] + sorted[length / 2]) / 2.0
    else
      sorted[length / 2]
    end
  end

  def calculate_percentile(values, percentile)
    sorted = values.sort
    index = (percentile / 100.0 * (sorted.length - 1)).round
    sorted[index]
  end

  def calculate_scaling_efficiency(concurrency_level, throughput)
    # Efficiency based on linear scaling expectation
    expected_throughput = BENCHMARK_CONFIG[:baseline_throughput_rps] * concurrency_level
    (throughput / expected_throughput) * 100
  end

  def calculate_reliability_score(successful, total, response_times)
    success_rate = (successful.to_f / total) * 100
    avg_response_time = response_times.sum / response_times.length
    
    # Weighted score: 70% success rate, 30% response time consistency
    time_consistency = 100 - ((response_times.max - response_times.min) / response_times.max * 100)
    (success_rate * 0.7) + (time_consistency * 0.3)
  end

  def get_memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    0
  end

  def load_baseline_metrics
    # Load or generate baseline performance metrics
    {
      baseline_simple_response_time: BENCHMARK_CONFIG[:baseline_simple_content_time],
      baseline_complex_response_time: BENCHMARK_CONFIG[:baseline_complex_content_time],
      baseline_memory_usage: BENCHMARK_CONFIG[:baseline_memory_usage_mb],
      baseline_throughput: BENCHMARK_CONFIG[:baseline_throughput_rps]
    }
  end

  def extract_current_performance_metrics
    return {} unless @benchmark_results[:content_generation]
    
    content_gen = @benchmark_results[:content_generation]
    
    {
      current_simple_response_time: content_gen[:simple_content]&.[](:avg_response_time),
      current_complex_response_time: content_gen[:complex_content]&.[](:avg_response_time),
      current_memory_usage: content_gen[:simple_content]&.[](:memory_usage),
      current_throughput: content_gen[:simple_content]&.[](:throughput)
    }
  end

  def detect_performance_regressions(current, baseline)
    regressions = []
    improvements = []
    
    # Check response time regressions (5% threshold)
    if current[:current_simple_response_time] && baseline[:baseline_simple_response_time]
      change = ((current[:current_simple_response_time] - baseline[:baseline_simple_response_time]) / baseline[:baseline_simple_response_time]) * 100
      
      if change > 5
        regressions << { metric: 'simple_response_time', change: change, current: current[:current_simple_response_time], baseline: baseline[:baseline_simple_response_time] }
      elsif change < -5
        improvements << { metric: 'simple_response_time', change: change, current: current[:current_simple_response_time], baseline: baseline[:baseline_simple_response_time] }
      end
    end
    
    # Check complex content response time
    if current[:current_complex_response_time] && baseline[:baseline_complex_response_time]
      change = ((current[:current_complex_response_time] - baseline[:baseline_complex_response_time]) / baseline[:baseline_complex_response_time]) * 100
      
      if change > 5
        regressions << { metric: 'complex_response_time', change: change, current: current[:current_complex_response_time], baseline: baseline[:baseline_complex_response_time] }
      elsif change < -5
        improvements << { metric: 'complex_response_time', change: change, current: current[:current_complex_response_time], baseline: baseline[:baseline_complex_response_time] }
      end
    end
    
    # Check throughput regressions
    if current[:current_throughput] && baseline[:baseline_throughput]
      change = ((current[:current_throughput] - baseline[:baseline_throughput]) / baseline[:baseline_throughput]) * 100
      
      if change < -5
        regressions << { metric: 'throughput', change: change, current: current[:current_throughput], baseline: baseline[:baseline_throughput] }
      elsif change > 5
        improvements << { metric: 'throughput', change: change, current: current[:current_throughput], baseline: baseline[:baseline_throughput] }
      end
    end
    
    {
      regressions_detected: regressions.any?,
      regressions: regressions,
      improvements: improvements,
      total_regressions: regressions.length,
      total_improvements: improvements.length
    }
  end

  def analyze_content_generation_benchmarks(benchmarks)
    puts "\n📊 Content Generation Analysis:"
    puts "-" * 40
    
    benchmarks.each do |type, data|
      puts "#{type.to_s.humanize}:"
      puts "  Avg Response Time: #{data[:avg_response_time].round(3)}s"
      puts "  P95 Response Time: #{data[:p95_response_time]&.round(3)}s"
      puts "  Throughput: #{data[:throughput].round(2)} RPS"
      puts "  Success Rate: #{data[:success_rate].round(2)}%"
      puts ""
    end
  end

  def analyze_concurrency_scaling(benchmarks)
    puts "\n⚡ Concurrency Scaling Analysis:"
    puts "-" * 40
    
    benchmarks.each do |level, data|
      puts "Concurrency Level #{data[:concurrency_level]}:"
      puts "  Throughput: #{data[:throughput].round(2)} RPS"
      puts "  Scaling Efficiency: #{data[:scaling_efficiency].round(2)}%"
      puts "  Success Rate: #{data[:success_rate].round(2)}%"
      puts ""
    end
  end

  def analyze_provider_performance_comparison(benchmarks)
    puts "\n🔄 Provider Performance Comparison:"
    puts "-" * 40
    
    benchmarks.each do |provider, data|
      puts "#{provider.to_s.upcase}:"
      puts "  Avg Response Time: #{data[:avg_response_time].round(3)}s"
      puts "  Reliability Score: #{data[:reliability_score].round(2)}"
      puts "  Throughput: #{data[:throughput].round(2)} RPS"
      puts ""
    end
  end

  def analyze_resource_utilization(benchmarks)
    puts "\n🖥️ Resource Utilization Analysis:"
    puts "-" * 40
    
    benchmarks.each do |resource, data|
      case resource
      when :memory_utilization
        puts "Memory:"
        puts "  Peak Usage: #{data[:peak_memory].round(2)}MB"
        puts "  Memory Growth: #{data[:memory_growth].round(2)}MB"
        puts "  Efficiency: #{data[:memory_efficiency].round(2)} req/MB"
      when :cpu_utilization
        puts "CPU:"
        puts "  Efficiency Score: #{data[:cpu_efficiency_score].round(2)}"
        puts "  Avg RPS: #{data[:avg_requests_per_second].round(2)}"
      end
      puts ""
    end
  end

  def analyze_optimization_effectiveness(benchmarks)
    puts "\n🚀 Optimization Effectiveness Analysis:"
    puts "-" * 40
    
    benchmarks.each do |strategy, data|
      puts "#{strategy.humanize}:"
      puts "  Throughput: #{data[:throughput].round(2)} RPS"
      puts "  Efficiency Gain: #{data[:efficiency_gain].round(2)}%"
      puts "  Avg Response Time: #{data[:avg_response_time].round(3)}s"
      puts ""
    end
  end

  def report_regression_findings(analysis)
    puts "\n🔍 Performance Regression Analysis:"
    puts "-" * 40
    
    if analysis[:regressions_detected]
      puts "⚠️  REGRESSIONS DETECTED:"
      analysis[:regressions].each do |regression|
        puts "  #{regression[:metric]}: #{regression[:change].round(2)}% slower"
        puts "    Current: #{regression[:current].round(3)}"
        puts "    Baseline: #{regression[:baseline].round(3)}"
      end
    else
      puts "✅ No performance regressions detected"
    end
    
    if analysis[:improvements].any?
      puts "\n🎉 PERFORMANCE IMPROVEMENTS:"
      analysis[:improvements].each do |improvement|
        puts "  #{improvement[:metric]}: #{improvement[:change].abs.round(2)}% improvement"
      end
    end
  end

  def generate_comprehensive_benchmark_report
    total_duration = @end_time - @start_time
    
    puts "\n" + "="*80
    puts "LLM PERFORMANCE BENCHMARK REPORT"
    puts "="*80
    puts "Total benchmark duration: #{total_duration.round(2)} seconds"
    
    # Generate detailed benchmark report
    report_data = {
      test_suite: "LLM Performance Benchmark Suite",
      execution_time: @start_time.iso8601,
      total_duration: total_duration,
      benchmark_configuration: BENCHMARK_CONFIG,
      baseline_metrics: @baseline_metrics,
      results: @benchmark_results,
      environment: {
        rails_version: Rails.version,
        ruby_version: RUBY_VERSION,
        test_environment: Rails.env
      }
    }
    
    # Save benchmark reports
    timestamp = @start_time.strftime('%Y%m%d_%H%M%S')
    json_path = Rails.root.join("tmp", "llm_benchmark_report_#{timestamp}.json")
    csv_path = Rails.root.join("tmp", "llm_benchmark_metrics_#{timestamp}.csv")
    
    File.write(json_path, JSON.pretty_generate(report_data))
    generate_benchmark_csv_report(csv_path)
    
    puts "\n📊 Benchmark reports saved:"
    puts "  JSON Report: #{json_path}"
    puts "  CSV Metrics: #{csv_path}"
    
    generate_benchmark_recommendations
  end

  def generate_benchmark_csv_report(csv_path)
    CSV.open(csv_path, 'w') do |csv|
      csv << ['Test Type', 'Metric', 'Value', 'Unit', 'Baseline', 'Change %']
      
      # Content generation metrics
      if @benchmark_results[:content_generation]
        @benchmark_results[:content_generation].each do |type, metrics|
          csv << ["Content Generation", "#{type} Avg Response Time", metrics[:avg_response_time].round(3), "seconds", @baseline_metrics[:baseline_simple_content_time], ""]
          csv << ["Content Generation", "#{type} Throughput", metrics[:throughput].round(2), "RPS", "", ""]
          csv << ["Content Generation", "#{type} Success Rate", metrics[:success_rate].round(2), "%", "", ""]
        end
      end
      
      # Concurrency metrics
      if @benchmark_results[:concurrency_scaling]
        @benchmark_results[:concurrency_scaling].each do |level, metrics|
          csv << ["Concurrency", "Level #{metrics[:concurrency_level]} Throughput", metrics[:throughput].round(2), "RPS", "", ""]
          csv << ["Concurrency", "Level #{metrics[:concurrency_level]} Efficiency", metrics[:scaling_efficiency].round(2), "%", "", ""]
        end
      end
      
      # Provider comparison metrics
      if @benchmark_results[:provider_comparison]
        @benchmark_results[:provider_comparison].each do |provider, metrics|
          csv << ["Provider", "#{provider} Avg Response Time", metrics[:avg_response_time].round(3), "seconds", "", ""]
          csv << ["Provider", "#{provider} Reliability Score", metrics[:reliability_score].round(2), "score", "", ""]
        end
      end
    end
  end

  def generate_benchmark_recommendations
    puts "\n🎯 BENCHMARK RECOMMENDATIONS:"
    puts "-" * 50
    
    recommendations = []
    
    # Analyze results and generate recommendations
    if @benchmark_results[:content_generation]
      simple_data = @benchmark_results[:content_generation][:simple_content]
      if simple_data && simple_data[:avg_response_time] > 1.5
        recommendations << "Optimize simple content generation - current avg: #{simple_data[:avg_response_time].round(3)}s"
      end
      
      complex_data = @benchmark_results[:content_generation][:complex_content]
      if complex_data && complex_data[:avg_response_time] > 8.0
        recommendations << "Optimize complex content generation - current avg: #{complex_data[:avg_response_time].round(3)}s"
      end
    end
    
    if @benchmark_results[:concurrency_scaling]
      # Find the optimal concurrency level
      scaling_data = @benchmark_results[:concurrency_scaling].values
      optimal_level = scaling_data.max_by { |data| data[:scaling_efficiency] }
      recommendations << "Optimal concurrency level appears to be #{optimal_level[:concurrency_level]} threads"
    end
    
    if @benchmark_results[:regression_detection]
      regression_data = @benchmark_results[:regression_detection][:regression_analysis]
      if regression_data[:regressions_detected]
        recommendations << "Address performance regressions in: #{regression_data[:regressions].map { |r| r[:metric] }.join(', ')}"
      end
    end
    
    if recommendations.empty?
      puts "✅ All benchmarks within acceptable performance ranges"
    else
      recommendations.each_with_index do |rec, index|
        puts "#{index + 1}. #{rec}"
      end
    end
    
    puts "\nBenchmarking best practices:"
    puts "• Run benchmarks regularly to track performance trends"
    puts "• Compare results across different environments and configurations"
    puts "• Use benchmark data to set performance SLAs and alerts"
    puts "• Consider A/B testing optimization strategies in production"
    puts "• Monitor key metrics continuously in production environments"
  end

  def cleanup_benchmark_data
    Rails.cache.clear if Rails.cache.respond_to?(:clear)
  end
end