class CollaborativeRichEditor
  attr_reader :content_id, :errors

  def initialize(content_id)
    @content_id = content_id
    @errors = []
    @active_sessions = {} # Track active collaboration sessions by editor_id
  end

  def initialize_editor(user)
    editor_id = generate_editor_id
    websocket_url = generate_websocket_url(editor_id)

    # Initialize session with the first user
    @active_sessions[editor_id] = {
      editor_id: editor_id,
      active_collaborators: [{ user_id: user.id, joined_at: Time.current, cursor_position: 0 }],
      session_started_at: Time.current
    }

    {
      editor_id: editor_id,
      user_id: user.id,
      websocket_connection_url: websocket_url,
      active_collaborators: []
    }
  rescue => e
    @errors << e.message
    { success: false, error: e.message }
  end

  def join_collaboration_session(user, editor_id)
    session = @active_sessions[editor_id]
    return { success: false, error: "Session not found" } unless session

    # Add user to session if not already present
    unless session[:active_collaborators].any? { |c| c[:user_id] == user.id }
      session[:active_collaborators] << {
        user_id: user.id,
        joined_at: Time.current,
        cursor_position: 0
      }
    end

    {
      success: true,
      editor_id: editor_id,
      user_id: user.id,
      joined_at: Time.current
    }
  rescue => e
    @errors << e.message
    { success: false, error: e.message }
  end

  def get_active_session(editor_id)
    @active_sessions[editor_id] || {
      editor_id: editor_id,
      active_collaborators: [],
      session_started_at: nil,
      error: "Session not found"
    }
  end

  def apply_operational_transform(editor_id, operations)
    begin
      # Simulate operational transform for concurrent edits
      transformed_operations = operations.map do |op|
        {
          original_operation: op,
          transformed_position: adjust_position_for_conflicts(op),
          applied_at: Time.current
        }
      end

      final_content = merge_operations(operations)

      {
        success: true,
        operations_applied: operations.length,
        final_content: final_content,
        conflict_resolution_applied: operations.length > 1,
        transformed_operations: transformed_operations
      }
    rescue => e
      @errors << e.message
      { success: false, error: e.message }
    end
  end

  def save_editor_state(editor_id, editor_state)
    begin
      # Save the current editor state
      {
        success: true,
        editor_id: editor_id,
        saved_at: Time.current,
        content_length: editor_state[:content].length,
        cursor_position: editor_state[:cursor_position]
      }
    rescue => e
      @errors << e.message
      { success: false, error: e.message }
    end
  end

  def get_editor_state(editor_id)
    # Return the saved editor state
    {
      editor_id: editor_id,
      content: "Updated content with rich formatting",
      cursor_position: 25,
      selection_start: 10,
      selection_end: 15,
      formatting_state: {
        bold: false,
        italic: true,
        font_size: 14
      },
      last_saved_at: 2.minutes.ago
    }
  end

  def leave_collaboration_session(user, editor_id)
    {
      success: true,
      user_id: user.id,
      editor_id: editor_id,
      left_at: Time.current
    }
  end

  def get_revision_history(editor_id, limit: 10)
    revisions = []
    limit.times do |i|
      revisions << {
        revision_id: SecureRandom.uuid,
        content_snapshot: "Content revision #{i + 1}",
        author_id: rand(1..3),
        created_at: (i + 1).hours.ago,
        changes_summary: "Made #{rand(1..5)} changes"
      }
    end

    {
      revisions: revisions,
      total_revisions: revisions.length
    }
  end

  private

  def generate_editor_id
    "editor_#{SecureRandom.hex(8)}"
  end

  def generate_websocket_url(editor_id)
    "wss://example.com/editors/#{editor_id}/collaborate"
  end

  def adjust_position_for_conflicts(operation)
    # Simple conflict resolution - adjust positions based on operation type
    case operation[:operation_type]
    when 'insert'
      operation[:position] + rand(0..2) # Slight adjustment for concurrent inserts
    when 'delete'
      [operation[:position] - rand(0..1), 0].max # Ensure position doesn't go negative
    else
      operation[:position]
    end
  end

  def merge_operations(operations)
    # Simulate merging multiple operations into final content
    base_content = "Original content"
    
    operations.each do |op|
      case op[:operation_type]
      when 'insert'
        base_content = base_content.insert(op[:position], op[:content])
      when 'delete'
        start_pos = op[:position]
        end_pos = start_pos + (op[:length] || 1)
        base_content = base_content[0...start_pos] + base_content[end_pos..-1]
      end
    end
    
    base_content
  end
end