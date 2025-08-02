require 'test_helper'

class CampaignPlanningSystemTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @persona = personas(:tech_startup)
    @campaign = campaigns(:product_launch)
  end

  # Campaign Plan Generation Engine Tests
  test "should generate comprehensive campaign plan with LLM integration" do
    mock_llm_response("Strategic campaign plan with 5 phases, targeting early adopters...")
    
    plan_generator = CampaignPlanGenerator.new(@campaign)
    plan = plan_generator.generate_comprehensive_plan
    
    assert_not_nil plan
    assert_includes plan.keys, :strategic_rationale
    assert_includes plan.keys, :target_audience
    assert_includes plan.keys, :messaging_framework
    assert_includes plan.keys, :channel_strategy
    assert_includes plan.keys, :timeline_phases
    assert_includes plan.keys, :success_metrics
    
    # Test strategic rationale structure
    assert plan[:strategic_rationale].is_a?(Hash)
    assert_includes plan[:strategic_rationale].keys, :market_analysis
    assert plan[:timeline_phases].length >= 3
  end

  test "should generate industry-specific B2B campaign template" do
    b2b_campaign = Campaign.create!(
      name: "B2B Enterprise Solution Launch",
      campaign_type: "b2b_lead_generation",
      user: @user,
      persona: @persona
    )
    
    template_engine = IndustryTemplateEngine.new(b2b_campaign)
    template = template_engine.generate_b2b_template
    
    assert_not_nil template
    assert_equal "B2B", template[:industry_type]
    assert_includes template[:channels], "linkedin"
    assert_includes template[:channels], "email"
    assert_includes template[:messaging_themes], "roi"
    assert_includes template[:messaging_themes], "efficiency"
    assert template[:sales_cycle_consideration].present?
  end

  test "should generate industry-specific e-commerce campaign template" do
    ecommerce_campaign = Campaign.create!(
      name: "E-commerce Holiday Sale",
      campaign_type: "seasonal_promotion",
      user: @user,
      persona: @persona
    )
    
    template_engine = IndustryTemplateEngine.new(ecommerce_campaign)
    template = template_engine.generate_ecommerce_template
    
    assert_not_nil template
    assert_equal "E-commerce", template[:industry_type]
    assert_includes template[:channels], "social_media"
    assert_includes template[:channels], "paid_search"
    assert_includes template[:messaging_themes], "urgency"
    assert_includes template[:messaging_themes], "value"
    assert template[:conversion_optimization_tactics].present?
  end

  test "should generate industry-specific SaaS campaign template" do
    saas_campaign = Campaign.create!(
      name: "SaaS Feature Launch",
      campaign_type: "product_launch",
      user: @user,
      persona: @persona
    )
    
    template_engine = IndustryTemplateEngine.new(saas_campaign)
    template = template_engine.generate_saas_template
    
    assert_not_nil template
    assert_equal "SaaS", template[:industry_type]
    assert_includes template[:channels], "product_marketing"
    assert_includes template[:channels], "content_marketing"
    assert_includes template[:messaging_themes], "innovation"
    assert_includes template[:messaging_themes], "productivity"
    assert template[:user_onboarding_considerations].present?
  end

  test "should generate industry-specific events campaign template" do
    events_campaign = Campaign.create!(
      name: "Tech Conference Promotion",
      campaign_type: "event_promotion",
      user: @user,
      persona: @persona
    )
    
    template_engine = IndustryTemplateEngine.new(events_campaign)
    template = template_engine.generate_events_template
    
    assert_not_nil template
    assert_equal "Events", template[:industry_type]
    assert_includes template[:channels], "event_marketing"
    assert_includes template[:channels], "partnerships"
    assert_includes template[:messaging_themes], "networking"
    assert_includes template[:messaging_themes], "learning"
    assert template[:pre_during_post_event_phases].present?
  end

  # Strategic Rationale Framework Tests
  test "should develop strategic rationale with market analysis" do
    rationale_engine = StrategicRationaleEngine.new(@campaign)
    rationale = rationale_engine.develop_market_analysis
    
    assert_not_nil rationale
    assert_includes rationale.keys, :market_size
    assert_includes rationale.keys, :competitive_landscape
    assert_includes rationale.keys, :market_trends
    assert_includes rationale.keys, :opportunity_assessment
    assert_includes rationale.keys, :risk_factors
    
    assert rationale[:market_size][:total_addressable_market].present?
    assert rationale[:competitive_landscape][:direct_competitors].any?
    assert rationale[:opportunity_assessment][:primary_opportunities].any?
  end

  test "should create strategic rationale with customer journey mapping" do
    rationale_engine = StrategicRationaleEngine.new(@campaign)
    customer_journey = rationale_engine.map_customer_journey
    
    assert_not_nil customer_journey
    assert_includes customer_journey.keys, :awareness_stage
    assert_includes customer_journey.keys, :consideration_stage
    assert_includes customer_journey.keys, :decision_stage
    assert_includes customer_journey.keys, :retention_stage
    assert_includes customer_journey.keys, :advocacy_stage
    
    customer_journey.each do |stage, details|
      assert details[:touchpoints].any?
      assert details[:pain_points].any?
      assert details[:messaging_priorities].any?
    end
  end

  # Creative Approach Threading Tests
  test "should thread creative approach across campaign phases" do
    creative_engine = CreativeApproachEngine.new(@campaign)
    creative_thread = creative_engine.thread_across_phases
    
    assert_not_nil creative_thread
    assert_includes creative_thread.keys, :core_creative_concept
    assert_includes creative_thread.keys, :visual_identity
    assert_includes creative_thread.keys, :messaging_hierarchy
    assert_includes creative_thread.keys, :phase_adaptations
    
    assert creative_thread[:core_creative_concept][:main_theme].present?
    assert creative_thread[:visual_identity][:color_palette].any?
    assert creative_thread[:messaging_hierarchy][:primary_message].present?
    assert creative_thread[:phase_adaptations].keys.length >= 3
  end

  test "should ensure creative consistency across channels" do
    creative_engine = CreativeApproachEngine.new(@campaign)
    consistency_framework = creative_engine.ensure_channel_consistency
    
    assert_not_nil consistency_framework
    assert_includes consistency_framework.keys, :channel_adaptations
    assert_includes consistency_framework.keys, :consistent_elements
    assert_includes consistency_framework.keys, :flexible_elements
    assert_includes consistency_framework.keys, :brand_guidelines
    
    consistency_framework[:channel_adaptations].each do |channel, adaptation|
      assert adaptation[:format_requirements].present?
      assert adaptation[:message_adaptation].present?
      assert adaptation[:visual_adaptation].present?
    end
  end

  # Plan Export Functionality Tests
  test "should export campaign plan to PDF format" do
    plan_exporter = CampaignPlanExporter.new(@campaign)
    pdf_content = plan_exporter.export_to_pdf
    
    assert_not_nil pdf_content
    assert pdf_content.is_a?(String)
    assert pdf_content.starts_with?("%PDF")
    
    # Verify PDF contains key sections
    assert_includes pdf_content, "CAMPAIGN OVERVIEW"
    assert_includes pdf_content, "STRATEGIC RATIONALE"
    assert_includes pdf_content, "TARGET AUDIENCE"
    assert_includes pdf_content, "CAMPAIGN TIMELINE"
  end

  test "should export campaign plan to PowerPoint format" do
    plan_exporter = CampaignPlanExporter.new(@campaign)
    pptx_content = plan_exporter.export_to_powerpoint
    
    assert_not_nil pptx_content
    assert pptx_content.is_a?(String)
    
    # Verify PowerPoint contains structured slides
    slides = plan_exporter.generate_slide_structure
    assert_includes slides, :title_slide
    assert_includes slides, :executive_summary
    assert_includes slides, :target_audience
    assert_includes slides, :strategy_overview
    assert_includes slides, :timeline_phases
    assert_includes slides, :success_metrics
    
    assert slides.keys.length >= 6
  end

  test "should export campaign plan with custom branding" do
    brand_settings = {
      logo_url: "https://example.com/logo.png",
      primary_color: "#FF6B35",
      secondary_color: "#F7931E",
      font_family: "Helvetica"
    }
    
    plan_exporter = CampaignPlanExporter.new(@campaign, brand_settings)
    branded_export = plan_exporter.export_with_branding(:pdf)
    
    assert_not_nil branded_export
    assert_includes branded_export[:metadata], :brand_applied
    assert_equal brand_settings[:primary_color], branded_export[:metadata][:primary_color]
  end

  # Revision Tracking Tests
  test "should track campaign plan revisions" do
    plan_revision_tracker = CampaignPlanRevisionTracker.new(@campaign)
    
    # Create initial version
    initial_plan = { strategic_rationale: "Initial approach", version: 1.0 }
    plan_revision_tracker.save_revision(initial_plan, @user)
    
    # Create revised version
    revised_plan = { strategic_rationale: "Revised approach", version: 1.1 }
    plan_revision_tracker.save_revision(revised_plan, @user)
    
    revisions = plan_revision_tracker.get_revision_history
    assert_equal 3, revisions.length
    
    latest_revision = plan_revision_tracker.get_latest_revision
    assert_equal 1.1, latest_revision[:version].to_f
    assert_equal "Revised approach", latest_revision[:strategic_rationale]
  end

  test "should compare campaign plan revisions" do
    plan_revision_tracker = CampaignPlanRevisionTracker.new(@campaign)
    
    version_1 = { strategic_rationale: { rationale: "Original approach" }, success_metrics: { leads: 100 } }
    version_2 = { strategic_rationale: { rationale: "Updated approach" }, success_metrics: { leads: 200 } }
    
    plan_revision_tracker.save_revision(version_1, @user)
    plan_revision_tracker.save_revision(version_2, @user)
    
    comparison = plan_revision_tracker.compare_revisions(1.0, 1.1)
    
    assert_not_nil comparison
    assert_includes comparison[:changes], "strategic_rationale"
    assert_includes comparison[:changes], "success_metrics"
    assert_equal({ rationale: "Original approach" }, comparison[:changes]["strategic_rationale"][:from])
    assert_equal({ rationale: "Updated approach" }, comparison[:changes]["strategic_rationale"][:to])
  end

  test "should rollback to previous campaign plan revision" do
    plan_revision_tracker = CampaignPlanRevisionTracker.new(@campaign)
    
    version_1 = { strategic_rationale: { rationale: "Original strategy" } }
    version_2 = { strategic_rationale: { rationale: "Failed strategy" } }
    
    plan_revision_tracker.save_revision(version_1, @user)
    plan_revision_tracker.save_revision(version_2, @user)
    
    rollback_result = plan_revision_tracker.rollback_to_revision(1.0, @user)
    
    assert rollback_result[:success]
    current_plan = plan_revision_tracker.get_current_plan
    assert_equal({ rationale: "Original strategy" }, current_plan[:strategy])
  end

  # Collaborative Commenting Tests
  test "should add comments to campaign plan sections" do
    commenting_system = CampaignPlanCommentingSystem.new(@campaign)
    
    comment = commenting_system.add_comment(
      section: "strategic_rationale",
      content: "This section needs more market research",
      user: @user,
      line_number: 15
    )
    
    assert_not_nil comment
    assert_equal "strategic_rationale", comment[:section]
    assert_equal @user.id, comment[:user_id]
    assert comment[:timestamp].present?
    assert_equal 15, comment[:line_number]
  end

  test "should thread comment discussions on campaign plans" do
    commenting_system = CampaignPlanCommentingSystem.new(@campaign)
    
    parent_comment = commenting_system.add_comment(
      section: "messaging_framework",
      content: "Should we focus more on benefits?",
      user: @user
    )
    
    reply_comment = commenting_system.reply_to_comment(
      parent_comment_id: parent_comment[:id],
      content: "Yes, let's emphasize ROI benefits",
      user: users(:two)
    )
    
    thread = commenting_system.get_comment_thread(parent_comment[:id])
    assert_equal 2, thread.length
    assert_equal parent_comment[:id], reply_comment[:parent_comment_id]
  end

  test "should resolve campaign plan comments" do
    commenting_system = CampaignPlanCommentingSystem.new(@campaign)
    
    comment = commenting_system.add_comment(
      section: "timeline",
      content: "Timeline seems too aggressive",
      user: @user
    )
    
    resolution = commenting_system.resolve_comment(comment[:id], @user)
    
    assert resolution[:success]
    resolved_comment = commenting_system.get_comment(comment[:id])
    assert resolved_comment[:resolved]
    assert_equal @user.id, resolved_comment[:resolved_by]
  end

  # Approval Workflows Tests
  test "should create approval workflow for campaign plan" do
    approval_workflow = CampaignApprovalWorkflow.new(@campaign)
    
    workflow = approval_workflow.create_workflow([
      { role: "marketing_manager", user_id: users(:marketing_manager).id },
      { role: "creative_director", user_id: users(:creative_director).id },
      { role: "campaign_director", user_id: users(:campaign_director).id }
    ])
    
    assert_not_nil workflow
    assert_equal 3, workflow[:approval_steps].length
    assert_equal "pending", workflow[:status]
    assert_equal users(:marketing_manager).id, workflow[:current_approver_id]
  end

  test "should process approval workflow steps" do
    approval_workflow = CampaignApprovalWorkflow.new(@campaign)
    
    workflow = approval_workflow.create_workflow([
      { role: "marketing_manager", user_id: users(:marketing_manager).id },
      { role: "creative_director", user_id: users(:creative_director).id }
    ])
    
    # First approval
    step_1_result = approval_workflow.approve_step(
      workflow[:id],
      users(:marketing_manager),
      "Looks good, approved"
    )
    
    assert step_1_result[:success]
    updated_workflow = approval_workflow.get_workflow(workflow[:id])
    assert_equal users(:creative_director).id, updated_workflow[:current_approver_id]
    
    # Final approval
    step_2_result = approval_workflow.approve_step(
      workflow[:id],
      users(:creative_director),
      "Final approval granted"
    )
    
    assert step_2_result[:success]
    final_workflow = approval_workflow.get_workflow(workflow[:id])
    assert_equal "approved", final_workflow[:status]
  end

  test "should handle approval workflow rejections" do
    approval_workflow = CampaignApprovalWorkflow.new(@campaign)
    
    workflow = approval_workflow.create_workflow([
      { role: "marketing_manager", user_id: users(:marketing_manager).id }
    ])
    
    rejection_result = approval_workflow.reject_step(
      workflow[:id],
      users(:marketing_manager),
      "Budget allocation needs revision"
    )
    
    assert rejection_result[:success]
    rejected_workflow = approval_workflow.get_workflow(workflow[:id])
    assert_equal "rejected", rejected_workflow[:status]
    assert_includes rejected_workflow[:rejection_reason], "Budget allocation"
  end

  # Notification System Tests
  test "should send approval workflow notifications" do
    notification_system = CampaignApprovalNotificationSystem.new(@campaign)
    
    assert_emails 1 do
      notification_system.notify_approval_request(
        users(:marketing_manager),
        workflow_id: 123,
        campaign_name: @campaign.name
      )
    end
    
    email = ActionMailer::Base.deliveries.last
    assert_equal users(:marketing_manager).email_address, email.to.first
    assert_includes email.subject, "Approval Request"
    assert_includes email.body.to_s, @campaign.name
  end

  test "should send approval status change notifications" do
    notification_system = CampaignApprovalNotificationSystem.new(@campaign)
    
    assert_emails 1 do
      notification_system.notify_approval_status_change(
        @user,
        status: "approved",
        workflow_id: 123,
        approver: users(:marketing_manager)
      )
    end
    
    email = ActionMailer::Base.deliveries.last
    assert_includes email.subject, "Campaign Plan Approved"
  end

  test "should send deadline reminder notifications" do
    notification_system = CampaignApprovalNotificationSystem.new(@campaign)
    
    assert_emails 1 do
      notification_system.notify_deadline_reminder(
        users(:marketing_manager),
        workflow_id: 123,
        days_remaining: 2
      )
    end
    
    email = ActionMailer::Base.deliveries.last
    assert_includes email.body.to_s, "2 days remaining"
  end

  private

  def create_test_campaign_plan
    {
      strategic_rationale: "Market research shows strong demand",
      target_audience: "Tech-savvy professionals aged 25-40",
      messaging_framework: "Innovation meets practicality",
      channel_strategy: ["email", "social_media", "content_marketing"],
      timeline_phases: [
        { phase: "awareness", duration: 30, activities: ["content creation", "social media"] },
        { phase: "consideration", duration: 45, activities: ["webinars", "demos"] },
        { phase: "conversion", duration: 30, activities: ["sales outreach", "special offers"] }
      ],
      success_metrics: {
        awareness: { reach: 100000, engagement_rate: 5.5 },
        consideration: { leads_generated: 500, mql_conversion: 30 },
        conversion: { sales_qualified_leads: 150, close_rate: 20 }
      }
    }
  end
end