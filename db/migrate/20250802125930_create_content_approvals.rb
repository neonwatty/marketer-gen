class CreateContentApprovals < ActiveRecord::Migration[8.0]
  def change
    create_table :content_approvals do |t|
      t.references :content_repository, null: false, foreign_key: true
      t.references :workflow, null: true, foreign_key: { to_table: :content_workflows }
      t.references :user, null: false, foreign_key: true
      t.references :assigned_approver, null: true, foreign_key: { to_table: :users }
      t.integer :approval_step
      t.integer :status
      t.integer :step_order

      t.timestamps
    end
  end
end
