class JourneyStage < ApplicationRecord
  # Associations
  belongs_to :journey
  has_many :content_assets, as: :assetable, dependent: :destroy
  
  # Through associations
  has_one :campaign, through: :journey
  has_one :brand_identity, through: :campaign

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :stage_type, presence: true, inclusion: { in: %w[Awareness Consideration Conversion Retention Advocacy] }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: %w[draft in_progress completed published archived] }
  validates :duration_days, numericality: { greater_than: 0 }, allow_nil: true
  validates :description, length: { maximum: 1000 }
  validates :content, length: { maximum: 5000 }
  validate :position_unique_within_journey

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_stage_type, ->(type) { where(stage_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :ordered, -> { order(:position) }
  scope :draft, -> { where(status: 'draft') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :published, -> { where(status: 'published') }
  scope :with_duration, -> { where.not(duration_days: nil) }

  # Callbacks
  before_validation :set_defaults
  after_create :reorder_subsequent_stages
  after_destroy :reorder_subsequent_stages

  # Configuration Management
  def update_configuration(config_updates)
    return false unless config_updates.is_a?(Hash)
    
    merged_config = configuration.merge(config_updates)
    update(configuration: merged_config)
  end

  def get_config(key)
    configuration[key.to_s]
  end

  def set_config(key, value)
    updated_config = configuration.dup
    updated_config[key.to_s] = value
    update(configuration: updated_config)
  end

  # Content Management
  def add_content_asset(asset_params)
    content_assets.create(asset_params.merge(stage: name))
  end

  def content_by_channel
    content_assets.group(:channel).count
  end

  def total_content_assets
    content_assets.count
  end

  # Position Management
  def move_to_position(new_position)
    return false if new_position < 0
    return true if position == new_position

    transaction do
      if new_position > position
        # Moving down - shift intermediate stages up
        journey.journey_stages
               .where('position > ? AND position <= ?', position, new_position)
               .update_all('position = position - 1')
      else
        # Moving up - shift intermediate stages down
        journey.journey_stages
               .where('position >= ? AND position < ?', new_position, position)
               .update_all('position = position + 1')
      end

      update!(position: new_position)
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def move_up
    return false if position == 0
    
    swap_with_stage_at_position(position - 1)
  end

  def move_down
    max_position = journey.journey_stages.maximum(:position) || 0
    return false if position >= max_position
    
    swap_with_stage_at_position(position + 1)
  end

  # Navigation Methods
  def next_stage
    journey.journey_stages.where('position > ?', position).ordered.first
  end

  def previous_stage
    journey.journey_stages.where('position < ?', position).order(position: :desc).first
  end

  def first_stage?
    position == 0
  end

  def last_stage?
    position == (journey.journey_stages.maximum(:position) || 0)
  end

  # Status Management
  def can_transition_to?(new_status)
    valid_transitions = {
      'draft' => %w[in_progress archived],
      'in_progress' => %w[draft completed archived],
      'completed' => %w[published archived],
      'published' => %w[archived],
      'archived' => %w[draft]
    }
    
    valid_transitions[status]&.include?(new_status) || false
  end

  def transition_to!(new_status)
    return false unless can_transition_to?(new_status)
    
    update!(status: new_status)
  end

  # Utility Methods
  def stage_type_color
    colors = {
      'Awareness' => 'bg-blue-100 text-blue-800',
      'Consideration' => 'bg-yellow-100 text-yellow-800', 
      'Conversion' => 'bg-green-100 text-green-800',
      'Retention' => 'bg-purple-100 text-purple-800',
      'Advocacy' => 'bg-pink-100 text-pink-800'
    }
    
    colors[stage_type] || 'bg-gray-100 text-gray-600'
  end

  def status_color
    colors = {
      'draft' => 'bg-gray-100 text-gray-600',
      'in_progress' => 'bg-blue-100 text-blue-800',
      'completed' => 'bg-green-100 text-green-800',
      'published' => 'bg-emerald-100 text-emerald-800',
      'archived' => 'bg-red-100 text-red-600'
    }
    
    colors[status] || 'bg-gray-100 text-gray-600'
  end

  def summary_stats
    {
      content_assets: total_content_assets,
      content_by_channel: content_by_channel,
      duration: duration_days,
      position_info: {
        current: position,
        is_first: first_stage?,
        is_last: last_stage?
      }
    }
  end

  private

  def set_defaults
    self.status ||= 'draft'
    self.is_active = true if is_active.nil?
    self.configuration ||= {}
  end

  def position_unique_within_journey
    return unless position && journey_id

    existing_stage = journey.journey_stages
                           .where(position: position)
                           .where.not(id: id)
                           .first

    if existing_stage
      errors.add(:position, "is already taken by another stage in this journey")
    end
  end

  def reorder_subsequent_stages
    return unless journey_id && position

    journey.journey_stages
           .where('position > ?', position)
           .where.not(id: id)
           .order(:position)
           .each_with_index do |stage, index|
             stage.update_columns(position: position + index + 1)
           end
  end

  def swap_with_stage_at_position(target_position)
    other_stage = journey.journey_stages.find_by(position: target_position)
    return false unless other_stage

    transaction do
      temp_position = -1
      update!(position: temp_position)
      other_stage.update!(position: position)
      update!(position: target_position)
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end
end
