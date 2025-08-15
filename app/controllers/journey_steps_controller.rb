class JourneyStepsController < ApplicationController
  before_action :require_authentication
  before_action :set_journey
  before_action :set_journey_step, only: [:edit, :update, :destroy]

  def new
    @journey_step = @journey.journey_steps.build
    authorize @journey_step
  end

  def create
    @journey_step = @journey.journey_steps.build(journey_step_params)
    authorize @journey_step
    
    if @journey_step.save
      redirect_to @journey, notice: 'Journey step was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @journey_step
  end

  def update
    authorize @journey_step
    if @journey_step.update(journey_step_params)
      redirect_to @journey, notice: 'Journey step was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @journey_step
    @journey_step.destroy
    redirect_to @journey, notice: 'Journey step was successfully deleted.'
  end

  private

  def set_journey
    @journey = policy_scope(Journey).find(params[:journey_id])
  end

  def set_journey_step
    @journey_step = @journey.journey_steps.find(params[:id])
  end

  def journey_step_params
    params.require(:journey_step).permit(:title, :description, :step_type, :channel, :sequence_order, settings: {})
  end
end