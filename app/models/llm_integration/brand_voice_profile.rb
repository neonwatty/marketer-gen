module LlmIntegration
  class BrandVoiceProfile < ApplicationRecord
    self.table_name = "brand_voice_profiles"

    # Associations
    belongs_to :brand

    # Validations
    validates :brand, presence: true, uniqueness: true
    validates :voice_characteristics, presence: true
    validates :extracted_from_sources, presence: true
    validates :confidence_score, presence: true,
              numericality: {
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 1,
                message: "must be between 0 and 1"
              }
    validates :last_updated, presence: true
    validates :version, presence: true, numericality: { greater_than: 0 }
    validate :voice_characteristics_structure

    # Serialization
    serialize :voice_characteristics, coder: JSON
    serialize :extracted_from_sources, coder: JSON

    # Scopes
    scope :high_confidence, -> { where("confidence_score >= ?", 0.8) }
    scope :recent, -> { order(last_updated: :desc) }
    scope :by_version, ->(version) { where(version: version) }

    # Callbacks
    before_validation :set_defaults, on: :create
    before_update :increment_version_if_changed

    # Instance methods
    def primary_traits
      voice_characteristics.dig("primary_traits") || []
    end

    def tone_descriptors
      voice_characteristics.dig("tone_descriptors") || []
    end

    def communication_style
      voice_characteristics.dig("communication_style") || "balanced"
    end

    def brand_personality
      voice_characteristics.dig("brand_personality") || "professional"
    end

    def language_preferences
      voice_characteristics.dig("language_preferences") || {}
    end

    def update_voice_profile(new_characteristics)
      merged_characteristics = voice_characteristics.merge(new_characteristics)

      update!(
        voice_characteristics: merged_characteristics,
        last_updated: Time.current,
        confidence_score: calculate_confidence_score(merged_characteristics)
      )
    end

    def confidence_level
      case confidence_score
      when 0.9..1.0 then :very_high
      when 0.8..0.89 then :high
      when 0.7..0.79 then :medium
      when 0.6..0.69 then :moderate
      else :low
      end
    end

    def is_high_confidence?
      confidence_score >= 0.8
    end

    def needs_update?
      last_updated < 30.days.ago || confidence_score < 0.7
    end

    def voice_summary
      {
        primary_traits: primary_traits.join(", "),
        tone: tone_descriptors.join(", "),
        style: communication_style,
        personality: brand_personality,
        confidence: confidence_level,
        last_updated: last_updated.strftime("%B %d, %Y")
      }
    end

    def generate_prompt_instructions
      instructions = []

      if primary_traits.any?
        instructions << "Embody these brand traits: #{primary_traits.join(', ')}"
      end

      if tone_descriptors.any?
        instructions << "Use a tone that is: #{tone_descriptors.join(', ')}"
      end

      instructions << "Communication style: #{communication_style}"
      instructions << "Brand personality: #{brand_personality}"

      if language_preferences.any?
        lang_prefs = language_preferences.map { |k, v| "#{k}: #{v}" }.join(", ")
        instructions << "Language preferences: #{lang_prefs}"
      end

      instructions.join(". ") + "."
    end

    def similarity_score(other_profile)
      return 0.0 unless other_profile.is_a?(BrandVoiceProfile)

      trait_similarity = calculate_array_similarity(primary_traits, other_profile.primary_traits)
      tone_similarity = calculate_array_similarity(tone_descriptors, other_profile.tone_descriptors)
      style_similarity = communication_style == other_profile.communication_style ? 1.0 : 0.0
      personality_similarity = brand_personality == other_profile.brand_personality ? 1.0 : 0.0

      (trait_similarity * 0.4) + (tone_similarity * 0.3) + (style_similarity * 0.15) + (personality_similarity * 0.15)
    end

    def extract_keywords
      keywords = []
      keywords.concat(primary_traits)
      keywords.concat(tone_descriptors)
      keywords << communication_style
      keywords << brand_personality
      keywords.uniq.compact
    end

    private

    def set_defaults
      self.last_updated ||= Time.current
      self.version ||= 1
      self.confidence_score ||= 0.5
      self.extracted_from_sources ||= []
    end

    def voice_characteristics_structure
      return unless voice_characteristics.present?

      unless voice_characteristics.is_a?(Hash)
        errors.add(:voice_characteristics, "must be a hash")
        return
      end

      required_keys = %w[primary_traits tone_descriptors communication_style brand_personality]

      required_keys.each do |key|
        unless voice_characteristics.key?(key)
          errors.add(:voice_characteristics, "must include #{key}")
        end
      end

      # Validate array fields
      %w[primary_traits tone_descriptors].each do |key|
        next unless voice_characteristics[key]

        unless voice_characteristics[key].is_a?(Array)
          errors.add(:voice_characteristics, "#{key} must be an array")
        end
      end
    end

    def increment_version_if_changed
      if voice_characteristics_changed?
        self.version = (version || 0) + 1
        self.last_updated = Time.current
      end
    end

    def calculate_confidence_score(characteristics)
      # Calculate confidence based on completeness and specificity
      base_score = 0.5

      # Add points for completeness
      required_fields = %w[primary_traits tone_descriptors communication_style brand_personality]
      complete_fields = required_fields.count { |field| characteristics[field].present? }
      completeness_score = (complete_fields.to_f / required_fields.length) * 0.3

      # Add points for specificity
      trait_count = characteristics.dig("primary_traits")&.length || 0
      tone_count = characteristics.dig("tone_descriptors")&.length || 0
      specificity_score = [ (trait_count + tone_count) * 0.05, 0.2 ].min

      [ base_score + completeness_score + specificity_score, 1.0 ].min
    end

    def calculate_array_similarity(array1, array2)
      return 0.0 if array1.empty? && array2.empty?
      return 0.0 if array1.empty? || array2.empty?

      intersection = (array1 & array2).length
      union = (array1 | array2).length

      intersection.to_f / union
    end
  end
end
