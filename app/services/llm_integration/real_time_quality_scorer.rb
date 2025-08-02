module LlmIntegration
  class RealTimeQualityScorer
    include ActiveModel::Model

    def initialize(brand = nil)
      @brand = brand
      @scoring_cache = {}
      @quality_weights = {
        brand_compliance: 0.25,
        readability: 0.20,
        engagement_potential: 0.20,
        conversion_potential: 0.15,
        originality: 0.10,
        technical_quality: 0.10
      }
    end

    def score_content(content, brand = nil, options = {})
      cache_key = generate_cache_key(content, brand, options)

      # Return cached result if available and fresh
      if @scoring_cache[cache_key] && cache_fresh?(cache_key)
        return @scoring_cache[cache_key]
      end

      # Calculate comprehensive quality score
      quality_scores = {
        brand_compliance: score_brand_compliance(content, brand),
        readability: score_readability(content),
        engagement_potential: score_engagement_potential(content),
        conversion_potential: score_conversion_potential(content),
        originality: score_originality(content),
        technical_quality: score_technical_quality(content)
      }

      overall_score = calculate_weighted_score(quality_scores)

      result = {
        overall_score: overall_score,
        component_scores: quality_scores,
        quality_grade: determine_quality_grade(overall_score),
        improvement_suggestions: generate_improvement_suggestions(quality_scores),
        confidence_level: calculate_confidence_level(quality_scores),
        scoring_timestamp: Time.current,
        cache_key: cache_key
      }

      # Cache the result
      @scoring_cache[cache_key] = result

      result
    end

    def score_content_real_time(content, brand = nil)
      # Fast scoring for real-time feedback
      quick_scores = {
        brand_compliance: quick_brand_check(content, brand),
        readability: quick_readability_check(content),
        engagement: quick_engagement_check(content),
        technical: quick_technical_check(content)
      }

      overall = (quick_scores.values.sum / quick_scores.length).round(2)

      {
        overall_score: overall,
        component_scores: quick_scores,
        feedback_type: "real_time",
        suggestions: generate_quick_suggestions(quick_scores),
        timestamp: Time.current
      }
    end

    def batch_score_content(content_items, brand = nil)
      results = {}

      content_items.each_with_index do |content, index|
        key = "item_#{index}"
        results[key] = score_content(content, brand)
      end

      # Add batch analysis
      results[:batch_analysis] = analyze_batch_quality(results.values)

      results
    end

    def get_quality_trends(content_history)
      return { trend: "insufficient_data" } if content_history.length < 3

      scores = content_history.map { |item| score_content(item[:content], item[:brand])[:overall_score] }

      {
        trend_direction: determine_trend_direction(scores),
        average_score: (scores.sum / scores.length).round(2),
        score_variance: calculate_variance(scores),
        improvement_rate: calculate_improvement_rate(scores),
        quality_consistency: assess_quality_consistency(scores)
      }
    end

    def benchmark_against_industry(content, industry, content_type)
      content_score = score_content(content)
      industry_benchmarks = get_industry_benchmarks(industry, content_type)

      {
        content_score: content_score[:overall_score],
        industry_average: industry_benchmarks[:average],
        industry_percentile: calculate_percentile(content_score[:overall_score], industry_benchmarks),
        competitive_position: determine_competitive_position(content_score[:overall_score], industry_benchmarks),
        improvement_to_top_quartile: calculate_improvement_needed(content_score[:overall_score], industry_benchmarks[:top_quartile])
      }
    end

    private

    def score_brand_compliance(content, brand)
      return 0.7 unless brand # Default score if no brand provided

      # Use existing brand compliance checker
      begin
        compliance_checker = BrandComplianceChecker.new
        result = compliance_checker.check_compliance(content, brand)
        result[:overall_score] || 0.7
      rescue => e
        Rails.logger.warn "Brand compliance scoring failed: #{e.message}"
        0.7
      end
    end

    def score_readability(content)
      return 0 if content.blank?

      # Calculate multiple readability metrics
      flesch_score = calculate_flesch_reading_ease(content)
      sentence_complexity = analyze_sentence_complexity(content)
      vocabulary_complexity = analyze_vocabulary_complexity(content)

      # Combine metrics (Flesch is primary, others are modifiers)
      base_score = normalize_flesch_score(flesch_score)
      complexity_penalty = (sentence_complexity + vocabulary_complexity) / 2 * 0.2

      [ base_score - complexity_penalty, 0 ].max
    end

    def score_engagement_potential(content)
      return 0 if content.blank?

      # Analyze engagement factors
      emotional_appeal = analyze_emotional_content(content)
      question_usage = analyze_question_usage(content)
      action_orientation = analyze_action_orientation(content)
      story_elements = analyze_story_elements(content)
      social_triggers = analyze_social_triggers(content)

      # Weight different factors
      engagement_score = (
        emotional_appeal * 0.25 +
        question_usage * 0.15 +
        action_orientation * 0.25 +
        story_elements * 0.20 +
        social_triggers * 0.15
      )

      [ engagement_score, 1.0 ].min
    end

    def score_conversion_potential(content)
      return 0 if content.blank?

      # Analyze conversion factors
      cta_strength = analyze_cta_strength(content)
      value_proposition_clarity = analyze_value_proposition(content)
      urgency_creation = analyze_urgency_signals(content)
      trust_signals = analyze_trust_signals(content)
      objection_handling = analyze_objection_handling(content)

      # Weight conversion factors
      conversion_score = (
        cta_strength * 0.30 +
        value_proposition_clarity * 0.25 +
        urgency_creation * 0.15 +
        trust_signals * 0.15 +
        objection_handling * 0.15
      )

      [ conversion_score, 1.0 ].min
    end

    def score_originality(content)
      return 0 if content.blank?

      # Simple originality checks
      cliche_count = count_cliches(content)
      unique_phrases = count_unique_phrases(content)
      creativity_indicators = analyze_creativity_indicators(content)

      # Base score modified by creativity and cliches
      base_score = 0.7
      cliche_penalty = cliche_count * 0.1
      creativity_boost = creativity_indicators * 0.2

      [ [ base_score - cliche_penalty + creativity_boost, 0 ].max, 1.0 ].min
    end

    def score_technical_quality(content)
      return 0 if content.blank?

      # Technical quality checks
      spelling_accuracy = check_spelling_accuracy(content)
      grammar_quality = check_grammar_quality(content)
      punctuation_correctness = check_punctuation(content)
      formatting_consistency = check_formatting(content)

      # Average technical scores
      technical_scores = [ spelling_accuracy, grammar_quality, punctuation_correctness, formatting_consistency ]
      technical_scores.sum / technical_scores.length
    end

    # Quick scoring methods for real-time feedback
    def quick_brand_check(content, brand)
      return 0.7 unless brand

      # Basic brand keyword presence
      brand_terms = extract_brand_terms(brand)
      term_presence = brand_terms.count { |term| content.downcase.include?(term.downcase) }

      term_presence > 0 ? 0.8 : 0.6
    end

    def quick_readability_check(content)
      words = content.split
      avg_word_length = words.map(&:length).sum.to_f / words.length

      # Simple readability based on word length
      case avg_word_length
      when 0..4 then 0.9
      when 4..6 then 0.8
      when 6..8 then 0.6
      else 0.4
      end
    end

    def quick_engagement_check(content)
      engagement_words = %w[you your discover amazing new exclusive limited special]
      question_count = content.count("?")

      engagement_score = 0.5
      engagement_score += engagement_words.count { |word| content.downcase.include?(word) } * 0.05
      engagement_score += question_count * 0.1

      [ engagement_score, 1.0 ].min
    end

    def quick_technical_check(content)
      # Basic checks
      has_spelling_errors = content.match?(/\b(?:teh|recieve|seperate|definately)\b/i)
      has_double_spaces = content.include?("  ")
      proper_capitalization = content.match?(/^[A-Z]/)

      score = 0.8
      score -= 0.2 if has_spelling_errors
      score -= 0.1 if has_double_spaces
      score -= 0.1 unless proper_capitalization

      [ score, 0 ].max
    end

    def calculate_weighted_score(quality_scores)
      weighted_sum = @quality_weights.sum do |component, weight|
        (quality_scores[component] || 0.5) * weight
      end

      weighted_sum.round(3)
    end

    def determine_quality_grade(score)
      case score
      when 0.9..1.0 then "A"
      when 0.8..0.9 then "B"
      when 0.7..0.8 then "C"
      when 0.6..0.7 then "D"
      else "F"
      end
    end

    def generate_improvement_suggestions(quality_scores)
      suggestions = []

      quality_scores.each do |component, score|
        next if score >= 0.8 # Good scores don't need improvement

        case component
        when :brand_compliance
          suggestions << "Review brand guidelines and adjust tone/messaging"
        when :readability
          suggestions << "Simplify language and shorten sentences"
        when :engagement_potential
          suggestions << "Add more engaging elements like questions or stories"
        when :conversion_potential
          suggestions << "Strengthen call-to-action and value proposition"
        when :originality
          suggestions << "Use more unique language and avoid cliches"
        when :technical_quality
          suggestions << "Review for spelling, grammar, and formatting issues"
        end
      end

      suggestions
    end

    def calculate_confidence_level(quality_scores)
      # Higher confidence when scores are consistent
      score_variance = calculate_variance(quality_scores.values)
      base_confidence = 0.8

      # Lower confidence for high variance
      confidence_adjustment = score_variance > 0.1 ? -0.2 : 0.1

      [ base_confidence + confidence_adjustment, 1.0 ].min
    end

    # Helper methods for detailed analysis
    def calculate_flesch_reading_ease(content)
      words = content.split.length
      sentences = content.split(/[.!?]+/).length
      syllables = content.split.sum { |word| count_syllables(word) }

      return 50 if sentences == 0 || words == 0

      206.835 - (1.015 * (words.to_f / sentences)) - (84.6 * (syllables.to_f / words))
    end

    def count_syllables(word)
      word.downcase.scan(/[aeiouy]+/).length
    end

    def normalize_flesch_score(flesch_score)
      # Convert Flesch score (0-100) to 0-1 scale
      # 60+ is good readability
      case flesch_score
      when 80..100 then 1.0
      when 60..80 then 0.8
      when 40..60 then 0.6
      when 20..40 then 0.4
      else 0.2
      end
    end

    def analyze_sentence_complexity(content)
      sentences = content.split(/[.!?]+/)
      return 0 if sentences.empty?

      avg_sentence_length = sentences.map { |s| s.split.length }.sum.to_f / sentences.length

      # Penalty for very long sentences
      avg_sentence_length > 20 ? 0.8 : 0.2
    end

    def analyze_vocabulary_complexity(content)
      words = content.downcase.split
      complex_words = words.count { |word| word.length > 6 }

      return 0 if words.empty?

      complexity_ratio = complex_words.to_f / words.length
      complexity_ratio > 0.3 ? 0.8 : 0.2
    end

    def analyze_emotional_content(content)
      emotional_words = %w[love hate excited thrilled amazed shocked surprised delighted frustrated angry happy sad]
      words = content.downcase.split

      emotional_count = emotional_words.count { |emotion| words.include?(emotion) }
      [ emotional_count.to_f / words.length * 10, 1.0 ].min
    end

    def analyze_question_usage(content)
      question_count = content.count("?")
      word_count = content.split.length

      return 0 if word_count == 0

      # Optimal question ratio is around 1 question per 50 words
      question_ratio = question_count.to_f / (word_count / 50.0)

      case question_ratio
      when 0.5..2.0 then 1.0
      when 0.2..0.5, 2.0..3.0 then 0.7
      else 0.3
      end
    end

    def analyze_action_orientation(content)
      action_words = %w[discover explore try start begin join create build learn grow achieve unlock]
      imperative_patterns = [ "click", "download", "sign up", "get started", "learn more" ]

      words = content.downcase.split

      action_count = action_words.count { |word| words.include?(word) }
      imperative_count = imperative_patterns.count { |pattern| content.downcase.include?(pattern) }

      total_action_score = (action_count + imperative_count * 2).to_f / words.length * 20
      [ total_action_score, 1.0 ].min
    end

    def analyze_story_elements(content)
      story_indicators = %w[when then suddenly after before during while meanwhile story example case]
      words = content.downcase.split

      story_count = story_indicators.count { |indicator| words.include?(indicator) }
      [ story_count.to_f / words.length * 15, 1.0 ].min
    end

    def analyze_social_triggers(content)
      social_words = %w[people everyone others community together share join connect network]
      social_count = social_words.count { |word| content.downcase.include?(word) }

      [ social_count.to_f * 0.1, 1.0 ].min
    end

    def analyze_cta_strength(content)
      strong_ctas = [ "buy now", "get started", "sign up today", "download now", "call now" ]
      medium_ctas = [ "learn more", "contact us", "find out", "discover" ]
      weak_ctas = [ "click here", "more info" ]

      cta_score = 0
      cta_score += strong_ctas.count { |cta| content.downcase.include?(cta) } * 0.8
      cta_score += medium_ctas.count { |cta| content.downcase.include?(cta) } * 0.5
      cta_score += weak_ctas.count { |cta| content.downcase.include?(cta) } * 0.2

      [ cta_score, 1.0 ].min
    end

    def analyze_value_proposition(content)
      value_words = %w[benefit save time money free exclusive unique best solution results proven guaranteed]
      value_count = value_words.count { |word| content.downcase.include?(word) }

      [ value_count.to_f * 0.1, 1.0 ].min
    end

    def analyze_urgency_signals(content)
      urgency_words = %w[now today limited time offer expires deadline hurry quick fast immediate]
      urgency_count = urgency_words.count { |word| content.downcase.include?(word) }

      [ urgency_count.to_f * 0.15, 1.0 ].min
    end

    def analyze_trust_signals(content)
      trust_words = %w[guarantee secure safe trusted verified certified proven testimonial review award]
      trust_count = trust_words.count { |word| content.downcase.include?(word) }

      [ trust_count.to_f * 0.2, 1.0 ].min
    end

    def analyze_objection_handling(content)
      objection_phrases = [ "you might think", "but what if", "some people say", "however", "actually", "in fact" ]
      objection_count = objection_phrases.count { |phrase| content.downcase.include?(phrase) }

      [ objection_count.to_f * 0.3, 1.0 ].min
    end

    def count_cliches(content)
      cliches = [ "think outside the box", "low hanging fruit", "paradigm shift", "game changer", "revolutionary" ]
      cliches.count { |cliche| content.downcase.include?(cliche) }
    end

    def count_unique_phrases(content)
      # Simplified uniqueness check
      phrases = content.split(/[.!?]+/)
      unique_elements = phrases.count { |phrase| phrase.split.length > 3 && !phrase.match?(/\b(the|and|or|but|in|on|at|to|for|of|with)\b.*\b(the|and|or|but|in|on|at|to|for|of|with)\b/) }

      phrases.empty? ? 0 : unique_elements.to_f / phrases.length
    end

    def analyze_creativity_indicators(content)
      creative_elements = 0

      # Check for metaphors (simplified)
      metaphor_words = %w[like as similar metaphor bridge journey path mountain ocean]
      creative_elements += metaphor_words.count { |word| content.downcase.include?(word) } * 0.1

      # Check for unique word combinations
      words = content.split
      if words.length > 10
        unique_combinations = words.each_cons(2).count { |pair| !common_word_pair?(pair) }
        creative_elements += unique_combinations.to_f / words.length
      end

      [ creative_elements, 1.0 ].min
    end

    def common_word_pair?(pair)
      common_pairs = [ [ "the", "best" ], [ "and", "the" ], [ "of", "the" ], [ "in", "the" ] ]
      common_pairs.include?(pair.map(&:downcase))
    end

    # Technical quality methods
    def check_spelling_accuracy(content)
      # Simplified spell check
      common_misspellings = [ "teh", "recieve", "seperate", "definately", "occured" ]
      misspelling_count = common_misspellings.count { |word| content.downcase.include?(word) }

      words_count = content.split.length
      return 1.0 if words_count == 0

      error_rate = misspelling_count.to_f / words_count
      [ 1.0 - error_rate * 10, 0 ].max
    end

    def check_grammar_quality(content)
      # Basic grammar checks
      grammar_issues = 0

      # Check for double spaces
      grammar_issues += content.scan(/\s{2,}/).length

      # Check for missing spaces after punctuation
      grammar_issues += content.scan(/[.!?][A-Za-z]/).length

      # Check for lowercase sentence starts
      sentences = content.split(/[.!?]+/)
      grammar_issues += sentences.count { |s| s.strip.match?(/^[a-z]/) }

      return 1.0 if content.split.empty?

      error_rate = grammar_issues.to_f / content.split.length
      [ 1.0 - error_rate * 5, 0 ].max
    end

    def check_punctuation(content)
      # Check for proper punctuation usage
      punctuation_score = 1.0

      # Penalty for multiple exclamation marks
      punctuation_score -= content.scan(/!{2,}/).length * 0.1

      # Penalty for missing punctuation at end
      unless content.strip.match?(/[.!?]$/)
        punctuation_score -= 0.2
      end

      [ punctuation_score, 0 ].max
    end

    def check_formatting(content)
      # Basic formatting consistency
      formatting_score = 1.0

      # Check for consistent spacing
      if content.include?("  ") # Double spaces
        formatting_score -= 0.2
      end

      # Check for proper capitalization
      unless content.match?(/^[A-Z]/)
        formatting_score -= 0.1
      end

      [ formatting_score, 0 ].max
    end

    # Utility methods
    def generate_cache_key(content, brand, options)
      content_hash = Digest::MD5.hexdigest(content.to_s)
      brand_id = brand&.id || "no_brand"
      options_hash = Digest::MD5.hexdigest(options.to_s)

      "quality_score_#{content_hash}_#{brand_id}_#{options_hash}"
    end

    def cache_fresh?(cache_key)
      cached_result = @scoring_cache[cache_key]
      return false unless cached_result

      # Cache is fresh for 1 hour
      cached_result[:scoring_timestamp] > 1.hour.ago
    end

    def extract_brand_terms(brand)
      terms = [ brand.name ]

      if brand.respond_to?(:brand_voice_profiles) && brand.brand_voice_profiles.exists?
        profile = brand.brand_voice_profiles.first
        terms.concat(profile.primary_traits || [])
      end

      terms.compact.uniq
    end

    def generate_quick_suggestions(quick_scores)
      suggestions = []

      quick_scores.each do |component, score|
        next if score >= 0.7

        case component
        when :brand_compliance
          suggestions << "Consider incorporating brand-specific language"
        when :readability
          suggestions << "Try shorter, simpler words"
        when :engagement
          suggestions << "Add questions or action words"
        when :technical
          suggestions << "Check spelling and formatting"
        end
      end

      suggestions
    end

    def analyze_batch_quality(results)
      scores = results.map { |r| r[:overall_score] }

      {
        average_quality: (scores.sum / scores.length).round(2),
        quality_range: { min: scores.min, max: scores.max },
        consistency: calculate_variance(scores) < 0.1 ? "high" : "low",
        improvement_recommendations: generate_batch_recommendations(results)
      }
    end

    def determine_trend_direction(scores)
      return "stable" if scores.length < 3

      recent_avg = scores.last(3).sum / 3.0
      earlier_avg = scores.first(3).sum / 3.0

      if recent_avg > earlier_avg + 0.05
        "improving"
      elsif recent_avg < earlier_avg - 0.05
        "declining"
      else
        "stable"
      end
    end

    def calculate_variance(values)
      return 0 if values.empty?

      mean = values.sum.to_f / values.length
      variance = values.sum { |v| (v - mean) ** 2 } / values.length
      Math.sqrt(variance)
    end

    def calculate_improvement_rate(scores)
      return 0 if scores.length < 2

      ((scores.last - scores.first) / scores.first * 100).round(2)
    end

    def assess_quality_consistency(scores)
      variance = calculate_variance(scores)

      case variance
      when 0..0.05 then "very_consistent"
      when 0.05..0.1 then "consistent"
      when 0.1..0.2 then "moderate"
      else "inconsistent"
      end
    end

    def get_industry_benchmarks(industry, content_type)
      # Simplified industry benchmarks
      benchmarks = {
        "technology" => { average: 0.75, top_quartile: 0.85 },
        "healthcare" => { average: 0.78, top_quartile: 0.88 },
        "finance" => { average: 0.72, top_quartile: 0.82 },
        "retail" => { average: 0.70, top_quartile: 0.80 }
      }

      benchmarks[industry.downcase] || { average: 0.70, top_quartile: 0.80 }
    end

    def calculate_percentile(score, benchmarks)
      # Simplified percentile calculation
      if score >= benchmarks[:top_quartile]
        90
      elsif score >= benchmarks[:average]
        60
      else
        30
      end
    end

    def determine_competitive_position(score, benchmarks)
      if score >= benchmarks[:top_quartile]
        "leader"
      elsif score >= benchmarks[:average]
        "competitive"
      else
        "below_average"
      end
    end

    def calculate_improvement_needed(current_score, target_score)
      return 0 if current_score >= target_score

      ((target_score - current_score) * 100).round(2)
    end

    def generate_batch_recommendations(results)
      # Analyze common issues across batch
      common_issues = Hash.new(0)

      results.each do |result|
        result[:improvement_suggestions].each do |suggestion|
          common_issues[suggestion] += 1
        end
      end

      # Return most common issues
      common_issues.sort_by { |_, count| -count }.first(3).map(&:first)
    end
  end
end
