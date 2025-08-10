class BrandAssetsController < ApplicationController
  before_action :set_brand_asset, only: [:update, :update_metadata, :destroy]
  
  # GET /brand_assets
  def index
    @brand_assets = BrandAsset.active
                             .includes([file_attachment: :blob])
                             .recent
                             .limit(20)
                             .offset((params[:page].to_i - 1) * 20)

    # Apply filters if present
    @brand_assets = @brand_assets.by_file_type(params[:file_type]) if params[:file_type].present?
    @brand_assets = @brand_assets.by_scan_status(params[:scan_status]) if params[:scan_status].present?
    @brand_assets = @brand_assets.search_content(params[:search]) if params[:search].present?

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
      'brand_guideline' => 10.megabytes,
      'style_guide' => 10.megabytes, 
      'compliance_document' => 10.megabytes,
      'presentation' => 10.megabytes,
      'logo' => 5.megabytes,
      'image_asset' => 5.megabytes,
      'font_file' => 2.megabytes,
      'color_palette' => 1.megabyte,
      'brand_template' => 5.megabytes,
      'other' => 5.megabytes
    }
  end

  # POST /brand_assets
  def create
    @brand_asset = BrandAsset.new(brand_asset_params)
    
    if @brand_asset.save
      render json: {
        success: true,
        brand_asset: serialize_brand_asset(@brand_asset),
        message: 'Brand asset uploaded successfully'
      }, status: :created
    else
      render json: {
        success: false,
        errors: @brand_asset.errors.full_messages,
        message: 'Failed to upload brand asset'
      }, status: :unprocessable_entity
    end
  end

  # POST /brand_assets/upload_multiple
  def upload_multiple
    uploaded_assets = []
    failed_uploads = []

    upload_params = params.require(:uploads)

    upload_params.each do |upload_data|
      brand_asset = BrandAsset.new(
        file: upload_data[:file],
        file_type: upload_data[:file_type],
        purpose: upload_data[:purpose],
        assetable: find_or_create_assetable(upload_data)
      )

      if brand_asset.save
        uploaded_assets << serialize_brand_asset(brand_asset)
      else
        failed_uploads << {
          filename: upload_data[:file]&.original_filename,
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
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /brand_assets/1
  def update
    if @brand_asset.update(brand_asset_params.except(:file))
      render json: {
        success: true,
        brand_asset: serialize_brand_asset(@brand_asset),
        message: 'Brand asset updated successfully'
      }
    else
      render json: {
        success: false,
        errors: @brand_asset.errors.full_messages,
        message: 'Failed to update brand asset'
      }, status: :unprocessable_entity
    end
  end

  # PATCH /brand_assets/1/update_metadata
  def update_metadata
    metadata_params = params.require(:metadata)

    if @brand_asset.merge_metadata(metadata_params)
      render json: {
        success: true,
        brand_asset: serialize_brand_asset(@brand_asset),
        message: 'Metadata updated successfully'
      }
    else
      render json: {
        success: false,
        errors: @brand_asset.errors.full_messages,
        message: 'Failed to update metadata'
      }, status: :unprocessable_entity
    end
  end

  # DELETE /brand_assets/1
  def destroy
    if @brand_asset.destroy
      render json: {
        success: true,
        message: 'Brand asset deleted successfully'
      }
    else
      render json: {
        success: false,
        errors: @brand_asset.errors.full_messages,
        message: 'Failed to delete brand asset'
      }, status: :unprocessable_entity
    end
  end

  private

  def set_brand_asset
    @brand_asset = BrandAsset.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: 'Brand asset not found'
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
    assetable_type = upload_data[:assetable_type] || 'BrandIdentity'
    assetable_id = upload_data[:assetable_id]

    case assetable_type
    when 'BrandIdentity'
      if assetable_id.present?
        BrandIdentity.find(assetable_id)
      else
        # Create a default brand identity if none exists
        BrandIdentity.first_or_create(
          name: 'Default Brand Identity',
          description: 'Default brand identity for uploaded assets'
        )
      end
    when 'Campaign'
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
end