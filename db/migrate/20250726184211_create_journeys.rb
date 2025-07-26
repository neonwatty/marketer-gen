class CreateJourneys < ActiveRecord::Migration[8.0]
  def change
    create_table :journeys do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :status, default: 'draft', null: false
      t.string :brand_id
      t.string :campaign_type
      t.text :target_audience
      t.text :goals
      t.json :metadata, default: {}
      t.json :settings, default: {}
      t.datetime :published_at
      t.datetime :archived_at

      t.timestamps
    end
    
    add_index :journeys, :status
    add_index :journeys, :brand_id
    add_index :journeys, :campaign_type
    add_index :journeys, [:user_id, :status]
    add_index :journeys, :published_at
  end
end
