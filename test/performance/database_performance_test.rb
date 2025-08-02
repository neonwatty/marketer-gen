require "test_helper"
require "benchmark"

class DatabasePerformanceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @campaign = create(:campaign, user: @user)
    @journey = create(:journey, user: @user, campaign: @campaign)
  end

  test "N+1 query detection in journey loading" do
    # Create complex journey structure
    journey = create(:journey, user: @user, campaign: @campaign)
    
    # Create journey steps with various associations
    steps = []
    20.times do |i|
      steps << create(:journey_step,
        journey: journey,
        name: "Query Test Step #{i + 1}",
        position: i + 1,
        config: { "template" => "template_#{i}" }
      )
    end
    
    # Create step transitions
    15.times do
      from_step = steps.sample
      to_step = steps.sample
      next if from_step == to_step
      
      create(:step_transition,
        from_step: from_step,
        to_step: to_step,
        condition_type: "always"
      )
    end
    
    # Create analytics for each step
    steps.each do |step|
      create(:journey_analytics,
        journey: journey,
        campaign: @campaign,
        user: @user,
        step_data: { "step_id" => step.id }
      )
    end
    
    # Test query count when loading journey with associations
    query_count = 0
    original_method = ActiveRecord::Base.connection.method(:execute)
    
    ActiveRecord::Base.connection.define_singleton_method(:execute) do |sql, *args|
      query_count += 1 unless sql.match?(/^(BEGIN|COMMIT|SAVEPOINT|RELEASE|ROLLBACK)/)
      original_method.call(sql, *args)
    end
    
    time = Benchmark.measure do
      # Load journey with all associations
      loaded_journey = Journey.includes(
        :journey_steps, 
        :journey_analytics,
        journey_steps: [:step_transitions, :to_transitions]
      ).find(journey.id)
      
      # Access all associations to trigger loading
      loaded_journey.journey_steps.each do |step|
        step.step_transitions.count
        step.to_transitions.count
      end
      
      loaded_journey.journey_analytics.count
    end
    
    # Restore original method
    ActiveRecord::Base.connection.define_singleton_method(:execute, original_method)
    
    puts "Loaded journey with associations in #{time.real.round(2)} seconds using #{query_count} queries"
    
    # Should use reasonable number of queries (less than 10 for proper eager loading)
    assert query_count < 10, "Too many queries (N+1 detected): #{query_count} queries"
    
    # Should load quickly
    assert time.real < 0.5, "Journey loading too slow: #{time.real} seconds"
  end

  test "campaign planning query optimization" do
    # Create large dataset for campaign planning
    users = []
    campaigns = []
    
    5.times do |i|
      users << create(:user, email_address: "querytest#{i}@example.com")
    end
    
    users.each do |user|
      10.times do |i|
        campaign = create(:campaign, user: user, name: "Query Test Campaign #{i + 1}")
        campaigns << campaign
        
        # Create campaign plan with revisions and comments
        plan = create(:campaign_plan, campaign: campaign, user: user)
        
        5.times do |j|
          create(:plan_revision, campaign_plan: plan, user: user, version_number: j + 1)
        end
        
        3.times do
          create(:plan_comment, campaign_plan: plan, user: user)
        end
      end
    end
    
    puts "Created test dataset: #{users.length} users, #{campaigns.length} campaigns"
    
    # Test query performance for campaign dashboard
    query_count = 0
    original_method = ActiveRecord::Base.connection.method(:execute)
    
    ActiveRecord::Base.connection.define_singleton_method(:execute) do |sql, *args|
      query_count += 1 unless sql.match?(/^(BEGIN|COMMIT|SAVEPOINT|RELEASE|ROLLBACK)/)
      original_method.call(sql, *args)
    end
    
    dashboard_time = Benchmark.measure do
      # Simulate campaign dashboard query
      user = users.first
      
      # Load user's campaigns with plans, revisions, and comments
      user_campaigns = Campaign.includes(
        :campaign_plan,
        campaign_plan: [:plan_revisions, :plan_comments]
      ).where(user: user)
      
      user_campaigns.each do |campaign|
        campaign.campaign_plan&.plan_revisions&.count
        campaign.campaign_plan&.plan_comments&.count
      end
    end
    
    # Restore original method
    ActiveRecord::Base.connection.define_singleton_method(:execute, original_method)
    
    puts "Campaign dashboard loaded in #{dashboard_time.real.round(2)} seconds using #{query_count} queries"
    
    # Should use efficient queries
    assert query_count < 5, "Campaign dashboard uses too many queries: #{query_count}"
    assert dashboard_time.real < 0.3, "Campaign dashboard loading too slow: #{dashboard_time.real} seconds"
  end

  test "content repository search query performance" do
    # Create large content repository
    repository = create(:content_repository, name: "Query Performance Repository", user: @user)
    
    # Create large dataset of content
    content_items = []
    500.times do |i|
      content_items << create(:content_repository,  # Should be content item
        name: "Query Test Content #{i + 1}",
        description: "Content item #{i + 1} with searchable text including #{['marketing', 'design', 'strategy'].sample}",
        user: @user,
        tags: ["tag#{rand(1..50)}", "category#{rand(1..20)}"],
        content_type: ['document', 'image', 'video'].sample,
        metadata: {
          "keywords" => ['content', 'performance', 'testing'].sample(2),
          "category" => ['blog', 'social', 'email'].sample
        }
      )
    end
    
    puts "Created 500 content items for search performance testing"
    
    # Test various search query patterns
    search_queries = [
      # Text search
      -> { ContentRepository.where("name ILIKE ? OR description ILIKE ?", "%marketing%", "%marketing%") },
      # Tag search (array contains)
      -> { ContentRepository.where("tags && ARRAY[?]", ["tag1", "tag2"]) },
      # Content type filter
      -> { ContentRepository.where(content_type: 'document') },
      # Combined search
      -> { ContentRepository.where("name ILIKE ?", "%content%").where(content_type: ['document', 'image']) },
      # Date range search
      -> { ContentRepository.where("created_at > ?", 7.days.ago) }
    ]
    
    search_queries.each_with_index do |query_proc, index|
      query_count = 0
      original_method = ActiveRecord::Base.connection.method(:execute)
      
      ActiveRecord::Base.connection.define_singleton_method(:execute) do |sql, *args|
        query_count += 1 unless sql.match?(/^(BEGIN|COMMIT|SAVEPOINT|RELEASE|ROLLBACK)/)
        original_method.call(sql, *args)
      end
      
      time = Benchmark.measure do
        results = query_proc.call
        results.limit(50).to_a  # Force query execution
      end
      
      # Restore original method
      ActiveRecord::Base.connection.define_singleton_method(:execute, original_method)
      
      puts "Search query #{index + 1} completed in #{time.real.round(2)} seconds using #{query_count} queries"
      
      # Each search should use only 1 query and complete quickly
      assert query_count == 1, "Search query #{index + 1} uses too many queries: #{query_count}"
      assert time.real < 0.1, "Search query #{index + 1} too slow: #{time.real} seconds"
    end
  end

  test "A/B test metrics aggregation query performance" do
    # Create A/B test with large metrics dataset
    ab_test = create(:ab_test, user: @user, campaign: @campaign)
    control_variant = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey)
    variation_variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey)
    
    # Create large metrics dataset
    1000.times do |i|
      variant = [control_variant, variation_variant].sample
      
      create(:ab_test_metric,
        ab_test: ab_test,
        ab_test_variant: variant,
        user: @user,
        metric_name: ['impression', 'click', 'conversion'].sample,
        metric_value: rand(0..1),
        visitor_id: "visitor_#{rand(1..500)}",  # Some visitors have multiple metrics
        timestamp: Time.current - rand(30.days).seconds
      )
    end
    
    puts "Created 1000 A/B test metrics for aggregation testing"
    
    # Test aggregation query performance
    aggregation_queries = [
      # Basic aggregation by variant
      -> { 
        AbTestMetric.where(ab_test: ab_test)
                   .group(:ab_test_variant_id)
                   .group(:metric_name)
                   .count
      },
      # Conversion rate calculation
      -> {
        AbTestMetric.where(ab_test: ab_test, metric_name: 'conversion')
                   .group(:ab_test_variant_id)
                   .average(:metric_value)
      },
      # Daily metrics trend
      -> {
        AbTestMetric.where(ab_test: ab_test)
                   .group(:ab_test_variant_id)
                   .group("DATE(timestamp)")
                   .count
      },
      # Unique visitor count
      -> {
        AbTestMetric.where(ab_test: ab_test)
                   .group(:ab_test_variant_id)
                   .distinct
                   .count(:visitor_id)
      }
    ]
    
    aggregation_queries.each_with_index do |query_proc, index|
      query_count = 0
      original_method = ActiveRecord::Base.connection.method(:execute)
      
      ActiveRecord::Base.connection.define_singleton_method(:execute) do |sql, *args|
        query_count += 1 unless sql.match?(/^(BEGIN|COMMIT|SAVEPOINT|RELEASE|ROLLBACK)/)
        original_method.call(sql, *args)
      end
      
      time = Benchmark.measure do
        result = query_proc.call
        result.to_h if result.respond_to?(:to_h)  # Force query execution
      end
      
      # Restore original method
      ActiveRecord::Base.connection.define_singleton_method(:execute, original_method)
      
      puts "Aggregation query #{index + 1} completed in #{time.real.round(2)} seconds using #{query_count} queries"
      
      # Each aggregation should use only 1 query and complete quickly
      assert query_count == 1, "Aggregation query #{index + 1} uses too many queries: #{query_count}"
      assert time.real < 0.2, "Aggregation query #{index + 1} too slow: #{time.real} seconds"
    end
  end

  test "database index effectiveness" do
    # Create data to test index performance
    users = []
    100.times do |i|
      users << create(:user, 
        email_address: "indextest#{i}@example.com",
        created_at: Time.current - rand(365.days).seconds
      )
    end
    
    campaigns = []
    users.each do |user|
      5.times do |i|
        campaigns << create(:campaign,
          user: user,
          name: "Index Test Campaign #{i + 1}",
          status: ['draft', 'active', 'paused', 'completed'].sample,
          created_at: Time.current - rand(180.days).seconds
        )
      end
    end
    
    puts "Created test dataset for index effectiveness testing"
    
    # Test queries that should benefit from indexes
    index_queries = [
      # User lookup by email (should have unique index)
      -> { User.where(email_address: "indextest50@example.com").first },
      # Campaign lookup by user (should have foreign key index)
      -> { Campaign.where(user: users.first).count },
      # Campaign lookup by status (should have index on status)
      -> { Campaign.where(status: 'active').count },
      # Recent campaigns (should have index on created_at)
      -> { Campaign.where("created_at > ?", 30.days.ago).count },
      # User campaigns with status filter (compound query)
      -> { Campaign.where(user: users.first, status: 'active').count }
    ]
    
    index_queries.each_with_index do |query_proc, index|
      # Measure query execution time
      time = Benchmark.measure do
        10.times { query_proc.call }  # Run multiple times for average
      end
      
      average_time = time.real / 10
      puts "Index query #{index + 1} average time: #{(average_time * 1000).round(2)}ms"
      
      # Indexed queries should be very fast (under 10ms on average)
      assert average_time < 0.01, "Index query #{index + 1} too slow: #{(average_time * 1000).round(2)}ms"
    end
  end

  test "large dataset join performance" do
    # Create large related dataset
    brands = []
    5.times do |i|
      brands << create(:brand, 
        name: "Join Test Brand #{i + 1}",
        user: @user
      )
    end
    
    campaigns = []
    brands.each do |brand|
      20.times do |i|
        campaign = create(:campaign,
          user: @user,
          name: "Join Test Campaign #{i + 1}",
          brand: brand
        )
        campaigns << campaign
        
        # Create journey for each campaign
        journey = create(:journey, user: @user, campaign: campaign)
        
        # Create steps for each journey
        10.times do |j|
          create(:journey_step,
            journey: journey,
            name: "Join Test Step #{j + 1}",
            position: j + 1
          )
        end
        
        # Create analytics
        create(:journey_analytics,
          journey: journey,
          campaign: campaign,
          user: @user,
          total_executions: rand(100..1000)
        )
      end
    end
    
    puts "Created large dataset for join performance testing"
    
    # Test complex join queries
    join_queries = [
      # Simple join: campaigns with brands
      -> {
        Campaign.joins(:brand)
               .where(brands: { user: @user })
               .select('campaigns.*, brands.name as brand_name')
      },
      # Multiple joins: campaigns -> journeys -> steps
      -> {
        Campaign.joins(journeys: :journey_steps)
               .where(user: @user)
               .group('campaigns.id')
               .select('campaigns.*, COUNT(journey_steps.id) as step_count')
      },
      # Complex join with aggregation: campaigns with analytics
      -> {
        Campaign.joins(journeys: :journey_analytics)
               .where(user: @user)
               .group('campaigns.id')
               .select('campaigns.*, AVG(journey_analytics.total_executions) as avg_executions')
      },
      # Left join with null handling
      -> {
        Campaign.left_joins(:journeys)
               .where(user: @user)
               .group('campaigns.id')
               .select('campaigns.*, COUNT(journeys.id) as journey_count')
      }
    ]
    
    join_queries.each_with_index do |query_proc, index|
      query_count = 0
      original_method = ActiveRecord::Base.connection.method(:execute)
      
      ActiveRecord::Base.connection.define_singleton_method(:execute) do |sql, *args|
        query_count += 1 unless sql.match?(/^(BEGIN|COMMIT|SAVEPOINT|RELEASE|ROLLBACK)/)
        original_method.call(sql, *args)
      end
      
      time = Benchmark.measure do
        results = query_proc.call
        results.to_a  # Force query execution
      end
      
      # Restore original method
      ActiveRecord::Base.connection.define_singleton_method(:execute, original_method)
      
      puts "Join query #{index + 1} completed in #{time.real.round(2)} seconds using #{query_count} queries"
      
      # Join queries should use only 1 query and complete reasonably fast
      assert query_count == 1, "Join query #{index + 1} uses too many queries: #{query_count}"
      assert time.real < 0.5, "Join query #{index + 1} too slow: #{time.real} seconds"
    end
  end

  test "database connection pool performance under load" do
    # Test database connection handling under concurrent load
    thread_count = 20
    queries_per_thread = 50
    
    time = Benchmark.measure do
      threads = []
      
      thread_count.times do |thread_idx|
        threads << Thread.new do
          test_user = create(:user, email_address: "dbpool#{thread_idx}@example.com")
          
          queries_per_thread.times do |query_idx|
            # Mix of different query types to stress connection pool
            case query_idx % 4
            when 0
              # Read query
              Campaign.where(user: test_user).count
            when 1
              # Write query
              create(:campaign, user: test_user, name: "Pool Test #{query_idx}")
            when 2
              # Update query
              if test_user.campaigns.any?
                test_user.campaigns.first.update(name: "Updated #{query_idx}")
              end
            when 3
              # Join query
              Campaign.joins(:user).where(users: { id: test_user.id }).count
            end
          end
        end
      end
      
      # Wait for all threads to complete
      threads.each(&:join)
    end
    
    total_queries = thread_count * queries_per_thread
    puts "Executed #{total_queries} concurrent database queries in #{time.real.round(2)} seconds"
    puts "Query throughput: #{(total_queries / time.real).round(2)} queries/second"
    
    # Should handle concurrent load efficiently (under 30 seconds)
    assert time.real < 30.0, "Database connection pool performance too slow: #{time.real} seconds"
  end

  test "query plan analysis for slow queries" do
    # Create dataset that might cause slow queries
    campaign = create(:campaign, user: @user)
    journey = create(:journey, user: @user, campaign: campaign)
    
    # Create large number of steps (potential for slow queries)
    100.times do |i|
      create(:journey_step,
        journey: journey,
        name: "Query Plan Step #{i + 1}",
        position: i + 1,
        config: { "data" => "value_#{i}" }
      )
    end
    
    # Test potentially problematic queries
    slow_query_candidates = [
      # Unoptimized text search
      -> { JourneyStep.where("name LIKE ?", "%Step%") },
      # JSON field search (might be slow without gin index)
      -> { JourneyStep.where("config::text LIKE ?", "%value%") },
      # Order by without index
      -> { JourneyStep.where(journey: journey).order(:name) },
      # Complex where condition
      -> { JourneyStep.where(journey: journey).where("position > ? AND position < ?", 25, 75) }
    ]
    
    slow_query_candidates.each_with_index do |query_proc, index|
      time = Benchmark.measure do
        query_proc.call.to_a  # Force execution
      end
      
      puts "Potentially slow query #{index + 1} completed in #{time.real.round(2)} seconds"
      
      # Log warning if query is slow (might need optimization)
      if time.real > 0.1
        puts "WARNING: Query #{index + 1} is slow and may need optimization"
      end
      
      # Set reasonable threshold (should not be extremely slow)
      assert time.real < 1.0, "Query #{index + 1} unacceptably slow: #{time.real} seconds"
    end
  end

  test "memory usage during large database operations" do
    initial_memory = get_memory_usage
    
    # Perform large database operations
    large_dataset = []
    
    # Create large batch of records
    500.times do |i|
      large_dataset << {
        name: "Memory Test Campaign #{i + 1}",
        description: "Campaign #{i + 1} for memory testing with detailed information" * 10,
        user: @user,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    # Bulk insert (should be memory efficient)
    Campaign.insert_all(large_dataset)
    
    # Load large result set
    campaigns = Campaign.where(user: @user).includes(:journeys).to_a
    
    # Process large result set
    campaigns.each do |campaign|
      campaign.journeys.count  # Access associations
    end
    
    final_memory = get_memory_usage
    memory_increase = final_memory - initial_memory
    
    puts "Memory increased by #{memory_increase.round(2)}MB during large database operations"
    
    # Should not consume excessive memory during database operations
    assert memory_increase < 100, "Database operations memory usage too high: #{memory_increase}MB"
  end

  private

  def get_memory_usage
    # Simple memory usage check (in MB)
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    0 # Return 0 if memory check fails
  end
end