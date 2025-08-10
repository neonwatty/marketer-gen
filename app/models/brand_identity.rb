class BrandIdentity < ApplicationRecord
  # Active Storage Associations
  has_one_attached :primary_logo
  has_one_attached :secondary_logo
  has_one_attached :favicon
  has_many_attached :brand_assets
  has_many_attached :style_guides

  # Model Associations
  has_many :campaigns, dependent: :nullify, counter_cache: true
  has_many :content_assets, as: :assetable, dependent: :destroy
  has_many :brand_assets, as: :assetable, dependent: :destroy, counter_cache: true

  # Through associations for easier access
  has_many :customer_journeys, through: :campaigns
  has_many :brand_templates, -> { where(template_type: [ "brand", "content" ]) }, class_name: "Template", as: :assetable

  # Validations
  validates :name, presence: true, uniqueness: true, length: { minimum: 2, maximum: 100 }
  validates :version, presence: true, numericality: { greater_than: 0 }
  validate :guidelines_structure_valid
  validate :color_palette_structure_valid
  validate :typography_structure_valid
  validate :messaging_frameworks_structure_valid

  # Scopes
  scope :active, -> { where(active: true) }
  scope :published, -> { where.not(published_at: nil) }
  scope :latest_version, -> { order(version: :desc) }
  scope :by_name, ->(name) { where(name: name) }

  # Callbacks
  before_save :set_published_at, if: :active_changed?
  before_create :increment_version_if_exists

  # Brand Configuration Methods
  def primary_color
    color_palette.dig("primary") || "#000000"
  end

  def secondary_color
    color_palette.dig("secondary") || "#666666"
  end

  def accent_color
    color_palette.dig("accent") || "#0066cc"
  end

  def brand_colors
    {
      primary: primary_color,
      secondary: secondary_color,
      accent: accent_color,
      additional: color_palette.dig("additional") || []
    }
  end

  def primary_font
    typography.dig("primary_font", "family") || "Arial, sans-serif"
  end

  def secondary_font
    typography.dig("secondary_font", "family") || "Georgia, serif"
  end

  def font_sizes
    typography.dig("font_sizes") || {
      "small" => "14px",
      "medium" => "16px",
      "large" => "24px",
      "xlarge" => "36px"
    }
  end

  # Brand Guidelines Methods
  def get_guideline(key)
    guidelines.dig(key.to_s)
  end

  def update_guideline(key, value)
    updated_guidelines = guidelines.dup
    updated_guidelines[key.to_s] = value
    update(guidelines: updated_guidelines)
  end

  def logo_usage_rules
    guidelines.dig("logo_usage") || {}
  end

  def color_usage_rules
    guidelines.dig("color_usage") || {}
  end

  def typography_rules
    guidelines.dig("typography") || {}
  end

  # Messaging Framework Methods
  def brand_voice
    messaging_frameworks.dig("voice") || {}
  end

  def brand_tone
    messaging_frameworks.dig("tone") || {}
  end

  def key_messages
    messaging_frameworks.dig("key_messages") || []
  end

  def brand_values
    messaging_frameworks.dig("values") || []
  end

  def update_messaging_framework(framework_type, data)
    updated_frameworks = messaging_frameworks.dup
    updated_frameworks[framework_type.to_s] = data
    update(messaging_frameworks: updated_frameworks)
  end

  # Brand Asset Methods
  def has_primary_logo?
    primary_logo.attached?
  end

  def has_secondary_logo?
    secondary_logo.attached?
  end

  def logo_variants
    variants = []
    variants << { type: "primary", attached: primary_logo.attached?, url: primary_logo.attached? ? Rails.application.routes.url_helpers.rails_blob_path(primary_logo, only_path: true) : nil }
    variants << { type: "secondary", attached: secondary_logo.attached?, url: secondary_logo.attached? ? Rails.application.routes.url_helpers.rails_blob_path(secondary_logo, only_path: true) : nil }
    variants << { type: "favicon", attached: favicon.attached?, url: favicon.attached? ? Rails.application.routes.url_helpers.rails_blob_path(favicon, only_path: true) : nil }
    variants
  end

  def brand_asset_count
    brand_assets.count
  end

  def style_guide_count
    style_guides.count
  end

  # Brand Compliance Methods
  def validate_color_compliance(hex_color)
    return false unless hex_color.match?(/\A#[0-9A-Fa-f]{6}\z/)

    brand_hex_colors = [ primary_color, secondary_color, accent_color ]
    additional_colors = color_palette.dig("additional") || []
    all_brand_colors = brand_hex_colors + additional_colors

    all_brand_colors.include?(hex_color.upcase)
  end

  def validate_font_compliance(font_family)
    approved_fonts = [
      primary_font,
      secondary_font,
      typography.dig("approved_fonts")
    ].flatten.compact

    approved_fonts.any? { |font| font_family.to_s.downcase.include?(font.to_s.downcase.split(",").first.strip) }
  end

  # Version Management
  def create_new_version(attributes = {})
    new_version = self.class.new(
      name: name,
      description: description,
      guidelines: guidelines,
      messaging_frameworks: messaging_frameworks,
      color_palette: color_palette,
      typography: typography,
      version: version + 1,
      active: false
    )

    # Copy attributes if provided
    new_version.assign_attributes(attributes) if attributes.present?

    # Copy attachments
    if primary_logo.attached?
      new_version.primary_logo.attach(primary_logo.blob)
    end

    if secondary_logo.attached?
      new_version.secondary_logo.attach(secondary_logo.blob)
    end

    if favicon.attached?
      new_version.favicon.attach(favicon.blob)
    end

    new_version.save
    new_version
  end

  def publish!
    update!(active: true, published_at: Time.current)
  end

  def unpublish!
    update!(active: false, published_at: nil)
  end

  def published?
    active? && published_at.present?
  end

  private

  def set_published_at
    if active?
      self.published_at = Time.current if published_at.blank?
    else
      self.published_at = nil
    end
  end

  def increment_version_if_exists
    existing_brand = self.class.find_by(name: name)
    if existing_brand
      self.version = existing_brand.version + 1
    end
  end

  def guidelines_structure_valid
    return if guidelines.blank?

    unless guidelines.is_a?(Hash)
      errors.add(:guidelines, "must be a valid JSON object")
      return
    end

    # Validate specific guideline sections if present
    validate_logo_usage_guidelines if guidelines["logo_usage"].present?
    validate_color_usage_guidelines if guidelines["color_usage"].present?
  end

  def validate_logo_usage_guidelines
    logo_usage = guidelines["logo_usage"]
    return unless logo_usage.is_a?(Hash)

    %w[minimum_size clear_space do_not].each do |key|
      if logo_usage[key].present? && !logo_usage[key].is_a?(String)
        errors.add(:guidelines, "logo_usage.#{key} must be a string")
      end
    end
  end

  def validate_color_usage_guidelines
    color_usage = guidelines["color_usage"]
    return unless color_usage.is_a?(Hash)

    if color_usage["accessibility"].present? && !color_usage["accessibility"].is_a?(Hash)
      errors.add(:guidelines, "color_usage.accessibility must be an object")
    end
  end

  def color_palette_structure_valid
    return if color_palette.blank?

    unless color_palette.is_a?(Hash)
      errors.add(:color_palette, "must be a valid JSON object")
      return
    end

    %w[primary secondary accent].each do |color_type|
      if color_palette[color_type].present?
        unless color_palette[color_type].match?(/\A#[0-9A-Fa-f]{6}\z/)
          errors.add(:color_palette, "#{color_type} must be a valid hex color")
        end
      end
    end
  end

  def typography_structure_valid
    return if typography.blank?

    unless typography.is_a?(Hash)
      errors.add(:typography, "must be a valid JSON object")
      return
    end

    %w[primary_font secondary_font].each do |font_type|
      if typography[font_type].present? && !typography[font_type].is_a?(Hash)
        errors.add(:typography, "#{font_type} must be an object")
      end
    end
  end

  def messaging_frameworks_structure_valid
    return if messaging_frameworks.blank?

    unless messaging_frameworks.is_a?(Hash)
      errors.add(:messaging_frameworks, "must be a valid JSON object")
      return
    end

    if messaging_frameworks["key_messages"].present? && !messaging_frameworks["key_messages"].is_a?(Array)
      errors.add(:messaging_frameworks, "key_messages must be an array")
    end

    if messaging_frameworks["values"].present? && !messaging_frameworks["values"].is_a?(Array)
      errors.add(:messaging_frameworks, "values must be an array")
    end
  end
end
