class CreateSuggestionFeedback < ActiveRecord::Migration[8.0]
  def change
    create_table :suggestion_feedbacks do |t|
      t.references :journey, null: false, foreign_key: true
      t.references :journey_step, null: false, foreign_key: true
      t.integer :suggested_step_id
      t.references :user, null: false, foreign_key: true
      t.string :feedback_type, null: false
      t.integer :rating, limit: 1 # 1-5 rating scale
      t.boolean :selected, default: false, null: false
      t.text :context
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :suggestion_feedbacks, [:journey_id, :user_id]
    add_index :suggestion_feedbacks, [:journey_step_id, :feedback_type]
    add_index :suggestion_feedbacks, [:suggested_step_id]
    add_index :suggestion_feedbacks, [:rating]
    add_index :suggestion_feedbacks, [:selected]
    add_index :suggestion_feedbacks, [:created_at]
    
    # Add check constraint for rating
    add_check_constraint :suggestion_feedbacks, 'rating >= 1 AND rating <= 5', name: 'rating_range'
  end
end
