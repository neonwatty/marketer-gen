class Template < ApplicationRecord
  # Associations
  belongs_to :parent_template, class_name: 'Template', optional: true, counter_cache: :child_templates_count
  has_many :child_templates, class_name: 'Template', foreign_key: 'parent_template_id', dependent: :destroy, counter_cache: true
  has_many :content_assets, as: :assetable, dependent: :destroy
  
  # Through associations for template relationships
  has_many :grandchild_templates, through: :child_templates, source: :child_templates
  has_many :sibling_templates, through: :parent_template, source: :child_templates

  # Enums
  enum :template_type, {
    journey: 'journey',
    content: 'content',
    campaign: 'campaign',
    email: 'email',
    social_post: 'social_post',
    landing_page: 'landing_page'
  }, prefix: :template

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 200 }
  validates :template_type, presence: true
  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :usage_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :template_data_structure_valid
  validate :variables_structure_valid
  validate :parent_template_compatibility
  validate :circular_dependency_check

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_type, ->(type) { where(template_type: type) }
  scope :by_category, ->(category) { where(category: category) }
  scope :published, -> { where.not(published_at: nil) }
  scope :unpublished, -> { where(published_at: nil) }
  scope :popular, -> { order(usage_count: :desc) }
  scope :recent, -> { order(created_at: :desc) }
  scope :root_templates, -> { where(parent_template_id: nil) }
  scope :child_templates, -> { where.not(parent_template_id: nil) }

  # Callbacks
  before_save :extract_variables_from_template_data
  before_save :set_published_at, if: :is_active_changed?
  after_create :increment_parent_usage, if: :parent_template_id?

  # Template Management Methods
  def duplicate(new_name = nil)
    new_template = self.class.new(
      name: new_name || "#{name} (Copy)",
      template_type: template_type,
      category: category,
      template_data: template_data.deep_dup,
      description: description,
      variables: variables.deep_dup,
      metadata: metadata.deep_dup,
      tags: tags,
      is_active: false,
      version: 1
    )
    
    new_template.save
    new_template
  end

  def create_child_template(attributes = {})
    child = self.class.new(
      name: attributes[:name] || "#{name} - Customized",
      template_type: template_type,
      category: category,
      template_data: template_data.deep_dup,
      description: attributes[:description] || description,
      variables: variables.deep_dup,
      metadata: metadata.merge(attributes[:metadata] || {}),
      parent_template: self,
      is_active: attributes[:is_active] || false,
      version: 1
    )
    
    # Apply customizations
    if attributes[:template_data]
      child.template_data = child.template_data.deep_merge(attributes[:template_data])
    end
    
    child.save
    child
  end

  def create_new_version(attributes = {})
    new_version = self.class.new(
      name: name,
      template_type: template_type,
      category: category,
      template_data: template_data.deep_dup,
      description: description,
      variables: variables.deep_dup,
      metadata: metadata.deep_dup,
      tags: tags,
      author: author,
      version: version + 1,
      is_active: false
    )
    
    # Apply updates
    new_version.assign_attributes(attributes) if attributes.present?
    new_version.save
    new_version
  end

  # Variable Management
  def variable_names
    variables.is_a?(Array) ? variables : []
  end

  def add_variable(variable_name, default_value = nil, description = nil)
    updated_variables = variables.dup
    variable_info = {
      'name' => variable_name.to_s,
      'default' => default_value,
      'description' => description
    }.compact
    
    # Check if variable already exists
    existing_index = updated_variables.find_index { |v| v['name'] == variable_name.to_s }
    if existing_index
      updated_variables[existing_index] = variable_info
    else
      updated_variables << variable_info
    end
    
    update(variables: updated_variables)
  end

  def remove_variable(variable_name)
    updated_variables = variables.reject { |v| v['name'] == variable_name.to_s }
    update(variables: updated_variables)
  end

  def get_variable_info(variable_name)
    variables.find { |v| v['name'] == variable_name.to_s }
  end

  def has_variable?(variable_name)
    variable_names.include?(variable_name.to_s)
  end

  # Template Instantiation and Rendering
  def instantiate(variable_values = {})
    rendered_data = render_template_with_variables(template_data, variable_values)
    
    case template_type
    when 'journey'
      instantiate_journey(rendered_data)
    when 'content'
      instantiate_content(rendered_data)
    when 'campaign'
      instantiate_campaign(rendered_data)
    else
      rendered_data
    end
  end

  def render_preview(variable_values = {})
    render_template_with_variables(template_data, variable_values)
  end

  def validate_variables(variable_values)
    errors = []
    required_variables = variable_names.select { |v| get_variable_info(v)&.dig('required') }
    
    required_variables.each do |var_name|
      if variable_values[var_name].blank? && variable_values[var_name.to_sym].blank?
        errors << "Variable '#{var_name}' is required"
      end
    end
    
    errors
  end

  # Template Content Analysis
  def extract_template_variables
    variables_found = Set.new
    extract_variables_from_data(template_data, variables_found)
    variables_found.to_a
  end

  def template_size
    template_data.to_json.bytesize
  end

  def complexity_score
    # Simple complexity scoring based on nested objects, variables, etc.
    score = 0
    score += count_nested_objects(template_data) * 2
    score += variable_names.count * 3
    score += child_templates.count * 5
    score
  end

  # Template Publishing and Activation
  def publish!
    update!(is_active: true, published_at: Time.current)
  end

  def unpublish!
    update!(is_active: false, published_at: nil)
  end

  def published?
    is_active? && published_at.present?
  end

  def increment_usage!
    increment!(:usage_count)
  end

  # Template Categories and Tags
  def tag_list
    return [] if tags.blank?
    tags.split(',').map(&:strip)
  end

  def tag_list=(new_tags)
    if new_tags.is_a?(Array)
      self.tags = new_tags.join(', ')
    else
      self.tags = new_tags.to_s
    end
  end

  def add_tag(tag)
    current_tags = tag_list
    current_tags << tag.to_s unless current_tags.include?(tag.to_s)
    self.tag_list = current_tags
    save
  end

  def remove_tag(tag)
    current_tags = tag_list
    current_tags.delete(tag.to_s)
    self.tag_list = current_tags
    save
  end

  # Search and Discovery
  def self.search(query)
    return none if query.blank?
    
    where("LOWER(name) LIKE ? OR LOWER(description) LIKE ? OR LOWER(category) LIKE ? OR LOWER(tags) LIKE ?",
          "%#{query.downcase}%", "%#{query.downcase}%", "%#{query.downcase}%", "%#{query.downcase}%")
  end

  def self.by_tag(tag)
    where("LOWER(tags) LIKE ?", "%#{tag.downcase}%")
  end

  # Metadata Management
  def get_metadata(key)
    metadata.dig(key.to_s)
  end

  def set_metadata(key, value)
    updated_metadata = metadata.dup
    updated_metadata[key.to_s] = value
    update(metadata: updated_metadata)
  end

  def merge_metadata(new_metadata)
    return false unless new_metadata.is_a?(Hash)
    
    updated_metadata = metadata.merge(new_metadata.stringify_keys)
    update(metadata: updated_metadata)
  end

  private

  def extract_variables_from_template_data
    return if template_data.blank?
    
    found_variables = extract_template_variables
    
    # Update variables array with found variables (keep existing info)
    updated_variables = variables.dup
    
    found_variables.each do |var_name|
      unless updated_variables.any? { |v| v['name'] == var_name }
        updated_variables << { 'name' => var_name, 'type' => 'string' }
      end
    end
    
    self.variables = updated_variables
  end

  def extract_variables_from_data(data, variables_set)
    case data
    when Hash
      data.each do |key, value|
        extract_variables_from_data(key, variables_set)
        extract_variables_from_data(value, variables_set)
      end
    when Array
      data.each { |item| extract_variables_from_data(item, variables_set) }
    when String
      # Extract variables in format {{variable_name}} or {variable_name}
      data.scan(/\{\{?([^}]+)\}?\}/).each do |match|
        variables_set.add(match[0].strip)
      end
    end
  end

  def render_template_with_variables(data, variable_values)
    case data
    when Hash
      data.transform_values { |value| render_template_with_variables(value, variable_values) }
    when Array
      data.map { |item| render_template_with_variables(item, variable_values) }
    when String
      rendered_string = data.dup
      
      # Replace {{variable}} and {variable} patterns
      variable_values.each do |key, value|
        key_str = key.to_s
        rendered_string.gsub!(/\{\{#{key_str}\}\}/, value.to_s)
        rendered_string.gsub!(/\{#{key_str}\}/, value.to_s)
      end
      
      # Replace with defaults for remaining variables
      variables.each do |var_info|
        var_name = var_info['name']
        default_value = var_info['default'] || ''
        rendered_string.gsub!(/\{\{#{var_name}\}\}/, default_value.to_s)
        rendered_string.gsub!(/\{#{var_name}\}/, default_value.to_s)
      end
      
      rendered_string
    else
      data
    end
  end

  def instantiate_journey(rendered_data)
    # Create a CustomerJourney instance from template data
    # This would integrate with the CustomerJourney model
    rendered_data
  end

  def instantiate_content(rendered_data)
    # Create ContentAsset instances from template data
    # This would integrate with the ContentAsset model
    rendered_data
  end

  def instantiate_campaign(rendered_data)
    # Create Campaign instance from template data
    # This would integrate with the Campaign model
    rendered_data
  end

  def count_nested_objects(data, depth = 0)
    case data
    when Hash
      count = depth > 0 ? 1 : 0
      data.values.sum { |value| count_nested_objects(value, depth + 1) } + count
    when Array
      count = depth > 0 ? 1 : 0
      data.sum { |item| count_nested_objects(item, depth + 1) } + count
    else
      0
    end
  end

  def set_published_at
    if is_active?
      self.published_at = Time.current if published_at.blank?
    else
      self.published_at = nil
    end
  end

  def increment_parent_usage
    parent_template&.increment!(:usage_count)
  end

  def template_data_structure_valid
    return if template_data.blank?
    
    unless template_data.is_a?(Hash)
      errors.add(:template_data, "must be a valid JSON object")
    end
  end

  def variables_structure_valid
    return if variables.blank?
    
    unless variables.is_a?(Array)
      errors.add(:variables, "must be an array")
      return
    end
    
    variables.each_with_index do |var, index|
      unless var.is_a?(Hash) && var['name'].present?
        errors.add(:variables, "Variable at position #{index} must have a name")
        break
      end
    end
  end

  def parent_template_compatibility
    return unless parent_template
    
    unless parent_template.template_type == template_type
      errors.add(:parent_template, "must have the same template type")
    end
  end

  def circular_dependency_check
    return unless parent_template_id
    
    current_template = self
    visited_ids = Set.new
    
    while current_template.parent_template_id
      if visited_ids.include?(current_template.parent_template_id)
        errors.add(:parent_template, "creates a circular dependency")
        break
      end
      
      visited_ids.add(current_template.parent_template_id)
      current_template = Template.find_by(id: current_template.parent_template_id)
      break unless current_template
    end
  end
end
