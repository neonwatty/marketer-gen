class BrandIdentitiesController < ApplicationController
  before_action :set_brand_identity, only: [:show, :edit, :update, :destroy, :activate, :deactivate, :process_materials]
  
  def index
    authorize BrandIdentity
    @brand_identities = policy_scope(BrandIdentity).order(created_at: :desc)
    @active_brand_identity = Current.user.active_brand_identity
  end

  def show
    authorize @brand_identity
    @compliance_summary = calculate_compliance_summary if @brand_identity.active?
  end

  def new
    @brand_identity = Current.user.brand_identities.build
    authorize @brand_identity
  end

  def create
    @brand_identity = Current.user.brand_identities.build(brand_identity_params)
    authorize @brand_identity
    
    if @brand_identity.save
      if params[:brand_identity][:brand_materials].present? || 
         params[:brand_identity][:logo_files].present? || 
         params[:brand_identity][:style_guides].present?
        @brand_identity.process_materials!
        flash[:notice] = "Brand identity created successfully. Materials are being processed."
      else
        flash[:notice] = "Brand identity created successfully."
      end
      redirect_to @brand_identity
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @brand_identity
  end

  def update
    authorize @brand_identity
    if @brand_identity.update(brand_identity_params)
      if material_files_updated?
        @brand_identity.process_materials!
        flash[:notice] = "Brand identity updated successfully. Materials are being reprocessed."
      else
        flash[:notice] = "Brand identity updated successfully."
      end
      redirect_to @brand_identity
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @brand_identity
    @brand_identity.destroy
    flash[:notice] = "Brand identity deleted successfully."
    redirect_to brand_identities_path
  end

  def activate
    authorize @brand_identity, :activate?
    @brand_identity.activate!
    flash[:notice] = "Brand identity activated successfully."
    redirect_to @brand_identity
  rescue => e
    flash[:alert] = "Failed to activate brand identity: #{e.message}"
    redirect_to @brand_identity
  end

  def deactivate
    authorize @brand_identity, :deactivate?
    @brand_identity.deactivate!
    flash[:notice] = "Brand identity deactivated successfully."
    redirect_to @brand_identity
  end

  def process_materials
    authorize @brand_identity, :process_materials?
    @brand_identity.process_materials!
    flash[:notice] = "Brand materials processing started. This may take a few minutes."
    redirect_to @brand_identity
  end

  private

  def set_brand_identity
    @brand_identity = BrandIdentity.find(params[:id])
  end

  def brand_identity_params
    params.require(:brand_identity).permit(
      :name, :description, :brand_voice, :tone_guidelines, 
      :messaging_framework, :restrictions,
      brand_materials: [],
      logo_files: [],
      style_guides: []
    )
  end

  def material_files_updated?
    params[:brand_identity][:brand_materials].present? ||
    params[:brand_identity][:logo_files].present? ||
    params[:brand_identity][:style_guides].present?
  end

  def calculate_compliance_summary
    # This would be used to show compliance stats on the brand identity page
    return {} unless @brand_identity.active?
    
    # For now, return placeholder data
    {
      total_content_checks: 0,
      compliant_content: 0,
      compliance_rate: 0.0,
      common_violations: []
    }
  end
end
