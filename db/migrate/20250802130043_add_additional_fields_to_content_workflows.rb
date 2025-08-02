class AddAdditionalFieldsToContentWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_column :content_workflows, :cancellation_reason, :text
    add_reference :content_workflows, :cancelled_by, null: true, foreign_key: { to_table: :users }
    add_column :content_workflows, :cancelled_at, :datetime
    add_column :content_workflows, :completed_at, :datetime
    add_reference :content_workflows, :restarted_by, null: true, foreign_key: { to_table: :users }
    add_column :content_workflows, :restarted_at, :datetime
  end
end
