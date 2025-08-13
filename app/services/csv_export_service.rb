require 'csv'

class CsvExportService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :model_class, :filters, :columns, :options

  def initialize(model_class:, filters: {}, columns: nil, options: {})
    @model_class = model_class
    @filters = filters || {}
    @columns = columns
    @options = options || {}
  end

  def export
    records = build_query
    csv_data = generate_csv(records)
    
    {
      data: csv_data,
      filename: generate_filename,
      content_type: 'text/csv',
      metadata: {
        total_records: records.count,
        exported_at: Time.current,
        filters_applied: filters,
        columns_included: column_headers
      }
    }
  end

  def export_to_file(filepath)
    result = export
    File.write(filepath, result[:data])
    filepath
  end

  def self.export_campaigns(filters: {}, columns: nil, options: {})
    new(
      model_class: Campaign,
      filters: filters,
      columns: columns || default_campaign_columns,
      options: options
    ).export
  end

  def self.export_content_variants(filters: {}, columns: nil, options: {})
    new(
      model_class: ContentVariant,
      filters: filters,
      columns: columns || default_content_variant_columns,
      options: options
    ).export
  end

  def self.export_content_assets(filters: {}, columns: nil, options: {})
    new(
      model_class: ContentAsset,
      filters: filters,
      columns: columns || default_content_asset_columns,
      options: options
    ).export
  end

  def self.export_journeys(filters: {}, columns: nil, options: {})
    new(
      model_class: Journey,
      filters: filters,
      columns: columns || default_journey_columns,
      options: options
    ).export
  end

  def self.export_brand_assets(filters: {}, columns: nil, options: {})
    new(
      model_class: BrandAsset,
      filters: filters,
      columns: columns || default_brand_asset_columns,
      options: options
    ).export
  end

  private

  def build_query
    query = model_class.all
    
    # Apply filters
    filters.each do |key, value|
      next if value.blank?
      
      case key.to_s
      when 'status'
        query = query.where(status: value)
      when 'date_range'
        if value.is_a?(Hash) && value[:start] && value[:end]
          query = query.where(created_at: value[:start]..value[:end])
        end
      when 'campaign_id'
        if model_class.column_names.include?('campaign_id')
          query = query.where(campaign_id: value)
        elsif model_class.reflect_on_association(:campaign)
          query = query.joins(:campaign).where(campaigns: { id: value })
        end
      when 'search'
        query = apply_search_filter(query, value)
      when 'ids'
        query = query.where(id: value) if value.is_a?(Array)
      else
        # Dynamic filter based on column names
        if model_class.column_names.include?(key.to_s)
          query = query.where(key => value)
        end
      end
    end

    # Apply ordering
    order_by = options[:order_by] || 'created_at'
    order_direction = options[:order_direction] || 'desc'
    query = query.order("#{order_by} #{order_direction}")

    # Apply limit if specified
    query = query.limit(options[:limit]) if options[:limit]

    query
  end

  def apply_search_filter(query, search_term)
    searchable_columns = get_searchable_columns
    return query if searchable_columns.empty?

    conditions = searchable_columns.map do |column|
      "#{column} ILIKE ?"
    end.join(' OR ')

    search_values = Array.new(searchable_columns.length, "%#{search_term}%")
    query.where(conditions, *search_values)
  end

  def get_searchable_columns
    text_columns = model_class.columns.select do |column|
      [:string, :text].include?(column.type)
    end.map(&:name)

    # Add specific searchable columns based on model
    case model_class.name
    when 'Campaign'
      text_columns & %w[name purpose description]
    when 'ContentVariant'
      text_columns & %w[name content strategy_type]
    when 'ContentAsset'
      text_columns & %w[title description content_text channel]
    when 'Journey'
      text_columns & %w[name description]
    when 'BrandAsset'
      text_columns & %w[name description asset_type]
    else
      text_columns.first(3) # Limit to prevent overly complex queries
    end
  end

  def generate_csv(records)
    CSV.generate(headers: true) do |csv|
      csv << column_headers
      
      records.find_each(batch_size: options[:batch_size] || 1000) do |record|
        csv << generate_row_data(record)
      end
    end
  end

  def column_headers
    @column_headers ||= if columns.present?
      columns.map { |col| format_header(col) }
    else
      default_columns_for_model.map { |col| format_header(col) }
    end
  end

  def format_header(column)
    column.to_s.humanize
  end

  def generate_row_data(record)
    column_list = columns.present? ? columns : default_columns_for_model
    
    column_list.map do |column|
      extract_value(record, column)
    end
  end

  def extract_value(record, column)
    case column.to_s
    when 'id', 'name', 'status', 'created_at', 'updated_at'
      record.send(column)
    when 'campaign_name'
      record.respond_to?(:campaign) ? record.campaign&.name : nil
    when 'brand_identity_name'
      record.respond_to?(:brand_identity) ? record.brand_identity&.name : nil
    when 'content_preview'
      if record.respond_to?(:content)
        truncate_content(record.content)
      elsif record.respond_to?(:content_text)
        truncate_content(record.content_text)
      end
    when 'performance_score'
      record.respond_to?(:performance_score) ? record.performance_score&.round(3) : nil
    when 'budget'
      record.respond_to?(:budget) ? record.budget : nil
    when 'duration_days'
      record.respond_to?(:duration_days) ? record.duration_days : nil
    when 'tags_list'
      if record.respond_to?(:tag_list)
        record.tag_list.join(', ')
      elsif record.respond_to?(:tags) && record.tags.is_a?(Array)
        record.tags.join(', ')
      end
    when 'metadata_summary'
      if record.respond_to?(:metadata) && record.metadata.present?
        summarize_metadata(record.metadata)
      end
    else
      # Try to get the value directly
      if record.respond_to?(column)
        value = record.send(column)
        format_value(value)
      else
        nil
      end
    end
  end

  def truncate_content(content, limit = 100)
    return nil unless content.present?
    content.length > limit ? "#{content[0, limit]}..." : content
  end

  def summarize_metadata(metadata)
    return nil unless metadata.is_a?(Hash)
    
    # Extract key metadata points
    summary_items = []
    
    if metadata['platform']
      summary_items << "Platform: #{metadata['platform']}"
    end
    
    if metadata['character_count']
      summary_items << "Chars: #{metadata['character_count']}"
    end
    
    if metadata['hashtag_count']
      summary_items << "Hashtags: #{metadata['hashtag_count']}"
    end
    
    summary_items.join('; ')
  end

  def format_value(value)
    case value
    when Time, DateTime
      value.strftime('%Y-%m-%d %H:%M:%S')
    when Date
      value.strftime('%Y-%m-%d')
    when Array
      value.join(', ')
    when Hash
      value.to_json
    when true, false
      value.to_s.capitalize
    when Numeric
      value.is_a?(Float) ? value.round(3) : value
    else
      value.to_s
    end
  end

  def default_columns_for_model
    case model_class.name
    when 'Campaign'
      self.class.default_campaign_columns
    when 'ContentVariant'
      self.class.default_content_variant_columns
    when 'ContentAsset'
      self.class.default_content_asset_columns
    when 'Journey'
      self.class.default_journey_columns
    when 'BrandAsset'
      self.class.default_brand_asset_columns
    else
      %w[id name status created_at updated_at]
    end
  end

  def generate_filename
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    model_name = model_class.name.underscore.pluralize
    "#{model_name}_export_#{timestamp}.csv"
  end

  # Default column configurations for different models
  def self.default_campaign_columns
    %w[
      id name status purpose budget start_date end_date 
      duration_days progress_percentage brand_identity_name
      created_at updated_at
    ]
  end

  def self.default_content_variant_columns
    %w[
      id name variant_number strategy_type status performance_score
      content_preview campaign_name tags_list metadata_summary
      created_at updated_at
    ]
  end

  def self.default_content_asset_columns
    %w[
      id title channel asset_type status content_preview
      campaign_name brand_identity_name file_size
      created_at updated_at
    ]
  end

  def self.default_journey_columns
    %w[
      id name description status priority campaign_name
      total_stages completed_stages progress_percentage
      created_at updated_at
    ]
  end

  def self.default_brand_asset_columns
    %w[
      id name asset_type status description file_size
      brand_identity_name metadata_summary
      created_at updated_at
    ]
  end

  # Batch export methods for multiple models
  def self.export_campaign_summary(campaign_id, options: {})
    filters = { campaign_id: campaign_id }
    
    {
      campaign: export_campaigns(filters: { ids: [campaign_id] }),
      content_variants: export_content_variants(filters: filters),
      content_assets: export_content_assets(filters: filters),
      journeys: export_journeys(filters: filters)
    }
  end

  def self.export_all_data(date_range: nil, options: {})
    base_filters = {}
    base_filters[:date_range] = date_range if date_range

    {
      campaigns: export_campaigns(filters: base_filters, options: options),
      content_variants: export_content_variants(filters: base_filters, options: options),
      content_assets: export_content_assets(filters: base_filters, options: options),
      journeys: export_journeys(filters: base_filters, options: options),
      brand_assets: export_brand_assets(filters: base_filters, options: options)
    }
  end

  # Custom CSV formats for specific use cases
  def self.export_performance_summary(options: {})
    new(
      model_class: ContentVariant,
      filters: { status: ['testing', 'completed'] },
      columns: %w[
        id name strategy_type performance_score campaign_name
        content_preview testing_started_at testing_completed_at
      ],
      options: options
    ).export
  end

  def self.export_active_campaigns_summary(options: {})
    new(
      model_class: Campaign,
      filters: { status: 'active' },
      columns: %w[
        id name start_date end_date days_remaining progress_percentage
        budget brand_identity_name status
      ],
      options: options
    ).export
  end
end