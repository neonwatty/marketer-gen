class CreateEmailMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :email_metrics do |t|
      t.references :email_integration, null: false, foreign_key: true
      t.references :email_campaign, null: false, foreign_key: true
      t.string :metric_type, null: false
      t.date :metric_date, null: false
      t.integer :opens, default: 0
      t.integer :clicks, default: 0
      t.integer :bounces, default: 0
      t.integer :unsubscribes, default: 0
      t.integer :complaints, default: 0
      t.integer :delivered, default: 0
      t.integer :sent, default: 0
      t.integer :unique_opens, default: 0
      t.integer :unique_clicks, default: 0
      t.decimal :open_rate, precision: 5, scale: 4, default: 0
      t.decimal :click_rate, precision: 5, scale: 4, default: 0
      t.decimal :bounce_rate, precision: 5, scale: 4, default: 0
      t.decimal :unsubscribe_rate, precision: 5, scale: 4, default: 0
      t.decimal :complaint_rate, precision: 5, scale: 4, default: 0
      t.decimal :delivery_rate, precision: 5, scale: 4, default: 0

      t.timestamps
    end

    add_index :email_metrics, [:email_campaign_id, :metric_date], unique: true
    add_index :email_metrics, :metric_type
    add_index :email_metrics, :metric_date
    add_index :email_metrics, [:email_integration_id, :metric_date]
  end
end
