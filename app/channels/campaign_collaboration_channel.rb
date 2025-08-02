class CampaignCollaborationChannel < ApplicationCable::Channel
  def subscribed
    campaign_plan = CampaignPlan.find(params[:campaign_plan_id])
    
    # Ensure user has access to this campaign plan
    reject unless can_access_campaign_plan?(campaign_plan)
    
    stream_from "campaign_collaboration_#{params[:campaign_plan_id]}"
    
    # Broadcast user joined event
    broadcast_user_event('user_joined', campaign_plan)
    
    # Track user presence
    track_user_presence(campaign_plan)
  end

  def unsubscribed
    if params[:campaign_plan_id]
      campaign_plan = CampaignPlan.find_by(id: params[:campaign_plan_id])
      if campaign_plan && can_access_campaign_plan?(campaign_plan)
        broadcast_user_event('user_left', campaign_plan)
        remove_user_presence(campaign_plan)
      end
    end
  end

  def receive_message(data)
    campaign_plan = CampaignPlan.find(params[:campaign_plan_id])
    return unless can_access_campaign_plan?(campaign_plan)

    case data['type']
    when 'plan_update'
      handle_plan_update(campaign_plan, data)
    when 'comment_added'
      handle_comment_added(campaign_plan, data)
    when 'cursor_move'
      handle_cursor_move(campaign_plan, data)
    when 'heartbeat'
      handle_heartbeat(campaign_plan)
    end
  end

  private

  def can_access_campaign_plan?(campaign_plan)
    # Basic access control - user must be the owner or have campaign access
    current_user == campaign_plan.user || 
    current_user == campaign_plan.campaign.user ||
    has_campaign_permission?(campaign_plan.campaign)
  end

  def has_campaign_permission?(campaign)
    # Placeholder for more sophisticated permission system
    # Could check team membership, role-based access, etc.
    true
  end

  def broadcast_user_event(event_type, campaign_plan)
    ActionCable.server.broadcast(
      "campaign_collaboration_#{campaign_plan.id}",
      {
        type: event_type,
        user: current_user_data,
        campaign_plan_id: campaign_plan.id,
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def track_user_presence(campaign_plan)
    Rails.cache.write(
      "presence:campaign:#{campaign_plan.id}:#{current_user.id}",
      {
        user: current_user_data,
        status: 'online',
        last_seen: Time.current.iso8601,
        location: "campaign_plan_#{campaign_plan.id}"
      },
      expires_in: 5.minutes
    )
  end

  def remove_user_presence(campaign_plan)
    Rails.cache.delete("presence:campaign:#{campaign_plan.id}:#{current_user.id}")
  end

  def handle_plan_update(campaign_plan, data)
    # Validate and sanitize the update
    return unless valid_plan_update?(data)

    # Check for conflicts
    conflict_resolution = detect_and_resolve_conflicts(campaign_plan, data)
    
    begin
      # Apply the update with optimistic locking
      update_campaign_plan(campaign_plan, data, conflict_resolution)
      
      # Broadcast successful update to all subscribers
      broadcast_plan_update(campaign_plan, data, conflict_resolution)
      
    rescue ActiveRecord::StaleObjectError
      # Handle concurrent updates
      handle_concurrent_update_conflict(campaign_plan, data)
    end
  end

  def valid_plan_update?(data)
    allowed_fields = %w[
      strategic_rationale target_audience messaging_framework
      channel_strategy timeline_phases success_metrics
      budget_allocation creative_approach market_analysis
    ]
    
    data['field'].in?(allowed_fields) && data['new_value'].present?
  end

  def detect_and_resolve_conflicts(campaign_plan, data)
    # Get the latest version from database
    current_version = campaign_plan.reload.version
    client_version = data['version']&.to_f || 0
    
    if current_version > client_version
      # Conflict detected - another user has made changes
      current_value = campaign_plan.send(data['field'])
      
      {
        conflict_detected: true,
        server_version: current_version,
        client_version: client_version,
        server_value: current_value,
        client_value: data['new_value'],
        resolution_strategy: determine_resolution_strategy(data['field'], current_value, data['new_value'])
      }
    else
      { conflict_detected: false }
    end
  end

  def determine_resolution_strategy(field, server_value, client_value)
    # Simple conflict resolution strategies
    case field
    when 'timeline_phases', 'channel_strategy'
      # For arrays, try to merge if possible
      if server_value.is_a?(Array) && client_value.is_a?(Array)
        'merge'
      else
        'manual'
      end
    when 'budget_allocation', 'success_metrics'
      # For hashes, try to merge
      if server_value.is_a?(Hash) && client_value.is_a?(Hash)
        'merge'
      else
        'manual'
      end
    else
      # For simple fields, use last-writer-wins
      'remote_wins'
    end
  end

  def update_campaign_plan(campaign_plan, data, conflict_resolution)
    if conflict_resolution[:conflict_detected]
      case conflict_resolution[:resolution_strategy]
      when 'merge'
        merged_value = merge_values(
          conflict_resolution[:server_value], 
          data['new_value'], 
          data['field']
        )
        campaign_plan.update!(data['field'] => merged_value, version: campaign_plan.version + 0.1)
      when 'remote_wins'
        campaign_plan.update!(data['field'] => data['new_value'], version: campaign_plan.version + 0.1)
      when 'manual'
        # Don't auto-resolve, let users choose
        return
      end
    else
      campaign_plan.update!(data['field'] => data['new_value'], version: campaign_plan.version + 0.1)
    end

    # Create revision record
    create_plan_revision(campaign_plan, data)
  end

  def merge_values(server_value, client_value, field)
    case field
    when 'timeline_phases', 'channel_strategy'
      # Merge arrays by combining unique elements
      if server_value.is_a?(Array) && client_value.is_a?(Array)
        (server_value + client_value).uniq { |item| item['id'] || item['name'] }
      else
        client_value
      end
    when 'budget_allocation', 'success_metrics'
      # Merge hashes
      if server_value.is_a?(Hash) && client_value.is_a?(Hash)
        server_value.deep_merge(client_value)
      else
        client_value
      end
    else
      client_value
    end
  end

  def create_plan_revision(campaign_plan, data)
    campaign_plan.plan_revisions.create!(
      revision_number: campaign_plan.version,
      plan_data: campaign_plan.to_export_hash,
      user: current_user,
      change_summary: "Updated #{data['field']} via real-time collaboration"
    )
  end

  def broadcast_plan_update(campaign_plan, data, conflict_resolution)
    ActionCable.server.broadcast(
      "campaign_collaboration_#{campaign_plan.id}",
      {
        type: 'plan_updated',
        user: current_user_data,
        campaign_plan_id: campaign_plan.id,
        field: data['field'],
        new_value: campaign_plan.send(data['field']),
        version: campaign_plan.version,
        conflict_resolution: conflict_resolution,
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def handle_concurrent_update_conflict(campaign_plan, data)
    ActionCable.server.broadcast(
      "campaign_collaboration_#{campaign_plan.id}",
      {
        type: 'update_conflict',
        user: current_user_data,
        campaign_plan_id: campaign_plan.id,
        field: data['field'],
        attempted_value: data['new_value'],
        current_value: campaign_plan.reload.send(data['field']),
        message: 'Another user updated this field simultaneously',
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def handle_comment_added(campaign_plan, data)
    return unless valid_comment_data?(data)

    comment = campaign_plan.plan_comments.create!(
      user: current_user,
      content: data['content'],
      field_reference: data['field_reference']
    )

    ActionCable.server.broadcast(
      "campaign_collaboration_#{campaign_plan.id}",
      {
        type: 'comment_added',
        user: current_user_data,
        campaign_plan_id: campaign_plan.id,
        comment: {
          id: comment.id,
          content: comment.content,
          field_reference: comment.field_reference,
          created_at: comment.created_at.iso8601,
          user: current_user_data
        },
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def valid_comment_data?(data)
    data['content'].present? && data['content'].length <= 1000
  end

  def handle_cursor_move(campaign_plan, data)
    # Don't persist cursor movements, just broadcast them
    ActionCable.server.broadcast(
      "campaign_collaboration_#{campaign_plan.id}",
      {
        type: 'cursor_moved',
        user: current_user_data,
        campaign_plan_id: campaign_plan.id,
        cursor_position: {
          x: data['x']&.to_f,
          y: data['y']&.to_f,
          element_id: data['element_id'],
          selection_start: data['selection_start']&.to_i,
          selection_end: data['selection_end']&.to_i
        },
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def handle_heartbeat(campaign_plan)
    # Update user presence
    track_user_presence(campaign_plan)
    
    # Send heartbeat response
    ActionCable.server.broadcast(
      "campaign_collaboration_#{campaign_plan.id}",
      {
        type: 'heartbeat_response',
        user: current_user_data,
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def current_user_data
    {
      id: current_user.id,
      name: current_user.name || current_user.email,
      email: current_user.email,
      avatar_url: current_user.avatar.attached? ? url_for(current_user.avatar) : nil
    }
  end

  def generate_message_id
    "msg_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
  end
end