class ContentArchivalSystem
  attr_reader :errors

  def initialize
    @errors = []
  end

  def archive_content(archive_request)
    archive_id = SecureRandom.uuid
    storage_location = generate_storage_location(archive_request[:archive_level])
    metadata_backup_location = "#{storage_location}/metadata.json"

    archive_record = {
      archive_id: archive_id,
      content_id: archive_request[:content_id],
      archive_reason: archive_request[:archive_reason],
      retention_period: archive_request[:retention_period] || "7_years",
      archive_level: archive_request[:archive_level] || "cold_storage",
      storage_location: storage_location,
      metadata_backup_location: metadata_backup_location,
      archived_at: Time.current,
      status: "archived"
    }

    {
      success: true,
      archive_id: archive_id,
      storage_location: storage_location,
      metadata_backup_location: metadata_backup_location,
      archived_at: Time.current
    }
  rescue => e
    @errors << e.message
    raise e
  end

  def restore_content(content_id, requested_by:, restore_reason:)
    begin
      restoration_time = estimate_restoration_time(content_id)

      {
        success: true,
        content_id: content_id,
        requested_by: requested_by.id,
        restore_reason: restore_reason,
        restoration_time: restoration_time,
        estimated_completion: Time.current + restoration_time,
        restore_job_id: SecureRandom.uuid
      }
    rescue => e
      @errors << e.message
      { success: false, error: e.message }
    end
  end

  def get_archived_content(content_id)
    # Simulate archived content metadata
    {
      content_id: content_id,
      is_archived: true,
      archived_at: 30.days.ago,
      archive_level: "cold_storage",
      metadata: {
        title: "Archived Content Item",
        content_type: "email_template",
        original_size: "15.2 KB",
        tags: [ "archived", "email", "marketing" ]
      },
      content_body: nil, # Content body not immediately accessible in archive
      restoration_available: true,
      retention_expires_at: 6.years.from_now
    }
  end

  def get_content(content_id)
    # Return content that has been restored or is not archived
    {
      content_id: content_id,
      is_archived: false,
      title: "Restored Content Item",
      content_body: "This is the restored content body...",
      restored_at: 1.hour.ago,
      restoration_reason: "Need for new campaign"
    }
  end

  def list_archived_content(filters = {})
    archived_items = []

    # Simulate multiple archived content items
    5.times do |i|
      archived_items << {
        content_id: SecureRandom.uuid,
        title: "Archived Content #{i + 1}",
        archive_level: [ "hot_storage", "warm_storage", "cold_storage", "deep_archive" ].sample,
        archived_at: rand(1..365).days.ago,
        retention_expires_at: rand(1..7).years.from_now,
        size_mb: rand(1.0..50.0).round(2)
      }
    end

    # Apply filters if provided
    if filters[:archive_level]
      archived_items = archived_items.select { |item| item[:archive_level] == filters[:archive_level] }
    end

    if filters[:archived_after]
      archived_items = archived_items.select { |item| item[:archived_at] >= filters[:archived_after] }
    end

    {
      archived_content: archived_items,
      total_count: archived_items.length,
      total_size_mb: archived_items.sum { |item| item[:size_mb] }.round(2)
    }
  end

  def get_archive_statistics
    {
      total_archived_items: 127,
      total_storage_size_gb: 2.8,
      storage_breakdown: {
        hot_storage: { count: 15, size_gb: 0.5 },
        warm_storage: { count: 35, size_gb: 0.8 },
        cold_storage: { count: 62, size_gb: 1.2 },
        deep_archive: { count: 15, size_gb: 0.3 }
      },
      recent_archives: 8,
      recent_restorations: 3,
      expiring_soon: 5 # Items expiring in next 30 days
    }
  end

  def extend_retention(content_id, new_expiry_date:, extended_by:, reason:)
    {
      success: true,
      content_id: content_id,
      old_expiry_date: 2.years.from_now,
      new_expiry_date: new_expiry_date,
      extended_by: extended_by.id,
      extension_reason: reason,
      extended_at: Time.current
    }
  end

  def bulk_archive(content_ids, archive_options)
    results = []

    content_ids.each do |content_id|
      archive_request = archive_options.merge(content_id: content_id)
      result = archive_content(archive_request)
      results << { content_id: content_id, result: result }
    end

    {
      success: results.all? { |r| r[:result][:success] },
      archived_count: results.count { |r| r[:result][:success] },
      failed_count: results.count { |r| !r[:result][:success] },
      results: results
    }
  end

  private

  def generate_storage_location(archive_level)
    level_path = archive_level || "cold_storage"
    date_path = Date.current.strftime("%Y/%m")
    "archives/#{level_path}/#{date_path}/#{SecureRandom.hex(8)}"
  end

  def estimate_restoration_time(content_id)
    # Simulate different restoration times based on archive level
    archive_levels = [ "hot_storage", "warm_storage", "cold_storage", "deep_archive" ]
    level = archive_levels.sample

    case level
    when "hot_storage"
      1.minute
    when "warm_storage"
      5.minutes
    when "cold_storage"
      2.hours
    when "deep_archive"
      24.hours
    else
      1.hour
    end
  end
end
