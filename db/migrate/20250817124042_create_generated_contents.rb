class CreateGeneratedContents < ActiveRecord::Migration[8.0]
  def change
    create_table :generated_contents do |t|
      t.string :content_type, null: false
      t.string :title, null: false
      t.text :body_content, null: false
      t.string :format_variant, default: 'standard'
      t.string :status, default: 'draft', null: false
      t.integer :version_number, default: 1, null: false
      t.integer :original_content_id # Self-referential for version history
      t.references :campaign_plan, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :approved_by, null: true, foreign_key: { to_table: :users }
      t.text :metadata # JSON field for platform-specific settings
      t.datetime :deleted_at # Soft delete timestamp

      t.timestamps
    end

    # Add indexes for frequently queried fields
    add_index :generated_contents, :content_type
    add_index :generated_contents, :status
    add_index :generated_contents, :format_variant
    add_index :generated_contents, :version_number
    add_index :generated_contents, :original_content_id
    add_index :generated_contents, :deleted_at
    add_index :generated_contents, [:campaign_plan_id, :content_type]
    add_index :generated_contents, [:campaign_plan_id, :status]
    add_index :generated_contents, [:original_content_id, :version_number]
    add_index :generated_contents, [:created_by_id, :created_at]

    # Add foreign key for self-referential relationship
    add_foreign_key :generated_contents, :generated_contents, column: :original_content_id
  end
end
