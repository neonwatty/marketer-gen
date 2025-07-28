class BrandGuidelinesController < ApplicationController
  before_action :set_brand
  before_action :set_brand_guideline, only: [:show, :edit, :update, :destroy]

  def index
    @guidelines_by_category = @brand.brand_guidelines.active.ordered
                                    .group_by(&:category)
  end

  def show
  end

  def new
    @brand_guideline = @brand.brand_guidelines.build
  end

  def create
    @brand_guideline = @brand.brand_guidelines.build(brand_guideline_params)
    
    if @brand_guideline.save
      redirect_to brand_brand_guidelines_path(@brand), 
                  notice: 'Brand guideline was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @brand_guideline.update(brand_guideline_params)
      redirect_to brand_brand_guidelines_path(@brand), 
                  notice: 'Brand guideline was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @brand_guideline.destroy!
    redirect_to brand_brand_guidelines_path(@brand), 
                notice: 'Brand guideline was successfully destroyed.'
  end

  private

  def set_brand
    @brand = current_user.brands.find(params[:brand_id])
  end

  def set_brand_guideline
    @brand_guideline = @brand.brand_guidelines.find(params[:id])
  end

  def brand_guideline_params
    params.require(:brand_guideline).permit(
      :rule_type,
      :rule_content,
      :category,
      :priority,
      :active,
      examples: {},
      metadata: {}
    )
  end
end
