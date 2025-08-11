class Api::V1::GenerateController < ApplicationController
  # Skip CSRF token verification for API endpoints
  skip_before_action :verify_authenticity_token
  
  # Set JSON response format
  before_action :set_response_format
  before_action :validate_content_generation_params, except: [:campaign_plan, :brand_analysis]
  before_action :validate_campaign_plan_params, only: [:campaign_plan]
  before_action :validate_brand_analysis_params, only: [:brand_analysis]
  
  # Content generation endpoints
  
  # POST /api/v1/generate/social_media
  def social_media
    template = find_template('social_media')
    variables = extract_social_media_variables
    
    result = generate_content_with_template(template, variables)
    
    if result[:success]
      render json: {
        success: true,
        content: result[:content],
        template_used: template.name,
        generation_metadata: result[:metadata],
        variations: result[:variations]
      }, status: :ok
    else
      render_error(result[:error], result[:status] || :unprocessable_entity)
    end
  end

  # POST /api/v1/generate/ad_copy
  def ad_copy
    template = find_template('ad_copy')
    variables = extract_ad_copy_variables
    
    result = generate_content_with_template(template, variables)
    
    if result[:success]
      render json: {
        success: true,
        content: result[:content],
        template_used: template.name,
        generation_metadata: result[:metadata],
        variations: result[:variations]
      }, status: :ok
    else
      render_error(result[:error], result[:status] || :unprocessable_entity)
    end
  end

  # POST /api/v1/generate/email
  def email
    template = find_template('email_marketing')
    variables = extract_email_variables
    
    result = generate_content_with_template(template, variables)
    
    if result[:success]
      render json: {
        success: true,
        content: result[:content],
        template_used: template.name,
        generation_metadata: result[:metadata],
        variations: result[:variations]
      }, status: :ok
    else
      render_error(result[:error], result[:status] || :unprocessable_entity)
    end
  end

  # POST /api/v1/generate/landing_page
  def landing_page
    template = find_template('landing_page')
    variables = extract_landing_page_variables
    
    result = generate_content_with_template(template, variables)
    
    if result[:success]
      render json: {
        success: true,
        content: result[:content],
        template_used: template.name,
        generation_metadata: result[:metadata],
        variations: result[:variations]
      }, status: :ok
    else
      render_error(result[:error], result[:status] || :unprocessable_entity)
    end
  end

  # POST /api/v1/generate/campaign_plan
  def campaign_plan
    template = find_template('campaign_planning')
    variables = extract_campaign_plan_variables
    
    result = generate_content_with_template(template, variables)
    
    if result[:success]
      render json: {
        success: true,
        campaign_plan: result[:content],
        template_used: template.name,
        generation_metadata: result[:metadata]
      }, status: :ok
    else
      render_error(result[:error], result[:status] || :unprocessable_entity)
    end
  end

  # POST /api/v1/generate/brand_analysis
  def brand_analysis
    template = find_template('brand_analysis')
    variables = extract_brand_analysis_variables
    
    result = generate_content_with_template(template, variables)
    
    if result[:success]
      render json: {
        success: true,
        analysis: result[:content],
        template_used: template.name,
        generation_metadata: result[:metadata]
      }, status: :ok
    else
      render_error(result[:error], result[:status] || :unprocessable_entity)
    end
  end

  private

  def set_response_format
    request.format = :json
  end

  # Template finding and validation
  def find_template(prompt_type)
    template = PromptTemplate.active.where(prompt_type: prompt_type).order(:id).first
    
    unless template
      raise StandardError.new("No active template found for #{prompt_type}")
    end
    
    template
  end

  # Core content generation logic
  def generate_content_with_template(template, variables)
    begin
      # Validate variables
      validation_errors = template.validate_variable_values(variables)
      if validation_errors.any?
        return {
          success: false,
          error: "Variable validation failed: #{validation_errors.join(', ')}",
          status: :bad_request
        }
      end

      # Get AI service
      ai_service = get_ai_service
      
      # Render the prompt with variables
      rendered_prompt = template.render_prompt(variables)
      
      # Generate content using AI service
      response = ai_service.generate_content(
        rendered_prompt[:user_prompt],
        system_message: rendered_prompt[:system_prompt],
        temperature: rendered_prompt[:temperature],
        max_tokens: rendered_prompt[:max_tokens]
      )
      
      # Track template usage
      template.increment_usage!
      
      # Format response
      content = parse_ai_response(response)
      
      # Generate variations if requested
      variations = []
      if params[:generate_variations].present? && params[:variation_count].to_i > 0
        variations = generate_content_variations(template, variables, params[:variation_count].to_i)
      end

      {
        success: true,
        content: content,
        variations: variations,
        metadata: {
          template_id: template.id,
          template_version: template.version,
          model_used: ai_service.ai_provider&.model_name,
          generated_at: Time.current.iso8601,
          variable_count: variables.keys.count,
          content_length: content.to_s.length
        }
      }
    rescue AiServiceBase::CircuitBreakerOpenError, AiServiceBase::RateLimitError => e
      # Re-raise specific AI service errors so they can be handled by rescue_from
      raise e
    rescue => e
      Rails.logger.error "Content generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.respond_to?(:backtrace)
      
      {
        success: false,
        error: "Content generation failed: #{e.message}",
        status: :internal_server_error
      }
    end
  end

  def get_ai_service
    @ai_service ||= AiService.new(
      provider: params[:ai_provider] || 'anthropic',
      model: params[:ai_model] || 'claude-3-5-sonnet-20241022',
      enable_context7: true,
      enable_caching: true
    )
  end

  def parse_ai_response(response)
    if response.is_a?(Hash) && response["content"]
      # Handle Anthropic response format
      content_blocks = response["content"] || []
      content_blocks.map { |block| block["text"] }.compact.join("\n")
    else
      response.to_s
    end
  end

  def generate_content_variations(template, base_variables, count)
    variations = []
    
    count.times do |i|
      begin
        # Create slight variations in temperature or other params
        variation_template_params = {
          temperature: template.temperature + (rand(-0.2..0.2)),
          max_tokens: template.max_tokens
        }
        
        ai_service = get_ai_service
        rendered_prompt = template.render_prompt(base_variables)
        
        response = ai_service.generate_content(
          rendered_prompt[:user_prompt],
          system_message: rendered_prompt[:system_prompt],
          temperature: variation_template_params[:temperature],
          max_tokens: variation_template_params[:max_tokens]
        )
        
        variations << {
          variation_id: i + 1,
          content: parse_ai_response(response),
          temperature_used: variation_template_params[:temperature]
        }
      rescue => e
        Rails.logger.warn "Failed to generate variation #{i + 1}: #{e.message}"
        # Continue with other variations
      end
    end
    
    variations
  end

  # Parameter extraction methods
  def extract_social_media_variables
    {
      'content_type' => params[:content_type] || 'social media post',
      'platform' => params[:platform] || 'general',
      'brand_context' => params[:brand_context] || '',
      'campaign_name' => params[:campaign_name] || '',
      'campaign_goal' => params[:campaign_goal] || 'engagement',
      'target_audience' => params[:target_audience] || '',
      'tone' => params[:tone] || 'engaging',
      'content_length' => params[:content_length] || 'medium',
      'required_elements' => params[:required_elements] || '',
      'restrictions' => params[:restrictions] || '',
      'additional_context' => params[:additional_context] || ''
    }
  end

  def extract_ad_copy_variables
    {
      'ad_type' => params[:ad_type] || 'display ad',
      'platform' => params[:platform] || 'Google Ads',
      'campaign_name' => params[:campaign_name] || '',
      'offering' => params[:offering] || '',
      'target_audience' => params[:target_audience] || '',
      'character_limit' => params[:character_limit] || '150',
      'headline_count' => params[:headline_count] || '3',
      'description_count' => params[:description_count] || '2',
      'key_messages' => params[:key_messages] || '',
      'usp' => params[:usp] || '',
      'emotional_hooks' => params[:emotional_hooks] || '',
      'cta' => params[:cta] || 'Learn More',
      'brand_voice' => params[:brand_voice] || 'professional',
      'platform_requirements' => params[:platform_requirements] || ''
    }
  end

  def extract_email_variables
    {
      'email_type' => params[:email_type] || 'promotional',
      'campaign_context' => params[:campaign_context] || '',
      'subject_focus' => params[:subject_focus] || '',
      'primary_goal' => params[:primary_goal] || 'conversion',
      'target_segment' => params[:target_segment] || '',
      'send_timing' => params[:send_timing] || 'immediate',
      'brand_voice' => params[:brand_voice] || 'professional',
      'tone' => params[:tone] || 'friendly',
      'content_length' => params[:content_length] || 'medium',
      'call_to_action' => params[:call_to_action] || 'Click here',
      'personalization_level' => params[:personalization_level] || 'medium',
      'special_requirements' => params[:special_requirements] || ''
    }
  end

  def extract_landing_page_variables
    {
      'page_purpose' => params[:page_purpose] || 'product promotion',
      'offering' => params[:offering] || '',
      'target_audience' => params[:target_audience] || '',
      'conversion_goal' => params[:conversion_goal] || 'signup',
      'brand_context' => params[:brand_context] || '',
      'page_sections' => params[:page_sections] || 'hero, features, testimonials, cta',
      'key_benefits' => params[:key_benefits] || '',
      'social_proof' => params[:social_proof] || '',
      'competitive_advantages' => params[:competitive_advantages] || '',
      'cta_text' => params[:cta_text] || 'Get Started',
      'additional_requirements' => params[:additional_requirements] || ''
    }
  end

  def extract_campaign_plan_variables
    {
      'campaign_name' => params[:campaign_name] || '',
      'campaign_purpose' => params[:campaign_purpose] || '',
      'budget' => params[:budget] || '',
      'start_date' => params[:start_date] || '',
      'end_date' => params[:end_date] || '',
      'target_audience' => params[:target_audience] || '',
      'brand_context' => params[:brand_context] || '',
      'additional_requirements' => params[:additional_requirements] || ''
    }
  end

  def extract_brand_analysis_variables
    {
      'brand_assets' => params[:brand_assets] || '',
      'focus_areas' => params[:focus_areas] || 'brand voice, messaging, target audience, compliance',
      'technical_context' => params[:technical_context] || ''
    }
  end

  # Parameter validation
  def validate_content_generation_params
    errors = []
    
    # Basic required parameters for most content types
    unless params[:brand_context].present?
      errors << 'brand_context is required'
    end
    
    # Content type specific validations
    case action_name
    when 'social_media'
      errors << 'platform is required' unless params[:platform].present?
    when 'ad_copy'
      errors << 'offering is required' unless params[:offering].present?
      errors << 'target_audience is required' unless params[:target_audience].present?
    when 'email'
      errors << 'email_type is required' unless params[:email_type].present?
      errors << 'primary_goal is required' unless params[:primary_goal].present?
    when 'landing_page'
      errors << 'page_purpose is required' unless params[:page_purpose].present?
      errors << 'offering is required' unless params[:offering].present?
    end
    
    if errors.any?
      render_error("Parameter validation failed: #{errors.join(', ')}", :bad_request)
      return false
    end
    
    true
  end

  def validate_campaign_plan_params
    errors = []
    
    errors << 'campaign_name is required' unless params[:campaign_name].present?
    errors << 'campaign_purpose is required' unless params[:campaign_purpose].present?
    
    if errors.any?
      render_error("Parameter validation failed: #{errors.join(', ')}", :bad_request)
      return false
    end
    
    true
  end

  def validate_brand_analysis_params
    errors = []
    
    errors << 'brand_assets is required' unless params[:brand_assets].present?
    
    if errors.any?
      render_error("Parameter validation failed: #{errors.join(', ')}", :bad_request)
      return false
    end
    
    true
  end

  # Error handling
  def render_error(message, status = :unprocessable_entity)
    render json: {
      success: false,
      error: message,
      timestamp: Time.current.iso8601
    }, status: status
  end

  # Handle exceptions
  rescue_from StandardError do |e|
    Rails.logger.error "API Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if e.respond_to?(:backtrace)
    
    render_error("Internal server error: #{e.message}", :internal_server_error)
  end

  rescue_from AiServiceBase::CircuitBreakerOpenError do |e|
    render_error("AI service temporarily unavailable: #{e.message}", :service_unavailable)
  end

  rescue_from AiServiceBase::RateLimitError do |e|
    render_error("Rate limit exceeded: #{e.message}", :too_many_requests)
  end
end