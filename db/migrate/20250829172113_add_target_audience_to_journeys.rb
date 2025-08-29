class AddTargetAudienceToJourneys < ActiveRecord::Migration[8.0]
  def change
    add_column :journeys, :target_audience, :text
  end
end
