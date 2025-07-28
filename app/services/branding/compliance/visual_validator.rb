module Branding
  module Compliance
    class VisualValidator < BaseValidator
      SUPPORTED_FORMATS = %w[image/jpeg image/png image/gif image/webp image/svg+xml].freeze
      
      COLOR_TOLERANCE = 15 # Delta E tolerance for color matching
      
      def initialize(brand, content, options = {})
        super
        @visual_data = options[:visual_data] || {}
        @llm_service = options[:llm_service] || LlmService.new
      end

      def validate
        return unless visual_content?
        
        # Validate colors
        check_color_compliance
        
        # Validate typography (if text is present)
        check_typography_compliance
        
        # Validate logo usage
        check_logo_compliance
        
        # Validate composition and layout
        check_composition_compliance
        
        # Validate image quality
        check_quality_standards
        
        # Check accessibility
        check_visual_accessibility
        
        { violations: @violations, suggestions: @suggestions }
      end

      def analyze_image(image_data)
        cached_result("visual_analysis:#{image_data[:id]}") do
          prompt = build_visual_analysis_prompt(image_data)
          
          response = @llm_service.analyze(prompt, {
            json_response: true,
            temperature: 0.3,
            system_message: "You are an expert visual brand compliance analyst."
          })
          
          parse_json_response(response)
        end
      end

      private

      def visual_content?
        @visual_data.present? || content_type_visual?
      end

      def content_type_visual?
        return false unless options[:content_type]
        
        %w[image video infographic logo banner].include?(options[:content_type])
      end

      def check_color_compliance
        return unless @visual_data[:colors].present?
        
        detected_colors = @visual_data[:colors]
        brand_colors = {
          primary: brand.primary_colors,
          secondary: brand.secondary_colors
        }
        
        # Check primary color usage
        primary_compliant = check_color_set_compliance(
          detected_colors[:primary] || [],
          brand_colors[:primary],
          "primary"
        )
        
        # Check secondary color usage
        secondary_compliant = check_color_set_compliance(
          detected_colors[:secondary] || [],
          brand_colors[:secondary],
          "secondary"
        )
        
        # Check color harmony
        check_color_harmony(detected_colors)
        
        # Check brand color dominance
        check_brand_color_dominance(detected_colors, brand_colors)
      end

      def check_color_set_compliance(detected_colors, brand_colors, color_type)
        return true if brand_colors.empty?
        
        non_compliant_colors = []
        
        detected_colors.each do |detected|
          unless color_matches_any?(detected, brand_colors)
            non_compliant_colors << detected
          end
        end
        
        if non_compliant_colors.any?
          add_violation(
            type: "color_violation",
            severity: color_type == "primary" ? "high" : "medium",
            message: "Non-brand #{color_type} colors detected",
            details: {
              non_compliant_colors: non_compliant_colors,
              expected_colors: brand_colors,
              color_type: color_type
            }
          )
          false
        else
          true
        end
      end

      def color_matches_any?(color, color_set)
        color_set.any? do |brand_color|
          color_distance(color, brand_color) <= COLOR_TOLERANCE
        end
      end

      def color_distance(color1, color2)
        # Calculate Delta E (CIE76) color distance
        lab1 = rgb_to_lab(parse_color(color1))
        lab2 = rgb_to_lab(parse_color(color2))
        
        Math.sqrt(
          (lab2[:l] - lab1[:l]) ** 2 +
          (lab2[:a] - lab1[:a]) ** 2 +
          (lab2[:b] - lab1[:b]) ** 2
        )
      end

      def parse_color(color)
        if color.start_with?('#')
          # Hex color
          hex = color.delete('#')
          {
            r: hex[0..1].to_i(16),
            g: hex[2..3].to_i(16),
            b: hex[4..5].to_i(16)
          }
        elsif color.start_with?('rgb')
          # RGB color
          matches = color.match(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/)
          {
            r: matches[1].to_i,
            g: matches[2].to_i,
            b: matches[3].to_i
          }
        else
          # Named color - would need a lookup table
          { r: 0, g: 0, b: 0 }
        end
      end

      def rgb_to_lab(rgb)
        # Convert RGB to XYZ
        r = rgb[:r] / 255.0
        g = rgb[:g] / 255.0
        b = rgb[:b] / 255.0
        
        # Gamma correction
        r = r > 0.04045 ? ((r + 0.055) / 1.055) ** 2.4 : r / 12.92
        g = g > 0.04045 ? ((g + 0.055) / 1.055) ** 2.4 : g / 12.92
        b = b > 0.04045 ? ((b + 0.055) / 1.055) ** 2.4 : b / 12.92
        
        # Observer = 2°, Illuminant = D65
        x = (r * 0.4124 + g * 0.3576 + b * 0.1805) * 100
        y = (r * 0.2126 + g * 0.7152 + b * 0.0722) * 100
        z = (r * 0.0193 + g * 0.1192 + b * 0.9505) * 100
        
        # Convert XYZ to Lab
        x = x / 95.047
        y = y / 100.000
        z = z / 108.883
        
        x = x > 0.008856 ? x ** (1.0/3.0) : (7.787 * x + 16.0/116.0)
        y = y > 0.008856 ? y ** (1.0/3.0) : (7.787 * y + 16.0/116.0)
        z = z > 0.008856 ? z ** (1.0/3.0) : (7.787 * z + 16.0/116.0)
        
        {
          l: (116 * y) - 16,
          a: 500 * (x - y),
          b: 200 * (y - z)
        }
      end

      def check_color_harmony(detected_colors)
        all_colors = (detected_colors[:primary] || []) + (detected_colors[:secondary] || [])
        return if all_colors.length < 2
        
        # Check for clashing colors
        clashing_pairs = []
        
        all_colors.combination(2).each do |color1, color2|
          if colors_clash?(color1, color2)
            clashing_pairs << [color1, color2]
          end
        end
        
        if clashing_pairs.any?
          add_violation(
            type: "color_harmony",
            severity: "low",
            message: "Color combinations may clash",
            details: {
              clashing_pairs: clashing_pairs,
              suggestion: "Consider adjusting color combinations for better harmony"
            }
          )
        end
      end

      def colors_clash?(color1, color2)
        # Simplified clash detection based on complementary colors
        lab1 = rgb_to_lab(parse_color(color1))
        lab2 = rgb_to_lab(parse_color(color2))
        
        # Check if colors are too similar (muddy) or complementary (potentially clashing)
        distance = color_distance(color1, color2)
        
        # Too similar but not identical
        (distance > 5 && distance < 20) ||
        # Complementary colors with high saturation
        (complementary_colors?(lab1, lab2) && high_saturation?(lab1) && high_saturation?(lab2))
      end

      def complementary_colors?(lab1, lab2)
        # Check if colors are roughly complementary
        hue_diff = (Math.atan2(lab1[:b], lab1[:a]) - Math.atan2(lab2[:b], lab2[:a])).abs
        hue_diff = hue_diff * 180 / Math::PI
        
        hue_diff > 150 && hue_diff < 210
      end

      def high_saturation?(lab)
        # Calculate chroma (saturation in Lab space)
        Math.sqrt(lab[:a] ** 2 + lab[:b] ** 2) > 50
      end

      def check_brand_color_dominance(detected_colors, brand_colors)
        return unless @visual_data[:color_percentages]
        
        brand_color_percentage = calculate_brand_color_percentage(
          detected_colors,
          brand_colors
        )
        
        if brand_color_percentage < 60
          add_violation(
            type: "brand_color_dominance",
            severity: "medium",
            message: "Brand colors not dominant enough",
            details: {
              brand_color_percentage: brand_color_percentage,
              recommendation: "Brand colors should comprise at least 60% of the visual"
            }
          )
        elsif brand_color_percentage < 70
          add_suggestion(
            type: "brand_color_enhancement",
            message: "Consider increasing brand color prominence",
            details: {
              current_percentage: brand_color_percentage,
              target_percentage: 70
            }
          )
        end
      end

      def calculate_brand_color_percentage(detected_colors, brand_colors)
        total_percentage = 0
        all_brand_colors = brand_colors[:primary] + brand_colors[:secondary]
        
        @visual_data[:color_percentages].each do |color, percentage|
          if color_matches_any?(color, all_brand_colors)
            total_percentage += percentage
          end
        end
        
        total_percentage
      end

      def check_typography_compliance
        return unless @visual_data[:typography].present?
        
        detected_fonts = @visual_data[:typography][:fonts] || []
        brand_fonts = brand.font_families
        
        non_compliant_fonts = detected_fonts - brand_fonts.values.flatten
        
        if non_compliant_fonts.any?
          add_violation(
            type: "typography_violation",
            severity: "medium",
            message: "Non-brand fonts detected",
            details: {
              non_compliant_fonts: non_compliant_fonts,
              brand_fonts: brand_fonts
            }
          )
        end
        
        # Check font hierarchy
        check_font_hierarchy(detected_fonts)
        
        # Check text legibility
        check_text_legibility
      end

      def check_font_hierarchy(detected_fonts)
        if detected_fonts.length > 3
          add_violation(
            type: "font_hierarchy",
            severity: "low",
            message: "Too many font variations",
            details: {
              font_count: detected_fonts.length,
              recommendation: "Limit to 2-3 font variations for better hierarchy"
            }
          )
        end
      end

      def check_text_legibility
        return unless @visual_data[:typography][:legibility_score]
        
        score = @visual_data[:typography][:legibility_score]
        
        if score < 0.6
          add_violation(
            type: "text_legibility",
            severity: "high",
            message: "Text legibility issues detected",
            details: {
              legibility_score: score,
              issues: @visual_data[:typography][:legibility_issues] || []
            }
          )
        elsif score < 0.8
          add_suggestion(
            type: "legibility_improvement",
            message: "Text legibility could be improved",
            details: {
              current_score: score,
              suggestions: suggest_legibility_improvements
            }
          )
        end
      end

      def check_logo_compliance
        return unless @visual_data[:logo].present?
        
        logo_data = @visual_data[:logo]
        
        # Check logo size
        check_logo_size(logo_data)
        
        # Check logo clear space
        check_logo_clear_space(logo_data)
        
        # Check logo placement
        check_logo_placement(logo_data)
        
        # Check logo modifications
        check_logo_integrity(logo_data)
      end

      def check_logo_size(logo_data)
        min_size = brand.brand_guidelines
                        .by_category("logo")
                        .find { |g| g.metadata&.dig("min_size") }
                        &.metadata&.dig("min_size") || 100
        
        if logo_data[:size] && logo_data[:size] < min_size
          add_violation(
            type: "logo_size",
            severity: "high",
            message: "Logo is below minimum size requirements",
            details: {
              current_size: logo_data[:size],
              minimum_size: min_size
            }
          )
        end
      end

      def check_logo_clear_space(logo_data)
        return unless logo_data[:clear_space_ratio]
        
        min_clear_space = 0.5 # Half the logo height/width
        
        if logo_data[:clear_space_ratio] < min_clear_space
          add_violation(
            type: "logo_clear_space",
            severity: "medium",
            message: "Insufficient clear space around logo",
            details: {
              current_ratio: logo_data[:clear_space_ratio],
              required_ratio: min_clear_space
            }
          )
        end
      end

      def check_logo_placement(logo_data)
        approved_placements = brand.brand_guidelines
                                  .by_category("logo")
                                  .find { |g| g.metadata&.dig("approved_placements") }
                                  &.metadata&.dig("approved_placements") || 
                                  ["top-left", "top-center", "center"]
        
        if logo_data[:placement] && !approved_placements.include?(logo_data[:placement])
          add_violation(
            type: "logo_placement",
            severity: "medium",
            message: "Logo placed in non-approved position",
            details: {
              current_placement: logo_data[:placement],
              approved_placements: approved_placements
            }
          )
        end
      end

      def check_logo_integrity(logo_data)
        if logo_data[:modified]
          modifications = logo_data[:modifications] || []
          
          add_violation(
            type: "logo_modification",
            severity: "critical",
            message: "Logo has been modified",
            details: {
              modifications: modifications,
              rule: "Logo must not be altered in any way"
            }
          )
        end
      end

      def check_composition_compliance
        return unless @visual_data[:composition]
        
        composition = @visual_data[:composition]
        
        # Check balance
        if composition[:balance_score] && composition[:balance_score] < 0.6
          add_suggestion(
            type: "composition_balance",
            message: "Visual composition could be better balanced",
            details: {
              balance_score: composition[:balance_score],
              suggestions: ["Redistribute visual weight", "Align elements to grid"]
            }
          )
        end
        
        # Check whitespace
        check_whitespace_usage(composition)
        
        # Check visual hierarchy
        check_visual_hierarchy(composition)
      end

      def check_whitespace_usage(composition)
        whitespace_ratio = composition[:whitespace_ratio] || 0
        
        if whitespace_ratio < 0.2
          add_violation(
            type: "whitespace_insufficient",
            severity: "medium",
            message: "Insufficient whitespace",
            details: {
              current_ratio: whitespace_ratio,
              recommendation: "Increase whitespace for better readability"
            }
          )
        elsif whitespace_ratio > 0.7
          add_suggestion(
            type: "whitespace_excessive",
            message: "Consider using space more efficiently",
            details: {
              current_ratio: whitespace_ratio
            }
          )
        end
      end

      def check_visual_hierarchy(composition)
        hierarchy_score = composition[:hierarchy_score] || 0
        
        if hierarchy_score < 0.5
          add_violation(
            type: "visual_hierarchy",
            severity: "medium",
            message: "Weak visual hierarchy",
            details: {
              hierarchy_score: hierarchy_score,
              issues: composition[:hierarchy_issues] || [],
              suggestions: [
                "Use size contrast for importance",
                "Apply consistent spacing",
                "Group related elements"
              ]
            }
          )
        end
      end

      def check_quality_standards
        return unless @visual_data[:quality]
        
        quality = @visual_data[:quality]
        
        # Check resolution
        if quality[:resolution] && quality[:resolution] < 72
          add_violation(
            type: "low_resolution",
            severity: "high",
            message: "Image resolution too low",
            details: {
              current_dpi: quality[:resolution],
              minimum_dpi: 72,
              recommendation: "Use images with at least 72 DPI for web, 300 DPI for print"
            }
          )
        end
        
        # Check compression artifacts
        if quality[:compression_score] && quality[:compression_score] < 0.7
          add_suggestion(
            type: "compression_quality",
            message: "Image shows compression artifacts",
            details: {
              quality_score: quality[:compression_score],
              recommendation: "Use higher quality compression settings"
            }
          )
        end
        
        # Check file size
        check_file_size_optimization(quality)
      end

      def check_file_size_optimization(quality)
        return unless quality[:file_size] && quality[:dimensions]
        
        # Calculate bytes per pixel
        total_pixels = quality[:dimensions][:width] * quality[:dimensions][:height]
        bytes_per_pixel = quality[:file_size].to_f / total_pixels
        
        # Rough guidelines for web images
        if bytes_per_pixel > 1.5
          add_suggestion(
            type: "file_size_optimization",
            message: "Image file size could be optimized",
            details: {
              current_size: quality[:file_size],
              bytes_per_pixel: bytes_per_pixel.round(2),
              recommendation: "Consider optimizing without quality loss"
            }
          )
        end
      end

      def check_visual_accessibility
        # Check color contrast
        check_color_contrast
        
        # Check for alt text (if applicable)
        check_alt_text
        
        # Check for motion/animation issues
        check_motion_accessibility
      end

      def check_color_contrast
        return unless @visual_data[:accessibility]
        
        contrast_issues = @visual_data[:accessibility][:contrast_issues] || []
        
        if contrast_issues.any?
          add_violation(
            type: "color_contrast",
            severity: "high",
            message: "Color contrast accessibility issues",
            details: {
              issues: contrast_issues,
              wcag_level: "AA",
              recommendation: "Ensure 4.5:1 contrast for normal text, 3:1 for large text"
            }
          )
        end
      end

      def check_alt_text
        return unless options[:requires_alt_text]
        
        if @visual_data[:alt_text].blank?
          add_violation(
            type: "missing_alt_text",
            severity: "high",
            message: "Missing alternative text for accessibility",
            details: {
              recommendation: "Add descriptive alt text for screen readers"
            }
          )
        elsif @visual_data[:alt_text].length < 10
          add_suggestion(
            type: "improve_alt_text",
            message: "Alt text could be more descriptive",
            details: {
              current_length: @visual_data[:alt_text].length,
              recommendation: "Provide meaningful description of the visual content"
            }
          )
        end
      end

      def check_motion_accessibility
        return unless @visual_data[:has_animation]
        
        animation_data = @visual_data[:animation] || {}
        
        if animation_data[:autoplay] && !animation_data[:has_pause_control]
          add_violation(
            type: "motion_control",
            severity: "medium",
            message: "Auto-playing animation without pause control",
            details: {
              recommendation: "Provide user controls for animations",
              wcag_guideline: "2.2.2 Pause, Stop, Hide"
            }
          )
        end
        
        if animation_data[:flashing_detected]
          add_violation(
            type: "flashing_content",
            severity: "critical",
            message: "Flashing content detected",
            details: {
              recommendation: "Remove flashing to prevent seizures",
              wcag_guideline: "2.3.1 Three Flashes or Below Threshold"
            }
          )
        end
      end

      def build_visual_analysis_prompt(image_data)
        <<~PROMPT
          Analyze this image for brand compliance based on these guidelines:
          
          Brand Colors:
          Primary: #{brand.primary_colors.to_json}
          Secondary: #{brand.secondary_colors.to_json}
          
          Brand Fonts:
          #{brand.font_families.to_json}
          
          Visual Guidelines:
          #{extract_visual_guidelines.to_json}
          
          Please analyze:
          1. Color usage and compliance
          2. Typography (if text is present)
          3. Logo usage and placement
          4. Overall composition and balance
          5. Brand consistency
          
          Return analysis in JSON format with detailed findings.
        PROMPT
      end

      def extract_visual_guidelines
        guidelines = {}
        
        %w[logo color typography composition].each do |category|
          category_guidelines = brand.brand_guidelines.by_category(category)
          guidelines[category] = category_guidelines.map do |g|
            {
              rule: g.rule_content,
              type: g.rule_type,
              mandatory: g.mandatory?
            }
          end
        end
        
        guidelines
      end

      def suggest_legibility_improvements
        [
          "Increase font size for body text",
          "Improve contrast between text and background",
          "Use simpler fonts for better readability",
          "Increase line spacing",
          "Avoid thin font weights for small text"
        ]
      end

      def parse_json_response(response)
        return nil if response.nil?
        
        begin
          JSON.parse(response, symbolize_names: true)
        rescue JSON::ParserError
          Rails.logger.error "Failed to parse visual analysis response"
          nil
        end
      end
    end
  end
end