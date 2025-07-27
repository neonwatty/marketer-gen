class JourneyTemplate < ApplicationRecord
  has_many :journeys
  
  # Versioning associations
  belongs_to :original_template, class_name: 'JourneyTemplate', optional: true
  has_many :versions, class_name: 'JourneyTemplate', foreign_key: 'original_template_id', dependent: :destroy
  
  CATEGORIES = %w[
    b2b
    b2c
    ecommerce
    saas
    nonprofit
    education
    healthcare
    financial_services
    real_estate
    hospitality
  ].freeze
  
  DIFFICULTY_LEVELS = %w[beginner intermediate advanced].freeze
  
  validates :name, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :campaign_type, inclusion: { in: Journey::CAMPAIGN_TYPES }, allow_blank: true
  validates :difficulty_level, inclusion: { in: DIFFICULTY_LEVELS }, allow_blank: true
  validates :estimated_duration_days, numericality: { greater_than: 0 }, allow_blank: true
  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :version, uniqueness: { scope: :original_template_id }, if: :original_template_id?
  
  scope :active, -> { where(is_active: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_campaign_type, ->(type) { where(campaign_type: type) }
  scope :popular, -> { order(usage_count: :desc) }
  scope :recent, -> { order(created_at: :desc) }
  scope :published_versions, -> { where(is_published_version: true) }
  scope :latest_versions, -> { joins("LEFT JOIN journey_templates jt2 ON jt2.original_template_id = journey_templates.original_template_id AND jt2.version > journey_templates.version").where("jt2.id IS NULL") }
  
  def create_journey_for_user(user, journey_params = {})
    journey = user.journeys.build(
      name: journey_params[:name] || "#{name} - #{Date.current}",
      description: journey_params[:description] || description,
      campaign_type: campaign_type,
      target_audience: journey_params[:target_audience],
      goals: journey_params[:goals],
      brand_id: journey_params[:brand_id],
      metadata: {
        template_id: id,
        template_name: name,
        created_from_template: true
      }
    )
    
    if journey.save
      create_steps_for_journey(journey)
      increment!(:usage_count)
      journey
    else
      journey
    end
  end
  
  def preview_steps
    template_data['steps'] || []
  end
  
  def steps_data
    template_data['steps'] || []
  end
  
  def steps_data=(value)
    self.template_data = (template_data || {}).merge('steps' => value)
  end
  
  def connections_data
    template_data['connections'] || []
  end
  
  def connections_data=(value)
    self.template_data = (template_data || {}).merge('connections' => value)
  end
  
  def step_count
    preview_steps.size
  end
  
  def stages_covered
    preview_steps.map { |step| step['stage'] }.uniq
  end
  
  def channels_used
    preview_steps.map { |step| step['channel'] }.uniq.compact
  end
  
  def content_types_included
    preview_steps.map { |step| step['content_type'] }.uniq.compact
  end
  
  def is_original?
    original_template_id.nil?
  end
  
  def root_template
    original_template || self
  end
  
  def all_versions
    if is_original?
      [self] + versions.order(:version)
    else
      original_template.versions.order(:version)
    end
  end
  
  def latest_version
    if is_original?
      versions.order(:version).last || self
    else
      original_template.latest_version
    end
  end
  
  def create_new_version(version_params = {})
    new_version_number = calculate_next_version_number
    
    new_version = self.dup
    new_version.assign_attributes(
      original_template: root_template,
      version: new_version_number,
      parent_version: version,
      version_notes: version_params[:version_notes],
      is_published_version: version_params[:is_published_version] || false,
      usage_count: 0,
      is_active: true
    )
    
    # Update name to include version if it's not the original
    unless new_version.name.match(/v\d+\.\d+/)
      new_version.name = "#{name} v#{new_version_number}"
    end
    
    new_version
  end
  
  def publish_version!
    transaction do
      # Unpublish other versions of the same template
      root_template.versions.update_all(is_published_version: false)
      if root_template != self
        root_template.update!(is_published_version: false)
      end
      
      # Publish this version
      update!(is_published_version: true)
    end
  end
  
  def version_history
    all_versions.map do |version|
      {
        version: version.version,
        created_at: version.created_at,
        version_notes: version.version_notes,
        is_published: version.is_published_version,
        usage_count: version.usage_count
      }
    end
  end
  
  private
  
  def calculate_next_version_number
    existing_versions = root_template.versions.pluck(:version)
    existing_versions << root_template.version
    
    major_version = existing_versions.map(&:to_i).max || 1
    minor_versions = existing_versions.select { |v| v.to_i == major_version }.map { |v| (v % 1 * 100).to_i }
    next_minor = (minor_versions.max || 0) + 1
    
    # If minor version reaches 100, increment major version
    if next_minor >= 100
      major_version += 1
      next_minor = 0
    end
    
    major_version + (next_minor / 100.0)
  end
  
  def create_steps_for_journey(journey)
    return unless template_data['steps'].present?
    
    step_mapping = {}
    
    # First pass: create all steps
    template_data['steps'].each_with_index do |step_data, index|
      step = journey.journey_steps.create!(
        name: step_data['name'],
        description: step_data['description'],
        stage: step_data['stage'],
        position: index,
        content_type: step_data['content_type'],
        channel: step_data['channel'],
        duration_days: step_data['duration_days'] || 1,
        config: step_data['config'] || {},
        conditions: step_data['conditions'] || {},
        metadata: step_data['metadata'] || {},
        is_entry_point: step_data['is_entry_point'] || (index == 0),
        is_exit_point: step_data['is_exit_point'] || false
      )
      
      step_mapping[step_data['id']] = step if step_data['id']
    end
    
    # Second pass: create transitions
    template_data['transitions']&.each do |transition_data|
      from_step = step_mapping[transition_data['from_step_id']]
      to_step = step_mapping[transition_data['to_step_id']]
      
      if from_step && to_step
        StepTransition.create!(
          from_step: from_step,
          to_step: to_step,
          transition_type: transition_data['transition_type'] || 'sequential',
          conditions: transition_data['conditions'] || {},
          priority: transition_data['priority'] || 0,
          metadata: transition_data['metadata'] || {}
        )
      end
    end
  end
end
