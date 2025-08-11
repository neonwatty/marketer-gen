class PromptTemplate < ApplicationRecord
  # Associations
  belongs_to :parent_template, class_name: "PromptTemplate", optional: true, counter_cache: :child_templates_count
  has_many :child_templates, class_name: "PromptTemplate", foreign_key: "parent_template_id", dependent: :destroy, counter_cache: true

  # Enums
  enum :prompt_type, {
    campaign_planning: "campaign_planning",
    brand_analysis: "brand_analysis", 
    content_generation: "content_generation",
    social_media: "social_media",
    email_marketing: "email_marketing",
    landing_page: "landing_page",
    ad_copy: "ad_copy",
    seo_optimization: "seo_optimization",
    competitor_analysis: "competitor_analysis",
    customer_persona: "customer_persona"
  }, prefix: :prompt

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 200 }
  validates :prompt_type, presence: true
  validates :system_prompt, presence: true
  validates :user_prompt, presence: true
  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :usage_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :temperature, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2 }
  validates :max_tokens, numericality: { greater_than: 0 }
  validate :variables_structure_valid
  validate :default_values_valid
  validate :model_preferences_valid
  validate :circular_dependency_check

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_type, ->(type) { where(prompt_type: type) }
  scope :by_category, ->(category) { where(category: category) }
  scope :popular, -> { order(usage_count: :desc) }
  scope :recent, -> { order(created_at: :desc) }
  scope :root_templates, -> { where(parent_template_id: nil) }

  # Callbacks
  before_save :extract_variables_from_prompts
  after_create :increment_parent_usage, if: :parent_template_id?

  # Template Rendering Methods
  def render_prompt(variable_values = {})
    merged_values = default_values.merge(variable_values.stringify_keys)
    
    {
      system_prompt: interpolate_variables(system_prompt, merged_values),
      user_prompt: interpolate_variables(user_prompt, merged_values),
      temperature: temperature,
      max_tokens: max_tokens,
      model_preferences: parsed_model_preferences
    }
  end

  def render_system_prompt(variable_values = {})
    merged_values = default_values.merge(variable_values.stringify_keys)
    interpolate_variables(system_prompt, merged_values)
  end

  def render_user_prompt(variable_values = {})
    merged_values = default_values.merge(variable_values.stringify_keys)
    interpolate_variables(user_prompt, merged_values)
  end

  def preview(variable_values = {})
    {
      name: name,
      type: prompt_type,
      rendered: render_prompt(variable_values),
      variables: variable_info,
      metadata: metadata
    }
  end

  # Variable Management
  def variable_names
    variables.is_a?(Array) ? variables.map { |v| v["name"] }.compact : []
  end

  def variable_info
    variables.is_a?(Array) ? variables : []
  end

  def required_variables
    variable_info.select { |v| v["required"] == true }.map { |v| v["name"] }
  end

  def optional_variables
    variable_info.reject { |v| v["required"] == true }.map { |v| v["name"] }
  end

  def add_variable(name, options = {})
    updated_variables = variables.dup
    
    variable_config = {
      "name" => name.to_s,
      "type" => options[:type] || "string",
      "description" => options[:description],
      "required" => options[:required] || false,
      "validation" => options[:validation]
    }.compact

    # Update existing or add new
    existing_index = updated_variables.find_index { |v| v["name"] == name.to_s }
    if existing_index
      updated_variables[existing_index] = variable_config
    else
      updated_variables << variable_config
    end

    update(variables: updated_variables)
  end

  def remove_variable(name)
    updated_variables = variables.reject { |v| v["name"] == name.to_s }
    updated_defaults = default_values.except(name.to_s)
    
    update(
      variables: updated_variables,
      default_values: updated_defaults
    )
  end

  def set_default_value(variable_name, value)
    updated_defaults = default_values.dup
    updated_defaults[variable_name.to_s] = value
    update(default_values: updated_defaults)
  end

  def validate_variable_values(variable_values)
    errors = []
    
    # Check required variables
    required_variables.each do |var_name|
      unless variable_values.key?(var_name) || variable_values.key?(var_name.to_sym)
        errors << "Required variable '#{var_name}' is missing"
      end
    end

    # Type validation
    variable_info.each do |var_config|
      var_name = var_config["name"]
      value = variable_values[var_name] || variable_values[var_name.to_sym]
      
      next unless value.present?
      
      case var_config["type"]
      when "integer"
        unless value.is_a?(Integer) || (value.is_a?(String) && value.match?(/^\d+$/))
          errors << "Variable '#{var_name}' must be an integer"
        end
      when "float"
        unless value.is_a?(Numeric) || (value.is_a?(String) && value.match?(/^\d*\.?\d+$/))
          errors << "Variable '#{var_name}' must be a number"
        end
      when "boolean"
        unless [true, false, "true", "false", "1", "0"].include?(value)
          errors << "Variable '#{var_name}' must be true or false"
        end
      end
    end

    errors
  end

  # Template Management
  def duplicate(new_name = nil)
    new_template = self.class.new(
      name: new_name || "#{name} (Copy)",
      prompt_type: prompt_type,
      system_prompt: system_prompt,
      user_prompt: user_prompt,
      variables: variables.deep_dup,
      default_values: default_values.deep_dup,
      description: description,
      category: category,
      temperature: temperature,
      max_tokens: max_tokens,
      model_preferences: model_preferences,
      metadata: metadata.deep_dup,
      tags: tags,
      is_active: false,
      version: 1
    )
    
    new_template.save
    new_template
  end

  def create_version(attributes = {})
    new_version = self.class.new(
      name: name,
      prompt_type: prompt_type,
      system_prompt: system_prompt,
      user_prompt: user_prompt,
      variables: variables.deep_dup,
      default_values: default_values.deep_dup,
      description: description,
      category: category,
      temperature: temperature,
      max_tokens: max_tokens,
      model_preferences: model_preferences,
      metadata: metadata.deep_dup,
      tags: tags,
      version: version + 1,
      is_active: false
    )
    
    # Apply updates
    new_version.assign_attributes(attributes) if attributes.present?
    new_version.save
    new_version
  end

  # A/B Testing Support
  def create_variant(variant_name, changes = {})
    variant = duplicate("#{name} - #{variant_name}")
    variant.assign_attributes(changes)
    variant.metadata = metadata.merge(
      "variant_of" => id,
      "variant_name" => variant_name,
      "created_for_testing" => true
    )
    variant.save
    variant
  end

  def variants
    # SQLite doesn't support JSON operators like PostgreSQL, so we'll use LIKE
    # Check for both string and integer representations
    self.class.where(
      "metadata LIKE ? OR metadata LIKE ?", 
      "%\"variant_of\":\"#{id}\"%",
      "%\"variant_of\":#{id}%"
    )
  end

  def original_template
    return self unless metadata["variant_of"]
    self.class.find_by(id: metadata["variant_of"])
  end

  # Usage and Analytics
  def increment_usage!
    increment!(:usage_count)
  end

  def usage_analytics
    {
      usage_count: usage_count,
      created_at: created_at,
      last_used: metadata["last_used"],
      variants: variants.count,
      child_templates_count: child_templates.count
    }
  end

  # Search and Discovery
  def self.search(query)
    return none if query.blank?
    
    where(
      "LOWER(name) LIKE ? OR LOWER(description) LIKE ? OR LOWER(category) LIKE ? OR LOWER(tags) LIKE ? OR LOWER(system_prompt) LIKE ? OR LOWER(user_prompt) LIKE ?",
      *(["%#{query.downcase}%"] * 6)
    )
  end

  def self.by_tag(tag)
    where("LOWER(tags) LIKE ?", "%#{tag.downcase}%")
  end

  # Tag Management
  def tag_list
    return [] if tags.blank?
    tags.split(",").map(&:strip)
  end

  def tag_list=(new_tags)
    if new_tags.is_a?(Array)
      self.tags = new_tags.join(", ")
    else
      self.tags = new_tags.to_s
    end
  end

  # Model Preferences
  def parsed_model_preferences
    return {} if model_preferences.blank?
    
    begin
      JSON.parse(model_preferences)
    rescue JSON::ParserError
      {}
    end
  end

  def set_model_preference(key, value)
    prefs = parsed_model_preferences
    prefs[key.to_s] = value
    update(model_preferences: prefs.to_json)
  end

  private

  def interpolate_variables(text, variable_values)
    return text if text.blank?
    
    result = text.dup
    
    # Handle both {{variable}} and {variable} formats
    variable_values.each do |key, value|
      key_str = key.to_s
      result.gsub!(/\{\{#{Regexp.escape(key_str)}\}\}/, value.to_s)
      result.gsub!(/\{#{Regexp.escape(key_str)}\}/, value.to_s)
    end
    
    result
  end

  def extract_variables_from_prompts
    variables_found = Set.new
    
    [system_prompt, user_prompt].each do |text|
      next if text.blank?
      
      # Extract {{variable}} and {variable} patterns
      text.scan(/\{\{?([^}]+)\}?\}/).each do |match|
        var_name = match[0].strip
        variables_found.add(var_name) unless var_name.blank?
      end
    end

    # Update variables array, preserving existing configuration
    current_vars = variables.dup
    
    variables_found.each do |var_name|
      unless current_vars.any? { |v| v["name"] == var_name }
        current_vars << {
          "name" => var_name,
          "type" => "string",
          "required" => false
        }
      end
    end
    
    self.variables = current_vars
  end

  def variables_structure_valid
    return if variables.blank?
    
    unless variables.is_a?(Array)
      errors.add(:variables, "must be an array")
      return
    end
    
    variables.each_with_index do |var, index|
      unless var.is_a?(Hash) && var["name"].present?
        errors.add(:variables, "Variable at position #{index} must have a name")
        break
      end
    end
  end

  def default_values_valid
    return if default_values.blank?
    
    unless default_values.is_a?(Hash)
      errors.add(:default_values, "must be a hash")
    end
  end

  def model_preferences_valid
    return if model_preferences.blank?
    
    begin
      JSON.parse(model_preferences)
    rescue JSON::ParserError
      errors.add(:model_preferences, "must be valid JSON")
    end
  end

  def circular_dependency_check
    return unless parent_template_id
    
    # Include the current template in visited set to detect immediate cycles
    visited_ids = Set.new([id])
    current_template_id = parent_template_id
    
    while current_template_id
      if visited_ids.include?(current_template_id)
        errors.add(:parent_template, "creates a circular dependency")
        break
      end
      
      visited_ids.add(current_template_id)
      current_template = PromptTemplate.find_by(id: current_template_id)
      break unless current_template
      
      current_template_id = current_template.parent_template_id
    end
  end

  def increment_parent_usage
    parent_template&.increment!(:usage_count)
  end
end