class BrandGuideline < ApplicationRecord
  include Branding::Compliance::CacheInvalidation
  
  belongs_to :brand

  # Constants
  RULE_TYPES = %w[do dont must should avoid prefer].freeze
  CATEGORIES = %w[voice tone visual messaging grammar style accessibility].freeze

  # Validations
  validates :rule_type, presence: true, inclusion: { in: RULE_TYPES }
  validates :rule_content, presence: true
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  validates :priority, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_type, ->(type) { where(rule_type: type) }
  scope :high_priority, -> { where("priority >= ?", 7) }
  scope :ordered, -> { order(priority: :desc, created_at: :asc) }

  # Methods
  def positive_rule?
    %w[do must should prefer].include?(rule_type)
  end

  def negative_rule?
    %w[dont avoid].include?(rule_type)
  end

  def mandatory?
    %w[must dont].include?(rule_type)
  end

  def suggestion?
    %w[should prefer avoid].include?(rule_type)
  end

  def toggle_active!
    update!(active: !active)
  end

  # Class methods
  def self.by_priority
    ordered.group_by(&:priority)
  end

  def self.mandatory_rules
    active.where(rule_type: %w[must dont])
  end

  def self.suggestions
    active.where(rule_type: %w[should prefer avoid])
  end
end
