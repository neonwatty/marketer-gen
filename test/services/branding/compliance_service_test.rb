require "test_helper"

class Branding::ComplianceServiceTest < ActiveSupport::TestCase
  setup do
    @brand = brands(:one)
    @messaging_framework = messaging_frameworks(:one)
    @service = Branding::ComplianceService.new(@brand, "Test content for analysis")
  end

  test "should check banned words compliance" do
    content_with_banned_words = "This is a cheap solution with basic features"
    service = Branding::ComplianceService.new(@brand, content_with_banned_words)
    
    result = service.check_compliance
    
    assert_not result[:compliant]
    banned_word_violation = result[:violations].find { |v| v[:type] == "banned_words" }
    assert_not_nil banned_word_violation
    assert_includes banned_word_violation[:details], "cheap"
    assert_includes banned_word_violation[:details], "basic"
  end

  test "should pass compliance with clean content" do
    # Clear guidelines to focus on content analysis only
    @brand.brand_guidelines.destroy_all
    
    clean_content = "Our innovative solution provides proven results with industry leadership"
    service = Branding::ComplianceService.new(@brand, clean_content)
    
    result = service.check_compliance
    
    # Should have reasonable compliance score
    assert result[:score] > 0.5
    # With no guidelines, should have no violations
    assert result[:violations].empty?, "Should have no violations with clean content and no guidelines: #{result[:violations]}"
  end

  test "should detect tone mismatch" do
    casual_content = "Hey, this is gonna be awesome! Our solution rocks and you'll love it!"
    service = Branding::ComplianceService.new(@brand, casual_content)
    
    result = service.check_compliance
    
    tone_violation = result[:violations].find { |v| v[:type] == "tone_mismatch" }
    assert_not_nil tone_violation
    assert_equal "medium", tone_violation[:severity]
  end

  test "should check messaging alignment" do
    aligned_content = "Our innovative technology delivers proven results with industry-leading reliability"
    service = Branding::ComplianceService.new(@brand, aligned_content)
    
    result = service.check_compliance
    
    # Should have good alignment with brand key messages
    assert result[:score] > 0.5
  end

  test "should provide suggestions for improvements" do
    moderate_content = "We offer technology solutions for businesses"
    service = Branding::ComplianceService.new(@brand, moderate_content)
    
    result = service.validate_and_suggest
    
    if result[:compliant]
      assert_not_empty result[:suggestions]
    else
      assert_not_empty result[:corrections]
    end
  end

  test "should handle empty content gracefully" do
    service = Branding::ComplianceService.new(@brand, "")
    result = service.check_compliance
    
    assert_not result[:compliant]
    assert_equal "No content provided", result[:error]
  end

  test "should calculate compliance score correctly" do
    result = @service.check_compliance
    
    assert result[:score].is_a?(Float)
    assert result[:score] >= 0
    assert result[:score] <= 1
  end

  test "should provide compliance summary" do
    result = @service.check_compliance
    
    assert_not_nil result[:summary]
    assert result[:summary].is_a?(String)
    assert result[:summary].length > 0
  end
end