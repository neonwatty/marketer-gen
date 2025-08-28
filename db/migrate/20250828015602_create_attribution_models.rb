class CreateAttributionModels < ActiveRecord::Migration[8.0]
  def change
    create_table :attribution_models do |t|
      t.references :user, null: false, foreign_key: true
      t.references :touchpoint, null: false, foreign_key: true
      t.references :journey, null: false, foreign_key: true
      t.string :model_type, null: false
      t.decimal :attribution_percentage, precision: 5, scale: 2, null: false
      t.decimal :conversion_value, precision: 10, scale: 2
      t.decimal :confidence_score, precision: 4, scale: 4
      t.text :calculation_metadata
      t.text :algorithm_parameters

      t.timestamps
    end

    add_index :attribution_models, [:journey_id, :model_type]
    add_index :attribution_models, [:touchpoint_id, :model_type]
    add_index :attribution_models, :model_type
    add_index :attribution_models, :confidence_score
  end
end
