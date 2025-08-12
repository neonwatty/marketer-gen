# Response model for A/B testing content variants
class ContentVariantResponse
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :original_request
  attribute :variants, default: -> { [] }
  attribute :generated_at, :datetime
  attribute :variant_analysis, default: -> { {} }

  def variant_count
    variants.size
  end

  def best_variant_by_quality
    return nil if variants.empty?
    variants.max_by(&:quality_score)
  end

  def best_variant_by_engagement
    return nil if variants.empty?
    variants.max_by(&:engagement_prediction)
  end

  def length_diversity
    return 0 if variants.size < 2
    lengths = variants.map(&:character_count)
    (lengths.max - lengths.min).to_f / lengths.max
  end

  def quality_range
    return { min: 0, max: 0 } if variants.empty?
    quality_scores = variants.map(&:quality_score).compact
    { min: quality_scores.min, max: quality_scores.max }
  end
end