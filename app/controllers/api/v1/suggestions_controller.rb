class Api::V1::SuggestionsController < ApplicationController
  before_action :require_authentication

  def campaign_plan_suggestions
    field_name = params[:field]
    query = params[:query]
    
    service = SmartDefaultsService.new(Current.user)
    defaults = service.campaign_plan_defaults
    
    suggestions = case field_name
    when 'name'
      filter_suggestions(defaults[:suggested_names], query)
    when 'description'
      filter_suggestions(defaults[:suggested_descriptions], query)
    when 'target_audience'
      filter_suggestions(defaults[:suggested_target_audiences], query)
    when 'budget_constraints'
      filter_suggestions(defaults[:suggested_budgets], query)
    when 'timeline_constraints'
      filter_suggestions(defaults[:suggested_timelines], query)
    else
      []
    end

    render json: {
      field: field_name,
      query: query,
      suggestions: suggestions.map { |s| format_suggestion(s, field_name) }
    }
  end

  def journey_suggestions
    field_name = params[:field]
    query = params[:query]
    
    service = SmartDefaultsService.new(Current.user)
    defaults = service.journey_defaults
    
    suggestions = case field_name
    when 'name'
      filter_suggestions(defaults[:suggested_names], query)
    when 'target_audience'
      filter_suggestions(defaults[:suggested_target_audiences], query)
    else
      []
    end

    render json: {
      field: field_name,
      query: query,
      suggestions: suggestions.map { |s| format_suggestion(s, field_name) }
    }
  end

  def onboarding_status
    service = SmartDefaultsService.new(Current.user)
    progress = service.user_onboarding_progress
    
    render json: {
      user_id: Current.user.id,
      onboarding: progress,
      smart_suggestions_enabled: true
    }
  end

  def onboarding_progress
    service = SmartDefaultsService.new(Current.user)
    progress = service.user_onboarding_progress
    
    render json: {
      onboarding: progress,
      timestamp: Time.current.iso8601
    }
  end

  private

  def filter_suggestions(suggestions, query)
    return suggestions.first(5) if query.blank?
    
    # Filter suggestions based on query
    filtered = suggestions.select do |suggestion|
      suggestion.to_s.downcase.include?(query.downcase)
    end
    
    # If no matches, return original suggestions
    filtered.any? ? filtered.first(5) : suggestions.first(3)
  end

  def format_suggestion(suggestion, field_name)
    case field_name
    when 'name'
      {
        text: suggestion,
        description: "Suggested based on current date and your history"
      }
    when 'description'
      {
        text: suggestion,
        description: "Template description for quick setup"
      }
    when 'target_audience'
      {
        text: suggestion,
        description: "Common target audience definition"
      }
    when 'budget_constraints', 'timeline_constraints'
      {
        text: suggestion,
        description: "Typical constraint for this type of campaign"
      }
    else
      suggestion.is_a?(String) ? { text: suggestion } : suggestion
    end
  end
end