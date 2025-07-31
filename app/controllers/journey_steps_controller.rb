class JourneyStepsController < ApplicationController
  include Authentication
  include ActivityTracker
  
  before_action :set_journey
  before_action :set_journey_step, only: [:show, :edit, :update, :destroy, :move, :duplicate]
  before_action :ensure_user_can_access_journey
  before_action :ensure_user_can_access_step, only: [:show, :edit, :update, :destroy, :move, :duplicate]
  
  # GET /journeys/:journey_id/steps/:id
  def show
    @transitions_from = @journey_step.transitions_from.includes(:to_step)
    @transitions_to = @journey_step.transitions_to.includes(:from_step)
    
    # Track activity  
    track_activity('viewed_journey_step', { 
      journey_id: @journey.id,
      step_id: @journey_step.id,
      step_name: @journey_step.name
    })
    
    respond_to do |format|
      format.html
      format.json { render json: serialize_step_for_json(@journey_step) }
    end
  end
  
  # GET /journeys/:journey_id/steps/new
  def new
    @journey_step = @journey.journey_steps.build
    
    # Set defaults
    @journey_step.stage = params[:stage] if params[:stage].present?
    @journey_step.content_type = params[:content_type] if params[:content_type].present?
    @journey_step.channel = params[:channel] if params[:channel].present?
    
    authorize @journey_step
    
    respond_to do |format|
      format.html
      format.json { render json: serialize_step_for_json(@journey_step) }
    end
  end
  
  # POST /journeys/:journey_id/steps
  def create
    @journey_step = @journey.journey_steps.build(journey_step_params)
    authorize @journey_step
    
    respond_to do |format|
      if @journey_step.save
        # Track activity
        track_activity('created_journey_step', { 
          journey_id: @journey.id,
          step_id: @journey_step.id,
          step_name: @journey_step.name,
          stage: @journey_step.stage,
          content_type: @journey_step.content_type
        })
        
        format.html { redirect_to [@journey, @journey_step], notice: 'Journey step was successfully created.' }
        format.json { render json: serialize_step_for_json(@journey_step), status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @journey_step.errors.as_json }, status: :unprocessable_entity }
      end
    end
  end
  
  # GET /journeys/:journey_id/steps/:id/edit
  def edit
    respond_to do |format|
      format.html
      format.json { render json: serialize_step_for_json(@journey_step) }
    end
  end
  
  # PATCH/PUT /journeys/:journey_id/steps/:id
  def update
    respond_to do |format|
      if @journey_step.update(journey_step_params)
        # Track activity
        track_activity('updated_journey_step', { 
          journey_id: @journey.id,
          step_id: @journey_step.id,
          step_name: @journey_step.name,
          changes: @journey_step.saved_changes.keys
        })
        
        format.html { redirect_to [@journey, @journey_step], notice: 'Journey step was successfully updated.' }
        format.json { render json: serialize_step_for_json(@journey_step) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @journey_step.errors.as_json }, status: :unprocessable_entity }
      end
    end
  end
  
  # DELETE /journeys/:journey_id/steps/:id
  def destroy
    step_name = @journey_step.name
    @journey_step.destroy!
    
    # Track activity
    track_activity('deleted_journey_step', { 
      journey_id: @journey.id,
      step_name: step_name,
      step_id: params[:id]
    })
    
    respond_to do |format|
      format.html { redirect_to @journey, notice: 'Journey step was successfully deleted.' }
      format.json { render json: { message: 'Journey step was successfully deleted.' } }
    end
  end
  
  # PATCH /journeys/:journey_id/steps/:id/move
  def move
    new_position = params[:position].to_i
    
    respond_to do |format|
      begin
        @journey_step.move_to_position(new_position)
        
        # Track activity
        track_activity('moved_journey_step', { 
          journey_id: @journey.id,
          step_id: @journey_step.id,
          step_name: @journey_step.name,
          new_position: new_position
        })
        
        format.html { redirect_to @journey, notice: 'Journey step position updated successfully.' }
        format.json { render json: serialize_step_for_json(@journey_step.reload) }
      rescue => e
        format.html { redirect_to @journey, alert: "Failed to move step: #{e.message}" }
        format.json { render json: { error: "Failed to move step: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end
  
  # POST /journeys/:journey_id/steps/:id/duplicate
  def duplicate
    respond_to do |format|
      begin
        # Create a duplicate of the step
        @new_step = @journey_step.dup
        @new_step.name = "#{@journey_step.name} (Copy)"
        @new_step.position = nil # Will be set automatically
        
        if @new_step.save
          # Track activity
          track_activity('duplicated_journey_step', { 
            journey_id: @journey.id,
            original_step_id: @journey_step.id,
            new_step_id: @new_step.id,
            step_name: @new_step.name
          })
          
          format.html { redirect_to [@journey, @new_step], notice: 'Journey step was successfully duplicated.' }
          format.json { render json: serialize_step_for_json(@new_step), status: :created }
        else
          format.html { redirect_to [@journey, @journey_step], alert: 'Failed to duplicate step.' }
          format.json { render json: { errors: @new_step.errors.as_json }, status: :unprocessable_entity }
        end
      rescue => e
        format.html { redirect_to [@journey, @journey_step], alert: "Failed to duplicate step: #{e.message}" }
        format.json { render json: { error: "Failed to duplicate step: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end
  
  private
  
  def set_journey
    @journey = Journey.find(params[:journey_id])
  end
  
  def set_journey_step
    @journey_step = @journey.journey_steps.find(params[:id])
  end
  
  def ensure_user_can_access_journey
    authorize @journey
  end
  
  def ensure_user_can_access_step
    authorize @journey_step
  end
  
  def journey_step_params
    params.require(:journey_step).permit(
      :name, :description, :stage, :content_type, :channel, :duration_days,
      :is_entry_point, :is_exit_point, config: {}, conditions: {}, metadata: {}
    )
  end
  
  def serialize_step_for_json(step)
    {
      id: step.id,
      name: step.name,
      description: step.description,
      stage: step.stage,
      position: step.position,
      content_type: step.content_type,
      channel: step.channel,
      duration_days: step.duration_days,
      config: step.config,
      conditions: step.conditions,
      metadata: step.metadata,
      is_entry_point: step.is_entry_point,
      is_exit_point: step.is_exit_point,
      journey_id: step.journey_id,
      created_at: step.created_at,
      updated_at: step.updated_at,
      transitions_from: step.transitions_from.map { |t| serialize_transition(t) },
      transitions_to: step.transitions_to.map { |t| serialize_transition(t) },
      brand_compliant: step.respond_to?(:brand_compliant?) ? step.brand_compliant? : true,
      compliance_score: step.respond_to?(:quick_compliance_score) ? step.quick_compliance_score : 1.0
    }
  end
  
  def serialize_transition(transition)
    {
      id: transition.id,
      from_step_id: transition.from_step_id,
      to_step_id: transition.to_step_id,
      from_step_name: transition.from_step&.name,
      to_step_name: transition.to_step&.name,
      transition_type: transition.transition_type,
      conditions: transition.conditions,
      priority: transition.priority,
      metadata: transition.metadata
    }
  end
end