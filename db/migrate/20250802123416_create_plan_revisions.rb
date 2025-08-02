class CreatePlanRevisions < ActiveRecord::Migration[8.0]
  def change
    create_table :plan_revisions do |t|
      t.references :campaign_plan, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :revision_number
      t.text :plan_data
      t.text :change_summary
      t.text :changes_made
      t.text :metadata

      t.timestamps
    end
  end
end
