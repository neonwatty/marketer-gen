class AbTestResult < ApplicationRecord
  belongs_to :ab_test

  validates :event_type, presence: true
  validates :value, presence: true, numericality: true
  validates :confidence, presence: true, numericality: { in: 0..100 }

  scope :by_event_type, ->(type) { where(event_type: type) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_high_confidence, -> { where("confidence >= ?", 95.0) }

  def self.record_event(ab_test, event_type, value, confidence = 95.0, metadata = {})
    create!(
      ab_test: ab_test,
      event_type: event_type,
      value: value,
      confidence: confidence,
      metadata: metadata
    )
  end

  def significant?
    confidence >= 95.0
  end

  def performance_impact
    case event_type
    when "conversion"
      value > 0 ? "positive" : "negative"
    when "engagement"
      value > 50 ? "high" : "low"
    else
      "neutral"
    end
  end
end
