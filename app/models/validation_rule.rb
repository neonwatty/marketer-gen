class ValidationRule < ApplicationRecord
  validates :table_name, presence: true
  validates :field_name, presence: true, uniqueness: { scope: :table_name }
  validates :rules, presence: true
  
  scope :enabled, -> { where(real_time_enabled: true) }
  scope :for_table, ->(table_name) { where(table_name: table_name) }
  scope :for_field, ->(table_name, field_name) { where(table_name: table_name, field_name: field_name) }
  
  # Predefined validation rule templates
  RULE_TEMPLATES = {
    email_uniqueness: {
      type: 'uniqueness',
      endpoint: '/api/v1/validations/email_unique',
      error_message: 'This email address is already taken'
    },
    required: {
      type: 'presence',
      error_message: 'This field is required'
    },
    email_format: {
      type: 'format',
      pattern: '/^[^\s@]+@[^\s@]+\.[^\s@]+$/',
      error_message: 'Please enter a valid email address'
    },
    min_length: {
      type: 'length',
      min: 8,
      error_message: 'Must be at least {min} characters'
    },
    max_length: {
      type: 'length',
      max: 255,
      error_message: 'Must be no more than {max} characters'
    }
  }.freeze
  
  def self.seed_default_rules
    # User email validation
    find_or_create_by(table_name: 'users', field_name: 'email_address') do |rule|
      rule.rules = [
        RULE_TEMPLATES[:required],
        RULE_TEMPLATES[:email_format],
        RULE_TEMPLATES[:email_uniqueness]
      ]
      rule.validation_endpoint = '/api/v1/validations/users/email_address'
      rule.error_message_template = 'Email validation failed'
    end
    
    # Campaign plan name validation
    find_or_create_by(table_name: 'campaign_plans', field_name: 'name') do |rule|
      rule.rules = [
        RULE_TEMPLATES[:required],
        { type: 'length', min: 3, max: 100, error_message: 'Name must be 3-100 characters' }
      ]
      rule.validation_endpoint = '/api/v1/validations/campaign_plans/name'
    end
    
    # Journey name validation
    find_or_create_by(table_name: 'journeys', field_name: 'name') do |rule|
      rule.rules = [
        RULE_TEMPLATES[:required],
        { type: 'length', min: 3, max: 100, error_message: 'Name must be 3-100 characters' }
      ]
      rule.validation_endpoint = '/api/v1/validations/journeys/name'
    end
  end
  
  def validate_value(value, context = {})
    results = []
    
    rules.each do |rule|
      case rule['type']
      when 'presence'
        if value.blank?
          results << { valid: false, error: rule['error_message'] }
        end
      when 'format'
        if value.present? && !value.match?(Regexp.new(rule['pattern']))
          results << { valid: false, error: rule['error_message'] }
        end
      when 'length'
        if value.present?
          if rule['min'] && value.length < rule['min']
            results << { valid: false, error: rule['error_message'].gsub('{min}', rule['min'].to_s) }
          elsif rule['max'] && value.length > rule['max']
            results << { valid: false, error: rule['error_message'].gsub('{max}', rule['max'].to_s) }
          end
        end
      end
    end
    
    if results.any? { |r| !r[:valid] }
      { valid: false, errors: results.select { |r| !r[:valid] }.map { |r| r[:error] } }
    else
      { valid: true, errors: [] }
    end
  end
end