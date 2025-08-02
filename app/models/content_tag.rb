class ContentTag < ApplicationRecord
  belongs_to :content_repository
  belongs_to :user

  validates :tag_name, presence: true
  validates :tag_type, presence: true

  enum tag_type: {
    category: 0,
    keyword: 1,
    custom_tag: 2,
    system_tag: 3,
    ai_generated: 4
  }

  scope :by_type, ->(type) { where(tag_type: type) }
  scope :by_repository, ->(repo_id) { where(content_repository_id: repo_id) }
  scope :categories, -> { where(tag_type: "category") }
  scope :keywords, -> { where(tag_type: "keyword") }
  scope :custom_tags, -> { where(tag_type: "custom_tag") }
  scope :search_by_name, ->(name) { where("tag_name ILIKE ?", "%#{name}%") }

  before_save :normalize_tag_name
  after_create :update_tag_usage_count

  def self.popular_tags(limit: 10)
    select(:tag_name, :tag_type)
      .group(:tag_name, :tag_type)
      .order("COUNT(*) DESC")
      .limit(limit)
      .count
  end

  def self.apply_bulk_tags(content_repository_id:, tags_data:, user:)
    transaction do
      # Remove existing tags if requested
      if tags_data[:replace_existing]
        where(content_repository_id: content_repository_id).destroy_all
      end

      # Add categories
      tags_data[:categories]&.each do |category|
        create!(
          content_repository_id: content_repository_id,
          tag_name: category,
          tag_type: "category",
          user: user
        )
      end

      # Add keywords
      tags_data[:keywords]&.each do |keyword|
        create!(
          content_repository_id: content_repository_id,
          tag_name: keyword,
          tag_type: "keyword",
          user: user
        )
      end

      # Add custom tags
      tags_data[:custom_tags]&.each do |custom_tag|
        create!(
          content_repository_id: content_repository_id,
          tag_name: custom_tag,
          tag_type: "custom_tag",
          user: user
        )
      end
    end
  end

  def self.get_content_tags(content_repository_id)
    tags = where(content_repository_id: content_repository_id)

    {
      categories: tags.categories.pluck(:tag_name),
      keywords: tags.keywords.pluck(:tag_name),
      custom_tags: tags.custom_tags.pluck(:tag_name),
      all_tags: tags.pluck(:tag_name, :tag_type).map { |name, type| { name: name, type: type } }
    }
  end

  def self.search_content_by_tags(tag_names, tag_types: nil)
    query = joins(:content_repository)

    if tag_types.present?
      query = query.where(tag_type: tag_types)
    end

    query.where(tag_name: tag_names)
         .select("content_repositories.*, COUNT(*) as tag_matches")
         .group("content_repositories.id")
         .order("tag_matches DESC")
  end

  def usage_count
    self.class.where(tag_name: tag_name, tag_type: tag_type).count
  end

  private

  def normalize_tag_name
    self.tag_name = tag_name.strip.downcase if tag_name.present?
  end

  def update_tag_usage_count
    # This could trigger background job to update tag popularity metrics
    # For now, we'll keep it simple and let the popular_tags method handle it
  end
end
