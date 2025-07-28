class BrandAssetsController < ApplicationController
  before_action :set_brand
  before_action :set_brand_asset, only: [:show, :edit, :update, :destroy, :reprocess, :download]

  def index
    @brand_assets = @brand.brand_assets.includes(:file_attachment)
  end

  def show
  end

  def new
    @brand_asset = @brand.brand_assets.build
  end

  def create
    if params[:brand_asset][:files].present?
      # Handle multiple file uploads
      @brand_assets = []
      @errors = []
      
      params[:brand_asset][:files].each do |file|
        brand_asset = @brand.brand_assets.build(
          file: file,
          asset_type: determine_asset_type(file),
          original_filename: file.original_filename
        )
        
        if brand_asset.save
          @brand_assets << brand_asset
        else
          @errors << { filename: file.original_filename, errors: brand_asset.errors.full_messages }
        end
      end
      
      if request.xhr?
        render json: {
          success: @errors.empty?,
          assets: @brand_assets.map { |asset| asset_json(asset) },
          errors: @errors
        }
      else
        if @errors.empty?
          redirect_to brand_brand_assets_path(@brand), 
                      notice: "#{@brand_assets.count} asset(s) uploaded successfully."
        else
          flash[:alert] = "Some files failed to upload: #{@errors.map { |e| e[:filename] }.join(', ')}"
          redirect_to new_brand_brand_asset_path(@brand)
        end
      end
    else
      # Handle single file upload
      @brand_asset = @brand.brand_assets.build(brand_asset_params)
      
      if @brand_asset.save
        if request.xhr?
          render json: { success: true, asset: asset_json(@brand_asset) }
        else
          redirect_to brand_brand_asset_path(@brand, @brand_asset), 
                      notice: 'Brand asset was successfully uploaded and is being processed.'
        end
      else
        if request.xhr?
          render json: { success: false, errors: @brand_asset.errors.full_messages }, status: :unprocessable_entity
        else
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  def edit
  end

  def update
    if @brand_asset.update(brand_asset_params)
      redirect_to brand_brand_asset_path(@brand, @brand_asset), 
                  notice: 'Brand asset was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @brand_asset.destroy!
    redirect_to brand_brand_assets_url(@brand), 
                notice: 'Brand asset was successfully destroyed.'
  end

  def reprocess
    @brand_asset.update!(processing_status: 'pending')
    BrandAssetProcessingJob.perform_later(@brand_asset)
    
    redirect_to brand_brand_asset_path(@brand, @brand_asset), 
                notice: 'Brand asset is being reprocessed.'
  end

  def download
    if @brand_asset.file.attached?
      redirect_to rails_blob_url(@brand_asset.file, disposition: "attachment")
    else
      redirect_to brand_brand_assets_url(@brand), 
                  alert: 'No file attached to this asset.'
    end
  end

  # AJAX endpoint for upload status
  def status
    @brand_asset = @brand.brand_assets.find(params[:id])
    render json: asset_json(@brand_asset)
  end

  # AJAX endpoint for batch status check
  def batch_status
    asset_ids = params[:asset_ids].split(',')
    @brand_assets = @brand.brand_assets.where(id: asset_ids)
    render json: {
      assets: @brand_assets.map { |asset| asset_json(asset) }
    }
  end

  private

  def set_brand
    @brand = current_user.brands.find(params[:brand_id])
  end

  def set_brand_asset
    @brand_asset = @brand.brand_assets.find(params[:id])
  end

  def brand_asset_params
    params.require(:brand_asset).permit(:file, :asset_type, :original_filename)
  end

  def determine_asset_type(file)
    content_type = file.content_type
    filename = file.original_filename.downcase
    
    case content_type
    when *BrandAsset::ALLOWED_CONTENT_TYPES[:image]
      return 'logo' if filename.include?('logo')
      'image'
    when *BrandAsset::ALLOWED_CONTENT_TYPES[:document]
      return 'brand_guidelines' if filename.include?('guideline') || filename.include?('brand')
      return 'style_guide' if filename.include?('style')
      'document'
    when *BrandAsset::ALLOWED_CONTENT_TYPES[:video]
      'video'
    else
      'document' # Default fallback
    end
  end

  def asset_json(asset)
    {
      id: asset.id,
      filename: asset.original_filename,
      asset_type: asset.asset_type,
      processing_status: asset.processing_status,
      file_size: asset.file_size_mb.round(2),
      content_type: asset.file.attached? ? asset.file.content_type : nil,
      url: asset.file.attached? ? rails_blob_path(asset.file) : nil,
      download_url: brand_brand_asset_path(@brand, asset, format: :download),
      created_at: asset.created_at.iso8601,
      processed_at: asset.processed_at&.iso8601
    }
  end
end
