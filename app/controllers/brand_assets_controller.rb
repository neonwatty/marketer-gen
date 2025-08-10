class BrandAssetsController < ApplicationController
  before_action :set_brand_asset, only: [ :update, :update_metadata, :destroy ]

  # GET /brand_assets
  def index
    @brand_assets = BrandAsset.active.includes([ file_attachment: :blob ])

    # Apply search and filters
    apply_search_and_filters

    # Apply sorting
    apply_sorting

    # Apply pagination
    page = [ params[:page].to_i, 1 ].max
    per_page = params[:per_page]&.to_i || 20
    offset = (page - 1) * per_page

    @brand_assets = @brand_assets.limit(per_page).offset(offset)

    respond_to do |format|
      format.html
      format.json { render json: serialize_brand_assets(@brand_assets) }
    end
  end

  # GET /brand_assets/new
  def new
    @brand_asset = BrandAsset.new
    @file_types = BrandAsset.file_types.keys
    @max_file_sizes = {
      "brand_guideline" => 10.megabytes,
      "style_guide" => 10.megabytes,
      "compliance_document" => 10.megabytes,
      "presentation" => 10.megabytes,
      "logo" => 5.megabytes,
      "image_asset" => 5.megabytes,
      "font_file" => 2.megabytes,
      "color_palette" => 1.megabyte,
      "brand_template" => 5.megabytes,
      "other" => 5.megabytes
    }
  end

  # POST /brand_assets
  def create
    @brand_asset = BrandAsset.new(brand_asset_params)

    if @brand_asset.save
      render json: {
        success: true,
        brand_asset: serialize_brand_asset(@brand_asset),
        message: "Brand asset uploaded successfully"
      }, status: :created
    else
      render json: {
        success: false,
        errors: @brand_asset.errors.full_messages,
        message: "Failed to upload brand asset"
      }, status: :unprocessable_content
    end
  end

  # POST /brand_assets/upload_multiple
  def upload_multiple
    uploaded_assets = []
    failed_uploads = []

    upload_params = params.require(:uploads)

    upload_params.each do |upload_data|
      # Convert Parameters to hash and permit the necessary fields
      permitted_data = upload_data.permit(:file, :file_type, :purpose, :assetable_type, :assetable_id)

      brand_asset = BrandAsset.new(
        file: permitted_data[:file],
        file_type: permitted_data[:file_type],
        purpose: permitted_data[:purpose],
        assetable: find_or_create_assetable(permitted_data)
      )

      if brand_asset.save
        uploaded_assets << serialize_brand_asset(brand_asset)
      else
        failed_uploads << {
          filename: permitted_data[:file]&.original_filename,
          errors: brand_asset.errors.full_messages
        }
      end
    end

    if failed_uploads.empty?
      render json: {
        success: true,
        brand_assets: uploaded_assets,
        message: "Successfully uploaded #{uploaded_assets.count} file(s)"
      }, status: :created
    else
      render json: {
        success: false,
        uploaded_assets: uploaded_assets,
        failed_uploads: failed_uploads,
        message: "#{failed_uploads.count} file(s) failed to upload"
      }, status: :unprocessable_content
    end
  end

  # PATCH/PUT /brand_assets/1
  def update
    if @brand_asset.update(brand_asset_params.except(:file))
      render json: {
        success: true,
        brand_asset: serialize_brand_asset(@brand_asset),
        message: "Brand asset updated successfully"
      }
    else
      render json: {
        success: false,
        errors: @brand_asset.errors.full_messages,
        message: "Failed to update brand asset"
      }, status: :unprocessable_content
    end
  end

  # PATCH /brand_assets/1/update_metadata
  def update_metadata
    metadata_params = params.require(:metadata)

    # Convert ActionController::Parameters to hash for merge_metadata
    # Handle case where metadata is not a valid Parameters object
    begin
      metadata_hash = metadata_params.respond_to?(:to_unsafe_h) ? metadata_params.to_unsafe_h : metadata_params
    rescue
      render json: {
        success: false,
        errors: [ "Invalid metadata format" ],
        message: "Metadata must be a valid object"
      }, status: :unprocessable_content
      return
    end

    # Ensure metadata_hash is a hash
    unless metadata_hash.is_a?(Hash)
      render json: {
        success: false,
        errors: [ "Invalid metadata format" ],
        message: "Metadata must be a valid object"
      }, status: :unprocessable_content
      return
    end

    if @brand_asset.merge_metadata(metadata_hash)
      render json: {
        success: true,
        brand_asset: serialize_brand_asset(@brand_asset),
        message: "Metadata updated successfully"
      }
    else
      render json: {
        success: false,
        errors: @brand_asset.errors.full_messages,
        message: "Failed to update metadata"
      }, status: :unprocessable_content
    end
  end

  # DELETE /brand_assets/1
  def destroy
    if @brand_asset.destroy
      render json: {
        success: true,
        message: "Brand asset deleted successfully"
      }
    else
      render json: {
        success: false,
        errors: @brand_asset.errors.full_messages,
        message: "Failed to delete brand asset"
      }, status: :unprocessable_content
    end
  end

  private

  def set_brand_asset
    @brand_asset = BrandAsset.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: "Brand asset not found"
    }, status: :not_found
  end

  def brand_asset_params
    params.require(:brand_asset).permit(
      :file,
      :file_type,
      :purpose,
      :assetable_type,
      :assetable_id,
      :active,
      metadata: {}
    )
  end

  def find_or_create_assetable(upload_data)
    # For now, we'll assume uploads are for a global brand identity
    # This can be extended later to support specific campaigns or other entities
    assetable_type = upload_data[:assetable_type] || "BrandIdentity"
    assetable_id = upload_data[:assetable_id]

    case assetable_type
    when "BrandIdentity"
      if assetable_id.present?
        BrandIdentity.find(assetable_id)
      else
        # Create a default brand identity if none exists
        BrandIdentity.first_or_create(
          name: "Default Brand Identity",
          description: "Default brand identity for uploaded assets"
        )
      end
    when "Campaign"
      Campaign.find(assetable_id) if assetable_id.present?
    else
      nil
    end
  end

  def serialize_brand_asset(brand_asset)
    {
      id: brand_asset.id,
      file_type: brand_asset.file_type,
      purpose: brand_asset.purpose,
      original_filename: brand_asset.original_filename,
      file_size: brand_asset.file_size,
      human_file_size: brand_asset.human_file_size,
      content_type: brand_asset.content_type,
      file_extension: brand_asset.file_extension,
      file_url: brand_asset.file_url,
      scan_status: brand_asset.scan_status,
      active: brand_asset.active,
      metadata: brand_asset.metadata,
      extracted_text: brand_asset.has_extracted_text? ? brand_asset.text_preview : nil,
      created_at: brand_asset.created_at,
      updated_at: brand_asset.updated_at,
      assetable_type: brand_asset.assetable_type,
      assetable_id: brand_asset.assetable_id
    }
  end

  def serialize_brand_assets(brand_assets)
    {
      brand_assets: brand_assets.map { |asset| serialize_brand_asset(asset) },
      meta: {
        current_page: brand_assets.respond_to?(:current_page) ? brand_assets.current_page : 1,
        total_pages: brand_assets.respond_to?(:total_pages) ? brand_assets.total_pages : 1,
        total_count: brand_assets.respond_to?(:total_count) ? brand_assets.total_count : brand_assets.count
      }
    }
  end

  def apply_search_and_filters
    # Search across multiple fields
    if params[:query].present? || params[:search].present?
      search_term = params[:query] || params[:search]
      @brand_assets = @brand_assets.search_content(search_term)
    end

    # File type filter
    if params[:file_type].present?
      @brand_assets = @brand_assets.by_file_type(params[:file_type])
    end

    # Scan status filter
    if params[:scan_status].present?
      @brand_assets = @brand_assets.by_scan_status(params[:scan_status])
    end

    # Size range filter
    if params[:size_range].present?
      case params[:size_range]
      when "small"
        @brand_assets = @brand_assets.where("file_size < ?", 1.megabyte)
      when "medium"
        @brand_assets = @brand_assets.where("file_size >= ? AND file_size <= ?", 1.megabyte, 5.megabytes)
      when "large"
        @brand_assets = @brand_assets.where("file_size > ?", 5.megabytes)
      end
    end

    # Purpose filter
    if params[:purpose].present?
      @brand_assets = @brand_assets.where("purpose LIKE ?", "%#{params[:purpose]}%")
    end

    # Date range filter
    if params[:date_from].present?
      @brand_assets = @brand_assets.where("created_at >= ?", params[:date_from])
    end

    if params[:date_to].present?
      @brand_assets = @brand_assets.where("created_at <= ?", params[:date_to])
    end

    # With extracted text
    if params[:has_text] == "true"
      @brand_assets = @brand_assets.with_text_extracted
    elsif params[:has_text] == "false"
      @brand_assets = @brand_assets.where(extracted_text: [ nil, "" ])
    end

    # Metadata filters
    if params[:tags].present?
      tag_list = params[:tags].split(",").map(&:strip)
      tag_list.each do |tag|
        @brand_assets = @brand_assets.where("JSON_EXTRACT(metadata, '$.tags') LIKE ?", "%#{tag}%")
      end
    end
  end

  def apply_sorting
    case params[:sort]
    when "oldest"
      @brand_assets = @brand_assets.order(created_at: :asc)
    when "name"
      @brand_assets = @brand_assets.order(original_filename: :asc)
    when "name_desc"
      @brand_assets = @brand_assets.order(original_filename: :desc)
    when "size"
      @brand_assets = @brand_assets.order(file_size: :asc)
    when "size_desc"
      @brand_assets = @brand_assets.order(file_size: :desc)
    when "file_type"
      @brand_assets = @brand_assets.order(file_type: :asc, created_at: :desc)
    when "scan_status"
      @brand_assets = @brand_assets.order(scan_status: :asc, created_at: :desc)
    else # 'recent' or default
      @brand_assets = @brand_assets.recent
    end
  end
end
