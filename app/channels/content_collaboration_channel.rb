class ContentCollaborationChannel < ApplicationCable::Channel
  def subscribed
    content = ContentRepository.find(params[:content_id])
    
    # Ensure user has access to this content
    reject unless can_access_content?(content)
    
    stream_from "content_collaboration_#{params[:content_id]}"
    
    # Broadcast user joined event
    broadcast_user_event('user_joined', content)
    
    # Track user presence
    track_user_presence(content)
  end

  def unsubscribed
    if params[:content_id]
      content = ContentRepository.find_by(id: params[:content_id])
      if content && can_access_content?(content)
        broadcast_user_event('user_left', content)
        remove_user_presence(content)
      end
    end
  end

  def receive_message(data)
    content = ContentRepository.find(params[:content_id])
    return unless can_access_content?(content)

    case data['type']
    when 'content_update'
      handle_content_update(content, data)
    when 'cursor_move'
      handle_cursor_move(content, data)
    when 'selection_change'
      handle_selection_change(content, data)
    when 'operational_transform'
      handle_operational_transform(content, data)
    when 'heartbeat'
      handle_heartbeat(content)
    end
  end

  private

  def can_access_content?(content)
    # Check if user can access this content
    current_user == content.user || 
    (content.campaign && current_user == content.campaign.user) ||
    has_content_permission?(content)
  end

  def has_content_permission?(content)
    # Check content permissions if they exist
    content.content_permissions.exists?(user: current_user) ||
    # For now, allow any authenticated user - can be tightened based on requirements
    true
  end

  def broadcast_user_event(event_type, content)
    ActionCable.server.broadcast(
      "content_collaboration_#{content.id}",
      {
        type: event_type,
        user: current_user_data,
        content_id: content.id,
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def track_user_presence(content)
    Rails.cache.write(
      "presence:content:#{content.id}:#{current_user.id}",
      {
        user: current_user_data,
        status: 'online',
        last_seen: Time.current.iso8601,
        location: "content_#{content.id}",
        cursor_position: nil
      },
      expires_in: 5.minutes
    )
  end

  def remove_user_presence(content)
    Rails.cache.delete("presence:content:#{content.id}:#{current_user.id}")
  end

  def handle_content_update(content, data)
    return unless valid_content_update?(data)

    begin
      # Create operational transform for the update
      operation = create_operational_transform(content, data)
      
      # Apply the operation
      new_content = apply_operation(content, operation)
      
      # Create new content version
      version = content.create_version!(
        body: new_content,
        author: current_user,
        commit_message: "Real-time collaborative edit"
      )
      
      # Broadcast the operation to all collaborators
      broadcast_operational_transform(content, operation, version)
      
    rescue => e
      handle_content_update_error(content, data, e)
    end
  end

  def valid_content_update?(data)
    data['operation'].present? && 
    %w[insert delete retain].include?(data['operation']) &&
    data['position'].is_a?(Integer) &&
    data['position'] >= 0
  end

  def create_operational_transform(content, data)
    {
      operation: data['operation'],
      position: data['position'],
      content: data['content'],
      length: data['length'],
      author_id: current_user.id,
      timestamp: Time.current.iso8601,
      version: content.total_versions + 1
    }
  end

  def apply_operation(content, operation)
    current_content = content.current_version&.body || ''
    
    case operation[:operation]
    when 'insert'
      # Insert content at position
      current_content.insert(operation[:position], operation[:content] || '')
    when 'delete'
      # Delete content at position
      length = operation[:length] || 1
      current_content.slice!(operation[:position], length)
      current_content
    when 'retain'
      # No change to content, just move cursor
      current_content
    else
      current_content
    end
  end

  def broadcast_operational_transform(content, operation, version)
    ActionCable.server.broadcast(
      "content_collaboration_#{content.id}",
      {
        type: 'operational_transform',
        user: current_user_data,
        content_id: content.id,
        operation: operation,
        version: version.version_number,
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def handle_content_update_error(content, data, error)
    ActionCable.server.broadcast(
      "content_collaboration_#{content.id}",
      {
        type: 'content_update_error',
        user: current_user_data,
        content_id: content.id,
        error: {
          message: 'Failed to apply content update',
          details: error.message
        },
        attempted_operation: data,
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def handle_operational_transform(content, data)
    # Handle incoming operational transforms from other clients
    return unless valid_operational_transform?(data)

    # Transform the operation against concurrent operations
    transformed_operation = transform_operation(content, data)
    
    # Apply and broadcast if successful
    if transformed_operation
      broadcast_transformed_operation(content, transformed_operation)
    end
  end

  def valid_operational_transform?(data)
    data['operation_id'].present? &&
    data['base_version'].is_a?(Integer) &&
    data['operations'].is_a?(Array)
  end

  def transform_operation(content, data)
    # Simplified operational transform - in production, use a library like ShareJS
    current_version = content.total_versions
    base_version = data['base_version']
    
    if current_version == base_version
      # No concurrent operations, apply directly
      data['operations']
    else
      # Need to transform against concurrent operations
      # This is a complex algorithm - simplified implementation
      transform_against_concurrent_operations(data['operations'], base_version, current_version)
    end
  end

  def transform_against_concurrent_operations(operations, base_version, current_version)
    # Simplified transform - in production use proper OT library
    # For now, just return the operations (may cause conflicts)
    operations
  end

  def broadcast_transformed_operation(content, operations)
    ActionCable.server.broadcast(
      "content_collaboration_#{content.id}",
      {
        type: 'operations_transformed',
        user: current_user_data,
        content_id: content.id,
        operations: operations,
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def handle_cursor_move(content, data)
    return unless valid_cursor_data?(data)

    # Update user presence with cursor position
    Rails.cache.write(
      "presence:content:#{content.id}:#{current_user.id}",
      {
        user: current_user_data,
        status: 'online',
        last_seen: Time.current.iso8601,
        location: "content_#{content.id}",
        cursor_position: {
          position: data['position'],
          selection_start: data['selection_start'],
          selection_end: data['selection_end']
        }
      },
      expires_in: 5.minutes
    )

    # Broadcast cursor movement to other users
    ActionCable.server.broadcast(
      "content_collaboration_#{content.id}",
      {
        type: 'cursor_moved',
        user: current_user_data,
        content_id: content.id,
        cursor: {
          position: data['position'],
          selection_start: data['selection_start'],
          selection_end: data['selection_end'],
          color: generate_user_color
        },
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def valid_cursor_data?(data)
    data['position'].is_a?(Integer) && data['position'] >= 0
  end

  def handle_selection_change(content, data)
    return unless valid_selection_data?(data)

    ActionCable.server.broadcast(
      "content_collaboration_#{content.id}",
      {
        type: 'selection_changed',
        user: current_user_data,
        content_id: content.id,
        selection: {
          start: data['start'],
          end: data['end'],
          direction: data['direction'] || 'forward'
        },
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def valid_selection_data?(data)
    data['start'].is_a?(Integer) && 
    data['end'].is_a?(Integer) && 
    data['start'] >= 0 && 
    data['end'] >= data['start']
  end

  def handle_heartbeat(content)
    # Update user presence
    track_user_presence(content)
    
    # Get all active users for this content
    active_users = get_active_users(content)
    
    # Send heartbeat response with user list
    ActionCable.server.broadcast(
      "content_collaboration_#{content.id}",
      {
        type: 'heartbeat_response',
        user: current_user_data,
        content_id: content.id,
        active_users: active_users,
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def get_active_users(content)
    # Get all users currently present for this content
    pattern = "presence:content:#{content.id}:*"
    keys = Rails.cache.redis.keys(pattern)
    
    keys.map do |key|
      presence_data = Rails.cache.read(key)
      presence_data if presence_data && 
                     Time.parse(presence_data[:last_seen]) > 5.minutes.ago
    end.compact
  end

  def generate_user_color
    # Generate a consistent color for this user
    colors = %w[#FF6B6B #4ECDC4 #45B7D1 #96CEB4 #FFEAA7 #DDA0DD #98D8C8]
    colors[current_user.id % colors.length]
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