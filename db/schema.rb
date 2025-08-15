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

ActiveRecord::Schema[8.0].define(version: 2025_08_15_190447) do
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

  create_table "journey_steps", force: :cascade do |t|
    t.integer "journey_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "step_type", null: false
    t.text "content"
    t.string "channel"
    t.integer "sequence_order", null: false
    t.text "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "draft", null: false
    t.index ["channel"], name: "index_journey_steps_on_channel"
    t.index ["journey_id", "sequence_order"], name: "index_journey_steps_on_journey_id_and_sequence_order", unique: true
    t.index ["journey_id"], name: "index_journey_steps_on_journey_id"
    t.index ["status"], name: "index_journey_steps_on_status"
    t.index ["step_type"], name: "index_journey_steps_on_step_type"
  end

  create_table "journey_templates", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "campaign_type", null: false
    t.text "template_data", null: false
    t.boolean "is_default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_type", "is_default"], name: "index_journey_templates_on_campaign_type_and_is_default"
    t.index ["name"], name: "index_journey_templates_on_name", unique: true
  end

  create_table "journeys", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "campaign_type", null: false
    t.integer "user_id", null: false
    t.text "stages"
    t.string "status", default: "draft", null: false
    t.string "template_type"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_type"], name: "index_journeys_on_campaign_type"
    t.index ["status"], name: "index_journeys_on_status"
    t.index ["template_type"], name: "index_journeys_on_template_type"
    t.index ["user_id", "name"], name: "index_journeys_on_user_id_and_name"
    t.index ["user_id"], name: "index_journeys_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "marketer", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.string "company"
    t.text "bio"
    t.text "notification_preferences"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "journey_steps", "journeys"
  add_foreign_key "journeys", "users"
  add_foreign_key "sessions", "users"
end
