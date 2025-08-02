class CreateAbTestResults < ActiveRecord::Migration[8.0]
  def change
    create_table :ab_test_results do |t|
      t.references :ab_test, null: false, foreign_key: true
      t.string :event_type
      t.decimal :value
      t.decimal :confidence
      t.json :metadata

      t.timestamps
    end
  end
end
