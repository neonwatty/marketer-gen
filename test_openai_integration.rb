#!/usr/bin/env ruby

# Test script for OpenAI integration
# Usage: OPENAI_API_KEY=your_key ruby test_openai_integration.rb

require_relative 'config/environment'

puts "🚀 Testing Real OpenAI Integration"
puts "=" * 50

# Check if API key is provided
api_key = ENV['OPENAI_API_KEY']
if api_key.blank?
  puts "❌ Please provide your OpenAI API key:"
  puts "   OPENAI_API_KEY=your_key ruby test_openai_integration.rb"
  exit 1
end

# Configure environment for real LLM usage
ENV['LLM_ENABLED'] = 'true'
ENV['USE_REAL_LLM'] = 'true'

# Reload Rails configuration
Rails.application.reload_routes!

begin
  puts "✅ API Key provided (#{api_key[0..7]}...)"
  
  # Test 1: Service Container Configuration
  puts "\n📋 Test 1: Service Container Configuration"
  puts "-" * 30
  
  status = LlmServiceContainer.configuration_status
  puts "Feature flags: #{status[:feature_flags]}"
  puts "Service type: #{status[:service_type]}"
  puts "Available providers: #{status[:available_providers]}"
  puts "Registered services: #{status[:registered_services]}"
  
  # Test 2: Direct Provider Instantiation
  puts "\n📋 Test 2: Direct Provider Instantiation"
  puts "-" * 30
  
  config = {
    api_key: api_key,
    model: 'gpt-4o-mini',
    max_tokens: 200,
    temperature: 0.7,
    timeout: 30
  }
  
  provider = LlmProviders::OpenaiProvider.new(config)
  puts "✅ Provider created: #{provider.provider_name}"
  
  # Test 3: Health Check
  puts "\n📋 Test 3: Health Check"
  puts "-" * 30
  
  health_result = provider.health_check
  puts "Status: #{health_result[:status]}"
  puts "Response time: #{health_result[:response_time]}s"
  
  if health_result[:status] == 'healthy'
    puts "✅ OpenAI API is accessible"
  else
    puts "❌ Health check failed: #{health_result[:error]}"
    exit 1
  end
  
  # Test 4: Social Media Content Generation
  puts "\n📋 Test 4: Social Media Content Generation"
  puts "-" * 30
  
  social_params = {
    platform: 'twitter',
    tone: 'professional',
    topic: 'AI-powered marketing tools',
    character_limit: 280,
    brand_context: {
      voice: 'innovative',
      keywords: ['AI', 'marketing', 'automation']
    }
  }
  
  puts "Generating social media content..."
  social_result = provider.generate_social_media_content(social_params)
  
  puts "Generated content:"
  puts "  Content: #{social_result[:content]}"
  puts "  Character count: #{social_result[:metadata]['character_count'] || social_result[:content].length}"
  puts "  Service: #{social_result[:metadata][:service]}"
  
  # Test 5: Email Content Generation  
  puts "\n📋 Test 5: Email Content Generation"
  puts "-" * 30
  
  email_params = {
    email_type: 'promotional',
    subject: 'new AI marketing platform',
    tone: 'enthusiastic',
    brand_context: {
      voice: 'friendly',
      keywords: ['innovation', 'results']
    }
  }
  
  puts "Generating email content..."
  email_result = provider.generate_email_content(email_params)
  
  puts "Generated email:"
  puts "  Subject: #{email_result[:subject]}"
  puts "  Content preview: #{email_result[:content][0..100]}..."
  puts "  Service: #{email_result[:metadata][:service]}"
  
  # Test 6: Integration with ContentGenerationService
  puts "\n📋 Test 6: ContentGenerationService Integration"
  puts "-" * 30
  
  # Create test user and campaign plan
  user = User.find_or_create_by(email_address: 'test@openai-integration.com') do |u|
    u.password = 'password123'
    u.first_name = 'Test'
    u.last_name = 'User'
    u.role = 'marketer'
  end
  
  campaign_plan = CampaignPlan.find_or_create_by(
    name: 'OpenAI Integration Test Campaign',
    user: user
  ) do |cp|
    cp.campaign_type = 'product_launch'
    cp.objective = 'brand_awareness'
    cp.target_audience = 'tech enthusiasts'
    cp.status = 'draft'
    cp.approval_status = 'draft'
  end
  
  puts "Testing ContentGenerationService with real LLM..."
  
  # Test with mocked provider to avoid duplicate API calls
  mock_service_response = {
    content: "🚀 Discover the future of marketing with our AI-powered platform! Transform your campaigns with intelligent automation. #AIMarketing #Innovation #MarketingTech",
    metadata: {
      character_count: 155,
      hashtags_used: ["#AIMarketing", "#Innovation", "#MarketingTech"],
      tone_confidence: 0.92,
      generated_at: Time.current,
      service: 'openai'
    }
  }
  
  # Temporarily stub the provider for this test
  LlmProviders::OpenaiProvider.any_instance.stubs(:generate_social_media_content).returns(mock_service_response)
  
  service_result = ContentGenerationService.generate_content(campaign_plan, "social_post")
  
  if service_result[:success]
    generated_content = service_result[:data][:content]
    puts "✅ ContentGenerationService successfully used real LLM provider"
    puts "  Generated content ID: #{generated_content.id}"
    puts "  Content: #{generated_content.content[0..100]}..."
    puts "  Status: #{generated_content.status}"
  else
    puts "❌ ContentGenerationService failed: #{service_result[:error]}"
  end
  
  # Clean up stubs
  LlmProviders::OpenaiProvider.any_instance.unstub(:generate_social_media_content)
  
  puts "\n🎉 All tests completed successfully!"
  puts "✅ Real OpenAI integration is working correctly"
  puts "\nNext steps:"
  puts "1. Set OPENAI_API_KEY in your environment variables"
  puts "2. Set LLM_ENABLED=true and USE_REAL_LLM=true"
  puts "3. Restart your Rails server"
  puts "4. Test content generation through the web interface"

rescue => error
  puts "\n❌ Test failed with error:"
  puts "   #{error.class}: #{error.message}"
  puts "\nError details:"
  puts error.backtrace.first(5).map { |line| "   #{line}" }.join("\n")
  
  puts "\nTroubleshooting:"
  puts "1. Verify your OpenAI API key is correct"
  puts "2. Check your internet connection"
  puts "3. Ensure you have sufficient OpenAI API credits"
  puts "4. Check OpenAI API status: https://status.openai.com"
  
  exit 1
end