class CreateComplianceRequirements < ActiveRecord::Migration[8.0]
  def change
    create_table :compliance_requirements do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :compliance_type
      t.text :description
      t.string :risk_level
      t.string :status
      t.datetime :implementation_deadline
      t.datetime :next_review_date
      t.string :responsible_party
      t.text :regulatory_reference
      t.string :monitoring_frequency
      t.text :custom_rules
      t.text :evidence_requirements
      t.text :monitoring_criteria

      t.timestamps
    end
  end
end
