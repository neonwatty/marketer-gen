class CreateBrandAnalyses < ActiveRecord::Migration[8.0]
  def change
    create_table :brand_analyses do |t|
      t.references :brand, null: false, foreign_key: true
      t.json :analysis_data, default: {}
      t.json :extracted_rules, default: {}
      t.json :voice_attributes, default: {}
      t.json :brand_values, default: []
      t.json :messaging_pillars, default: []
      t.json :visual_guidelines, default: {}
      t.string :analysis_status, default: "pending"
      t.datetime :analyzed_at
      t.float :confidence_score
      t.text :analysis_notes

      t.timestamps
    end

    add_index :brand_analyses, :analysis_status
    add_index :brand_analyses, [:brand_id, :created_at]
  end
end
