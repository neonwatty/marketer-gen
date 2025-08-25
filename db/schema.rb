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

ActiveRecord::Schema[8.0].define(version: 2025_08_25_175806) do
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

  create_table "approval_workflows", force: :cascade do |t|
    t.integer "generated_content_id", null: false
    t.string "workflow_type", null: false
    t.json "required_approvers", null: false
    t.integer "current_stage", default: 1, null: false
    t.string "status", default: "pending", null: false
    t.datetime "due_date"
    t.json "escalation_rules"
    t.integer "created_by_id", null: false
    t.datetime "completed_at"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_approval_workflows_on_created_by_id"
    t.index ["due_date"], name: "index_approval_workflows_on_due_date"
    t.index ["generated_content_id"], name: "index_approval_workflows_on_generated_content_id"
    t.index ["status"], name: "index_approval_workflows_on_status"
    t.index ["workflow_type"], name: "index_approval_workflows_on_workflow_type"
  end

  create_table "brand_identities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.text "brand_voice"
    t.text "tone_guidelines"
    t.text "messaging_framework"
    t.text "restrictions"
    t.string "status", default: "draft", null: false
    t.boolean "is_active", default: false, null: false
    t.text "processed_guidelines"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_brand_identities_on_is_active"
    t.index ["status"], name: "index_brand_identities_on_status"
    t.index ["user_id", "name"], name: "index_brand_identities_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_brand_identities_on_user_id"
  end

  create_table "brand_variants", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "brand_identity_id", null: false
    t.integer "persona_id"
    t.string "name", null: false
    t.text "description", null: false
    t.string "adaptation_context", null: false
    t.string "adaptation_type", null: false
    t.string "status", default: "draft", null: false
    t.integer "priority", default: 0, null: false
    t.integer "usage_count", default: 0, null: false
    t.decimal "effectiveness_score", precision: 4, scale: 2
    t.datetime "last_used_at"
    t.datetime "last_measured_at"
    t.datetime "activated_at"
    t.datetime "archived_at"
    t.datetime "testing_started_at"
    t.json "adaptation_rules"
    t.json "brand_voice_adjustments"
    t.json "messaging_variations"
    t.json "visual_guidelines"
    t.json "channel_specifications"
    t.json "audience_targeting"
    t.json "performance_metrics"
    t.json "a_b_test_results"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["adaptation_context", "adaptation_type"], name: "index_brand_variants_on_adaptation_context_and_adaptation_type"
    t.index ["brand_identity_id"], name: "index_brand_variants_on_brand_identity_id"
    t.index ["effectiveness_score"], name: "index_brand_variants_on_effectiveness_score"
    t.index ["last_used_at"], name: "index_brand_variants_on_last_used_at"
    t.index ["name", "user_id", "brand_identity_id"], name: "index_brand_variants_unique_name_per_user_brand", unique: true
    t.index ["persona_id"], name: "index_brand_variants_on_persona_id"
    t.index ["priority"], name: "index_brand_variants_on_priority"
    t.index ["user_id", "brand_identity_id"], name: "index_brand_variants_on_user_id_and_brand_identity_id"
    t.index ["user_id", "status"], name: "index_brand_variants_on_user_id_and_status"
    t.index ["user_id"], name: "index_brand_variants_on_user_id"
  end

  create_table "campaign_plans", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "campaign_type", null: false
    t.string "objective", null: false
    t.text "target_audience"
    t.text "brand_context"
    t.text "budget_constraints"
    t.text "timeline_constraints"
    t.text "generated_summary"
    t.text "generated_strategy"
    t.text "generated_timeline"
    t.text "generated_assets"
    t.string "status", default: "draft", null: false
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "content_strategy"
    t.text "creative_approach"
    t.text "strategic_rationale"
    t.text "content_mapping"
    t.string "approval_status", default: "draft"
    t.datetime "submitted_for_approval_at"
    t.datetime "approved_at"
    t.integer "approved_by_id"
    t.datetime "rejected_at"
    t.integer "rejected_by_id"
    t.integer "current_version_id"
    t.text "rejection_reason"
    t.text "stakeholder_notes"
    t.text "engagement_metrics"
    t.text "performance_data"
    t.text "roi_tracking"
    t.boolean "analytics_enabled", default: true, null: false
    t.datetime "analytics_last_updated_at"
    t.datetime "plan_execution_started_at"
    t.datetime "plan_execution_completed_at"
    t.text "competitive_intelligence"
    t.text "market_research_data"
    t.text "competitor_analysis"
    t.text "industry_benchmarks"
    t.datetime "competitive_analysis_last_updated_at"
    t.index ["analytics_enabled"], name: "index_campaign_plans_on_analytics_enabled"
    t.index ["analytics_last_updated_at"], name: "index_campaign_plans_on_analytics_last_updated_at"
    t.index ["approval_status"], name: "index_campaign_plans_on_approval_status"
    t.index ["approved_by_id"], name: "index_campaign_plans_on_approved_by_id"
    t.index ["campaign_type"], name: "index_campaign_plans_on_campaign_type"
    t.index ["competitive_analysis_last_updated_at"], name: "index_campaign_plans_on_competitive_analysis_last_updated_at"
    t.index ["current_version_id"], name: "index_campaign_plans_on_current_version_id"
    t.index ["objective"], name: "index_campaign_plans_on_objective"
    t.index ["plan_execution_started_at"], name: "index_campaign_plans_on_plan_execution_started_at"
    t.index ["rejected_by_id"], name: "index_campaign_plans_on_rejected_by_id"
    t.index ["status"], name: "index_campaign_plans_on_status"
    t.index ["submitted_for_approval_at"], name: "index_campaign_plans_on_submitted_for_approval_at"
    t.index ["user_id", "name"], name: "index_campaign_plans_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_campaign_plans_on_user_id"
  end

  create_table "content_ab_test_results", force: :cascade do |t|
    t.string "metric_name", limit: 100, null: false
    t.decimal "metric_value", precision: 12, scale: 4, null: false
    t.integer "sample_size", default: 1, null: false
    t.date "recorded_date", null: false
    t.string "data_source", limit: 100
    t.text "metadata"
    t.integer "content_ab_test_variant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_ab_test_variant_id", "metric_name"], name: "idx_on_content_ab_test_variant_id_metric_name_bb8201f271"
    t.index ["content_ab_test_variant_id", "recorded_date"], name: "idx_on_content_ab_test_variant_id_recorded_date_5e4f48b70f"
    t.index ["content_ab_test_variant_id"], name: "index_content_ab_test_results_on_content_ab_test_variant_id"
    t.index ["data_source"], name: "index_content_ab_test_results_on_data_source"
    t.index ["metric_name", "recorded_date"], name: "index_content_ab_test_results_on_metric_name_and_recorded_date"
    t.index ["metric_name"], name: "index_content_ab_test_results_on_metric_name"
    t.index ["recorded_date"], name: "index_content_ab_test_results_on_recorded_date"
  end

  create_table "content_ab_test_variants", force: :cascade do |t|
    t.string "variant_name", limit: 255, null: false
    t.string "status", limit: 50, default: "draft", null: false
    t.decimal "traffic_split", precision: 5, scale: 2, null: false
    t.integer "sample_size", default: 0
    t.text "metadata"
    t.integer "content_ab_test_id", null: false
    t.integer "generated_content_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_ab_test_id", "status"], name: "idx_on_content_ab_test_id_status_c257b84dff"
    t.index ["content_ab_test_id", "variant_name"], name: "index_ab_test_variants_on_test_and_name", unique: true
    t.index ["content_ab_test_id"], name: "index_content_ab_test_variants_on_content_ab_test_id"
    t.index ["generated_content_id", "content_ab_test_id"], name: "index_ab_test_variants_on_content_and_test", unique: true
    t.index ["generated_content_id"], name: "index_content_ab_test_variants_on_generated_content_id"
    t.index ["status"], name: "index_content_ab_test_variants_on_status"
  end

  create_table "content_ab_tests", force: :cascade do |t|
    t.string "test_name", limit: 255, null: false
    t.string "status", limit: 50, default: "draft", null: false
    t.string "primary_goal", limit: 50, null: false
    t.string "confidence_level", limit: 10, default: "95", null: false
    t.decimal "traffic_allocation", precision: 5, scale: 2, default: "100.0", null: false
    t.integer "minimum_sample_size", default: 100, null: false
    t.integer "test_duration_days", default: 14, null: false
    t.datetime "start_date"
    t.datetime "end_date"
    t.boolean "statistical_significance", default: false
    t.string "winner_variant_id", limit: 100
    t.text "description"
    t.text "secondary_goals"
    t.text "audience_segments"
    t.text "metadata"
    t.integer "campaign_plan_id", null: false
    t.integer "created_by_id", null: false
    t.integer "control_content_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_plan_id", "status"], name: "index_content_ab_tests_on_campaign_plan_id_and_status"
    t.index ["campaign_plan_id"], name: "index_content_ab_tests_on_campaign_plan_id"
    t.index ["control_content_id"], name: "index_content_ab_tests_on_control_content_id"
    t.index ["created_by_id"], name: "index_content_ab_tests_on_created_by_id"
    t.index ["primary_goal"], name: "index_content_ab_tests_on_primary_goal"
    t.index ["start_date", "end_date"], name: "index_content_ab_tests_on_start_date_and_end_date"
    t.index ["status"], name: "index_content_ab_tests_on_status"
    t.index ["test_name"], name: "index_content_ab_tests_on_test_name", unique: true
  end

  create_table "content_audit_logs", force: :cascade do |t|
    t.integer "generated_content_id", null: false
    t.integer "user_id", null: false
    t.string "action", null: false
    t.json "old_values"
    t.json "new_values"
    t.string "ip_address"
    t.text "user_agent"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_content_audit_logs_on_action"
    t.index ["created_at"], name: "index_content_audit_logs_on_created_at"
    t.index ["generated_content_id", "created_at"], name: "idx_on_generated_content_id_created_at_2cdc80bf3b"
    t.index ["generated_content_id"], name: "index_content_audit_logs_on_generated_content_id"
    t.index ["user_id"], name: "index_content_audit_logs_on_user_id"
  end

  create_table "content_feedbacks", force: :cascade do |t|
    t.integer "generated_content_id", null: false
    t.integer "reviewer_user_id", null: false
    t.text "feedback_text", null: false
    t.string "feedback_type", null: false
    t.datetime "resolved_at"
    t.integer "resolved_by_user_id"
    t.integer "approval_workflow_id"
    t.integer "priority", default: 1
    t.string "status", default: "pending", null: false
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approval_workflow_id"], name: "index_content_feedbacks_on_approval_workflow_id"
    t.index ["created_at"], name: "index_content_feedbacks_on_created_at"
    t.index ["feedback_type"], name: "index_content_feedbacks_on_feedback_type"
    t.index ["generated_content_id", "status"], name: "index_content_feedbacks_on_generated_content_id_and_status"
    t.index ["generated_content_id"], name: "index_content_feedbacks_on_generated_content_id"
    t.index ["priority"], name: "index_content_feedbacks_on_priority"
    t.index ["resolved_by_user_id"], name: "index_content_feedbacks_on_resolved_by_user_id"
    t.index ["reviewer_user_id"], name: "index_content_feedbacks_on_reviewer_user_id"
    t.index ["status"], name: "index_content_feedbacks_on_status"
  end

  create_table "content_versions", force: :cascade do |t|
    t.integer "generated_content_id", null: false
    t.integer "version_number", null: false
    t.string "action_type", null: false
    t.integer "changed_by_id", null: false
    t.text "changes_summary"
    t.datetime "timestamp", null: false
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_type"], name: "index_content_versions_on_action_type"
    t.index ["changed_by_id"], name: "index_content_versions_on_changed_by_id"
    t.index ["generated_content_id", "version_number"], name: "idx_on_generated_content_id_version_number_7f2182d7fb", unique: true
    t.index ["generated_content_id"], name: "index_content_versions_on_generated_content_id"
    t.index ["timestamp"], name: "index_content_versions_on_timestamp"
  end

  create_table "feedback_comments", force: :cascade do |t|
    t.integer "plan_version_id", null: false
    t.integer "user_id", null: false
    t.text "content", null: false
    t.string "comment_type", default: "general"
    t.string "priority", default: "medium"
    t.string "status", default: "open"
    t.json "metadata"
    t.integer "parent_comment_id"
    t.text "section_reference"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["comment_type"], name: "index_feedback_comments_on_comment_type"
    t.index ["parent_comment_id"], name: "index_feedback_comments_on_parent_comment_id"
    t.index ["plan_version_id", "status"], name: "index_feedback_comments_on_plan_version_id_and_status"
    t.index ["plan_version_id"], name: "index_feedback_comments_on_plan_version_id"
    t.index ["priority"], name: "index_feedback_comments_on_priority"
    t.index ["user_id", "created_at"], name: "index_feedback_comments_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_feedback_comments_on_user_id"
  end

  create_table "generated_contents", force: :cascade do |t|
    t.string "content_type", null: false
    t.string "title", null: false
    t.text "body_content", null: false
    t.string "format_variant", default: "standard"
    t.string "status", default: "draft", null: false
    t.integer "version_number", default: 1, null: false
    t.integer "original_content_id"
    t.integer "campaign_plan_id", null: false
    t.integer "created_by_id", null: false
    t.integer "approved_by_id"
    t.text "metadata"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_generated_contents_on_approved_by_id"
    t.index ["campaign_plan_id", "content_type"], name: "index_generated_contents_on_campaign_plan_id_and_content_type"
    t.index ["campaign_plan_id", "status"], name: "index_generated_contents_on_campaign_plan_id_and_status"
    t.index ["campaign_plan_id"], name: "index_generated_contents_on_campaign_plan_id"
    t.index ["content_type"], name: "index_generated_contents_on_content_type"
    t.index ["created_by_id", "created_at"], name: "index_generated_contents_on_created_by_id_and_created_at"
    t.index ["created_by_id"], name: "index_generated_contents_on_created_by_id"
    t.index ["deleted_at"], name: "index_generated_contents_on_deleted_at"
    t.index ["format_variant"], name: "index_generated_contents_on_format_variant"
    t.index ["original_content_id", "version_number"], name: "idx_on_original_content_id_version_number_b94c5ed42a"
    t.index ["original_content_id"], name: "index_generated_contents_on_original_content_id"
    t.index ["status"], name: "index_generated_contents_on_status"
    t.index ["version_number"], name: "index_generated_contents_on_version_number"
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
    t.string "category"
    t.string "industry"
    t.string "complexity_level"
    t.text "prerequisites"
    t.index ["campaign_type", "is_default"], name: "index_journey_templates_on_campaign_type_and_is_default"
    t.index ["category", "industry"], name: "index_journey_templates_on_category_and_industry"
    t.index ["category"], name: "index_journey_templates_on_category"
    t.index ["complexity_level"], name: "index_journey_templates_on_complexity_level"
    t.index ["industry"], name: "index_journey_templates_on_industry"
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

  create_table "persona_contents", force: :cascade do |t|
    t.integer "persona_id", null: false
    t.integer "generated_content_id", null: false
    t.string "adaptation_type", null: false
    t.text "adapted_content"
    t.text "adaptation_metadata"
    t.decimal "effectiveness_score", precision: 5, scale: 2
    t.boolean "is_primary_adaptation", default: false
    t.text "adaptation_rationale"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["adaptation_type"], name: "index_persona_contents_on_adaptation_type"
    t.index ["effectiveness_score"], name: "index_persona_contents_on_effectiveness_score"
    t.index ["generated_content_id"], name: "index_persona_contents_on_generated_content_id"
    t.index ["persona_id", "generated_content_id"], name: "index_persona_contents_unique", unique: true
    t.index ["persona_id"], name: "index_persona_contents_on_persona_id"
  end

  create_table "personas", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.text "characteristics"
    t.text "demographics"
    t.text "goals"
    t.text "pain_points"
    t.text "preferred_channels"
    t.text "content_preferences"
    t.text "behavioral_traits"
    t.boolean "is_active", default: true, null: false
    t.integer "priority", default: 0
    t.integer "user_id", null: false
    t.text "tags"
    t.text "matching_rules"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_personas_on_is_active"
    t.index ["priority"], name: "index_personas_on_priority"
    t.index ["user_id", "name"], name: "index_personas_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_personas_on_user_id"
  end

  create_table "plan_audit_logs", force: :cascade do |t|
    t.integer "campaign_plan_id", null: false
    t.integer "user_id", null: false
    t.string "action", null: false
    t.json "details"
    t.json "metadata"
    t.integer "plan_version_id"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_plan_audit_logs_on_action"
    t.index ["campaign_plan_id", "created_at"], name: "index_plan_audit_logs_on_campaign_plan_id_and_created_at"
    t.index ["campaign_plan_id"], name: "index_plan_audit_logs_on_campaign_plan_id"
    t.index ["plan_version_id"], name: "index_plan_audit_logs_on_plan_version_id"
    t.index ["user_id", "created_at"], name: "index_plan_audit_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_plan_audit_logs_on_user_id"
  end

  create_table "plan_share_tokens", force: :cascade do |t|
    t.integer "campaign_plan_id", null: false
    t.string "token", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.datetime "accessed_at"
    t.integer "access_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_plan_id"], name: "index_plan_share_tokens_on_campaign_plan_id"
    t.index ["email"], name: "index_plan_share_tokens_on_email"
    t.index ["expires_at"], name: "index_plan_share_tokens_on_expires_at"
    t.index ["token"], name: "index_plan_share_tokens_on_token", unique: true
  end

  create_table "plan_versions", force: :cascade do |t|
    t.integer "campaign_plan_id", null: false
    t.integer "version_number", null: false
    t.json "content"
    t.json "metadata"
    t.integer "created_by_id", null: false
    t.string "status", default: "draft"
    t.text "change_summary"
    t.boolean "is_current", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_plan_id", "is_current"], name: "index_plan_versions_on_campaign_plan_id_and_is_current"
    t.index ["campaign_plan_id", "version_number"], name: "index_plan_versions_on_campaign_plan_id_and_version_number", unique: true
    t.index ["campaign_plan_id"], name: "index_plan_versions_on_campaign_plan_id"
    t.index ["created_by_id"], name: "index_plan_versions_on_created_by_id"
    t.index ["status"], name: "index_plan_versions_on_status"
  end

  create_table "platform_connections", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "platform", null: false
    t.text "credentials"
    t.string "status", default: "inactive"
    t.datetime "last_sync_at"
    t.text "metadata"
    t.string "account_id"
    t.string "account_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_sync_at"], name: "index_platform_connections_on_last_sync_at"
    t.index ["status"], name: "index_platform_connections_on_status"
    t.index ["user_id", "platform"], name: "index_platform_connections_on_user_id_and_platform", unique: true
    t.index ["user_id"], name: "index_platform_connections_on_user_id"
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
  add_foreign_key "approval_workflows", "generated_contents"
  add_foreign_key "approval_workflows", "users", column: "created_by_id"
  add_foreign_key "brand_identities", "users"
  add_foreign_key "brand_variants", "brand_identities"
  add_foreign_key "brand_variants", "personas"
  add_foreign_key "brand_variants", "users"
  add_foreign_key "campaign_plans", "users"
  add_foreign_key "campaign_plans", "users", column: "approved_by_id"
  add_foreign_key "campaign_plans", "users", column: "rejected_by_id"
  add_foreign_key "content_ab_test_results", "content_ab_test_variants"
  add_foreign_key "content_ab_test_variants", "content_ab_tests"
  add_foreign_key "content_ab_test_variants", "generated_contents"
  add_foreign_key "content_ab_tests", "campaign_plans"
  add_foreign_key "content_ab_tests", "generated_contents", column: "control_content_id"
  add_foreign_key "content_ab_tests", "users", column: "created_by_id"
  add_foreign_key "content_audit_logs", "generated_contents"
  add_foreign_key "content_audit_logs", "users"
  add_foreign_key "content_feedbacks", "approval_workflows"
  add_foreign_key "content_feedbacks", "generated_contents"
  add_foreign_key "content_feedbacks", "users", column: "resolved_by_user_id"
  add_foreign_key "content_feedbacks", "users", column: "reviewer_user_id"
  add_foreign_key "content_versions", "generated_contents"
  add_foreign_key "content_versions", "users", column: "changed_by_id"
  add_foreign_key "feedback_comments", "feedback_comments", column: "parent_comment_id"
  add_foreign_key "feedback_comments", "plan_versions"
  add_foreign_key "feedback_comments", "users"
  add_foreign_key "generated_contents", "campaign_plans"
  add_foreign_key "generated_contents", "generated_contents", column: "original_content_id"
  add_foreign_key "generated_contents", "users", column: "approved_by_id"
  add_foreign_key "generated_contents", "users", column: "created_by_id"
  add_foreign_key "journey_steps", "journeys"
  add_foreign_key "journeys", "users"
  add_foreign_key "persona_contents", "generated_contents"
  add_foreign_key "persona_contents", "personas"
  add_foreign_key "personas", "users"
  add_foreign_key "plan_audit_logs", "campaign_plans"
  add_foreign_key "plan_audit_logs", "plan_versions"
  add_foreign_key "plan_audit_logs", "users"
  add_foreign_key "plan_share_tokens", "campaign_plans"
  add_foreign_key "plan_versions", "campaign_plans"
  add_foreign_key "plan_versions", "users", column: "created_by_id"
  add_foreign_key "platform_connections", "users"
  add_foreign_key "sessions", "users"
end
