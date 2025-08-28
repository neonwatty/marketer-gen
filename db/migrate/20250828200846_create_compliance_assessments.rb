class CreateComplianceAssessments < ActiveRecord::Migration[8.0]
  def change
    create_table :compliance_assessments do |t|
      t.references :compliance_requirement, null: false, foreign_key: true
      t.integer :total_criteria
      t.integer :met_criteria
      t.date :assessment_date
      t.string :status

      t.timestamps
    end
  end
end
