require 'test_helper'

class ContentBranchTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:summer_launch)
  end

  test "should create main branch" do
    branch = ContentBranch.create_main_branch(@campaign)
    
    assert branch.persisted?
    assert_equal 'main', branch.name
    assert_equal 'main', branch.branch_type
    assert_equal 'active', branch.status
    assert_not_nil branch.head_version
  end

  test "should create feature branch from main" do
    main_branch = ContentBranch.create_main_branch(@campaign)
    
    feature_branch = ContentBranch.create_feature_branch('new-feature', main_branch)
    
    assert feature_branch.persisted?
    assert_equal 'feature/new-feature', feature_branch.name
    assert_equal 'feature', feature_branch.branch_type
    assert_equal main_branch.head_version, feature_branch.source_version
  end

  test "should validate branch name format" do
    # Test with empty name after normalization (only special chars)
    branch = ContentBranch.new(
      name: '!@#$%',
      content_item: @campaign
    )
    
    assert_not branch.valid?
    assert branch.errors[:name].any?
    
    branch.name = 'valid-branch-name'
    assert branch.valid?
  end

  test "should ensure unique branch names per content item" do
    ContentBranch.create!(
      name: 'test-branch',
      content_item: @campaign,
      branch_type: 'feature',
      status: 'active'
    )
    
    duplicate_branch = ContentBranch.new(
      name: 'test-branch',
      content_item: @campaign,
      branch_type: 'feature',
      status: 'active'
    )
    
    assert_not duplicate_branch.valid?
    assert_includes duplicate_branch.errors[:name], 'has already been taken'
  end

  test "should checkout new version on branch" do
    branch = ContentBranch.create_main_branch(@campaign)
    original_head = branch.head_version
    
    new_version = branch.checkout_new_version(
      { content: "New content version" },
      "Added new feature",
      nil
    )
    
    assert new_version.persisted?
    assert_equal 'committed', new_version.status
    assert_equal original_head, new_version.parent
    assert_equal new_version, branch.reload.head_version
  end

  test "should track commits ahead and behind" do
    main_branch = ContentBranch.create_main_branch(@campaign)
    
    # Add a commit to main
    main_branch.checkout_new_version(
      { content: "Main branch content" },
      "Main commit",
      nil
    )
    
    # Create feature branch from earlier state
    feature_branch = ContentBranch.create_feature_branch('feature', main_branch)
    
    # Add commits to feature branch
    feature_branch.checkout_new_version(
      { content: "Feature content 1" },
      "Feature commit 1",
      nil
    )
    
    feature_branch.checkout_new_version(
      { content: "Feature content 2" },
      "Feature commit 2",
      nil
    )
    
    divergence = feature_branch.divergence_info(main_branch)
    
    assert_equal 2, divergence[:ahead_count]
    assert_equal 2, divergence[:behind_count]
    assert divergence[:requires_merge]
  end

  test "should delete and restore branch" do
    branch = ContentBranch.create_feature_branch('temp-feature', ContentBranch.create_main_branch(@campaign))
    
    assert_equal 'active', branch.status
    
    branch.delete_branch!
    
    assert_equal 'deleted', branch.status
    assert_not_nil branch.deleted_at
    
    branch.restore_branch!
    
    assert_equal 'active', branch.status
    assert_nil branch.deleted_at
  end

  test "should generate branch activity summary" do
    branch = ContentBranch.create_main_branch(@campaign)
    
    # Add some commits
    3.times do |i|
      branch.checkout_new_version(
        { content: "Content #{i}" },
        "Commit #{i}",
        nil
      )
    end
    
    summary = branch.activity_summary
    
    assert_equal 4, summary[:total_commits] # Including initial commit
    assert_not_nil summary[:first_commit]
    assert_not_nil summary[:last_commit]
  end
end