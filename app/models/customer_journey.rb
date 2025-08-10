class CustomerJourney < ApplicationRecord
  # Associations
  belongs_to :campaign, counter_cache: true
  has_many :content_assets, as: :assetable, dependent: :destroy
  
  # Through associations for easier access  
  has_one :brand_identity, through: :campaign
  has_many :journey_templates, -> { where(template_type: 'journey') }, class_name: 'Template', as: :assetable

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  # Note: stages can be empty initially, validation happens in stages_structure_valid
  validates :content_types, presence: true
  validate :stages_structure_valid
  validate :content_types_valid

  # Scopes
  scope :ordered, -> { order(:position, :created_at) }
  scope :by_campaign, ->(campaign) { where(campaign: campaign) }
  scope :with_stages, -> { where.not(stages: []) }

  # Stage Management Methods
  def add_stage(stage_data)
    return false unless valid_stage_structure?(stage_data)
    
    stage = stage_data.merge(
      'id' => SecureRandom.uuid,
      'created_at' => Time.current.iso8601,
      'position' => stages.length
    )
    
    self.stages = stages + [stage]
    save
  end

  def remove_stage(stage_id)
    return false unless stage_id.present?
    
    self.stages = stages.reject { |stage| stage['id'] == stage_id }
    reorder_stages!
    save
  end

  def reorder_stages(stage_ids = nil)
    return false if stage_ids.nil?
    
    # Reorder based on provided stage IDs array
    ordered_stages = stage_ids.map do |id|
      stages.find { |stage| stage['id'] == id }
    end.compact
    
    # Update positions
    ordered_stages.each_with_index do |stage, index|
      stage['position'] = index
    end
    
    self.stages = ordered_stages
    save
  end

  def update_stage(stage_id, updates)
    return false unless stage_id.present? && updates.is_a?(Hash)
    
    stage_index = stages.find_index { |stage| stage['id'] == stage_id }
    return false unless stage_index
    
    updated_stages = stages.dup
    updated_stages[stage_index] = updated_stages[stage_index].merge(updates)
    updated_stages[stage_index]['updated_at'] = Time.current.iso8601
    
    self.stages = updated_stages
    save
  end

  def find_stage(stage_id)
    stages.find { |stage| stage['id'] == stage_id }
  end

  def stage_count
    stages.length
  end

  def stage_names
    stages.map { |stage| stage['name'] }
  end

  def next_stage(current_stage_id)
    current_index = stages.find_index { |stage| stage['id'] == current_stage_id }
    return nil unless current_index && current_index < stages.length - 1
    
    stages[current_index + 1]
  end

  def previous_stage(current_stage_id)
    current_index = stages.find_index { |stage| stage['id'] == current_stage_id }
    return nil unless current_index && current_index > 0
    
    stages[current_index - 1]
  end

  # Touchpoint Management
  def add_touchpoint(stage_id, touchpoint_data)
    return false unless stage_id.present? && touchpoint_data.is_a?(Hash)
    
    stage_touchpoints = touchpoints[stage_id] || []
    touchpoint = touchpoint_data.merge(
      'id' => SecureRandom.uuid,
      'created_at' => Time.current.iso8601
    )
    
    updated_touchpoints = touchpoints.dup
    updated_touchpoints[stage_id] = stage_touchpoints + [touchpoint]
    
    self.touchpoints = updated_touchpoints
    save
  end

  def remove_touchpoint(stage_id, touchpoint_id)
    return false unless stage_id.present? && touchpoint_id.present?
    
    updated_touchpoints = touchpoints.dup
    if updated_touchpoints[stage_id]
      updated_touchpoints[stage_id] = updated_touchpoints[stage_id].reject { |tp| tp['id'] == touchpoint_id }
    end
    
    self.touchpoints = updated_touchpoints
    save
  end

  # Metrics Management
  def update_metrics(metric_data)
    return false unless metric_data.is_a?(Hash)
    
    updated_metrics = metrics.merge(metric_data)
    updated_metrics['last_updated'] = Time.current.iso8601
    
    self.metrics = updated_metrics
    save
  end

  def add_metric(key, value)
    updated_metrics = metrics.dup
    updated_metrics[key.to_s] = value
    updated_metrics['last_updated'] = Time.current.iso8601
    
    self.metrics = updated_metrics
    save
  end

  private

  def reorder_stages!
    self.stages = stages.each_with_index.map do |stage, index|
      stage.merge('position' => index)
    end
  end

  def stages_structure_valid
    # Allow empty stages array for new journeys
    return if stages.blank?
    
    stages.each_with_index do |stage, index|
      unless valid_stage_structure?(stage)
        errors.add(:stages, "Stage at position #{index} has invalid structure")
        break
      end
    end
  end

  def valid_stage_structure?(stage)
    return false unless stage.is_a?(Hash)
    return false unless stage['name'].present?
    
    # Optional fields validation
    if stage['duration_days'].present?
      return false unless stage['duration_days'].is_a?(Integer) && stage['duration_days'] > 0
    end
    
    if stage['description'].present?
      return false unless stage['description'].is_a?(String)
    end
    
    true
  end

  def content_types_valid
    return if content_types.blank?
    
    valid_types = %w[email social_media blog_post video infographic webinar landing_page advertisement newsletter case_study whitepaper]
    
    invalid_types = content_types - valid_types
    if invalid_types.any?
      errors.add(:content_types, "Invalid content types: #{invalid_types.join(', ')}")
    end
  end
end
