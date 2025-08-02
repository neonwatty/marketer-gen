class ContentCategory < ApplicationRecord
  belongs_to :parent, class_name: "ContentCategory", optional: true
  has_many :children, class_name: "ContentCategory", foreign_key: "parent_id", dependent: :destroy
  has_many :content_repositories, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :parent_id }
  validates :slug, presence: true, uniqueness: true

  scope :root_categories, -> { where(parent_id: nil) }
  scope :by_level, ->(level) { where(hierarchy_level: level) }
  scope :active, -> { where(active: true) }

  before_validation :generate_slug
  before_save :calculate_hierarchy_level
  after_create :update_children_hierarchy

  def self.create_hierarchy(category_path)
    return nil if category_path.empty?

    current_parent = nil
    created_categories = []

    category_path.each_with_index do |category_name, index|
      category = find_or_create_by(name: category_name, parent: current_parent) do |cat|
        cat.description = "Auto-generated category: #{category_name}"
        cat.active = true
      end

      created_categories << category
      current_parent = category
    end

    {
      root_category: created_categories.first.name,
      levels: created_categories.map(&:name),
      leaf_category: created_categories.last,
      full_path: full_hierarchy_path(created_categories.last)
    }
  end

  def self.full_hierarchy_path(category)
    path = []
    current = category

    while current
      path.unshift(current.name)
      current = current.parent
    end

    path.join(" > ")
  end

  def full_path
    self.class.full_hierarchy_path(self)
  end

  def descendants
    self.class.where("hierarchy_path LIKE ?", "#{hierarchy_path}%").where.not(id: id)
  end

  def ancestors
    return self.class.none unless hierarchy_path.present?

    paths = []
    path_parts = hierarchy_path.split("/")

    path_parts.each_with_index do |_, index|
      paths << path_parts[0..index].join("/")
    end

    self.class.where(hierarchy_path: paths).where.not(id: id)
  end

  def siblings
    if parent
      parent.children.where.not(id: id)
    else
      self.class.root_categories.where.not(id: id)
    end
  end

  def root?
    parent_id.nil?
  end

  def leaf?
    children.empty?
  end

  def content_count
    # Count content in this category and all subcategories
    descendant_ids = descendants.pluck(:id) + [ id ]
    ContentRepository.where(content_category_id: descendant_ids).count
  end

  def assign_content(content_repository)
    content_repository.update!(content_category: self)

    {
      success: true,
      hierarchy_level: hierarchy_level,
      full_path: full_path
    }
  end

  def move_to_parent(new_parent)
    transaction do
      self.parent = new_parent
      save!
      update_hierarchy_data
    end
  end

  private

  def generate_slug
    return if name.blank?

    base_slug = name.parameterize
    counter = 1
    potential_slug = base_slug

    while self.class.exists?(slug: potential_slug) && (new_record? || slug != potential_slug)
      potential_slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = potential_slug
  end

  def calculate_hierarchy_level
    self.hierarchy_level = parent ? parent.hierarchy_level + 1 : 0
  end

  def update_children_hierarchy
    update_hierarchy_data
  end

  def update_hierarchy_data
    calculate_hierarchy_level
    build_hierarchy_path
    save! if changed?

    # Update all descendants
    children.each(&:update_hierarchy_data)
  end

  def build_hierarchy_path
    path_components = []
    current = self

    while current
      path_components.unshift(current.slug)
      current = current.parent
    end

    self.hierarchy_path = path_components.join("/")
  end
end
