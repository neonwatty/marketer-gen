class CreateCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.string :name, null: false
      t.text :description
      t.references :persona, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, default: 'draft', null: false
      t.string :campaign_type
      t.text :goals
      t.json :target_metrics, default: {}
      t.json :metadata, default: {}
      t.json :settings, default: {}
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end
    
    add_index :campaigns, [:user_id, :status]
    add_index :campaigns, [:persona_id, :status]
    add_index :campaigns, :campaign_type
    add_index :campaigns, :started_at
    add_index :campaigns, :ended_at
    add_index :campaigns, [:user_id, :name], unique: true
  end
end
