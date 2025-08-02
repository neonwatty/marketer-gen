require "test_helper"
require "digest"

class ContentManagementSystemTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @campaign = campaigns(:product_launch)
    @content_piece = create_test_content_piece
  end

  # Content Storage with Tagging and Categorization Tests
  test "should store content with comprehensive metadata" do
    content_storage = ContentStorageSystem.new

    content_data = {
      title: "Product Launch Email Template",
      body: "Exciting news about our new product...",
      content_type: "email_template",
      format: "html",
      campaign_id: @campaign.id,
      user_id: @user.id
    }

    stored_content = content_storage.store(content_data)

    assert_not_nil stored_content
    assert_equal content_data[:title], stored_content[:title]
    assert_equal content_data[:content_type], stored_content[:content_type]
    assert stored_content[:created_at].present?
    assert stored_content[:file_hash].present?
    assert stored_content[:storage_path].present?
  end

  test "should tag content with multiple categories and keywords" do
    content_tagging = ContentTaggingSystem.new

    tags_data = {
      content_id: @content_piece[:id],
      categories: [ "email_marketing", "product_launch", "promotional" ],
      keywords: [ "innovation", "technology", "launch", "benefits" ],
      custom_tags: [ "urgent", "high_priority", "stakeholder_review" ],
      user_id: @user.id
    }

    tagging_result = content_tagging.apply_tags(tags_data)

    assert tagging_result[:success]

    tagged_content = content_tagging.get_content_tags(@content_piece[:id])
    assert_includes tagged_content[:categories], "email_marketing"
    assert_includes tagged_content[:keywords], "innovation"
    assert_includes tagged_content[:custom_tags], "urgent"
    assert_equal 3, tagged_content[:categories].length
    assert_equal 4, tagged_content[:keywords].length
  end

  test "should categorize content automatically using AI" do
    ai_categorizer = ContentAICategorizer.new

    content_text = "This email template promotes our new SaaS platform features, targeting enterprise customers with ROI messaging."

    auto_categories = ai_categorizer.categorize_content(content_text)

    assert_not_nil auto_categories
    assert_includes auto_categories[:primary_categories], "email_template"
    assert_includes auto_categories[:secondary_categories], "saas_marketing"
    assert_includes auto_categories[:audience_tags], "enterprise"
    assert_includes auto_categories[:intent_tags], "promotional"

    confidence_scores = auto_categories[:confidence_scores]
    assert confidence_scores.values.all? { |score| score.between?(0, 1) }
  end

  test "should enable hierarchical content categorization" do
    category_hierarchy = ContentCategoryHierarchy.new

    hierarchy_structure = category_hierarchy.create_hierarchy([
      "Marketing Materials",
      "Email Marketing",
      "Product Launch Emails",
      "Launch Announcement Templates"
    ])

    assert_not_nil hierarchy_structure
    assert_equal 4, hierarchy_structure[:levels].length
    assert_equal "Marketing Materials", hierarchy_structure[:root_category]

    # Assign content to specific level
    assignment = category_hierarchy.assign_to_category(
      @content_piece[:id],
      "Launch Announcement Templates"
    )

    assert assignment[:success]
    assert_equal 4, assignment[:hierarchy_level]
    assert_includes assignment[:full_path], "Marketing Materials"
  end

  # Git-like Version Control Tests
  test "should initialize content repository with version control" do
    version_control = ContentVersionControl.new(@user)

    repository = version_control.init_repository(@campaign.id)

    assert_not_nil repository
    assert_equal @campaign.id, repository[:campaign_id]
    assert repository[:git_repository_path].present?
    assert_equal "main", repository[:default_branch]
    assert repository[:initial_commit_hash].present?
  end

  test "should commit content changes with detailed metadata" do
    version_control = ContentVersionControl.new(@user)
    repository = version_control.init_repository(@campaign.id)

    content_changes = {
      added_files: [ "email_template_v1.html", "social_post_draft.txt" ],
      modified_files: [ "campaign_overview.md" ],
      deleted_files: [],
      commit_message: "Add email template and update campaign overview",
      author: @user.email_address
    }

    commit_result = version_control.commit_changes(repository[:id], content_changes)

    assert commit_result[:success]
    assert commit_result[:commit_hash].present?
    assert_equal 3, commit_result[:files_changed]
    assert_includes commit_result[:commit_message], "Add email template"
  end

  test "should create and manage content branches" do
    version_control = ContentVersionControl.new(@user)
    repository = version_control.init_repository(@campaign.id)

    # Create feature branch
    branch_result = version_control.create_branch(
      repository[:id],
      "feature/new-messaging-approach",
      base_branch: "main"
    )

    assert branch_result[:success]
    assert_equal "feature/new-messaging-approach", branch_result[:branch_name]

    # Switch to branch
    checkout_result = version_control.checkout_branch(
      repository[:id],
      "feature/new-messaging-approach"
    )

    assert checkout_result[:success]

    # List all branches
    branches = version_control.list_branches(repository[:id])
    assert_includes branches[:branch_names], "main"
    assert_includes branches[:branch_names], "feature/new-messaging-approach"
    assert_equal "feature/new-messaging-approach", branches[:current_branch]
  end

  test "should merge content branches with conflict resolution" do
    version_control = ContentVersionControl.new(@user)
    repository = version_control.init_repository(@campaign.id)

    # Create and modify in feature branch
    version_control.create_branch(repository[:id], "feature/update-copy")
    version_control.checkout_branch(repository[:id], "feature/update-copy")

    feature_changes = {
      modified_files: [ "main_template.html" ],
      commit_message: "Update copy with new messaging",
      content_diffs: {
        "main_template.html" => {
          lines_added: 5,
          lines_removed: 3,
          changes: [
            { line: 10, old: "Old headline text", new: "New compelling headline" }
          ]
        }
      }
    }

    version_control.commit_changes(repository[:id], feature_changes)

    # Merge to main
    merge_result = version_control.merge_branch(
      repository[:id],
      source_branch: "feature/update-copy",
      target_branch: "main",
      merge_strategy: "squash"
    )

    assert merge_result[:success]
    assert merge_result[:merge_commit_hash].present?
    assert_equal 0, merge_result[:conflicts].length
  end

  test "should handle merge conflicts in content versions" do
    version_control = ContentVersionControl.new(@user)
    repository = version_control.init_repository(@campaign.id)

    # Create conflicting changes in two branches
    version_control.create_branch(repository[:id], "branch-a")
    version_control.create_branch(repository[:id], "branch-b")

    # Conflicting changes
    conflict_scenario = {
      branch_a_changes: { line: 5, content: "Version A content" },
      branch_b_changes: { line: 5, content: "Version B content" },
      file: "shared_template.html"
    }

    merge_with_conflicts = version_control.merge_with_conflicts(
      repository[:id],
      "branch-a",
      "branch-b"
    )

    assert_not merge_with_conflicts[:success]
    assert merge_with_conflicts[:has_conflicts]
    assert_equal 1, merge_with_conflicts[:conflicts].length

    conflict = merge_with_conflicts[:conflicts].first
    assert_equal "shared_template.html", conflict[:file]
    assert_equal 5, conflict[:line]
    assert conflict[:version_a].present?
    assert conflict[:version_b].present?
  end

  test "should resolve merge conflicts manually" do
    version_control = ContentVersionControl.new(@user)
    repository = version_control.init_repository(@campaign.id)

    conflict_id = "conflict_123"
    resolution = {
      conflict_id: conflict_id,
      file: "template.html",
      line: 5,
      resolved_content: "Merged content combining both versions",
      resolution_strategy: "manual",
      resolver_user_id: @user.id
    }

    resolution_result = version_control.resolve_conflict(repository[:id], resolution)

    assert resolution_result[:success]
    assert_equal "manual", resolution_result[:resolution_strategy]
    assert_equal @user.id, resolution_result[:resolved_by]
  end

  # Rich Content Editor with Collaboration Tests
  test "should initialize collaborative rich text editor" do
    rich_editor = CollaborativeRichEditor.new(@content_piece[:id])

    editor_instance = rich_editor.initialize_editor(@user)

    assert_not_nil editor_instance
    assert editor_instance[:editor_id].present?
    assert_equal @user.id, editor_instance[:user_id]
    assert editor_instance[:websocket_connection_url].present?
    assert_equal [], editor_instance[:active_collaborators]
  end

  test "should track real-time collaborative editing" do
    rich_editor = CollaborativeRichEditor.new(@content_piece[:id])
    editor_instance = rich_editor.initialize_editor(@user)

    # User joins editing session
    user_2 = users(:two)
    collaboration_session = rich_editor.join_collaboration_session(user_2, editor_instance[:editor_id])

    assert collaboration_session[:success]

    # Check active collaborators
    active_session = rich_editor.get_active_session(editor_instance[:editor_id])
    assert_equal 2, active_session[:active_collaborators].length
    assert_includes active_session[:active_collaborators].map { |c| c[:user_id] }, @user.id
    assert_includes active_session[:active_collaborators].map { |c| c[:user_id] }, user_2.id
  end

  test "should handle simultaneous content editing with operational transforms" do
    rich_editor = CollaborativeRichEditor.new(@content_piece[:id])
    editor_instance = rich_editor.initialize_editor(@user)

    # Two users make simultaneous edits
    edit_operation_1 = {
      user_id: @user.id,
      operation_type: "insert",
      position: 10,
      content: "new text",
      timestamp: Time.current
    }

    edit_operation_2 = {
      user_id: users(:two).id,
      operation_type: "delete",
      position: 15,
      length: 5,
      timestamp: Time.current + 0.1.seconds
    }

    transform_result = rich_editor.apply_operational_transform(
      editor_instance[:editor_id],
      [ edit_operation_1, edit_operation_2 ]
    )

    assert transform_result[:success]
    assert_equal 2, transform_result[:operations_applied]
    assert transform_result[:final_content].present?
    assert transform_result[:conflict_resolution_applied]
  end

  test "should save editor states and cursor positions" do
    rich_editor = CollaborativeRichEditor.new(@content_piece[:id])
    editor_instance = rich_editor.initialize_editor(@user)

    editor_state = {
      content: "Updated content with rich formatting",
      cursor_position: 25,
      selection_start: 10,
      selection_end: 15,
      formatting_state: {
        bold: false,
        italic: true,
        font_size: 14
      }
    }

    save_result = rich_editor.save_editor_state(editor_instance[:editor_id], editor_state)

    assert save_result[:success]

    retrieved_state = rich_editor.get_editor_state(editor_instance[:editor_id])
    assert_equal editor_state[:content], retrieved_state[:content]
    assert_equal 25, retrieved_state[:cursor_position]
    assert retrieved_state[:formatting_state][:italic]
  end

  # Approval Workflows and Role-based Permissions Tests
  test "should define content approval workflow with role-based permissions" do
    approval_system = ContentApprovalSystem.new

    workflow_definition = {
      content_id: @content_piece[:id],
      approval_steps: [
        { role: "content_creator", permissions: [ "create", "edit" ], required: false },
        { role: "content_reviewer", permissions: [ "review", "comment" ], required: true },
        { role: "content_manager", permissions: [ "approve", "reject" ], required: true },
        { role: "brand_guardian", permissions: [ "final_approval" ], required: true }
      ],
      parallel_approval: false,
      auto_progression: true
    }

    workflow = approval_system.create_workflow(workflow_definition)

    assert_not_nil workflow
    assert_equal 4, workflow[:approval_steps].length
    assert_equal "content_creator", workflow[:current_step][:role]
    assert_equal "pending", workflow[:status]
  end

  test "should enforce role-based permissions for content actions" do
    permission_system = ContentPermissionSystem.new(@content_piece[:id])

    # Test content creator permissions
    creator_permissions = permission_system.check_permissions(@user, "content_creator")
    assert creator_permissions[:can_create]
    assert creator_permissions[:can_edit]
    assert_not creator_permissions[:can_approve]

    # Test content manager permissions
    manager_permissions = permission_system.check_permissions(@user, "content_manager")
    assert manager_permissions[:can_create]
    assert manager_permissions[:can_edit]
    assert manager_permissions[:can_approve]
    assert manager_permissions[:can_reject]

    # Test read-only permissions
    readonly_permissions = permission_system.check_permissions(@user, "viewer")
    assert readonly_permissions[:can_view]
    assert_not readonly_permissions[:can_edit]
    assert_not readonly_permissions[:can_approve]
  end

  test "should process content through approval workflow steps" do
    approval_system = ContentApprovalSystem.new
    workflow = approval_system.create_workflow({
      content_id: @content_piece[:id],
      approval_steps: [
        { role: "content_reviewer", user_id: users(:reviewer).id },
        { role: "content_manager", user_id: users(:manager).id }
      ]
    })

    # First approval step
    review_result = approval_system.process_approval_step(
      workflow[:id],
      users(:reviewer),
      action: "approve",
      comments: "Content looks good, minor formatting needed"
    )

    assert review_result[:success]
    assert_equal "approved", review_result[:step_status]

    updated_workflow = approval_system.get_workflow(workflow[:id])
    assert_equal "content_manager", updated_workflow[:current_step][:role]

    # Final approval step
    final_result = approval_system.process_approval_step(
      workflow[:id],
      users(:manager),
      action: "approve",
      comments: "Final approval granted"
    )

    assert final_result[:success]
    final_workflow = approval_system.get_workflow(workflow[:id])
    assert_equal "completed", final_workflow[:status]
  end

  test "should handle content rejection in approval workflow" do
    approval_system = ContentApprovalSystem.new
    workflow = approval_system.create_workflow({
      content_id: @content_piece[:id],
      approval_steps: [ { role: "content_reviewer", user_id: users(:reviewer).id } ]
    })

    rejection_result = approval_system.process_approval_step(
      workflow[:id],
      users(:reviewer),
      action: "reject",
      comments: "Brand messaging needs alignment with guidelines"
    )

    assert rejection_result[:success]
    assert_equal "rejected", rejection_result[:step_status]

    rejected_workflow = approval_system.get_workflow(workflow[:id])
    assert_equal "rejected", rejected_workflow[:status]
    assert_includes rejected_workflow[:rejection_comments], "Brand messaging"
  end

  # Content Lifecycle Management Tests
  test "should manage content lifecycle states" do
    lifecycle_manager = ContentLifecycleManager.new(@content_piece[:id])

    # Initial state
    assert_equal "draft", lifecycle_manager.get_current_state

    # Transition to review
    review_transition = lifecycle_manager.transition_to("review", @user)
    assert review_transition[:success]
    assert_equal "review", lifecycle_manager.get_current_state

    # Transition to published
    publish_transition = lifecycle_manager.transition_to("published", @user)
    assert publish_transition[:success]
    assert_equal "published", lifecycle_manager.get_current_state

    # Check lifecycle history
    history = lifecycle_manager.get_lifecycle_history
    assert_equal 3, history.length  # draft -> review -> published
    assert_equal "published", history.last[:state]
  end

  test "should enforce lifecycle transition rules" do
    lifecycle_manager = ContentLifecycleManager.new(@content_piece[:id])

    # Try invalid transition (draft -> archived without publishing)
    invalid_transition = lifecycle_manager.transition_to("archived", @user)

    assert_not invalid_transition[:success]
    assert_includes invalid_transition[:error], "Invalid state transition"

    # Valid transition path
    lifecycle_manager.transition_to("review", @user)
    lifecycle_manager.transition_to("published", @user)

    archive_transition = lifecycle_manager.transition_to("archived", @user)
    assert archive_transition[:success]
    assert_equal "archived", lifecycle_manager.get_current_state
  end

  test "should schedule automatic content archiving" do
    lifecycle_manager = ContentLifecycleManager.new(@content_piece[:id])

    # Set content to published with auto-archive date
    lifecycle_manager.transition_to("published", @user)

    archive_schedule = lifecycle_manager.schedule_auto_archive(
      archive_date: 30.days.from_now,
      reason: "Campaign end date reached"
    )

    assert archive_schedule[:success]
    assert archive_schedule[:scheduled_job_id].present?

    scheduled_tasks = lifecycle_manager.get_scheduled_tasks
    assert_equal 1, scheduled_tasks.length
    assert_equal "auto_archive", scheduled_tasks.first[:task_type]
  end

  # Content Archiving Tests
  test "should archive content with metadata preservation" do
    archival_system = ContentArchivalSystem.new

    archive_request = {
      content_id: @content_piece[:id],
      archive_reason: "Campaign completed",
      retention_period: "7_years",
      archive_level: "cold_storage",
      metadata_preservation: true
    }

    archive_result = archival_system.archive_content(archive_request)

    assert archive_result[:success]
    assert archive_result[:archive_id].present?
    assert archive_result[:storage_location].present?
    assert archive_result[:metadata_backup_location].present?

    # Verify content is archived but metadata accessible
    archived_content = archival_system.get_archived_content(@content_piece[:id])
    assert archived_content[:is_archived]
    assert archived_content[:metadata].present?
    assert_nil archived_content[:content_body]  # Content body not immediately accessible
  end

  test "should restore archived content" do
    archival_system = ContentArchivalSystem.new

    # First archive the content
    archive_result = archival_system.archive_content({
      content_id: @content_piece[:id],
      archive_reason: "Test archival"
    })

    # Then restore it
    restore_result = archival_system.restore_content(
      @content_piece[:id],
      requested_by: @user,
      restore_reason: "Need for new campaign"
    )

    assert restore_result[:success]
    assert restore_result[:restoration_time].present?

    # Verify content is accessible again
    restored_content = archival_system.get_content(@content_piece[:id])
    assert_not restored_content[:is_archived]
    assert restored_content[:content_body].present?
  end

  # Search and Filtering Tests
  test "should perform advanced content search with multiple criteria" do
    search_engine = ContentSearchEngine.new

    search_criteria = {
      text_query: "product launch email",
      content_types: [ "email_template", "social_post" ],
      date_range: { from: 30.days.ago, to: Time.current },
      tags: [ "urgent", "product_launch" ],
      approval_status: [ "approved", "published" ],
      user_id: @user.id,
      campaign_id: @campaign.id
    }

    search_results = search_engine.advanced_search(search_criteria)

    assert_not_nil search_results
    assert search_results[:total_results] >= 0
    assert search_results[:results].is_a?(Array)

    if search_results[:total_results] > 0
      first_result = search_results[:results].first
      assert first_result[:title].present?
      assert first_result[:relevance_score].present?
      assert first_result[:snippet].present?
    end
  end

  test "should filter content by hierarchical categories" do
    filter_engine = ContentFilterEngine.new

    category_filter = {
      primary_category: "Marketing Materials",
      secondary_category: "Email Marketing",
      tertiary_category: "Product Launch",
      include_subcategories: true
    }

    filtered_results = filter_engine.filter_by_category_hierarchy(category_filter)

    assert_not_nil filtered_results
    assert filtered_results[:matching_content].is_a?(Array)
    assert filtered_results[:category_path].present?

    if filtered_results[:matching_content].any?
      assert filtered_results[:matching_content].all? { |content|
        content[:categories].any? { |cat| cat.include?("Email Marketing") }
      }
    end
  end

  test "should perform semantic content search using AI" do
    semantic_search = ContentSemanticSearch.new

    semantic_query = {
      intent: "Find promotional content for SaaS product launches",
      context: "B2B technology marketing",
      similarity_threshold: 0.75,
      max_results: 10
    }

    semantic_results = semantic_search.semantic_search(semantic_query)

    assert_not_nil semantic_results
    assert semantic_results[:results].is_a?(Array)

    if semantic_results[:results].any?
      semantic_results[:results].each do |result|
        assert result[:semantic_similarity] >= 0.75
        assert result[:content_vector].present?
        assert result[:matching_concepts].any?
      end
    end
  end

  private

  def create_test_content_piece
    # Create an actual ContentRepository record for testing
    file_hash = Digest::SHA256.hexdigest("test_content_#{Time.current.to_f}")
    storage_path = "test/content/#{file_hash[0..7]}"

    repository = ContentRepository.create!(
      title: "Test Email Template",
      body: "This is a test email template for product launch.",
      content_type: "email_template",
      format: "html",
      campaign_id: @campaign.id,
      user_id: @user.id,
      storage_path: storage_path,
      file_hash: file_hash
    )

    {
      id: repository.id,
      title: repository.title,
      body: repository.body,
      content_type: repository.content_type,
      format: repository.format,
      campaign_id: repository.campaign_id,
      user_id: repository.user_id,
      created_at: repository.created_at,
      updated_at: repository.updated_at
    }
  end
end
