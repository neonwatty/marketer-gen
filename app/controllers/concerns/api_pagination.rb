module ApiPagination
  extend ActiveSupport::Concern

  DEFAULT_PAGE_SIZE = 25
  MAX_PAGE_SIZE = 100

  private

  def paginate_collection(collection)
    page = [params[:page].to_i, 1].max
    per_page = [[params[:per_page].to_i, DEFAULT_PAGE_SIZE].max, MAX_PAGE_SIZE].min
    
    offset = (page - 1) * per_page
    total_count = collection.count
    total_pages = (total_count.to_f / per_page).ceil
    
    paginated_collection = collection.limit(per_page).offset(offset)
    
    {
      collection: paginated_collection,
      meta: {
        pagination: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: total_pages,
          has_next_page: page < total_pages,
          has_previous_page: page > 1
        }
      }
    }
  end

  def paginate_and_render(collection, serializer: nil, **options)
    result = paginate_collection(collection)
    
    data = if serializer
      result[:collection].map { |item| serializer.call(item) }
    else
      result[:collection]
    end
    
    render_success(
      data: data,
      meta: result[:meta],
      **options
    )
  end
end