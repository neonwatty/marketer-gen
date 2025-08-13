require "test_helper"

class ContentSchedulesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @campaign = campaigns(:summer_launch)
    @content_schedule = ContentSchedule.create!(
      campaign: @campaign,
      content_item_type: 'ContentAsset',
      content_item_id: 1,
      platform: 'twitter',
      channel: 'social_media',
      scheduled_at: 1.hour.from_now,
      priority: 3,
      status: 'scheduled'
    )
  end

  test "should get index" do
    get content_schedules_url
    assert_response :success
  end

  test "should get index as json" do
    get content_schedules_url, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
  end

  test "should filter by platform" do
    # Create schedule with different platform
    ContentSchedule.create!(
      campaign: @campaign,
      content_item_type: 'ContentAsset',
      content_item_id: 2,
      platform: 'instagram',
      channel: 'social_media',
      scheduled_at: 2.hours.from_now,
      priority: 3
    )
    
    get content_schedules_url, params: { platform: 'twitter' }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.all? { |schedule| schedule['platform'] == 'twitter' }
  end

  test "should get calendar view" do
    get calendar_content_schedules_url
    assert_response :success
  end

  test "should get calendar data as json" do
    get calendar_content_schedules_url, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
    
    # Check event structure
    if json_response.any?
      event = json_response.first
      assert event.key?('id')
      assert event.key?('title')
      assert event.key?('start')
      assert event.key?('backgroundColor')
    end
  end

  test "should get timeline view" do
    get timeline_content_schedules_url
    assert_response :success
  end

  test "should get timeline data as json" do
    get timeline_content_schedules_url, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('events')
    assert json_response.key?('dateRange')
    assert json_response.key?('statistics')
  end

  test "should show content schedule" do
    get content_schedule_url(@content_schedule)
    assert_response :success
  end

  test "should get new" do
    get new_content_schedule_url
    assert_response :success
  end

  test "should create content schedule" do
    assert_difference('ContentSchedule.count') do
      post content_schedules_url, params: {
        content_schedule: {
          campaign_id: @campaign.id,
          content_item_type: 'ContentAsset',
          content_item_id: 1,
          platform: 'instagram',
          channel: 'social_media',
          scheduled_at: 2.hours.from_now,
          priority: 4
        }
      }
    end

    assert_redirected_to content_schedule_url(ContentSchedule.last)
  end

  test "should create content schedule as json" do
    assert_difference('ContentSchedule.count') do
      post content_schedules_url, params: {
        content_schedule: {
          campaign_id: @campaign.id,
          content_item_type: 'ContentAsset',
          content_item_id: 1,
          platform: 'instagram',
          channel: 'social_media',
          scheduled_at: 2.hours.from_now,
          priority: 4
        }
      }, as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal 'instagram', json_response['platform']
  end

  test "should detect conflicts on create" do
    # Create overlapping schedule
    post content_schedules_url, params: {
      content_schedule: {
        campaign_id: @campaign.id,
        content_item_type: 'ContentAsset',
        content_item_id: 2,
        platform: 'twitter',
        channel: 'social_media',
        scheduled_at: @content_schedule.scheduled_at + 2.minutes,
        priority: 3
      }
    }, as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response.key?('conflicts')
    assert_equal false, json_response['success']
  end

  test "should get edit" do
    get edit_content_schedule_url(@content_schedule)
    assert_response :success
  end

  test "should update content schedule" do
    patch content_schedule_url(@content_schedule), params: {
      content_schedule: {
        priority: 5,
        platform: 'linkedin'
      }
    }

    assert_redirected_to content_schedule_url(@content_schedule)
    @content_schedule.reload
    assert_equal 5, @content_schedule.priority
    assert_equal 'linkedin', @content_schedule.platform
  end

  test "should update content schedule as json" do
    patch content_schedule_url(@content_schedule), params: {
      content_schedule: {
        priority: 5,
        platform: 'linkedin'
      }
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'linkedin', json_response['platform']
    assert_equal 5, json_response['priority']
  end

  test "should destroy content schedule" do
    assert_difference('ContentSchedule.count', -1) do
      delete content_schedule_url(@content_schedule)
    end

    assert_redirected_to content_schedules_url
  end

  test "should duplicate content schedule" do
    assert_difference('ContentSchedule.count') do
      post duplicate_content_schedule_url(@content_schedule), params: {
        new_scheduled_at: 2.hours.from_now
      }, as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal @content_schedule.platform, json_response['platform']
    assert_equal 'draft', json_response['status']
  end

  test "should reschedule content schedule" do
    new_time = 3.hours.from_now
    
    post reschedule_content_schedule_url(@content_schedule), params: {
      scheduled_at: new_time
    }, as: :json

    assert_response :success
    @content_schedule.reload
    assert_in_delta new_time.to_f, @content_schedule.scheduled_at.to_f, 60.0
  end

  test "should get conflicts" do
    get conflicts_content_schedules_url, params: {
      start_time: @content_schedule.scheduled_at + 1.minute,
      platform: 'twitter'
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
  end

  test "should require start_time and platform for conflicts" do
    get conflicts_content_schedules_url, params: {
      platform: 'twitter'
    }, as: :json

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert json_response.key?('error')
  end

  test "should get available slots" do
    get available_slots_content_schedules_url, params: {
      platform: 'twitter',
      date: Date.current
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?('available_slots')
    assert json_response.key?('platform')
    assert json_response.key?('date')
  end

  test "should require platform for available slots" do
    get available_slots_content_schedules_url, as: :json

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert json_response.key?('error')
  end

  test "should generate optimal schedule" do
    post optimal_schedule_content_schedules_url, params: {
      content_item_ids: ['ContentAsset:1', 'ContentAsset:2'],
      platform: 'twitter',
      start_date: Date.current
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?('optimal_schedules')
    assert json_response.key?('platform')
    assert json_response.key?('start_date')
  end

  test "should require content_item_ids and platform for optimal schedule" do
    post optimal_schedule_content_schedules_url, params: {
      platform: 'twitter'
    }, as: :json

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert json_response.key?('error')
  end

  test "should bulk create schedules" do
    assert_difference('ContentSchedule.count', 2) do
      post bulk_create_content_schedules_url, params: {
        content_item_ids: ['ContentAsset:1', 'ContentAsset:2'],
        campaign_id: @campaign.id,
        platform: 'instagram',
        channel: 'social_media',
        scheduled_at: 2.hours.from_now,
        priority: 3,
        stagger_minutes: 30,
        time_zone: 'UTC'
      }, as: :json
    end

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal true, json_response['success']
    assert_equal 2, json_response['created']
  end

  test "should schedule content" do
    @content_schedule.update!(status: 'draft')
    
    patch schedule_content_schedule_url(@content_schedule), as: :json

    assert_response :success
    @content_schedule.reload
    assert_equal 'scheduled', @content_schedule.status
  end

  test "should cancel content" do
    @content_schedule.update!(status: 'scheduled')
    
    patch cancel_content_schedule_url(@content_schedule), as: :json

    assert_response :success
    @content_schedule.reload
    assert_equal 'cancelled', @content_schedule.status
  end

  test "should pause content" do
    @content_schedule.update!(status: 'scheduled')
    
    patch pause_content_schedule_url(@content_schedule), as: :json

    assert_response :success
    @content_schedule.reload
    assert_equal 'paused', @content_schedule.status
  end

  test "should resume content" do
    @content_schedule.update!(status: 'paused')
    
    patch resume_content_schedule_url(@content_schedule), as: :json

    assert_response :success
    @content_schedule.reload
    assert_equal 'scheduled', @content_schedule.status
  end

  test "should handle invalid state transitions" do
    @content_schedule.update!(status: 'published')
    
    patch schedule_content_schedule_url(@content_schedule), as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response.key?('error')
  end

  test "should search schedules" do
    get content_schedules_url, params: {
      search: 'test content'
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
  end

  test "should filter by date range" do
    start_date = Date.current
    end_date = Date.current + 1.week
    
    get content_schedules_url, params: {
      start_date: start_date,
      end_date: end_date
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
    
    # Check that all returned schedules are within date range
    json_response.each do |schedule|
      scheduled_date = Date.parse(schedule['scheduled_at'])
      assert scheduled_date >= start_date
      assert scheduled_date <= end_date
    end
  end

  test "should filter by status" do
    @content_schedule.update!(status: 'published')
    
    get content_schedules_url, params: {
      status: 'published'
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.all? { |schedule| schedule['status'] == 'published' }
  end

  test "should filter by campaign" do
    other_campaign = Campaign.create!(
      name: 'Other Campaign', 
      brand_identity: @campaign.brand_identity,
      purpose: 'This is a test campaign for filtering functionality'
    )
    ContentSchedule.create!(
      campaign: other_campaign,
      content_item_type: 'ContentAsset',
      content_item_id: 3,
      platform: 'twitter',
      channel: 'social_media',
      scheduled_at: 2.hours.from_now,
      priority: 3
    )
    
    get content_schedules_url, params: {
      campaign_id: @campaign.id
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.all? { |schedule| schedule['campaign_id'] == @campaign.id }
  end
end