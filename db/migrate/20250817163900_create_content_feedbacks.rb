class CreateContentFeedbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :content_feedbacks do |t|
      t.references :generated_content, null: false, foreign_key: true
      t.references :reviewer_user, null: false, foreign_key: { to_table: :users }
      t.text :feedback_text, null: false
      t.string :feedback_type, null: false
      t.datetime :resolved_at
      t.references :resolved_by_user, null: true, foreign_key: { to_table: :users }
      t.references :approval_workflow, null: true, foreign_key: true
      t.integer :priority, default: 1
      t.string :status, default: 'pending', null: false
      t.json :metadata

      t.timestamps
    end
    
    add_index :content_feedbacks, :feedback_type
    add_index :content_feedbacks, :status
    add_index :content_feedbacks, :priority
    add_index :content_feedbacks, :created_at
    add_index :content_feedbacks, [:generated_content_id, :status]
  end
end
