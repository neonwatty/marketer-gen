class ContentCategoryHierarchy
  attr_reader :errors

  def initialize
    @errors = []
  end

  def create_hierarchy(category_path)
    return nil if category_path.empty?

    current_parent = nil
    created_categories = []

    category_path.each_with_index do |category_name, index|
      category = ContentCategory.find_or_create_by(name: category_name, parent: current_parent) do |cat|
        cat.description = "Auto-generated category: #{category_name}"
        cat.active = true
      end

      created_categories << category
      current_parent = category
    end

    {
      root_category: created_categories.first.name,
      levels: created_categories.map(&:name),
      leaf_category: created_categories.last
    }
  rescue => e
    @errors << e.message
    raise e
  end

  def assign_to_category(content_id, category_name)
    begin
      category = ContentCategory.find_by(name: category_name)
      return { success: false, error: "Category not found" } unless category

      repository = ContentRepository.find(content_id)
      repository.update!(content_category: category)

      {
        success: true,
        hierarchy_level: category.hierarchy_level,
        full_path: build_full_path(category)
      }
    rescue => e
      @errors << e.message
      { success: false, error: e.message }
    end
  end

  def get_hierarchy_path(category_id)
    category = ContentCategory.find(category_id)
    build_full_path(category)
  end

  def move_content(content_id, new_category_name)
    begin
      new_category = ContentCategory.find_by(name: new_category_name)
      return { success: false, error: "Category not found" } unless new_category

      repository = ContentRepository.find(content_id)
      old_category = repository.content_category

      repository.update!(content_category: new_category)

      {
        success: true,
        old_category: old_category&.name,
        new_category: new_category.name,
        hierarchy_level: new_category.hierarchy_level
      }
    rescue => e
      @errors << e.message
      { success: false, error: e.message }
    end
  end

  def get_subcategories(category_name)
    category = ContentCategory.find_by(name: category_name)
    return [] unless category

    category.children.active.pluck(:name)
  end

  def get_content_by_category(category_name, include_subcategories: false)
    category = ContentCategory.find_by(name: category_name)
    return [] unless category

    if include_subcategories
      descendant_ids = category.descendants.pluck(:id) + [ category.id ]
      ContentRepository.where(content_category_id: descendant_ids)
    else
      ContentRepository.where(content_category: category)
    end
  end

  private

  def build_full_path(category)
    path = []
    current = category

    while current
      path.unshift(current.name)
      current = current.parent
    end

    path
  end
end
