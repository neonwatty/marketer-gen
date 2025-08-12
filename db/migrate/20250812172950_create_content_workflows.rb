class CreateContentWorkflows < ActiveRecord::Migration[8.0]
  def change
    create_table :content_workflows do |t|
      t.references :content_item, polymorphic: true, null: false
      t.string :current_stage
      t.string :previous_stage
      t.string :template_name
      t.string :template_version
      t.integer :status
      t.integer :priority
      t.integer :created_by_id
      t.integer :updated_by_id
      t.text :metadata
      t.text :settings

      t.timestamps
    end
  end
end
