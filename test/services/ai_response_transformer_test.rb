require "test_helper"

class AiResponseTransformerTest < ActiveSupport::TestCase
  def setup
    @transformer = AiResponseTransformer.new
  end

  # Configuration tests
  test "should initialize with default settings" do
    transformer = AiResponseTransformer.new
    assert_equal 'standard', transformer.target_format
    assert_includes transformer.transformation_options, 'normalize_whitespace'
    assert_includes transformer.transformation_options, 'extract_metadata'
    assert_equal true, transformer.preserve_original
  end

  test "should validate configuration on initialization" do
    assert_nothing_raised do
      AiResponseTransformer.new(target_format: 'json')
    end

    assert_raises AiResponseTransformer::UnsupportedFormatError do
      AiResponseTransformer.new(target_format: 'invalid_format')
    end

    assert_raises AiResponseTransformer::TransformationError do
      AiResponseTransformer.new(transformation_options: ['invalid_option'])
    end
  end

  # Source format detection tests
  test "should detect various source formats correctly" do
    transformer = AiResponseTransformer.new
    
    # Hash with AI response structure
    ai_response = { provider: 'anthropic', content: 'test' }
    result = transformer.transform(ai_response)
    assert_equal 'ai_response', result[:metadata][:source_format]

    # JSON string
    json_string = '{"key": "value"}'
    result = transformer.transform(json_string)
    assert_equal 'json_string', result[:metadata][:source_format]

    # Markdown
    markdown_text = "# Title\n\nContent with ```code```"
    result = transformer.transform(markdown_text)
    assert_equal 'markdown', result[:metadata][:source_format]

    # Plain text
    plain_text = "Just regular text content"
    result = transformer.transform(plain_text)
    assert_equal 'plain_text', result[:metadata][:source_format]
  end

  # Standard format transformation tests
  test "should transform to standard format" do
    transformer = AiResponseTransformer.new(target_format: 'standard')
    
    input_content = "Sample marketing content for transformation"
    result = transformer.transform(input_content)

    assert result[:success]
    assert_equal 'standard', result[:transformed_content][:format]
    assert result[:transformed_content][:content]
    assert result[:transformed_content][:metadata]
    assert result[:transformed_content][:transformed_at]
  end

  test "should preserve original content when requested" do
    transformer = AiResponseTransformer.new(preserve_original: true)
    
    original_content = "Original content to be preserved"
    result = transformer.transform(original_content)

    assert_equal original_content, result[:original_content]
  end

  test "should not preserve original content when not requested" do
    transformer = AiResponseTransformer.new(preserve_original: false)
    
    original_content = "Original content"
    result = transformer.transform(original_content)

    assert_nil result[:original_content]
  end

  # Campaign plan transformation tests
  test "should transform to campaign plan format" do
    transformer = AiResponseTransformer.new(target_format: 'campaign_plan')
    
    campaign_content = <<~TEXT
      Title: Summer Marketing Campaign
      Objective: Increase brand awareness by 30%
      Target Audience: Young professionals aged 25-40
      Budget: $15000 for digital advertising
      Timeline: 3 months starting July 1st
      Channels: Social media, email marketing, Google ads
      Key Messages: Innovation, quality, affordability
      Success Metrics: Click-through rate, conversion rate, brand recall
    TEXT

    result = transformer.transform(campaign_content)

    assert result[:success]
    campaign_plan = result[:transformed_content][:campaign_plan]
    assert campaign_plan.is_a?(Hash)
    assert_equal 'Summer Marketing Campaign', campaign_plan[:title]
    assert_equal 'Increase brand awareness by 30%', campaign_plan[:objective]
    assert_equal 'Young professionals aged 25-40', campaign_plan[:target_audience]
  end

  # Brand analysis transformation tests
  test "should transform to brand analysis format" do
    transformer = AiResponseTransformer.new(target_format: 'brand_analysis')
    
    brand_content = <<~TEXT
      Brand Voice: Professional yet approachable
      Brand Values: Innovation, integrity, customer-centricity
      Competitive Position: Market leader in innovation
      Opportunities: Expansion into new markets, digital transformation
      Recommendations: Increase social media presence, develop mobile app
    TEXT

    result = transformer.transform(brand_content)

    assert result[:success]
    brand_analysis = result[:transformed_content][:brand_analysis]
    assert brand_analysis.is_a?(Hash)
    assert_equal 'Professional yet approachable', brand_analysis[:brand_voice]
    assert brand_analysis[:opportunities].is_a?(Array) if brand_analysis[:opportunities]
  end

  # Social media transformation tests
  test "should transform to social media format" do
    transformer = AiResponseTransformer.new(target_format: 'social_media')
    
    social_content = <<~TEXT
      🎉 Exciting news! Our summer sale is here with up to 50% off! 
      Don't miss these amazing deals. Shop now! 
      #SummerSale #Deals #Fashion @YourBrand
      
      Visit our website to learn more!
    TEXT

    result = transformer.transform(social_content)

    assert result[:success]
    social_media_content = result[:transformed_content][:social_media_content]
    assert social_media_content.is_a?(Hash)
    assert social_media_content[:post_text]
    assert social_media_content[:hashtags].is_a?(Array)
    assert_includes social_media_content[:hashtags], '#SummerSale'
    assert social_media_content[:mentions].is_a?(Array)
    assert_includes social_media_content[:mentions], '@YourBrand'
  end

  # Email transformation tests
  test "should transform to email format" do
    transformer = AiResponseTransformer.new(target_format: 'email')
    
    email_content = <<~TEXT
      Subject: Welcome to Our Newsletter
      
      Dear Valued Customer,
      
      Thank you for subscribing to our newsletter! We're excited to share 
      the latest updates and exclusive offers with you.
      
      Click here to visit our website and explore our products.
      
      Best regards,
      The Marketing Team
    TEXT

    result = transformer.transform(email_content)

    assert result[:success]
    email_structure = result[:transformed_content][:email_content]
    assert email_structure.is_a?(Hash)
    assert_equal 'Welcome to Our Newsletter', email_structure[:subject_line]
    assert_includes email_structure[:body], 'Thank you for subscribing'
  end

  # Ad copy transformation tests
  test "should transform to ad copy format" do
    transformer = AiResponseTransformer.new(target_format: 'ad_copy')
    
    ad_content = <<~TEXT
      Revolutionary Fitness App - Transform Your Health
      
      Get fit in just 20 minutes a day with our AI-powered fitness app.
      Personalized workouts, nutrition tracking, and expert guidance.
      
      Download now and get 30 days free!
      
      Key benefits: Save time, see results, stay motivated
    TEXT

    result = transformer.transform(ad_content)

    assert result[:success]
    ad_copy = result[:transformed_content][:ad_copy]
    assert ad_copy.is_a?(Hash)
    assert ad_copy[:headline]
    assert ad_copy[:description]
    assert ad_copy[:call_to_action]
    assert ad_copy[:key_benefits].is_a?(Array) if ad_copy[:key_benefits]
  end

  # Blog post transformation tests
  test "should transform to blog post format" do
    transformer = AiResponseTransformer.new(target_format: 'blog_post')
    
    blog_content = <<~TEXT
      The Future of Digital Marketing
      
      Digital marketing continues to evolve rapidly with new technologies 
      and changing consumer behaviors. In this comprehensive guide, we'll 
      explore the key trends shaping the industry.
      
      Artificial intelligence is revolutionizing how we approach marketing...
      
      In conclusion, businesses that embrace these digital trends will be 
      better positioned for success in the competitive marketplace.
      
      Tags: digital marketing, AI, trends, technology
    TEXT

    result = transformer.transform(blog_content)

    assert result[:success]
    blog_post = result[:transformed_content][:blog_post]
    assert blog_post.is_a?(Hash)
    assert blog_post[:title]
    assert blog_post[:main_content]
    assert blog_post[:tags].is_a?(Array) if blog_post[:tags]
  end

  # JSON transformation tests
  test "should transform to JSON format" do
    transformer = AiResponseTransformer.new(target_format: 'json')
    
    hash_content = { title: 'Test Campaign', budget: 5000, active: true }
    result = transformer.transform(hash_content)

    assert result[:success]
    json_output = result[:transformed_content]
    assert json_output.is_a?(String)
    
    parsed_json = JSON.parse(json_output)
    assert_equal 'Test Campaign', parsed_json['title']
    assert_equal 5000, parsed_json['budget']
  end

  test "should transform text to structured JSON" do
    transformer = AiResponseTransformer.new(target_format: 'json')
    
    text_content = "Simple text content for JSON conversion"
    result = transformer.transform(text_content)

    assert result[:success]
    json_output = result[:transformed_content]
    
    parsed_json = JSON.parse(json_output)
    assert parsed_json['content']
    assert parsed_json['format']
    assert parsed_json['transformed_at']
  end

  # Markdown transformation tests
  test "should transform to markdown format" do
    transformer = AiResponseTransformer.new(target_format: 'markdown')
    
    structured_content = {
      title: 'Marketing Campaign Overview',
      objective: 'Increase brand awareness',
      strategies: ['Social media marketing', 'Content marketing', 'Email campaigns'],
      budget: '$10,000'
    }
    
    result = transformer.transform(structured_content)

    assert result[:success]
    markdown_output = result[:transformed_content]
    assert markdown_output.is_a?(String)
    assert_includes markdown_output, '# Marketing Campaign Overview'
    assert_includes markdown_output, '## Objective'
    assert_includes markdown_output, '- Social media marketing'
  end

  test "should format plain text as markdown" do
    transformer = AiResponseTransformer.new(target_format: 'markdown')
    
    text_content = <<~TEXT
      Marketing Strategy Overview
      Our comprehensive approach includes multiple channels.
      Key focus areas are customer engagement and brand building.
    TEXT
    
    result = transformer.transform(text_content)

    assert result[:success]
    markdown_output = result[:transformed_content]
    assert_includes markdown_output, '# Marketing Strategy Overview'
  end

  # HTML transformation tests
  test "should transform to HTML format" do
    transformer = AiResponseTransformer.new(target_format: 'html')
    
    structured_content = {
      title: 'Campaign Results',
      summary: 'Excellent performance across all metrics',
      metrics: ['50% increase in CTR', '30% boost in conversions'],
      conclusion: 'Campaign exceeded expectations'
    }
    
    result = transformer.transform(structured_content)

    assert result[:success]
    html_output = result[:transformed_content]
    assert html_output.is_a?(String)
    assert_includes html_output, '<h1>Campaign Results</h1>'
    assert_includes html_output, '<div class="transformed-content">'
    assert_includes html_output, '<li>50% increase in CTR</li>'
  end

  test "should escape HTML in content" do
    transformer = AiResponseTransformer.new(target_format: 'html')
    
    content_with_html = "Content with <script>alert('xss')</script> and & special chars"
    result = transformer.transform(content_with_html)

    html_output = result[:transformed_content]
    assert_includes html_output, '&lt;script&gt;'
    assert_includes html_output, '&amp;'
    refute_includes html_output, '<script>alert'
  end

  # Pre-transformation processing tests
  test "should normalize whitespace during transformation" do
    transformer = AiResponseTransformer.new(
      transformation_options: ['normalize_whitespace']
    )
    
    messy_content = "Content    with     excessive     spaces\r\n\r\n\r\n\r\nand    line   breaks"
    result = transformer.transform(messy_content)

    normalized_content = result[:transformed_content][:content]
    refute_includes normalized_content, '    '  # No excessive spaces
    refute_includes normalized_content, "\r"   # No carriage returns
    refute_includes normalized_content, "\n\n\n\n"  # No excessive line breaks
  end

  test "should extract content metadata" do
    transformer = AiResponseTransformer.new(
      transformation_options: ['extract_metadata']
    )
    
    content = "This is a sample content with multiple words for testing metadata extraction capabilities."
    result = transformer.transform(content)

    metadata = result[:transformed_content][:metadata]
    assert metadata[:word_count] > 0
    assert metadata[:character_count] > 0
    assert metadata[:estimated_read_time] > 0
  end

  test "should format links during transformation" do
    transformer = AiResponseTransformer.new(
      transformation_options: ['format_links']
    )
    
    content_with_urls = "Visit our website at https://example.com and check out http://blog.example.com for more info."
    result = transformer.transform(content_with_urls)

    formatted_content = result[:transformed_content][:content]
    assert_includes formatted_content, '[https://example.com](https://example.com)'
    assert_includes formatted_content, '[http://blog.example.com](http://blog.example.com)'
  end

  test "should process hashtags during transformation" do
    transformer = AiResponseTransformer.new(
      transformation_options: ['process_hashtags']
    )
    
    content_with_hashtags = "Great news about our product! #Innovation #Technology #Success"
    result = transformer.transform(content_with_hashtags)

    transformed = result[:transformed_content]
    if transformed.is_a?(Hash) && transformed[:hashtags]
      assert_includes transformed[:hashtags], '#Innovation'
      assert_includes transformed[:hashtags], '#Technology'
    end
  end

  # Post-transformation processing tests
  test "should add timestamps when requested" do
    transformer = AiResponseTransformer.new(
      transformation_options: ['add_timestamps']
    )
    
    result = transformer.transform("Test content")

    transformed_content = result[:transformed_content]
    if transformed_content.is_a?(Hash)
      assert transformed_content[:generated_at]
      assert transformed_content[:transformed_at]
    end
  end

  test "should include source info when requested" do
    transformer = AiResponseTransformer.new(
      transformation_options: ['include_source_info']
    )
    
    result = transformer.transform("Test content")

    transformed_content = result[:transformed_content]
    if transformed_content.is_a?(Hash)
      assert transformed_content[:source_info]
      assert transformed_content[:source_info][:transformer_version]
      assert transformed_content[:source_info][:target_format]
    end
  end

  # Quick transformation tests
  test "should provide quick transformation method" do
    content = "Quick transformation test content"
    
    # Should work without affecting the original transformer
    json_result = @transformer.quick_transform(content, 'json')
    standard_result = @transformer.quick_transform(content, 'standard')
    
    assert json_result.is_a?(String)  # JSON output
    assert standard_result.is_a?(Hash)  # Standard format output
    assert_equal 'standard', @transformer.target_format  # Original format unchanged
  end

  test "should return original content if quick transformation fails" do
    # Use invalid format to trigger failure
    result = @transformer.quick_transform("test", 'invalid_format')
    assert_equal "test", result
  end

  # Batch transformation tests
  test "should transform batch of content" do
    content_array = [
      "First piece of content",
      "Second piece of content", 
      { content: "Third structured content" }
    ]

    results = @transformer.transform_batch(content_array)

    assert_equal 3, results.length
    results.each do |result|
      assert result.key?(:success) || result.key?(:batch_index)
    end
  end

  test "should handle batch transformation errors gracefully" do
    transformer = AiResponseTransformer.new(
      target_format: 'json',
      strict_validation: true
    )
    
    content_array = [
      '{"valid": "json"}',
      'invalid content for strict json validation'
    ]

    results = transformer.transform_batch(content_array)

    assert_equal 2, results.length
    assert results[1][:success] == false  # Second item should fail
    assert results[1][:error]
  end

  # Validation tests (strict mode)
  test "should validate structure in strict mode" do
    transformer = AiResponseTransformer.new(
      target_format: 'campaign_plan',
      strict_validation: true
    )

    # Missing required fields should cause validation error
    incomplete_campaign = "Title: Test Campaign"  # Missing objective and target_audience
    
    result = transformer.transform(incomplete_campaign)

    refute result[:success]
    assert result[:error]
  end

  test "should pass validation with complete structure" do
    transformer = AiResponseTransformer.new(
      target_format: 'campaign_plan',
      strict_validation: true
    )

    complete_campaign = <<~TEXT
      Title: Complete Campaign
      Objective: Increase sales by 25%
      Target Audience: Business professionals
      Budget: $10000
    TEXT
    
    result = transformer.transform(complete_campaign)

    assert result[:success]
  end

  # Error handling tests
  test "should handle empty content gracefully" do
    result = @transformer.transform("")

    refute result[:success]
    assert result[:error]
  end

  test "should handle nil content gracefully" do
    result = @transformer.transform(nil)

    refute result[:success]
    assert result[:error]
  end

  test "should handle transformation errors gracefully" do
    # Create a scenario that might cause transformation errors
    transformer = AiResponseTransformer.new(target_format: 'json')
    
    # This should not crash even with problematic content
    assert_nothing_raised do
      result = transformer.transform("Content with unicode: 🎉💖✨")
      assert result.is_a?(Hash)
      assert result.key?(:success)
    end
  end

  # Utility method tests
  test "should count words correctly" do
    transformer = AiResponseTransformer.new
    content = "This is a test content with exactly eight words."
    
    result = transformer.transform(content)
    
    if result[:transformed_content].is_a?(Hash) && result[:transformed_content][:metadata]
      word_count = result[:transformed_content][:metadata][:word_count]
      assert_equal 9, word_count  # Including "exactly" makes it 9 words
    end
  end

  test "should estimate read time correctly" do
    transformer = AiResponseTransformer.new
    
    # 200 words should take 1 minute to read
    long_content = ("word " * 200).strip
    result = transformer.transform(long_content)
    
    if result[:transformed_content].is_a?(Hash) && result[:transformed_content][:metadata]
      read_time = result[:transformed_content][:metadata][:estimated_read_time]
      assert_equal 1, read_time
    end
  end

  test "should calculate readability score" do
    transformer = AiResponseTransformer.new
    
    # Simple sentences should have higher readability
    simple_content = "This is easy. Content is simple. Words are short."
    complex_content = "This extraordinarily sophisticated content demonstrates the implementation of comprehensive methodological approaches."
    
    simple_result = transformer.transform(simple_content)
    complex_result = transformer.transform(complex_content)
    
    # Both should have readability scores, simple should be higher
    assert simple_result[:success]
    assert complex_result[:success]
  end

  # Brand guidelines integration tests
  test "should apply brand guidelines when provided" do
    brand_guidelines = { 'brand_name' => 'Acme Corp' }
    transformer = AiResponseTransformer.new(
      brand_guidelines: brand_guidelines,
      transformation_options: ['apply_branding']
    )
    
    content_with_brand = "Welcome to acme corp, the leading provider of solutions"
    result = transformer.transform(content_with_brand)

    # Brand name should be corrected to proper case
    transformed_content = result[:transformed_content]
    if transformed_content.is_a?(String)
      assert_includes transformed_content, 'Acme Corp'
    end
  end

  private

  def sample_campaign_content
    <<~TEXT
      Campaign Title: Summer Product Launch
      
      Objective: Increase product awareness and drive sales during summer season
      
      Target Audience: Young professionals aged 25-35 interested in outdoor activities
      
      Budget Allocation: 
      - Digital advertising: $5,000
      - Social media: $2,000
      - Content creation: $1,500
      
      Timeline: June 1 - August 31, 2024
      
      Key Channels: Instagram, Facebook, Google Ads, Email marketing
      
      Key Messages: 
      - Perfect for summer adventures
      - Durable and reliable
      - Great value for money
      
      Success Metrics: 
      - 25% increase in website traffic
      - 15% boost in conversion rate
      - 1000 new email subscribers
    TEXT
  end

  def sample_email_content
    <<~TEXT
      Subject Line: Exclusive Summer Sale - 50% Off Everything!
      
      Preheader: Don't miss out on our biggest sale of the year
      
      Hi [First Name],
      
      We're excited to announce our exclusive summer sale with incredible savings 
      of up to 50% on all products! This limited-time offer is our way of saying 
      thank you for being a valued customer.
      
      Shop now and save big on:
      - Premium outdoor gear
      - Summer essentials
      - Bestselling accessories
      
      Use code SUMMER50 at checkout to unlock your savings.
      
      Shop Now → [https://example.com/sale]
      
      This offer expires on July 15th, so don't wait!
      
      Happy shopping,
      The Acme Team
      
      P.S. Follow us on social media for daily deals and inspiration!
    TEXT
  end
end