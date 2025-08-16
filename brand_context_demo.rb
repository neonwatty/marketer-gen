#!/usr/bin/env ruby

# Brand Context Integration Demo
# This script demonstrates how the MockLlmService integrates brand context
# to generate brand-aware content.

require_relative 'config/environment'

puts "🎯 Brand Context Integration Demo"
puts "=" * 50

# Initialize the mock service
service = MockLlmService.new

# Demo 1: Social Media without Brand Context
puts "\n📱 Social Media Content - Without Brand Context:"
result1 = service.generate_social_media_content(
  platform: 'twitter',
  topic: 'new product launch',
  tone: 'professional'
)
puts "Content: #{result1[:content]}"
puts "Brand Applied: #{result1[:metadata][:brand_voice_applied]}"

# Demo 2: Social Media with Brand Context
puts "\n📱 Social Media Content - With Brand Context:"
brand_context = {
  voice: 'innovative',
  keywords: ['cutting-edge', 'revolutionary'],
  style: { emoji: 'minimal' }
}

result2 = service.generate_social_media_content(
  platform: 'twitter',
  topic: 'new product launch',
  tone: 'professional',
  brand_context: brand_context
)
puts "Content: #{result2[:content]}"
puts "Effective Tone: #{result2[:metadata][:tone]}"
puts "Brand Applied: #{result2[:metadata][:brand_voice_applied]}"

# Demo 3: Email with Brand Context
puts "\n📧 Email Content - With Brand Context:"
email_brand_context = {
  voice: 'trustworthy',
  keywords: ['reliable', 'quality'],
  style: { emoji: false, capitalization: 'sentence' }
}

result3 = service.generate_email_content(
  email_type: 'promotional',
  subject: 'product announcement',
  brand_context: email_brand_context
)
puts "Subject: #{result3[:subject]}"
puts "Content: #{result3[:content][0..100]}..."
puts "Brand Applied: #{result3[:metadata][:brand_voice_applied]}"

# Demo 4: Ad Copy with Brand Context
puts "\n🎯 Ad Copy - With Brand Context:"
ad_brand_context = {
  voice: 'authoritative',
  keywords: ['expert', 'trusted'],
  style: { emoji: false }
}

result4 = service.generate_ad_copy(
  ad_type: 'search',
  platform: 'google',
  objective: 'conversions',
  brand_context: ad_brand_context
)
puts "Headline: #{result4[:headline]}"
puts "Description: #{result4[:description]}"
puts "CTA: #{result4[:call_to_action]}"
puts "Brand Applied: #{result4[:metadata][:brand_voice_applied]}"

# Demo 5: Campaign Plan with Brand Context
puts "\n📋 Campaign Plan - With Brand Context:"
campaign_brand_context = {
  voice: 'creative',
  keywords: ['innovative', 'breakthrough'],
  style: { emoji: false }
}

result5 = service.generate_campaign_plan(
  campaign_type: 'product_launch',
  objective: 'brand_awareness',
  brand_context: campaign_brand_context
)
puts "Summary: #{result5[:summary][0..150]}..."
puts "Brand Applied: #{result5[:metadata][:brand_voice_applied]}"

puts "\n" + "=" * 50
puts "✅ Brand Context Integration Demo Complete!"
puts "\nKey Features Demonstrated:"
puts "• Brand voice mapping (innovative → enthusiastic, trustworthy → professional)"
puts "• Brand keyword injection into content"
puts "• Brand style preferences (emoji control, capitalization)"
puts "• Conditional application (only when brand_context provided)"
puts "• Metadata tracking (brand_voice_applied flag)"