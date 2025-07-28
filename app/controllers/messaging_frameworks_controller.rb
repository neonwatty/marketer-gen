class MessagingFrameworksController < ApplicationController
  before_action :set_brand
  before_action :set_messaging_framework

  def show
  end

  def edit
  end

  def update
    if @messaging_framework.update(messaging_framework_params)
      redirect_to brand_messaging_framework_path(@brand), 
                  notice: 'Messaging framework was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_brand
    @brand = current_user.brands.find(params[:brand_id])
  end

  def set_messaging_framework
    @messaging_framework = @brand.messaging_framework || @brand.create_messaging_framework!
  end

  def messaging_framework_params
    params.require(:messaging_framework).permit(
      :tagline,
      :mission_statement,
      :vision_statement,
      :active,
      key_messages: {},
      value_propositions: {},
      terminology: {},
      approved_phrases: [],
      banned_words: [],
      tone_attributes: {}
    )
  end
end
