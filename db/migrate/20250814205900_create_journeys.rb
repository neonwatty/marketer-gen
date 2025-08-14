class CreateJourneys < ActiveRecord::Migration[8.0]
  def change
    create_table :journeys do |t|
      t.string :name, null: false
      t.text :description
      t.string :campaign_type, null: false
      t.references :user, null: false, foreign_key: true
      t.text :stages
      t.string :status, default: 'draft', null: false
      t.string :template_type
      t.text :metadata

      t.timestamps
    end

    add_index :journeys, [:user_id, :name]
    add_index :journeys, :campaign_type
    add_index :journeys, :status
    add_index :journeys, :template_type
  end
end
