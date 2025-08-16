class CreatePlanShareTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :plan_share_tokens do |t|
      t.references :campaign_plan, null: false, foreign_key: true
      t.string :token, null: false
      t.string :email, null: false
      t.datetime :expires_at, null: false
      t.datetime :accessed_at
      t.integer :access_count, default: 0, null: false

      t.timestamps
    end
    add_index :plan_share_tokens, :token, unique: true
    add_index :plan_share_tokens, :email
    add_index :plan_share_tokens, :expires_at
  end
end
