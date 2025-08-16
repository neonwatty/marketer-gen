class CreatePlanVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :plan_versions do |t|
      t.references :campaign_plan, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.json :content
      t.json :metadata
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :status, default: 'draft'
      t.text :change_summary
      t.boolean :is_current, default: false

      t.timestamps
    end

    add_index :plan_versions, [:campaign_plan_id, :version_number], unique: true
    add_index :plan_versions, [:campaign_plan_id, :is_current]
    add_index :plan_versions, :status
  end
end
