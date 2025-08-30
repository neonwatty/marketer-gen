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
      # Step 1: Analyzing Requirements (0-15%)
      update_progress(0, 5, 'Analyzing campaign requirements...', '2-3 minutes')
      sleep(0.5) # Simulate processing time
      
      # Step 2: Gathering Brand Context (15-35%)
      update_progress(1, 20, 'Gathering brand context and guidelines...', '90 seconds')
      brand_context = gather_brand_context
      sleep(0.5)

      # Step 3: Generating Strategy (35-60%)
      update_progress(2, 45, 'Generating campaign strategy...', '60 seconds')
      llm_params = prepare_llm_parameters(brand_context)
      sleep(0.5)

      # Step 4: Creating Content Plan (60-80%)
      update_progress(3, 70, 'Creating detailed content plan...', '45 seconds')
      llm_response = llm_service.generate_campaign_plan(llm_params)
      sleep(0.5)

      # Step 5: Building Timeline (80-95%)
      update_progress(4, 85, 'Building campaign timeline...', '20 seconds')
      process_llm_response(llm_response)
      sleep(0.5)

      # Step 6: Finalizing Assets (95-100%)
      update_progress(5, 95, 'Finalizing campaign assets...', '10 seconds')
      sleep(0.5)

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
      content_strategy: nil,
      creative_approach: nil,
      strategic_rationale: nil,
      content_mapping: nil,
      metadata: (@campaign_plan.metadata || {}).merge(regenerated_at: Time.current)
    )

    generate_plan
  end

  private

  def update_progress(step, percentage, message, estimated_time)
    @campaign_plan.update_generation_progress(
      step: step,
      percentage: percentage,
      message: message,
      estimated_time: estimated_time
    )
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
      },
      strategic_requirements: {
        include_content_strategy: true,
        include_creative_approach: true,
        include_strategic_rationale: true,
        include_content_mapping: true,
        cross_asset_consistency: true,
        platform_specific_adaptations: true,
        justification_required: true
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
    
    # Extract strategic elements
    content_strategy = response[:content_strategy] || response['content_strategy']
    creative_approach = response[:creative_approach] || response['creative_approach']
    strategic_rationale = response[:strategic_rationale] || response['strategic_rationale']
    content_mapping = response[:content_mapping] || response['content_mapping']

    # Apply content size limits to prevent excessive content
    summary = truncate_content(summary, 2000) if summary.is_a?(String)
    strategy = truncate_strategy_content(strategy)
    timeline = truncate_timeline_content(timeline)
    assets = truncate_assets_content(assets)
    content_strategy = truncate_content_hash(content_strategy, 1500)
    creative_approach = truncate_content_hash(creative_approach, 1500)
    strategic_rationale = truncate_content_hash(strategic_rationale, 1500)
    content_mapping = truncate_content_mapping(content_mapping)

    # Update the campaign plan with generated content
    @campaign_plan.update!(
      generated_summary: summary,
      generated_strategy: strategy.is_a?(Hash) ? strategy : { description: strategy },
      generated_timeline: timeline.is_a?(Array) ? timeline : [{ activity: timeline }],
      generated_assets: assets.is_a?(Array) ? assets : [assets].compact,
      content_strategy: content_strategy.present? ? (content_strategy.is_a?(Hash) ? content_strategy : { description: content_strategy }) : nil,
      creative_approach: creative_approach.present? ? (creative_approach.is_a?(Hash) ? creative_approach : { description: creative_approach }) : nil,
      strategic_rationale: strategic_rationale.present? ? (strategic_rationale.is_a?(Hash) ? strategic_rationale : { description: strategic_rationale }) : nil,
      content_mapping: content_mapping.present? ? (content_mapping.is_a?(Array) ? content_mapping : [content_mapping]) : nil,
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

  # Content truncation methods to prevent excessive page rendering
  def truncate_content(content, max_length)
    return content unless content.is_a?(String)
    content.length > max_length ? "#{content[0..max_length]}..." : content
  end

  def truncate_content_hash(content_hash, max_length)
    return content_hash unless content_hash.is_a?(Hash)
    
    truncated = {}
    content_hash.each do |key, value|
      if value.is_a?(String)
        truncated[key] = truncate_content(value, max_length)
      elsif value.is_a?(Array)
        truncated[key] = value.first(10) # Limit arrays to 10 items
      else
        truncated[key] = value
      end
    end
    truncated
  end

  def truncate_strategy_content(strategy)
    return strategy unless strategy.is_a?(Hash)
    
    truncated = {}
    strategy.each do |key, value|
      case key.to_s
      when 'description'
        truncated[key] = truncate_content(value, 3000)
      when 'phases', 'channels'
        truncated[key] = value.is_a?(Array) ? value.first(8) : value
      when 'budget_allocation'
        truncated[key] = value.is_a?(Hash) ? value : value
      else
        truncated[key] = value.is_a?(String) ? truncate_content(value, 1000) : value
      end
    end
    truncated
  end

  def truncate_timeline_content(timeline)
    return timeline unless timeline.is_a?(Array)
    
    # Limit timeline to 20 items and truncate activity descriptions
    timeline.first(20).map do |item|
      if item.is_a?(Hash) && item[:activity]
        item.merge(activity: truncate_content(item[:activity].to_s, 200))
      elsif item.is_a?(Hash) && item['activity']
        item.merge('activity' => truncate_content(item['activity'].to_s, 200))
      else
        item
      end
    end
  end

  def truncate_assets_content(assets)
    return assets unless assets.is_a?(Array)
    
    # Limit to 15 assets and truncate descriptions
    assets.first(15).map do |asset|
      asset.is_a?(String) ? truncate_content(asset, 150) : asset
    end
  end

  def truncate_content_mapping(content_mapping)
    return content_mapping unless content_mapping.is_a?(Array)
    
    # Limit content mapping to 10 items
    content_mapping.first(10).map do |mapping|
      if mapping.is_a?(Hash)
        truncated = {}
        mapping.each do |key, value|
          truncated[key] = value.is_a?(String) ? truncate_content(value, 500) : value
        end
        truncated
      else
        mapping
      end
    end
  end
end