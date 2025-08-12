# Response model for multi-channel content generation
class ContentMultiChannelResponse
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :request_id, :string
  attribute :channel_results, default: -> { {} }
  attribute :generated_at, :datetime
  attribute :generation_summary, default: -> { {} }

  def successful_channels
    channel_results.reject { |_, result| result.is_a?(Hash) && result.key?(:error) }
  end

  def failed_channels
    channel_results.select { |_, result| result.is_a?(Hash) && result.key?(:error) }
  end

  def success_rate
    return 0 if channel_results.empty?
    successful_channels.size.to_f / channel_results.size
  end

  def total_word_count
    successful_channels.values.map(&:word_count).sum
  end

  def average_quality_score
    quality_scores = successful_channels.values.map(&:quality_score).compact
    return 0 if quality_scores.empty?
    quality_scores.sum / quality_scores.size
  end
end