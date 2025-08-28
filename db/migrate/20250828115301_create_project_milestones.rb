class CreateProjectMilestones < ActiveRecord::Migration[8.0]
  def change
    create_table :project_milestones do |t|
      t.references :campaign_plan, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :assigned_to, null: true, foreign_key: { to_table: :users }
      t.references :completed_by, null: true, foreign_key: { to_table: :users }
      t.string :name
      t.text :description
      t.date :due_date
      t.string :status
      t.string :priority
      t.string :milestone_type
      t.integer :estimated_hours
      t.integer :actual_hours
      t.integer :completion_percentage
      t.datetime :started_at
      t.datetime :completed_at
      t.text :notes
      t.text :resources_required
      t.text :deliverables
      t.text :dependencies
      t.text :risk_factors

      t.timestamps
    end
  end
end
