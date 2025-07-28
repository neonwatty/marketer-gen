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
    ENV.stub :[], nil do
      provider = service.send(:determine_best_provider)
      assert_equal 'gpt-3.5-turbo', provider  # Fallback
    end
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
end