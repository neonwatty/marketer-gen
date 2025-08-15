class AddStatusToJourneySteps < ActiveRecord::Migration[8.0]
  def change
    add_column :journey_steps, :status, :string, null: false, default: 'draft'
    add_index :journey_steps, :status
  end
end
