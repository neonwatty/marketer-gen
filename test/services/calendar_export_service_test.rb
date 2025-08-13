require 'test_helper'

class CalendarExportServiceTest < ActiveSupport::TestCase
  def setup
    @campaign = campaigns(:one)
    @events_data = [
      {
        title: 'Campaign Launch',
        start_time: Time.current + 1.day,
        end_time: Time.current + 1.day + 2.hours,
        description: 'Launch the new campaign',
        event_type: 'campaign_launch',
        campaign_id: @campaign.id
      },
      {
        title: 'Content Review',
        start_time: Time.current + 3.days,
        end_time: Time.current + 3.days + 1.hour,
        description: 'Review content variants',
        event_type: 'content_review'
      }
    ]
  end

  test "should initialize with valid parameters" do
    service = CalendarExportService.new(
      events_data: @events_data,
      calendar_name: 'Test Calendar',
      timezone: 'America/New_York',
      options: { description: 'Test calendar description' }
    )
    
    assert_equal @events_data, service.events_data
    assert_equal 'Test Calendar', service.calendar_name
    assert_equal 'America/New_York', service.timezone
    assert_equal 'Test calendar description', service.options[:description]
  end

  test "should generate basic calendar export" do
    service = CalendarExportService.new(
      events_data: @events_data,
      calendar_name: 'Test Marketing Calendar'
    )
    
    result = service.generate
    
    assert_not_nil result[:data]
    assert_equal 'text/calendar', result[:content_type]
    assert result[:filename].end_with?('.ics')
    assert result[:filename].include?('test-marketing-calendar')
    
    # Check metadata
    metadata = result[:metadata]
    assert_equal 'Test Marketing Calendar', metadata[:calendar_name]
    assert_equal 2, metadata[:event_count]
    assert_equal 'UTC', metadata[:timezone]
    assert_not_nil metadata[:generated_at]
  end

  test "should generate valid ICS format" do
    service = CalendarExportService.new(
      events_data: @events_data,
      calendar_name: 'Test Calendar'
    )
    
    result = service.generate
    ics_data = result[:data]
    
    # Check ICS format structure
    assert ics_data.include?('BEGIN:VCALENDAR'), "Should start with VCALENDAR"
    assert ics_data.include?('VERSION:2.0'), "Should include version"
    assert ics_data.include?('BEGIN:VEVENT'), "Should include events"
    assert ics_data.include?('END:VEVENT'), "Should end events"
    assert ics_data.include?('END:VCALENDAR'), "Should end with VCALENDAR"
    
    # Check for our test events
    assert ics_data.include?('Campaign Launch'), "Should include first event"
    assert ics_data.include?('Content Review'), "Should include second event"
  end

  test "should export campaign schedule" do
    result = CalendarExportService.export_campaign_schedule(@campaign)
    
    assert_not_nil result[:data]
    assert_equal 'text/calendar', result[:content_type]
    assert result[:filename].include?(@campaign.name.parameterize)
    
    ics_data = result[:data]
    
    # Should include campaign events if campaign has dates
    if @campaign.start_date
      assert ics_data.include?('Campaign Launch'), "Should include campaign launch event"
    end
  end

  test "should export content publishing schedule" do
    # Create mock content variants
    content_variants = []
    if defined?(ContentVariant)
      content_variants = [
        OpenStruct.new(
          id: 1,
          name: 'Test Content 1',
          variant_number: 1,
          strategy_type: 'tone_variation',
          status: 'active',
          content: 'Test content',
          created_at: Time.current - 1.day,
          testing_started_at: Time.current + 1.day,
          testing_completed_at: nil
        )
      ]
    end
    
    result = CalendarExportService.export_content_publishing_schedule(content_variants)
    
    assert_not_nil result[:data]
    assert_equal 'text/calendar', result[:content_type]
    
    if content_variants.any?
      ics_data = result[:data]
      assert ics_data.include?('Content Publish'), "Should include content publishing event"
    end
  end

  test "should export journey schedule" do
    # Create mock journeys
    journeys = [
      OpenStruct.new(
        id: 1,
        name: 'Test Journey',
        description: 'Test journey description',
        status: 'active',
        created_at: Time.current,
        journey_stages: []
      )
    ]
    
    # Mock the journey_stages method
    journeys.first.define_singleton_method(:journey_stages) do
      []
    end
    
    result = CalendarExportService.export_journey_schedule(journeys)
    
    assert_not_nil result[:data]
    assert_equal 'text/calendar', result[:content_type]
    
    ics_data = result[:data]
    assert ics_data.include?('Journey Launch'), "Should include journey launch event"
    assert ics_data.include?('Test Journey'), "Should include journey name"
  end

  test "should export comprehensive schedule" do
    # Create mock data
    campaigns = [@campaign]
    content_variants = []
    journeys = []
    
    result = CalendarExportService.export_comprehensive_schedule(
      campaigns: campaigns,
      content_variants: content_variants,
      journeys: journeys
    )
    
    assert_not_nil result[:data]
    assert_equal 'text/calendar', result[:content_type]
    assert result[:metadata][:calendar_name] == 'Marketing Comprehensive Schedule'
  end

  test "should generate to file" do
    service = CalendarExportService.new(
      events_data: @events_data,
      calendar_name: 'Test Calendar'
    )
    
    temp_file = Tempfile.new(['test_calendar', '.ics'])
    
    begin
      filepath = service.generate_to_file(temp_file.path)
      
      assert_equal temp_file.path, filepath
      assert File.exist?(filepath)
      
      content = File.read(filepath)
      assert content.length > 0
      assert content.include?('BEGIN:VCALENDAR')
      assert content.include?('Campaign Launch')
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  test "should handle empty events gracefully" do
    service = CalendarExportService.new(
      events_data: [],
      calendar_name: 'Empty Calendar'
    )
    
    result = service.generate
    
    assert_not_nil result[:data]
    assert_equal 'text/calendar', result[:content_type]
    assert_equal 0, result[:metadata][:event_count]
    
    # Should still be valid ICS format
    ics_data = result[:data]
    assert ics_data.include?('BEGIN:VCALENDAR')
    assert ics_data.include?('END:VCALENDAR')
  end

  test "should handle timezone correctly" do
    service = CalendarExportService.new(
      events_data: @events_data,
      calendar_name: 'Timezone Test',
      timezone: 'America/New_York'
    )
    
    result = service.generate
    ics_data = result[:data]
    
    # Should include timezone information
    assert ics_data.include?('X-WR-TIMEZONE:America/New_York')
  end

  test "should include custom properties" do
    events_with_custom_props = [
      {
        title: 'Campaign Event',
        start_time: Time.current + 1.day,
        end_time: Time.current + 1.day + 1.hour,
        campaign_id: @campaign.id,
        content_type: 'social_media',
        platform: 'twitter',
        priority: 'high',
        status: 'active'
      }
    ]
    
    service = CalendarExportService.new(
      events_data: events_with_custom_props,
      calendar_name: 'Custom Props Test'
    )
    
    result = service.generate
    ics_data = result[:data]
    
    # Should include custom properties
    assert ics_data.include?('X-CAMPAIGN-ID'), "Should include campaign ID property"
    assert ics_data.include?('X-CONTENT-TYPE'), "Should include content type property"
    assert ics_data.include?('X-PLATFORM'), "Should include platform property"
  end

  test "should handle recurrence rules" do
    recurring_event = {
      title: 'Weekly Content Review',
      start_time: Time.current + 1.day,
      end_time: Time.current + 1.day + 1.hour,
      recurrence: {
        frequency: 'WEEKLY',
        interval: 1,
        count: 4
      }
    }
    
    service = CalendarExportService.new(
      events_data: [recurring_event],
      calendar_name: 'Recurrence Test'
    )
    
    result = service.generate
    ics_data = result[:data]
    
    # Should include recurrence rule
    assert ics_data.include?('RRULE:'), "Should include recurrence rule"
    assert ics_data.include?('FREQ=WEEKLY'), "Should include frequency"
    assert ics_data.include?('COUNT=4'), "Should include count"
  end

  test "should add reminders" do
    event_with_reminder = {
      title: 'Important Campaign Milestone',
      start_time: Time.current + 1.day,
      end_time: Time.current + 1.day + 1.hour,
      reminder: {
        minutes_before: 30,
        message: 'Campaign milestone approaching'
      }
    }
    
    service = CalendarExportService.new(
      events_data: [event_with_reminder],
      calendar_name: 'Reminder Test'
    )
    
    result = service.generate
    ics_data = result[:data]
    
    # Should include alarm/reminder
    assert ics_data.include?('BEGIN:VALARM'), "Should include alarm"
    assert ics_data.include?('ACTION:DISPLAY'), "Should include display action"
    assert ics_data.include?('-PT30M'), "Should include 30 minute reminder"
  end

  test "should generate proper filename" do
    service = CalendarExportService.new(
      events_data: @events_data,
      calendar_name: 'Test Calendar with Spaces'
    )
    
    result = service.generate
    filename = result[:filename]
    
    assert filename.include?('test-calendar-with-spaces')
    assert filename.end_with?('.ics')
    assert filename.match?(/\d{8}_\d{6}/) # Should include timestamp
  end

  test "should handle invalid datetime gracefully" do
    invalid_event = {
      title: 'Invalid Date Event',
      start_time: 'invalid-date',
      end_time: nil,
      description: 'Test event with invalid date'
    }
    
    service = CalendarExportService.new(
      events_data: [invalid_event],
      calendar_name: 'Invalid Date Test'
    )
    
    result = service.generate
    
    # Should not crash and should generate valid calendar
    assert_not_nil result[:data]
    assert_equal 'text/calendar', result[:content_type]
    
    ics_data = result[:data]
    assert ics_data.include?('Invalid Date Event'), "Should include event title"
  end

  test "should build campaign events correctly" do
    # Test with campaign that has start and end dates
    campaign_with_dates = Campaign.new(
      id: 999,
      name: 'Test Campaign with Dates',
      purpose: 'Test purpose',
      status: 'active',
      start_date: Date.current + 1.day,
      end_date: Date.current + 30.days
    )
    
    # Mock duration_days method
    def campaign_with_dates.duration_days
      29
    end
    
    events = CalendarExportService.build_campaign_events(campaign_with_dates)
    
    assert events.length >= 2, "Should have start and end events"
    
    start_event = events.find { |e| e[:title].include?('Launch') }
    end_event = events.find { |e| e[:title].include?('End') }
    
    assert_not_nil start_event, "Should have campaign launch event"
    assert_not_nil end_event, "Should have campaign end event"
    
    assert_equal campaign_with_dates.id, start_event[:campaign_id]
    assert_equal 'campaign_launch', start_event[:event_type]
  end

  test "should include categories for filtering" do
    categorized_event = {
      title: 'Categorized Event',
      start_time: Time.current + 1.day,
      end_time: Time.current + 1.day + 1.hour,
      event_type: 'campaign_launch',
      campaign_name: 'Test Campaign'
    }
    
    service = CalendarExportService.new(
      events_data: [categorized_event],
      calendar_name: 'Category Test'
    )
    
    result = service.generate
    ics_data = result[:data]
    
    # Should include categories
    assert ics_data.include?('CATEGORIES:'), "Should include categories"
  end

  test "should validate generated ICS with icalendar gem" do
    service = CalendarExportService.new(
      events_data: @events_data,
      calendar_name: 'Validation Test'
    )
    
    result = service.generate
    ics_data = result[:data]
    
    # Try to parse the generated ICS with the icalendar gem
    begin
      parsed_calendar = Icalendar::Calendar.parse(ics_data).first
      
      assert_not_nil parsed_calendar, "Should be parseable by icalendar gem"
      assert parsed_calendar.events.length > 0, "Should have events"
      
      first_event = parsed_calendar.events.first
      assert_not_nil first_event.summary, "Event should have summary"
      assert_not_nil first_event.dtstart, "Event should have start time"
    rescue => e
      flunk "Generated ICS should be valid: #{e.message}"
    end
  end
end