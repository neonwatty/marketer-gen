class JourneyTemplate < ApplicationRecord
  # Associations
  belongs_to :parent_template, class_name: 'JourneyTemplate', optional: true
  has_many :child_templates, class_name: 'JourneyTemplate', foreign_key: 'parent_template_id', dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :template_type, presence: true, inclusion: { in: %w[lead_nurturing customer_retention product_launch brand_awareness sales_enablement event_promotion] }
  validates :category, inclusion: { in: %w[b2b b2c saas ecommerce nonprofit education healthcare], allow_blank: true }
  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :usage_count, numericality: { greater_than_or_equal_to: 0 }
  validates :description, length: { maximum: 1000 }
  validates :author, length: { maximum: 100 }
  validate :template_data_structure
  validate :variables_structure

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_template_type, ->(type) { where(template_type: type) }
  scope :by_category, ->(category) { where(category: category) }
  scope :published, -> { where.not(published_at: nil) }
  scope :unpublished, -> { where(published_at: nil) }
  scope :popular, -> { order(usage_count: :desc) }
  scope :recent, -> { order(created_at: :desc) }
  scope :latest_versions, -> { where(version: select('MAX(version)').where('name = journey_templates.name')) }

  # Callbacks
  before_validation :set_defaults
  before_save :update_template_data_structure

  # Template Management
  def create_journey_from_template(campaign, journey_params = {})
    return nil unless campaign

    journey_attributes = {
      name: journey_params[:name] || "#{name} Journey",
      template_type: template_type,
      purpose: template_data['purpose'] || journey_params[:purpose],
      goals: template_data['goals'] || journey_params[:goals],
      timing: template_data['timing'] || journey_params[:timing],
      audience: template_data['audience'] || journey_params[:audience],
      campaign: campaign
    }

    journey = Journey.create!(journey_attributes)
    
    # Create stages from template
    create_stages_from_template(journey) if template_data['stages'].present?
    
    increment_usage_count!
    journey
  end

  def create_stages_from_template(journey)
    return unless template_data['stages'].is_a?(Array)

    template_data['stages'].each_with_index do |stage_data, index|
      journey.journey_stages.create!(
        name: stage_data['name'],
        stage_type: stage_data['stage_type'],
        description: stage_data['description'],
        content: stage_data['content'],
        duration_days: stage_data['duration_days'],
        position: index,
        configuration: stage_data['configuration'] || {}
      )
    end
  end

  def increment_usage_count!
    increment!(:usage_count)
  end

  # Template Data Management
  def update_template_data(new_data)
    return false unless new_data.is_a?(Hash)
    
    merged_data = template_data.merge(new_data)
    update(template_data: merged_data)
  end

  def get_template_value(key)
    template_data[key.to_s]
  end

  def set_template_value(key, value)
    updated_data = template_data.dup
    updated_data[key.to_s] = value
    update(template_data: updated_data)
  end

  # Variable Management
  def required_variables
    variables.select { |var| var['required'] == true }
  end

  def optional_variables
    variables.select { |var| var['required'] != true }
  end

  def variable_names
    variables.map { |var| var['name'] }
  end

  def has_variable?(variable_name)
    variable_names.include?(variable_name.to_s)
  end

  def variable_default(variable_name)
    var = variables.find { |v| v['name'] == variable_name.to_s }
    var&.dig('default_value')
  end

  # Publishing
  def publish!
    update!(published_at: Time.current, is_active: true)
  end

  def unpublish!
    update!(published_at: nil)
  end

  def published?
    published_at.present?
  end

  # Versioning
  def create_new_version(updates = {})
    new_version = dup
    new_version.version = version + 1
    new_version.parent_template_id = id
    new_version.published_at = nil
    new_version.usage_count = 0
    
    updates.each do |key, value|
      new_version.send("#{key}=", value) if new_version.respond_to?("#{key}=")
    end
    
    new_version.save!
    new_version
  end

  def latest_version?
    self.class.where(name: name).maximum(:version) == version
  end

  def previous_version
    return nil if parent_template_id.nil?
    parent_template
  end

  def next_version
    child_templates.order(:version).first
  end

  # Statistics and Analytics
  def adoption_rate
    return 0 if usage_count == 0
    
    total_journeys = Journey.where(template_type: template_type).count
    return 0 if total_journeys == 0
    
    (usage_count.to_f / total_journeys * 100).round(2)
  end

  def stage_count
    template_data.dig('stages')&.length || 0
  end

  def estimated_duration_days
    return nil unless template_data['stages'].is_a?(Array)
    
    template_data['stages'].sum { |stage| stage['duration_days'] || 0 }
  end

  # Utility Methods
  def template_type_humanized
    template_type.humanize
  end

  def category_humanized
    category&.humanize || 'General'
  end

  def tags_array
    tags&.split(',')&.map(&:strip) || []
  end

  def tags_array=(array)
    self.tags = array&.join(', ')
  end

  def summary_info
    {
      name: name,
      type: template_type_humanized,
      category: category_humanized,
      version: version,
      usage_count: usage_count,
      stage_count: stage_count,
      estimated_duration: estimated_duration_days,
      published: published?,
      active: is_active
    }
  end

  private

  def set_defaults
    self.version ||= 1
    self.usage_count ||= 0
    self.is_active = true if is_active.nil?
    self.template_data ||= {}
    self.variables ||= []
    self.metadata ||= {}
  end

  def template_data_structure
    return unless template_data.present?

    unless template_data.is_a?(Hash)
      errors.add(:template_data, "must be a valid JSON object")
      return
    end

    # Validate stages structure if present
    if template_data['stages'].present?
      unless template_data['stages'].is_a?(Array)
        errors.add(:template_data, "stages must be an array")
        return
      end

      template_data['stages'].each_with_index do |stage, index|
        unless stage.is_a?(Hash) && stage['name'].present? && stage['stage_type'].present?
          errors.add(:template_data, "stage at index #{index} is missing required fields (name, stage_type)")
          break
        end

        unless %w[Awareness Consideration Conversion Retention Advocacy].include?(stage['stage_type'])
          errors.add(:template_data, "stage at index #{index} has invalid stage_type")
          break
        end
      end
    end
  end

  def variables_structure
    return unless variables.present?

    unless variables.is_a?(Array)
      errors.add(:variables, "must be an array")
      return
    end

    variables.each_with_index do |variable, index|
      unless variable.is_a?(Hash) && variable['name'].present? && variable['type'].present?
        errors.add(:variables, "variable at index #{index} is missing required fields (name, type)")
        break
      end

      valid_types = %w[string number boolean date array object]
      unless valid_types.include?(variable['type'])
        errors.add(:variables, "variable at index #{index} has invalid type")
        break
      end
    end
  end

  def update_template_data_structure
    return unless template_data_changed?
    
    # Ensure metadata includes last modified timestamp
    self.metadata = metadata.merge({
      'last_modified' => Time.current.iso8601,
      'structure_version' => '1.0'
    })
  end
end
