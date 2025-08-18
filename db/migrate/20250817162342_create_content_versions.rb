class CreateContentVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :content_versions do |t|
      t.references :generated_content, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.string :action_type, null: false
      t.references :changed_by, null: false, foreign_key: { to_table: :users }
      t.text :changes_summary
      t.datetime :timestamp, null: false
      t.json :metadata

      t.timestamps
    end
    
    add_index :content_versions, [:generated_content_id, :version_number], unique: true
    add_index :content_versions, :action_type
    add_index :content_versions, :timestamp
  end
end
