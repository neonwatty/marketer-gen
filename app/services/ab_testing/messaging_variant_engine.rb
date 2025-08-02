module AbTesting
  class MessagingVariantEngine
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def generate_messaging_variants(base_messaging, variant_count = 3)
      variants = []

      variant_count.times do |index|
        variant = create_messaging_variant(base_messaging, index)
        variants << variant
      end

      variants
    end

    def analyze_message_sentiment(message_text)
      # Simplified sentiment analysis
      positive_words = %w[great amazing excellent wonderful fantastic outstanding superb]
      negative_words = %w[bad terrible awful horrible disappointing poor worst]

      words = message_text.downcase.split(/\W+/)
      positive_count = words.count { |word| positive_words.include?(word) }
      negative_count = words.count { |word| negative_words.include?(word) }

      total_sentiment_words = positive_count + negative_count
      return "neutral" if total_sentiment_words == 0

      sentiment_score = (positive_count - negative_count).to_f / total_sentiment_words

      case sentiment_score
      when 0.3..1.0 then "positive"
      when -1.0..-0.3 then "negative"
      else "neutral"
      end
    end

    def calculate_readability_score(text)
      # Simplified Flesch Reading Ease approximation
      return 0 if text.blank?

      sentences = text.split(/[.!?]+/).length
      words = text.split(/\s+/).length
      syllables = estimate_syllables(text)

      return 0 if sentences == 0 || words == 0

      avg_sentence_length = words.to_f / sentences
      avg_syllables_per_word = syllables.to_f / words

      # Simplified Flesch formula
      score = 206.835 - (1.015 * avg_sentence_length) - (84.6 * avg_syllables_per_word)
      [ [ score, 0 ].max, 100 ].min.round(1)
    end

    def identify_persuasion_techniques(message_text)
      techniques = []
      text_lower = message_text.downcase

      # Social proof
      social_proof_indicators = [ "customers love", "rated #1", "trusted by", "join thousands", "most popular" ]
      techniques << "social_proof" if social_proof_indicators.any? { |indicator| text_lower.include?(indicator) }

      # Urgency
      urgency_indicators = [ "limited time", "expires soon", "act now", "don't wait", "hurry" ]
      techniques << "urgency" if urgency_indicators.any? { |indicator| text_lower.include?(indicator) }

      # Scarcity
      scarcity_indicators = [ "only", "last chance", "limited", "exclusive", "while supplies last" ]
      techniques << "scarcity" if scarcity_indicators.any? { |indicator| text_lower.include?(indicator) }

      # Authority
      authority_indicators = [ "expert", "proven", "research shows", "studies confirm", "recommended by" ]
      techniques << "authority" if authority_indicators.any? { |indicator| text_lower.include?(indicator) }

      # Reciprocity
      reciprocity_indicators = [ "free", "bonus", "gift", "complimentary", "no obligation" ]
      techniques << "reciprocity" if reciprocity_indicators.any? { |indicator| text_lower.include?(indicator) }

      # Emotional appeal
      emotional_indicators = [ "feel", "imagine", "experience", "discover", "transform" ]
      techniques << "emotional_appeal" if emotional_indicators.any? { |indicator| text_lower.include?(indicator) }

      techniques.uniq
    end

    private

    def create_messaging_variant(base_messaging, index)
      variant_strategies = [
        { strategy: "benefit_focused", psychology: "value_driven" },
        { strategy: "urgency_driven", psychology: "fear_of_missing_out" },
        { strategy: "social_proof_heavy", psychology: "social_validation" },
        { strategy: "authority_based", psychology: "expert_credibility" },
        { strategy: "emotional_appeal", psychology: "emotional_connection" }
      ]

      strategy = variant_strategies[index % variant_strategies.length]

      transformed_messaging = transform_messaging(base_messaging, strategy)

      {
        primary_headline: transformed_messaging[:primary_headline],
        subheading: transformed_messaging[:subheading],
        cta_text: transformed_messaging[:cta_text],
        value_proposition: transformed_messaging[:value_proposition],
        sentiment_analysis: analyze_message_sentiment(transformed_messaging[:primary_headline]),
        readability_score: calculate_readability_score(transformed_messaging[:primary_headline]),
        persuasion_techniques: identify_persuasion_techniques("#{transformed_messaging[:primary_headline]} #{transformed_messaging[:subheading]}"),
        target_psychology_profile: strategy[:psychology],
        messaging_strategy: strategy[:strategy],
        predicted_performance: predict_messaging_performance(strategy)
      }
    end

    def transform_messaging(base_messaging, strategy)
      case strategy[:strategy]
      when "benefit_focused"
        transform_to_benefit_focused(base_messaging)
      when "urgency_driven"
        transform_to_urgency_driven(base_messaging)
      when "social_proof_heavy"
        transform_to_social_proof(base_messaging)
      when "authority_based"
        transform_to_authority_based(base_messaging)
      when "emotional_appeal"
        transform_to_emotional_appeal(base_messaging)
      else
        base_messaging
      end
    end

    def transform_to_benefit_focused(messaging)
      benefit_headlines = [
        "Increase Your #{extract_key_benefit(messaging[:primary_headline])} by 40%",
        "Get More #{extract_key_benefit(messaging[:primary_headline])} in Less Time",
        "Unlock the Power of #{extract_key_benefit(messaging[:primary_headline])}"
      ]

      {
        primary_headline: benefit_headlines.sample,
        subheading: "Discover how our solution delivers measurable results for your business",
        cta_text: "See Results Now",
        value_proposition: "Proven to increase efficiency by 40%"
      }
    end

    def transform_to_urgency_driven(messaging)
      urgency_headlines = [
        "Limited Time: #{messaging[:primary_headline]}",
        "Act Now - #{messaging[:primary_headline]} Expires Soon",
        "Don't Wait - #{messaging[:primary_headline]} Today Only"
      ]

      {
        primary_headline: urgency_headlines.sample,
        subheading: "This exclusive offer won't last long",
        cta_text: "Claim Now",
        value_proposition: "Limited time opportunity"
      }
    end

    def transform_to_social_proof(messaging)
      social_proof_headlines = [
        "Join 10,000+ Companies Who #{extract_action(messaging[:primary_headline])}",
        "Trusted by Industry Leaders: #{messaging[:primary_headline]}",
        "The #1 Choice for #{extract_target_audience(messaging[:primary_headline])}"
      ]

      {
        primary_headline: social_proof_headlines.sample,
        subheading: "See why thousands of customers choose us",
        cta_text: "Join Them Today",
        value_proposition: "Trusted by industry leaders"
      }
    end

    def transform_to_authority_based(messaging)
      authority_headlines = [
        "Expert-Recommended: #{messaging[:primary_headline]}",
        "Research-Proven #{messaging[:primary_headline]}",
        "Industry Expert's Choice: #{messaging[:primary_headline]}"
      ]

      {
        primary_headline: authority_headlines.sample,
        subheading: "Backed by research and recommended by experts",
        cta_text: "Get Expert Solution",
        value_proposition: "Expert-recommended solution"
      }
    end

    def transform_to_emotional_appeal(messaging)
      emotional_headlines = [
        "Transform Your Life with #{messaging[:primary_headline]}",
        "Experience the Joy of #{messaging[:primary_headline]}",
        "Feel Confident with #{messaging[:primary_headline]}"
      ]

      {
        primary_headline: emotional_headlines.sample,
        subheading: "Imagine how great it will feel to achieve your goals",
        cta_text: "Start Your Journey",
        value_proposition: "Transform your experience"
      }
    end

    def extract_key_benefit(headline)
      # Simplified benefit extraction
      benefit_words = %w[efficiency productivity growth sales revenue success results performance]
      words = headline.downcase.split(/\W+/)

      found_benefit = words.find { |word| benefit_words.include?(word) }
      found_benefit || "Success"
    end

    def extract_action(headline)
      # Simplified action extraction
      action_words = %w[transform grow improve increase boost optimize enhance succeed]
      words = headline.downcase.split(/\W+/)

      found_action = words.find { |word| action_words.include?(word) }
      found_action ? "#{found_action.capitalize} Their Business" : "Succeed"
    end

    def extract_target_audience(headline)
      # Simplified audience extraction
      audience_words = %w[business entrepreneur startup company professional marketer]
      words = headline.downcase.split(/\W+/)

      found_audience = words.find { |word| audience_words.include?(word) }
      found_audience ? found_audience.capitalize.pluralize : "Professionals"
    end

    def predict_messaging_performance(strategy)
      # Performance predictions based on strategy
      performance_data = {
        "benefit_focused" => { conversion_lift: 8.5, engagement_lift: 12.3, click_through_lift: 6.7 },
        "urgency_driven" => { conversion_lift: 15.2, engagement_lift: 8.9, click_through_lift: 18.4 },
        "social_proof_heavy" => { conversion_lift: 22.1, engagement_lift: 16.7, click_through_lift: 14.2 },
        "authority_based" => { conversion_lift: 11.8, engagement_lift: 13.5, click_through_lift: 9.1 },
        "emotional_appeal" => { conversion_lift: 18.9, engagement_lift: 25.4, click_through_lift: 16.8 }
      }

      performance_data[strategy[:strategy]] || { conversion_lift: 5.0, engagement_lift: 5.0, click_through_lift: 5.0 }
    end

    def estimate_syllables(text)
      # Simple syllable estimation
      return 0 if text.blank?

      words = text.downcase.split(/\W+/)
      total_syllables = 0

      words.each do |word|
        # Count vowel groups
        syllable_count = word.scan(/[aeiouy]+/).length
        # Adjust for silent e
        syllable_count -= 1 if word.end_with?("e") && syllable_count > 1
        # Ensure at least 1 syllable per word
        syllable_count = [ syllable_count, 1 ].max
        total_syllables += syllable_count
      end

      total_syllables
    end
  end
end
