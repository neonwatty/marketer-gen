class BrandsController < ApplicationController
  before_action :set_brand, only: [:show, :edit, :update, :destroy, :compliance_check, :check_content_compliance]

  def index
    @brands = current_user.brands.active.includes(:brand_assets, :latest_analysis)
  end

  def show
    @latest_analysis = @brand.latest_analysis
    @brand_assets = @brand.brand_assets.includes(:file_attachment)
    @guidelines = @brand.brand_guidelines.active.ordered
    @messaging_framework = @brand.messaging_framework
  end

  def new
    @brand = current_user.brands.build
  end

  def create
    @brand = current_user.brands.build(brand_params)
    
    if @brand.save
      redirect_to @brand, notice: 'Brand was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @brand.update(brand_params)
      redirect_to @brand, notice: 'Brand was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @brand.destroy!
    redirect_to brands_url, notice: 'Brand was successfully destroyed.'
  end

  def compliance_check
    @compliance_form = ComplianceCheckForm.new
  end

  def check_content_compliance
    content = params[:content]
    content_type = params[:content_type] || 'general'
    
    service = Branding::ComplianceService.new(@brand, content, content_type)
    result = service.validate_and_suggest
    
    respond_to do |format|
      format.json { render json: result }
      format.html do
        @compliance_result = result
        render :compliance_result
      end
    end
  end

  private

  def set_brand
    @brand = current_user.brands.find(params[:id])
  end

  def brand_params
    params.require(:brand).permit(
      :name,
      :description,
      :industry,
      :website,
      :active,
      color_scheme: {},
      typography: {},
      settings: {}
    )
  end
end
