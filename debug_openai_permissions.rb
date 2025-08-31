#!/usr/bin/env ruby

# Debug script to check OpenAI API permissions
require 'openai'

api_key = ENV['OPENAI_API_KEY'] || ARGV[0]

if api_key.nil? || api_key.empty?
  puts "Please provide API key: ruby debug_openai_permissions.rb YOUR_API_KEY"
  exit 1
end

puts "🔍 Debugging OpenAI API Permissions"
puts "=" * 50
puts "API Key: #{api_key[0..7]}..."

client = OpenAI::Client.new(
  access_token: api_key,
  log_errors: true
)

# Test 1: List models (usually works with most keys)
puts "\n📋 Test 1: Available Models"
puts "-" * 30

begin
  response = client.models
  models = response['data']
  
  if models&.any?
    puts "✅ Found #{models.length} available models:"
    relevant_models = models.select { |m| m['id'].include?('gpt') }.first(5)
    relevant_models.each { |model| puts "  - #{model['id']}" }
    
    # Find the simplest model to test with
    test_model = models.find { |m| m['id'] == 'gpt-3.5-turbo' } || 
                 models.find { |m| m['id'] == 'gpt-4o-mini' } ||
                 models.find { |m| m['id'].include?('gpt') }
    
    if test_model
      puts "\n🎯 Will test with model: #{test_model['id']}"
      
      # Test 2: Simple chat completion
      puts "\n📋 Test 2: Simple Chat Completion"
      puts "-" * 30
      
      test_response = client.chat(
        parameters: {
          model: test_model['id'],
          messages: [{ role: "user", content: "Say 'Hello World'" }],
          max_tokens: 10
        }
      )
      
      if test_response.dig('choices', 0, 'message', 'content')
        puts "✅ Chat completion successful!"
        puts "Response: #{test_response.dig('choices', 0, 'message', 'content')}"
        puts "\n🎉 Your API key is working! The issue was with the model selection."
        puts "Recommended model for this key: #{test_model['id']}"
      end
    end
  else
    puts "❌ No models available with this API key"
  end

rescue => error
  puts "❌ Models request failed:"
  puts "   #{error.class}: #{error.message}"
  
  # If models fails, try a basic chat request with different models
  puts "\n📋 Fallback Test: Try Basic Models"
  puts "-" * 30
  
  test_models = ['gpt-3.5-turbo', 'gpt-4o-mini', 'gpt-4o', 'gpt-4']
  
  test_models.each do |model|
    begin
      puts "Testing #{model}..."
      test_response = client.chat(
        parameters: {
          model: model,
          messages: [{ role: "user", content: "Hi" }],
          max_tokens: 5
        }
      )
      
      puts "✅ #{model} works!"
      puts "Response: #{test_response.dig('choices', 0, 'message', 'content')}"
      break
      
    rescue => model_error
      puts "❌ #{model} failed: #{model_error.message}"
    end
  end
end