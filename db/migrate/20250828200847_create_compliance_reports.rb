class CreateComplianceReports < ActiveRecord::Migration[8.0]
  def change
    create_table :compliance_reports do |t|
      t.references :compliance_requirement, null: false, foreign_key: true
      t.string :report_type
      t.datetime :generated_at

      t.timestamps
    end
  end
end
