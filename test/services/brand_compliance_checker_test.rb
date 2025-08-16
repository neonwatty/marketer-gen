require "test_helper"

class BrandComplianceCheckerTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @brand_identity = brand_identities(:active_brand)
    @content = "This is professional and friendly content that should align with brand guidelines."
  end

  test "class method check_compliance creates instance and calls check_compliance" do
    result = BrandComplianceChecker.check_compliance(@brand_identity, @content)
    
    assert result.is_a?(Hash)
    assert_includes result.keys, :compliant
    assert_includes result.keys, :violations
    assert_includes result.keys, :brand_identity_id
    assert_includes result.keys, :checked_at
    assert_includes result.keys, :content_length
  end

  test "check_compliance returns non-compliant when no brand identity provided" do
    result = BrandComplianceChecker.new(nil, @content).check_compliance
    
    assert_not result[:compliant]
    assert_includes result[:violations], "No brand identity provided"
  end

  test "check_compliance returns non-compliant when brand identity is not active" do
    inactive_brand = brand_identities(:valid_brand) # This one has status: draft
    result = BrandComplianceChecker.new(inactive_brand, @content).check_compliance
    
    assert_not result[:compliant]
    assert_includes result[:violations], "Brand identity is not active"
  end

  test "check_compliance returns compliant for blank content" do
    result = BrandComplianceChecker.new(@brand_identity, "").check_compliance
    
    assert result[:compliant]
    assert_empty result[:violations]
  end

  test "check_compliance returns compliant for nil content" do
    result = BrandComplianceChecker.new(@brand_identity, nil).check_compliance
    
    assert result[:compliant]
    assert_empty result[:violations]
  end

  test "check_compliance includes brand_identity_id in result" do
    result = BrandComplianceChecker.new(@brand_identity, @content).check_compliance
    
    assert_equal @brand_identity.id, result[:brand_identity_id]
  end

  test "check_compliance includes content_length in result" do
    result = BrandComplianceChecker.new(@brand_identity, @content).check_compliance
    
    assert_equal @content.length, result[:content_length]
  end

  test "check_compliance includes timestamp" do
    freeze_time = Time.current
    Time.stubs(:current).returns(freeze_time)
    
    result = BrandComplianceChecker.new(@brand_identity, @content).check_compliance
    
    assert_equal freeze_time, result[:checked_at]
  end

  test "extract_voice_keywords finds voice-related terms" do
    voice_text = "We are professional, friendly, and authoritative in our communication"
    checker = BrandComplianceChecker.new(@brand_identity, @content)
    
    keywords = checker.send(:extract_voice_keywords, voice_text)
    
    assert_includes keywords, "professional"
    assert_includes keywords, "friendly" 
    assert_includes keywords, "authoritative"
  end

  test "extract_tone_keywords finds tone-related terms" do
    tone_text = "Always be positive and enthusiastic, never negative"
    checker = BrandComplianceChecker.new(@brand_identity, @content)
    
    keywords = checker.send(:extract_tone_keywords, tone_text)
    
    assert_includes keywords, "positive"
    assert_includes keywords, "enthusiastic"
    assert_includes keywords, "negative"
  end

  test "extract_restricted_terms finds restrictions" do
    restrictions_text = "Avoid: jargon, technical speak. Don't use: complicated language."
    checker = BrandComplianceChecker.new(@brand_identity, @content)
    
    terms = checker.send(:extract_restricted_terms, restrictions_text)
    
    assert_includes terms, "jargon, technical speak"
    assert_includes terms, "complicated language"
  end

  test "check_restrictions detects restricted terms in content" do
    # Test the current implementation which looks for simple word matches
    @brand_identity.update!(restrictions: "forbidden_word bad_term")
    content_with_restriction = "This content contains forbidden_word which should be flagged"
    
    # Create a new checker instance to use the updated brand identity
    checker = BrandComplianceChecker.new(@brand_identity.reload, content_with_restriction)
    
    # Mock the extract_restricted_terms method to return what we expect
    checker.stubs(:extract_restricted_terms).returns(["forbidden_word"])
    
    result = checker.check_compliance
    
    assert_not result[:compliant]
    assert result[:violations].any? { |v| v.include?("forbidden_word") }
  end

  test "check_restrictions is case insensitive" do
    @brand_identity.update!(restrictions: "FORBIDDEN")
    content_with_restriction = "This content contains forbidden which should be flagged"
    
    # Create a new checker instance to use the updated brand identity  
    checker = BrandComplianceChecker.new(@brand_identity.reload, content_with_restriction)
    
    # Mock the extract_restricted_terms method to return what we expect
    checker.stubs(:extract_restricted_terms).returns(["FORBIDDEN"])
    
    result = checker.check_compliance
    
    assert_not result[:compliant]
    assert result[:violations].any? { |v| v.include?("FORBIDDEN") }
  end

  test "detailed_analysis returns comprehensive analysis" do
    checker = BrandComplianceChecker.new(@brand_identity, @content)
    analysis = checker.detailed_analysis
    
    assert analysis.is_a?(Hash)
    assert_includes analysis.keys, :brand_voice_analysis
    assert_includes analysis.keys, :tone_analysis
    assert_includes analysis.keys, :messaging_analysis
    assert_includes analysis.keys, :restrictions_analysis
    assert_includes analysis.keys, :overall_score
    assert_includes analysis.keys, :recommendations
  end

  test "detailed_analysis returns empty hash for inactive brand identity" do
    inactive_brand = brand_identities(:valid_brand)
    checker = BrandComplianceChecker.new(inactive_brand, @content)
    analysis = checker.detailed_analysis
    
    assert_equal({}, analysis)
  end

  test "calculate_compliance_score returns value between 0 and 1" do
    checker = BrandComplianceChecker.new(@brand_identity, @content)
    score = checker.send(:calculate_compliance_score)
    
    assert score >= 0.0
    assert score <= 1.0
  end

  test "generate_recommendations returns array of strings" do
    checker = BrandComplianceChecker.new(@brand_identity, @content)
    recommendations = checker.send(:generate_recommendations)
    
    assert recommendations.is_a?(Array)
    recommendations.each do |rec|
      assert rec.is_a?(String)
    end
  end

  test "analyze_brand_voice returns expected structure" do
    checker = BrandComplianceChecker.new(@brand_identity, @content)
    analysis = checker.send(:analyze_brand_voice)
    
    assert analysis.is_a?(Hash)
    assert_includes analysis.keys, :detected_voice_elements
    assert_includes analysis.keys, :matches_brand_voice
    assert_includes analysis.keys, :confidence_score
    assert analysis[:detected_voice_elements].is_a?(Array)
    assert [true, false].include?(analysis[:matches_brand_voice])
    assert analysis[:confidence_score].is_a?(Numeric)
  end

  test "analyze_tone returns expected structure" do
    checker = BrandComplianceChecker.new(@brand_identity, @content)
    analysis = checker.send(:analyze_tone)
    
    assert analysis.is_a?(Hash)
    assert_includes analysis.keys, :detected_tone_elements
    assert_includes analysis.keys, :matches_brand_tone
    assert_includes analysis.keys, :confidence_score
    assert analysis[:detected_tone_elements].is_a?(Array)
    assert [true, false].include?(analysis[:matches_brand_tone])
    assert analysis[:confidence_score].is_a?(Numeric)
  end

  test "analyze_restrictions returns expected structure" do
    checker = BrandComplianceChecker.new(@brand_identity, @content)
    analysis = checker.send(:analyze_restrictions)
    
    assert analysis.is_a?(Hash)
    assert_includes analysis.keys, :violations_found
    assert_includes analysis.keys, :restriction_compliance_score
    assert_includes analysis.keys, :flagged_content
    assert analysis[:violations_found].is_a?(Array)
    assert analysis[:restriction_compliance_score].is_a?(Numeric)
    assert analysis[:flagged_content].is_a?(Array)
  end

  test "compliance_result helper returns properly formatted result" do
    checker = BrandComplianceChecker.new(@brand_identity, @content)
    violations = ["Test violation"]
    
    result = checker.send(:compliance_result, false, violations)
    
    assert_equal false, result[:compliant]
    assert_equal violations, result[:violations]
    assert_equal @brand_identity.id, result[:brand_identity_id]
    assert_equal @content.length, result[:content_length]
    assert result[:checked_at].present?
  end
end