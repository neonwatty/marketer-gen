# Service for AI-powered journey step suggestions based on campaign objectives
class JourneySuggestionService
  attr_reader :campaign_type, :template_type, :current_stage, :existing_steps

  def initialize(campaign_type:, template_type: nil, current_stage: nil, existing_steps: [])
    @campaign_type = campaign_type
    @template_type = template_type
    @current_stage = current_stage
    @existing_steps = existing_steps
  end

  def suggest_steps(limit: 5)
    base_suggestions = get_base_suggestions_for_campaign_type
    stage_specific_suggestions = get_stage_specific_suggestions
    template_suggestions = get_template_specific_suggestions

    # Combine and prioritize suggestions
    all_suggestions = (base_suggestions + stage_specific_suggestions + template_suggestions).uniq
    
    # Filter out existing step types
    existing_step_types = Array(existing_steps).compact.filter_map do |step|
      next unless step.is_a?(Hash)
      step[:step_type] || step['step_type']
    end.compact
    filtered_suggestions = all_suggestions.reject { |suggestion| existing_step_types.include?(suggestion[:step_type]) }
    
    # Return top suggestions (ensure limit is non-negative)
    safe_limit = [limit, 0].max
    filtered_suggestions.first(safe_limit)
  end

  def suggest_channels_for_step(step_type)
    channel_mapping = {
      'email' => ['email'],
      'social_post' => ['social_media'],
      'content_piece' => ['website', 'blog'],
      'webinar' => ['webinar'],
      'event' => ['event'],
      'landing_page' => ['website'],
      'automation' => ['email', 'sms'],
      'custom' => ['email', 'social_media', 'website']
    }

    suggested_channels = channel_mapping[step_type] || []
    
    # Add campaign-type specific channel recommendations
    case campaign_type
    when 'awareness'
      suggested_channels += ['social_media', 'blog', 'video']
    when 'consideration'
      suggested_channels += ['webinar', 'email', 'website']
    when 'conversion'
      suggested_channels += ['email', 'website', 'sms']
    when 'retention'
      suggested_channels += ['email', 'push_notification']
    when 'upsell_cross_sell'
      suggested_channels += ['email', 'website']
    end

    suggested_channels.uniq
  end

  def suggest_content_for_step(step_type, stage)
    content_suggestions = {
      'email' => generate_email_content_suggestions(stage),
      'social_post' => generate_social_content_suggestions(stage),
      'content_piece' => generate_content_piece_suggestions(stage),
      'webinar' => generate_webinar_suggestions(stage),
      'event' => generate_event_suggestions(stage),
      'landing_page' => generate_landing_page_suggestions(stage),
      'automation' => generate_automation_suggestions(stage)
    }

    content_suggestions[step_type] || {}
  end

  private

  def get_base_suggestions_for_campaign_type
    case campaign_type
    when 'awareness'
      [
        {
          step_type: 'social_post',
          title: 'Brand Introduction Post',
          description: 'Introduce your brand and value proposition to new audiences',
          priority: 'high',
          estimated_effort: 'low'
        },
        {
          step_type: 'content_piece',
          title: 'Educational Blog Post',
          description: 'Create educational content that addresses your audience\'s pain points',
          priority: 'high',
          estimated_effort: 'medium'
        },
        {
          step_type: 'email',
          title: 'Welcome Series Email',
          description: 'Welcome new subscribers and set expectations',
          priority: 'medium',
          estimated_effort: 'low'
        }
      ]
    when 'consideration'
      [
        {
          step_type: 'webinar',
          title: 'Educational Webinar',
          description: 'Host a webinar that demonstrates expertise and builds trust',
          priority: 'high',
          estimated_effort: 'high'
        },
        {
          step_type: 'content_piece',
          title: 'Comparison Guide',
          description: 'Create content that helps prospects evaluate their options',
          priority: 'high',
          estimated_effort: 'medium'
        },
        {
          step_type: 'email',
          title: 'Case Study Email',
          description: 'Share success stories and social proof',
          priority: 'medium',
          estimated_effort: 'medium'
        }
      ]
    when 'conversion'
      [
        {
          step_type: 'landing_page',
          title: 'Conversion Landing Page',
          description: 'Create a focused landing page with clear call-to-action',
          priority: 'high',
          estimated_effort: 'medium'
        },
        {
          step_type: 'email',
          title: 'Limited-Time Offer Email',
          description: 'Create urgency with time-sensitive offers',
          priority: 'high',
          estimated_effort: 'low'
        },
        {
          step_type: 'automation',
          title: 'Cart Abandonment Sequence',
          description: 'Automated follow-up for incomplete purchases',
          priority: 'medium',
          estimated_effort: 'medium'
        }
      ]
    when 'retention'
      [
        {
          step_type: 'email',
          title: 'Onboarding Email Series',
          description: 'Help new customers get the most value from your product',
          priority: 'high',
          estimated_effort: 'medium'
        },
        {
          step_type: 'content_piece',
          title: 'Best Practices Guide',
          description: 'Share tips and best practices to increase product usage',
          priority: 'medium',
          estimated_effort: 'medium'
        },
        {
          step_type: 'automation',
          title: 'Usage Milestone Celebration',
          description: 'Celebrate customer achievements and milestones',
          priority: 'medium',
          estimated_effort: 'low'
        }
      ]
    when 'upsell_cross_sell'
      [
        {
          step_type: 'email',
          title: 'Product Recommendation Email',
          description: 'Suggest complementary products based on purchase history',
          priority: 'high',
          estimated_effort: 'medium'
        },
        {
          step_type: 'automation',
          title: 'Upgrade Opportunity Sequence',
          description: 'Identify and act on upgrade opportunities',
          priority: 'high',
          estimated_effort: 'high'
        },
        {
          step_type: 'content_piece',
          title: 'Feature Comparison Sheet',
          description: 'Show the benefits of premium features or products',
          priority: 'medium',
          estimated_effort: 'low'
        }
      ]
    else
      []
    end
  end

  def get_stage_specific_suggestions
    return [] unless current_stage

    stage_suggestions = {
      'discovery' => [
        {
          step_type: 'social_post',
          title: 'Problem Awareness Post',
          description: 'Help prospects recognize they have a problem worth solving',
          priority: 'high',
          estimated_effort: 'low'
        }
      ],
      'education' => [
        {
          step_type: 'content_piece',
          title: 'Educational Resource',
          description: 'Provide valuable information without selling',
          priority: 'high',
          estimated_effort: 'medium'
        }
      ],
      'research' => [
        {
          step_type: 'content_piece',
          title: 'Industry Report',
          description: 'Share data and insights about the industry',
          priority: 'medium',
          estimated_effort: 'high'
        }
      ],
      'evaluation' => [
        {
          step_type: 'webinar',
          title: 'Product Demo Webinar',
          description: 'Demonstrate your solution in action',
          priority: 'high',
          estimated_effort: 'high'
        }
      ],
      'decision' => [
        {
          step_type: 'email',
          title: 'Final Decision Support Email',
          description: 'Address final concerns and provide reassurance',
          priority: 'high',
          estimated_effort: 'medium'
        }
      ]
    }

    stage_suggestions[current_stage] || []
  end

  def get_template_specific_suggestions
    return [] unless template_type

    template_suggestions = {
      'email' => [
        {
          step_type: 'automation',
          title: 'Email Sequence Setup',
          description: 'Create an automated email nurture sequence',
          priority: 'high',
          estimated_effort: 'medium'
        }
      ],
      'social_media' => [
        {
          step_type: 'social_post',
          title: 'Engagement Post Series',
          description: 'Create a series of posts to boost engagement',
          priority: 'high',
          estimated_effort: 'low'
        }
      ],
      'webinar' => [
        {
          step_type: 'landing_page',
          title: 'Webinar Registration Page',
          description: 'Create a compelling registration page for your webinar',
          priority: 'high',
          estimated_effort: 'medium'
        }
      ]
    }

    template_suggestions[template_type] || []
  end

  def generate_email_content_suggestions(stage)
    {
      subject_line_ideas: get_subject_lines_for_stage(stage),
      content_structure: get_email_structure_for_stage(stage),
      call_to_action: get_cta_for_stage(stage)
    }
  end

  def generate_social_content_suggestions(stage)
    {
      post_types: ['educational', 'behind_the_scenes', 'user_generated_content'],
      hashtag_suggestions: get_hashtags_for_campaign_type,
      content_themes: get_social_themes_for_stage(stage)
    }
  end

  def generate_content_piece_suggestions(stage)
    {
      content_formats: ['blog_post', 'infographic', 'video', 'podcast', 'ebook'],
      topic_ideas: get_topics_for_stage(stage),
      target_length: get_content_length_for_stage(stage)
    }
  end

  def generate_webinar_suggestions(stage)
    {
      format: 'educational_presentation',
      duration: '45-60 minutes',
      follow_up_strategy: 'email_sequence'
    }
  end

  def generate_event_suggestions(stage)
    {
      event_types: ['workshop', 'networking', 'product_launch'],
      duration: '2-4 hours',
      follow_up_strategy: 'personal_outreach'
    }
  end

  def generate_landing_page_suggestions(stage)
    {
      page_focus: get_landing_page_focus_for_stage(stage),
      key_elements: ['headline', 'value_proposition', 'social_proof', 'cta'],
      conversion_optimization: ['a_b_testing', 'mobile_optimization']
    }
  end

  def generate_automation_suggestions(stage)
    {
      trigger_events: get_automation_triggers_for_stage(stage),
      sequence_length: '3-5 messages',
      timing: 'immediate_then_spaced'
    }
  end

  # Helper methods for content generation
  def get_subject_lines_for_stage(stage)
    case stage
    when 'discovery'
      ['Are you struggling with...?', 'The hidden problem with...']
    when 'education'
      ['How to improve...', 'The complete guide to...']
    when 'evaluation'
      ['See how [Company] achieved...', 'Compare your options...']
    when 'decision'
      ['Ready to move forward?', 'Your next steps...']
    else
      ['Important update', 'Quick question for you']
    end
  end

  def get_email_structure_for_stage(stage)
    case stage
    when 'discovery'
      'Problem identification → Solution preview → Soft CTA'
    when 'education'
      'Value delivery → Educational content → Resource offer'
    when 'evaluation'
      'Social proof → Feature benefits → Demo invitation'
    when 'decision'
      'Address objections → Provide assurance → Clear next steps'
    else
      'Hook → Value → Call to action'
    end
  end

  def get_cta_for_stage(stage)
    case stage
    when 'discovery'
      'Learn more'
    when 'education'
      'Download guide'
    when 'evaluation'
      'Schedule demo'
    when 'decision'
      'Get started today'
    else
      'Take action'
    end
  end

  def get_hashtags_for_campaign_type
    case campaign_type
    when 'awareness'
      ['#brandawareness', '#newbrand', '#innovation']
    when 'consideration'
      ['#solutions', '#comparison', '#evaluation']
    when 'conversion'
      ['#offer', '#limitedtime', '#getstarted']
    when 'retention'
      ['#customersuccess', '#tips', '#bestpractices']
    when 'upsell_cross_sell'
      ['#upgrade', '#newfeatures', '#expansion']
    else
      ['#marketing', '#business', '#growth']
    end
  end

  def get_social_themes_for_stage(stage)
    case stage
    when 'discovery'
      ['problem_identification', 'industry_insights']
    when 'education'
      ['how_to_guides', 'tips_and_tricks']
    when 'evaluation'
      ['case_studies', 'testimonials']
    when 'decision'
      ['urgency', 'social_proof']
    else
      ['general_value', 'engagement']
    end
  end

  def get_topics_for_stage(stage)
    case stage
    when 'discovery'
      ['industry_challenges', 'emerging_trends']
    when 'education'
      ['best_practices', 'step_by_step_guides']
    when 'evaluation'
      ['feature_comparisons', 'roi_calculations']
    when 'decision'
      ['implementation_guides', 'success_stories']
    else
      ['general_insights', 'thought_leadership']
    end
  end

  def get_content_length_for_stage(stage)
    case stage
    when 'discovery'
      'short (300-500 words)'
    when 'education'
      'medium (800-1200 words)'
    when 'evaluation'
      'long (1500+ words)'
    when 'decision'
      'medium (600-800 words)'
    else
      'medium (500-800 words)'
    end
  end

  def get_landing_page_focus_for_stage(stage)
    case stage
    when 'discovery'
      'problem_awareness'
    when 'education'
      'value_education'
    when 'evaluation'
      'feature_demonstration'
    when 'decision'
      'conversion_optimization'
    else
      'general_value_proposition'
    end
  end

  def get_automation_triggers_for_stage(stage)
    case stage
    when 'discovery'
      ['content_download', 'website_visit']
    when 'education'
      ['email_engagement', 'resource_access']
    when 'evaluation'
      ['demo_request', 'pricing_page_visit']
    when 'decision'
      ['cart_abandonment', 'proposal_view']
    else
      ['form_submission', 'email_click']
    end
  end
end