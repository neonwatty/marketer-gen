class CreateFeedbackComments < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_comments do |t|
      t.references :plan_version, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content, null: false
      t.string :comment_type, default: 'general' # general, suggestion, concern, approval
      t.string :priority, default: 'medium' # low, medium, high, critical
      t.string :status, default: 'open' # open, addressed, resolved, dismissed
      t.json :metadata
      t.references :parent_comment, null: true, foreign_key: { to_table: :feedback_comments }
      t.text :section_reference # Reference to specific section of the plan

      t.timestamps
    end

    add_index :feedback_comments, [:plan_version_id, :status]
    add_index :feedback_comments, [:user_id, :created_at]
    add_index :feedback_comments, :comment_type
    add_index :feedback_comments, :priority
  end
end
