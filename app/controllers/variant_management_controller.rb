# Controller for managing A/B test variants and comparison interfaces
class VariantManagementController < ApplicationController
  before_action :set_content_request, only: [:show, :create, :compare, :update, :destroy]
  before_action :set_variant, only: [:show_variant, :update_variant, :destroy_variant]

  # GET /content/:content_request_id/variants
  def index
    @content_request = ContentRequest.find(params[:content_request_id])
    @variants = @content_request.content_variants.includes(:performance_data)
    @comparison_data = build_comparison_overview(@variants) if @variants.length > 1
  end

  # GET /content/:content_request_id/variants/new
  def new
    @content_request = ContentRequest.find(params[:content_request_id])
    @original_content = @content_request.content_response&.generated_content
    @generation_options = build_generation_options
    @ai_suggestions = fetch_ai_suggestions(@original_content) if @original_content
  end

  # POST /content/:content_request_id/variants
  def create
    begin
      variant_service = initialize_variant_service
      generation_result = variant_service.generate_variants(
        strategies: params[:strategies]&.split(',')&.map(&:to_sym),
        variant_count: params[:variant_count]&.to_i || 3,
        options: build_generation_options_from_params
      )

      @variants = save_generated_variants(generation_result)
      
      render json: {
        success: true,
        variants: format_variants_for_response(@variants),
        analysis: generation_result[:strategy_analysis],
        predictions: generation_result[:performance_predictions]
      }
    rescue => e
      Rails.logger.error "Variant generation failed: #{e.message}"
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end
  end

  # GET /content/:content_request_id/variants/compare
  def compare
    variant_ids = params[:variant_ids]&.split(',') || []
    @variants = @content_request.content_variants.where(id: variant_ids)
    
    if @variants.length < 2
      redirect_to content_request_variants_path(@content_request), 
                  alert: 'Please select at least 2 variants to compare'
      return
    end

    @comparison_analysis = build_detailed_comparison(@variants)
    @performance_predictions = generate_performance_predictions(@variants)
    @testing_recommendations = generate_testing_recommendations(@variants)
  end

  # GET /variants/:id
  def show_variant
    @content_request = @variant.content_request
    @performance_data = @variant.performance_data || {}
    @analysis = analyze_single_variant(@variant)
    @suggested_improvements = generate_improvement_suggestions(@variant)
  end

  # PATCH /variants/:id
  def update_variant
    if @variant.update(variant_params)
      render json: { 
        success: true, 
        variant: format_variant_for_response(@variant),
        message: 'Variant updated successfully'
      }
    else
      render json: { 
        success: false, 
        errors: @variant.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # DELETE /variants/:id
  def destroy_variant
    @variant.destroy
    render json: { success: true, message: 'Variant deleted successfully' }
  end

  # POST /content/:content_request_id/variants/generate_ai_suggestions
  def generate_ai_suggestions
    original_content = @content_request.content_response&.generated_content
    return render json: { error: 'No original content found' }, status: :not_found unless original_content

    begin
      advisor_service = initialize_ai_advisor_service
      suggestions = advisor_service.generate_intelligent_suggestions(
        original_content,
        build_ai_context
      )

      render json: {
        success: true,
        suggestions: suggestions[:suggested_variants],
        analysis: suggestions[:content_analysis],
        opportunities: suggestions[:optimization_opportunities]
      }
    rescue => e
      Rails.logger.error "AI suggestion generation failed: #{e.message}"
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
  end

  # POST /content/:content_request_id/variants/duplicate
  def duplicate
    source_variant = @content_request.content_variants.find(params[:source_variant_id])
    
    new_variant = source_variant.dup
    new_variant.name = "#{source_variant.name} (Copy)"
    new_variant.variant_number = @content_request.content_variants.count + 1
    new_variant.performance_data = {}
    
    if new_variant.save
      render json: {
        success: true,
        variant: format_variant_for_response(new_variant),
        message: 'Variant duplicated successfully'
      }
    else
      render json: {
        success: false,
        errors: new_variant.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /content/:content_request_id/variants/bulk_action
  def bulk_action
    variant_ids = params[:variant_ids]&.split(',') || []
    action = params[:action]
    
    case action
    when 'delete'
      @content_request.content_variants.where(id: variant_ids).destroy_all
      message = 'Variants deleted successfully'
    when 'archive'
      @content_request.content_variants.where(id: variant_ids).update_all(status: 'archived')
      message = 'Variants archived successfully'
    when 'activate'
      @content_request.content_variants.where(id: variant_ids).update_all(status: 'active')
      message = 'Variants activated successfully'
    else
      return render json: { success: false, error: 'Invalid action' }, status: :bad_request
    end

    render json: { success: true, message: message }
  end

  private

  def set_content_request
    @content_request = ContentRequest.find(params[:content_request_id])
  end

  def set_variant
    @variant = ContentVariant.find(params[:id])
  end

  def variant_params
    params.require(:variant).permit(:name, :content, :description, :status, :tags, 
                                   :strategy_type, :optimization_goal, :target_audience)
  end

  def initialize_variant_service
    ai_service = AiServiceFactory.create_service(
      service_type: :anthropic,
      context: { user_id: current_user&.id }
    )

    VariantGeneratorService.new(
      ai_service: ai_service,
      original_content: @content_request.content_response&.generated_content,
      context: build_variant_context,
      platform: @content_request.content_type,
      target_audience: @content_request.target_audience
    )
  end

  def initialize_ai_advisor_service
    ai_service = AiServiceFactory.create_service(
      service_type: :anthropic,
      context: { user_id: current_user&.id }
    )

    AiVariantAdvisorService.new(
      ai_service: ai_service,
      performance_data: fetch_performance_data,
      industry_insights: fetch_industry_insights,
      competitive_data: fetch_competitive_data
    )
  end

  def build_variant_context
    {
      brand_context: @content_request.brand_context,
      campaign_goal: @content_request.campaign_goal,
      content_length: @content_request.content_length,
      tone: @content_request.tone,
      platform: @content_request.content_type,
      target_audience: @content_request.target_audience,
      required_elements: @content_request.required_elements,
      restrictions: @content_request.restrictions
    }
  end

  def build_ai_context
    build_variant_context.merge(
      optimization_goal: params[:optimization_goal],
      competitive_analysis: params[:include_competitive_analysis] == 'true',
      audience_segments: params[:audience_segments]&.split(','),
      performance_focus: params[:performance_focus]
    )
  end

  def build_generation_options
    {
      strategies: VariantGeneratorService::VARIANT_STRATEGIES.keys,
      strategy_descriptions: VariantGeneratorService::VARIANT_STRATEGIES.transform_values { |v| v[:description] },
      platform_options: %w[twitter instagram linkedin facebook email google_ads facebook_ads],
      optimization_goals: %w[engagement conversion click_through brand_awareness lead_generation],
      audience_types: %w[general professional casual young_adults business_owners marketers]
    }
  end

  def build_generation_options_from_params
    {
      optimization_goal: params[:optimization_goal],
      quick_generation: params[:quick_generation] == 'true',
      performance_informed: params[:performance_informed] == 'true',
      platform_requirements: params[:platform_requirements],
      audience_focus: params[:audience_focus]
    }
  end

  def save_generated_variants(generation_result)
    variants = []
    
    generation_result[:variants].each do |variant_data|
      variant = @content_request.content_variants.build(
        name: generate_variant_name(variant_data),
        content: variant_data[:content],
        strategy_type: variant_data[:strategy],
        variant_number: variant_data[:variant_number],
        performance_score: variant_data[:performance_score],
        metadata: variant_data[:metadata],
        differences_analysis: variant_data[:differences_from_original],
        tags: variant_data[:tags],
        status: 'draft'
      )
      
      if variant.save
        variants << variant
      else
        Rails.logger.error "Failed to save variant: #{variant.errors.full_messages}"
      end
    end
    
    variants
  end

  def generate_variant_name(variant_data)
    strategy_name = variant_data[:strategy_name] || variant_data[:strategy].to_s.humanize
    "#{strategy_name} - Variant #{variant_data[:variant_number]}"
  end

  def build_comparison_overview(variants)
    return {} if variants.length < 2

    {
      total_variants: variants.length,
      strategy_distribution: variants.group(:strategy_type).count,
      performance_range: {
        highest: variants.maximum(:performance_score) || 0,
        lowest: variants.minimum(:performance_score) || 0,
        average: variants.average(:performance_score)&.round(3) || 0
      },
      content_length_range: {
        shortest: variants.minimum('LENGTH(content)') || 0,
        longest: variants.maximum('LENGTH(content)') || 0,
        average: variants.average('LENGTH(content)')&.round(0) || 0
      }
    }
  end

  def build_detailed_comparison(variants)
    comparison = {
      variants: [],
      side_by_side_analysis: {},
      performance_comparison: {},
      recommendation: nil
    }

    variants.each do |variant|
      comparison[:variants] << {
        id: variant.id,
        name: variant.name,
        content: variant.content,
        strategy: variant.strategy_type,
        performance_score: variant.performance_score,
        length: variant.content.length,
        key_differences: extract_key_differences(variant),
        strengths: identify_variant_strengths(variant),
        weaknesses: identify_variant_weaknesses(variant)
      }
    end

    comparison[:side_by_side_analysis] = generate_side_by_side_analysis(variants)
    comparison[:performance_comparison] = compare_performance_metrics(variants)
    comparison[:recommendation] = generate_comparison_recommendation(variants)

    comparison
  end

  def extract_key_differences(variant)
    return [] unless variant.differences_analysis.present?

    variant.differences_analysis.map do |diff|
      "#{diff['type'].humanize}: #{diff['description']}"
    end
  end

  def identify_variant_strengths(variant)
    strengths = []
    
    # Analyze content for strengths
    content = variant.content
    
    strengths << "Strong call-to-action" if has_strong_cta(content)
    strengths << "Engaging questions" if content.include?('?')
    strengths << "Personal tone" if content.match?(/\b(you|your)\b/i)
    strengths << "Emotional appeal" if has_emotional_language(content)
    strengths << "Specific benefits" if has_specific_benefits(content)
    strengths << "High performance score" if variant.performance_score > 0.7
    
    strengths
  end

  def identify_variant_weaknesses(variant)
    weaknesses = []
    
    content = variant.content
    
    weaknesses << "Weak call-to-action" unless has_strong_cta(content)
    weaknesses << "Too long for platform" if content.length > platform_max_length(variant.content_request.content_type)
    weaknesses << "Too short" if content.length < 50
    weaknesses << "Lacks engagement elements" unless has_engagement_elements(content)
    weaknesses << "Low performance score" if variant.performance_score < 0.5
    
    weaknesses
  end

  def generate_side_by_side_analysis(variants)
    analysis = {}
    
    # Content length comparison
    lengths = variants.map { |v| v.content.length }
    analysis[:length_comparison] = {
      shortest: lengths.min,
      longest: lengths.max,
      difference: lengths.max - lengths.min
    }
    
    # Strategy comparison
    strategies = variants.map(&:strategy_type).uniq
    analysis[:strategy_diversity] = {
      unique_strategies: strategies.length,
      strategies: strategies
    }
    
    # Performance comparison
    scores = variants.map(&:performance_score)
    analysis[:performance_spread] = {
      range: scores.max - scores.min,
      best_performer: variants.find { |v| v.performance_score == scores.max }&.name,
      worst_performer: variants.find { |v| v.performance_score == scores.min }&.name
    }
    
    analysis
  end

  def compare_performance_metrics(variants)
    comparison = {
      predicted_engagement: {},
      predicted_conversion: {},
      overall_ranking: []
    }
    
    variants.each do |variant|
      # Calculate predicted metrics based on performance score
      base_engagement = 0.05
      base_conversion = 0.02
      
      predicted_engagement = base_engagement * variant.performance_score
      predicted_conversion = base_conversion * variant.performance_score
      
      comparison[:predicted_engagement][variant.id] = predicted_engagement.round(4)
      comparison[:predicted_conversion][variant.id] = predicted_conversion.round(4)
    end
    
    # Rank variants by performance score
    comparison[:overall_ranking] = variants.sort_by(&:performance_score).reverse.map do |variant|
      {
        id: variant.id,
        name: variant.name,
        score: variant.performance_score,
        rank: variants.sort_by(&:performance_score).reverse.index(variant) + 1
      }
    end
    
    comparison
  end

  def generate_performance_predictions(variants)
    predictions = {}
    
    variants.each do |variant|
      predictions[variant.id] = {
        engagement_rate: calculate_engagement_prediction(variant),
        click_through_rate: calculate_ctr_prediction(variant),
        conversion_rate: calculate_conversion_prediction(variant),
        confidence_level: calculate_prediction_confidence(variant)
      }
    end
    
    predictions
  end

  def generate_testing_recommendations(variants)
    recommendations = []
    
    if variants.length == 2
      better_variant = variants.max_by(&:performance_score)
      recommendations << "Run A/B test between control and #{better_variant.name}"
      recommendations << "Focus on #{better_variant.strategy_type.humanize} strategy"
    elsif variants.length >= 3
      top_variants = variants.sort_by(&:performance_score).reverse.first(3)
      recommendations << "Run A/B/C test with top 3 performing variants"
      recommendations << "Test strategies: #{top_variants.map(&:strategy_type).join(', ')}"
    end
    
    # Performance-based recommendations
    best_variant = variants.max_by(&:performance_score)
    if best_variant.performance_score > 0.8
      recommendations << "#{best_variant.name} shows high potential - prioritize for testing"
    end
    
    worst_variant = variants.min_by(&:performance_score)
    if worst_variant.performance_score < 0.4
      recommendations << "Consider revising or excluding #{worst_variant.name} from testing"
    end
    
    # Strategy-based recommendations
    strategy_performance = variants.group_by(&:strategy_type)
                                  .transform_values { |vars| vars.sum(&:performance_score) / vars.length }
    
    best_strategy = strategy_performance.max_by { |_, score| score }&.first
    if best_strategy
      recommendations << "#{best_strategy.humanize} strategy shows strongest performance"
    end
    
    recommendations
  end

  def analyze_single_variant(variant)
    {
      content_analysis: {
        word_count: variant.content.split.length,
        character_count: variant.content.length,
        sentence_count: variant.content.split(/[.!?]+/).length,
        readability_score: calculate_readability_score(variant.content),
        sentiment: analyze_sentiment(variant.content)
      },
      performance_analysis: {
        predicted_engagement: calculate_engagement_prediction(variant),
        predicted_ctr: calculate_ctr_prediction(variant),
        predicted_conversion: calculate_conversion_prediction(variant),
        confidence_level: calculate_prediction_confidence(variant)
      },
      strategy_analysis: {
        strategy_type: variant.strategy_type,
        key_elements: extract_strategy_elements(variant),
        effectiveness_score: variant.performance_score
      }
    }
  end

  def generate_improvement_suggestions(variant)
    suggestions = []
    content = variant.content
    
    # Content-based suggestions
    suggestions << "Add compelling questions to increase engagement" unless content.include?('?')
    suggestions << "Strengthen the call-to-action" unless has_strong_cta(content)
    suggestions << "Include specific numbers or statistics" unless content.match?(/\d+/)
    suggestions << "Add emotional language for better connection" unless has_emotional_language(content)
    suggestions << "Optimize length for platform" if content.length > platform_max_length(variant.content_request.content_type)
    
    # Performance-based suggestions
    if variant.performance_score < 0.6
      suggestions << "Consider revising overall strategy - current performance below average"
    end
    
    suggestions
  end

  def format_variants_for_response(variants)
    variants.map { |variant| format_variant_for_response(variant) }
  end

  def format_variant_for_response(variant)
    {
      id: variant.id,
      name: variant.name,
      content: variant.content,
      strategy_type: variant.strategy_type,
      performance_score: variant.performance_score,
      status: variant.status,
      tags: variant.tags,
      created_at: variant.created_at,
      character_count: variant.content.length,
      word_count: variant.content.split.length
    }
  end

  def generate_comparison_recommendation(variants)
    return "No variants to compare" if variants.empty?
    
    best_variant = variants.max_by(&:performance_score)
    score_difference = variants.length > 1 ? 
      best_variant.performance_score - variants.sort_by(&:performance_score)[-2].performance_score : 0
    
    if score_difference > 0.2
      "Clear winner: #{best_variant.name} significantly outperforms others. Recommend for primary testing."
    elsif score_difference > 0.1
      "Moderate leader: #{best_variant.name} shows better performance. Test against control first."
    else
      "Close competition: Multiple variants show similar performance. Run comprehensive A/B test."
    end
  end

  # Helper methods for content analysis
  def has_strong_cta(content)
    cta_patterns = [
      /\b(get started|learn more|sign up|buy now|contact us|try now)\b/i,
      /\b(click|call|visit|download|subscribe)\b/i
    ]
    cta_patterns.any? { |pattern| content.match?(pattern) }
  end

  def has_engagement_elements(content)
    content.include?('?') || 
    content.match?(/\b(you|your|we|us)\b/i) ||
    content.match?(/\b(think|feel|believe)\b/i)
  end

  def has_emotional_language(content)
    emotional_words = %w[amazing incredible fantastic love exciting wonderful]
    content_words = content.downcase.split(/\W+/)
    (content_words & emotional_words).any?
  end

  def has_specific_benefits(content)
    benefit_indicators = %w[save gain get achieve improve increase reduce]
    content_words = content.downcase.split(/\W+/)
    (content_words & benefit_indicators).any?
  end

  def platform_max_length(platform)
    case platform&.to_sym
    when :twitter then 280
    when :instagram then 2200
    when :linkedin then 3000
    when :facebook then 63206
    else 1000
    end
  end

  def calculate_engagement_prediction(variant)
    base_rate = 0.05
    (base_rate * variant.performance_score).round(4)
  end

  def calculate_ctr_prediction(variant)
    base_rate = 0.02
    (base_rate * variant.performance_score).round(4)
  end

  def calculate_conversion_prediction(variant)
    base_rate = 0.01
    (base_rate * variant.performance_score).round(4)
  end

  def calculate_prediction_confidence(variant)
    # Higher performance scores generally have higher confidence
    base_confidence = 0.6
    score_boost = variant.performance_score * 0.3
    [base_confidence + score_boost, 0.95].min
  end

  def calculate_readability_score(content)
    sentences = content.split(/[.!?]+/).reject(&:blank?)
    words = content.split(/\W+/).reject(&:blank?)
    
    return 0.5 if sentences.empty? || words.empty?
    
    avg_sentence_length = words.length.to_f / sentences.length
    # Ideal sentence length is around 15-20 words
    if avg_sentence_length.between?(15, 20)
      1.0
    else
      1.0 - [(avg_sentence_length - 17.5).abs / 17.5, 1.0].min
    end
  end

  def analyze_sentiment(content)
    positive_words = %w[great amazing excellent wonderful fantastic love excited happy]
    negative_words = %w[bad terrible awful horrible disappointing sad angry]
    neutral_words = %w[okay fine alright decent average]
    
    content_words = content.downcase.split(/\W+/)
    
    positive_count = (content_words & positive_words).length
    negative_count = (content_words & negative_words).length
    neutral_count = (content_words & neutral_words).length
    
    if positive_count > negative_count && positive_count > neutral_count
      'positive'
    elsif negative_count > positive_count && negative_count > neutral_count
      'negative'
    else
      'neutral'
    end
  end

  def extract_strategy_elements(variant)
    content = variant.content
    elements = []
    
    case variant.strategy_type&.to_sym
    when :tone_variation
      elements << "Tone: #{analyze_tone(content)}"
    when :cta_variation
      elements << "CTA: #{extract_cta(content)}"
    when :length_variation
      elements << "Length: #{content.length} characters"
    when :headline_variation
      first_sentence = content.split(/[.!?]+/).first
      elements << "Headline: #{first_sentence&.strip}"
    end
    
    elements
  end

  def analyze_tone(content)
    if content.match?(/\b(professional|expertise|solution)\b/i)
      'professional'
    elsif content.match?(/\b(awesome|cool|amazing|love)\b/i)
      'casual'
    elsif content.match?(/\b(urgent|now|limited|hurry)\b/i)
      'urgent'
    else
      'neutral'
    end
  end

  def extract_cta(content)
    cta_patterns = [
      /\b(learn more|get started|sign up|contact us|buy now|try now)\b/i,
      /\b(click|call|visit|download)\b/i
    ]
    
    cta_patterns.each do |pattern|
      match = content.match(pattern)
      return match.to_s if match
    end
    
    'No clear CTA'
  end

  def fetch_ai_suggestions(content)
    return [] unless content.present?
    
    begin
      advisor_service = initialize_ai_advisor_service
      suggestions = advisor_service.generate_intelligent_suggestions(content, build_ai_context)
      suggestions[:suggested_variants] || []
    rescue => e
      Rails.logger.error "Failed to fetch AI suggestions: #{e.message}"
      []
    end
  end

  def fetch_performance_data
    # Fetch historical performance data for the current user/brand
    {}
  end

  def fetch_industry_insights
    # Fetch industry-specific insights
    { industry_name: @content_request&.brand_context&.dig('industry') }
  end

  def fetch_competitive_data
    # Fetch competitive analysis data
    {}
  end
end