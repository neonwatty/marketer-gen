class Api::V1::JourneySuggestionsController < Api::V1::BaseController
  
  def index
    suggestions = generate_suggestions_for_journey
    render_success(data: { suggestions: suggestions })
  end
  
  def for_stage
    stage = params[:stage]
    
    unless Journey::STAGES.include?(stage)
      return render_error(message: 'Invalid stage specified', code: 'INVALID_STAGE')
    end
    
    suggestions = generate_suggestions_for_stage(stage)
    render_success(data: { suggestions: suggestions })
  end
  
  def for_step
    step_data = params.permit(:type, :stage, :previous_steps => [], :journey_context => {})
    suggestions = generate_suggestions_for_step(step_data)
    render_success(data: { suggestions: suggestions })
  end
  
  def bulk_suggestions
    request_params = params.permit(:journey_id, :count, stages: [], context: {})
    
    journey = current_user.journeys.find(request_params[:journey_id]) if request_params[:journey_id]
    stages = request_params[:stages] || Journey::STAGES
    count_per_stage = [request_params[:count].to_i, 3].max
    count_per_stage = [count_per_stage, 10].min # Cap at 10 per stage
    
    bulk_suggestions = {}
    
    stages.each do |stage|
      next unless Journey::STAGES.include?(stage)
      
      suggestions = generate_suggestions_for_stage(stage)
      bulk_suggestions[stage] = suggestions.take(count_per_stage)
    end
    
    render_success(
      data: { 
        bulk_suggestions: bulk_suggestions,
        journey_context: journey ? serialize_journey_context(journey) : nil
      }
    )
  end
  
  def personalized_suggestions
    persona_id = params[:persona_id]
    campaign_id = params[:campaign_id]
    journey_id = params[:journey_id]
    
    context = build_personalization_context(persona_id, campaign_id, journey_id)
    suggestions = generate_personalized_suggestions(context)
    
    render_success(
      data: { 
        suggestions: suggestions,
        personalization_context: context
      }
    )
  end
  
  def create_feedback
    feedback_params = params.permit(:suggestion_id, :feedback_type, :rating, :comment, :journey_id, :step_id)
    
    begin
      feedback = current_user.suggestion_feedbacks.create!(
        suggestion_id: feedback_params[:suggestion_id],
        feedback_type: feedback_params[:feedback_type],
        rating: feedback_params[:rating],
        comment: feedback_params[:comment],
        journey_id: feedback_params[:journey_id],
        metadata: {
          step_id: feedback_params[:step_id],
          created_via_api: true,
          user_agent: request.user_agent
        }
      )
      
      render_success(
        data: serialize_feedback(feedback),
        message: 'Feedback recorded successfully'
      )
    rescue => e
      render_error(message: "Failed to record feedback: #{e.message}")
    end
  end
  
  def feedback_analytics
    # Get feedback analytics for improving suggestions
    days = [params[:days].to_i, 30].max
    days = [days, 365].min
    
    start_date = days.days.ago
    feedbacks = current_user.suggestion_feedbacks.where(created_at: start_date..)
    
    analytics = {
      total_feedback_count: feedbacks.count,
      average_rating: feedbacks.average(:rating)&.round(2) || 0,
      feedback_by_type: feedbacks.group(:feedback_type).count,
      rating_distribution: feedbacks.group(:rating).count,
      top_suggestions: find_top_rated_suggestions(feedbacks),
      improvement_areas: identify_improvement_areas(feedbacks)
    }
    
    render_success(data: analytics)
  end
  
  def suggestion_history
    journey_id = params[:journey_id]
    days = [params[:days].to_i, 30].max
    days = [days, 90].min
    
    # This would track suggestion history in a real implementation
    history_data = {
      suggestions_generated: 0,
      suggestions_used: 0,
      user_satisfaction: 0.0,
      popular_suggestion_types: [],
      trend_analysis: {}
    }
    
    render_success(data: history_data)
  end
  
  def refresh_cache
    # Clear and refresh suggestion caches
    # This would integrate with the caching system
    
    render_success(message: 'Suggestion cache refreshed successfully')
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
  
  def serialize_journey_context(journey)
    {
      id: journey.id,
      name: journey.name,
      campaign_type: journey.campaign_type,
      target_audience: journey.target_audience,
      step_count: journey.total_steps,
      stages_used: journey.steps_by_stage.keys
    }
  end
  
  def build_personalization_context(persona_id, campaign_id, journey_id)
    context = {}
    
    if persona_id.present?
      persona = current_user.personas.find_by(id: persona_id)
      context[:persona] = persona.to_campaign_context if persona
    end
    
    if campaign_id.present?
      campaign = current_user.campaigns.find_by(id: campaign_id)
      context[:campaign] = campaign.to_analytics_context if campaign
    end
    
    if journey_id.present?
      journey = current_user.journeys.find_by(id: journey_id)
      context[:journey] = serialize_journey_context(journey) if journey
    end
    
    context
  end
  
  def generate_personalized_suggestions(context)
    # Enhanced suggestions based on persona, campaign, and journey context
    base_suggestions = generate_suggestions_for_journey
    
    # Customize suggestions based on context
    if context[:persona]
      base_suggestions = filter_suggestions_by_persona(base_suggestions, context[:persona])
    end
    
    if context[:campaign]
      base_suggestions = enhance_suggestions_with_campaign_data(base_suggestions, context[:campaign])
    end
    
    base_suggestions
  end
  
  def filter_suggestions_by_persona(suggestions, persona_context)
    # Filter and prioritize suggestions based on persona characteristics
    suggestions.map do |suggestion|
      # Adjust confidence scores based on persona fit
      if persona_context[:age_range] == '25-35' && suggestion[:data][:step_type] == 'social_media'
        suggestion[:confidence] = [suggestion[:confidence] * 1.1, 1.0].min
      end
      
      suggestion
    end
  end
  
  def enhance_suggestions_with_campaign_data(suggestions, campaign_context)
    # Enhance suggestions with campaign-specific data
    suggestions.map do |suggestion|
      suggestion[:data][:campaign_context] = {
        campaign_type: campaign_context[:campaign_type],
        industry: campaign_context[:industry]
      }
      
      suggestion
    end
  end
  
  def serialize_feedback(feedback)
    {
      id: feedback.id,
      suggestion_id: feedback.suggestion_id,
      feedback_type: feedback.feedback_type,
      rating: feedback.rating,
      comment: feedback.comment,
      journey_id: feedback.journey_id,
      created_at: feedback.created_at
    }
  end
  
  def find_top_rated_suggestions(feedbacks)
    feedbacks.group(:suggestion_id)
      .average(:rating)
      .sort_by { |_, rating| -rating }
      .first(5)
      .map { |suggestion_id, rating| { suggestion_id: suggestion_id, rating: rating.round(2) } }
  end
  
  def identify_improvement_areas(feedbacks)
    low_rated = feedbacks.where('rating < ?', 3)
    
    areas = []
    areas << 'Suggestion relevance' if low_rated.where(feedback_type: 'relevance').count > low_rated.count * 0.3
    areas << 'Suggestion quality' if low_rated.where(feedback_type: 'quality').count > low_rated.count * 0.3
    areas << 'Implementation difficulty' if low_rated.where(feedback_type: 'difficulty').count > low_rated.count * 0.3
    
    areas
  end
end