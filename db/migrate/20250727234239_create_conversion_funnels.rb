class CreateConversionFunnels < ActiveRecord::Migration[8.0]
  def change
    create_table :conversion_funnels do |t|
      t.references :journey, null: false, foreign_key: true
      t.references :campaign, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :funnel_name, null: false
      t.string :stage, null: false
      t.integer :stage_order, null: false
      t.integer :visitors, default: 0
      t.integer :conversions, default: 0
      t.decimal :conversion_rate, precision: 5, scale: 2, default: 0.0
      t.decimal :drop_off_rate, precision: 5, scale: 2, default: 0.0
      t.datetime :period_start, null: false
      t.datetime :period_end, null: false
      t.json :metadata, default: {}

      t.timestamps
    end
    
    add_index :conversion_funnels, [:journey_id, :funnel_name, :stage_order], 
              name: 'index_conversion_funnels_on_journey_funnel_stage'
    add_index :conversion_funnels, [:campaign_id, :period_start]
    add_index :conversion_funnels, [:user_id, :period_start]
    add_index :conversion_funnels, :stage
    add_index :conversion_funnels, :conversion_rate
    add_index :conversion_funnels, :period_start
    add_index :conversion_funnels, [:funnel_name, :stage_order]
  end
end
