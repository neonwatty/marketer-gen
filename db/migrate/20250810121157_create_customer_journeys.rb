class CreateCustomerJourneys < ActiveRecord::Migration[8.0]
  def change
    create_table :customer_journeys do |t|
      t.references :campaign, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.json :stages, null: false, default: []
      t.json :content_types, null: false, default: []
      t.json :touchpoints, null: false, default: {}
      t.json :metrics, null: false, default: {}
      t.integer :position, default: 0

      t.timestamps
    end

    # Add indexes for performance
    add_index :customer_journeys, :position
    add_index :customer_journeys, :name
  end
end
