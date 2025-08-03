module ApplicationHelper
  # Navigation helper methods
  def nav_link_classes(active = false)
    base_classes = "nav-link inline-flex items-center px-3 py-2 text-sm font-medium rounded-lg transition-colors focus-visible:outline-2 focus-visible:outline-blue-600 focus-visible:outline-offset-2"
    
    if active
      "#{base_classes} bg-blue-50 text-blue-700 border-blue-200"
    else
      "#{base_classes} text-secondary hover:text-primary hover:bg-gray-50"
    end
  end
  
  def mobile_nav_link_classes(active = false)
    base_classes = "mobile-nav-link flex items-center px-3 py-2 text-sm font-medium rounded-lg transition-colors"
    
    if active
      "#{base_classes} bg-blue-50 text-blue-700"
    else
      "#{base_classes} text-secondary hover:text-primary hover:bg-gray-50"
    end
  end
  
  # Dashboard utility methods
  def dashboard_widget_classes(size: 'default', collapsible: false)
    base_classes = "dashboard-widget bg-white rounded-xl border border-gray-200 shadow-sm hover:shadow-md transition-shadow duration-200"
    
    size_classes = case size
    when 'small'
      'col-span-1 row-span-1'
    when 'medium'
      'col-span-1 md:col-span-2 row-span-1'
    when 'large'
      'col-span-1 md:col-span-2 lg:col-span-3 row-span-2'
    when 'full'
      'col-span-full row-span-1'
    else
      'col-span-1 md:col-span-1 row-span-1'
    end
    
    collapsible_classes = collapsible ? 'collapsible-widget' : ''
    
    "#{base_classes} #{size_classes} #{collapsible_classes}".strip
  end
  
  # Format numbers for dashboard display
  def format_metric(value, type: :number, precision: 0)
    return 'N/A' if value.nil?
    
    case type
    when :currency
      number_to_currency(value, precision: precision)
    when :percentage
      number_to_percentage(value, precision: precision)
    when :human
      number_to_human(value, precision: precision)
    else
      number_with_delimiter(value)
    end
  end
  
  # Generate trend indicator
  def trend_indicator(current, previous, format: :percentage)
    return content_tag(:span, 'N/A', class: 'text-muted text-sm') if current.nil? || previous.nil? || previous.zero?
    
    change = ((current - previous) / previous.to_f) * 100
    trend_class = change >= 0 ? 'text-success' : 'text-error'
    arrow = change >= 0 ? '↗' : '↘'
    
    formatted_change = case format
    when :percentage
      "#{change.abs.round(1)}%"
    when :number
      number_with_delimiter(change.abs.round)
    else
      change.abs.round(2).to_s
    end
    
    content_tag(:span, class: "trend-indicator #{trend_class} text-sm font-medium") do
      "#{arrow} #{formatted_change}"
    end
  end
  
  # Time-based greeting
  def time_based_greeting
    hour = Time.current.hour
    
    case hour
    when 5..11
      "Good morning"
    when 12..17
      "Good afternoon"
    when 18..21
      "Good evening"
    else
      "Good night"
    end
  end

  # Campaign status styling helpers
  def campaign_status_classes(status)
    case status&.to_s
    when 'active'
      'bg-green-100 text-green-800'
    when 'draft'
      'bg-gray-100 text-gray-800'
    when 'paused'
      'bg-yellow-100 text-yellow-800'
    when 'completed'
      'bg-blue-100 text-blue-800'
    when 'archived'
      'bg-purple-100 text-purple-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end

  def campaign_status_icon(status)
    case status&.to_s
    when 'active'
      content_tag(:svg, class: 'w-3 h-3 mr-1', fill: 'currentColor', viewBox: '0 0 20 20', 'aria-hidden': 'true') do
        content_tag(:path, '', 'fill-rule': 'evenodd', d: 'M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z', 'clip-rule': 'evenodd')
      end
    when 'draft'
      content_tag(:svg, class: 'w-3 h-3 mr-1', fill: 'currentColor', viewBox: '0 0 20 20', 'aria-hidden': 'true') do
        content_tag(:path, '', 'fill-rule': 'evenodd', d: 'M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z', 'clip-rule': 'evenodd')
      end
    when 'paused'
      content_tag(:svg, class: 'w-3 h-3 mr-1', fill: 'currentColor', viewBox: '0 0 20 20', 'aria-hidden': 'true') do
        content_tag(:path, '', 'fill-rule': 'evenodd', d: 'M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z', 'clip-rule': 'evenodd')
      end
    when 'completed'
      content_tag(:svg, class: 'w-3 h-3 mr-1', fill: 'currentColor', viewBox: '0 0 20 20', 'aria-hidden': 'true') do
        content_tag(:path, '', 'fill-rule': 'evenodd', d: 'M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z', 'clip-rule': 'evenodd')
      end
    when 'archived'
      content_tag(:svg, class: 'w-3 h-3 mr-1', fill: 'currentColor', viewBox: '0 0 20 20', 'aria-hidden': 'true') do
        content_tag(:path, '', d: 'M4 3a2 2 0 100 4h12a2 2 0 100-4H4z')
        content_tag(:path, '', 'fill-rule': 'evenodd', d: 'M3 8h14v7a2 2 0 01-2 2H5a2 2 0 01-2-2V8zm5 3a1 1 0 011-1h2a1 1 0 110 2H9a1 1 0 01-1-1z', 'clip-rule': 'evenodd')
      end
    else
      content_tag(:span, '•', class: 'w-3 h-3 mr-1')
    end
  end

  def campaign_type_bg_color(campaign_type)
    case campaign_type&.to_s
    when 'product_launch'
      'bg-blue-100'
    when 'brand_awareness'
      'bg-purple-100'
    when 'lead_generation'
      'bg-green-100'
    when 'customer_retention'
      'bg-yellow-100'
    when 'seasonal_promotion'
      'bg-orange-100'
    when 'content_marketing'
      'bg-pink-100'
    when 'email_nurture'
      'bg-indigo-100'
    when 'social_media'
      'bg-cyan-100'
    when 'event_promotion'
      'bg-red-100'
    when 'customer_onboarding'
      'bg-teal-100'
    when 're_engagement'
      'bg-violet-100'
    when 'cross_sell', 'upsell'
      'bg-emerald-100'
    when 'referral'
      'bg-rose-100'
    when 'b2b_lead_generation'
      'bg-slate-100'
    else
      'bg-gray-100'
    end
  end

  def campaign_type_icon(campaign_type)
    icon_class = 'w-5 h-5'
    
    case campaign_type&.to_s
    when 'product_launch'
      icon_color = 'text-blue-600'
      content_tag(:svg, class: "#{icon_class} #{icon_color}", fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24', 'aria-hidden': 'true') do
        content_tag(:path, '', 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'M13 10V3L4 14h7v7l9-11h-7z')
      end
    when 'brand_awareness'
      icon_color = 'text-purple-600'
      content_tag(:svg, class: "#{icon_class} #{icon_color}", fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24', 'aria-hidden': 'true') do
        content_tag(:path, '', 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z')
      end
    when 'lead_generation'
      icon_color = 'text-green-600'
      content_tag(:svg, class: "#{icon_class} #{icon_color}", fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24', 'aria-hidden': 'true') do
        content_tag(:path, '', 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z')
      end
    when 'email_nurture'
      icon_color = 'text-indigo-600'
      content_tag(:svg, class: "#{icon_class} #{icon_color}", fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24', 'aria-hidden': 'true') do
        content_tag(:path, '', 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z')
      end
    when 'social_media'
      icon_color = 'text-cyan-600'
      content_tag(:svg, class: "#{icon_class} #{icon_color}", fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24', 'aria-hidden': 'true') do
        content_tag(:path, '', 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2m-9 0v16l4-4 4 4V4M7 4h10')
      end
    else
      icon_color = 'text-gray-600'
      content_tag(:svg, class: "#{icon_class} #{icon_color}", fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24', 'aria-hidden': 'true') do
        content_tag(:path, '', 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'M13 10V3L4 14h7v7l9-11h-7z')
      end
    end
  end

  # Workflow and status management helpers
  def status_dot_color(status)
    case status&.to_s
    when 'draft'
      'bg-gray-400'
    when 'active'
      'bg-green-500'
    when 'paused'
      'bg-yellow-500'
    when 'completed'
      'bg-blue-500'
    when 'archived'
      'bg-purple-500'
    else
      'bg-gray-400'
    end
  end

  def status_text_color(status)
    case status&.to_s
    when 'draft'
      'text-gray-700'
    when 'active'
      'text-green-700'
    when 'paused'
      'text-yellow-700'
    when 'completed'
      'text-blue-700'
    when 'archived'
      'text-purple-700'
    else
      'text-gray-700'
    end
  end

  def status_description(status)
    case status&.to_s
    when 'draft'
      'Campaign is being prepared and not yet active'
    when 'active'
      'Campaign is live and actively running'
    when 'paused'
      'Campaign is temporarily stopped and can be resumed'
    when 'completed'
      'Campaign has finished and achieved its goals'
    when 'archived'
      'Campaign is stored in the archive for future reference'
    else
      'Status description not available'
    end
  end

  def timeline_step_classes(current_status, step_status)
    status_reached = status_reached?(current_status, step_status)
    is_current = current_status == step_status
    
    if status_reached && !is_current
      'bg-green-600 border-green-600 text-white'
    elsif is_current
      'bg-blue-600 border-blue-600 text-white'
    else
      'bg-white border-gray-300 text-gray-500'
    end
  end

  def status_reached?(current_status, target_status)
    status_order = ['draft', 'active', 'paused', 'completed', 'archived']
    current_index = status_order.index(current_status) || 0
    target_index = status_order.index(target_status) || 0
    
    # Special case for paused - it's not "reached" in linear progression
    return current_status == 'paused' if target_status == 'paused'
    
    current_index >= target_index
  end

  def status_transition_options(current_status)
    transitions = {
      'draft' => [['Draft', 'draft'], ['Active', 'active'], ['Archived', 'archived']],
      'active' => [['Active', 'active'], ['Paused', 'paused'], ['Completed', 'completed'], ['Archived', 'archived']],
      'paused' => [['Paused', 'paused'], ['Active', 'active'], ['Completed', 'completed'], ['Archived', 'archived']],
      'completed' => [['Completed', 'completed'], ['Archived', 'archived']],
      'archived' => [['Archived', 'archived'], ['Draft', 'draft']]
    }
    
    transitions[current_status] || [['Unknown', current_status]]
  end

  def get_status_timestamp(campaign, status)
    # This would typically come from a status_changes table
    # For now, use campaign timestamps based on status
    case status
    when 'draft'
      campaign.created_at
    when 'active'
      campaign.started_at
    when 'completed'
      campaign.ended_at
    when 'archived'
      campaign.updated_at if campaign.status == 'archived'
    else
      nil
    end
  end

  def get_next_milestone(campaign)
    case campaign.status
    when 'draft'
      'Campaign activation'
    when 'active'
      'Performance review'
    when 'paused'
      'Resume or complete'
    when 'completed'
      'Final review'
    when 'archived'
      'N/A'
    else
      'Unknown'
    end
  end

  # Workflow helper methods
  def get_completed_steps_count(campaign)
    statuses = ['draft', 'active', 'paused', 'completed', 'archived']
    current_index = statuses.index(campaign.status) || 0
    [current_index, 0].max
  end

  def get_pending_steps_count(campaign)
    statuses = ['draft', 'active', 'paused', 'completed', 'archived']
    current_index = statuses.index(campaign.status) || 0
    [statuses.length - current_index - 1, 0].max
  end

  def get_workflow_progress(campaign)
    statuses = ['draft', 'active', 'paused', 'completed', 'archived']
    current_index = statuses.index(campaign.status) || 0
    ((current_index.to_f / (statuses.length - 1)) * 100).round
  end

  def get_estimated_completion(campaign)
    case campaign.status
    when 'draft'
      'Not started'
    when 'active'
      if campaign.end_date
        distance_of_time_in_words(Time.current, campaign.end_date)
      else
        'TBD'
      end
    when 'paused'
      'On hold'
    when 'completed'
      'Completed'
    when 'archived'
      'Archived'
    else
      'Unknown'
    end
  end

  def get_workflow_timeline(campaign)
    timeline = []
    
    # Campaign creation
    timeline << {
      title: 'Campaign Created',
      description: 'Campaign was created and saved as draft',
      timestamp: campaign.created_at,
      completed: true,
      current: false,
      metadata: { user: 'System', type: 'creation' }
    }
    
    # Status progression
    if campaign.started_at
      timeline << {
        title: 'Campaign Activated',
        description: 'Campaign was activated and began running',
        timestamp: campaign.started_at,
        completed: true,
        current: false,
        metadata: { user: 'User', type: 'activation' }
      }
    end
    
    if campaign.status == 'completed' && campaign.ended_at
      timeline << {
        title: 'Campaign Completed',
        description: 'Campaign reached completion and finished running',
        timestamp: campaign.ended_at,
        completed: true,
        current: false,
        metadata: { user: 'System', type: 'completion' }
      }
    end
    
    # Current status
    unless ['completed', 'archived'].include?(campaign.status)
      timeline << {
        title: "Currently #{campaign.status.humanize}",
        description: status_description(campaign.status),
        timestamp: campaign.updated_at,
        completed: false,
        current: true,
        metadata: { user: 'System', type: 'current' }
      }
    end
    
    timeline
  end

  # Status history helpers
  def get_status_history(campaign)
    # This would typically come from a status_changes table
    # For now, create a mock history based on available data
    history = []
    
    history << {
      action: 'created',
      from_status: nil,
      to_status: 'draft',
      user: 'Current User',
      timestamp: campaign.created_at.iso8601,
      reason: 'Campaign initialized',
      metadata: { source: 'web_interface' }
    }
    
    if campaign.started_at
      history << {
        action: 'status_changed',
        from_status: 'draft',
        to_status: 'active',
        user: 'Current User',
        timestamp: campaign.started_at.iso8601,
        reason: 'Campaign ready for launch',
        metadata: { method: 'manual' }
      }
    end
    
    if campaign.status == 'completed' && campaign.ended_at
      history << {
        action: 'status_changed',
        from_status: 'active',
        to_status: 'completed',
        user: 'System',
        timestamp: campaign.ended_at.iso8601,
        reason: 'Campaign reached end date',
        metadata: { automated: true }
      }
    end
    
    history.sort_by { |entry| Time.parse(entry[:timestamp]) }.reverse
  end

  def status_history_icon_classes(action)
    case action
    when 'created'
      'bg-green-100 text-green-600'
    when 'status_changed'
      'bg-blue-100 text-blue-600'
    when 'activated'
      'bg-green-100 text-green-600'
    when 'paused'
      'bg-yellow-100 text-yellow-600'
    when 'completed'
      'bg-blue-100 text-blue-600'
    when 'archived'
      'bg-purple-100 text-purple-600'
    else
      'bg-gray-100 text-gray-600'
    end
  end

  def status_history_title(action, from_status, to_status)
    case action
    when 'created'
      'Campaign Created'
    when 'status_changed'
      "Status changed from #{from_status&.humanize} to #{to_status&.humanize}"
    when 'activated'
      'Campaign Activated'
    when 'paused'
      'Campaign Paused'
    when 'completed'
      'Campaign Completed'
    when 'archived'
      'Campaign Archived'
    else
      action.humanize
    end
  end

  def status_badge_classes(status)
    campaign_status_classes(status)
  end

  # Approval workflow helpers
  def get_approval_status(campaign)
    # Mock approval status - would be from approval_workflows table
    case campaign.status
    when 'draft'
      'pending_approval'
    when 'active'
      'approved'
    when 'completed'
      'approved'
    else
      'not_required'
    end
  end

  def get_approval_progress(campaign)
    # Mock progress calculation
    case get_approval_status(campaign)
    when 'approved'
      100
    when 'pending_approval'
      25
    when 'rejected'
      0
    else
      0
    end
  end

  def get_approval_steps(campaign)
    # Mock approval steps - would be from approval_steps table
    [
      {
        id: 1,
        title: 'Content Review',
        description: 'Review campaign content and messaging',
        status: 'completed',
        approver: { name: 'Sarah Johnson', role: 'Content Manager' },
        completed_at: 1.day.ago,
        comments: 'Content looks good, approved for launch'
      },
      {
        id: 2,
        title: 'Budget Approval',
        description: 'Approve campaign budget and resource allocation',
        status: 'current',
        approver: { name: 'Mike Chen', role: 'Finance Manager' },
        deadline: 2.days.from_now,
        notified_at: 1.hour.ago
      },
      {
        id: 3,
        title: 'Final Launch Approval',
        description: 'Final approval to launch the campaign',
        status: 'pending',
        approver: { name: 'Lisa Davis', role: 'Marketing Director' },
        deadline: 3.days.from_now
      }
    ]
  end

  def get_approval_history(campaign)
    # Mock approval history
    [
      {
        user: { name: 'Sarah Johnson' },
        action: 'approved content review',
        comments: 'Content looks good, approved for launch',
        timestamp: 1.day.ago
      },
      {
        user: { name: 'System' },
        action: 'sent approval request to Mike Chen',
        comments: nil,
        timestamp: 1.hour.ago
      }
    ]
  end

  def approval_status_classes(status)
    case status&.to_s
    when 'approved'
      'bg-green-100 text-green-800'
    when 'pending_approval'
      'bg-yellow-100 text-yellow-800'
    when 'rejected'
      'bg-red-100 text-red-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end

  def can_approve?(user, step)
    # Mock approval permission check
    step[:approver][:name] == 'Current User'
  end

  def can_manage_approvals?(user, campaign)
    # Mock approval management permission check
    true
  end

  def requires_approval?(campaign)
    # Mock approval requirement check
    ['draft', 'active'].include?(campaign.status)
  end

  # Automated rules helpers
  def get_automated_rules(campaign)
    # Mock automated rules - would be from automated_rules table
    [
      {
        id: 1,
        name: 'Auto-complete on end date',
        description: 'Automatically complete campaign when end date is reached',
        enabled: true,
        trigger: {
          description: 'End date is reached',
          status_change: false,
          date_condition: true,
          from_status: nil,
          to_status: nil
        },
        action: {
          description: 'Change status to completed'
        },
        last_triggered: 1.week.ago
      },
      {
        id: 2,
        name: 'Budget alert at 80%',
        description: 'Send notification when 80% of budget is spent',
        enabled: true,
        trigger: {
          description: 'Budget reaches 80% of allocated amount',
          status_change: false,
          budget_condition: true,
          from_status: nil,
          to_status: nil
        },
        action: {
          description: 'Send notification to campaign manager'
        },
        last_triggered: nil
      }
    ]
  end

  def campaign_ready_for_activation?(campaign)
    campaign.name.present? && 
    campaign.description.present? && 
    campaign.persona.present? && 
    campaign.journeys.any?
  end
end
