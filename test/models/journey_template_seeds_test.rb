require "test_helper"

class JourneyTemplateSeedsTest < ActiveSupport::TestCase
  setup do
    # Clear existing templates to avoid conflicts
    JourneyTemplate.delete_all
    # Load seeds fresh for each test
    Rails.application.load_seed
  end

  test "seeded templates have valid structure and data" do
    
    expected_templates = [
      { name: 'Product Launch Campaign', campaign_type: 'awareness' },
      { name: 'Lead Generation Campaign', campaign_type: 'consideration' },
      { name: 'Re-Engagement Campaign', campaign_type: 'retention' },
      { name: 'Brand Awareness Campaign', campaign_type: 'upsell_cross_sell' }
    ]
    
    expected_templates.each do |template_info|
      template = JourneyTemplate.find_by(name: template_info[:name])
      
      assert template.present?, "Template '#{template_info[:name]}' should exist"
      assert_equal template_info[:campaign_type], template.campaign_type
      assert template.is_default?, "Template should be marked as default"
      
      # Validate template data structure
      assert template.template_data['stages'].present?, "Template should have stages"
      assert template.template_data['steps'].present?, "Template should have steps"
      assert template.template_data['metadata'].present?, "Template should have metadata"
      
      # Validate each step has required fields
      template.template_data['steps'].each_with_index do |step, index|
        assert step['title'].present?, "Step #{index} should have title"
        assert step['step_type'].present?, "Step #{index} should have step_type"
        assert step['stage'].present?, "Step #{index} should have stage"
        assert step['channel'].present?, "Step #{index} should have channel"
      end
      
      # Validate metadata completeness
      metadata = template.template_data['metadata']
      assert metadata['timeline'].present?, "Template should have timeline"
      assert metadata['key_metrics'].present?, "Template should have key_metrics"
      assert metadata['target_audience'].present?, "Template should have target_audience"
    end
  end

  test "each seeded template creates functional journeys" do
    user = users(:one)
    
    JourneyTemplate.default_templates.each do |template|
      journey = template.create_journey_for_user(user, name: "Test #{template.name}")
      
      assert journey.persisted?, "Journey should be created from template #{template.name}"
      assert journey.journey_steps.count > 0, "Journey should have steps from template"
      assert_equal template.template_data['stages'], journey.stages
      assert_equal template.campaign_type, journey.campaign_type
      
      # Verify step creation matches template
      template_steps_count = template.template_data['steps'].length
      assert_equal template_steps_count, journey.journey_steps.count
    end
  end

  test "seeded templates have unique names within campaign types" do
    JourneyTemplate.for_campaign_type('awareness').default_templates.each do |template|
      duplicate_count = JourneyTemplate.where(
        campaign_type: template.campaign_type,
        name: template.name
      ).count
      
      assert_equal 1, duplicate_count, "Template name should be unique within campaign type"
    end
  end
end