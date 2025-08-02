class ContentTaggingSystem
  attr_reader :errors

  def initialize
    @errors = []
  end

  def apply_tags(tags_data)
    ContentTag.transaction do
      # Remove existing tags if replacing
      if tags_data[:replace_existing]
        ContentTag.where(content_repository_id: tags_data[:content_id]).destroy_all
      end

      # Apply categories
      tags_data[:categories]&.each do |category|
        ContentTag.create!(
          content_repository_id: tags_data[:content_id],
          tag_name: category,
          tag_type: "category",
          user_id: tags_data[:user_id]
        )
      end

      # Apply keywords
      tags_data[:keywords]&.each do |keyword|
        ContentTag.create!(
          content_repository_id: tags_data[:content_id],
          tag_name: keyword,
          tag_type: "keyword",
          user_id: tags_data[:user_id]
        )
      end

      # Apply custom tags
      tags_data[:custom_tags]&.each do |custom_tag|
        ContentTag.create!(
          content_repository_id: tags_data[:content_id],
          tag_name: custom_tag,
          tag_type: "custom_tag",
          user_id: tags_data[:user_id]
        )
      end
    end

    { success: true }
  rescue => e
    @errors << e.message
    raise e
  end

  def get_content_tags(content_id)
    tags = ContentTag.where(content_repository_id: content_id)

    {
      categories: tags.where(tag_type: "category").pluck(:tag_name),
      keywords: tags.where(tag_type: "keyword").pluck(:tag_name),
      custom_tags: tags.where(tag_type: "custom_tag").pluck(:tag_name)
    }
  end

  def remove_tags(content_id, tag_names)
    ContentTag.where(
      content_repository_id: content_id,
      tag_name: tag_names
    ).destroy_all
    { success: true }
  end

  def search_by_tags(tag_names, options = {})
    content_ids = ContentTag.where(tag_name: tag_names)
                            .group(:content_repository_id)
                            .having("COUNT(*) >= ?", options[:min_matches] || 1)
                            .pluck(:content_repository_id)

    ContentRepository.where(id: content_ids)
                    .includes(:content_tags)
                    .order(created_at: :desc)
  end
end
