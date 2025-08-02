class MessagingFramework < ApplicationRecord
  belongs_to :brand

  # Validations
  validates :brand, presence: true, uniqueness: { scope: :active, if: :active? }

  # Scopes
  scope :active, -> { where(active: true) }

  # Callbacks
  before_save :ensure_arrays_for_lists

  # Methods
  def add_key_message(category, message)
    self.key_messages ||= {}
    self.key_messages[category] ||= []
    self.key_messages[category] << message unless self.key_messages[category].include?(message)
    save
  end

  def add_value_proposition(proposition)
    self.value_propositions ||= {}
    self.value_propositions["main"] ||= []
    self.value_propositions["main"] << proposition unless self.value_propositions["main"].include?(proposition)
    save
  end

  def add_approved_phrase(phrase)
    self.approved_phrases ||= []
    self.approved_phrases << phrase unless self.approved_phrases.include?(phrase)
    save
  end

  def add_banned_word(word)
    self.banned_words ||= []
    self.banned_words << word.downcase unless self.banned_words.include?(word.downcase)
    save
  end

  def remove_banned_word(word)
    self.banned_words ||= []
    self.banned_words.delete(word.downcase)
    save
  end

  def is_word_banned?(word)
    return false if banned_words.blank?
    banned_words.include?(word.downcase)
  end

  def contains_banned_words?(text)
    return false if banned_words.blank?
    words = text.downcase.split(/\W+/)
    (words & banned_words).any?
  end

  def get_banned_words_in_text(text)
    return [] if banned_words.blank?
    words = text.downcase.split(/\W+/)
    words & banned_words
  end

  def tone_formal?
    tone_attributes["formality"] == "formal"
  end

  def tone_casual?
    tone_attributes["formality"] == "casual"
  end

  def tone_professional?
    tone_attributes["style"] == "professional"
  end

  def tone_friendly?
    tone_attributes["style"] == "friendly"
  end

  # Real-time validation methods
  def validate_message_realtime(content)
    return { validation_score: 0.0, error: "Content cannot be empty" } if content.blank?
    
    start_time = Time.current
    
    # Basic validation score calculation
    score = calculate_base_score(content)
    
    # Check for banned words
    banned_word_violations = get_banned_words_in_text(content)
    score -= banned_word_violations.length * 0.1  # Reduce penalty to be less severe
    
    # Check tone alignment
    tone_score = calculate_tone_alignment(content)
    score = (score + tone_score) / 2
    
    # Ensure score is between 0 and 1
    score = [[score, 0.0].max, 1.0].min
    
    processing_time = Time.current - start_time
    
    {
      validation_score: score.round(2),
      processing_time: processing_time,
      rule_violations: banned_word_violations.map { |word| "Banned word: #{word}" },
      suggestions: generate_suggestions(content, score)
    }
  end

  def validate_journey_step(journey_step)
    return { approved_for_journey: false, error: "Invalid journey step" } unless journey_step
    
    content_text = extract_content_text(journey_step)
    validation = validate_message_realtime(content_text)
    
    {
      approved_for_journey: validation[:validation_score] >= 0.7,
      validation_score: validation[:validation_score],
      violations: validation[:rule_violations],
      suggestions: validation[:suggestions]
    }
  end

  private

  def ensure_arrays_for_lists
    self.approved_phrases = [] if approved_phrases.nil?
    self.banned_words = [] if banned_words.nil?
  end

  def calculate_base_score(content)
    # Start with a base score
    score = 0.8
    
    # Adjust based on approved phrases usage
    if approved_phrases.present?
      approved_count = approved_phrases.count { |phrase| content.downcase.include?(phrase.downcase) }
      score += (approved_count * 0.1)
    end
    
    score
  end

  def calculate_tone_alignment(content)
    return 0.7 unless tone_attributes.present?
    
    # Simple tone analysis based on word choice and structure
    score = 0.7
    
    if tone_professional?
      # Check for professional language indicators
      professional_indicators = ['pleased', 'committed', 'deliver', 'excellence', 'innovative']
      professional_count = professional_indicators.count { |word| content.downcase.include?(word) }
      score += professional_count * 0.05
      
      # Penalize casual language
      casual_words = ['hey', 'guys', 'awesome', 'totally', 'like']
      casual_count = casual_words.count { |word| content.downcase.include?(word) }
      score -= casual_count * 0.2  # Keep higher penalty for casual language
    end
    
    if tone_formal?
      # Reward formal structure
      score += 0.1 if content.include?('.')
      score -= 0.1 if content.include?('!')
    end
    
    [[score, 0.0].max, 1.0].min
  end

  def generate_suggestions(content, score)
    suggestions = []
    
    if score < 0.7
      if contains_banned_words?(content)
        suggestions << "Remove or replace banned words: #{get_banned_words_in_text(content).join(', ')}"
      end
      
      if tone_professional? && content.downcase.match(/hey|guys|awesome|totally/)
        suggestions << "Use more professional language to match brand tone"
      end
      
      if approved_phrases.present?
        suggestions << "Consider incorporating approved phrases: #{approved_phrases.sample(2).join(', ')}"
      end
    end
    
    suggestions
  end

  def extract_content_text(journey_step)
    text_parts = []
    
    # Get text from description
    text_parts << journey_step.description if journey_step.description.present?
    
    # Get text from config hash
    config = journey_step.config || {}
    text_parts << config['subject'] if config['subject'].present?
    text_parts << config['body'] if config['body'].present?
    text_parts << config['title'] if config['title'].present?
    text_parts << config['description'] if config['description'].present?
    
    text_parts.join(' ').strip
  end
end
