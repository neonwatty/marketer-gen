require "test_helper"

class Branding::AnalysisServiceTest < ActiveSupport::TestCase
  def setup
    @brand = brands(:one)
    @service = Branding::AnalysisService.new(@brand)
  end

  test "initialize with default options" do
    assert_equal @brand, @service.brand
    assert_not_nil @service.content
  end

  test "initialize with custom content" do
    custom_content = "Custom brand content"
    service = Branding::AnalysisService.new(@brand, custom_content)
    assert_equal custom_content, service.content
  end

  test "analyze returns error for insufficient content" do
    service = Branding::AnalysisService.new(@brand, "")
    result = service.analyze
    
    assert_not result[:success]
    assert_includes result[:error], "Insufficient content"
  end

  test "analyze creates brand analysis record" do
    # Create some brand assets with content
    @brand.brand_assets.create!(
      asset_type: 'style_guide',
      extracted_text: 'A' * 200,  # Minimum content length
      processing_status: 'processed'
    )
    
    assert_difference 'BrandAnalysis.count', 1 do
      result = @service.analyze
      assert result[:success]
      assert_not_nil result[:analysis_id]
    end
  end

  test "chunk_content handles small content" do
    service = Branding::AnalysisService.new(@brand, "Small content")
    chunks = service.send(:chunk_content, "Small content")
    
    assert_equal 1, chunks.size
    assert_equal "Small content", chunks.first
  end

  test "chunk_content splits large content" do
    large_content = "This is a sentence. " * 500  # Create large content
    service = Branding::AnalysisService.new(@brand, large_content)
    chunks = service.send(:chunk_content, large_content)
    
    assert chunks.size > 1
    chunks.each do |chunk|
      assert chunk.length <= Branding::AnalysisService::CHUNK_SIZE
    end
  end

  test "aggregate_brand_content prioritizes by asset type" do
    # Create assets with different priorities
    @brand.brand_assets.create!(
      asset_type: 'style_guide',
      extracted_text: 'Style guide content',
      processing_status: 'processed',
      metadata: { 'filename' => 'style.pdf' }
    )
    
    @brand.brand_assets.create!(
      asset_type: 'marketing_material',
      extracted_text: 'Marketing content',
      processing_status: 'processed',
      metadata: { 'filename' => 'brochure.pdf' }
    )
    
    @brand.brand_assets.create!(
      asset_type: 'website',
      extracted_text: 'Website content',
      processing_status: 'processed',
      metadata: { 'filename' => 'homepage.html' }
    )
    
    content = @service.send(:aggregate_brand_content)
    
    # Check that style guide appears before marketing material
    assert content.index('Style guide content') < content.index('Marketing content')
    assert content.index('Marketing content') < content.index('Website content')
  end

  test "determine_best_provider selects appropriate LLM" do
    # Test with different API key configurations
    service = Branding::AnalysisService.new(@brand)
    
    # Mock environment variables
    ENV.stubs(:[]).returns(nil)
    
    provider = service.send(:determine_best_provider)
    assert_equal 'gpt-3.5-turbo', provider  # Fallback
  end

  test "default_voice_attributes returns valid structure" do
    service = Branding::AnalysisService.new(@brand)
    attrs = service.send(:default_voice_attributes)
    
    assert attrs[:formality]
    assert attrs[:energy]
    assert attrs[:warmth]
    assert attrs[:authority]
    assert attrs[:tone]
    assert attrs[:style]
    assert_equal [], attrs[:personality_traits]
  end

  test "validate_dimension handles invalid data" do
    service = Branding::AnalysisService.new(@brand)
    
    # Test with nil
    result = service.send(:validate_dimension, nil, 'formality')
    assert_equal 'neutral', result[:level]
    assert_equal 0.5, result[:score]
    
    # Test with invalid level
    invalid_data = { 'level' => 'invalid', 'score' => 0.8 }
    result = service.send(:validate_dimension, invalid_data, 'formality')
    assert_equal 'neutral', result[:level]  # Falls back to middle value
    assert_equal 0.8, result[:score]
  end

  test "calculate_content_volume_score scales with content" do
    service = Branding::AnalysisService.new(@brand)
    
    # Test different content volumes
    service.instance_variable_set(:@content, 'word ' * 100)
    assert service.send(:calculate_content_volume_score) < 0.5
    
    service.instance_variable_set(:@content, 'word ' * 1000)
    score1 = service.send(:calculate_content_volume_score)
    
    service.instance_variable_set(:@content, 'word ' * 5000)
    score2 = service.send(:calculate_content_volume_score)
    
    assert score2 > score1  # More content = higher score
  end

  test "cross_validate_findings detects inconsistencies" do
    service = Branding::AnalysisService.new(@brand)
    
    # Create conflicting data
    voice_attrs = {
      formality: { level: 'very_casual', score: 0.9 },
      tone: { primary: 'playful', secondary: ['casual'] }
    }
    
    guidelines = {
      voice_tone_rules: {
        must_do: ['Maintain formal, professional tone'],
        must_not_do: ['Use casual language']
      }
    }
    
    brand_vals = [{ name: 'Innovation', score: 0.8 }]
    messaging_pillars = { pillars: [] }
    
    validated = service.send(:cross_validate_findings, voice_attrs, brand_vals, messaging_pillars, guidelines)
    
    assert validated[:validation_results][:voice_guideline_alignment][:score] < 0.7
    assert validated[:validation_results][:voice_guideline_alignment][:misalignments].any?
  end

  test "aggregate_brand_values combines and ranks values" do
    service = Branding::AnalysisService.new(@brand)
    
    chunk_values = [
      {
        explicit_values: [
          { value: 'Innovation', evidence: 'We innovate', strength: 0.9 }
        ],
        implied_values: [
          { value: 'Quality', evidence: 'High standards', strength: 0.7 }
        ]
      },
      {
        explicit_values: [
          { value: 'Innovation', evidence: 'Leading innovation', strength: 0.95 }
        ],
        behavioral_values: [
          { value: 'Sustainability', evidence: 'Green practices', strength: 0.8 }
        ]
      }
    ]
    
    result = service.send(:aggregate_brand_values, chunk_values)
    
    assert result.is_a?(Array)
    assert result.first[:name] == 'Innovation'  # Most frequent
    assert result.first[:frequency] == 2
    assert result.first[:type] == :explicit
  end

  test "detect_rule_conflicts identifies contradictions" do
    service = Branding::AnalysisService.new(@brand)
    
    aggregated = {
      voice_tone_rules: {
        must_do: ['Use formal language in all communications'],
        must_not_do: ['Never use formal or stiff language']
      }
    }
    
    conflicts = service.send(:detect_rule_conflicts, aggregated)
    
    assert conflicts.any?
    assert_equal :voice_tone_rules, conflicts.first[:category]
    assert_equal 'direct_contradiction', conflicts.first[:type]
  end

  test "perform_analysis completes full analysis workflow" do
    skip "Requires mocked LLM responses"
    
    # This would require extensive mocking of LLM service
    # In a real test suite, you'd mock the llm_service responses
  end

  # Enhanced AI Processing Tests (FAILING - TDD RED PHASE)
  
  test "should achieve 95% extraction accuracy with comprehensive content" do
    # This test will fail until we implement accuracy improvements
    comprehensive_content = create_comprehensive_brand_content
    service = Branding::AnalysisService.new(@brand, comprehensive_content)
    
    result = service.analyze_with_accuracy_tracking
    
    assert result[:success]
    assert result[:accuracy_metrics][:overall_accuracy] >= 0.95
    assert result[:accuracy_metrics][:voice_accuracy] >= 0.95
    assert result[:accuracy_metrics][:visual_accuracy] >= 0.95
    assert result[:accuracy_metrics][:rule_accuracy] >= 0.95
  end

  test "should extract brand characteristics with confidence scoring" do
    # This test will fail until we implement confidence scoring
    service = Branding::AnalysisService.new(@brand)
    
    @brand.brand_assets.create!(
      asset_type: 'comprehensive_guide',
      extracted_text: create_comprehensive_brand_content,
      processing_status: 'processed'
    )
    
    result = service.extract_with_confidence
    
    assert result[:success]
    assert result[:confidence_scores][:voice_extraction] >= 0.8
    assert result[:confidence_scores][:brand_values] >= 0.8
    assert result[:confidence_scores][:visual_guidelines] >= 0.8
    assert result[:confidence_scores][:messaging_pillars] >= 0.8
    assert result[:overall_confidence] >= 0.85
  end

  test "should perform multi-pass analysis for accuracy" do
    # This test will fail until we implement multi-pass analysis
    service = Branding::AnalysisService.new(@brand)
    
    @brand.brand_assets.create!(
      asset_type: 'style_guide',
      extracted_text: create_comprehensive_brand_content,
      processing_status: 'processed'
    )
    
    result = service.multi_pass_analysis
    
    assert result[:success]
    assert result[:analysis_passes] >= 2
    assert result[:consistency_score] >= 0.9
    assert result[:validation_results][:cross_validation_passed]
  end

  test "should validate extraction against known benchmarks" do
    # This test will fail until we implement benchmark validation
    service = Branding::AnalysisService.new(@brand)
    
    # Use known benchmark content with expected results
    benchmark_content = create_benchmark_brand_content
    expected_results = get_benchmark_expected_results
    
    result = service.analyze_against_benchmark(benchmark_content, expected_results)
    
    assert result[:success]
    assert result[:benchmark_score] >= 0.95
    assert result[:accuracy_by_category][:voice] >= 0.95
    assert result[:accuracy_by_category][:visual] >= 0.95
    assert result[:accuracy_by_category][:messaging] >= 0.95
  end

  test "should handle complex brand guidelines with nested rules" do
    # This test will fail until we implement complex rule parsing
    complex_content = create_complex_nested_guidelines
    service = Branding::AnalysisService.new(@brand, complex_content)
    
    result = service.analyze_complex_structure
    
    assert result[:success]
    assert result[:extracted_rules][:nested_voice_rules].present?
    assert result[:extracted_rules][:conditional_guidelines].present?
    assert result[:extracted_rules][:context_specific_rules].present?
    assert result[:rule_hierarchy].present?
  end

  test "should integrate real-time compliance checking" do
    # This test will fail until we implement real-time checking
    service = Branding::AnalysisService.new(@brand)
    
    @brand.brand_assets.create!(
      asset_type: 'brand_guidelines',
      extracted_text: create_comprehensive_brand_content,
      processing_status: 'processed'
    )
    
    test_content = "This is a test message that may violate brand guidelines."
    
    compliance_result = service.check_realtime_compliance(test_content)
    
    assert compliance_result[:overall_score].present?
    assert compliance_result[:rule_violations].is_a?(Array)
    assert compliance_result[:suggestions].is_a?(Array)
    assert compliance_result[:processing_time] < 2.0 # Under 2 seconds
  end

  test "should support batch analysis for multiple assets" do
    # This test will fail until we implement batch processing
    service = Branding::AnalysisService.new(@brand)
    
    # Create multiple brand assets
    3.times do |i|
      @brand.brand_assets.create!(
        asset_type: "document_#{i}",
        extracted_text: "Brand content #{i}: " + create_comprehensive_brand_content,
        processing_status: 'processed'
      )
    end
    
    result = service.batch_analyze_assets
    
    assert result[:success]
    assert result[:processed_assets] == 3
    assert result[:aggregated_analysis].present?
    assert result[:consistency_across_assets] >= 0.8
  end

  test "should generate compliance recommendations" do
    # This test will fail until we implement recommendation engine
    service = Branding::AnalysisService.new(@brand)
    
    @brand.brand_assets.create!(
      asset_type: 'brand_guidelines',
      extracted_text: create_comprehensive_brand_content,
      processing_status: 'processed'
    )
    
    non_compliant_content = "Hey buddy! This is super casual and uses slang, ya know? 😎"
    
    recommendations = service.generate_compliance_recommendations(non_compliant_content)
    
    assert recommendations[:success]
    assert recommendations[:recommendations].count >= 3
    assert recommendations[:severity_scores].present?
    assert recommendations[:suggested_revisions].present?
  end

  private

  def create_test_analysis
    @brand.brand_analyses.create!(
      analysis_status: "processing",
      voice_attributes: {},
      brand_values: [],
      messaging_pillars: [],
      extracted_rules: {},
      visual_guidelines: {},
      confidence_score: 0.0
    )
  end

  def create_comprehensive_brand_content
    <<~TEXT
      COMPREHENSIVE BRAND GUIDELINES
      
      BRAND VOICE & TONE:
      Voice: Professional, approachable, and authoritative
      Tone: Confident yet humble, helpful, innovative
      Personality: Trustworthy, forward-thinking, customer-centric
      
      COMMUNICATION GUIDELINES:
      DO:
      - Use active voice in all communications
      - Maintain professional tone while being approachable
      - Focus on customer benefits and value proposition
      - Use data-driven language when appropriate
      - Include clear calls-to-action
      - Use inclusive language
      
      DON'T:
      - Use overly casual language or slang
      - Make unsubstantiated claims
      - Use negative or fear-based messaging
      - Overuse technical jargon
      - Use outdated references or terminology
      
      VISUAL IDENTITY:
      Primary Brand Colors:
      - Navy Blue: #1a365d (Authority, Trust)
      - Bright Blue: #3182ce (Innovation, Progress)
      - Dark Gray: #2d3748 (Professional, Stable)
      
      Secondary Colors:
      - Green: #38a169 (Growth, Success)
      - Orange: #dd6b20 (Energy, Creativity)
      - Light Gray: #e2e8f0 (Clean, Modern)
      
      TYPOGRAPHY:
      Headlines: Roboto Bold (28-48px)
      Subheadings: Roboto Medium (18-24px)
      Body Text: Source Sans Pro Regular (14-16px)
      Captions: Source Sans Pro Light (12-14px)
      
      LOGO USAGE:
      - Minimum size: 32px height for digital, 1 inch for print
      - Clear space: 2x logo height on all sides
      - Never alter colors, proportions, or add effects
      - Use white version on dark backgrounds
      
      MESSAGING PILLARS:
      1. Innovation Leadership: We lead through cutting-edge solutions
      2. Customer Success: Our customers' success is our primary goal  
      3. Reliable Partnership: We deliver consistent, dependable results
      4. Continuous Improvement: We evolve and adapt to serve better
      
      BRAND VALUES:
      - Integrity: We do what's right, always
      - Excellence: We strive for the highest quality
      - Innovation: We embrace new ideas and technologies
      - Collaboration: We work together to achieve more
      - Customer Focus: We put customers at the center of everything
      
      TARGET AUDIENCE:
      Primary: Business decision-makers, ages 30-50
      Secondary: Technical professionals, ages 25-45
      Tertiary: Enterprise buyers, ages 35-55
      
      CONTENT GUIDELINES:
      - Headlines should be benefit-focused and action-oriented
      - Use bullet points for easy scanning
      - Include social proof and testimonials
      - End with clear, compelling calls-to-action
      - Maintain consistent voice across all channels
      
      COMPLIANCE RULES:
      - All marketing materials must include disclaimer
      - Claims must be substantiated with data
      - Accessibility standards must be met (WCAG 2.1 AA)
      - Brand colors must match exact hex values
      - Logo placement must follow spacing guidelines
    TEXT
  end

  def create_benchmark_brand_content
    <<~TEXT
      BENCHMARK BRAND GUIDE
      
      Voice: Professional
      Tone: Confident
      Primary Color: #1a365d
      Logo Minimum Size: 32px
      
      DO: Use professional language
      DON'T: Use casual slang
      
      Brand Values: Innovation, Trust, Excellence
    TEXT
  end

  def get_benchmark_expected_results
    {
      voice_attributes: {
        formality: { level: 'professional', score: 0.9 },
        tone: { primary: 'confident', score: 0.85 }
      },
      brand_values: [
        { name: 'Innovation', score: 0.9 },
        { name: 'Trust', score: 0.9 },
        { name: 'Excellence', score: 0.9 }
      ],
      visual_guidelines: {
        primary_colors: ['#1a365d'],
        logo_min_size: '32px'
      },
      extracted_rules: {
        voice_tone_rules: {
          must_do: ['Use professional language'],
          must_not_do: ['Use casual slang']
        }
      }
    }
  end

  def create_complex_nested_guidelines
    <<~TEXT
      COMPLEX BRAND GUIDELINES
      
      CONTEXT-SPECIFIC RULES:
      
      For Email Communications:
      - Subject lines: Action-oriented, under 50 characters
      - Body: Professional tone, max 200 words
      - CTA: Single, clear action
      
      For Social Media:
      - Voice: More casual but still professional
      - Hashtags: Max 3 relevant hashtags
      - Emojis: Occasional use acceptable
      
      For Enterprise Sales:
      - Voice: Highly professional, data-driven
      - Include: ROI metrics, case studies
      - Avoid: Casual language, unsubstantiated claims
      
      CONDITIONAL GUIDELINES:
      IF audience = executives THEN use formal tone
      IF channel = social THEN allow moderate casualness
      IF content_type = testimonial THEN include attribution
      
      NESTED VOICE RULES:
      Professional Communication:
        Formal Settings:
          - Use complete sentences
          - Avoid contractions
          - Include proper titles
        Casual Settings:
          - Contractions acceptable
          - Conversational tone OK
          - Personal pronouns encouraged
    TEXT
  end
end