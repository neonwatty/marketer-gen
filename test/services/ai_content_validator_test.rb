require "test_helper"

class AiContentValidatorTest < ActiveSupport::TestCase
  def setup
    @validator = AiContentValidator.new
  end

  # Configuration tests
  test "should initialize with default settings" do
    validator = AiContentValidator.new
    assert_equal ['quality', 'appropriateness'], validator.validation_types
    assert_equal 'general', validator.content_category
    assert_equal false, validator.strict_mode
    assert_equal 70, validator.min_quality_score
  end

  test "should validate configuration on initialization" do
    assert_nothing_raised do
      AiContentValidator.new(validation_types: ['quality', 'appropriateness'])
    end

    assert_raises AiContentValidator::InvalidConfigurationError do
      AiContentValidator.new(validation_types: ['invalid_type'])
    end

    assert_raises AiContentValidator::InvalidConfigurationError do
      AiContentValidator.new(content_category: 'invalid_category')
    end
  end

  # Quality validation tests
  test "should validate content quality - passing case" do
    validator = AiContentValidator.new(validation_types: ['quality'])
    
    good_content = <<~TEXT
      This is a well-written marketing campaign description that provides 
      comprehensive information about our product offerings. The content 
      maintains professional language throughout and offers clear value 
      propositions for potential customers. Each sentence contributes 
      meaningfully to the overall message without unnecessary repetition.
    TEXT

    result = validator.validate(good_content)

    assert_equal 'pass', result[:overall_status]
    quality_result = result[:validation_results].find { |r| r[:type] == 'quality' }
    assert quality_result[:score] >= 70
  end

  test "should validate content quality - failing case" do
    validator = AiContentValidator.new(validation_types: ['quality'])
    
    poor_content = "Bad bad bad bad bad bad bad content [PLACEHOLDER] TODO: fix this"

    result = validator.validate(poor_content)

    assert_equal 'fail', result[:overall_status]
    quality_result = result[:validation_results].find { |r| r[:type] == 'quality' }
    assert quality_result[:score] < 70
    assert_includes quality_result[:message], 'placeholders'
    assert_includes quality_result[:message], 'repetition'
  end

  test "should detect content length issues" do
    validator = AiContentValidator.new(validation_types: ['quality'])
    
    # Too short
    short_result = validator.validate("Short")
    quality_result = short_result[:validation_results].find { |r| r[:type] == 'quality' }
    assert_includes quality_result[:message], 'too short'

    # Too long for non-blog content
    long_content = "A" * 6000
    long_result = validator.validate(long_content)
    quality_result = long_result[:validation_results].find { |r| r[:type] == 'quality' }
    assert_includes quality_result[:message], 'too long'
  end

  test "should detect placeholder content" do
    validator = AiContentValidator.new(validation_types: ['quality'])
    
    placeholder_content = "Welcome to [COMPANY NAME] where we offer {PRODUCT} solutions. TODO: Add more details here."
    result = validator.validate(placeholder_content)

    quality_result = result[:validation_results].find { |r| r[:type] == 'quality' }
    assert_includes quality_result[:message], 'placeholders'
    assert quality_result[:score] < 80
  end

  # Appropriateness validation tests
  test "should validate content appropriateness - passing case" do
    validator = AiContentValidator.new(validation_types: ['appropriateness'])
    
    appropriate_content = <<~TEXT
      Our professional services help businesses grow through innovative 
      solutions and dedicated customer support. We work collaboratively 
      with clients to achieve their goals effectively.
    TEXT

    result = validator.validate(appropriate_content)

    assert_equal 'pass', result[:overall_status]
    appropriateness_result = result[:validation_results].find { |r| r[:type] == 'appropriateness' }
    assert appropriateness_result[:score] >= 80
  end

  test "should detect inappropriate language" do
    validator = AiContentValidator.new(validation_types: ['appropriateness'])
    
    inappropriate_content = "This damn product is stupid and anyone who doesn't buy it is an idiot!"
    result = validator.validate(inappropriate_content)

    appropriateness_result = result[:validation_results].find { |r| r[:type] == 'appropriateness' }
    assert_includes appropriateness_result[:message], 'inappropriate language'
    assert appropriateness_result[:score] < 80
  end

  test "should detect overly promotional content" do
    validator = AiContentValidator.new(validation_types: ['appropriateness'])
    
    spammy_content = "BUY NOW!!! LIMITED TIME!!! FREE OFFER!!! ACT NOW!!! GUARANTEED RESULTS!!!"
    result = validator.validate(spammy_content)

    appropriateness_result = result[:validation_results].find { |r| r[:type] == 'appropriateness' }
    assert_includes appropriateness_result[:message], 'promotional'
    assert appropriateness_result[:score] < 80
  end

  test "should flag sensitive topics" do
    validator = AiContentValidator.new(validation_types: ['appropriateness'])
    
    sensitive_content = "Our medical treatment guarantees financial profit through legal investment opportunities."
    result = validator.validate(sensitive_content)

    appropriateness_result = result[:validation_results].find { |r| r[:type] == 'appropriateness' }
    assert_includes appropriateness_result[:message], 'sensitive topics'
  end

  # Brand compliance validation tests
  test "should validate brand compliance when guidelines provided" do
    brand_guidelines = {
      'required_terms' => ['Acme Corp', 'innovation'],
      'forbidden_terms' => ['competitor', 'cheap'],
      'tone' => 'professional'
    }
    
    validator = AiContentValidator.new(
      validation_types: ['brand_compliance'],
      brand_guidelines: brand_guidelines
    )
    
    compliant_content = "Acme Corp leads through innovation and professional service excellence."
    result = validator.validate(compliant_content)

    compliance_result = result[:validation_results].find { |r| r[:type] == 'brand_compliance' }
    assert compliance_result[:score] >= 70
  end

  test "should detect missing required brand terms" do
    brand_guidelines = {
      'required_terms' => ['Acme Corp', 'innovation'],
      'tone' => 'professional'
    }
    
    validator = AiContentValidator.new(
      validation_types: ['brand_compliance'],
      brand_guidelines: brand_guidelines
    )
    
    non_compliant_content = "This company offers great services and products."
    result = validator.validate(non_compliant_content)

    compliance_result = result[:validation_results].find { |r| r[:type] == 'brand_compliance' }
    assert_includes compliance_result[:message], 'required brand term'
    assert compliance_result[:score] < 70
  end

  test "should detect forbidden brand terms" do
    brand_guidelines = {
      'forbidden_terms' => ['competitor', 'cheap', 'discount']
    }
    
    validator = AiContentValidator.new(
      validation_types: ['brand_compliance'],
      brand_guidelines: brand_guidelines
    )
    
    non_compliant_content = "Unlike our competitor, we offer cheap discount prices."
    result = validator.validate(non_compliant_content)

    compliance_result = result[:validation_results].find { |r| r[:type] == 'brand_compliance' }
    assert_includes compliance_result[:message], 'forbidden term'
    assert compliance_result[:score] < 50
  end

  # Content structure validation tests
  test "should validate email structure" do
    validator = AiContentValidator.new(
      validation_types: ['content_structure'],
      content_category: 'email'
    )
    
    good_email = <<~TEXT
      Subject: Welcome to Our Newsletter
      
      Dear Customer,
      
      Thank you for subscribing to our newsletter. Click here to visit our website 
      and explore our latest offerings.
      
      Best regards,
      The Team
    TEXT

    result = validator.validate(good_email)
    
    structure_result = result[:validation_results].find { |r| r[:type] == 'content_structure' }
    assert structure_result[:score] >= 70
  end

  test "should detect missing email structure elements" do
    validator = AiContentValidator.new(
      validation_types: ['content_structure'],
      content_category: 'email'
    )
    
    poor_email = "Just some content without proper email structure."
    result = validator.validate(poor_email)

    structure_result = result[:validation_results].find { |r| r[:type] == 'content_structure' }
    assert_includes structure_result[:message], 'subject line'
    assert structure_result[:score] < 70
  end

  test "should validate social media structure" do
    validator = AiContentValidator.new(
      validation_types: ['content_structure'],
      content_category: 'social_media'
    )
    
    good_social = "🎉 Exciting news! Check out our latest product launch #NewProduct #Innovation"
    result = validator.validate(good_social)

    structure_result = result[:validation_results].find { |r| r[:type] == 'content_structure' }
    assert structure_result[:score] >= 70
  end

  test "should detect missing social media elements" do
    validator = AiContentValidator.new(
      validation_types: ['content_structure'],
      content_category: 'social_media'
    )
    
    poor_social = "This is a very long social media post without hashtags that goes on for way too many characters and doesn't have engaging elements that make it suitable for social media platforms where brevity and engagement are key."
    result = validator.validate(poor_social)

    structure_result = result[:validation_results].find { |r| r[:type] == 'content_structure' }
    assert_includes structure_result[:message], 'hashtags' 
    assert_includes structure_result[:message], 'too long'
  end

  # Language quality validation tests
  test "should validate language quality - good case" do
    validator = AiContentValidator.new(validation_types: ['language_quality'])
    
    good_language = <<~TEXT
      Our company provides excellent services to customers worldwide. 
      We have developed innovative solutions that help businesses grow. 
      Each client receives personalized attention from our dedicated team.
    TEXT

    result = validator.validate(good_language)

    language_result = result[:validation_results].find { |r| r[:type] == 'language_quality' }
    assert language_result[:score] >= 70
  end

  test "should detect basic grammar issues" do
    validator = AiContentValidator.new(validation_types: ['language_quality'])
    
    poor_grammar = "we have a excellent product.the quality are great.contact us for more informations."
    result = validator.validate(poor_grammar)

    language_result = result[:validation_results].find { |r| r[:type] == 'language_quality' }
    assert_includes language_result[:message], 'capital letter'
    assert language_result[:score] < 70
  end

  # Marketing effectiveness validation tests
  test "should validate marketing effectiveness - good case" do
    validator = AiContentValidator.new(validation_types: ['marketing_effectiveness'])
    
    effective_content = <<~TEXT
      Transform your business with our innovative solutions! You'll save time 
      and increase productivity while reducing costs. Our proven methods help 
      you achieve better results. Contact us today to get started with your 
      personalized consultation.
    TEXT

    result = validator.validate(effective_content)

    effectiveness_result = result[:validation_results].find { |r| r[:type] == 'marketing_effectiveness' }
    assert effectiveness_result[:score] >= 70
  end

  test "should detect missing call-to-action" do
    validator = AiContentValidator.new(validation_types: ['marketing_effectiveness'])
    
    weak_content = "Our product is really good and has nice features. Many people like it."
    result = validator.validate(weak_content)

    effectiveness_result = result[:validation_results].find { |r| r[:type] == 'marketing_effectiveness' }
    assert_includes effectiveness_result[:message], 'call-to-action'
    assert effectiveness_result[:score] < 70
  end

  test "should detect missing benefits" do
    validator = AiContentValidator.new(validation_types: ['marketing_effectiveness'])
    
    weak_content = "We have a product. Please click here to buy it now."
    result = validator.validate(weak_content)

    effectiveness_result = result[:validation_results].find { |r| r[:type] == 'marketing_effectiveness' }
    assert_includes effectiveness_result[:message], 'benefits'
    assert effectiveness_result[:score] < 70
  end

  # Platform compliance validation tests
  test "should validate platform compliance when requirements provided" do
    platform_requirements = {
      'max_length' => 280,
      'max_hashtags' => 2,
      'required_elements' => ['hashtags']
    }
    
    validator = AiContentValidator.new(
      validation_types: ['platform_compliance'],
      platform_requirements: platform_requirements
    )
    
    compliant_content = "Great news about our product! #Innovation #Tech"
    result = validator.validate(compliant_content)

    platform_result = result[:validation_results].find { |r| r[:type] == 'platform_compliance' }
    assert platform_result[:score] >= 80
  end

  test "should detect platform violations" do
    platform_requirements = {
      'max_length' => 50,
      'max_hashtags' => 1
    }
    
    validator = AiContentValidator.new(
      validation_types: ['platform_compliance'],
      platform_requirements: platform_requirements
    )
    
    violating_content = "This content is way too long for the specified platform requirements and has too many hashtags #one #two #three"
    result = validator.validate(violating_content)

    platform_result = result[:validation_results].find { |r| r[:type] == 'platform_compliance' }
    assert_includes platform_result[:message], 'exceeds platform limit'
    assert_includes platform_result[:message], 'Too many hashtags'
    assert platform_result[:score] < 60
  end

  # Safety validation tests
  test "should validate content safety - safe case" do
    validator = AiContentValidator.new(validation_types: ['safety'])
    
    safe_content = "Our educational platform helps students learn effectively through interactive courses."
    result = validator.validate(safe_content)

    safety_result = result[:validation_results].find { |r| r[:type] == 'safety' }
    assert safety_result[:score] >= 90
  end

  test "should detect safety concerns" do
    validator = AiContentValidator.new(validation_types: ['safety'])
    
    unsafe_content = "This virus software will hack your password and steal your credit card information."
    result = validator.validate(unsafe_content)

    safety_result = result[:validation_results].find { |r| r[:type] == 'safety' }
    assert_includes safety_result[:message], 'security-related terms'
    assert_includes safety_result[:message], 'sensitive personal information'
    assert safety_result[:score] < 70
  end

  test "should detect potential misinformation" do
    validator = AiContentValidator.new(validation_types: ['safety'])
    
    misleading_content = "This miracle cure is 100% effective and guaranteed to work instantly!"
    result = validator.validate(misleading_content)

    safety_result = result[:validation_results].find { |r| r[:type] == 'safety' }
    assert_includes safety_result[:message], 'misinformation'
    assert safety_result[:score] < 90
  end

  # Multiple validation types tests
  test "should run multiple validation types" do
    validator = AiContentValidator.new(
      validation_types: ['quality', 'appropriateness', 'marketing_effectiveness']
    )
    
    mixed_content = "This is decent content with good benefits. Click here to learn more!"
    result = validator.validate(mixed_content)

    assert_equal 3, result[:validation_results].length
    assert result[:validation_results].any? { |r| r[:type] == 'quality' }
    assert result[:validation_results].any? { |r| r[:type] == 'appropriateness' }
    assert result[:validation_results].any? { |r| r[:type] == 'marketing_effectiveness' }
  end

  # Overall scoring tests
  test "should calculate overall score correctly" do
    validator = AiContentValidator.new(
      validation_types: ['quality', 'appropriateness']
    )
    
    good_content = <<~TEXT
      Our professional team delivers exceptional results through innovative 
      approaches and dedicated service. We help you achieve your goals 
      with personalized solutions tailored to your needs.
    TEXT

    result = validator.validate(good_content)

    assert result[:overall_score] > 0
    assert result[:overall_score] <= 100
    assert_equal 'pass', result[:overall_status]
  end

  # Quick validation tests
  test "should provide quick valid check" do
    validator = AiContentValidator.new
    
    assert validator.valid?("This is good quality appropriate content for marketing purposes.")
    refute validator.valid?("Bad bad bad [PLACEHOLDER] content")
  end

  # Results filtering tests
  test "should filter results by severity" do
    validator = AiContentValidator.new(validation_types: ['quality', 'appropriateness'])
    
    poor_content = "damn this bad content has [PLACEHOLDER] TODO fix"
    validator.validate(poor_content)

    critical_issues = validator.critical_issues
    warnings = validator.results_by_severity('warning')
    
    assert critical_issues.is_a?(Array)
    assert warnings.is_a?(Array)
  end

  test "should provide recommendations" do
    validator = AiContentValidator.new(validation_types: ['quality'])
    
    poor_content = "short [TODO]"
    validator.validate(poor_content)

    recommendations = validator.recommendations
    assert recommendations.is_a?(Array)
    assert recommendations.length > 0
    assert recommendations.any? { |rec| rec.include?('content') }
  end

  # Error handling tests
  test "should handle empty content gracefully" do
    result = @validator.validate("")

    assert_equal 'error', result[:overall_status]
    assert result[:error]
  end

  test "should handle nil content gracefully" do
    result = @validator.validate(nil)

    assert_equal 'error', result[:overall_status]
    assert result[:error]
  end

  test "should handle validation errors gracefully" do
    # This should not raise an exception even with problematic content
    assert_nothing_raised do
      @validator.validate("Content with unicode: 🎉💖✨")
    end
  end

  # Strict mode tests
  test "should enforce stricter validation in strict mode" do
    strict_validator = AiContentValidator.new(
      validation_types: ['quality'],
      strict_mode: true,
      min_quality_score: 85
    )
    
    mediocre_content = "This content is okay but not great. It has some issues."
    result = strict_validator.validate(mediocre_content)

    # Should be more likely to fail in strict mode
    assert result[:overall_score] < 85 || result[:overall_status] != 'pass'
  end

  private

  def sample_high_quality_content
    <<~TEXT
      Our comprehensive marketing solutions empower businesses to achieve 
      sustainable growth through data-driven strategies and innovative 
      approaches. We collaborate closely with clients to understand their 
      unique challenges and develop customized campaigns that deliver 
      measurable results. Contact our expert team today to schedule your 
      complimentary consultation and discover how we can help you reach 
      your marketing goals.
    TEXT
  end

  def sample_poor_quality_content
    "[COMPANY] has good [PRODUCTS] that are [ADJECTIVE] and [BENEFIT]. TODO: add more details here. Buy now buy now buy now!!!"
  end
end