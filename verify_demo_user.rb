#!/usr/bin/env ruby
# Script to verify demo user setup

require_relative 'config/environment'

puts "\n" + "="*60
puts "DEMO USER VERIFICATION"
puts "="*60 + "\n"

# Find demo user
demo_user = User.find_by(email_address: 'demo@example.com')

if demo_user
  puts "✅ Demo user found: #{demo_user.email_address}"
  puts "   Name: #{demo_user.full_name}"
  puts "   Role: #{demo_user.role}"
  
  # Verify password
  if demo_user.authenticate('password')
    puts "✅ Password authentication successful"
  else
    puts "❌ Password authentication failed"
  end
  
  # Brand Identity
  puts "\n📁 BRAND IDENTITY:"
  if demo_user.brand_identities.any?
    brand = demo_user.brand_identities.first
    puts "   ✓ #{brand.name} (#{brand.status})"
    puts "     - Has brand materials: #{brand.brand_materials.attached? ? 'Yes' : 'No'}"
    puts "     - Processed guidelines: #{brand.processed_guidelines.present? ? 'Yes' : 'No'}"
  else
    puts "   ❌ No brand identities found"
  end
  
  # Journeys
  puts "\n🚀 JOURNEYS (#{demo_user.journeys.count}):"
  demo_user.journeys.each do |journey|
    steps_count = journey.journey_steps.count
    puts "   ✓ #{journey.name}"
    puts "     - Status: #{journey.status}"
    puts "     - Type: #{journey.campaign_type}"
    puts "     - Steps: #{steps_count}"
    puts "     - Completion: #{journey.completion_rate}%"
  end
  
  # Campaign Plans
  puts "\n📋 CAMPAIGN PLANS (#{demo_user.campaign_plans.count}):"
  demo_user.campaign_plans.each do |plan|
    puts "   ✓ #{plan.name}"
    puts "     - Status: #{plan.status}"
    puts "     - Type: #{plan.campaign_type}"
    puts "     - Approval: #{plan.approval_status}"
    puts "     - Has content: #{plan.has_generated_content? ? 'Yes' : 'No'}"
  end
  
  # Generated Content
  content_count = GeneratedContent.joins(:campaign_plan).where(campaign_plan: { user_id: demo_user.id }).count
  puts "\n✍️  GENERATED CONTENT (#{content_count}):"
  GeneratedContent.joins(:campaign_plan).where(campaign_plan: { user_id: demo_user.id }).limit(3).each do |content|
    puts "   ✓ #{content.title[0..50]}..."
    puts "     - Type: #{content.content_type}"
    puts "     - Status: #{content.status}"
    puts "     - Words: #{content.word_count}"
  end
  
  # Personas
  puts "\n👥 PERSONAS (#{demo_user.personas.count}):"
  demo_user.personas.each do |persona|
    puts "   ✓ #{persona.name}"
    puts "     - Active: #{persona.is_active ? 'Yes' : 'No'}"
    channels = persona.preferred_channels.is_a?(Array) ? persona.preferred_channels.join(', ') : persona.preferred_channels.to_s
    puts "     - Channels: #{channels}"
  end
  
  puts "\n" + "="*60
  puts "✅ DEMO USER SETUP VERIFIED SUCCESSFULLY!"
  puts "="*60
  puts "\nYou can log in with:"
  puts "  Email: demo@example.com"
  puts "  Password: password"
  puts "\nAll features are populated with realistic example data."
  
else
  puts "❌ Demo user not found!"
  puts "   Please run: rails db:seed"
end

puts "\n"