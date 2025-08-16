# frozen_string_literal: true

# Service for generating campaign summary plans using LLM integration
class CampaignPlanService < ApplicationService
  include LlmServiceHelper

  def initialize(campaign_plan)
    @campaign_plan = campaign_plan
    @user = campaign_plan.user
  end

  def generate_plan
    return failure_result('Campaign plan must be in draft status') unless @campaign_plan.draft?
    return failure_result('Campaign plan is not ready for generation') unless @campaign_plan.ready_for_generation?

    @campaign_plan.mark_generation_started!

    begin
      # Gather brand context
      brand_context = gather_brand_context

      # Prepare parameters for LLM service
      llm_params = prepare_llm_parameters(brand_context)

      # Generate campaign plan using LLM service
      llm_response = llm_service.generate_campaign_plan(llm_params)

      # Process and store the response
      process_llm_response(llm_response)

      @campaign_plan.mark_generation_completed!
      success_result('Campaign plan generated successfully', @campaign_plan)

    rescue StandardError => e
      @campaign_plan.mark_generation_failed!(e.message)
      Rails.logger.error "Campaign plan generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      failure_result("Failed to generate campaign plan: #{e.message}")
    end
  end

  def regenerate_plan
    return failure_result('Campaign plan cannot be regenerated') unless @campaign_plan.can_be_regenerated?

    # Reset the plan to draft status for regeneration
    @campaign_plan.update!(
      status: 'draft',
      generated_summary: nil,
      generated_strategy: nil,
      generated_timeline: nil,
      generated_assets: nil,
      metadata: (@campaign_plan.metadata || {}).merge(regenerated_at: Time.current)
    )

    generate_plan
  end

  def update_plan_parameters(params)
    begin
      @campaign_plan.update!(params.slice(
        :name, :description, :campaign_type, :objective,
        :target_audience, :brand_context, :budget_constraints, :timeline_constraints
      ))
      success_result('Campaign plan parameters updated', @campaign_plan)
    rescue ActiveRecord::RecordInvalid => e
      failure_result("Invalid parameters: #{e.message}")
    end
  end

  private

  def gather_brand_context
    brand_identity = @user.active_brand_identity
    
    base_context = {
      user_preferences: {
        company: @user.company,
        role: @user.role
      }
    }

    if brand_identity
      base_context.merge!(
        brand_name: brand_identity.name,
        brand_voice: brand_identity.brand_voice,
        tone_guidelines: brand_identity.tone_guidelines,
        messaging_framework: brand_identity.messaging_framework,
        restrictions: brand_identity.restrictions,
        processed_guidelines: brand_identity.processed_guidelines_summary
      )
    end

    # Merge with campaign-specific brand context if provided
    if @campaign_plan.brand_context.present?
      campaign_context = @campaign_plan.brand_context_summary
      base_context = base_context.merge(campaign_context)
    end

    base_context
  end

  def prepare_llm_parameters(brand_context)
    {
      campaign_type: @campaign_plan.campaign_type,
      objective: @campaign_plan.objective,
      description: @campaign_plan.description,
      target_audience: @campaign_plan.target_audience_summary,
      brand_context: brand_context,
      budget_constraints: @campaign_plan.budget_summary,
      timeline_constraints: @campaign_plan.timeline_summary,
      user_context: {
        company: @user.company,
        industry: extract_industry_from_brand_context(brand_context)
      }
    }
  end

  def process_llm_response(response)
    # Extract the main components from LLM response
    summary = response[:summary] || response['summary']
    strategy = response[:strategy] || response['strategy']
    timeline = response[:timeline] || response['timeline']
    assets = response[:assets] || response['assets']
    metadata = response[:metadata] || response['metadata']

    # Update the campaign plan with generated content
    @campaign_plan.update!(
      generated_summary: summary,
      generated_strategy: strategy.is_a?(Hash) ? strategy : { description: strategy },
      generated_timeline: timeline.is_a?(Array) ? timeline : [{ activity: timeline }],
      generated_assets: assets.is_a?(Array) ? assets : [assets].compact,
      metadata: (@campaign_plan.metadata || {}).merge(
        llm_metadata: metadata || {},
        generated_at: Time.current,
        generation_method: 'llm_service'
      )
    )
  end

  def extract_industry_from_brand_context(brand_context)
    # Try to extract industry information from brand context
    industry_keywords = {
      'technology' => %w[tech software saas app platform digital],
      'healthcare' => %w[health medical healthcare pharma wellness],
      'finance' => %w[financial bank fintech investment insurance],
      'retail' => %w[retail ecommerce shopping store commerce],
      'education' => %w[education learning school university training],
      'hospitality' => %w[hotel restaurant hospitality travel tourism],
      'manufacturing' => %w[manufacturing industrial production factory],
      'consulting' => %w[consulting advisory professional services]
    }

    context_text = brand_context.values.join(' ').downcase

    industry_keywords.each do |industry, keywords|
      return industry if keywords.any? { |keyword| context_text.include?(keyword) }
    end

    'general'
  end

  def success_result(message, data = nil)
    {
      success: true,
      message: message,
      data: data
    }
  end

  def failure_result(message, errors = nil)
    {
      success: false,
      message: message,
      errors: errors
    }
  end
end