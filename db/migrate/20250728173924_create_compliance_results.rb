class CreateComplianceResults < ActiveRecord::Migration[8.0]
  def change
    create_table :compliance_results do |t|
      t.references :brand, null: false, foreign_key: true
      t.string :content_type
      t.string :content_hash
      t.boolean :compliant
      t.decimal :score, precision: 5, scale: 3
      t.integer :violations_count, default: 0
      t.json :violations_data, default: []
      t.json :suggestions_data, default: []
      t.json :analysis_data, default: {}
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :compliance_results, :content_hash
    add_index :compliance_results, :compliant
    add_index :compliance_results, [:brand_id, :content_type]
    add_index :compliance_results, :created_at
  end
end
