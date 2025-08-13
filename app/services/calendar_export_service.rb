require 'icalendar'
require 'icalendar/tzinfo'

class CalendarExportService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :events_data, :calendar_name, :timezone, :options

  def initialize(events_data:, calendar_name: 'Marketing Calendar', timezone: 'UTC', options: {})
    @events_data = events_data || []
    @calendar_name = calendar_name
    @timezone = timezone
    @options = options || {}
  end

  def generate
    calendar = create_calendar
    add_events_to_calendar(calendar)
    
    {
      data: calendar.to_ical,
      filename: generate_filename,
      content_type: 'text/calendar',
      metadata: {
        calendar_name: calendar_name,
        event_count: events_data.length,
        timezone: timezone,
        generated_at: Time.current
      }
    }
  end

  def generate_to_file(filepath)
    result = generate
    File.write(filepath, result[:data])
    filepath
  end

  # Static methods for different calendar types
  def self.export_campaign_schedule(campaign, options: {})
    events_data = build_campaign_events(campaign)
    
    new(
      events_data: events_data,
      calendar_name: "#{campaign.name} - Campaign Schedule",
      timezone: options[:timezone] || 'UTC',
      options: options
    ).generate
  end

  def self.export_content_publishing_schedule(content_variants, options: {})
    events_data = build_content_publishing_events(content_variants)
    
    new(
      events_data: events_data,
      calendar_name: 'Content Publishing Schedule',
      timezone: options[:timezone] || 'UTC',
      options: options
    ).generate
  end

  def self.export_journey_schedule(journeys, options: {})
    events_data = build_journey_events(journeys)
    
    new(
      events_data: events_data,
      calendar_name: 'Customer Journey Schedule',
      timezone: options[:timezone] || 'UTC',
      options: options
    ).generate
  end

  def self.export_brand_asset_deadlines(brand_assets, options: {})
    events_data = build_brand_asset_events(brand_assets)
    
    new(
      events_data: events_data,
      calendar_name: 'Brand Asset Deadlines',
      timezone: options[:timezone] || 'UTC',
      options: options
    ).generate
  end

  def self.export_comprehensive_schedule(campaigns: [], content_variants: [], journeys: [], options: {})
    events_data = []
    events_data += build_campaign_events_from_array(campaigns) if campaigns.any?
    events_data += build_content_publishing_events(content_variants) if content_variants.any?
    events_data += build_journey_events(journeys) if journeys.any?
    
    new(
      events_data: events_data,
      calendar_name: 'Marketing Comprehensive Schedule',
      timezone: options[:timezone] || 'UTC',
      options: options
    ).generate
  end

  private

  def create_calendar
    cal = Icalendar::Calendar.new
    
    # Set calendar properties
    cal.x_wr_calname = calendar_name
    cal.x_wr_timezone = timezone
    cal.x_wr_caldesc = options[:description] || "Marketing calendar exported from Marketing Campaign Platform"
    
    # Add timezone information
    if timezone != 'UTC'
      tz = TZInfo::Timezone.get(timezone)
      cal.add_timezone tz.ical_timezone(Time.current.beginning_of_year)
    end
    
    cal
  end

  def add_events_to_calendar(calendar)
    events_data.each do |event_data|
      event = create_event(event_data)
      calendar.add_event(event) if event
    end
  end

  def create_event(event_data)
    return nil unless event_data[:start_time] && event_data[:title]

    event = Icalendar::Event.new
    
    # Required fields
    event.dtstart = parse_datetime(event_data[:start_time])
    event.dtend = parse_datetime(event_data[:end_time] || event_data[:start_time])
    event.summary = event_data[:title]
    
    # Optional fields
    event.description = event_data[:description] if event_data[:description]
    event.location = event_data[:location] if event_data[:location]
    event.url = event_data[:url] if event_data[:url]
    
    # Set UID for uniqueness
    event.uid = event_data[:uid] || generate_uid(event_data)
    
    # Set created and last modified timestamps
    event.created = Time.current
    event.last_modified = Time.current
    
    # Add custom properties
    add_custom_properties(event, event_data)
    
    # Set recurrence if specified
    add_recurrence_rules(event, event_data[:recurrence]) if event_data[:recurrence]
    
    # Set alarm/reminder if specified
    add_alarm(event, event_data[:reminder]) if event_data[:reminder]
    
    event
  end

  def parse_datetime(datetime_value)
    case datetime_value
    when String
      Time.parse(datetime_value)
    when Date
      datetime_value.to_time
    when Time, DateTime
      datetime_value
    else
      Time.current
    end
  rescue ArgumentError
    Time.current
  end

  def generate_uid(event_data)
    base_string = "#{event_data[:title]}-#{event_data[:start_time]}-#{calendar_name}"
    "#{Digest::MD5.hexdigest(base_string)}@marketing-platform.local"
  end

  def add_custom_properties(event, event_data)
    # Add marketing-specific custom properties
    if event_data[:campaign_id]
      event.add_custom_property('X-CAMPAIGN-ID', event_data[:campaign_id])
    end
    
    if event_data[:content_type]
      event.add_custom_property('X-CONTENT-TYPE', event_data[:content_type])
    end
    
    if event_data[:platform]
      event.add_custom_property('X-PLATFORM', event_data[:platform])
    end
    
    if event_data[:priority]
      event.add_custom_property('X-PRIORITY', event_data[:priority])
    end
    
    if event_data[:status]
      event.add_custom_property('X-STATUS', event_data[:status])
    end
    
    # Add categories for filtering
    categories = []
    categories << event_data[:event_type] if event_data[:event_type]
    categories << event_data[:campaign_name] if event_data[:campaign_name]
    event.categories = categories.join(',') if categories.any?
  end

  def add_recurrence_rules(event, recurrence_config)
    return unless recurrence_config.is_a?(Hash)
    
    freq = recurrence_config[:frequency]&.upcase
    return unless %w[DAILY WEEKLY MONTHLY YEARLY].include?(freq)
    
    rrule = "FREQ=#{freq}"
    
    if recurrence_config[:interval]
      rrule += ";INTERVAL=#{recurrence_config[:interval]}"
    end
    
    if recurrence_config[:count]
      rrule += ";COUNT=#{recurrence_config[:count]}"
    elsif recurrence_config[:until]
      until_date = parse_datetime(recurrence_config[:until]).strftime('%Y%m%dT%H%M%SZ')
      rrule += ";UNTIL=#{until_date}"
    end
    
    if recurrence_config[:by_day]
      by_day = Array(recurrence_config[:by_day]).join(',')
      rrule += ";BYDAY=#{by_day}"
    end
    
    event.rrule = rrule
  end

  def add_alarm(event, reminder_config)
    return unless reminder_config
    
    alarm = Icalendar::Alarm.new
    alarm.action = 'DISPLAY'
    
    # Set reminder time
    if reminder_config.is_a?(Hash)
      minutes_before = reminder_config[:minutes_before] || 15
      alarm.summary = reminder_config[:message] || event.summary
    else
      minutes_before = 15
      alarm.summary = event.summary
    end
    
    alarm.trigger = "-PT#{minutes_before}M"
    event.add_alarm(alarm)
  end

  def generate_filename
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    safe_name = calendar_name.parameterize
    "#{safe_name}_#{timestamp}.ics"
  end

  # Event building methods for different data types
  def self.build_campaign_events(campaign)
    events = []
    
    # Campaign start event
    if campaign.start_date
      events << {
        title: "Campaign Launch: #{campaign.name}",
        description: "Campaign '#{campaign.name}' launches today. #{campaign.purpose}",
        start_time: campaign.start_date,
        end_time: campaign.start_date.end_of_day,
        event_type: 'campaign_launch',
        campaign_id: campaign.id,
        campaign_name: campaign.name,
        priority: 'high',
        status: campaign.status,
        uid: "campaign-start-#{campaign.id}@marketing-platform.local"
      }
    end
    
    # Campaign end event
    if campaign.end_date
      events << {
        title: "Campaign End: #{campaign.name}",
        description: "Campaign '#{campaign.name}' ends today.",
        start_time: campaign.end_date,
        end_time: campaign.end_date.end_of_day,
        event_type: 'campaign_end',
        campaign_id: campaign.id,
        campaign_name: campaign.name,
        priority: 'medium',
        status: campaign.status,
        uid: "campaign-end-#{campaign.id}@marketing-platform.local"
      }
    end
    
    # Milestone events (if campaign has progress tracking)
    if campaign.respond_to?(:duration_days) && campaign.duration_days && campaign.start_date
      add_milestone_events(events, campaign)
    end
    
    events
  end

  def self.build_campaign_events_from_array(campaigns)
    events = []
    campaigns.each { |campaign| events += build_campaign_events(campaign) }
    events
  end

  def self.add_milestone_events(events, campaign)
    return unless campaign.duration_days > 7
    
    # Add milestone at 25%, 50%, 75% of campaign duration
    [0.25, 0.5, 0.75].each do |percentage|
      milestone_date = campaign.start_date + (campaign.duration_days * percentage).days
      next if milestone_date > campaign.end_date
      
      events << {
        title: "Campaign Milestone: #{campaign.name} (#{(percentage * 100).to_i}%)",
        description: "#{(percentage * 100).to_i}% milestone for campaign '#{campaign.name}'",
        start_time: milestone_date,
        end_time: milestone_date.end_of_day,
        event_type: 'campaign_milestone',
        campaign_id: campaign.id,
        campaign_name: campaign.name,
        priority: 'low',
        status: campaign.status,
        uid: "campaign-milestone-#{percentage}-#{campaign.id}@marketing-platform.local"
      }
    end
  end

  def self.build_content_publishing_events(content_variants)
    events = []
    
    content_variants.each do |variant|
      # Use testing_started_at or created_at as the publish date
      publish_date = variant.respond_to?(:testing_started_at) ? variant.testing_started_at : variant.created_at
      next unless publish_date
      
      events << {
        title: "Content Publish: #{variant.name || "Variant #{variant.variant_number}"}",
        description: build_content_description(variant),
        start_time: publish_date,
        end_time: publish_date + 1.hour,
        event_type: 'content_publish',
        campaign_id: variant.respond_to?(:campaign_id) ? variant.campaign_id : nil,
        content_type: variant.respond_to?(:strategy_type) ? variant.strategy_type : 'content',
        priority: variant.respond_to?(:performance_score) && variant.performance_score && variant.performance_score > 0.7 ? 'high' : 'medium',
        status: variant.status,
        uid: "content-publish-#{variant.id}@marketing-platform.local"
      }
      
      # Add testing completion event if applicable
      if variant.respond_to?(:testing_completed_at) && variant.testing_completed_at
        events << {
          title: "Content Testing Complete: #{variant.name || "Variant #{variant.variant_number}"}",
          description: "A/B testing completed for #{variant.name || "variant #{variant.variant_number}"}",
          start_time: variant.testing_completed_at,
          end_time: variant.testing_completed_at + 30.minutes,
          event_type: 'content_testing_complete',
          campaign_id: variant.respond_to?(:campaign_id) ? variant.campaign_id : nil,
          content_type: variant.respond_to?(:strategy_type) ? variant.strategy_type : 'content',
          priority: 'low',
          status: variant.status,
          uid: "content-testing-complete-#{variant.id}@marketing-platform.local"
        }
      end
    end
    
    events
  end

  def self.build_content_description(variant)
    description = []
    
    if variant.respond_to?(:strategy_type) && variant.strategy_type
      description << "Strategy: #{variant.strategy_type.humanize}"
    end
    
    if variant.respond_to?(:performance_score) && variant.performance_score
      description << "Performance Score: #{variant.performance_score.round(3)}"
    end
    
    if variant.respond_to?(:content) && variant.content
      preview = variant.content.length > 100 ? "#{variant.content[0, 100]}..." : variant.content
      description << "Content: #{preview}"
    end
    
    description.join("\n")
  end

  def self.build_journey_events(journeys)
    events = []
    
    journeys.each do |journey|
      # Journey start event
      events << {
        title: "Journey Launch: #{journey.name || 'Unnamed Journey'}",
        description: build_journey_description(journey),
        start_time: journey.created_at,
        end_time: journey.created_at + 1.hour,
        event_type: 'journey_launch',
        campaign_id: journey.respond_to?(:campaign_id) ? journey.campaign_id : nil,
        priority: 'medium',
        status: journey.respond_to?(:status) ? journey.status : 'active',
        uid: "journey-launch-#{journey.id}@marketing-platform.local"
      }
      
      # Add stage-specific events if journey has stages
      if journey.respond_to?(:journey_stages) && journey.journey_stages.any?
        add_journey_stage_events(events, journey)
      end
    end
    
    events
  end

  def self.build_journey_description(journey)
    description = []
    
    if journey.respond_to?(:description) && journey.description
      description << journey.description
    end
    
    if journey.respond_to?(:total_stages)
      description << "Total Stages: #{journey.total_stages}"
    end
    
    if journey.respond_to?(:priority)
      description << "Priority: #{journey.priority}"
    end
    
    description.join("\n")
  end

  def self.add_journey_stage_events(events, journey)
    journey.journey_stages.each_with_index do |stage, index|
      # Estimate stage timing based on journey creation date
      stage_date = journey.created_at + (index * 7).days # Weekly stages
      
      events << {
        title: "Journey Stage: #{stage.name || "Stage #{index + 1}"}",
        description: "Stage #{index + 1} of journey '#{journey.name}': #{stage.respond_to?(:description) ? stage.description : 'Stage execution'}",
        start_time: stage_date,
        end_time: stage_date + 2.hours,
        event_type: 'journey_stage',
        campaign_id: journey.respond_to?(:campaign_id) ? journey.campaign_id : nil,
        priority: 'low',
        status: stage.respond_to?(:status) ? stage.status : 'pending',
        uid: "journey-stage-#{journey.id}-#{index}@marketing-platform.local"
      }
    end
  end

  def self.build_brand_asset_events(brand_assets)
    events = []
    
    brand_assets.each do |asset|
      # Asset creation/upload event
      events << {
        title: "Brand Asset: #{asset.name || 'Unnamed Asset'}",
        description: build_asset_description(asset),
        start_time: asset.created_at,
        end_time: asset.created_at + 30.minutes,
        event_type: 'brand_asset_upload',
        content_type: asset.respond_to?(:asset_type) ? asset.asset_type : 'asset',
        priority: 'low',
        status: asset.respond_to?(:status) ? asset.status : 'active',
        uid: "brand-asset-#{asset.id}@marketing-platform.local"
      }
      
      # Add deadline event if asset has an expiration or deadline
      if asset.respond_to?(:expires_at) && asset.expires_at
        events << {
          title: "Asset Expires: #{asset.name || 'Unnamed Asset'}",
          description: "Brand asset '#{asset.name}' expires today",
          start_time: asset.expires_at,
          end_time: asset.expires_at.end_of_day,
          event_type: 'brand_asset_deadline',
          content_type: asset.respond_to?(:asset_type) ? asset.asset_type : 'asset',
          priority: 'high',
          status: asset.respond_to?(:status) ? asset.status : 'active',
          uid: "brand-asset-deadline-#{asset.id}@marketing-platform.local"
        }
      end
    end
    
    events
  end

  def self.build_asset_description(asset)
    description = []
    
    if asset.respond_to?(:description) && asset.description
      description << asset.description
    end
    
    if asset.respond_to?(:asset_type)
      description << "Type: #{asset.asset_type&.humanize}"
    end
    
    if asset.respond_to?(:file_size) && asset.file_size
      description << "Size: #{format_file_size(asset.file_size)}"
    end
    
    description.join("\n")
  end

  def self.format_file_size(size_in_bytes)
    return 'N/A' unless size_in_bytes.is_a?(Numeric)

    units = ['B', 'KB', 'MB', 'GB']
    size = size_in_bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end
end