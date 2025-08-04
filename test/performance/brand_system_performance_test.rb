require "test_helper"

class BrandSystemPerformanceTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @brand = brands(:one)
    sign_in @user
  end

  # Brand System Performance Tests (FAILING - TDD RED PHASE)
  
  test "brand asset processing performance with large files" do
    # This test will fail until we implement performance optimizations
    
    # Test with varying file sizes
    file_sizes = [
      { size: 1.megabyte, max_time: 5.seconds, description: "small file" },
      { size: 10.megabytes, max_time: 15.seconds, description: "medium file" },
      { size: 50.megabytes, max_time: 30.seconds, description: "large file" }
    ]
    
    file_sizes.each do |file_spec|
      large_content = generate_content_of_size(file_spec[:size])
      
      brand_asset = @brand.brand_assets.create!(
        asset_type: "document",
        original_filename: "#{file_spec[:description]}.pdf",
        content_type: "application/pdf",
        extracted_text: large_content
      )
      
      start_time = Time.current
      result = brand_asset.process_with_ai
      processing_time = Time.current - start_time
      
      assert result[:success], "Processing failed for #{file_spec[:description]}"
      assert processing_time <= file_spec[:max_time], 
             "Processing took #{processing_time}s, expected <= #{file_spec[:max_time]}s for #{file_spec[:description]}"
      
      # Verify quality wasn't sacrificed for speed
      assert result[:accuracy_score] >= 0.85, "Accuracy too low for #{file_spec[:description]}"
    end
  end

  test "real-time compliance checking performance" do
    # This test will fail until we implement optimized real-time checking
    
    # Set up brand with processed guidelines
    @brand.brand_assets.create!(
      asset_type: "brand_guidelines",
      processing_status: "completed",
      extracted_text: create_comprehensive_brand_content
    )
    
    # Test response times for different content lengths
    content_tests = [
      { text: "Short message", max_time: 0.5.seconds },
      { text: "Medium length message " * 20, max_time: 1.0.seconds },
      { text: "Long message content " * 100, max_time: 2.0.seconds }
    ]
    
    content_tests.each do |test_case|
      start_time = Time.current
      result = @brand.messaging_framework.validate_message_realtime(test_case[:text])
      response_time = Time.current - start_time
      
      assert result[:validation_score].present?
      assert response_time <= test_case[:max_time],
             "Response time #{response_time}s exceeded maximum #{test_case[:max_time]}s"
    end
  end

  test "concurrent compliance checking performance" do
    # This test will fail until we implement concurrent processing
    
    @brand.brand_assets.create!(
      asset_type: "brand_guidelines", 
      processing_status: "completed",
      extracted_text: create_comprehensive_brand_content
    )
    
    # Simulate concurrent requests
    concurrent_requests = 10
    test_content = "This is test content for concurrent compliance checking."
    
    threads = []
    results = []
    
    start_time = Time.current
    
    concurrent_requests.times do |i|
      threads << Thread.new do
        result = @brand.messaging_framework.validate_message_realtime(test_content)
        results << { thread_id: i, result: result, completed_at: Time.current }
      end
    end
    
    threads.each(&:join)
    total_time = Time.current - start_time
    
    # All requests should complete successfully
    assert results.count == concurrent_requests
    assert results.all? { |r| r[:result][:validation_score].present? }
    
    # Should handle concurrent load efficiently
    assert total_time < 5.seconds, "Concurrent processing took too long: #{total_time}s"
    
    # Individual response times should remain reasonable
    response_times = results.map { |r| r[:completed_at] - start_time }
    max_response_time = response_times.max
    assert max_response_time < 3.seconds, "Max individual response time too high: #{max_response_time}s"
  end

  test "batch processing performance scaling" do
    # This test will fail until we implement efficient batch processing
    
    batch_sizes = [5, 20, 50, 100]
    
    batch_sizes.each do |batch_size|
      # Create batch of brand assets
      assets = []
      batch_size.times do |i|
        assets << @brand.brand_assets.create!(
          asset_type: "document",
          original_filename: "batch_#{i}.pdf",
          content_type: "application/pdf",
          extracted_text: "Brand content #{i}: " + create_sample_brand_content
        )
      end
      
      # Process batch and measure performance
      start_time = Time.current
      result = BrandAsset.process_batch(assets)
      processing_time = Time.current - start_time
      
      assert result[:success]
      assert result[:processed_count] == batch_size
      
      # Processing time should scale reasonably (not linearly)
      expected_max_time = batch_size * 0.5 # Max 0.5 seconds per asset
      assert processing_time <= expected_max_time,
             "Batch of #{batch_size} took #{processing_time}s, expected <= #{expected_max_time}s"
      
      # Throughput should be reasonable
      throughput = batch_size / processing_time
      assert throughput >= 2, "Throughput too low: #{throughput} assets/second"
    end
  end

  test "memory usage remains stable with large content processing" do
    # This test will fail until we implement memory-efficient processing
    
    initial_memory = get_memory_usage
    
    # Process increasingly large content
    [1000, 5000, 10000, 20000].each do |word_count|
      large_content = generate_content_of_words(word_count)
      
      brand_asset = @brand.brand_assets.create!(
        asset_type: "large_document",
        original_filename: "large_#{word_count}.pdf",
        content_type: "application/pdf",
        extracted_text: large_content
      )
      
      result = brand_asset.process_with_ai
      current_memory = get_memory_usage
      
      assert result[:success]
      
      # Memory usage shouldn't grow excessively
      memory_growth = current_memory - initial_memory
      max_allowed_growth = 100 # MB
      assert memory_growth <= max_allowed_growth,
             "Memory usage grew by #{memory_growth}MB processing #{word_count} words, max allowed: #{max_allowed_growth}MB"
    end
  end

  test "database query performance for brand compliance" do
    # This test will fail until we implement query optimizations
    
    # Create test data
    create_test_brand_data
    
    # Test common queries with performance expectations
    query_tests = [
      {
        name: "Find brand with guidelines",
        query: -> { @brand.brand_guidelines.active },
        max_queries: 2,
        max_time: 0.1.seconds
      },
      {
        name: "Get latest brand analysis",
        query: -> { @brand.latest_analysis },
        max_queries: 1,
        max_time: 0.05.seconds
      },
      {
        name: "Check brand asset processing status",
        query: -> { @brand.brand_assets.processed },
        max_queries: 1,
        max_time: 0.05.seconds
      }
    ]
    
    query_tests.each do |test|
      # Measure query performance
      start_time = Time.current
      query_count_before = count_queries
      
      result = test[:query].call
      
      query_count_after = count_queries
      execution_time = Time.current - start_time
      
      queries_executed = query_count_after - query_count_before
      
      assert result.present?, "Query '#{test[:name]}' returned no results"
      assert queries_executed <= test[:max_queries],
             "Query '#{test[:name]}' executed #{queries_executed} queries, max allowed: #{test[:max_queries]}"
      assert execution_time <= test[:max_time],
             "Query '#{test[:name]}' took #{execution_time}s, max allowed: #{test[:max_time]}s"
    end
  end

  test "API endpoint response time performance" do
    # This test will fail until we implement API optimizations
    
    @brand.brand_assets.create!(
      asset_type: "brand_guidelines",
      processing_status: "completed", 
      extracted_text: create_comprehensive_brand_content
    )
    
    # Test API endpoints with performance expectations
    api_tests = [
      {
        method: :post,
        path: -> { api_v1_brand_compliance_validate_path(@brand) },
        params: { content: { text: "Test content for validation" } },
        max_time: 2.0.seconds,
        description: "Real-time validation"
      },
      {
        method: :post,
        path: -> { api_v1_brand_compliance_score_path(@brand) },
        params: { content: { subject: "Test", body: "Content" } },
        max_time: 1.5.seconds,
        description: "Compliance scoring"
      },
      {
        method: :post,
        path: -> { api_v1_brand_compliance_batch_validate_path(@brand) },
        params: { 
          batch: { 
            items: [
              { id: "1", text: "First message" },
              { id: "2", text: "Second message" }
            ]
          }
        },
        max_time: 3.0.seconds,
        description: "Batch validation"
      }
    ]
    
    api_tests.each do |test|
      start_time = Time.current
      
      case test[:method]
      when :post
        post test[:path].call, params: test[:params]
      when :get
        get test[:path].call, params: test[:params]
      end
      
      response_time = Time.current - start_time
      
      assert_response :success, "API endpoint failed: #{test[:description]}"
      assert response_time <= test[:max_time],
             "API endpoint '#{test[:description]}' took #{response_time}s, max allowed: #{test[:max_time]}s"
    end
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password'
      }
    }
  end

  def generate_content_of_size(target_size_bytes)
    base_text = "This is sample brand content for performance testing. "
    content = ""
    
    while content.bytesize < target_size_bytes
      content += base_text
    end
    
    content[0...target_size_bytes]
  end

  def generate_content_of_words(word_count)
    words = %w[brand professional innovative customer service excellence quality trust reliable modern efficient]
    content = []
    
    word_count.times do
      content << words.sample
    end
    
    content.join(' ')
  end

  def create_comprehensive_brand_content
    <<~TEXT
      BRAND GUIDELINES
      Voice: Professional, approachable
      Tone: Confident, helpful
      
      DO:
      - Use clear language
      - Be professional
      - Focus on benefits
      
      DON'T:
      - Use slang
      - Be overly casual
      - Make false claims
    TEXT
  end

  def create_sample_brand_content
    <<~TEXT
      Sample Brand Content
      Voice: Professional
      Tone: Helpful
      Values: Quality, Innovation, Trust
    TEXT
  end

  def create_test_brand_data
    # Create brand guidelines
    5.times do |i|
      @brand.brand_guidelines.create!(
        rule_type: ["do", "dont"].sample,
        rule_content: "Test rule #{i}",
        category: ["voice", "tone", "style"].sample,
        priority: rand(1..10)
      )
    end
    
    # Create brand assets
    3.times do |i|
      @brand.brand_assets.create!(
        asset_type: "document",
        original_filename: "test_#{i}.pdf",
        content_type: "application/pdf",
        processing_status: "completed",
        extracted_text: "Sample content #{i}"
      )
    end
    
    # Create brand analysis
    @brand.brand_analyses.create!(
      analysis_status: "completed",
      voice_attributes: { tone: { primary: "professional" } },
      brand_values: [{ name: "Quality", score: 0.9 }],
      confidence_score: 0.85
    )
  end

  def get_memory_usage
    # Simplified memory usage tracking
    # In a real implementation, you'd use proper memory profiling tools
    GC.stat[:heap_allocated_pages] * 16 / 1024.0 # Approximate MB
  end

  def count_queries
    # Simplified query counting
    # In a real implementation, you'd use proper query logging
    ActiveRecord::Base.connection.query_cache.size
  end
end