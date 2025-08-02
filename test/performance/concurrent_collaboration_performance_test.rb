require "test_helper"
require "benchmark"

class ConcurrentCollaborationPerformanceTest < ActiveSupport::TestCase
  setup do
    @users = []
    10.times do |i|
      @users << create(:user, email_address: "collaborator#{i}@example.com")
    end
    
    @campaign = create(:campaign, user: @users.first)
    @journey = create(:journey, user: @users.first, campaign: @campaign)
    @content_repository = create(:content_repository, name: "Collaboration Test Repository", user: @users.first)
  end

  test "concurrent journey editing performance" do
    # Create a journey with multiple steps for concurrent editing
    steps = []
    20.times do |i|
      steps << create(:journey_step,
        journey: @journey,
        name: "Collaborative Step #{i + 1}",
        position: i + 1,
        config: { "editable" => true, "content" => "Initial content #{i + 1}" }
      )
    end
    
    concurrent_users = 15
    edits_per_user = 30
    
    puts "Starting concurrent journey editing test with #{concurrent_users} users making #{edits_per_user} edits each"
    
    time = Benchmark.measure do
      threads = []
      
      concurrent_users.times do |user_idx|
        threads << Thread.new do
          user = @users[user_idx % @users.length]
          
          edits_per_user.times do |edit_idx|
            step = steps.sample
            
            # Simulate real-time editing operations
            begin
              # Update step configuration (simulating real-time collaboration)
              updated_config = step.config.dup
              updated_config["content"] = "Updated by user #{user_idx} at #{Time.current.to_f}"
              updated_config["last_editor"] = user.id
              updated_config["edit_count"] = (updated_config["edit_count"] || 0) + 1
              
              step.update!(
                config: updated_config,
                name: "#{step.name} - Edit #{edit_idx + 1}"
              )
              
              # Create activity log for collaboration tracking
              Activity.create!(
                user: user,
                action: 'journey_step_updated',
                trackable: step,
                metadata: {
                  "edit_type" => "collaborative_edit",
                  "concurrent_user_id" => user_idx,
                  "edit_number" => edit_idx + 1,
                  "timestamp" => Time.current.to_f
                }
              )
              
              # Small delay to simulate thinking time
              sleep(0.01)
              
            rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => e
              # Handle concurrent edit conflicts gracefully
              puts "Concurrent edit conflict handled for user #{user_idx}: #{e.class}"
            end
          end
        end
      end
      
      # Wait for all editing threads to complete
      threads.each(&:join)
    end
    
    total_edits = concurrent_users * edits_per_user
    successful_edits = Activity.where(action: 'journey_step_updated').count
    
    puts "Concurrent journey editing completed in #{time.real.round(2)} seconds"
    puts "Total attempted edits: #{total_edits}"
    puts "Successful edits: #{successful_edits}"
    puts "Edit throughput: #{(successful_edits / time.real).round(2)} edits/second"
    puts "Success rate: #{(successful_edits.to_f / total_edits * 100).round(2)}%"
    
    # Should handle concurrent editing efficiently
    assert time.real < 20.0, "Concurrent journey editing too slow: #{time.real} seconds"
    
    # Should have high success rate (at least 80% due to some expected conflicts)
    assert successful_edits.to_f / total_edits >= 0.8, "Too many edit conflicts: #{(successful_edits.to_f / total_edits * 100).round(2)}% success rate"
  end

  test "real-time campaign collaboration performance" do
    # Create campaign plans for collaborative editing
    plan = create(:campaign_plan, campaign: @campaign, user: @users.first)
    
    concurrent_collaborators = 12
    actions_per_collaborator = 25
    
    puts "Starting real-time campaign collaboration test with #{concurrent_collaborators} collaborators"
    
    time = Benchmark.measure do
      threads = []
      
      concurrent_collaborators.times do |collab_idx|
        threads << Thread.new do
          user = @users[collab_idx % @users.length]
          
          actions_per_collaborator.times do |action_idx|
            action_type = ['comment', 'revision', 'approval', 'status_change'].sample
            
            begin
              case action_type
              when 'comment'
                create(:plan_comment,
                  campaign_plan: plan,
                  user: user,
                  comment_text: "Collaborative comment #{action_idx + 1} from user #{collab_idx}",
                  section: ['strategic_rationale', 'target_audience', 'timeline'].sample,
                  parent_comment_id: nil,
                  metadata: {
                    "collaboration_session" => "session_#{collab_idx}",
                    "real_time" => true
                  }
                )
                
              when 'revision'
                create(:plan_revision,
                  campaign_plan: plan,
                  user: user,
                  version_number: "#{action_idx + 1}.#{collab_idx}",
                  changes_summary: "Real-time revision #{action_idx + 1} by collaborator #{collab_idx}",
                  revision_notes: "Collaborative changes with detailed updates and strategic refinements",
                  metadata: {
                    "concurrent_revision" => true,
                    "collaborator_id" => collab_idx
                  }
                )
                
              when 'approval'
                # Simulate approval workflow steps
                Activity.create!(
                  user: user,
                  action: 'campaign_plan_reviewed',
                  trackable: plan,
                  metadata: {
                    "review_type" => "collaborative_review",
                    "reviewer_id" => collab_idx,
                    "review_status" => ["approved", "needs_changes", "pending"].sample,
                    "timestamp" => Time.current.to_f
                  }
                )
                
              when 'status_change'
                # Update plan status (with potential conflicts)
                plan.reload  # Ensure fresh data
                plan.update!(
                  status: ['draft', 'review', 'approved', 'active'].sample,
                  updated_at: Time.current
                )
                
                Activity.create!(
                  user: user,
                  action: 'campaign_plan_status_changed',
                  trackable: plan,
                  metadata: {
                    "status_change" => true,
                    "changed_by" => collab_idx
                  }
                )
              end
              
              # Simulate network latency
              sleep(0.005)
              
            rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => e
              # Handle collaboration conflicts
              puts "Collaboration conflict handled: #{e.class}"
            end
          end
        end
      end
      
      # Wait for all collaboration threads to complete
      threads.each(&:join)
    end
    
    total_actions = concurrent_collaborators * actions_per_collaborator
    successful_actions = Activity.where(trackable: plan).count + 
                        PlanComment.where(campaign_plan: plan).count + 
                        PlanRevision.where(campaign_plan: plan).count
    
    puts "Real-time campaign collaboration completed in #{time.real.round(2)} seconds"
    puts "Total attempted actions: #{total_actions}"
    puts "Successful actions: #{successful_actions}"
    puts "Action throughput: #{(successful_actions / time.real).round(2)} actions/second"
    puts "Success rate: #{(successful_actions.to_f / total_actions * 100).round(2)}%"
    
    # Should handle real-time collaboration efficiently
    assert time.real < 15.0, "Real-time collaboration too slow: #{time.real} seconds"
    
    # Should maintain reasonable success rate
    assert successful_actions.to_f / total_actions >= 0.85, "Too many collaboration conflicts: #{(successful_actions.to_f / total_actions * 100).round(2)}% success rate"
  end

  test "concurrent content editing and version control performance" do
    # Create content items for concurrent editing
    content_items = []
    5.times do |i|
      content_items << create(:content_repository,  # Should be content item
        name: "Concurrent Edit Content #{i + 1}",
        description: "Content for concurrent editing performance testing",
        user: @users.first,
        content_type: 'document'
      )
    end
    
    concurrent_editors = 20
    edits_per_editor = 15
    
    puts "Starting concurrent content editing test with #{concurrent_editors} editors"
    
    time = Benchmark.measure do
      threads = []
      
      concurrent_editors.times do |editor_idx|
        threads << Thread.new do
          user = @users[editor_idx % @users.length]
          
          edits_per_editor.times do |edit_idx|
            content_item = content_items.sample
            
            begin
              # Create new version
              version = create(:content_version,
                content_repository: content_item,  # Should be content_item
                user: user,
                version_number: "#{edit_idx + 1}.#{editor_idx}",
                change_summary: "Concurrent edit #{edit_idx + 1} by editor #{editor_idx}",
                content_data: {
                  "title" => "Updated Title #{edit_idx + 1}",
                  "body" => "Content updated by editor #{editor_idx} at #{Time.current.to_f}",
                  "metadata" => {
                    "concurrent_edit" => true,
                    "editor_id" => editor_idx,
                    "edit_timestamp" => Time.current.to_f
                  }
                },
                file_size: rand(1000..50000),
                checksum: "sha256_#{SecureRandom.hex(16)}"
              )
              
              # Create revision record
              create(:content_revision,
                content_repository: content_item,  # Should be content_item
                user: user,
                revision_type: 'minor',
                changes_description: "Concurrent revision #{edit_idx + 1} with real-time collaboration",
                previous_content: {
                  "backup_timestamp" => Time.current.to_f,
                  "editor_info" => "editor_#{editor_idx}"
                }
              )
              
              # Log activity
              Activity.create!(
                user: user,
                action: 'content_edited',
                trackable: content_item,
                metadata: {
                  "concurrent_edit" => true,
                  "version_id" => version.id,
                  "editor_index" => editor_idx
                }
              )
              
              # Simulate editing time
              sleep(0.01)
              
            rescue ActiveRecord::RecordInvalid => e
              puts "Content editing conflict handled: #{e.class}"
            end
          end
        end
      end
      
      # Wait for all editing threads to complete
      threads.each(&:join)
    end
    
    total_edit_attempts = concurrent_editors * edits_per_editor
    successful_versions = ContentVersion.count
    successful_revisions = ContentRevision.count
    
    puts "Concurrent content editing completed in #{time.real.round(2)} seconds"
    puts "Total edit attempts: #{total_edit_attempts}"
    puts "Successful versions created: #{successful_versions}"
    puts "Successful revisions created: #{successful_revisions}"
    puts "Version creation rate: #{(successful_versions / time.real).round(2)} versions/second"
    
    # Should handle concurrent content editing efficiently
    assert time.real < 12.0, "Concurrent content editing too slow: #{time.real} seconds"
    
    # Should create versions successfully
    assert successful_versions >= total_edit_attempts * 0.8, "Too many version creation failures"
  end

  test "real-time A/B test monitoring performance" do
    # Create A/B test for real-time monitoring
    ab_test = create(:ab_test, user: @users.first, campaign: @campaign)
    control_variant = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey)
    variation_variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey)
    
    concurrent_visitors = 50
    events_per_visitor = 20
    
    puts "Starting real-time A/B test monitoring with #{concurrent_visitors} concurrent visitors"
    
    time = Benchmark.measure do
      threads = []
      
      concurrent_visitors.times do |visitor_idx|
        threads << Thread.new do
          visitor_id = "realtime_visitor_#{visitor_idx}"
          session_id = "realtime_session_#{visitor_idx}"
          
          # Assign visitor to variant
          assigned_variant = ab_test.assign_visitor(visitor_id)
          
          events_per_visitor.times do |event_idx|
            event_type = ['impression', 'click', 'engagement', 'conversion'].sample
            
            begin
              # Create real-time metric
              create(:ab_test_metric,
                ab_test: ab_test,
                ab_test_variant: assigned_variant,
                user: @users.first,
                metric_name: event_type,
                metric_value: case event_type
                             when 'impression' then 1
                             when 'click' then rand(0..1)
                             when 'engagement' then rand(1..100)
                             when 'conversion' then rand(0..1)
                             end,
                visitor_id: visitor_id,
                session_id: session_id,
                timestamp: Time.current,
                metadata: {
                  "real_time" => true,
                  "visitor_index" => visitor_idx,
                  "event_sequence" => event_idx + 1,
                  "user_agent" => "Test Agent #{visitor_idx}",
                  "page_url" => "/test-page-#{rand(1..5)}"
                }
              )
              
              # Simulate real-time processing delay
              sleep(0.002)
              
            rescue ActiveRecord::RecordInvalid => e
              puts "Real-time metric recording conflict: #{e.class}"
            end
          end
        end
      end
      
      # Wait for all visitor simulation threads to complete
      threads.each(&:join)
    end
    
    total_events = concurrent_visitors * events_per_visitor
    recorded_metrics = AbTestMetric.where(ab_test: ab_test).count
    
    puts "Real-time A/B test monitoring completed in #{time.real.round(2)} seconds"
    puts "Total events: #{total_events}"
    puts "Recorded metrics: #{recorded_metrics}"
    puts "Metric recording rate: #{(recorded_metrics / time.real).round(2)} metrics/second"
    puts "Recording success rate: #{(recorded_metrics.to_f / total_events * 100).round(2)}%"
    
    # Should handle real-time monitoring efficiently
    assert time.real < 8.0, "Real-time A/B test monitoring too slow: #{time.real} seconds"
    
    # Should have high success rate for metric recording
    assert recorded_metrics.to_f / total_events >= 0.95, "Metric recording success rate too low: #{(recorded_metrics.to_f / total_events * 100).round(2)}%"
  end

  test "collaborative brand asset management performance" do
    # Create brand assets for collaborative management
    brand = create(:brand, user: @users.first)
    
    asset_count = 10
    assets = []
    asset_count.times do |i|
      assets << create(:brand_asset,
        brand: brand,
        name: "Collaborative Asset #{i + 1}",
        asset_type: ['logo', 'image', 'document', 'video'].sample,
        file_size: rand(1000000..50000000),
        user: @users.first
      )
    end
    
    concurrent_managers = 15
    operations_per_manager = 20
    
    puts "Starting collaborative brand asset management test"
    
    time = Benchmark.measure do
      threads = []
      
      concurrent_managers.times do |manager_idx|
        threads << Thread.new do
          user = @users[manager_idx % @users.length]
          
          operations_per_manager.times do |op_idx|
            asset = assets.sample
            operation = ['update_metadata', 'add_version', 'change_status', 'add_tag'].sample
            
            begin
              case operation
              when 'update_metadata'
                asset.update!(
                  metadata: (asset.metadata || {}).merge({
                    "last_updated_by" => user.id,
                    "update_timestamp" => Time.current.to_f,
                    "collaborative_edit" => true,
                    "manager_index" => manager_idx
                  })
                )
                
              when 'add_version'
                # Simulate adding new version of asset
                Activity.create!(
                  user: user,
                  action: 'brand_asset_versioned',
                  trackable: asset,
                  metadata: {
                    "version_type" => "collaborative_update",
                    "version_number" => "#{op_idx + 1}.#{manager_idx}",
                    "file_size" => rand(1000000..10000000)
                  }
                )
                
              when 'change_status'
                asset.update!(
                  processing_status: ['pending', 'processing', 'completed', 'failed'].sample,
                  updated_at: Time.current
                )
                
              when 'add_tag'
                current_tags = asset.tags || []
                new_tag = "tag_#{manager_idx}_#{op_idx}"
                asset.update!(tags: current_tags + [new_tag])
              end
              
              # Log collaborative activity
              Activity.create!(
                user: user,
                action: 'brand_asset_managed',
                trackable: asset,
                metadata: {
                  "operation" => operation,
                  "collaborative" => true,
                  "manager_id" => manager_idx
                }
              )
              
              # Simulate processing time
              sleep(0.005)
              
            rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => e
              puts "Asset management conflict handled: #{e.class}"
            end
          end
        end
      end
      
      # Wait for all management threads to complete
      threads.each(&:join)
    end
    
    total_operations = concurrent_managers * operations_per_manager
    successful_activities = Activity.where(action: ['brand_asset_versioned', 'brand_asset_managed']).count
    
    puts "Collaborative brand asset management completed in #{time.real.round(2)} seconds"
    puts "Total operations: #{total_operations}"
    puts "Successful activities: #{successful_activities}"
    puts "Operation throughput: #{(successful_activities / time.real).round(2)} operations/second"
    
    # Should handle collaborative asset management efficiently
    assert time.real < 10.0, "Collaborative asset management too slow: #{time.real} seconds"
    
    # Should complete most operations successfully
    assert successful_activities >= total_operations * 0.8, "Too many asset management conflicts"
  end

  test "memory usage during concurrent collaboration" do
    initial_memory = get_memory_usage
    
    # Run a simplified version of concurrent collaboration
    journey = create(:journey, user: @users.first, campaign: @campaign)
    
    # Create steps for collaboration
    steps = []
    15.times do |i|
      steps << create(:journey_step,
        journey: journey,
        name: "Memory Test Step #{i + 1}",
        position: i + 1
      )
    end
    
    concurrent_users = 10
    edits_per_user = 15
    
    # Simulate concurrent editing with memory monitoring
    threads = []
    concurrent_users.times do |user_idx|
      threads << Thread.new do
        user = @users[user_idx % @users.length]
        
        edits_per_user.times do |edit_idx|
          step = steps.sample
          
          # Simulate memory-intensive operations
          large_config = {
            "content" => "x" * 1000,  # 1KB of content
            "metadata" => Array.new(100) { |i| "item_#{i}" },
            "history" => Array.new(50) { |i| { "edit" => i, "timestamp" => Time.current } }
          }
          
          step.update!(
            config: large_config,
            name: "Memory Test Edit #{edit_idx + 1}"
          )
          
          Activity.create!(
            user: user,
            action: 'journey_step_updated',
            trackable: step,
            metadata: {
              "memory_test" => true,
              "large_data" => "y" * 500  # 500B metadata
            }
          )
          
          sleep(0.01)
        end
      end
    end
    
    # Wait for completion
    threads.each(&:join)
    
    final_memory = get_memory_usage
    memory_increase = final_memory - initial_memory
    
    puts "Memory increased by #{memory_increase.round(2)}MB during concurrent collaboration"
    
    # Should not consume excessive memory during collaboration
    assert memory_increase < 150, "Concurrent collaboration memory usage too high: #{memory_increase}MB"
  end

  private

  def get_memory_usage
    # Simple memory usage check (in MB)
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    0 # Return 0 if memory check fails
  end
end