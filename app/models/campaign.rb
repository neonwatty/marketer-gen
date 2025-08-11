class Campaign < ApplicationRecord
  include AASM

  # Associations
  belongs_to :brand_identity, optional: true, counter_cache: true
  has_many :customer_journeys, dependent: :destroy
  has_one :customer_journey, -> { order(:created_at) }, dependent: :destroy
  has_many :journeys, -> { order(:position) }, dependent: :destroy
  has_many :content_assets, as: :assetable, dependent: :destroy
  has_many :brand_assets, as: :assetable, dependent: :destroy

  # Through associations for easier access
  has_many :campaign_templates, -> { where(template_type: "campaign") }, class_name: "Template"
  has_many :journey_stages, through: :customer_journeys, source: :stages
  has_many :structured_journey_stages, through: :journeys, source: :journey_stages
  has_many :email_content, -> { where(channel: "email") }, class_name: "ContentAsset", as: :assetable
  has_many :social_content, -> { where(channel: "social_media") }, class_name: "ContentAsset", as: :assetable
  has_many :web_content, -> { where(channel: "web") }, class_name: "ContentAsset", as: :assetable

  # Validations
  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :purpose, presence: true, length: { minimum: 10, maximum: 500 }
  validates :budget_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :start_date, :end_date, presence: true, if: :active_or_scheduled?
  validate :end_date_after_start_date, if: :dates_present?

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :draft, -> { where(status: "draft") }
  scope :by_status, ->(status) { where(status: status) }
  scope :with_budget, -> { where.not(budget_cents: nil) }
  scope :current, -> { where("start_date <= ? AND (end_date >= ? OR end_date IS NULL)", Date.current, Date.current) }
  scope :upcoming, -> { where("start_date > ?", Date.current) }
  scope :past, -> { where("end_date < ?", Date.current) }

  # AASM State Machine for campaign status
  aasm column: :status, whiny_transitions: false do
    state :draft, initial: true
    state :active
    state :paused
    state :completed
    state :archived

    event :activate do
      transitions from: [ :draft, :paused ], to: :active
      before do
        self.start_date ||= Date.current
      end
    end

    event :pause do
      transitions from: :active, to: :paused
    end

    event :complete do
      transitions from: [ :active, :paused ], to: :completed
      before do
        self.end_date ||= Date.current
      end
    end

    event :archive do
      transitions from: [ :draft, :completed, :paused ], to: :archived
    end

    event :reopen do
      transitions from: :archived, to: :draft
    end
  end

  # Instance methods
  def budget
    return nil unless budget_cents
    Money.new(budget_cents, "USD") if defined?(Money)
    budget_cents / 100.0
  end

  def budget=(amount)
    if amount.is_a?(String)
      # Remove currency symbols and convert to cents
      clean_amount = amount.gsub(/[$,]/, "").to_f
      self.budget_cents = (clean_amount * 100).to_i
    elsif amount.respond_to?(:cents)
      self.budget_cents = amount.cents
    elsif amount.is_a?(Numeric)
      self.budget_cents = (amount * 100).to_i
    else
      self.budget_cents = nil
    end
  end

  def duration_days
    return nil unless start_date && end_date
    (end_date - start_date).to_i + 1
  end

  def days_remaining
    return nil unless end_date && active?
    [ (end_date - Date.current).to_i, 0 ].max
  end

  def progress_percentage
    return 0 unless start_date && end_date && start_date <= Date.current
    return 100 if completed? || Date.current >= end_date

    total_days = (end_date - start_date).to_f
    elapsed_days = (Date.current - start_date).to_f
    ((elapsed_days / total_days) * 100).round(1)
  end

  def status_color
    case status
    when "active" then "bg-green-100 text-green-800"
    when "draft" then "bg-gray-100 text-gray-600"
    when "paused" then "bg-yellow-100 text-yellow-800"
    when "completed" then "bg-blue-100 text-blue-800"
    when "archived" then "bg-red-100 text-red-600"
    else "bg-gray-100 text-gray-600"
    end
  end

  def can_be_activated?
    may_activate? && start_date.present? && end_date.present?
  end

  def overdue?
    active? && end_date && end_date < Date.current
  end

  private

  def active_or_scheduled?
    active? || (start_date.present? && end_date.present?)
  end

  def dates_present?
    start_date.present? || end_date.present?
  end

  def end_date_after_start_date
    return unless start_date && end_date
    errors.add(:end_date, "must be after start date") if end_date < start_date
  end
end
