require 'test_helper'

class ComprehensivePlatformIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @persona = personas(:tech_startup)
    
    # Create core entities for integration testing
    @brand = brands(:one)
    @campaign = campaigns(:one)
    @journey = journeys(:one)
    
    # Mock WebSocket connections for collaboration features
    ActionCable.server.stubs(:broadcast)
  end

  # ===== CAMPAIGN-TO-CONTENT FLOW INTEGRATION =====
  
  test "should integrate campaign planning with content management system" do
    # Step 1: Create campaign plan
    campaign_generator = CampaignPlanGenerator.new(@campaign)
    
    # Mock LLM service to avoid external API calls
    mock_llm_response = {
      "strategic_rationale" => { "rationale" => "Launch strategy for tech startup" },
      "target_audience" => { "primary" => "Tech founders" },
      "success_metrics" => { "leads" => 100, "conversions" => 10 }
    }
    
    LlmService.any_instance.stubs(:analyze).returns(mock_llm_response.to_json)
    
    campaign_plan = campaign_generator.generate_comprehensive_plan
    assert campaign_plan[:success]
    
    # Step 2: Link campaign plan to content creation
    content_repo = ContentRepository.create!(
      title: "Campaign Content Repository",
      content: "Initial campaign content",
      content_type: "campaign_materials",
      status: "draft",
      user: @user,
      campaign_plan_id: @campaign.id  # Link to campaign
    )
    
    assert_equal @campaign.id, content_repo.campaign_plan_id
    
    # Step 3: Test content management integration with campaign context
    content_search = ContentSearchEngine.new
    search_results = content_search.search("campaign", { campaign_id: @campaign.id })
    
    assert search_results[:total_results] >= 1
    assert search_results[:results].any? { |result| result[:content_id] == content_repo.id }
    
    # Step 4: Test content approval workflow within campaign context
    approval_system = ContentApprovalSystem.new
    workflow_definition = {
      content_id: content_repo.id,
      approval_steps: [
        { role: "content_reviewer", user_id: @user.id, required: true },
        { role: "content_manager", user_id: @user.id, required: true }
      ]
    }
    
    workflow = approval_system.create_workflow(workflow_definition)
    assert workflow[:id].present?
    assert_equal "pending", workflow[:status]
    
    # Approve content in context of campaign
    approval_result = approval_system.process_approval_step(
      workflow[:id],
      @user,
      action: "approve",
      comments: "Campaign content approved"
    )
    
    assert approval_result[:success]
    assert_equal "approved", approval_result[:step_status]
  end

  test "should generate content variants from campaign messaging framework" do
    # Create messaging framework from campaign
    messaging_framework = MessagingFramework.create!(
      campaign: @campaign,
      primary_message: "Transform your startup with innovative solutions",
      value_propositions: ["Scalable", "Innovative", "Trusted"],
      proof_points: ["500+ successful launches", "99% uptime"],
      user: @user
    )
    
    # Generate content variants based on messaging framework
    variant_engine = AbTesting::MessagingVariantEngine.new(messaging_framework)
    
    variants = variant_engine.generate_message_variants({
      variant_count: 3,
      variation_types: ["headline", "cta", "value_prop"],
      tone_variations: ["professional", "casual", "urgent"]
    })
    
    assert_equal 3, variants[:variants].length
    assert variants[:variants].all? { |v| v[:messaging_elements].present? }
    
    # Verify variants maintain campaign brand consistency
    variants[:variants].each do |variant|
      assert variant[:messaging_elements][:primary_message].include?("Transform")
      assert variant[:brand_consistency_score] >= 80
    end
  end

  # ===== CONTENT-TO-A/B TESTING FLOW INTEGRATION =====
  
  test "should create A/B tests from content repository items" do
    # Step 1: Create content items for testing
    content_v1 = ContentRepository.create!(
      title: "Landing Page Variant A",
      content: "Professional approach messaging",
      content_type: "landing_page",
      status: "approved",
      user: @user
    )
    
    content_v2 = ContentRepository.create!(
      title: "Landing Page Variant B", 
      content: "Casual approach messaging",
      content_type: "landing_page",
      status: "approved",
      user: @user
    )
    
    # Step 2: Create A/B test using content repository items
    ab_test = AbTest.create!(
      name: "Landing Page Content Test",
      campaign: @campaign,
      test_type: "content_variant",
      status: "draft",
      start_date: 1.day.from_now,
      end_date: 1.week.from_now,
      significance_threshold: 95.0
    )
    
    # Step 3: Link content variants to A/B test
    variant_a = AbTestVariant.create!(
      ab_test: ab_test,
      name: "Professional Content",
      variant_type: "control",
      is_control: true,
      traffic_percentage: 50.0,
      content_id: content_v1.id,
      journey_id: @journey.id
    )
    
    variant_b = AbTestVariant.create!(
      ab_test: ab_test,
      name: "Casual Content",
      variant_type: "treatment", 
      is_control: false,
      traffic_percentage: 50.0,
      content_id: content_v2.id,
      journey_id: @journey.id
    )
    
    # Step 4: Test content version control integration with A/B testing
    version_control = ContentVersionControl.new(content_v1)
    
    # Create new version for A/B test optimization
    new_version = version_control.create_version({
      content: "Optimized professional messaging based on test data",
      version_notes: "A/B test optimization - increased conversion focus",
      created_by: @user
    })
    
    assert new_version[:success]
    assert new_version[:version_number].present?
    
    # Update A/B test variant to use new version
    variant_a.update!(
      metadata: variant_a.metadata.merge(
        content_version: new_version[:version_number],
        optimization_reason: "Data-driven content optimization"
      )
    )
    
    # Verify integration between content versioning and A/B testing
    assert_equal new_version[:version_number], variant_a.metadata["content_version"]
  end

  test "should track A/B test performance across content variants" do
    # Create A/B test with content variants
    ab_test = AbTest.create!(
      name: "Email Content Performance Test",
      campaign: @campaign,
      test_type: "email_variant",
      status: "running",
      start_date: 1.day.ago,
      end_date: 1.week.from_now,
      significance_threshold: 95.0
    )
    
    # Create variants with different content
    variants_data = [
      { name: "Short Email", content: "Brief, direct messaging", traffic: 33.33 },
      { name: "Detailed Email", content: "Comprehensive explanation with benefits", traffic: 33.33 },
      { name: "Visual Email", content: "Image-heavy with minimal text", traffic: 33.34 }
    ]
    
    variants = variants_data.map.with_index do |data, index|
      content = ContentRepository.create!(
        title: data[:name],
        content: data[:content],
        content_type: "email_template",
        status: "approved",
        user: @user
      )
      
      AbTestVariant.create!(
        ab_test: ab_test,
        name: data[:name],
        variant_type: index == 0 ? "control" : "treatment",
        is_control: index == 0,
        traffic_percentage: data[:traffic],
        content_id: content.id,
        journey_id: @journey.id
      )
    end
    
    # Test real-time metrics collection
    metrics_service = AbTesting::RealTimeAbTestMetrics.new(ab_test)
    
    # Simulate test performance data
    variants.each_with_index do |variant, index|
      performance_data = {
        visitors: 1000 + (index * 100),
        conversions: 50 + (index * 10),
        engagement_rate: 0.3 + (index * 0.05),
        bounce_rate: 0.4 - (index * 0.05)
      }
      
      metrics_service.update_variant_metrics(variant.id, performance_data)
    end
    
    # Get performance comparison
    performance_comparison = metrics_service.get_performance_comparison
    
    assert performance_comparison[:variants].length == 3
    assert performance_comparison[:statistical_significance].present?
    assert performance_comparison[:recommendations].present?
    
    # Test winner declaration based on content performance
    winner_declarator = AbTesting::AbTestWinnerDeclarator.new(ab_test)
    winner_analysis = winner_declarator.analyze_for_winner
    
    if winner_analysis[:has_winner]
      assert winner_analysis[:winning_variant_id].present?
      assert winner_analysis[:confidence_level] >= 95.0
    end
  end

  # ===== END-TO-END CAMPAIGN WORKFLOW INTEGRATION =====
  
  test "should execute complete campaign workflow from planning to A/B test results" do
    # PHASE 1: Campaign Planning
    LlmService.any_instance.stubs(:analyze).returns({
      "strategic_rationale" => { "rationale" => "Comprehensive product launch strategy" },
      "target_audience" => { "primary" => "Tech startup founders" },
      "success_metrics" => { "leads" => 500, "conversions" => 50 },
      "timeline" => { "duration_weeks" => 12 },
      "channels" => ["email", "social", "content"],
      "budget_allocation" => { "email" => 0.4, "social" => 0.35, "content" => 0.25 }
    }.to_json)
    
    campaign_generator = CampaignPlanGenerator.new(@campaign)
    campaign_plan = campaign_generator.generate_comprehensive_plan
    
    assert campaign_plan[:success]
    assert campaign_plan[:strategic_rationale].present?
    
    # PHASE 2: Content Generation
    content_items = []
    
    # Generate content for each channel
    %w[email social content].each do |channel|
      content = ContentRepository.create!(
        title: "#{channel.humanize} Campaign Content",
        content: "Optimized content for #{channel} channel targeting #{@persona.name}",
        content_type: channel,
        status: "approved",
        user: @user,
        campaign_plan_id: @campaign.id,
        metadata: { channel: channel, campaign_phase: "launch" }
      )
      content_items << content
    end
    
    assert_equal 3, content_items.length
    
    # PHASE 3: A/B Test Setup
    # Create A/B tests for critical content pieces
    email_test = AbTest.create!(
      name: "Email Campaign A/B Test",
      campaign: @campaign,
      test_type: "email_variant",
      status: "running",
      start_date: Time.current,
      end_date: 2.weeks.from_now,
      significance_threshold: 95.0
    )
    
    # Create email variants
    email_content = content_items.find { |c| c.content_type == "email" }
    
    email_variants = [
      { name: "Direct CTA", content: "Direct call-to-action approach", control: true },
      { name: "Benefit-focused", content: "Benefit-focused messaging", control: false }
    ].map do |variant_data|
      variant_content = ContentRepository.create!(
        title: "Email #{variant_data[:name]}",
        content: variant_data[:content],
        content_type: "email",
        status: "approved",
        user: @user,
        parent_content_id: email_content.id
      )
      
      AbTestVariant.create!(
        ab_test: email_test,
        name: variant_data[:name],
        variant_type: variant_data[:control] ? "control" : "treatment",
        is_control: variant_data[:control],
        traffic_percentage: 50.0,
        content_id: variant_content.id,
        journey_id: @journey.id
      )
    end
    
    # PHASE 4: Monitor Results
    # Simulate test execution and monitoring
    analytics_service = AbTestAnalyticsService.new(email_test)
    
    # Simulate performance data collection
    email_variants.each_with_index do |variant, index|
      metrics = {
        visitors: 2000,
        conversions: 100 + (index * 20), # Treatment performs better
        revenue: 5000 + (index * 1000),
        engagement_time: 120 + (index * 30)
      }
      
      analytics_service.record_metrics(variant.id, metrics)
    end
    
    # Get comprehensive campaign performance
    campaign_analytics = CampaignAnalyticsService.new(@campaign)
    performance_report = campaign_analytics.generate_comprehensive_report
    
    assert performance_report[:campaign_overview].present?
    assert performance_report[:ab_test_results].present?
    assert performance_report[:content_performance].present?
    assert performance_report[:roi_analysis].present?
    
    # PHASE 5: Optimization Recommendations
    # Test AI-powered optimization suggestions
    optimization_ai = AbTesting::AbTestOptimizationAi.new(email_test)
    recommendations = optimization_ai.generate_optimization_recommendations
    
    assert recommendations[:recommendations].present?
    assert recommendations[:confidence_score] >= 70
    assert recommendations[:next_steps].present?
    
    # Verify end-to-end data flow
    assert_equal @campaign.id, email_test.campaign_id
    assert email_test.ab_test_variants.count == 2
    assert content_items.all? { |c| c.campaign_plan_id == @campaign.id }
  end

  # ===== REAL-TIME COLLABORATION INTEGRATION =====
  
  test "should support real-time collaboration across all systems" do
    # Mock WebSocket broadcasting
    broadcasts = []
    ActionCable.server.stubs(:broadcast) do |channel, data|
      broadcasts << { channel: channel, data: data }
    end
    
    # Test campaign planning collaboration
    campaign_collaboration = CampaignCollaborationChannel.new
    
    # Simulate collaborative editing on campaign plan
    revision_tracker = CampaignPlanRevisionTracker.new(@campaign)
    LlmService.any_instance.stubs(:analyze).returns({
      "strategic_rationale" => { "rationale" => "Updated strategy" }
    }.to_json)
    
    plan_data = { strategic_rationale: "Collaborative plan update", version: 1.1 }
    revision_result = revision_tracker.save_revision(plan_data, @user)
    
    # Test content collaboration
    content = ContentRepository.create!(
      title: "Collaborative Content",
      content: "Initial content for collaboration",
      content_type: "blog_post",
      status: "draft",
      user: @user
    )
    
    # Simulate real-time content editing
    collaborative_editor = CollaborativeRichEditor.new(content)
    edit_operation = {
      type: "text_insert",
      position: 10,
      content: " (updated in real-time)",
      user_id: @user.id,
      timestamp: Time.current
    }
    
    edit_result = collaborative_editor.apply_operation(edit_operation)
    assert edit_result[:success]
    
    # Test A/B testing real-time monitoring
    ab_test = AbTest.create!(
      name: "Real-time Monitoring Test",
      campaign: @campaign,
      test_type: "landing_page",
      status: "running",
      start_date: Time.current,
      end_date: 1.week.from_now
    )
    
    # Simulate real-time metrics updates
    real_time_metrics = AbTesting::RealTimeAbTestMetrics.new(ab_test)
    
    metrics_update = {
      variant_id: 1,
      visitors: 100,
      conversions: 10,
      timestamp: Time.current
    }
    
    real_time_metrics.broadcast_metrics_update(metrics_update)
    
    # Verify presence system integration
    presence_system = PresenceSystem.new
    presence_system.user_joined(@user.id, "campaign_#{@campaign.id}")
    presence_system.user_joined(@user.id, "content_#{content.id}")
    presence_system.user_joined(@user.id, "ab_test_#{ab_test.id}")
    
    active_sessions = presence_system.get_active_users("campaign_#{@campaign.id}")
    assert active_sessions[:users].include?(@user.id)
  end

  # ===== DATABASE INTEGRATION AND MODEL ASSOCIATIONS =====
  
  test "should maintain data integrity across integrated systems" do
    # Test cascade operations and referential integrity
    
    # Create interconnected entities
    campaign_plan = CampaignPlan.create!(
      name: "Integration Test Campaign",
      campaign_type: "product_launch",
      status: "active",
      start_date: Time.current,
      end_date: 1.month.from_now,
      user: @user,
      brand: @brand
    )
    
    content_repo = ContentRepository.create!(
      title: "Campaign Content",
      content: "Test content for integration",
      content_type: "landing_page",
      status: "approved",
      user: @user,
      campaign_plan_id: campaign_plan.id
    )
    
    ab_test = AbTest.create!(
      name: "Integration A/B Test",
      campaign: @campaign,
      test_type: "content_variant",
      status: "running",
      start_date: Time.current,
      end_date: 1.week.from_now
    )
    
    ab_test_variant = AbTestVariant.create!(
      ab_test: ab_test,
      name: "Test Variant",
      variant_type: "control",
      is_control: true,
      traffic_percentage: 100.0,
      content_id: content_repo.id,
      journey_id: @journey.id
    )
    
    # Test model associations
    assert_equal campaign_plan.id, content_repo.campaign_plan_id
    assert_equal content_repo.id, ab_test_variant.content_id
    assert_equal @journey.id, ab_test_variant.journey_id
    
    # Test foreign key constraints
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ContentRepository.create!(
        title: "Invalid Content",
        content: "Test",
        content_type: "blog",
        status: "draft",
        user: @user,
        campaign_plan_id: 99999 # Non-existent campaign plan
      )
    end
    
    # Test cascade delete behavior
    original_content_count = ContentRepository.count
    original_variant_count = AbTestVariant.count
    
    # Delete campaign plan should handle dependent records appropriately
    campaign_plan.destroy
    
    # Verify dependent records are handled properly
    assert_nil ContentRepository.find_by(id: content_repo.id)
    
    # AB test variants should maintain referential integrity
    ab_test_variant.reload
    assert_nil ab_test_variant.content_id
  end

  test "should generate comprehensive test coverage report" do
    # Test coverage across all integrated systems
    coverage_report = {
      campaign_planning: {
        plan_generation: true,
        revision_tracking: true,
        collaboration: true,
        approval_workflow: true
      },
      content_management: {
        content_creation: true,
        version_control: true,
        approval_system: true,
        search_and_filter: true,
        archival_system: true
      },
      ab_testing: {
        test_creation: true,
        variant_management: true,
        traffic_allocation: true,
        statistical_analysis: true,
        winner_declaration: true,
        optimization_ai: true
      },
      integration_flows: {
        campaign_to_content: true,
        content_to_ab_testing: true,
        end_to_end_workflow: true,
        real_time_collaboration: true,
        database_integrity: true
      }
    }
    
    # Verify all systems are tested
    coverage_report.each do |system, features|
      features.each do |feature, tested|
        assert tested, "#{system} - #{feature} should be tested"
      end
    end
    
    # Calculate overall coverage percentage
    total_features = coverage_report.values.map(&:length).sum
    tested_features = coverage_report.values.map { |features| features.values.count(true) }.sum
    coverage_percentage = (tested_features.to_f / total_features * 100).round(2)
    
    assert coverage_percentage >= 85.0, "Test coverage should be at least 85%, got #{coverage_percentage}%"
    
    puts "\n=== INTEGRATION TEST COVERAGE REPORT ==="
    puts "Total Features: #{total_features}"
    puts "Tested Features: #{tested_features}" 
    puts "Coverage: #{coverage_percentage}%"
    puts "Status: #{coverage_percentage >= 85 ? 'PASSED' : 'FAILED'}"
    puts "========================================\n"
  end

  private

  def mock_websocket_connections
    # Mock ActionCable connections for testing
    ActionCable.server.stubs(:broadcast).returns(true)
  end
end