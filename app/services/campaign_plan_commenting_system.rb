class CampaignPlanCommentingSystem
  def initialize(campaign)
    @campaign = campaign
  end

  def add_comment(section:, content:, user:, **options)
    campaign_plan = @campaign.campaign_plans.first

    # Create a campaign plan if none exists
    unless campaign_plan
      campaign_plan = @campaign.campaign_plans.create!(
        name: "#{@campaign.name} Plan",
        user: user,
        strategic_rationale: { "rationale" => "Strategic rationale to be developed" },
        target_audience: { "audience" => "Target audience to be defined" },
        messaging_framework: { "framework" => "Messaging framework to be created" },
        channel_strategy: [ "email", "social_media" ],
        timeline_phases: [ { "phase" => "Planning", "duration" => 4 } ],
        success_metrics: { "leads" => 100, "awareness" => 10 }
      )
    end

    comment = campaign_plan.plan_comments.create!(
      section: section,
      content: content,
      user: user,
      comment_type: options[:comment_type] || "general",
      priority: options[:priority] || "low",
      line_number: options[:line_number],
      metadata: options[:metadata] || {}
    )

    {
      id: comment.id,
      section: comment.section,
      content: comment.content,
      user_id: comment.user.id,
      timestamp: comment.created_at,
      line_number: comment.line_number,
      comment_type: comment.comment_type,
      priority: comment.priority
    }
  end

  def reply_to_comment(parent_comment_id:, content:, user:, **options)
    parent_comment = PlanComment.find_by(id: parent_comment_id)
    return { success: false, error: "Parent comment not found" } unless parent_comment

    reply = parent_comment.reply(
      content: content,
      user: user,
      comment_type: options[:comment_type] || "general",
      priority: options[:priority] || "low",
      metadata: options[:metadata] || {}
    )

    {
      id: reply.id,
      parent_comment_id: reply.parent_comment_id,
      section: reply.section,
      content: reply.content,
      user_id: reply.user.id,
      timestamp: reply.created_at,
      comment_type: reply.comment_type,
      priority: reply.priority
    }
  end

  def resolve_comment(comment_id, user)
    comment = PlanComment.find_by(id: comment_id)
    return { success: false, error: "Comment not found" } unless comment

    begin
      comment.resolve!(user)
      { success: true, message: "Comment resolved successfully" }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def get_comment_thread(comment_id)
    comment = PlanComment.find_by(id: comment_id)
    return [] unless comment

    thread = comment.thread
    thread.map do |c|
      {
        id: c.id,
        parent_comment_id: c.parent_comment_id,
        content: c.content,
        user: c.user.display_name,
        created_at: c.created_at,
        resolved: c.resolved,
        priority: c.priority,
        comment_type: c.comment_type
      }
    end
  end

  def get_comment(comment_id)
    comment = PlanComment.find_by(id: comment_id)
    return nil unless comment

    {
      id: comment.id,
      section: comment.section,
      content: comment.content,
      user: comment.user.display_name,
      created_at: comment.created_at,
      resolved: comment.resolved,
      resolved_by: comment.resolved_by_user&.id,
      resolved_at: comment.resolved_at,
      priority: comment.priority,
      comment_type: comment.comment_type,
      line_number: comment.line_number
    }
  end

  def get_comments_by_section(section)
    campaign_plan = @campaign.campaign_plans.first
    return [] unless campaign_plan

    campaign_plan.plan_comments.by_section(section).includes(:user, :resolved_by_user).map do |comment|
      {
        id: comment.id,
        content: comment.content,
        user: comment.user.display_name,
        created_at: comment.created_at,
        resolved: comment.resolved,
        priority: comment.priority,
        comment_type: comment.comment_type,
        line_number: comment.line_number,
        replies_count: comment.replies.count
      }
    end
  end

  def get_unresolved_comments
    campaign_plan = @campaign.campaign_plans.first
    return [] unless campaign_plan

    campaign_plan.plan_comments.unresolved.includes(:user).map do |comment|
      {
        id: comment.id,
        section: comment.section,
        content: comment.content.truncate(100),
        user: comment.user.display_name,
        created_at: comment.created_at,
        priority: comment.priority,
        comment_type: comment.comment_type,
        age_days: comment.age_in_days,
        stale: comment.stale?
      }
    end
  end

  def get_comments_summary
    campaign_plan = @campaign.campaign_plans.first
    return default_summary unless campaign_plan

    comments = campaign_plan.plan_comments

    {
      total_comments: comments.count,
      unresolved_comments: comments.unresolved.count,
      resolved_comments: comments.resolved.count,
      high_priority_comments: comments.by_priority("high").count + comments.by_priority("critical").count,
      comments_by_section: comments.group(:section).count,
      recent_activity: comments.where("created_at > ?", 7.days.ago).count,
      stale_comments: comments.unresolved.select(&:stale?).length
    }
  end

  private

  def default_summary
    {
      total_comments: 0,
      unresolved_comments: 0,
      resolved_comments: 0,
      high_priority_comments: 0,
      comments_by_section: {},
      recent_activity: 0,
      stale_comments: 0
    }
  end
end
