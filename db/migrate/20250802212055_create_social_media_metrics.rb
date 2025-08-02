class CreateSocialMediaMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :social_media_metrics do |t|
      t.references :social_media_integration, null: false, foreign_key: true
      t.string :metric_type, null: false
      t.string :platform, null: false
      t.decimal :value, precision: 15, scale: 2
      t.date :date, null: false
      t.text :raw_data
      t.text :metadata

      t.timestamps
    end
    
    add_index :social_media_metrics, :metric_type
    add_index :social_media_metrics, :platform
    add_index :social_media_metrics, :date
    add_index :social_media_metrics, [:social_media_integration_id, :metric_type, :date], 
              unique: true, name: 'index_social_media_metrics_unique'
    add_index :social_media_metrics, [:platform, :date]
  end
end
