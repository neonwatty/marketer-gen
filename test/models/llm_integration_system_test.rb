require 'test_helper'

class LlmIntegrationSystemTest < ActiveSupport::TestCase
  def setup
    @brand = brands(:one)
    @user = users(:one)
  end

  test "LlmProvider model should manage multiple AI providers" do
    # Test LlmProvider model (would need to be created)
    provider = LlmIntegration::LlmProvider.new(
      name: "OpenAI",
      provider_type: :openai,
      api_endpoint: "https://api.openai.com/v1/chat/completions",
      supported_models: ["gpt-4-turbo", "gpt-3.5-turbo"],
      rate_limits: { requests_per_minute: 60, tokens_per_minute: 40000 },
      active: true
    )
    
    assert provider.valid?
    
    # Test validations
    provider.name = nil
    refute provider.valid?
    assert_includes provider.errors[:name], "can't be blank"
    
    provider.name = "OpenAI"
    provider.provider_type = :invalid_type
    refute provider.valid?
    assert_includes provider.errors[:provider_type], "is not included in the list"
    
    # Test rate limit validation
    provider.provider_type = :openai
    provider.rate_limits = { requests_per_minute: -1 }
    refute provider.valid?
    assert_includes provider.errors[:rate_limits], "requests_per_minute must be positive"
  end

  test "ContentGenerationRequest model should track generation requests" do
    request = LlmIntegration::ContentGenerationRequest.new(
      brand: @brand,
      user: @user,
      content_type: :email_subject,
      prompt_template: "Generate an email subject for {{product_name}}",
      prompt_variables: { product_name: "AI Analytics Pro" },
      provider_preference: :openai,
      status: :pending,
      priority: :medium
    )
    
    assert request.valid?
    
    # Test relationships
    assert_equal @brand, request.brand
    assert_equal @user, request.user
    
    # Test status transitions
    assert request.pending?
    
    request.status = :processing
    assert request.processing?
    
    request.status = :completed
    assert request.completed?
    
    # Test priority levels
    assert_includes LlmIntegration::ContentGenerationRequest::PRIORITIES, :high
    assert_includes LlmIntegration::ContentGenerationRequest::PRIORITIES, :medium
    assert_includes LlmIntegration::ContentGenerationRequest::PRIORITIES, :low
    
    # Test content type validation
    valid_types = [:email_subject, :email_body, :social_post, :ad_copy, :landing_page_headline]
    valid_types.each do |type|
      request.content_type = type
      assert request.valid?, "#{type} should be valid content type"
    end
  end

  test "GeneratedContent model should store LLM outputs with metadata" do
    generation_request = LlmIntegration::ContentGenerationRequest.create!(
      brand: @brand,
      user: @user,
      content_type: :social_post,
      prompt_template: "Create a LinkedIn post about {{topic}}",
      prompt_variables: { topic: "AI innovation" },
      status: :pending
    )
    
    generated_content = LlmIntegration::GeneratedContent.new(
      content_generation_request: generation_request,
      brand: @brand,
      content: "Exciting developments in AI are transforming how businesses operate.",
      provider_used: :openai,
      model_used: "gpt-4-turbo",
      tokens_used: 45,
      generation_time: 2.3,
      brand_compliance_score: 0.96,
      quality_score: 0.89,
      metadata: {
        optimization_strategy: "professional_tone",
        target_audience: "B2B professionals",
        sentiment_score: 0.7
      }
    )
    
    assert generated_content.valid?
    
    # Test relationships
    assert_equal generation_request, generated_content.content_generation_request
    assert_equal @brand, generated_content.brand
    
    # Test score validations
    generated_content.brand_compliance_score = 1.5
    refute generated_content.valid?
    assert_includes generated_content.errors[:brand_compliance_score], "must be between 0 and 1"
    
    generated_content.brand_compliance_score = -0.1
    refute generated_content.valid?
    assert_includes generated_content.errors[:brand_compliance_score], "must be between 0 and 1"
    
    # Test metadata JSON validation
    generated_content.brand_compliance_score = 0.96
    generated_content.metadata = "invalid json"
    refute generated_content.valid?
    assert_includes generated_content.errors[:metadata], "must be valid JSON"
  end

  test "ContentVariant model should support A/B testing integration" do
    base_content = LlmIntegration::GeneratedContent.create!(
      brand: @brand,
      content: "Transform your business with AI analytics",
      provider_used: :openai,
      brand_compliance_score: 0.95,
      quality_score: 0.90
    )
    
    variant = LlmIntegration::ContentVariant.new(
      base_content: base_content,
      variant_content: "Revolutionize your operations with intelligent analytics",
      variant_type: :headline_optimization,
      optimization_strategy: "power_word_enhancement",
      predicted_performance_lift: 0.15,
      ab_test_id: "test_123",
      variant_letter: "B"
    )
    
    assert variant.valid?
    
    # Test relationship
    assert_equal base_content, variant.base_content
    
    # Test variant type validation
    valid_types = [:headline_optimization, :tone_adjustment, :length_optimization, :cta_optimization]
    valid_types.each do |type|
      variant.variant_type = type
      assert variant.valid?, "#{type} should be valid variant type"
    end
    
    # Test performance lift validation
    variant.predicted_performance_lift = 2.0
    refute variant.valid?
    assert_includes variant.errors[:predicted_performance_lift], "must be between -1 and 1"
  end

  test "PromptTemplate model should manage reusable prompt structures" do
    template = LlmIntegration::PromptTemplate.new(
      name: "Product Launch Email Subject",
      content_type: :email_subject,
      template_content: "Introducing {{product_name}}: {{key_benefit}} for {{target_audience}}",
      variables: {
        product_name: { type: "string", required: true, max_length: 50 },
        key_benefit: { type: "string", required: true, max_length: 100 },
        target_audience: { type: "string", required: true }
      },
      brand_id: @brand.id,
      category: "product_launch",
      performance_rating: 4.2,
      usage_count: 0,
      active: true
    )
    
    assert template.valid?
    
    # Test variable validation
    template.variables = { invalid: "structure" }
    refute template.valid?
    assert_includes template.errors[:variables], "must define type for each variable"
    
    # Test template content validation
    template.variables = { product_name: { type: "string", required: true } }
    template.template_content = "Missing variable reference"
    refute template.valid?
    assert_includes template.errors[:template_content], "must reference all defined variables"
    
    # Test performance rating validation
    template.template_content = "Introducing {{product_name}}"
    template.performance_rating = 6.0
    refute template.valid?
    assert_includes template.errors[:performance_rating], "must be between 0 and 5"
  end

  test "BrandVoiceProfile model should store extracted brand characteristics" do
    voice_profile = LlmIntegration::BrandVoiceProfile.new(
      brand: @brand,
      voice_characteristics: {
        primary_traits: ["professional", "innovative", "trustworthy"],
        tone_descriptors: ["confident", "approachable", "expert"],
        communication_style: "direct_yet_friendly",
        brand_personality: "thought_leader"
      },
      extracted_from_sources: ["brand_guidelines", "website_content", "marketing_materials"],
      confidence_score: 0.87,
      last_updated: Time.current,
      version: 1
    )
    
    assert voice_profile.valid?
    
    # Test relationship
    assert_equal @brand, voice_profile.brand
    
    # Test confidence score validation
    voice_profile.confidence_score = 1.5
    refute voice_profile.valid?
    assert_includes voice_profile.errors[:confidence_score], "must be between 0 and 1"
    
    # Test voice characteristics structure
    voice_profile.confidence_score = 0.87
    voice_profile.voice_characteristics = { invalid: "structure" }
    refute voice_profile.valid?
    assert_includes voice_profile.errors[:voice_characteristics], "must include primary_traits"
    
    # Test version incrementing
    voice_profile.voice_characteristics = {
      primary_traits: ["professional"],
      tone_descriptors: ["confident"],
      communication_style: "direct",
      brand_personality: "expert"
    }
    
    assert voice_profile.valid?
    initial_version = voice_profile.version
    
    voice_profile.update_voice_profile({ primary_traits: ["professional", "innovative"] })
    assert_equal initial_version + 1, voice_profile.version
  end

  test "ContentOptimizationResult model should track optimization outcomes" do
    original_content = LlmIntegration::GeneratedContent.create!(
      brand: @brand,
      content: "Our solution helps businesses",
      provider_used: :openai,
      brand_compliance_score: 0.75,
      quality_score: 0.70
    )
    
    optimization_result = LlmIntegration::ContentOptimizationResult.new(
      original_content: original_content,
      optimized_content: "Our innovative platform transforms business operations",
      optimization_type: :quality_improvement,
      optimization_strategy: "specificity_enhancement",
      performance_improvement: {
        quality_score_delta: 0.15,
        brand_compliance_delta: 0.12,
        predicted_engagement_lift: 0.08
      },
      applied_techniques: ["power_words", "specificity", "active_voice"],
      optimization_time: 1.8,
      human_approved: false
    )
    
    assert optimization_result.valid?
    
    # Test relationship
    assert_equal original_content, optimization_result.original_content
    
    # Test optimization type validation
    valid_types = [:quality_improvement, :brand_alignment, :performance_optimization, :audience_targeting]
    valid_types.each do |type|
      optimization_result.optimization_type = type
      assert optimization_result.valid?, "#{type} should be valid optimization type"
    end
    
    # Test performance improvement structure
    optimization_result.performance_improvement = { invalid: "structure" }
    refute optimization_result.valid?
    assert_includes optimization_result.errors[:performance_improvement], "must include quality_score_delta"
  end

  test "ConversationSession model should manage campaign intake conversations" do
    session = LlmIntegration::ConversationSession.new(
      user: @user,
      brand: @brand,
      session_type: :campaign_setup,
      status: :active,
      context: {
        discussed_topics: ["campaign_type", "target_audience"],
        extracted_requirements: {
          campaign_type: "product_launch",
          budget_range: [5000, 10000]
        },
        conversation_stage: "gathering_requirements"
      },
      started_at: Time.current,
      last_activity_at: Time.current
    )
    
    assert session.valid?
    
    # Test relationships
    assert_equal @user, session.user
    assert_equal @brand, session.brand
    
    # Test status transitions
    assert session.active?
    
    session.status = :completed
    assert session.completed?
    
    session.status = :abandoned
    assert session.abandoned?
    
    # Test session timeout
    session.last_activity_at = 2.hours.ago
    assert session.expired?
    
    # Test context management
    session.add_to_context(:budget_confirmed, true)
    assert session.context[:budget_confirmed]
    
    extracted_req = session.extract_requirements
    assert_equal "product_launch", extracted_req[:campaign_type]
    assert_equal [5000, 10000], extracted_req[:budget_range]
  end

  test "ContentPerformanceMetric model should track content effectiveness" do
    generated_content = LlmIntegration::GeneratedContent.create!(
      brand: @brand,
      content: "Professional analytics platform for enterprises",
      provider_used: :openai,
      brand_compliance_score: 0.94,
      quality_score: 0.88
    )
    
    performance_metric = LlmIntegration::ContentPerformanceMetric.new(
      generated_content: generated_content,
      metric_type: :email_open_rate,
      metric_value: 0.28,
      sample_size: 1500,
      measurement_period: 7.days,
      channel: :email,
      audience_segment: "enterprise_decision_makers",
      recorded_at: Time.current
    )
    
    assert performance_metric.valid?
    
    # Test relationship
    assert_equal generated_content, performance_metric.generated_content
    
    # Test metric type validation
    valid_types = [:email_open_rate, :click_through_rate, :conversion_rate, :engagement_rate, :bounce_rate]
    valid_types.each do |type|
      performance_metric.metric_type = type
      assert performance_metric.valid?, "#{type} should be valid metric type"
    end
    
    # Test metric value validation (should be between 0 and 1 for rates)
    rate_metrics = [:email_open_rate, :click_through_rate, :conversion_rate]
    rate_metrics.each do |metric|
      performance_metric.metric_type = metric
      performance_metric.metric_value = 1.5
      refute performance_metric.valid?
      assert_includes performance_metric.errors[:metric_value], "must be between 0 and 1 for rate metrics"
    end
    
    # Test sample size validation
    performance_metric.metric_type = :email_open_rate
    performance_metric.metric_value = 0.28
    performance_metric.sample_size = 0
    refute performance_metric.valid?
    assert_includes performance_metric.errors[:sample_size], "must be greater than 0"
  end

  test "LlmProviderApiKey model should securely manage API credentials" do
    api_key = LlmIntegration::LlmProviderApiKey.new(
      provider_name: :openai,
      key_name: "primary_key",
      encrypted_api_key: "encrypted_key_value",
      key_permissions: ["chat:completions", "models:list"],
      usage_quota: { monthly_requests: 10000, monthly_tokens: 1000000 },
      expires_at: 1.year.from_now,
      active: true,
      last_used_at: nil
    )
    
    assert api_key.valid?
    
    # Test provider name validation
    valid_providers = [:openai, :anthropic, :cohere, :huggingface]
    valid_providers.each do |provider|
      api_key.provider_name = provider
      assert api_key.valid?, "#{provider} should be valid provider"
    end
    
    # Test key rotation
    old_key = api_key.encrypted_api_key
    api_key.rotate_key("new_encrypted_key_value")
    
    assert_not_equal old_key, api_key.encrypted_api_key
    assert_equal "new_encrypted_key_value", api_key.encrypted_api_key
    
    # Test expiration checking
    api_key.expires_at = 1.day.ago
    assert api_key.expired?
    
    api_key.expires_at = 7.days.from_now
    assert api_key.expires_soon?(within: 30.days)
    refute api_key.expires_soon?(within: 3.days)
    
    # Test usage tracking
    api_key.record_usage(requests: 5, tokens: 1200)
    assert_equal 5, api_key.current_usage[:requests]
    assert_equal 1200, api_key.current_usage[:tokens]
    
    # Test quota checking
    api_key.usage_quota = { monthly_requests: 10, monthly_tokens: 1000 }
    api_key.record_usage(requests: 15, tokens: 1500)
    
    assert api_key.quota_exceeded?(:requests)
    assert api_key.quota_exceeded?(:tokens)
  end
end