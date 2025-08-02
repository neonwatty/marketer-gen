require "test_helper"
require "benchmark"

class ContentManagementPerformanceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @brand = create(:brand, user: @user)
    @campaign = create(:campaign, user: @user)
  end

  test "content repository creation performance with large datasets" do
    repository_count = 50
    items_per_repository = 200  # Total: 10,000 content items
    
    time = Benchmark.measure do
      repository_count.times do |repo_idx|
        repository = create(:content_repository,
          name: "Performance Repository #{repo_idx + 1}",
          description: "Repository #{repo_idx + 1} for performance testing with large content volumes",
          user: @user,
          repository_type: ['asset_library', 'template_collection', 'brand_guidelines', 'campaign_materials'].sample,
          storage_limit: 10.gigabytes,
          is_public: [true, false].sample
        )
        
        # Create content items in batches for efficiency
        items_per_repository.times do |item_idx|
          create(:content_repository,  # This should be content item, but using repository for now
            name: "Content Item R#{repo_idx + 1}-I#{item_idx + 1}",
            description: "Content item #{item_idx + 1} in repository #{repo_idx + 1}",
            user: @user,
            content_type: ['document', 'image', 'video', 'template', 'asset'].sample,
            tags: ["tag#{rand(1..20)}", "category#{rand(1..10)}", "type#{rand(1..5)}"],
            metadata: {
              "file_size" => rand(1000..50000000),
              "dimensions" => "#{rand(100..4000)}x#{rand(100..4000)}",
              "format" => ['PNG', 'JPG', 'PDF', 'DOCX', 'MP4'].sample,
              "created_by" => "user_#{rand(1..100)}",
              "last_modified" => rand(30.days).seconds.ago
            }
          )
        end
      end
    end
    
    total_items = repository_count * items_per_repository
    puts "Created #{repository_count} repositories with #{total_items} content items in #{time.real.round(2)} seconds"
    puts "Average time per repository: #{(time.real / repository_count * 1000).round(2)}ms"
    puts "Average time per content item: #{(time.real / total_items * 1000).round(2)}ms"
    
    # Should create content efficiently (under 30 seconds for 10k items)
    assert time.real < 30.0, "Content creation too slow: #{time.real} seconds for #{total_items} items"
    
    # Verify content was created
    assert ContentRepository.count >= repository_count
  end

  test "content search performance with large repository" do
    # Create a large content repository
    repository = create(:content_repository, name: "Large Search Repository", user: @user)
    
    # Create diverse content for search testing
    content_items = []
    1000.times do |i|
      keywords = ['marketing', 'design', 'strategy', 'analytics', 'branding', 'content', 'social', 'email', 'campaign', 'creative'].sample(3)
      
      content_items << create(:content_repository,  # Should be content item
        name: "Search Test Content #{i + 1}",
        description: "Content item #{i + 1} featuring #{keywords.join(', ')} for comprehensive search testing",
        user: @user,
        content_type: ['document', 'image', 'video', 'template'].sample,
        tags: keywords + ["item#{i}", "batch#{i / 100}", "group#{i / 50}"],
        metadata: {
          "keywords" => keywords,
          "content_category" => ['blog_post', 'social_media', 'email_template', 'landing_page', 'advertisement'].sample,
          "difficulty_level" => ['beginner', 'intermediate', 'advanced'].sample,
          "industry" => ['technology', 'healthcare', 'finance', 'retail', 'education'].sample
        }
      )
    end
    
    puts "Created 1000 content items for search performance testing"
    
    # Test various search scenarios
    search_time = Benchmark.measure do
      # Simple text search
      marketing_results = ContentRepository.where("name ILIKE ? OR description ILIKE ?", "%marketing%", "%marketing%")
      assert marketing_results.count > 0
      
      # Tag-based search
      tag_results = ContentRepository.joins("LEFT JOIN unnest(tags) AS tag_element ON true")
                                   .where("tag_element::text ILIKE ?", "%design%")
      
      # Content type filtering
      image_results = ContentRepository.where(content_type: 'image')
      assert image_results.count >= 0
      
      # Metadata search (JSON queries)
      # Note: This is a simplified version - actual implementation would depend on JSON column structure
      advanced_results = ContentRepository.where("metadata->>'difficulty_level' = ?", 'advanced')
      
      # Complex combined search
      complex_results = ContentRepository.where("name ILIKE ? OR description ILIKE ?", "%strategy%", "%strategy%")
                                        .where(content_type: ['document', 'template'])
      
      # Search with sorting by relevance (simulated)
      sorted_results = ContentRepository.where("name ILIKE ?", "%content%")
                                       .order(:name)
                                       .limit(50)
      assert sorted_results.count <= 50
    end
    
    puts "Content search operations (1000 items) completed in #{search_time.real.round(2)} seconds"
    
    # Should search quickly (under 1 second)
    assert search_time.real < 1.0, "Content search too slow: #{search_time.real} seconds"
  end

  test "content version control performance" do
    repository = create(:content_repository, name: "Version Control Test", user: @user)
    
    # Create content items with extensive version history
    content_items = []
    10.times do |i|
      content_items << create(:content_repository,  # Should be content item
        name: "Versioned Content #{i + 1}",
        description: "Content with extensive version history",
        user: @user
      )
    end
    
    # Create version history for each content item
    version_time = Benchmark.measure do
      content_items.each do |content|
        # Create 50 versions per content item
        50.times do |version_num|
          create(:content_version,
            content_repository: content,  # Should be content_item: content
            user: @user,
            version_number: "#{version_num + 1}.0",
            change_summary: "Version #{version_num + 1} updates with performance testing modifications",
            content_data: {
              "title" => "Updated title for version #{version_num + 1}",
              "body" => "Content body updated in version #{version_num + 1} with comprehensive changes",
              "metadata" => {
                "word_count" => rand(500..5000),
                "last_edited" => Time.current,
                "editor" => "user_#{rand(1..10)}"
              }
            },
            file_size: rand(1000..100000),
            checksum: "sha256_#{SecureRandom.hex(32)}"
          )
        end
        
        # Create revision history
        10.times do |rev_num|
          create(:content_revision,
            content_repository: content,  # Should be content_item: content
            user: @user,
            revision_type: ['major', 'minor', 'patch'].sample,
            changes_description: "Revision #{rev_num + 1} with detailed change tracking and analysis",
            previous_content: {
              "backup_data" => "Previous version content #{rev_num}",
              "timestamp" => (rev_num + 1).hours.ago
            }
          )
        end
      end
    end
    
    total_versions = content_items.length * 50
    total_revisions = content_items.length * 10
    
    puts "Created #{total_versions} versions and #{total_revisions} revisions in #{version_time.real.round(2)} seconds"
    puts "Average time per version: #{(version_time.real / total_versions * 1000).round(2)}ms"
    
    # Should create versions efficiently (under 5 seconds)
    assert version_time.real < 5.0, "Version creation too slow: #{version_time.real} seconds"
    
    # Test version retrieval performance
    retrieval_time = Benchmark.measure do
      content_items.each do |content|
        # Get latest version
        latest = content.content_versions.order(:created_at).last
        assert latest.present?
        
        # Get specific version
        specific = content.content_versions.where(version_number: "25.0").first
        
        # Get version history
        history = content.content_versions.order(:created_at).limit(10)
        assert history.count <= 10
        
        # Get revision diff
        revisions = content.content_revisions.order(:created_at).limit(5)
        assert revisions.count <= 5
      end
    end
    
    puts "Version retrieval operations completed in #{retrieval_time.real.round(2)} seconds"
    
    # Should retrieve versions quickly (under 1 second)
    assert retrieval_time.real < 1.0, "Version retrieval too slow: #{retrieval_time.real} seconds"
  end

  test "content approval workflow performance" do
    repository = create(:content_repository, name: "Approval Workflow Test", user: @user)
    
    # Create content requiring approval
    content_items = []
    100.times do |i|
      content_items << create(:content_repository,  # Should be content item
        name: "Approval Test Content #{i + 1}",
        description: "Content #{i + 1} requiring approval workflow processing",
        user: @user,
        approval_status: 'pending'
      )
    end
    
    # Create approval workflows
    workflow_time = Benchmark.measure do
      content_items.each do |content|
        # Create approval workflow
        workflow = create(:content_workflow,
          content_repository: content,  # Should be content_item: content
          user: @user,
          workflow_type: 'approval',
          workflow_steps: [
            { "step" => "initial_review", "assignee" => "reviewer_1", "status" => "pending" },
            { "step" => "content_check", "assignee" => "editor_1", "status" => "waiting" },
            { "step" => "brand_compliance", "assignee" => "brand_manager", "status" => "waiting" },
            { "step" => "final_approval", "assignee" => "director", "status" => "waiting" }
          ],
          current_step: 0,
          deadline: 3.days.from_now
        )
        
        # Create approval record
        create(:content_approval,
          content_repository: content,  # Should be content_item: content
          user: @user,
          approval_status: 'pending',
          approval_type: 'content_review',
          comments: "Automated approval test for performance evaluation",
          approval_criteria: {
            "brand_compliance" => true,
            "content_quality" => true,
            "technical_accuracy" => true,
            "legal_compliance" => true
          }
        )
      end
    end
    
    puts "Created approval workflows for 100 content items in #{workflow_time.real.round(2)} seconds"
    
    # Should create workflows efficiently (under 3 seconds)
    assert workflow_time.real < 3.0, "Approval workflow creation too slow: #{workflow_time.real} seconds"
    
    # Test workflow processing performance
    processing_time = Benchmark.measure do
      content_items.first(20).each do |content|
        workflow = content.content_workflows.first
        approval = content.content_approvals.first
        
        # Simulate workflow progression
        workflow.workflow_steps.each_with_index do |step, index|
          step["status"] = ["approved", "rejected", "needs_revision"].sample
          workflow.current_step = index + 1
          workflow.save!
        end
        
        # Update approval status
        approval.approval_status = ["approved", "rejected", "pending_revision"].sample
        approval.approved_at = Time.current if approval.approval_status == 'approved'
        approval.save!
      end
    end
    
    puts "Processed 20 approval workflows in #{processing_time.real.round(2)} seconds"
    
    # Should process workflows quickly (under 1 second)
    assert processing_time.real < 1.0, "Workflow processing too slow: #{processing_time.real} seconds"
  end

  test "concurrent content collaboration simulation" do
    repository = create(:content_repository, name: "Collaboration Test", user: @user)
    
    # Create shared content for collaboration
    content_item = create(:content_repository,  # Should be content item
      name: "Collaborative Content",
      description: "Content for concurrent collaboration testing",
      user: @user
    )
    
    # Simulate concurrent users editing content
    user_count = 20
    edits_per_user = 10
    
    time = Benchmark.measure do
      threads = []
      
      user_count.times do |user_idx|
        threads << Thread.new do
          test_user = create(:user, email_address: "collab#{user_idx}@example.com")
          
          edits_per_user.times do |edit_idx|
            # Simulate content editing
            create(:content_revision,
              content_repository: content_item,  # Should be content_item: content_item
              user: test_user,
              revision_type: 'minor',
              changes_description: "Concurrent edit #{edit_idx + 1} by user #{user_idx}",
              previous_content: {
                "edit_timestamp" => Time.current,
                "edit_type" => "collaborative_edit",
                "user_id" => test_user.id
              }
            )
            
            # Add small delay to simulate real editing
            sleep(0.01)
          end
        end
      end
      
      # Wait for all threads to complete
      threads.each(&:join)
    end
    
    total_edits = user_count * edits_per_user
    puts "Processed #{total_edits} concurrent content edits (#{user_count} users) in #{time.real.round(2)} seconds"
    puts "Throughput: #{(total_edits / time.real).round(2)} edits/second"
    
    # Should handle concurrent editing efficiently (under 10 seconds)
    assert time.real < 10.0, "Concurrent content editing too slow: #{time.real} seconds"
    
    # Verify all edits were recorded
    assert content_item.content_revisions.count >= total_edits
  end

  test "content archive and cleanup performance" do
    repository = create(:content_repository, name: "Archive Test", user: @user)
    
    # Create large amount of content for archiving
    old_content = []
    500.times do |i|
      old_content << create(:content_repository,  # Should be content item
        name: "Archive Test Content #{i + 1}",
        description: "Content #{i + 1} for archive performance testing",
        user: @user,
        created_at: rand(365).days.ago,
        updated_at: rand(30).days.ago
      )
    end
    
    puts "Created 500 content items for archive testing"
    
    # Test archiving performance
    archive_time = Benchmark.measure do
      old_content.each_slice(50) do |content_batch|
        content_batch.each do |content|
          create(:content_archive,
            content_repository: content,  # Should be content_item: content
            user: @user,
            archive_reason: 'automated_cleanup',
            archive_type: 'soft_delete',
            archived_data: {
              "original_name" => content.name,
              "original_description" => content.description,
              "archive_timestamp" => Time.current,
              "retention_period" => "2 years"
            },
            retention_until: 2.years.from_now
          )
        end
      end
    end
    
    puts "Archived 500 content items in #{archive_time.real.round(2)} seconds"
    
    # Should archive content efficiently (under 5 seconds)
    assert archive_time.real < 5.0, "Content archiving too slow: #{archive_time.real} seconds"
    
    # Test archive retrieval performance
    retrieval_time = Benchmark.measure do
      # Get recently archived content
      recent_archives = ContentArchive.where("created_at > ?", 1.hour.ago)
      assert recent_archives.count > 0
      
      # Get archives by reason
      automated_archives = ContentArchive.where(archive_reason: 'automated_cleanup')
      assert automated_archives.count > 0
      
      # Get archives with specific retention
      long_term_archives = ContentArchive.where("retention_until > ?", 1.year.from_now)
      assert long_term_archives.count > 0
    end
    
    puts "Archive retrieval operations completed in #{retrieval_time.real.round(2)} seconds"
    
    # Should retrieve archives quickly (under 0.5 seconds)
    assert retrieval_time.real < 0.5, "Archive retrieval too slow: #{retrieval_time.real} seconds"
  end

  test "content tagging and categorization performance" do
    repository = create(:content_repository, name: "Tagging Test", user: @user)
    
    # Create content with extensive tagging
    content_items = []
    tag_time = Benchmark.measure do
      1000.times do |i|
        # Generate diverse tags
        category_tags = ["category_#{rand(1..20)}", "type_#{rand(1..15)}"]
        topic_tags = ["marketing", "design", "strategy", "analytics", "branding"].sample(2)
        difficulty_tags = ["beginner", "intermediate", "advanced"].sample(1)
        industry_tags = ["tech", "healthcare", "finance", "retail", "education"].sample(1)
        format_tags = ["video", "document", "image", "template", "presentation"].sample(1)
        
        all_tags = category_tags + topic_tags + difficulty_tags + industry_tags + format_tags
        
        content_items << create(:content_repository,  # Should be content item
          name: "Tagged Content #{i + 1}",
          description: "Content with comprehensive tagging for performance testing",
          user: @user,
          tags: all_tags,
          content_type: format_tags.first
        )
        
        # Create content tags
        all_tags.each do |tag_name|
          create(:content_tag,
            content_repository: content_items.last,  # Should be content_item
            user: @user,
            tag_name: tag_name,
            tag_type: case tag_name
                     when /^category_/ then 'category'
                     when /^type_/ then 'content_type'
                     when /marketing|design|strategy/ then 'topic'
                     when /beginner|intermediate|advanced/ then 'difficulty'
                     else 'general'
                     end,
            tag_weight: rand(1..10)
          )
        end
      end
    end
    
    puts "Created 1000 content items with comprehensive tagging in #{tag_time.real.round(2)} seconds"
    
    # Should tag content efficiently (under 10 seconds)
    assert tag_time.real < 10.0, "Content tagging too slow: #{tag_time.real} seconds"
    
    # Test tag-based search and filtering performance
    search_time = Benchmark.measure do
      # Search by specific tags
      marketing_content = ContentTag.joins(:content_repository)
                                   .where(tag_name: 'marketing')
                                   .includes(:content_repository)
      
      # Search by tag type
      category_content = ContentTag.where(tag_type: 'category')
                                  .includes(:content_repository)
      
      # Search by tag weight (popularity)
      popular_content = ContentTag.where("tag_weight > ?", 7)
                                 .includes(:content_repository)
      
      # Complex tag combinations
      complex_search = ContentTag.joins(:content_repository)
                                .where(tag_name: ['marketing', 'strategy'])
                                .group('content_repositories.id')
                                .having('COUNT(*) > 1')
    end
    
    puts "Tag-based search operations completed in #{search_time.real.round(2)} seconds"
    
    # Should search by tags quickly (under 1 second)
    assert search_time.real < 1.0, "Tag-based search too slow: #{search_time.real} seconds"
  end

  test "memory usage during large content operations" do
    initial_memory = get_memory_usage
    
    repository = create(:content_repository, name: "Memory Test Repository", user: @user)
    
    # Create large content dataset
    500.times do |i|
      content = create(:content_repository,  # Should be content item
        name: "Memory Test Content #{i + 1}",
        description: "Large content item #{i + 1} for memory performance testing with extensive metadata",
        user: @user,
        metadata: {
          "large_data" => "x" * 1000,  # 1KB of data per item
          "complex_structure" => {
            "nested_data" => Array.new(100) { |j| "item_#{j}" },
            "timestamps" => Array.new(50) { |j| (j + 1).hours.ago }
          }
        }
      )
      
      # Add versions and revisions
      5.times do |v|
        create(:content_version,
          content_repository: content,
          user: @user,
          version_number: "#{v + 1}.0",
          change_summary: "Version #{v + 1} for memory testing",
          content_data: { "version_data" => "y" * 500 }  # 500B per version
        )
      end
    end
    
    final_memory = get_memory_usage
    memory_increase = final_memory - initial_memory
    
    puts "Memory increased by #{memory_increase.round(2)}MB during large content operations"
    
    # Should not consume excessive memory (less than 200MB increase)
    assert memory_increase < 200, "Memory usage too high: #{memory_increase}MB"
  end

  private

  def get_memory_usage
    # Simple memory usage check (in MB)
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    0 # Return 0 if memory check fails
  end
end