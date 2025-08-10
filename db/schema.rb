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

ActiveRecord::Schema[8.0].define(version: 2025_08_10_135533) do
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

  create_table "brand_assets", force: :cascade do |t|
    t.string "file_type", null: false
    t.bigint "file_size"
    t.string "original_filename"
    t.json "metadata", default: {}, null: false
    t.text "extracted_text"
    t.string "scan_status", default: "pending"
    t.string "assetable_type", null: false
    t.integer "assetable_id", null: false
    t.string "content_type"
    t.string "checksum"
    t.string "purpose"
    t.boolean "active", default: true, null: false
    t.datetime "scanned_at"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "text_extracted_at"
    t.text "text_extraction_error"
    t.integer "version_number", default: 1
    t.integer "parent_asset_id"
    t.boolean "is_current_version", default: true
    t.text "version_notes"
    t.index ["active"], name: "index_brand_assets_on_active"
    t.index ["assetable_type", "assetable_id", "file_type"], name: "idx_on_assetable_type_assetable_id_file_type_768c8523e2"
    t.index ["assetable_type", "assetable_id"], name: "index_brand_assets_on_assetable"
    t.index ["file_type"], name: "index_brand_assets_on_file_type"
    t.index ["parent_asset_id", "is_current_version"], name: "index_brand_assets_on_parent_asset_id_and_is_current_version"
    t.index ["parent_asset_id", "version_number"], name: "index_brand_assets_on_parent_asset_id_and_version_number", unique: true
    t.index ["parent_asset_id"], name: "index_brand_assets_on_parent_asset_id"
    t.index ["scan_status"], name: "index_brand_assets_on_scan_status"
  end

  create_table "brand_identities", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.json "guidelines", default: {}, null: false
    t.json "messaging_frameworks", default: {}, null: false
    t.json "color_palette", default: {}, null: false
    t.json "typography", default: {}, null: false
    t.integer "version", default: 1, null: false
    t.boolean "active", default: true, null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "campaigns_count", default: 0, null: false
    t.integer "brand_assets_count", default: 0, null: false
    t.index ["active"], name: "index_brand_identities_on_active"
    t.index ["name", "version"], name: "index_brand_identities_on_name_and_version", unique: true
    t.index ["name"], name: "index_brand_identities_on_name", unique: true
    t.index ["published_at"], name: "index_brand_identities_on_published_at"
    t.index ["version"], name: "index_brand_identities_on_version"
  end

  create_table "campaigns", force: :cascade do |t|
    t.string "name"
    t.string "status"
    t.text "purpose"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "brand_identity_id"
    t.text "target_audience"
    t.integer "budget_cents"
    t.date "start_date"
    t.date "end_date"
    t.integer "customer_journeys_count", default: 0, null: false
    t.integer "content_assets_count", default: 0, null: false
    t.integer "brand_assets_count", default: 0, null: false
    t.index ["brand_identity_id"], name: "index_campaigns_on_brand_identity_id"
    t.index ["created_at"], name: "index_campaigns_on_created_at"
    t.index ["start_date"], name: "index_campaigns_on_start_date"
    t.index ["status", "start_date"], name: "index_campaigns_on_status_and_start_date"
    t.index ["status"], name: "index_campaigns_on_status"
  end

  create_table "content_assets", force: :cascade do |t|
    t.string "assetable_type", null: false
    t.integer "assetable_id", null: false
    t.string "content_type", null: false
    t.text "content"
    t.string "stage"
    t.string "channel", null: false
    t.json "metadata", default: {}, null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "version", default: 1, null: false
    t.integer "file_size"
    t.string "mime_type"
    t.datetime "published_at"
    t.datetime "approved_at"
    t.integer "approved_by_id"
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_content_assets_on_approved_by_id"
    t.index ["assetable_type", "assetable_id", "channel"], name: "index_content_assets_on_assetable_and_channel"
    t.index ["assetable_type", "assetable_id", "status"], name: "index_content_assets_on_assetable_and_status"
    t.index ["assetable_type", "assetable_id"], name: "index_content_assets_on_assetable"
    t.index ["assetable_type", "assetable_id"], name: "index_content_assets_on_assetable_type_and_assetable_id"
    t.index ["channel", "status", "published_at"], name: "index_content_assets_on_channel_status_published"
    t.index ["channel"], name: "index_content_assets_on_channel"
    t.index ["content_type"], name: "index_content_assets_on_content_type"
    t.index ["position"], name: "index_content_assets_on_position"
    t.index ["published_at"], name: "index_content_assets_on_published_at"
    t.index ["stage"], name: "index_content_assets_on_stage"
    t.index ["status"], name: "index_content_assets_on_status"
  end

  create_table "customer_journeys", force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.string "name", null: false
    t.text "description"
    t.json "stages", default: [], null: false
    t.json "content_types", default: [], null: false
    t.json "touchpoints", default: {}, null: false
    t.json "metrics", default: {}, null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "created_at"], name: "index_customer_journeys_on_campaign_and_date"
    t.index ["campaign_id"], name: "index_customer_journeys_on_campaign_id"
    t.index ["name"], name: "index_customer_journeys_on_name"
    t.index ["position"], name: "index_customer_journeys_on_position"
  end

  create_table "templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "template_type", null: false
    t.string "category"
    t.json "template_data", default: {}, null: false
    t.boolean "is_active", default: true, null: false
    t.integer "usage_count", default: 0, null: false
    t.text "description"
    t.integer "version", default: 1, null: false
    t.integer "parent_template_id"
    t.string "author"
    t.json "variables", default: [], null: false
    t.json "metadata", default: {}, null: false
    t.datetime "published_at"
    t.string "tags"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "child_templates_count", default: 0, null: false
    t.index ["category"], name: "index_templates_on_category"
    t.index ["is_active", "template_type"], name: "index_templates_on_is_active_and_template_type"
    t.index ["is_active"], name: "index_templates_on_is_active"
    t.index ["name"], name: "index_templates_on_name"
    t.index ["parent_template_id", "version"], name: "index_templates_on_parent_and_version"
    t.index ["parent_template_id"], name: "index_templates_on_parent_template_id"
    t.index ["published_at"], name: "index_templates_on_published_at"
    t.index ["template_type", "category"], name: "index_templates_on_template_type_and_category"
    t.index ["template_type", "is_active", "usage_count"], name: "index_templates_on_type_active_usage"
    t.index ["template_type"], name: "index_templates_on_template_type"
    t.index ["usage_count"], name: "index_templates_on_usage_count"
    t.index ["version"], name: "index_templates_on_version"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "brand_assets", "brand_assets", column: "parent_asset_id"
  add_foreign_key "campaigns", "brand_identities"
  add_foreign_key "customer_journeys", "campaigns"
  add_foreign_key "templates", "templates", column: "parent_template_id"
end
