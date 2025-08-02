class CreateAbTestConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :ab_test_configurations do |t|
      t.references :ab_test, null: false, foreign_key: true
      t.string :configuration_type
      t.json :settings
      t.boolean :is_active

      t.timestamps
    end
  end
end
