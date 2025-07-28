class BrandAnalysis < ApplicationRecord
  belongs_to :brand

  # Constants
  ANALYSIS_STATUSES = %w[pending processing completed failed].freeze

  # Validations
  validates :analysis_status, inclusion: { in: ANALYSIS_STATUSES }
  validates :confidence_score, numericality: { in: 0..1 }, allow_nil: true

  # Scopes
  scope :completed, -> { where(analysis_status: "completed") }
  scope :recent, -> { order(created_at: :desc) }
  scope :high_confidence, -> { where("confidence_score >= ?", 0.8) }

  # Callbacks
  before_validation :set_defaults

  # Methods
  def completed?
    analysis_status == "completed"
  end

  def processing?
    analysis_status == "processing"
  end

  def failed?
    analysis_status == "failed"
  end

  def mark_as_processing!
    update!(analysis_status: "processing")
  end

  def mark_as_completed!(confidence: nil)
    update!(
      analysis_status: "completed",
      analyzed_at: Time.current,
      confidence_score: confidence
    )
  end

  def mark_as_failed!(error_message = nil)
    update!(
      analysis_status: "failed",
      analysis_notes: error_message
    )
  end

  def voice_formality
    voice_attributes.dig("formality", "level") || "neutral"
  end

  def voice_tone
    voice_attributes.dig("tone", "primary") || "professional"
  end

  def primary_brand_values
    brand_values.first(3)
  end

  def has_visual_guidelines?
    visual_guidelines.present? && visual_guidelines.any?
  end

  def color_palette
    visual_guidelines.dig("colors") || {}
  end

  def typography_rules
    visual_guidelines.dig("typography") || {}
  end

  private

  def set_defaults
    self.analysis_data ||= {}
    self.extracted_rules ||= {}
    self.voice_attributes ||= {}
    self.brand_values ||= []
    self.messaging_pillars ||= []
    self.visual_guidelines ||= {}
  end
end
