# WorkflowTemplateService - Manages workflow templates for different content types
# Provides configurable templates with custom stages, roles, and business rules
class WorkflowTemplateService
  include ActiveModel::Model
  
  # Template categories
  TEMPLATE_CATEGORIES = %w[
    marketing_content
    social_media
    email_campaigns
    advertising
    blog_content
    video_content
    compliance_content
    urgent_content
  ].freeze
  
  def initialize
    @templates = load_workflow_templates
  end
  
  # Template management
  def get_template(template_name)
    @templates[template_name.to_s] || default_template
  end
  
  def list_templates(category: nil)
    templates = @templates
    
    if category
      templates = templates.select { |_name, template| template[:category] == category.to_s }
    end
    
    templates.map do |name, template|
      {
        name: name,
        display_name: template[:display_name],
        description: template[:description],
        category: template[:category],
        version: template[:version],
        estimated_duration: template[:estimated_duration],
        complexity: template[:complexity]
      }
    end
  end
  
  def template_exists?(template_name)
    @templates.key?(template_name.to_s)
  end
  
  def create_workflow_from_template(template_name, content_item, options = {})
    template = get_template(template_name)
    
    # Apply template-specific configurations
    workflow_config = build_workflow_config(template, content_item, options)
    
    # Create workflow with template settings
    workflow = ContentWorkflow.create!(workflow_config)
    
    # Apply template-specific setup
    setup_template_workflow(workflow, template, options)
    
    workflow
  end
  
  # Template definitions
  private
  
  def load_workflow_templates
    {
      # Standard marketing content approval
      'standard_content_approval' => {
        display_name: 'Standard Content Approval',
        description: 'Standard workflow for general marketing content with review and approval stages',
        category: 'marketing_content',
        version: '1.0',
        estimated_duration: '3-5 days',
        complexity: 'medium',
        stages: {
          draft: {
            name: 'Draft',
            description: 'Content creation and initial editing',
            order: 1,
            required_roles: %w[creator],
            allowed_actions: %w[edit submit_for_review delete],
            auto_assignments: {
              creator: { source: 'content_owner' }
            },
            sla_hours: 48,
            notifications: ['assignment_created']
          },
          review: {
            name: 'Review',
            description: 'Content review for quality and brand compliance',
            order: 2,
            required_roles: %w[reviewer],
            allowed_actions: %w[approve reject request_changes return_to_draft],
            auto_assignments: {
              reviewer: { source: 'department_reviewers', department: 'content' }
            },
            sla_hours: 24,
            notifications: ['stage_transitioned', 'approval_requested']
          },
          approved: {
            name: 'Approved',
            description: 'Content approved and ready for publication',
            order: 3,
            required_roles: %w[approver publisher],
            allowed_actions: %w[publish schedule reject return_to_review],
            auto_assignments: {
              publisher: { source: 'department_publishers', department: 'marketing' }
            },
            sla_hours: 12,
            notifications: ['content_approved']
          },
          scheduled: {
            name: 'Scheduled',
            description: 'Content scheduled for future publication',
            order: 4,
            required_roles: %w[publisher],
            allowed_actions: %w[publish cancel_schedule reschedule],
            sla_hours: nil,
            notifications: ['publication_scheduled']
          },
          published: {
            name: 'Published',
            description: 'Content published and live',
            order: 5,
            required_roles: %w[publisher],
            allowed_actions: %w[archive update_metadata],
            is_final: true,
            notifications: ['content_published', 'workflow_completed']
          }
        },
        business_rules: {
          require_approval_for_publish: true,
          allow_direct_publish: false,
          require_review_comments: true,
          auto_archive_after_days: 365
        }
      },
      
      # Fast-track for urgent content
      'urgent_content_fast_track' => {
        display_name: 'Urgent Content Fast Track',
        description: 'Expedited workflow for urgent content with shortened review cycles',
        category: 'urgent_content',
        version: '1.0',
        estimated_duration: '4-8 hours',
        complexity: 'low',
        stages: {
          draft: {
            name: 'Draft',
            description: 'Urgent content creation',
            order: 1,
            required_roles: %w[creator],
            allowed_actions: %w[edit submit_for_review],
            sla_hours: 2,
            notifications: ['assignment_created', 'urgent_content_created']
          },
          expedited_review: {
            name: 'Expedited Review',
            description: 'Fast-track review with senior reviewer',
            order: 2,
            required_roles: %w[approver],
            allowed_actions: %w[approve reject return_to_draft publish],
            auto_assignments: {
              approver: { source: 'senior_reviewers', priority: 'urgent' }
            },
            sla_hours: 2,
            notifications: ['urgent_approval_requested', 'escalation_triggered']
          },
          published: {
            name: 'Published',
            description: 'Urgent content published',
            order: 3,
            required_roles: %w[approver publisher],
            allowed_actions: %w[archive update_metadata],
            is_final: true,
            notifications: ['content_published', 'workflow_completed']
          }
        },
        business_rules: {
          require_approval_for_publish: true,
          allow_direct_publish: true,
          bypass_standard_review: true,
          escalate_overdue_hours: 1,
          priority: 'urgent'
        }
      },
      
      # Social media specific workflow
      'social_media_approval' => {
        display_name: 'Social Media Approval',
        description: 'Workflow optimized for social media content with platform-specific reviews',
        category: 'social_media',
        version: '1.0',
        estimated_duration: '1-2 days',
        complexity: 'medium',
        stages: {
          draft: {
            name: 'Draft',
            description: 'Social media content creation',
            order: 1,
            required_roles: %w[creator],
            allowed_actions: %w[edit submit_for_review delete],
            sla_hours: 12,
            notifications: ['assignment_created']
          },
          platform_review: {
            name: 'Platform Review',
            description: 'Platform-specific compliance and optimization review',
            order: 2,
            required_roles: %w[reviewer],
            allowed_actions: %w[approve reject request_changes return_to_draft],
            auto_assignments: {
              reviewer: { source: 'social_media_reviewers' }
            },
            sla_hours: 6,
            notifications: ['stage_transitioned', 'platform_review_requested']
          },
          brand_approval: {
            name: 'Brand Approval',
            description: 'Brand compliance and messaging approval',
            order: 3,
            required_roles: %w[approver],
            allowed_actions: %w[approve reject return_to_review schedule publish],
            auto_assignments: {
              approver: { source: 'brand_approvers' }
            },
            sla_hours: 4,
            notifications: ['brand_approval_requested']
          },
          scheduled: {
            name: 'Scheduled',
            description: 'Content scheduled for optimal posting time',
            order: 4,
            required_roles: %w[publisher],
            allowed_actions: %w[publish cancel_schedule reschedule],
            sla_hours: nil,
            notifications: ['social_media_scheduled']
          },
          published: {
            name: 'Published',
            description: 'Content posted to social media platforms',
            order: 5,
            required_roles: %w[publisher],
            allowed_actions: %w[archive monitor_engagement],
            is_final: true,
            notifications: ['social_media_published', 'workflow_completed']
          }
        },
        business_rules: {
          require_platform_review: true,
          auto_schedule_optimal_time: true,
          monitor_engagement: true,
          cross_platform_coordination: true
        }
      },
      
      # Email campaign workflow
      'email_campaign_approval' => {
        display_name: 'Email Campaign Approval',
        description: 'Comprehensive workflow for email campaigns with deliverability and compliance checks',
        category: 'email_campaigns',
        version: '1.0',
        estimated_duration: '2-4 days',
        complexity: 'high',
        stages: {
          draft: {
            name: 'Draft',
            description: 'Email content and design creation',
            order: 1,
            required_roles: %w[creator],
            allowed_actions: %w[edit submit_for_review delete],
            sla_hours: 24,
            notifications: ['assignment_created']
          },
          content_review: {
            name: 'Content Review',
            description: 'Content quality and messaging review',
            order: 2,
            required_roles: %w[reviewer],
            allowed_actions: %w[approve reject request_changes return_to_draft],
            auto_assignments: {
              reviewer: { source: 'email_content_reviewers' }
            },
            sla_hours: 12,
            notifications: ['email_content_review_requested']
          },
          deliverability_check: {
            name: 'Deliverability Check',
            description: 'Technical review for deliverability and compliance',
            order: 3,
            required_roles: %w[reviewer],
            allowed_actions: %w[approve reject return_to_review],
            auto_assignments: {
              reviewer: { source: 'email_technical_reviewers' }
            },
            sla_hours: 8,
            notifications: ['deliverability_check_requested']
          },
          final_approval: {
            name: 'Final Approval',
            description: 'Final campaign approval before scheduling',
            order: 4,
            required_roles: %w[approver],
            allowed_actions: %w[approve reject schedule return_to_review],
            auto_assignments: {
              approver: { source: 'campaign_approvers' }
            },
            sla_hours: 6,
            notifications: ['final_campaign_approval_requested']
          },
          scheduled: {
            name: 'Scheduled',
            description: 'Campaign scheduled for delivery',
            order: 5,
            required_roles: %w[publisher],
            allowed_actions: %w[send cancel_schedule reschedule],
            sla_hours: nil,
            notifications: ['email_campaign_scheduled']
          },
          sent: {
            name: 'Sent',
            description: 'Campaign delivered to subscribers',
            order: 6,
            required_roles: %w[publisher],
            allowed_actions: %w[archive monitor_metrics],
            is_final: true,
            notifications: ['email_campaign_sent', 'workflow_completed']
          }
        },
        business_rules: {
          require_deliverability_check: true,
          require_compliance_approval: true,
          auto_test_send: true,
          segment_approval_required: true,
          monitor_delivery_metrics: true
        }
      },
      
      # Advertising content workflow
      'advertising_approval' => {
        display_name: 'Advertising Content Approval',
        description: 'Workflow for advertising content with legal and platform compliance reviews',
        category: 'advertising',
        version: '1.0',
        estimated_duration: '3-7 days',
        complexity: 'high',
        stages: {
          draft: {
            name: 'Draft',
            description: 'Ad creative and copy development',
            order: 1,
            required_roles: %w[creator],
            allowed_actions: %w[edit submit_for_review delete],
            sla_hours: 48,
            notifications: ['assignment_created']
          },
          creative_review: {
            name: 'Creative Review',
            description: 'Creative quality and brand alignment review',
            order: 2,
            required_roles: %w[reviewer],
            allowed_actions: %w[approve reject request_changes return_to_draft],
            auto_assignments: {
              reviewer: { source: 'creative_reviewers' }
            },
            sla_hours: 24,
            notifications: ['creative_review_requested']
          },
          legal_compliance: {
            name: 'Legal Compliance',
            description: 'Legal and regulatory compliance review',
            order: 3,
            required_roles: %w[reviewer],
            allowed_actions: %w[approve reject return_to_review],
            auto_assignments: {
              reviewer: { source: 'legal_reviewers' }
            },
            sla_hours: 48,
            notifications: ['legal_review_requested']
          },
          platform_compliance: {
            name: 'Platform Compliance',
            description: 'Platform-specific policy compliance check',
            order: 4,
            required_roles: %w[reviewer],
            allowed_actions: %w[approve reject return_to_review],
            auto_assignments: {
              reviewer: { source: 'platform_specialists' }
            },
            sla_hours: 12,
            notifications: ['platform_compliance_check_requested']
          },
          final_approval: {
            name: 'Final Approval',
            description: 'Campaign manager final approval',
            order: 5,
            required_roles: %w[approver],
            allowed_actions: %w[approve reject schedule return_to_review],
            auto_assignments: {
              approver: { source: 'campaign_managers' }
            },
            sla_hours: 8,
            notifications: ['final_ad_approval_requested']
          },
          scheduled: {
            name: 'Scheduled',
            description: 'Ad campaign scheduled for launch',
            order: 6,
            required_roles: %w[publisher],
            allowed_actions: %w[launch cancel_schedule reschedule],
            sla_hours: nil,
            notifications: ['ad_campaign_scheduled']
          },
          live: {
            name: 'Live',
            description: 'Ad campaign running on platforms',
            order: 7,
            required_roles: %w[publisher],
            allowed_actions: %w[pause archive monitor_performance],
            is_final: true,
            notifications: ['ad_campaign_live', 'workflow_completed']
          }
        },
        business_rules: {
          require_legal_approval: true,
          require_platform_compliance: true,
          auto_budget_validation: true,
          performance_monitoring: true,
          compliance_archival: true
        }
      },
      
      # Blog content workflow
      'blog_content_approval' => {
        display_name: 'Blog Content Approval',
        description: 'Workflow for blog posts with SEO optimization and editorial review',
        category: 'blog_content',
        version: '1.0',
        estimated_duration: '4-6 days',
        complexity: 'medium',
        stages: {
          draft: {
            name: 'Draft',
            description: 'Blog post writing and initial editing',
            order: 1,
            required_roles: %w[creator],
            allowed_actions: %w[edit submit_for_review delete],
            sla_hours: 72,
            notifications: ['assignment_created']
          },
          editorial_review: {
            name: 'Editorial Review',
            description: 'Editorial review for quality, style, and accuracy',
            order: 2,
            required_roles: %w[reviewer],
            allowed_actions: %w[approve reject request_changes return_to_draft],
            auto_assignments: {
              reviewer: { source: 'editorial_reviewers' }
            },
            sla_hours: 24,
            notifications: ['editorial_review_requested']
          },
          seo_optimization: {
            name: 'SEO Optimization',
            description: 'SEO review and optimization',
            order: 3,
            required_roles: %w[reviewer],
            allowed_actions: %w[approve reject return_to_review],
            auto_assignments: {
              reviewer: { source: 'seo_specialists' }
            },
            sla_hours: 12,
            notifications: ['seo_review_requested']
          },
          final_review: {
            name: 'Final Review',
            description: 'Final editorial approval before publication',
            order: 4,
            required_roles: %w[approver],
            allowed_actions: %w[approve reject schedule publish return_to_review],
            auto_assignments: {
              approver: { source: 'content_managers' }
            },
            sla_hours: 8,
            notifications: ['final_blog_approval_requested']
          },
          scheduled: {
            name: 'Scheduled',
            description: 'Blog post scheduled for publication',
            order: 5,
            required_roles: %w[publisher],
            allowed_actions: %w[publish cancel_schedule reschedule],
            sla_hours: nil,
            notifications: ['blog_post_scheduled']
          },
          published: {
            name: 'Published',
            description: 'Blog post published and live',
            order: 6,
            required_roles: %w[publisher],
            allowed_actions: %w[archive update_seo monitor_performance],
            is_final: true,
            notifications: ['blog_post_published', 'workflow_completed']
          }
        },
        business_rules: {
          require_seo_optimization: true,
          auto_social_promotion: true,
          performance_tracking: true,
          content_syndication: true
        }
      }
    }
  end
  
  def default_template
    @templates['standard_content_approval']
  end
  
  def build_workflow_config(template, content_item, options)
    {
      content_item: content_item,
      current_stage: template[:stages].keys.first.to_s,
      template_name: template[:display_name],
      template_version: template[:version],
      priority: options[:priority] || determine_template_priority(template),
      metadata: {
        template_category: template[:category],
        estimated_duration: template[:estimated_duration],
        complexity: template[:complexity],
        business_rules: template[:business_rules],
        created_from_template: true,
        template_options: options
      },
      settings: build_template_settings(template, options)
    }
  end
  
  def setup_template_workflow(workflow, template, options)
    # Setup initial stage assignments
    setup_initial_assignments(workflow, template)
    
    # Configure notifications
    setup_template_notifications(workflow, template, options)
    
    # Apply business rules
    apply_business_rules(workflow, template)
    
    # Setup monitoring and alerts
    setup_template_monitoring(workflow, template)
  end
  
  def setup_initial_assignments(workflow, template)
    initial_stage = workflow.current_stage.to_sym
    stage_config = template[:stages][initial_stage]
    
    return unless stage_config && stage_config[:auto_assignments]
    
    stage_config[:auto_assignments].each do |role, assignment_config|
      users = find_users_for_assignment(assignment_config)
      
      users.each do |user_id|
        WorkflowAssignment.create!(
          content_workflow: workflow,
          user_id: user_id,
          role: role.to_s,
          stage: initial_stage.to_s,
          assignment_type: :automatic,
          assigned_at: Time.current
        )
      end
    end
  end
  
  def setup_template_notifications(workflow, template, options = {})
    # Configure notification preferences based on template
    notification_config = {
      enabled_types: extract_template_notifications(template),
      escalation_rules: build_escalation_rules(template),
      custom_recipients: options[:notification_recipients] || []
    }
    
    workflow.update!(
      settings: workflow.settings.merge(notifications: notification_config)
    )
  end
  
  def apply_business_rules(workflow, template)
    rules = template[:business_rules] || {}
    
    # Apply SLA rules
    if rules[:escalate_overdue_hours]
      setup_sla_monitoring(workflow, rules[:escalate_overdue_hours])
    end
    
    # Apply priority rules
    if rules[:priority]
      workflow.update!(priority: rules[:priority])
    end
    
    # Apply auto-archive rules
    if rules[:auto_archive_after_days]
      schedule_auto_archive(workflow, rules[:auto_archive_after_days])
    end
  end
  
  def setup_template_monitoring(workflow, template)
    # Setup performance monitoring based on template complexity
    monitoring_config = {
      track_stage_durations: true,
      alert_on_bottlenecks: template[:complexity] == 'high',
      performance_benchmarks: calculate_template_benchmarks(template),
      custom_metrics: template[:business_rules][:performance_monitoring] || false
    }
    
    workflow.update!(
      settings: workflow.settings.merge(monitoring: monitoring_config)
    )
  end
  
  # Helper methods
  
  def determine_template_priority(template)
    case template[:category]
    when 'urgent_content'
      :urgent
    when 'advertising'
      :high
    when 'email_campaigns'
      :high
    else
      :normal
    end
  end
  
  def build_template_settings(template, options)
    {
      template_name: template[:display_name],
      category: template[:category],
      complexity: template[:complexity],
      business_rules: template[:business_rules],
      stage_config: template[:stages],
      user_options: options
    }
  end
  
  def extract_template_notifications(template)
    notifications = []
    
    template[:stages].each do |_stage, config|
      notifications.concat(config[:notifications] || [])
    end
    
    notifications.uniq
  end
  
  def build_escalation_rules(template)
    escalation_rules = []
    
    template[:stages].each do |stage, config|
      if config[:sla_hours]
        escalation_rules << {
          stage: stage.to_s,
          escalate_after_hours: config[:sla_hours],
          escalation_type: template[:business_rules][:escalate_overdue_hours] ? 'urgent' : 'normal'
        }
      end
    end
    
    escalation_rules
  end
  
  def find_users_for_assignment(assignment_config)
    case assignment_config[:source]
    when 'content_owner'
      # Return content creator/owner
      [1] # Mock user ID
    when 'department_reviewers'
      # Find reviewers in specific department
      department = assignment_config[:department]
      get_department_users(department, 'reviewer')
    when 'senior_reviewers'
      # Find senior reviewers for urgent content
      get_users_by_role('senior_reviewer')
    when 'social_media_reviewers'
      get_users_by_specialty('social_media')
    when 'email_content_reviewers'
      get_users_by_specialty('email_marketing')
    when 'legal_reviewers'
      get_users_by_department('legal')
    else
      []
    end
  end
  
  def get_department_users(department, role)
    # Mock implementation - would integrate with User model
    case department
    when 'content'
      [6, 7]
    when 'marketing'
      [11, 12]
    when 'legal'
      [13, 14]
    else
      []
    end
  end
  
  def get_users_by_role(role)
    # Mock implementation
    case role
    when 'senior_reviewer'
      [15, 16]
    else
      []
    end
  end
  
  def get_users_by_specialty(specialty)
    # Mock implementation
    case specialty
    when 'social_media'
      [17, 18]
    when 'email_marketing'
      [19, 20]
    else
      []
    end
  end
  
  def get_users_by_department(department)
    # Mock implementation
    case department
    when 'legal'
      [21, 22]
    else
      []
    end
  end
  
  def setup_sla_monitoring(workflow, escalate_hours)
    # Setup background job to monitor SLA
    # SlaMonitorJob.set(wait: escalate_hours.hours).perform_later(workflow.id)
    Rails.logger.info "SLA monitoring setup for workflow #{workflow.id}: escalate after #{escalate_hours} hours"
  end
  
  def schedule_auto_archive(workflow, days)
    # Schedule auto-archive job
    # AutoArchiveJob.set(wait: days.days).perform_later(workflow.id)
    Rails.logger.info "Auto-archive scheduled for workflow #{workflow.id} after #{days} days"
  end
  
  def calculate_template_benchmarks(template)
    # Calculate performance benchmarks based on template complexity and historical data
    base_duration = case template[:complexity]
    when 'low'
      { draft: 2, review: 1, approval: 0.5 }
    when 'medium'
      { draft: 24, review: 8, approval: 4 }
    when 'high'
      { draft: 48, review: 24, approval: 12 }
    else
      { draft: 24, review: 8, approval: 4 }
    end
    
    # Convert to seconds and add stage-specific adjustments
    base_duration.transform_values { |hours| hours * 3600 }
  end
end