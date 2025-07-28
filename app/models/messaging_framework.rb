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

  private

  def ensure_arrays_for_lists
    self.approved_phrases = [] if approved_phrases.nil?
    self.banned_words = [] if banned_words.nil?
  end
end
