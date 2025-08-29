class Api::V1::ValidationsController < ApplicationController
  before_action :require_authentication
  skip_before_action :verify_authenticity_token
  
  # Generic validation endpoint
  def validate_field
    table_name = params[:table_name]
    field_name = params[:field_name]
    value = params[:value]
    context = params[:context] || {}
    
    validation_rule = ValidationRule.enabled.for_field(table_name, field_name).first
    
    if validation_rule.nil?
      return render json: { valid: true, errors: [] }
    end
    
    result = validation_rule.validate_value(value, context)
    
    # Add server-side validations for uniqueness checks
    if needs_uniqueness_check?(validation_rule, value)
      uniqueness_result = check_uniqueness(table_name, field_name, value, context)
      unless uniqueness_result[:valid]
        result[:valid] = false
        result[:errors] = (result[:errors] || []) + uniqueness_result[:errors]
      end
    end
    
    render json: result
  end
  
  # Specific validation endpoints for better performance
  def users_email_address
    email = params[:value]&.strip&.downcase
    user_id = params[:user_id] # For edit forms
    
    result = { valid: true, errors: [] }
    
    # Basic format validation
    unless email =~ URI::MailTo::EMAIL_REGEXP
      result[:valid] = false
      result[:errors] << "Please enter a valid email address"
      return render json: result
    end
    
    # Uniqueness check
    existing_user = User.where(email_address: email)
    existing_user = existing_user.where.not(id: user_id) if user_id.present?
    
    if existing_user.exists?
      result[:valid] = false
      result[:errors] << "This email address is already taken"
    end
    
    render json: result
  end
  
  def campaign_plans_name
    name = params[:value]&.strip
    user_id = Current.user.id
    plan_id = params[:plan_id] # For edit forms
    
    result = { valid: true, errors: [] }
    
    # Basic validation
    if name.blank?
      result[:valid] = false
      result[:errors] << "Name is required"
      return render json: result
    end
    
    if name.length < 3 || name.length > 100
      result[:valid] = false
      result[:errors] << "Name must be between 3 and 100 characters"
      return render json: result
    end
    
    # Uniqueness check within user's campaigns
    existing_plan = CampaignPlan.where(user_id: user_id, name: name)
    existing_plan = existing_plan.where.not(id: plan_id) if plan_id.present?
    
    if existing_plan.exists?
      result[:valid] = false
      result[:errors] << "You already have a campaign plan with this name"
    end
    
    render json: result
  end
  
  def journeys_name
    name = params[:value]&.strip
    user_id = Current.user.id
    journey_id = params[:journey_id] # For edit forms
    
    result = { valid: true, errors: [] }
    
    # Basic validation
    if name.blank?
      result[:valid] = false
      result[:errors] << "Name is required"
      return render json: result
    end
    
    if name.length < 3 || name.length > 100
      result[:valid] = false
      result[:errors] << "Name must be between 3 and 100 characters"
      return render json: result
    end
    
    # Uniqueness check within user's journeys
    existing_journey = Journey.where(user_id: user_id, name: name)
    existing_journey = existing_journey.where.not(id: journey_id) if journey_id.present?
    
    if existing_journey.exists?
      result[:valid] = false
      result[:errors] << "You already have a journey with this name"
    end
    
    render json: result
  end
  
  private
  
  def needs_uniqueness_check?(validation_rule, value)
    return false if value.blank?
    validation_rule.rules.any? { |rule| rule['type'] == 'uniqueness' }
  end
  
  def check_uniqueness(table_name, field_name, value, context = {})
    model_class = table_name.classify.constantize
    query = model_class.where(field_name => value)
    
    # Exclude current record for edit forms
    if context['record_id'].present?
      query = query.where.not(id: context['record_id'])
    end
    
    # Scope to current user for user-scoped resources
    if context['user_scoped'] && model_class.column_names.include?('user_id')
      query = query.where(user_id: Current.user.id)
    end
    
    if query.exists?
      { valid: false, errors: ["This #{field_name.humanize.downcase} is already taken"] }
    else
      { valid: true, errors: [] }
    end
  rescue => e
    Rails.logger.error "Validation error: #{e.message}"
    { valid: true, errors: [] } # Fail gracefully
  end
end