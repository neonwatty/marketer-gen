class BrandComplianceChecker
  attr_reader :brand_identity, :content_to_check
  
  def initialize(brand_identity, content_to_check)
    @brand_identity = brand_identity
    @content_to_check = content_to_check
  end
  
  def self.check_compliance(brand_identity, content)
    new(brand_identity, content).check_compliance
  end
  
  def check_compliance
    return compliance_result(false, ["No brand identity provided"]) unless brand_identity
    return compliance_result(false, ["Brand identity is not active"]) unless brand_identity.active?
    return compliance_result(true, []) if content_to_check.blank?
    
    violations = []
    
    # Check against brand voice guidelines
    violations.concat(check_brand_voice)
    
    # Check against tone guidelines  
    violations.concat(check_tone_guidelines)
    
    # Check against messaging framework
    violations.concat(check_messaging_framework)
    
    # Check against restrictions
    violations.concat(check_restrictions)
    
    # Check for required elements
    violations.concat(check_required_elements)
    
    compliance_result(violations.empty?, violations)
  end
  
  def detailed_analysis
    return {} unless brand_identity&.active?
    
    {
      brand_voice_analysis: analyze_brand_voice,
      tone_analysis: analyze_tone,
      messaging_analysis: analyze_messaging,
      restrictions_analysis: analyze_restrictions,
      overall_score: calculate_compliance_score,
      recommendations: generate_recommendations
    }
  end
  
  private
  
  def compliance_result(compliant, violations)
    {
      compliant: compliant,
      violations: violations,
      brand_identity_id: brand_identity&.id,
      checked_at: Time.current,
      content_length: content_to_check&.length || 0
    }
  end
  
  def check_brand_voice
    violations = []
    return violations unless brand_identity.brand_voice.present?
    
    # In a real implementation, this would use NLP/AI to analyze voice consistency
    # For now, implementing basic keyword and pattern checks
    
    voice_keywords = extract_voice_keywords(brand_identity.brand_voice)
    
    if voice_keywords.any? && !contains_voice_elements?(voice_keywords)
      violations << "Content does not reflect the established brand voice"
    end
    
    violations
  end
  
  def check_tone_guidelines
    violations = []
    return violations unless brand_identity.tone_guidelines.present?
    
    # Check for tone consistency
    tone_keywords = extract_tone_keywords(brand_identity.tone_guidelines)
    
    if tone_keywords.any? && !reflects_tone?(tone_keywords)
      violations << "Content tone does not align with brand tone guidelines"
    end
    
    violations
  end
  
  def check_messaging_framework
    violations = []
    return violations unless brand_identity.messaging_framework.present?
    
    # Check messaging consistency
    if !aligns_with_messaging_framework?
      violations << "Content does not align with the established messaging framework"
    end
    
    violations
  end
  
  def check_restrictions
    violations = []
    return violations unless brand_identity.restrictions.present?
    
    restricted_terms = extract_restricted_terms(brand_identity.restrictions)
    
    restricted_terms.each do |term|
      if content_to_check.downcase.include?(term.downcase)
        violations << "Content contains restricted term: '#{term}'"
      end
    end
    
    violations
  end
  
  def check_required_elements
    violations = []
    
    # In a real implementation, this would check for required brand elements
    # based on the brand guidelines
    
    violations
  end
  
  def extract_voice_keywords(voice_text)
    # Simple keyword extraction - in real implementation would use NLP
    voice_text.downcase.scan(/\b(professional|friendly|authoritative|casual|formal|informal|technical|approachable)\b/).flatten.uniq
  end
  
  def extract_tone_keywords(tone_text)
    # Simple keyword extraction for tone
    tone_text.downcase.scan(/\b(positive|negative|neutral|enthusiastic|serious|playful|conservative|innovative)\b/).flatten.uniq
  end
  
  def extract_restricted_terms(restrictions_text)
    # Extract terms that should not appear in content
    # This is a simple implementation - real version would be more sophisticated
    restrictions_text.scan(/(?:avoid|don't use|prohibited|forbidden|restricted):\s*([^.\n]+)/i)
      .flatten
      .map(&:strip)
      .reject(&:blank?)
  end
  
  def contains_voice_elements?(voice_keywords)
    # Check if content reflects the brand voice keywords
    voice_keywords.any? { |keyword| content_to_check.downcase.include?(keyword) }
  end
  
  def reflects_tone?(tone_keywords)
    # Check if content reflects the appropriate tone
    tone_keywords.any? { |keyword| content_to_check.downcase.include?(keyword) }
  end
  
  def aligns_with_messaging_framework?
    # In real implementation, would use AI to check message alignment
    true # Placeholder
  end
  
  def analyze_brand_voice
    # Detailed voice analysis for reporting
    {
      detected_voice_elements: extract_voice_keywords(content_to_check),
      matches_brand_voice: contains_voice_elements?(extract_voice_keywords(brand_identity.brand_voice || "")),
      confidence_score: rand(0.7..0.95) # Placeholder for AI confidence score
    }
  end
  
  def analyze_tone
    # Detailed tone analysis for reporting
    {
      detected_tone_elements: extract_tone_keywords(content_to_check),
      matches_brand_tone: reflects_tone?(extract_tone_keywords(brand_identity.tone_guidelines || "")),
      confidence_score: rand(0.7..0.95) # Placeholder for AI confidence score
    }
  end
  
  def analyze_messaging
    # Detailed messaging analysis for reporting
    {
      messaging_alignment_score: rand(0.6..0.9), # Placeholder for AI analysis
      key_messages_present: true, # Placeholder
      confidence_score: rand(0.7..0.95)
    }
  end
  
  def analyze_restrictions
    # Detailed restrictions analysis
    violations = check_restrictions
    {
      violations_found: violations,
      restriction_compliance_score: violations.empty? ? 1.0 : 0.0,
      flagged_content: [] # Would highlight problematic sections
    }
  end
  
  def calculate_compliance_score
    # Calculate overall compliance score (0.0 to 1.0)
    voice_score = analyze_brand_voice[:confidence_score]
    tone_score = analyze_tone[:confidence_score]
    messaging_score = analyze_messaging[:confidence_score]
    restrictions_score = analyze_restrictions[:restriction_compliance_score]
    
    (voice_score + tone_score + messaging_score + restrictions_score) / 4.0
  end
  
  def generate_recommendations
    recommendations = []
    
    voice_analysis = analyze_brand_voice
    unless voice_analysis[:matches_brand_voice]
      recommendations << "Consider adjusting the content to better reflect the brand voice"
    end
    
    tone_analysis = analyze_tone
    unless tone_analysis[:matches_brand_tone]
      recommendations << "Review the tone to ensure it aligns with brand guidelines"
    end
    
    restrictions_analysis = analyze_restrictions
    if restrictions_analysis[:violations_found].any?
      recommendations << "Remove or replace flagged content that violates brand restrictions"
    end
    
    if calculate_compliance_score < 0.7
      recommendations << "Consider reviewing the content against the complete brand guidelines"
    end
    
    recommendations
  end
end