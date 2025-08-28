class CreateSecurityIncidents < ActiveRecord::Migration[8.0]
  def change
    create_table :security_incidents do |t|
      t.string :incident_id, null: false, index: { unique: true }
      t.string :incident_type, null: false
      t.string :severity, null: false
      t.string :status, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.references :user, null: true, foreign_key: true
      t.string :source_ip
      t.string :user_agent
      t.text :metadata # JSON serialized
      t.text :threat_indicators # JSON serialized  
      t.text :response_actions # JSON serialized
      t.datetime :status_updated_at
      t.datetime :resolved_at
      t.integer :false_positive_score, default: 0

      t.timestamps

      t.index [:incident_type, :severity]
      t.index [:status, :created_at]
      t.index [:severity, :created_at]
      t.index :source_ip
    end
  end
end
