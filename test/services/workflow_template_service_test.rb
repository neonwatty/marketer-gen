require 'test_helper'

class WorkflowTemplateServiceTest < ActiveSupport::TestCase
  def setup
    @service = WorkflowTemplateService.new
    @campaign = campaigns(:summer_launch)
  end

  test 'should initialize with loaded templates' do
    assert @service.respond_to?(:get_template)
    assert @service.respond_to?(:list_templates)
  end

  test 'should get existing template' do
    template = @service.get_template('standard_content_approval')
    
    assert template
    assert_equal 'Standard Content Approval', template[:display_name]
    assert_equal 'marketing_content', template[:category]
    assert_equal '1.0', template[:version]
    assert template[:stages].key?(:draft)
    assert template[:stages].key?(:review)
    assert template[:stages].key?(:approved)
  end

  test 'should return default template for unknown template name' do
    template = @service.get_template('nonexistent_template')
    
    assert template
    assert_equal 'Standard Content Approval', template[:display_name]
  end

  test 'should list all templates' do
    templates = @service.list_templates
    
    assert templates.any?
    
    standard_template = templates.find { |t| t[:name] == 'standard_content_approval' }
    assert standard_template
    assert_equal 'Standard Content Approval', standard_template[:display_name]
    assert_equal 'marketing_content', standard_template[:category]
    assert_equal 'medium', standard_template[:complexity]
  end

  test 'should filter templates by category' do
    social_templates = @service.list_templates(category: 'social_media')
    
    assert social_templates.any?
    social_templates.each do |template|
      assert_equal 'social_media', template[:category]
    end
    
    urgent_templates = @service.list_templates(category: 'urgent_content')
    assert urgent_templates.any?
    urgent_templates.each do |template|
      assert_equal 'urgent_content', template[:category]
    end
  end

  test 'should check if template exists' do
    assert @service.template_exists?('standard_content_approval')
    assert @service.template_exists?('urgent_content_fast_track')
    refute @service.template_exists?('nonexistent_template')
  end

  test 'should create workflow from standard template' do
    workflow = @service.create_workflow_from_template('standard_content_approval', @campaign)
    
    assert workflow.persisted?
    assert_equal @campaign, workflow.content_item
    assert_equal 'draft', workflow.current_stage
    assert_equal 'Standard Content Approval', workflow.template_name
    assert_equal '1.0', workflow.template_version
    assert_equal 'normal', workflow.priority
    
    # Check metadata
    assert_equal 'marketing_content', workflow.metadata['template_category']
    assert_equal 'medium', workflow.metadata['complexity']
    assert workflow.metadata['created_from_template']
  end

  test 'should create workflow from urgent template with high priority' do
    workflow = @service.create_workflow_from_template('urgent_content_fast_track', @campaign)
    
    assert workflow.persisted?
    assert_equal 'urgent', workflow.priority
    assert_equal 'urgent_content', workflow.metadata['template_category']
    assert_equal 'low', workflow.metadata['complexity']
  end

  test 'should create workflow with custom options' do
    options = {
      priority: :high,
      notification_recipients: ['admin@example.com'],
      custom_setting: 'value'
    }
    
    workflow = @service.create_workflow_from_template('standard_content_approval', @campaign, options)
    
    assert_equal 'high', workflow.priority
    assert_equal options, workflow.metadata['template_options']
    assert_equal options, workflow.settings['user_options']
  end

  test 'should validate template structure for standard template' do
    template = @service.get_template('standard_content_approval')
    
    # Check required template fields
    assert template[:display_name]
    assert template[:description]
    assert template[:category]
    assert template[:version]
    assert template[:stages]
    
    # Check stage structure
    assert template[:stages][:draft]
    assert template[:stages][:review]
    assert template[:stages][:approved]
    assert template[:stages][:published]
    
    # Check draft stage configuration
    draft_stage = template[:stages][:draft]
    assert_equal 'Draft', draft_stage[:name]
    assert_equal 1, draft_stage[:order]
    assert_includes draft_stage[:required_roles], 'creator'
    assert_includes draft_stage[:allowed_actions], 'edit'
    assert_includes draft_stage[:allowed_actions], 'submit_for_review'
  end

  test 'should validate social media template specifics' do
    template = @service.get_template('social_media_approval')
    
    assert_equal 'Social Media Approval', template[:display_name]
    assert_equal 'social_media', template[:category]
    
    # Should have platform-specific review stage
    assert template[:stages][:platform_review]
    platform_stage = template[:stages][:platform_review]
    assert_equal 'Platform Review', platform_stage[:name]
    assert_includes platform_stage[:required_roles], 'reviewer'
    
    # Should have brand approval stage
    assert template[:stages][:brand_approval]
    brand_stage = template[:stages][:brand_approval]
    assert_equal 'Brand Approval', brand_stage[:name]
    
    # Check business rules
    rules = template[:business_rules]
    assert rules[:require_platform_review]
    assert rules[:auto_schedule_optimal_time]
  end

  test 'should validate email campaign template complexity' do
    template = @service.get_template('email_campaign_approval')
    
    assert_equal 'Email Campaign Approval', template[:display_name]
    assert_equal 'email_campaigns', template[:category]
    assert_equal 'high', template[:complexity]
    
    # Should have multiple review stages
    assert template[:stages][:content_review]
    assert template[:stages][:deliverability_check]
    assert template[:stages][:final_approval]
    
    # Check deliverability stage
    deliverability_stage = template[:stages][:deliverability_check]
    assert_equal 'Deliverability Check', deliverability_stage[:name]
    assert_equal 8, deliverability_stage[:sla_hours]
    
    # Check business rules
    rules = template[:business_rules]
    assert rules[:require_deliverability_check]
    assert rules[:require_compliance_approval]
    assert rules[:monitor_delivery_metrics]
  end

  test 'should validate advertising template legal requirements' do
    template = @service.get_template('advertising_approval')
    
    assert_equal 'Advertising Content Approval', template[:display_name]
    assert_equal 'advertising', template[:category]
    assert_equal 'high', template[:complexity]
    
    # Should have legal compliance stage
    assert template[:stages][:legal_compliance]
    legal_stage = template[:stages][:legal_compliance]
    assert_equal 'Legal Compliance', legal_stage[:name]
    assert_equal 48, legal_stage[:sla_hours] # Longer SLA for legal review
    
    # Should have platform compliance stage
    assert template[:stages][:platform_compliance]
    platform_stage = template[:stages][:platform_compliance]
    assert_equal 'Platform Compliance', platform_stage[:name]
    
    # Check business rules
    rules = template[:business_rules]
    assert rules[:require_legal_approval]
    assert rules[:require_platform_compliance]
    assert rules[:compliance_archival]
  end

  test 'should validate blog content template with SEO focus' do
    template = @service.get_template('blog_content_approval')
    
    assert_equal 'Blog Content Approval', template[:display_name]
    assert_equal 'blog_content', template[:category]
    
    # Should have SEO optimization stage
    assert template[:stages][:seo_optimization]
    seo_stage = template[:stages][:seo_optimization]
    assert_equal 'SEO Optimization', seo_stage[:name]
    assert_equal 12, seo_stage[:sla_hours]
    
    # Should have editorial review
    assert template[:stages][:editorial_review]
    editorial_stage = template[:stages][:editorial_review]
    assert_equal 'Editorial Review', editorial_stage[:name]
    
    # Check business rules
    rules = template[:business_rules]
    assert rules[:require_seo_optimization]
    assert rules[:auto_social_promotion]
    assert rules[:performance_tracking]
  end

  test 'should validate urgent template fast track' do
    template = @service.get_template('urgent_content_fast_track')
    
    assert_equal 'Urgent Content Fast Track', template[:display_name]
    assert_equal 'urgent_content', template[:category]
    assert_equal 'low', template[:complexity]
    assert_equal '4-8 hours', template[:estimated_duration]
    
    # Should have expedited review
    assert template[:stages][:expedited_review]
    expedited_stage = template[:stages][:expedited_review]
    assert_equal 'Expedited Review', expedited_stage[:name]
    assert_equal 2, expedited_stage[:sla_hours] # Very short SLA
    assert_includes expedited_stage[:allowed_actions], 'publish' # Can publish directly
    
    # Check business rules
    rules = template[:business_rules]
    assert rules[:allow_direct_publish]
    assert rules[:bypass_standard_review]
    assert_equal 1, rules[:escalate_overdue_hours]
    assert_equal 'urgent', rules[:priority]
  end

  test 'should setup initial assignments when creating workflow' do
    # Mock the assignment finding to return users
    @restore_find_users = stub_method(WorkflowTemplateService, :find_users_for_assignment, [123])
    
    workflow = @service.create_workflow_from_template('standard_content_approval', @campaign)
    
    # Should have initial assignment for draft stage
    assert workflow.assignments.any?
    assignment = workflow.assignments.first
    assert_equal 'creator', assignment.role
    assert_equal 'draft', assignment.stage
    assert assignment.assignment_type_automatic?
    
    @restore_find_users.call if @restore_find_users
  end

  test 'should configure notifications based on template' do
    workflow = @service.create_workflow_from_template('urgent_content_fast_track', @campaign)
    
    notification_config = workflow.settings['notifications']
    assert notification_config
    assert notification_config['enabled_types'].include?('urgent_content_created')
    assert notification_config['escalation_rules'].any?
  end

  test 'should apply business rules during workflow creation' do
    workflow = @service.create_workflow_from_template('urgent_content_fast_track', @campaign)
    
    # Should set urgent priority from business rules
    assert_equal 'urgent', workflow.priority
    
    # Should have escalation monitoring setup
    monitoring_config = workflow.settings['monitoring']
    assert monitoring_config
    assert monitoring_config['track_stage_durations']
  end

  test 'should handle template with auto-assignments' do
    template = @service.get_template('social_media_approval')
    
    # Check that auto-assignments are configured
    draft_stage = template[:stages][:draft]
    assert draft_stage[:auto_assignments]
    
    platform_review_stage = template[:stages][:platform_review]
    assert platform_review_stage[:auto_assignments]
    assert platform_review_stage[:auto_assignments][:reviewer]
  end

  test 'should calculate appropriate settings for different complexities' do
    # Test low complexity template
    low_complexity_workflow = @service.create_workflow_from_template('urgent_content_fast_track', @campaign)
    monitoring = low_complexity_workflow.settings['monitoring']
    refute monitoring['alert_on_bottlenecks'] # Low complexity shouldn't alert
    
    # Test high complexity template
    high_complexity_workflow = @service.create_workflow_from_template('email_campaign_approval', @campaign)
    monitoring = high_complexity_workflow.settings['monitoring']
    assert monitoring['alert_on_bottlenecks'] # High complexity should alert
  end

  test 'should provide comprehensive template information' do
    templates = @service.list_templates
    
    # Verify all expected templates are present
    template_names = templates.map { |t| t[:name] }
    
    assert_includes template_names, 'standard_content_approval'
    assert_includes template_names, 'urgent_content_fast_track'
    assert_includes template_names, 'social_media_approval'
    assert_includes template_names, 'email_campaign_approval'
    assert_includes template_names, 'advertising_approval'
    assert_includes template_names, 'blog_content_approval'
    
    # Check that each template has required information
    templates.each do |template|
      assert template[:name]
      assert template[:display_name]
      assert template[:description]
      assert template[:category]
      assert template[:version]
      assert template[:estimated_duration]
      assert template[:complexity]
    end
  end

  test 'should handle edge cases gracefully' do
    # Test with nil content item
    assert_raises(ActiveRecord::RecordInvalid) do
      @service.create_workflow_from_template('standard_content_approval', nil)
    end
    
    # Test with empty options
    workflow = @service.create_workflow_from_template('standard_content_approval', @campaign, {})
    assert workflow.persisted?
    assert_equal({}, workflow.metadata['template_options'])
  end
end