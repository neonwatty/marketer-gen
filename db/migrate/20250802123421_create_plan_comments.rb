class CreatePlanComments < ActiveRecord::Migration[8.0]
  def change
    create_table :plan_comments do |t|
      t.references :campaign_plan, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :parent_comment, null: true, foreign_key: { to_table: :plan_comments }
      t.text :content
      t.string :section
      t.string :comment_type
      t.string :priority
      t.integer :line_number
      t.boolean :resolved
      t.datetime :resolved_at
      t.references :resolved_by_user, null: true, foreign_key: { to_table: :users }
      t.text :mentioned_users
      t.text :metadata

      t.timestamps
    end
  end
end
