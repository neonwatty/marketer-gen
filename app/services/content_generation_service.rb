# frozen_string_literal: true

# Service for generating content with version control and LLM integration
# Coordinates content creation workflow with automatic version management
class ContentGenerationService < ApplicationService
  # Standard content generation
  # @param campaign_plan [CampaignPlan] - campaign to generate content for
  # @param content_type [String] - type of content to generate
  # @param options [Hash] - additional generation options
  # @option options [String] :format_variant - variant to generate (short, medium, long)
  # @option options [String] :title - custom title for content
  # @option options [Hash] :custom_prompts - custom prompts to override defaults
  # @option options [Boolean] :generate_variants - whether to generate all format variants
  # @return [Hash] result with success status and data/error
  def self.generate_content(campaign_plan, content_type, options = {})
    new(campaign_plan, content_type, options).generate_content
  end

  # Regenerate existing content (creates new version)
  # @param existing_content_id [Integer] - ID of content to regenerate
  # @param options [Hash] - regeneration options
  # @option options [String] :change_summary - summary of changes being made
  # @option options [Boolean] :preserve_approval - whether to preserve approval status
  # @return [Hash] result with success status and data/error
  def self.regenerate_content(existing_content_id, options = {})
    existing_content = GeneratedContent.find(existing_content_id)
    new(
      existing_content.campaign_plan,
      existing_content.content_type,
      options.merge(existing_content_id: existing_content_id)
    ).regenerate_content
  end

  # Create format variants for existing content
  # @param content_id [Integer] - ID of content to create variants for
  # @param variants [Array<String>] - list of variants to create
  # @return [Hash] result with success status and data/error
  def self.create_format_variants(content_id, variants)
    content = GeneratedContent.find(content_id)
    new(content.campaign_plan, content.content_type, {}).create_format_variants(content, variants)
  end

  # Approve content (workflow management)
  # @param content_id [Integer] - ID of content to approve
  # @param approver_user [User] - user approving the content
  # @return [Hash] result with success status and data/error
  def self.approve_content(content_id, approver_user)
    content = GeneratedContent.find(content_id)
    new(content.campaign_plan, content.content_type, {}).approve_content(content, approver_user)
  end

  attr_reader :campaign_plan, :content_type, :options, :existing_content

  def initialize(campaign_plan, content_type, options = {})
    @campaign_plan = campaign_plan
    @content_type = content_type
    @options = options
    @existing_content = options[:existing_content_id] ? GeneratedContent.find(options[:existing_content_id]) : nil

    validate_inputs!
  end

  # Main content generation method
  def generate_content
    log_service_call("ContentGenerationService#generate_content", {
      campaign_plan_id: campaign_plan.id,
      content_type: content_type,
      options: options.except(:custom_prompts)
    })

    begin
      ActiveRecord::Base.transaction do
        if options[:generate_variants]
          generate_all_format_variants
        else
          format_variant = options[:format_variant] || "standard"
          generate_single_content(format_variant)
        end
      end
    rescue => error
      Rails.logger.error "ContentGenerationService error: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?

      {
        success: false,
        error: error.message,
        context: {
          campaign_plan_id: campaign_plan.id,
          content_type: content_type,
          action: "generate_content"
        }
      }
    end
  end

  # Regenerate existing content as new version
  def regenerate_content
    log_service_call("ContentGenerationService#regenerate_content", {
      existing_content_id: existing_content.id,
      options: options.except(:custom_prompts)
    })

    begin
      ActiveRecord::Base.transaction do
        # Create new version from existing content
        current_user = (Current.respond_to?(:user) && Current.user) || campaign_plan.user
        new_version = existing_content.create_new_version!(
          current_user,
          options[:change_summary] || "Content regenerated"
        )

        # Generate new content for the version
        llm_result = generate_llm_content(existing_content.format_variant)

        if llm_result[:success]
          update_content_from_llm_result(new_version, llm_result[:data])

          {
            success: true,
            data: {
              content: new_version,
              action: "regenerated",
              version_number: new_version.version_number
            }
          }
        else
          raise StandardError, "LLM generation failed: #{llm_result[:error]}"
        end
      end
    rescue => error
      Rails.logger.error "ContentGenerationService error: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?

      {
        success: false,
        error: error.message,
        context: {
          existing_content_id: existing_content.id,
          action: "regenerate_content"
        }
      }
    end
  end

  # Create format variants for existing content
  def create_format_variants(content, variants)
    log_service_call("ContentGenerationService#create_format_variants", {
      content_id: content.id,
      variants: variants
    })

    begin
      results = []
      errors = []

      ActiveRecord::Base.transaction do
        variants.each do |variant|
          # Skip if variant already exists
          existing_variant = GeneratedContent.where(
            campaign_plan: content.campaign_plan,
            content_type: content.content_type,
            format_variant: variant,
            original_content_id: content.original_content_id || content.id
          ).first

          if existing_variant
            results << { variant: variant, status: "exists", content: existing_variant }
            next
          end

          # Generate new variant
          llm_result = generate_llm_content(variant)

          if llm_result[:success]
            variant_content = create_content_record(
              llm_result[:data],
              variant,
              content.original_content_id || content.id
            )
            results << { variant: variant, status: "created", content: variant_content }
          else
            errors << { variant: variant, error: llm_result[:error] }
          end
        end

        if errors.any?
          raise StandardError, "Failed to generate variants: #{errors.map { |e| "#{e[:variant]}: #{e[:error]}" }.join(', ')}"
        end
      end

      {
        success: true,
        data: {
          variants: results,
          total_created: results.count { |r| r[:status] == "created" },
          total_existing: results.count { |r| r[:status] == "exists" }
        }
      }
    rescue => error
      Rails.logger.error "ContentGenerationService error: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?

      {
        success: false,
        error: error.message,
        context: {
          content_id: content.id,
          variants: variants,
          action: "create_format_variants"
        }
      }
    end
  end

  # Approve content through workflow
  def approve_content(content, approver_user)
    Rails.logger.info "ContentGenerationService#approve_content - content_id: #{content.id}, approver_user_id: #{approver_user.id}"

    begin
      # Validate content can be approved
      unless content.in_review?
        return {
          success: false,
          error: "Content must be in review status to be approved. Current status: #{content.status}"
        }
      end

      # Approve content
      if content.approve!(approver_user)
        {
          success: true,
          data: {
            content: content.reload,
            action: "approved",
            approved_by: approver_user.full_name
          }
        }
      else
        {
          success: false,
          error: "Failed to approve content",
          validation_errors: content.errors.full_messages
        }
      end
    rescue => error
      Rails.logger.error "ContentGenerationService error: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?

      {
        success: false,
        error: error.message,
        context: {
          content_id: content.id,
          approver_user_id: approver_user.id,
          action: "approve_content"
        }
      }
    end
  end

  private

  # Validate initialization inputs
  def validate_inputs!
    unless campaign_plan.is_a?(CampaignPlan)
      raise ArgumentError, "campaign_plan must be a CampaignPlan instance"
    end

    unless GeneratedContent::CONTENT_TYPES.include?(content_type)
      raise ArgumentError, "Invalid content_type: #{content_type}. Must be one of: #{GeneratedContent::CONTENT_TYPES.join(', ')}"
    end

    format_variant = options[:format_variant]
    if format_variant && !GeneratedContent::FORMAT_VARIANTS.include?(format_variant)
      raise ArgumentError, "Invalid format_variant: #{format_variant}. Must be one of: #{GeneratedContent::FORMAT_VARIANTS.join(', ')}"
    end
  end

  # Generate all format variants for content type
  def generate_all_format_variants
    variants = determine_relevant_variants
    results = []
    errors = []

    variants.each do |variant|
      begin
        result = generate_single_content(variant)
        if result[:success]
          results << { variant: variant, content: result[:data][:content] }
        else
          errors << { variant: variant, error: result[:error] }
        end
      rescue => error
        errors << { variant: variant, error: error.message }
      end
    end

    if errors.any?
      raise StandardError, "Failed to generate some variants: #{errors.map { |e| "#{e[:variant]}: #{e[:error]}" }.join(', ')}"
    end

    {
      success: true,
      data: {
        variants: results,
        total_generated: results.length
      }
    }
  end

  # Generate single piece of content
  def generate_single_content(format_variant)
    llm_result = generate_llm_content(format_variant)

    if llm_result[:success]
      content = create_content_record(llm_result[:data], format_variant)

      {
        success: true,
        data: {
          content: content,
          format_variant: format_variant,
          action: "generated"
        }
      }
    else
      {
        success: false,
        error: "LLM generation failed: #{llm_result[:error]}",
        format_variant: format_variant
      }
    end
  end

  # Generate content using LLM service
  def generate_llm_content(format_variant)
    begin
      # Prepare generation parameters based on content type
      llm_params = build_llm_parameters(format_variant)

      # Call appropriate LLM service method based on content type
      llm_result = case content_type
      when "email"
        llm_service.generate_email_content(llm_params)
      when "social_post"
        llm_service.generate_social_media_content(llm_params)
      when "ad_copy"
        llm_service.generate_ad_copy(llm_params)
      when "landing_page"
        llm_service.generate_landing_page_content(llm_params)
      else
        # For other content types, use a generic approach
        generate_generic_content(llm_params, format_variant)
      end

      # Validate LLM response
      if llm_result && (llm_result[:content] || llm_result["content"])
        { success: true, data: normalize_llm_response(llm_result) }
      else
        { success: false, error: "LLM service returned empty or invalid response" }
      end

    rescue => error
      Rails.logger.error "LLM service error: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?

      # Return fallback content if LLM fails
      if options[:enable_fallback] != false
        { success: true, data: generate_fallback_content(format_variant) }
      else
        { success: false, error: "LLM service failed: #{error.message}" }
      end
    end
  end

  # Build parameters for LLM service call
  def build_llm_parameters(format_variant)
    base_params = {
      campaign_type: campaign_plan.campaign_type,
      objective: campaign_plan.objective,
      target_audience: campaign_plan.target_audience_summary,
      brand_context: campaign_plan.brand_context_summary,
      content_type: content_type,
      format_variant: format_variant
    }

    # Add content-specific parameters
    case content_type
    when "email"
      base_params.merge(
        email_type: options[:email_type] || "promotional",
        subject: options[:title] || generate_default_title,
        tone: options[:tone] || "professional"
      )
    when "social_post"
      base_params.merge(
        platform: options[:platform] || "general",
        tone: options[:tone] || "engaging",
        character_limit: get_character_limit_for_variant(format_variant)
      )
    when "ad_copy"
      base_params.merge(
        ad_type: options[:ad_type] || "search",
        platform: options[:platform] || "google",
        objective: campaign_plan.objective
      )
    when "landing_page"
      base_params.merge(
        page_type: options[:page_type] || "product",
        objective: campaign_plan.objective,
        key_features: options[:key_features] || []
      )
    else
      base_params
    end.merge(options[:custom_prompts] || {})
  end

  # Generate generic content for unsupported content types
  def generate_generic_content(params, format_variant)
    # Use social media generation as fallback for generic content
    params_with_context = params.merge(
      platform: "general",
      topic: "#{content_type} content for #{campaign_plan.name}",
      character_limit: get_character_limit_for_variant(format_variant)
    )

    llm_service.generate_social_media_content(params_with_context)
  end

  # Normalize LLM response to consistent format
  def normalize_llm_response(llm_result)
    case content_type
    when "email"
      {
        title: llm_result[:subject] || llm_result["subject"] || options[:title] || generate_default_title,
        content: llm_result[:content] || llm_result["content"],
        metadata: llm_result[:metadata] || llm_result["metadata"] || {}
      }
    when "ad_copy"
      {
        title: llm_result[:headline] || llm_result["headline"] || options[:title] || generate_default_title,
        content: build_ad_content(llm_result),
        metadata: (llm_result[:metadata] || llm_result["metadata"] || {}).merge(
          headline: llm_result[:headline] || llm_result["headline"],
          description: llm_result[:description] || llm_result["description"],
          call_to_action: llm_result[:call_to_action] || llm_result["call_to_action"]
        )
      }
    when "landing_page"
      {
        title: llm_result[:headline] || llm_result["headline"] || options[:title] || generate_default_title,
        content: build_landing_page_content(llm_result),
        metadata: (llm_result[:metadata] || llm_result["metadata"] || {}).merge(
          headline: llm_result[:headline] || llm_result["headline"],
          subheadline: llm_result[:subheadline] || llm_result["subheadline"],
          cta: llm_result[:cta] || llm_result["cta"]
        )
      }
    else
      {
        title: options[:title] || generate_default_title,
        content: llm_result[:content] || llm_result["content"],
        metadata: llm_result[:metadata] || llm_result["metadata"] || {}
      }
    end
  end

  # Build ad copy content from LLM response
  def build_ad_content(llm_result)
    parts = []
    parts << "Headline: #{llm_result[:headline] || llm_result['headline']}" if llm_result[:headline] || llm_result["headline"]
    parts << "Description: #{llm_result[:description] || llm_result['description']}" if llm_result[:description] || llm_result["description"]
    parts << "Call to Action: #{llm_result[:call_to_action] || llm_result['call_to_action']}" if llm_result[:call_to_action] || llm_result["call_to_action"]
    parts.join("\n\n")
  end

  # Build landing page content from LLM response
  def build_landing_page_content(llm_result)
    parts = []
    parts << "# #{llm_result[:headline] || llm_result['headline']}" if llm_result[:headline] || llm_result["headline"]
    parts << "## #{llm_result[:subheadline] || llm_result['subheadline']}" if llm_result[:subheadline] || llm_result["subheadline"]
    parts << llm_result[:body] || llm_result["body"] if llm_result[:body] || llm_result["body"]
    parts << "**Call to Action:** #{llm_result[:cta] || llm_result['cta']}" if llm_result[:cta] || llm_result["cta"]
    parts.join("\n\n")
  end

  # Create content record in database
  def create_content_record(llm_data, format_variant, original_content_id = nil)
    current_user = (Current.respond_to?(:user) && Current.user) || campaign_plan.user
    content_params = {
      campaign_plan: campaign_plan,
      content_type: content_type,
      format_variant: format_variant,
      title: llm_data[:title],
      body_content: llm_data[:content],
      status: "draft",
      created_by: current_user,
      metadata: build_content_metadata(llm_data[:metadata], format_variant),
      original_content_id: original_content_id
    }

    content = GeneratedContent.create!(content_params)
    validate_content_quality(content)
    content
  end

  # Update existing content from LLM result
  def update_content_from_llm_result(content, llm_data)
    content.update!(
      title: llm_data[:title],
      body_content: llm_data[:content],
      metadata: content.metadata.merge(
        llm_data[:metadata] || {},
        regenerated_at: Time.current,
        regeneration_source: "llm_service"
      )
    )

    validate_content_quality(content)
    content
  end

  # Build content metadata
  def build_content_metadata(llm_metadata, format_variant)
    base_metadata = {
      creation_source: "content_generation_service",
      auto_generated: true,
      generated_at: Time.current,
      format_variant: format_variant,
      campaign_plan_id: campaign_plan.id,
      generation_parameters: options.except(:custom_prompts)
    }

    base_metadata.merge(llm_metadata || {})
  end

  # Generate fallback content when LLM fails
  def generate_fallback_content(format_variant)
    {
      title: "#{content_type.humanize} for #{campaign_plan.name}",
      content: build_fallback_content_body(format_variant),
      metadata: {
        fallback_content: true,
        generated_at: Time.current,
        reason: "llm_service_unavailable"
      }
    }
  end

  # Build fallback content body
  def build_fallback_content_body(format_variant)
    base_length = get_character_limit_for_variant(format_variant)

    content = "This is placeholder #{content_type} content for the #{campaign_plan.name} campaign. "
    content += "Campaign objective: #{campaign_plan.objective}. "
    content += "Target audience: #{campaign_plan.target_audience&.truncate(100) || 'General audience'}. "

    # Pad content to meet minimum length requirements
    while content.length < base_length / 2
      content += "This content should be replaced with professionally generated copy that aligns with your brand guidelines and campaign objectives. "
    end

    content.truncate(base_length)
  end

  # Validate content quality
  def validate_content_quality(content)
    unless content.valid?
      raise ActiveRecord::RecordInvalid, content
    end

    # Additional quality checks
    if content.word_count < 5
      Rails.logger.warn "Generated content has very low word count: #{content.word_count} words"
    end

    # Check for placeholder content
    if content.body_content.downcase.include?("placeholder") || content.body_content.downcase.include?("lorem ipsum")
      Rails.logger.warn "Generated content appears to contain placeholder text"
    end
  end

  # Determine relevant variants for content type
  def determine_relevant_variants
    case content_type
    when "social_post"
      %w[short medium]
    when "email"
      %w[brief standard extended]
    when "ad_copy"
      %w[short medium long]
    when "blog_article", "white_paper", "case_study"
      %w[summary standard comprehensive]
    else
      %w[short medium long]
    end
  end

  # Get character limit for format variant
  def get_character_limit_for_variant(format_variant)
    case format_variant
    when "short", "brief"
      500
    when "medium", "standard"
      1500
    when "long", "extended", "detailed"
      3000
    when "comprehensive"
      5000
    else
      1500
    end
  end

  # Generate default title
  def generate_default_title
    "#{content_type.humanize} for #{campaign_plan.name}"
  end
end
