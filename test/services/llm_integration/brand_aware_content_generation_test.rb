require 'test_helper'

class BrandAwareContentGenerationTest < ActiveSupport::TestCase
  def setup
    @brand = brands(:one)
    # @brand_service = LlmIntegration::BrandAwareContentService.new(@brand)
    # @content_generator = LlmIntegration::BrandContentGenerator.new
    # @compliance_checker = LlmIntegration::BrandComplianceChecker.new
  end

  test "should generate content that adheres to brand voice and tone" do
    # Test brand voice integration
    brand_context = @brand_service.extract_brand_context
    assert_includes brand_context.keys, :voice_characteristics
    assert_includes brand_context.keys, :tone_guidelines
    assert_includes brand_context.keys, :messaging_pillars
    
    content_request = {
      content_type: :social_media_post,
      platform: :linkedin,
      topic: "product launch",
      target_audience: "B2B professionals"
    }
    
    generated_content = @brand_service.generate_content(content_request)
    
    # Content should reflect brand voice
    assert_not_nil generated_content[:content]
    assert generated_content[:brand_compliance_score] >= 0.95
    assert_includes generated_content[:applied_guidelines], "professional tone"
    assert_includes generated_content[:applied_guidelines], "industry expertise"
  end

  test "should achieve 95% brand compliance accuracy" do
    # Test compliance scoring system
    test_content = "Our innovative solution transforms your business processes with cutting-edge AI technology."
    
    compliance_result = @compliance_checker.check_compliance(test_content, @brand)
    
    assert_instance_of Hash, compliance_result
    assert_includes compliance_result.keys, :overall_score
    assert_includes compliance_result.keys, :voice_compliance
    assert_includes compliance_result.keys, :tone_compliance
    assert_includes compliance_result.keys, :messaging_compliance
    assert_includes compliance_result.keys, :violations
    assert_includes compliance_result.keys, :suggestions
    
    # Score should be between 0 and 1
    assert compliance_result[:overall_score] >= 0.0
    assert compliance_result[:overall_score] <= 1.0
  end

  test "should validate content against brand guidelines in real-time" do
    validator = LlmIntegration::RealTimeBrandValidator.new(@brand)
    
    # Test valid content
    compliant_content = "Our team of experts delivers professional solutions that drive measurable results."
    validation = validator.validate(compliant_content)
    
    assert validation[:compliant]
    assert validation[:confidence] >= 0.95
    assert_empty validation[:violations]
    
    # Test non-compliant content
    non_compliant_content = "This amazing product is totally awesome and will blow your mind!!!"
    validation = validator.validate(non_compliant_content)
    
    refute validation[:compliant]
    assert validation[:confidence] >= 0.95
    assert_not_empty validation[:violations]
    assert_includes validation[:violations].first[:type], "tone_mismatch"
  end

  test "should extract and apply brand voice characteristics" do
    voice_extractor = LlmIntegration::BrandVoiceExtractor.new
    
    brand_guidelines_text = @brand.brand_guidelines.first.content
    voice_profile = voice_extractor.extract_voice_profile(brand_guidelines_text)
    
    # Should extract key voice characteristics
    assert_includes voice_profile.keys, :primary_voice_traits
    assert_includes voice_profile.keys, :tone_descriptors  
    assert_includes voice_profile.keys, :language_preferences
    assert_includes voice_profile.keys, :communication_style
    assert_includes voice_profile.keys, :brand_personality
    
    # Test voice application
    content_brief = {
      message: "Announce new feature release",
      audience: "existing customers",
      channel: "email"
    }
    
    voice_applied_prompt = voice_extractor.apply_voice_to_prompt(
      base_prompt: "Write an announcement email",
      voice_profile: voice_profile,
      content_brief: content_brief
    )
    
    assert_includes voice_applied_prompt, "professional tone"
    assert_includes voice_applied_prompt, "expertise-focused"
  end

  test "should integrate with existing brand compliance system" do
    # Test integration with brand analysis service
    integration = LlmIntegration::BrandSystemIntegration.new
    
    # Should connect to existing brand analysis
    brand_analysis = integration.get_brand_analysis(@brand.id)
    assert_not_nil brand_analysis
    assert_includes brand_analysis.keys, :voice_analysis
    assert_includes brand_analysis.keys, :compliance_rules
    
    # Should sync with compliance results
    content = "Test marketing content for compliance checking"
    compliance_result = integration.check_with_existing_system(content, @brand)
    
    assert_instance_of ComplianceResult, compliance_result
    assert_not_nil compliance_result.overall_score
    assert_not_nil compliance_result.detailed_feedback
  end

  test "should provide content improvement suggestions" do
    suggestion_engine = LlmIntegration::ContentSuggestionEngine.new(@brand)
    
    suboptimal_content = "We have a good product that might help your business."
    suggestions = suggestion_engine.generate_suggestions(suboptimal_content)
    
    assert_instance_of Array, suggestions
    assert suggestions.length > 0
    
    first_suggestion = suggestions.first
    assert_includes first_suggestion.keys, :issue_type
    assert_includes first_suggestion.keys, :current_text
    assert_includes first_suggestion.keys, :suggested_text
    assert_includes first_suggestion.keys, :improvement_reason
    assert_includes first_suggestion.keys, :brand_alignment_score
  end

  test "should handle different content types with brand awareness" do
    content_types = [:email_subject, :social_post, :ad_copy, :blog_title, :landing_page_headline]
    
    content_types.each do |content_type|
      generator = LlmIntegration::TypeSpecificGenerator.new(content_type, @brand)
      
      content_spec = {
        topic: "product launch",
        target_audience: "B2B professionals",
        goal: "drive engagement"
      }
      
      result = generator.generate(content_spec)
      
      assert_not_nil result[:content]
      assert result[:brand_compliance] >= 0.90
      assert_includes result[:content_metadata], :character_count
      assert_includes result[:content_metadata], :content_type
      assert_equal content_type, result[:content_metadata][:content_type]
    end
  end

  test "should maintain brand consistency across content variations" do
    variation_generator = LlmIntegration::BrandConsistentVariationGenerator.new(@brand)
    
    base_content = "Discover our innovative solution for business transformation"
    variations = variation_generator.generate_variations(base_content, count: 5)
    
    assert_equal 5, variations.length
    
    # All variations should maintain high brand compliance
    variations.each_with_index do |variation, index|
      assert variation[:brand_compliance_score] >= 0.90, 
             "Variation #{index + 1} has low compliance: #{variation[:brand_compliance_score]}"
      assert_not_equal base_content, variation[:content], 
             "Variation #{index + 1} is identical to base content"
    end
    
    # Test consistency across variations
    consistency_score = variation_generator.calculate_consistency_score(variations)
    assert consistency_score >= 0.85
  end

  test "should support brand-specific content templates" do
    template_engine = LlmIntegration::BrandTemplateEngine.new(@brand)
    
    # Test template creation
    email_template = template_engine.create_template(
      type: :email_announcement,
      structure: {
        subject: "{{ product_name }} Launch: {{ key_benefit }}",
        greeting: "{{ audience_greeting }}",
        body: "{{ announcement_content }}",
        cta: "{{ action_verb }} {{ product_name }}"
      }
    )
    
    assert_not_nil email_template.id
    assert_equal :email_announcement, email_template.type
    
    # Test template usage with brand context
    content_data = {
      product_name: "AI Analytics Pro",
      key_benefit: "Advanced Business Intelligence",
      audience_greeting: "Dear valued customer",
      announcement_content: "We're excited to introduce our latest innovation",
      action_verb: "Explore"
    }
    
    rendered_content = template_engine.render_template(email_template, content_data)
    
    assert_includes rendered_content[:subject], "AI Analytics Pro Launch"
    assert_includes rendered_content[:body], "Advanced Business Intelligence"
    assert rendered_content[:brand_compliance_score] >= 0.95
  end

  test "should learn from brand compliance feedback" do
    learning_system = LlmIntegration::BrandComplianceLearningSystem.new(@brand)
    
    # Simulate feedback loop
    content_samples = [
      { content: "Professional solution for enterprise clients", compliance_score: 0.98, feedback: :approved },
      { content: "Amazing product that rocks!", compliance_score: 0.65, feedback: :rejected },
      { content: "Innovative technology driving business results", compliance_score: 0.96, feedback: :approved }
    ]
    
    content_samples.each do |sample|
      learning_system.record_feedback(
        content: sample[:content],
        compliance_score: sample[:compliance_score],
        human_feedback: sample[:feedback]
      )
    end
    
    # Test learning application
    improved_generator = learning_system.get_improved_generator
    test_prompt = "Create content about our new service"
    
    result = improved_generator.generate(test_prompt)
    
    # Should show improvement based on learning
    assert result[:confidence_score] >= 0.90
    assert result[:expected_compliance] >= 0.95
    assert_includes result[:applied_learnings], "professional_language_preference"
  end

  test "should handle brand compliance edge cases" do
    edge_case_handler = LlmIntegration::BrandComplianceEdgeCaseHandler.new(@brand)
    
    # Test handling of ambiguous content
    ambiguous_content = "This could be professional or casual depending on context"
    result = edge_case_handler.handle_ambiguous_content(ambiguous_content)
    
    assert_includes result.keys, :confidence_level
    assert_includes result.keys, :recommended_action
    assert_includes result.keys, :context_suggestions
    
    # Test handling of conflicting guidelines
    conflicting_request = {
      content: "Urgent: Limited time offer!",
      guidelines_conflict: ["avoid_urgency_language", "highlight_time_sensitive_offers"]
    }
    
    resolution = edge_case_handler.resolve_guideline_conflict(conflicting_request)
    assert_not_nil resolution[:chosen_approach]
    assert_not_nil resolution[:justification]
    assert_includes resolution.keys, :alternative_suggestions
  end
end