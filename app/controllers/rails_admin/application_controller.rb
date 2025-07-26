module RailsAdmin
  class ApplicationController < ::ApplicationController
    include AdminAuditable
    
    # Override to ensure we capture Rails Admin specific objects
    before_action :set_auditable_object

    private

    def set_auditable_object
      if params[:model_name].present?
        @model_name = params[:model_name]
        @abstract_model = RailsAdmin::AbstractModel.new(@model_name)
        
        if params[:id].present?
          @object = @abstract_model.get(params[:id])
        elsif action_name == "new"
          @object = @abstract_model.model.new
        end
      end
    end

    def _current_user
      current_user
    end
  end
end