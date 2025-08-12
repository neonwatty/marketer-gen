# Journey Persistence Service for handling auto-save, version history, and data management
class JourneyPersistenceService
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Configuration attributes
  attribute :journey, default: nil
  attribute :user, default: nil
  attribute :auto_save_enabled, :boolean, default: true
  attribute :version_limit, :integer, default: 50
  attribute :conflict_resolution_strategy, :string, default: 'prompt'

  class PersistenceError < StandardError; end
  class ConflictError < PersistenceError
    attr_reader :conflict_data, :conflict_type
    
    def initialize(message, conflict_data: nil, conflict_type: 'version_mismatch')
      super(message)
      @conflict_data = conflict_data
      @conflict_type = conflict_type
    end
  end
  class VersionLimitError < PersistenceError; end

  def initialize(attributes = {})
    super(attributes)
    @version_history = []
    @pending_operations = []
  end

  # Save journey with optimistic updates and conflict detection
  def save_journey(journey_data, options = {})
    validate_journey_data!(journey_data)
    
    # Check for conflicts if version is specified
    if options[:expected_version]
      check_version_conflicts!(options[:expected_version])
    end
    
    # Create version snapshot before saving
    previous_version = create_version_snapshot(journey, 'before_save')
    
    begin
      # Update journey with new data
      result = update_journey_data(journey_data, options)
      
      # Create version snapshot after saving
      new_version = create_version_snapshot(journey, options[:change_type] || 'update')
      
      # Store version in history
      store_version(new_version) unless options[:skip_versioning]
      
      # Return success result
      {
        success: true,
        version: new_version[:version],
        timestamp: new_version[:timestamp],
        journey_id: journey.id,
        changes_detected: detect_changes(previous_version[:data], journey_data),
        auto_save: options[:is_auto_save] || false
      }
      
    rescue ActiveRecord::RecordInvalid => e
      handle_validation_error(e, journey_data, options)
    rescue ActiveRecord::StaleObjectError => e
      handle_stale_object_error(e, journey_data, options)
    rescue => e
      handle_generic_error(e, journey_data, options)
    end
  end

  # Create version snapshot
  def create_version_snapshot(journey, change_type = 'update')
    {
      version: generate_version_number,
      timestamp: Time.current,
      change_type: change_type,
      data: serialize_journey_data(journey),
      metadata: {
        user_id: user&.id,
        user_name: user&.name || 'Unknown',
        ip_address: get_client_ip,
        user_agent: get_user_agent,
        stages_count: journey&.journey_stages&.count || 0,
        total_duration: journey&.total_duration_days || 0
      }
    }
  end

  # Store version in history with cleanup
  def store_version(version_data)
    @version_history.unshift(version_data)
    
    # Cleanup old versions
    if @version_history.length > version_limit
      @version_history = @version_history.first(version_limit)
    end
    
    # Persist version to database if journey exists
    if journey&.persisted?
      store_version_in_database(version_data)
    end
    
    version_data
  end

  # Retrieve version history
  def get_version_history(limit = nil)
    limit ||= version_limit
    
    if journey&.persisted?
      load_version_history_from_database(limit)
    else
      @version_history.first(limit)
    end
  end

  # Restore journey to specific version
  def restore_to_version(version_number, options = {})
    version_data = find_version(version_number)
    
    unless version_data
      raise PersistenceError, "Version #{version_number} not found"
    end
    
    # Create backup of current state
    current_backup = create_version_snapshot(journey, 'pre_restore_backup')
    store_version(current_backup)
    
    begin
      # Apply version data to journey
      restored_data = version_data[:data]
      result = update_journey_data(restored_data, options.merge(is_restore: true))
      
      # Create restore version entry
      restore_version = create_version_snapshot(journey, "restored_from_v#{version_number}")
      store_version(restore_version)
      
      {
        success: true,
        restored_from_version: version_number,
        current_version: restore_version[:version],
        backup_version: current_backup[:version],
        timestamp: restore_version[:timestamp]
      }
      
    rescue => e
      # If restore fails, we still have the backup
      raise PersistenceError, "Failed to restore to version #{version_number}: #{e.message}"
    end
  end

  # Duplicate journey with version history
  def duplicate_journey(options = {})
    unless journey&.persisted?
      raise PersistenceError, "Cannot duplicate unsaved journey"
    end
    
    Journey.transaction do
      # Create new journey
      new_journey = journey.dup
      new_journey.name = options[:name] || "#{journey.name} (Copy)"
      new_journey.position = (Journey.maximum(:position) || 0) + 1
      new_journey.save!

      # Duplicate stages
      journey.journey_stages.ordered.each do |original_stage|
        new_stage = original_stage.dup
        new_stage.journey = new_journey
        new_stage.save!

        # Duplicate content assets
        original_stage.content_assets.each do |original_asset|
          new_asset = original_asset.dup
          new_asset.assetable = new_stage
          new_asset.save!
        end
      end

      # Create initial version for duplicated journey
      duplicate_service = self.class.new(journey: new_journey, user: user)
      duplicate_service.create_version_snapshot(new_journey, 'duplicated_from_original')
      
      new_journey.reload
    end
  end

  # Export journey with version history
  def export_journey(format = 'json', options = {})
    export_data = {
      journey: serialize_journey_data(journey),
      version_history: options[:include_history] ? get_version_history : [],
      exported_at: Time.current.iso8601,
      exported_by: user&.name || 'Unknown',
      format_version: '1.0',
      metadata: {
        original_id: journey.id,
        campaign_id: journey.campaign_id,
        stage_count: journey.journey_stages.count,
        total_duration: journey.total_duration_days,
        template_type: journey.template_type
      }
    }
    
    case format.to_s.downcase
    when 'json'
      export_data.to_json
    when 'csv'
      convert_to_csv(export_data)
    when 'yaml'
      export_data.to_yaml
    else
      raise PersistenceError, "Unsupported export format: #{format}"
    end
  end

  # Import journey from exported data
  def import_journey(import_data, options = {})
    validate_import_data!(import_data)
    
    Journey.transaction do
      imported_journey_data = import_data['journey'] || import_data[:journey]
      
      # Create new journey from imported data
      new_journey = Journey.new(
        name: options[:name] || imported_journey_data['name'] || 'Imported Journey',
        purpose: imported_journey_data['purpose'],
        goals: imported_journey_data['goals'],
        audience: imported_journey_data['audience'],
        template_type: imported_journey_data['template_type'],
        campaign: options[:campaign]
      )
      new_journey.save!
      
      # Import stages
      imported_stages = imported_journey_data['stages'] || []
      imported_stages.each_with_index do |stage_data, index|
        new_stage = JourneyStage.new(
          journey: new_journey,
          name: stage_data['name'],
          description: stage_data['description'],
          stage_type: stage_data['stage_type'],
          duration_days: stage_data['duration_days'],
          position: index,
          configuration: stage_data['configuration'] || {}
        )
        new_stage.save!
      end
      
      # Import version history if requested and available
      if options[:import_history] && import_data['version_history']
        import_service = self.class.new(journey: new_journey, user: user)
        import_data['version_history'].each do |version_data|
          import_service.store_version(version_data.with_indifferent_access)
        end
      end
      
      # Create import version entry
      import_service = self.class.new(journey: new_journey, user: user)
      import_version = import_service.create_version_snapshot(new_journey, 'imported')
      import_service.store_version(import_version)
      
      new_journey.reload
    end
  end

  # Conflict resolution methods
  def detect_conflicts(expected_version)
    current_version = get_current_version_number
    
    return nil if current_version == expected_version
    
    {
      conflict_type: 'version_mismatch',
      expected_version: expected_version,
      current_version: current_version,
      conflicting_changes: get_changes_since_version(expected_version),
      resolution_strategies: %w[use_local use_remote merge manual]
    }
  end

  def resolve_conflict(resolution_strategy, local_data, remote_data, options = {})
    case resolution_strategy.to_s
    when 'use_local'
      save_journey(local_data, options.merge(force_update: true))
    when 'use_remote'
      { success: true, data: remote_data, action: 'used_remote' }
    when 'merge'
      merged_data = merge_journey_data(local_data, remote_data)
      save_journey(merged_data, options.merge(is_merge: true))
    when 'manual'
      # Return both datasets for manual resolution
      {
        success: false,
        requires_manual_resolution: true,
        local_data: local_data,
        remote_data: remote_data,
        merge_suggestions: generate_merge_suggestions(local_data, remote_data)
      }
    else
      raise PersistenceError, "Unknown conflict resolution strategy: #{resolution_strategy}"
    end
  end

  # Auto-save functionality
  def configure_auto_save(enabled: true, interval: 5000, max_pending: 10)
    @auto_save_config = {
      enabled: enabled,
      interval: interval,
      max_pending: max_pending,
      last_save: Time.current
    }
  end

  def should_auto_save?(changes_detected = true)
    return false unless auto_save_enabled
    return false unless changes_detected
    return false if @pending_operations.length >= (@auto_save_config&.dig(:max_pending) || 10)
    
    last_save = @auto_save_config&.dig(:last_save) || Time.current
    interval = (@auto_save_config&.dig(:interval) || 5000) / 1000.0 # Convert to seconds
    
    Time.current - last_save >= interval
  end

  private

  def validate_journey_data!(journey_data)
    unless journey_data.is_a?(Hash)
      raise PersistenceError, "Journey data must be a hash"
    end
    
    unless journey_data['stages'].is_a?(Array)
      raise PersistenceError, "Journey must have stages array"
    end
    
    # Additional validation can be added here
  end

  def validate_import_data!(import_data)
    unless import_data.is_a?(Hash)
      raise PersistenceError, "Import data must be a hash"
    end
    
    unless import_data['journey'] || import_data[:journey]
      raise PersistenceError, "Import data must contain journey information"
    end
    
    # Additional validation can be added here
  end

  def check_version_conflicts!(expected_version)
    current_version = get_current_version_number
    
    if current_version != expected_version
      conflict_data = detect_conflicts(expected_version)
      raise ConflictError.new(
        "Version conflict detected. Expected: #{expected_version}, Current: #{current_version}",
        conflict_data: conflict_data,
        conflict_type: 'version_mismatch'
      )
    end
  end

  def update_journey_data(journey_data, options = {})
    # Update journey attributes
    if journey_data['name']
      journey.name = journey_data['name']
    end
    
    if journey_data['purpose']
      journey.purpose = journey_data['purpose']
    end
    
    if journey_data['audience']
      journey.audience = journey_data['audience']
    end
    
    # Save journey
    journey.save!
    
    # Update stages
    if journey_data['stages']
      update_journey_stages(journey_data['stages'])
    end
    
    journey.reload
  end

  def update_journey_stages(stages_data)
    # Remove stages not in the new data
    existing_stage_ids = journey.journey_stages.pluck(:id).map(&:to_s)
    new_stage_ids = stages_data.select { |s| s['id'] }.map { |s| s['id'].to_s.gsub(/^stage-/, '') }
    
    stages_to_remove = existing_stage_ids - new_stage_ids
    journey.journey_stages.where(id: stages_to_remove).destroy_all if stages_to_remove.any?
    
    # Update or create stages
    stages_data.each_with_index do |stage_data, index|
      stage_id = stage_data['id']&.gsub(/^stage-/, '')
      
      stage = if stage_id && journey.journey_stages.exists?(id: stage_id)
        journey.journey_stages.find(stage_id)
      else
        journey.journey_stages.build
      end
      
      stage.assign_attributes(
        name: stage_data['name'],
        description: stage_data['description'],
        stage_type: stage_data['type']&.capitalize || stage_data['stage_type'],
        duration_days: stage_data['duration_days'],
        position: index,
        configuration: stage_data['configuration'] || {}
      )
      
      stage.save!
    end
  end

  def serialize_journey_data(journey)
    {
      id: journey.id,
      name: journey.name,
      purpose: journey.purpose,
      goals: journey.goals,
      audience: journey.audience,
      template_type: journey.template_type,
      stages: journey.journey_stages.ordered.map do |stage|
        {
          id: stage.id,
          name: stage.name,
          description: stage.description,
          stage_type: stage.stage_type,
          duration_days: stage.duration_days,
          position: stage.position,
          configuration: stage.configuration,
          content_assets: stage.content_assets.map do |asset|
            {
              id: asset.id,
              content_type: asset.content_type,
              content: asset.content,
              channel: asset.channel
            }
          end
        }
      end
    }
  end

  def generate_version_number
    current_max = get_current_version_number
    current_max + 1
  end

  def get_current_version_number
    return 0 unless journey&.persisted?
    
    # This would typically be stored in a versions table
    Rails.cache.fetch("journey_#{journey.id}_current_version", expires_in: 5.minutes) do
      # In a real implementation, you'd query a versions table
      # For now, use a simple counter based on updated_at
      ((Time.current.to_f - journey.created_at.to_f) / 60).to_i + 1
    end
  end

  def find_version(version_number)
    get_version_history.find { |v| v[:version] == version_number }
  end

  def store_version_in_database(version_data)
    # In a real implementation, you'd store this in a dedicated versions table
    Rails.cache.write(
      "journey_#{journey.id}_version_#{version_data[:version]}",
      version_data,
      expires_in: 30.days
    )
    
    # Update version list
    version_list = Rails.cache.fetch("journey_#{journey.id}_versions", expires_in: 30.days) { [] }
    version_list.unshift(version_data[:version])
    version_list = version_list.uniq.first(version_limit)
    Rails.cache.write("journey_#{journey.id}_versions", version_list, expires_in: 30.days)
  end

  def load_version_history_from_database(limit)
    return [] unless journey&.persisted?
    
    version_list = Rails.cache.fetch("journey_#{journey.id}_versions", expires_in: 30.days) { [] }
    
    version_list.first(limit).map do |version_num|
      Rails.cache.read("journey_#{journey.id}_version_#{version_num}")
    end.compact
  end

  def detect_changes(old_data, new_data)
    return {} unless old_data && new_data
    
    changes = {}
    
    # Compare basic fields
    %w[name purpose goals audience].each do |field|
      if old_data[field] != new_data[field]
        changes[field] = { from: old_data[field], to: new_data[field] }
      end
    end
    
    # Compare stages
    old_stages = old_data['stages'] || []
    new_stages = new_data['stages'] || []
    
    if old_stages.length != new_stages.length
      changes['stage_count'] = { from: old_stages.length, to: new_stages.length }
    end
    
    # More detailed stage comparison could be added here
    
    changes
  end

  def merge_journey_data(local_data, remote_data)
    # Simple merge strategy - prefer local changes for conflicts
    merged = remote_data.deep_dup
    
    # Merge basic fields (prefer local)
    %w[name purpose goals audience].each do |field|
      merged[field] = local_data[field] if local_data[field].present?
    end
    
    # Merge stages (this is simplified - real merging would be more complex)
    local_stages = local_data['stages'] || []
    remote_stages = remote_data['stages'] || []
    
    # For now, just use local stages if they exist
    merged['stages'] = local_stages.any? ? local_stages : remote_stages
    
    merged
  end

  def generate_merge_suggestions(local_data, remote_data)
    suggestions = []
    
    %w[name purpose goals audience].each do |field|
      local_val = local_data[field]
      remote_val = remote_data[field]
      
      if local_val != remote_val && local_val.present? && remote_val.present?
        suggestions << {
          field: field,
          local_value: local_val,
          remote_value: remote_val,
          suggestion: 'Choose the most recent or accurate value'
        }
      end
    end
    
    suggestions
  end

  def get_changes_since_version(version_number)
    # This would return actual changes - simplified for now
    {
      versions_behind: get_current_version_number - version_number,
      summary: "#{get_current_version_number - version_number} versions behind"
    }
  end

  def convert_to_csv(data)
    require 'csv'
    
    CSV.generate do |csv|
      # Header row
      csv << ['Field', 'Value']
      
      # Journey data
      journey_data = data[:journey] || data['journey']
      csv << ['Name', journey_data['name']]
      csv << ['Purpose', journey_data['purpose']]
      csv << ['Audience', journey_data['audience']]
      
      # Stages
      stages = journey_data['stages'] || []
      stages.each_with_index do |stage, index|
        csv << ["Stage #{index + 1} Name", stage['name']]
        csv << ["Stage #{index + 1} Type", stage['stage_type']]
        csv << ["Stage #{index + 1} Duration", stage['duration_days']]
        csv << ["Stage #{index + 1} Description", stage['description']]
      end
    end
  end

  def get_client_ip
    # This would be passed in from the controller
    '127.0.0.1'
  end

  def get_user_agent
    # This would be passed in from the controller
    'Unknown'
  end

  def handle_validation_error(error, journey_data, options)
    {
      success: false,
      error: 'validation_failed',
      message: error.message,
      details: error.record.errors.full_messages
    }
  end

  def handle_stale_object_error(error, journey_data, options)
    # This indicates a concurrent modification
    raise ConflictError.new(
      'Journey was modified by another user',
      conflict_data: {
        conflict_type: 'concurrent_modification',
        message: 'The journey has been modified since you started editing'
      }
    )
  end

  def handle_generic_error(error, journey_data, options)
    {
      success: false,
      error: 'save_failed',
      message: error.message,
      retry_recommended: true
    }
  end
end