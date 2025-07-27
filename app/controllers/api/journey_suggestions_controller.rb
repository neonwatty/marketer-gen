class Api::JourneySuggestionsController < ApplicationController
  before_action :require_authentication
  
  def index
    suggestions = generate_suggestions_for_journey
    render json: { suggestions: suggestions }
  end
  
  def for_stage
    stage = params[:stage]
    suggestions = generate_suggestions_for_stage(stage)
    render json: { suggestions: suggestions }
  end
  
  def for_step
    step_data = params.permit(:type, :stage, :previous_steps => [], :journey_context => {})
    suggestions = generate_suggestions_for_step(step_data)
    render json: { suggestions: suggestions }
  end
  
  def create_feedback
    feedback_params = params.permit(:suggestion_id, :feedback_type, :rating, :comment)
    
    # TODO: Store feedback for improving AI suggestions
    # For now, just return success
    render json: { status: 'success', message: 'Feedback recorded' }
  end
  
  private
  
  def generate_suggestions_for_journey
    # Generate general journey suggestions based on user context
    [
      {
        id: 'welcome-email-001',
        type: 'step',
        title: 'Welcome Email Sequence',
        description: 'Start with a personalized welcome email to introduce your brand',
        confidence: 0.95,
        data: {
          step_type: 'email_sequence',
          stage: 'awareness',
          timing: 'immediate',
          subject: 'Welcome to [Brand Name]!',
          template: 'welcome'
        }
      },
      {
        id: 'social-proof-002',
        type: 'step',
        title: 'Social Media Engagement',
        description: 'Share customer testimonials on social media',
        confidence: 0.88,
        data: {
          step_type: 'social_media',
          stage: 'consideration',
          timing: '3_days',
          channel: 'facebook'
        }
      },
      {
        id: 'nurture-sequence-003',
        type: 'step',
        title: 'Educational Content Series',
        description: 'Provide valuable content to nurture leads',
        confidence: 0.92,
        data: {
          step_type: 'blog_post',
          stage: 'consideration',
          timing: '1_week'
        }
      }
    ]
  end
  
  def generate_suggestions_for_stage(stage)
    stage_suggestions = {
      'awareness' => [
        {
          id: "#{stage}-blog-001",
          type: 'step',
          title: 'Educational Blog Post',
          description: 'Create content that addresses common pain points',
          confidence: 0.90,
          data: {
            step_type: 'blog_post',
            stage: stage,
            timing: 'immediate'
          }
        },
        {
          id: "#{stage}-social-001",
          type: 'step',
          title: 'Social Media Campaign',
          description: 'Reach new audiences through targeted social content',
          confidence: 0.85,
          data: {
            step_type: 'social_media',
            stage: stage,
            timing: 'immediate'
          }
        },
        {
          id: "#{stage}-lead-magnet-001",
          type: 'step',
          title: 'Lead Magnet',
          description: 'Offer valuable resource to capture leads',
          confidence: 0.93,
          data: {
            step_type: 'lead_magnet',
            stage: stage,
            timing: 'immediate'
          }
        }
      ],
      'consideration' => [
        {
          id: "#{stage}-email-sequence-001",
          type: 'step',
          title: 'Nurture Email Sequence',
          description: 'Build relationships with educational content',
          confidence: 0.95,
          data: {
            step_type: 'email_sequence',
            stage: stage,
            timing: '1_day'
          }
        },
        {
          id: "#{stage}-webinar-001",
          type: 'step',
          title: 'Educational Webinar',
          description: 'Demonstrate expertise and build trust',
          confidence: 0.88,
          data: {
            step_type: 'webinar',
            stage: stage,
            timing: '1_week'
          }
        },
        {
          id: "#{stage}-case-study-001",
          type: 'step',
          title: 'Customer Case Study',
          description: 'Show real results and social proof',
          confidence: 0.91,
          data: {
            step_type: 'case_study',
            stage: stage,
            timing: '3_days'
          }
        }
      ],
      'conversion' => [
        {
          id: "#{stage}-sales-call-001",
          type: 'step',
          title: 'Consultation Call',
          description: 'Personal conversation to address specific needs',
          confidence: 0.97,
          data: {
            step_type: 'sales_call',
            stage: stage,
            timing: '1_day'
          }
        },
        {
          id: "#{stage}-demo-001",
          type: 'step',
          title: 'Product Demonstration',
          description: 'Show how your solution solves their problems',
          confidence: 0.92,
          data: {
            step_type: 'demo',
            stage: stage,
            timing: 'immediate'
          }
        },
        {
          id: "#{stage}-trial-001",
          type: 'step',
          title: 'Free Trial Offer',
          description: 'Let prospects experience your product risk-free',
          confidence: 0.89,
          data: {
            step_type: 'trial_offer',
            stage: stage,
            timing: 'immediate'
          }
        }
      ],
      'retention' => [
        {
          id: "#{stage}-onboarding-001",
          type: 'step',
          title: 'Customer Onboarding',
          description: 'Ensure new customers get maximum value',
          confidence: 0.98,
          data: {
            step_type: 'onboarding',
            stage: stage,
            timing: 'immediate'
          }
        },
        {
          id: "#{stage}-newsletter-001",
          type: 'step',
          title: 'Regular Newsletter',
          description: 'Keep customers engaged with updates and tips',
          confidence: 0.86,
          data: {
            step_type: 'newsletter',
            stage: stage,
            timing: '1_week'
          }
        },
        {
          id: "#{stage}-feedback-001",
          type: 'step',
          title: 'Feedback Survey',
          description: 'Gather insights to improve customer experience',
          confidence: 0.82,
          data: {
            step_type: 'feedback_survey',
            stage: stage,
            timing: '2_weeks'
          }
        }
      ]
    }
    
    stage_suggestions[stage] || []
  end
  
  def generate_suggestions_for_step(step_data)
    suggestions = []
    
    # Analyze previous steps to suggest next logical steps
    previous_steps = step_data[:previous_steps] || []
    current_stage = step_data[:stage]
    
    # Logic to suggest next steps based on current step type and stage
    case step_data[:type]
    when 'lead_magnet'
      suggestions << {
        id: 'follow-up-email-001',
        type: 'connection',
        title: 'Follow-up Email',
        description: 'Send a thank you email with additional resources',
        confidence: 0.95,
        data: {
          step_type: 'email_sequence',
          stage: 'consideration',
          timing: '1_day',
          subject: 'Thank you for downloading [Resource Name]'
        }
      }
    when 'email_sequence'
      suggestions << {
        id: 'social-engagement-001',
        type: 'connection',
        title: 'Social Media Follow-up',
        description: 'Engage prospects on social media',
        confidence: 0.85,
        data: {
          step_type: 'social_media',
          stage: current_stage,
          timing: '2_days'
        }
      }
    when 'webinar'
      suggestions << {
        id: 'sales-call-follow-001',
        type: 'connection',
        title: 'Sales Call',
        description: 'Schedule a call with interested attendees',
        confidence: 0.92,
        data: {
          step_type: 'sales_call',
          stage: 'conversion',
          timing: '1_day'
        }
      }
    end
    
    suggestions
  end
end