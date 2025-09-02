# frozen_string_literal: true

# Service for generating all content pieces for a campaign plan in bulk
class BulkContentGenerationService < ApplicationService
  
  def initialize(campaign_plan)
    @campaign_plan = campaign_plan
    @user = campaign_plan.user
    @generated_contents = []
    @errors = []
  end

  def generate_all
    return failure_result('Campaign plan must be completed') unless @campaign_plan.completed?
    return failure_result('Campaign plan has no generated assets list') unless @campaign_plan.generated_assets.present?
    
    begin
      content_types = determine_content_types
      
      if content_types.empty?
        return failure_result('No content types could be determined from campaign assets')
      end
      
      # Generate content for each type
      content_types.each do |content_type|
        generate_content_for_type(content_type)
      end
      
      if @errors.any?
        partial_success_result
      else
        success_result("Successfully generated #{@generated_contents.count} content pieces", {
          contents: @generated_contents,
          count: @generated_contents.count
        })
      end
      
    rescue StandardError => e
      Rails.logger.error "Bulk content generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      failure_result("Failed to generate content: #{e.message}")
    end
  end

  private

  def determine_content_types
    content_types = []
    assets = @campaign_plan.generated_assets
    
    # Parse the assets list to determine what content types to generate
    if assets.is_a?(Array)
      assets.each do |asset|
        asset_text = asset.to_s.downcase
        
        # Map asset descriptions to content types
        if asset_text.include?('email')
          content_types << 'email' unless content_types.include?('email')
        end
        
        if asset_text.include?('social') || asset_text.include?('post')
          content_types << 'social_post' unless content_types.include?('social_post')
        end
        
        if asset_text.include?('blog') || asset_text.include?('article')
          content_types << 'blog_article' unless content_types.include?('blog_article')
        end
        
        if asset_text.include?('ad') || asset_text.include?('advertisement')
          content_types << 'ad_copy' unless content_types.include?('ad_copy')
        end
        
        if asset_text.include?('landing') || asset_text.include?('page')
          content_types << 'landing_page' unless content_types.include?('landing_page')
        end
        
        if asset_text.include?('video') || asset_text.include?('script')
          content_types << 'video_script' unless content_types.include?('video_script')
        end
        
        if asset_text.include?('press') || asset_text.include?('release')
          content_types << 'press_release' unless content_types.include?('press_release')
        end
        
        if asset_text.include?('newsletter')
          content_types << 'newsletter' unless content_types.include?('newsletter')
        end
      end
    end
    
    # If no specific types found, generate standard set based on campaign type
    if content_types.empty?
      content_types = default_content_types_for_campaign
    end
    
    content_types
  end

  def default_content_types_for_campaign
    case @campaign_plan.campaign_type
    when 'product_launch'
      ['email', 'social_post', 'press_release', 'blog_article', 'ad_copy']
    when 'brand_awareness'
      ['social_post', 'blog_article', 'ad_copy', 'video_script']
    when 'lead_generation'
      ['email', 'landing_page', 'ad_copy', 'white_paper']
    when 'customer_retention'
      ['email', 'newsletter', 'social_post', 'case_study']
    when 'sales_promotion'
      ['email', 'social_post', 'ad_copy', 'landing_page']
    when 'event_marketing'
      ['email', 'social_post', 'press_release', 'landing_page']
    else
      ['email', 'social_post', 'blog_article'] # Basic set
    end
  end

  def generate_content_for_type(content_type)
    begin
      # Determine format variants based on content type
      format_variants = determine_format_variants(content_type)
      
      format_variants.each do |format_variant|
        result = generate_single_content(content_type, format_variant)
        
        if result[:success]
          @generated_contents << result[:content]
        else
          @errors << "Failed to generate #{content_type} (#{format_variant}): #{result[:error]}"
        end
      end
      
    rescue StandardError => e
      @errors << "Error generating #{content_type}: #{e.message}"
      Rails.logger.error "Content generation error for #{content_type}: #{e.message}"
    end
  end

  def determine_format_variants(content_type)
    case content_type
    when 'social_post'
      ['short', 'medium'] # Multiple social post lengths
    when 'email'
      ['standard'] # Standard email format
    when 'blog_article'
      ['long'] # Full blog article
    when 'ad_copy'
      ['short', 'medium'] # Different ad lengths
    when 'landing_page'
      ['standard'] # Standard landing page
    when 'video_script'
      ['medium'] # Standard video script length
    when 'press_release'
      ['standard'] # Standard press release format
    when 'newsletter'
      ['standard'] # Standard newsletter
    when 'white_paper'
      ['comprehensive'] # Full white paper
    when 'case_study'
      ['detailed'] # Detailed case study
    else
      ['standard'] # Default format
    end
  end

  def generate_single_content(content_type, format_variant)
    begin
      # Use existing ContentGenerationService
      result = ContentGenerationService.generate_content(
        @campaign_plan,
        content_type,
        {
          format_variant: format_variant,
          title: generate_title(content_type, format_variant),
          auto_generated: true,
          bulk_generation: true
        }
      )
      
      if result[:success]
        content = result[:data][:content]
        { success: true, content: content }
      else
        { success: false, error: result[:error] || 'Unknown error' }
      end
      
    rescue StandardError => e
      { success: false, error: e.message }
    end
  end

  def generate_title(content_type, format_variant)
    base_title = "#{content_type.humanize} for #{@campaign_plan.name}"
    
    if format_variant != 'standard'
      "#{base_title} (#{format_variant.capitalize})"
    else
      base_title
    end
  end

  def partial_success_result
    {
      success: true,
      partial: true,
      message: "Generated #{@generated_contents.count} content pieces with #{@errors.count} errors",
      count: @generated_contents.count,
      errors: @errors,
      contents: @generated_contents
    }
  end
end