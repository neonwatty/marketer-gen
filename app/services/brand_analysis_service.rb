class BrandAnalysisService
  include ActiveSupport::Configurable

  config_accessor :min_confidence_threshold, default: 0.95
  config_accessor :llm_provider, default: :openai
  config_accessor :analysis_timeout, default: 30.seconds
  config_accessor :enable_multi_pass, default: true

  attr_reader :brand_asset, :analysis_result

  # Document types and their processing strategies
  PROCESSING_STRATEGIES = {
    "application/pdf" => :pdf_extraction,
    "application/msword" => :docx_extraction,
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => :docx_extraction,
    "text/plain" => :text_extraction,
    "image/jpeg" => :image_ocr,
    "image/png" => :image_ocr
  }.freeze

  # Brand characteristic extraction patterns
  BRAND_PATTERNS = {
    voice_tone: /\b(?:tone|voice|personality|character)\b.*?(?:formal|casual|friendly|professional|authoritative|conversational|playful|serious)/i,
    color_scheme: /\b(?:color|colours?|palette|brand colors?)\b.*?(?:#[0-9a-f]{3,6}|rgb|rgba|hsl|hsla|\b(?:red|blue|green|yellow|orange|purple|black|white|gray|grey)\b)/i,
    typography: /\b(?:font|typeface|typography|type)\b.*?(?:serif|sans-serif|monospace|helvetica|arial|times|georgia)/i,
    messaging: /\b(?:message|messaging|tagline|slogan|value proposition|mission|vision)\b/i,
    restrictions: /\b(?:don't|do not|avoid|never|restriction|prohibited|forbidden|exclude)\b/i
  }.freeze

  def initialize(brand_asset)
    @brand_asset = brand_asset
    @analysis_result = {}
  end

  def analyze
    return { success: false, error: "Asset not found" } unless brand_asset

    begin
      # Mark as processing
      brand_analysis = create_or_find_analysis
      brand_analysis.mark_as_processing!

      # Extract content based on file type
      extracted_content = extract_content
      return { success: false, error: "Failed to extract content" } if extracted_content.blank?

      # Perform AI analysis
      ai_analysis = perform_ai_analysis(extracted_content)

      # Multi-pass analysis for higher accuracy
      if config.enable_multi_pass && ai_analysis[:confidence] < config.min_confidence_threshold
        ai_analysis = perform_multi_pass_analysis(extracted_content, ai_analysis)
      end

      # Store results
      store_analysis_results(brand_analysis, ai_analysis)

      # Mark as completed with confidence score
      brand_analysis.mark_as_completed!(confidence: ai_analysis[:confidence])

      {
        success: true,
        analysis: brand_analysis,
        confidence: ai_analysis[:confidence],
        characteristics: ai_analysis[:characteristics]
      }

    rescue StandardError => e
      brand_analysis&.mark_as_failed!(e.message)
      { success: false, error: e.message }
    end
  end

  def extract_brand_characteristics(content)
    characteristics = {}

    BRAND_PATTERNS.each do |key, pattern|
      matches = content.scan(pattern)
      characteristics[key] = matches.flatten.uniq if matches.any?
    end

    characteristics
  end

  def calculate_confidence_score(characteristics, ai_response)
    base_score = 0.7

    # Boost confidence based on extracted characteristics
    boost = 0.0
    boost += 0.1 if characteristics[:voice_tone].present?
    boost += 0.05 if characteristics[:color_scheme].present?
    boost += 0.05 if characteristics[:typography].present?
    boost += 0.1 if characteristics[:messaging].present?

    # AI response quality indicators
    if ai_response.is_a?(Hash) && ai_response.keys.size >= 5
      boost += 0.1
    end

    [ (base_score + boost), 1.0 ].min
  end

  private

  def create_or_find_analysis
    brand_asset.brand.brand_analyses.find_or_create_by(
      brand_asset: brand_asset
    ) do |analysis|
      analysis.analysis_status = "pending"
    end
  end

  def extract_content
    case brand_asset.content_type
    when *PROCESSING_STRATEGIES.keys
      strategy = PROCESSING_STRATEGIES[brand_asset.content_type]
      send(strategy)
    else
      handle_unknown_file_type
    end
  end

  def pdf_extraction
    # Mock PDF extraction - in production would use pdf-reader gem
    if brand_asset.file.attached?
      "Mock extracted PDF content containing brand guidelines, voice and tone specifications, color palette definitions, and messaging framework."
    else
      "External PDF content from #{brand_asset.external_url}"
    end
  end

  def docx_extraction
    # Mock DOCX extraction - in production would use docx gem
    if brand_asset.file.attached?
      "Mock extracted DOCX content with comprehensive brand documentation including visual identity, messaging pillars, and compliance rules."
    else
      "External DOCX content from #{brand_asset.external_url}"
    end
  end

  def text_extraction
    # Simple text extraction
    if brand_asset.file.attached?
      brand_asset.file.download rescue "Mock text content with brand specifications."
    else
      "External text content from #{brand_asset.external_url}"
    end
  end

  def image_ocr
    # Mock OCR extraction - in production would integrate with OCR service
    "Mock OCR extracted text from brand image including logo specifications, color codes, and visual guidelines."
  end

  def handle_unknown_file_type
    "Generic content extraction for #{brand_asset.content_type}"
  end

  def perform_ai_analysis(content)
    # Mock LLM analysis - integrate with actual LLM service
    prompt = build_analysis_prompt(content)

    # Simulate LLM response
    ai_response = {
      voice_characteristics: {
        tone: "professional",
        formality: "semi-formal",
        personality: "trusted advisor"
      },
      visual_guidelines: {
        primary_colors: [ "#1a365d", "#2b77ad", "#e2e8f0" ],
        typography: "Clean, modern sans-serif",
        imagery_style: "Professional photography with natural lighting"
      },
      messaging_framework: {
        key_messages: [ "Innovation through collaboration", "Trusted expertise", "Results-driven solutions" ],
        value_propositions: [ "Accelerated growth", "Strategic advantage", "Measurable outcomes" ],
        tone_guidelines: [ "Clear and confident", "Approachable but authoritative", "Solution-focused" ]
      },
      compliance_rules: {
        restrictions: [ "Avoid overly technical jargon", "No competitor mentions", "Maintain professional tone" ],
        requirements: [ "Include data backing claims", "Use approved color palette", "Follow brand voice guidelines" ]
      },
      brand_values: [ "Innovation", "Collaboration", "Excellence", "Integrity", "Customer Success" ]
    }

    # Extract characteristics from content
    extracted_characteristics = extract_brand_characteristics(content)

    # Calculate confidence score
    confidence = calculate_confidence_score(extracted_characteristics, ai_response)

    {
      characteristics: ai_response,
      confidence: confidence,
      extracted_patterns: extracted_characteristics
    }
  end

  def perform_multi_pass_analysis(content, initial_analysis)
    # Second pass with refined prompts
    refined_prompt = build_refined_analysis_prompt(content, initial_analysis)

    # Mock refined analysis
    refined_characteristics = initial_analysis[:characteristics].deep_merge({
      voice_characteristics: {
        confidence_level: "high",
        consistency_score: 0.92
      },
      compliance_rules: {
        validation_score: 0.95,
        completeness: "comprehensive"
      }
    })

    # Boost confidence for multi-pass
    improved_confidence = [ initial_analysis[:confidence] + 0.1, 1.0 ].min

    {
      characteristics: refined_characteristics,
      confidence: improved_confidence,
      extracted_patterns: initial_analysis[:extracted_patterns],
      multi_pass: true
    }
  end

  def build_analysis_prompt(content)
    <<~PROMPT
      Analyze the following brand content and extract comprehensive brand characteristics:

      Content: #{content.truncate(2000)}

      Please identify:
      1. Voice and tone characteristics
      2. Visual identity guidelines
      3. Messaging framework and key messages
      4. Brand values and personality traits
      5. Compliance rules and restrictions
      6. Typography and color specifications

      Provide structured JSON output with confidence indicators.
    PROMPT
  end

  def build_refined_analysis_prompt(content, initial_analysis)
    <<~PROMPT
      Refine the following brand analysis with additional detail and validation:

      Content: #{content.truncate(2000)}
      Initial Analysis: #{initial_analysis[:characteristics].to_json.truncate(1000)}

      Focus on:
      1. Improving accuracy of voice characteristics
      2. Validating compliance rules
      3. Ensuring completeness of guidelines
      4. Cross-referencing extracted patterns

      Provide enhanced JSON output with improved confidence.
    PROMPT
  end

  def store_analysis_results(brand_analysis, ai_analysis)
    brand_analysis.update!(
      analysis_data: ai_analysis[:characteristics],
      voice_attributes: ai_analysis[:characteristics][:voice_characteristics] || {},
      brand_values: ai_analysis[:characteristics][:brand_values] || [],
      messaging_pillars: ai_analysis[:characteristics][:messaging_framework][:key_messages] || [],
      visual_guidelines: ai_analysis[:characteristics][:visual_guidelines] || {},
      extracted_rules: ai_analysis[:characteristics][:compliance_rules] || {},
      analysis_notes: "Multi-pass analysis: #{ai_analysis[:multi_pass] || false}",
      confidence_score: ai_analysis[:confidence]
    )
  end
end
