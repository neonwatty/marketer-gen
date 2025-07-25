# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_07_26_184452) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "action", null: false
    t.string "controller", null: false
    t.string "request_path"
    t.string "request_method"
    t.string "ip_address"
    t.text "user_agent"
    t.string "session_id"
    t.integer "response_status"
    t.float "response_time"
    t.text "metadata"
    t.datetime "occurred_at", null: false
    t.string "referrer"
    t.boolean "suspicious", default: false
    t.string "device_type"
    t.string "browser_name"
    t.string "os_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_activities_on_action"
    t.index ["ip_address"], name: "index_activities_on_ip_address"
    t.index ["occurred_at"], name: "index_activities_on_occurred_at"
    t.index ["session_id"], name: "index_activities_on_session_id"
    t.index ["suspicious"], name: "index_activities_on_suspicious"
    t.index ["user_id", "occurred_at"], name: "index_activities_on_user_id_and_occurred_at"
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "admin_audit_logs", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "action"
    t.string "auditable_type"
    t.integer "auditable_id"
    t.text "change_details"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_admin_audit_logs_on_user_id"
  end

  create_table "journey_steps", force: :cascade do |t|
    t.integer "journey_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "stage", null: false
    t.integer "position", default: 0, null: false
    t.string "content_type"
    t.string "channel"
    t.integer "duration_days", default: 1
    t.json "config", default: {}
    t.json "conditions", default: {}
    t.json "metadata", default: {}
    t.boolean "is_entry_point", default: false
    t.boolean "is_exit_point", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel"], name: "index_journey_steps_on_channel"
    t.index ["content_type"], name: "index_journey_steps_on_content_type"
    t.index ["journey_id", "position"], name: "index_journey_steps_on_journey_id_and_position"
    t.index ["journey_id", "stage"], name: "index_journey_steps_on_journey_id_and_stage"
    t.index ["journey_id"], name: "index_journey_steps_on_journey_id"
    t.index ["stage"], name: "index_journey_steps_on_stage"
  end

  create_table "journey_templates", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "category", null: false
    t.string "campaign_type"
    t.boolean "is_active", default: true
    t.integer "usage_count", default: 0
    t.json "template_data", default: {}
    t.json "metadata", default: {}
    t.string "thumbnail_url"
    t.integer "estimated_duration_days"
    t.string "difficulty_level"
    t.text "best_practices"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_type"], name: "index_journey_templates_on_campaign_type"
    t.index ["category", "is_active"], name: "index_journey_templates_on_category_and_is_active"
    t.index ["category"], name: "index_journey_templates_on_category"
    t.index ["is_active"], name: "index_journey_templates_on_is_active"
    t.index ["usage_count"], name: "index_journey_templates_on_usage_count"
  end

  create_table "journeys", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "status", default: "draft", null: false
    t.string "brand_id"
    t.string "campaign_type"
    t.text "target_audience"
    t.text "goals"
    t.json "metadata", default: {}
    t.json "settings", default: {}
    t.datetime "published_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_journeys_on_brand_id"
    t.index ["campaign_type"], name: "index_journeys_on_campaign_type"
    t.index ["published_at"], name: "index_journeys_on_published_at"
    t.index ["status"], name: "index_journeys_on_status"
    t.index ["user_id", "status"], name: "index_journeys_on_user_id_and_status"
    t.index ["user_id"], name: "index_journeys_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_active_at", default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "expires_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "step_transitions", force: :cascade do |t|
    t.integer "from_step_id", null: false
    t.integer "to_step_id", null: false
    t.json "conditions", default: {}
    t.integer "priority", default: 0
    t.string "transition_type", default: "sequential"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_step_id", "to_step_id"], name: "index_step_transitions_on_from_step_id_and_to_step_id", unique: true
    t.index ["from_step_id"], name: "index_step_transitions_on_from_step_id"
    t.index ["priority"], name: "index_step_transitions_on_priority"
    t.index ["to_step_id"], name: "index_step_transitions_on_to_step_id"
    t.index ["transition_type"], name: "index_step_transitions_on_transition_type"
  end

  create_table "user_activities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "action"
    t.string "controller_name"
    t.string "action_name"
    t.string "resource_type"
    t.integer "resource_id"
    t.string "ip_address"
    t.text "user_agent"
    t.text "request_params"
    t.json "metadata"
    t.datetime "performed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_activities_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.string "full_name"
    t.text "bio"
    t.string "phone_number"
    t.string "company"
    t.string "job_title"
    t.string "timezone", default: "UTC"
    t.boolean "notification_email", default: true, null: false
    t.boolean "notification_marketing", default: true, null: false
    t.boolean "notification_product", default: true, null: false
    t.datetime "locked_at"
    t.string "lock_reason"
    t.datetime "suspended_at"
    t.text "suspension_reason"
    t.integer "suspended_by_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["suspended_at"], name: "index_users_on_suspended_at"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "users"
  add_foreign_key "admin_audit_logs", "users"
  add_foreign_key "journey_steps", "journeys"
  add_foreign_key "journeys", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "step_transitions", "journey_steps", column: "from_step_id"
  add_foreign_key "step_transitions", "journey_steps", column: "to_step_id"
  add_foreign_key "user_activities", "users"
  add_foreign_key "users", "users", column: "suspended_by_id"
end
