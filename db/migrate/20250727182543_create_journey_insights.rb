class CreateJourneyInsights < ActiveRecord::Migration[8.0]
  def change
    create_table :journey_insights do |t|
      t.references :journey, null: false, foreign_key: true
      t.string :insights_type, null: false
      t.json :data, default: {}
      t.datetime :calculated_at, null: false
      t.datetime :expires_at
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :journey_insights, [:journey_id, :insights_type]
    add_index :journey_insights, [:insights_type]
    add_index :journey_insights, [:calculated_at]
    add_index :journey_insights, [:expires_at]
    add_index :journey_insights, [:created_at]
  end
end
