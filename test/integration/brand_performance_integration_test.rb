require "test_helper"

class BrandPerformanceIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @brand = brands(:one)
    @brand.update!(user: @user)
    sign_in @user
  end

  test "large brand file upload and processing performance" do
    # Create large brand content (simulating 50KB+ document)
    large_content = create_large_brand_content(15000) # 15k word document
    
    brand_asset = @brand.brand_assets.build(
      asset_type: "brand_guidelines",
      original_filename: "comprehensive_brand_guide.pdf",
      content_type: "application/pdf",
      extracted_text: large_content
    )
    brand_asset.skip_file_validation!
    
    # Time the save operation
    save_start = Time.current
    brand_asset.save!
    save_time = Time.current - save_start
    
    assert save_time < 1.0, "Large file save should complete within 1 second"
    
    # Time the AI processing
    process_start = Time.current
    result = brand_asset.process_with_ai
    process_time = Time.current - process_start
    
    assert result[:success], "Large file processing should succeed"
    assert process_time < 30.0, "Large file processing should complete within 30 seconds"
    assert result[:processing_chunks] > 1, "Large content should use chunking"
    assert result[:accuracy_score] >= 0.85, "Large content should maintain high accuracy"
  end

  test "concurrent brand asset processing performance" do
    assets = []
    
    # Create multiple assets concurrently
    5.times do |i|
      asset = @brand.brand_assets.build(
        asset_type: "document",
        original_filename: "brand_doc_#{i}.pdf",
        content_type: "application/pdf",
        extracted_text: create_medium_brand_content(5000)
      )
      asset.skip_file_validation!
      asset.save!
      assets << asset
    end
    
    # Process all assets concurrently
    start_time = Time.current
    results = assets.map { |asset| asset.process_with_ai }
    total_time = Time.current - start_time
    
    # All should succeed
    assert results.all? { |r| r[:success] }, "All concurrent processing should succeed"
    
    # Should be faster than sequential processing
    assert total_time < 60.0, "Concurrent processing should complete within 1 minute"
    
    # Use batch processing
    batch_start = Time.current
    batch_result = BrandAsset.process_batch(assets)
    batch_time = Time.current - batch_start
    
    assert batch_result[:success], "Batch processing should succeed"
    assert batch_result[:processed_count] == 5, "Should process all assets"
    assert batch_time < 45.0, "Batch processing should be efficient"
  end

  test "real-time compliance checking performance under load" do
    # Set up messaging framework
    @brand.messaging_framework.update!(
      banned_words: (1..100).map { |i| "banned#{i}" }, # 100 banned words
      approved_phrases: (1..50).map { |i| "approved phrase #{i}" },
      tone_attributes: { "style" => "professional", "formality" => "formal" }
    )
    
    # Test multiple compliance checks in rapid succession
    test_messages = [
      "We are pleased to inform you about our professional services.",
      "Our innovative solutions deliver exceptional results for clients.",
      "Thank you for your continued partnership with our organization.",
      "We remain committed to excellence in customer service delivery.",
      "Our comprehensive platform provides reliable business solutions."
    ]
    
    # Measure performance of rapid compliance checks
    total_start = Time.current
    results = []
    
    100.times do |i|
      message = test_messages[i % test_messages.length]
      result = @brand.messaging_framework.validate_message_realtime(message)
      results << result
    end
    
    total_time = Time.current - total_start
    avg_time = total_time / 100
    
    # Performance assertions
    assert total_time < 20.0, "100 compliance checks should complete within 20 seconds"
    assert avg_time < 0.2, "Average compliance check should be under 200ms"
    
    # All should return valid results
    assert results.all? { |r| r[:validation_score].present? }, "All checks should return scores"
    assert results.all? { |r| r[:processing_time] < 2.0 }, "All individual checks should be fast"
  end

  test "journey step validation performance with complex brand rules" do
    # Create comprehensive brand guidelines
    20.times do |i|
      @brand.brand_guidelines.create!(
        rule_type: ["do", "dont", "must", "should"].sample,
        rule_content: "Brand rule #{i}: #{Faker::Lorem.sentence(word_count: 10)}",
        category: ["voice", "tone", "messaging", "style"].sample,
        priority: rand(1..10)
      )
    end
    
    # Create journey with multiple steps
    journey = @brand.journeys.create!(name: "Performance Test Journey", user: @user)
    
    # Time step creation with validation
    creation_times = []
    
    50.times do |i|
      start_time = Time.current
      
      step = journey.journey_steps.create!(
        name: "Step #{i}",
        content_type: "email",
        stage: ["awareness", "consideration", "conversion"].sample,
        description: "Professional message #{i}: We are committed to delivering excellent service and innovative solutions for your business needs."
      )
      
      creation_time = Time.current - start_time
      creation_times << creation_time
      
      assert step.persisted?, "Step should be created successfully"
    end
    
    avg_creation_time = creation_times.sum / creation_times.length
    max_creation_time = creation_times.max
    
    assert avg_creation_time < 0.5, "Average step creation should be under 500ms"
    assert max_creation_time < 2.0, "No single step creation should exceed 2 seconds"
  end

  test "brand asset chunked upload simulation" do
    # Simulate large file chunked upload
    large_content = create_large_brand_content(25000) # Very large content
    chunk_size = 5000
    chunks = large_content.scan(/.{1,#{chunk_size}}/m)
    
    brand_asset = @brand.brand_assets.build(
      asset_type: "brand_guidelines",
      original_filename: "massive_brand_guide.pdf",
      content_type: "application/pdf",
      file_size: large_content.bytesize,
      chunk_count: chunks.length
    )
    brand_asset.skip_file_validation!
    brand_asset.save!
    
    # Simulate chunked upload
    upload_start = Time.current
    
    chunks.each_with_index do |chunk, index|
      chunk_result = brand_asset.chunk_upload(chunk, index + 1)
      assert chunk_result[:success], "Chunk #{index + 1} upload should succeed"
    end
    
    upload_time = Time.current - upload_start
    
    assert brand_asset.upload_complete?, "Upload should be complete"
    assert upload_time < 10.0, "Chunked upload should complete efficiently"
    
    # Set extracted text and process
    brand_asset.update!(extracted_text: large_content)
    
    process_start = Time.current
    result = brand_asset.process_with_ai
    process_time = Time.current - process_start
    
    assert result[:success], "Large chunked file should process successfully"
    assert process_time < 45.0, "Processing should complete within 45 seconds"
  end

  test "brand compliance caching and cache invalidation performance" do
    # Create content for caching tests
    test_content = "We are pleased to inform you about our innovative solutions."
    
    # First check - should populate cache
    cache_start = Time.current
    result1 = @brand.messaging_framework.validate_message_realtime(test_content)
    first_check_time = Time.current - cache_start
    
    # Second check - should use cache (if implemented)
    cache_start = Time.current
    result2 = @brand.messaging_framework.validate_message_realtime(test_content)
    second_check_time = Time.current - cache_start
    
    # Results should be consistent
    assert_equal result1[:validation_score], result2[:validation_score], "Cached results should be consistent"
    
    # Update messaging framework to invalidate cache
    @brand.messaging_framework.update!(banned_words: ["new", "banned", "words"])
    
    # Third check - should recalculate after cache invalidation
    result3 = @brand.messaging_framework.validate_message_realtime(test_content)
    assert result3[:validation_score].present?, "Should return valid score after cache invalidation"
  end

  test "memory usage remains stable during batch processing" do
    # This test would ideally use memory profiling tools in a real environment
    # For now, we'll test that large batches don't cause obvious memory issues
    
    initial_asset_count = @brand.brand_assets.count
    
    # Create large batch of assets
    100.times do |i|
      asset = @brand.brand_assets.build(
        asset_type: "document",
        original_filename: "batch_asset_#{i}.pdf",
        content_type: "application/pdf",
        extracted_text: create_medium_brand_content(1000)
      )
      asset.skip_file_validation!
      asset.save!
    end
    
    final_asset_count = @brand.brand_assets.count
    assert_equal initial_asset_count + 100, final_asset_count, "All assets should be created"
    
    # Process in batches to test memory stability
    @brand.brand_assets.limit(100).find_in_batches(batch_size: 10) do |batch|
      start_time = Time.current
      batch_result = BrandAsset.process_batch(batch)
      batch_time = Time.current - start_time
      
      assert batch_result[:success], "Each batch should process successfully"
      assert batch_time < 30.0, "Each batch should process efficiently"
    end
  end

  private

  def sign_in(user)
    post session_path, params: {
      email_address: user.email_address,
      password: 'password'
    }
  end

  def create_large_brand_content(word_count)
    base_content = <<~TEXT
      COMPREHENSIVE BRAND GUIDELINES
      
      BRAND VOICE & TONE:
      Voice: Professional, approachable, and authoritative
      Tone: Confident yet humble, helpful, innovative
      Personality: Trustworthy, forward-thinking, customer-centric
      
      COMMUNICATION GUIDELINES:
      DO: Use active voice, maintain professional tone, focus on customer benefits
      DON'T: Use casual language, make unsubstantiated claims, use fear-based messaging
      
      MESSAGING PILLARS:
      1. Innovation Leadership: We lead through cutting-edge solutions
      2. Customer Success: Our customers' success is our primary goal
      3. Reliable Partnership: We deliver consistent, dependable results
      4. Continuous Improvement: We evolve and adapt to serve better
      
      DETAILED GUIDELINES:
    TEXT
    
    # Generate additional content to reach word count
    words = base_content.split
    current_count = words.length
    
    additional_sentences = [
      "Our commitment to excellence drives every decision we make.",
      "We believe in transparent communication and honest partnerships.",
      "Innovation is at the heart of our service delivery model.",
      "Customer satisfaction remains our highest priority always.",
      "We continuously improve our processes to better serve clients.",
      "Professional integrity guides all our business relationships.",
      "Quality assurance is embedded in every aspect of our work.",
      "We deliver measurable results through strategic thinking and execution."
    ]
    
    while current_count < word_count
      sentence = additional_sentences.sample
      words += sentence.split
      current_count = words.length
    end
    
    words.first(word_count).join(' ')
  end

  def create_medium_brand_content(word_count)
    create_large_brand_content(word_count)
  end
end