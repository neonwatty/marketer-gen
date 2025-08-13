class ContentSchedulesController < ApplicationController
  before_action :set_content_schedule, only: [:show, :edit, :update, :destroy, :duplicate, :reschedule, :schedule, :cancel, :pause, :resume]
  before_action :set_filter_options, only: [:index, :calendar, :timeline]

  # GET /content_schedules
  def index
    @content_schedules = build_schedules_query.includes(:content_item, :campaign, :publishing_queues)
    
    respond_to do |format|
      format.html { @content_schedules = @content_schedules.page(params[:page]) }
      format.json { render json: format_schedules_for_json(@content_schedules) }
    end
  end

  # GET /content_schedules/calendar
  def calendar
    @view_type = params[:view] || 'month'
    @current_date = params[:date] ? Date.parse(params[:date]) : Date.current
    
    # Get events for calendar display
    start_date, end_date = calculate_date_range(@current_date, @view_type)
    @content_schedules = build_schedules_query
                           .where(scheduled_at: start_date..end_date)
                           .includes(:content_item, :campaign)

    respond_to do |format|
      format.html
      format.json { render json: format_events_for_calendar(@content_schedules) }
    end
  end

  # GET /content_schedules/timeline
  def timeline
    @time_range = params[:time_range] || '7d'
    @group_by = params[:group_by] || 'platform'
    
    date_range = calculate_timeline_date_range(@time_range)
    @content_schedules = build_schedules_query
                           .where(scheduled_at: date_range)
                           .includes(:content_item, :campaign)

    @statistics = calculate_timeline_statistics(@content_schedules)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          events: format_events_for_timeline(@content_schedules),
          dateRange: {
            start: date_range.begin,
            end: date_range.end
          },
          statistics: @statistics
        }
      end
    end
  end

  # GET /content_schedules/1
  def show
    respond_to do |format|
      format.html
      format.json { render json: format_schedule_for_json(@content_schedule) }
    end
  end

  # GET /content_schedules/new
  def new
    @content_schedule = ContentSchedule.new
    set_form_options
  end

  # GET /content_schedules/1/edit
  def edit
    set_form_options
  end

  # POST /content_schedules
  def create
    @content_schedule = ContentSchedule.new(content_schedule_params)

    # Check for conflicts before saving
    conflicts = check_conflicts(@content_schedule)
    
    if conflicts.any? && !params[:ignore_conflicts]
      render json: {
        success: false,
        conflicts: conflicts,
        message: "Scheduling conflicts detected. Please review and confirm."
      }, status: :unprocessable_entity
      return
    end

    if @content_schedule.save
      # Auto-schedule if requested
      @content_schedule.schedule! if params[:auto_schedule] && @content_schedule.may_schedule?
      
      respond_to do |format|
        format.html { redirect_to @content_schedule, notice: 'Content schedule was successfully created.' }
        format.json { render json: format_schedule_for_json(@content_schedule), status: :created }
      end
    else
      set_form_options
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @content_schedule.errors }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /content_schedules/1
  def update
    old_scheduled_at = @content_schedule.scheduled_at
    
    if @content_schedule.update(content_schedule_params)
      
      # Handle schedule time changes
      if @content_schedule.scheduled_at != old_scheduled_at
        handle_schedule_time_change(@content_schedule, old_scheduled_at)
      end

      respond_to do |format|
        format.html { redirect_to @content_schedule, notice: 'Content schedule was successfully updated.' }
        format.json { render json: format_schedule_for_json(@content_schedule) }
      end
    else
      set_form_options
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @content_schedule.errors }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /content_schedules/1
  def destroy
    @content_schedule.cancel! if @content_schedule.may_cancel?
    @content_schedule.destroy

    respond_to do |format|
      format.html { redirect_to content_schedules_url, notice: 'Content schedule was successfully cancelled.' }
      format.json { head :no_content }
    end
  end

  # POST /content_schedules/bulk_create
  def bulk_create
    content_items = find_content_items(params[:content_item_ids])
    base_options = bulk_schedule_params
    
    results = ContentSchedule.bulk_schedule(content_items, base_options)
    
    successful = results.select(&:persisted?)
    failed = results.reject(&:persisted?)
    
    respond_to do |format|
      format.json do
        render json: {
          success: failed.empty?,
          created: successful.length,
          failed: failed.length,
          schedules: successful.map { |s| format_schedule_for_json(s) },
          errors: failed.map(&:errors)
        }
      end
    end
  end

  # POST /content_schedules/1/duplicate
  def duplicate
    new_schedule = @content_schedule.dup
    new_schedule.status = 'draft'
    new_schedule.published_at = nil
    new_schedule.scheduled_at = params[:new_scheduled_at]&.to_datetime || @content_schedule.scheduled_at + 1.day
    
    if new_schedule.save
      render json: format_schedule_for_json(new_schedule), status: :created
    else
      render json: { errors: new_schedule.errors }, status: :unprocessable_entity
    end
  end

  # POST /content_schedules/1/reschedule
  def reschedule
    new_time = params[:scheduled_at]&.to_datetime
    
    unless new_time
      render json: { error: 'New scheduled time is required' }, status: :bad_request
      return
    end
    
    old_time = @content_schedule.scheduled_at
    
    if @content_schedule.update(scheduled_at: new_time)
      handle_schedule_time_change(@content_schedule, old_time)
      render json: format_schedule_for_json(@content_schedule)
    else
      render json: { errors: @content_schedule.errors }, status: :unprocessable_entity
    end
  end

  # GET /content_schedules/conflicts
  def conflicts
    start_time = params[:start_time]&.to_datetime
    end_time = params[:end_time]&.to_datetime
    platform = params[:platform]
    exclude_id = params[:exclude_id]
    
    unless start_time && platform
      render json: { error: 'start_time and platform are required' }, status: :bad_request
      return
    end
    
    end_time ||= start_time + 5.minutes # Default 5-minute window
    
    conflicts = ContentSchedule.find_conflicts(start_time, end_time, platform, exclude_id)
    
    render json: conflicts.map { |conflict| format_schedule_for_json(conflict) }
  end

  # GET /content_schedules/available_slots
  def available_slots
    platform = params[:platform]
    date = params[:date]&.to_date || Date.current
    duration = params[:duration]&.to_i || 5
    
    unless platform
      render json: { error: 'platform is required' }, status: :bad_request
      return
    end
    
    slots = ContentSchedule.available_time_slots(platform, date, duration)
    
    render json: {
      date: date,
      platform: platform,
      available_slots: slots
    }
  end

  # POST /content_schedules/optimal_schedule
  def optimal_schedule
    content_item_ids = params[:content_item_ids] || []
    platform = params[:platform]
    start_date = params[:start_date]&.to_date || Date.current
    options = params[:options] || {}
    
    unless content_item_ids.any? && platform
      render json: { error: 'content_item_ids and platform are required' }, status: :bad_request
      return
    end
    
    content_items = find_content_items(content_item_ids)
    optimal_schedules = ContentSchedule.generate_optimal_schedule(content_items, platform, start_date, options)
    
    render json: {
      optimal_schedules: optimal_schedules,
      platform: platform,
      start_date: start_date
    }
  end

  # State management actions
  def schedule
    if @content_schedule.may_schedule?
      @content_schedule.schedule!
      render json: { success: true, status: @content_schedule.status }
    else
      render json: { error: 'Cannot schedule this content' }, status: :unprocessable_entity
    end
  end

  def cancel
    if @content_schedule.may_cancel?
      @content_schedule.cancel!
      render json: { success: true, status: @content_schedule.status }
    else
      render json: { error: 'Cannot cancel this content' }, status: :unprocessable_entity
    end
  end

  def pause
    if @content_schedule.may_pause?
      @content_schedule.pause!
      render json: { success: true, status: @content_schedule.status }
    else
      render json: { error: 'Cannot pause this content' }, status: :unprocessable_entity
    end
  end

  def resume
    if @content_schedule.may_resume?
      @content_schedule.resume!
      render json: { success: true, status: @content_schedule.status }
    else
      render json: { error: 'Cannot resume this content' }, status: :unprocessable_entity
    end
  end

  private

  def set_content_schedule
    @content_schedule = ContentSchedule.find(params[:id])
  end

  def set_filter_options
    @platforms = ContentSchedule.distinct.pluck(:platform).compact.sort
    @channels = ContentSchedule.distinct.pluck(:channel).compact.sort
    @statuses = ContentSchedule.statuses.keys
    @campaigns = Campaign.active.limit(50).pluck(:id, :name)
  end

  def set_form_options
    @platforms = ['twitter', 'instagram', 'linkedin', 'facebook', 'youtube', 'tiktok']
    @channels = ['social_media', 'email', 'web', 'ads']
    @campaigns = Campaign.active.limit(50)
    @content_items = available_content_items
    @timezones = ActiveSupport::TimeZone.all.map { |tz| [tz.name, tz.name] }
  end

  def available_content_items
    # Get content items that can be scheduled
    items = []
    
    if defined?(ContentVariant)
      items += ContentVariant.where(status: ['active', 'testing'])
                           .includes(:content_request)
                           .limit(50)
                           .map { |cv| ["Content Variant: #{cv.name}", "ContentVariant:#{cv.id}"] }
    end
    
    if defined?(ContentAsset)
      items += ContentAsset.where(status: 'active')
                         .limit(50)
                         .map { |ca| ["Content Asset: #{ca.title}", "ContentAsset:#{ca.id}"] }
    end
    
    items
  end

  def content_schedule_params
    params.require(:content_schedule).permit(
      :content_item_type, :content_item_id, :campaign_id, :channel, :platform,
      :scheduled_at, :priority, :frequency, :auto_publish, :time_zone,
      recurrence_data: {}, metadata: {}
    )
  end

  def bulk_schedule_params
    params.permit(
      :campaign_id, :channel, :platform, :scheduled_at, :priority, :frequency,
      :auto_publish, :time_zone, :stagger_minutes, :auto_schedule,
      recurrence_data: {}, metadata: {}
    )
  end

  def build_schedules_query
    query = ContentSchedule.all
    
    # Apply filters
    query = query.where(platform: params[:platform]) if params[:platform].present?
    query = query.where(channel: params[:channel]) if params[:channel].present?
    query = query.where(status: params[:status]) if params[:status].present?
    query = query.where(campaign_id: params[:campaign_id]) if params[:campaign_id].present?
    
    # Date range filter
    if params[:start_date].present? && params[:end_date].present?
      start_date = params[:start_date].to_date.beginning_of_day
      end_date = params[:end_date].to_date.end_of_day
      query = query.where(scheduled_at: start_date..end_date)
    end
    
    # Search filter
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      query = query.joins("LEFT JOIN content_variants ON content_schedules.content_item_type = 'ContentVariant' AND content_schedules.content_item_id = content_variants.id")
                   .joins("LEFT JOIN content_assets ON content_schedules.content_item_type = 'ContentAsset' AND content_schedules.content_item_id = content_assets.id")
                   .where("content_variants.content LIKE ? OR content_assets.title LIKE ? OR content_assets.content LIKE ?", 
                          search_term, search_term, search_term)
    end
    
    query.order(scheduled_at: :asc)
  end

  def calculate_date_range(current_date, view_type)
    case view_type
    when 'day'
      [current_date.beginning_of_day, current_date.end_of_day]
    when 'week'
      [current_date.beginning_of_week, current_date.end_of_week]
    when 'month'
      [current_date.beginning_of_month, current_date.end_of_month]
    else
      [current_date.beginning_of_month, current_date.end_of_month]
    end
  end

  def calculate_timeline_date_range(time_range)
    case time_range
    when '1d'
      Date.current.beginning_of_day..Date.current.end_of_day
    when '3d'
      Date.current.beginning_of_day..(Date.current + 2.days).end_of_day
    when '7d'
      Date.current.beginning_of_day..(Date.current + 6.days).end_of_day
    when '14d'
      Date.current.beginning_of_day..(Date.current + 13.days).end_of_day
    when '30d'
      Date.current.beginning_of_day..(Date.current + 29.days).end_of_day
    else
      Date.current.beginning_of_day..(Date.current + 6.days).end_of_day
    end
  end

  def format_schedules_for_json(schedules)
    schedules.map { |schedule| format_schedule_for_json(schedule) }
  end

  def format_schedule_for_json(schedule)
    {
      id: schedule.id,
      title: schedule.content_preview,
      content_preview: schedule.content_preview,
      platform: schedule.platform,
      channel: schedule.channel,
      status: schedule.status,
      priority: schedule.priority,
      scheduled_at: schedule.scheduled_at,
      published_at: schedule.published_at,
      campaign_id: schedule.campaign_id,
      campaign_name: schedule.campaign&.name,
      auto_publish: schedule.auto_publish,
      frequency: schedule.frequency,
      time_zone: schedule.time_zone,
      is_overdue: schedule.is_overdue?,
      is_upcoming: schedule.is_upcoming?,
      time_until_publish: schedule.time_until_publish,
      created_at: schedule.created_at,
      updated_at: schedule.updated_at
    }
  end

  def format_events_for_calendar(schedules)
    schedules.map do |schedule|
      {
        id: schedule.id,
        title: schedule.content_preview&.truncate(50) || 'Untitled Content',
        start: schedule.scheduled_at.iso8601,
        allDay: false,
        backgroundColor: get_platform_color(schedule.platform),
        borderColor: get_status_color(schedule.status),
        extendedProps: {
          platform: schedule.platform,
          channel: schedule.channel,
          status: schedule.status,
          priority: schedule.priority,
          campaign_name: schedule.campaign&.name,
          content: schedule.content_preview,
          autoPublish: schedule.auto_publish
        }
      }
    end
  end

  def format_events_for_timeline(schedules)
    schedules.map do |schedule|
      {
        id: schedule.id,
        title: schedule.content_preview&.truncate(30) || 'Untitled Content',
        content_preview: schedule.content_preview,
        platform: schedule.platform,
        channel: schedule.channel,
        status: schedule.status,
        priority: schedule.priority,
        scheduled_at: schedule.scheduled_at,
        campaign_name: schedule.campaign&.name,
        campaign_id: schedule.campaign_id
      }
    end
  end

  def calculate_timeline_statistics(schedules)
    {
      total: schedules.count,
      published: schedules.where(status: 'published').count,
      scheduled: schedules.where(status: 'scheduled').count,
      draft: schedules.where(status: 'draft').count,
      failed: schedules.where(status: 'failed').count,
      by_platform: schedules.group(:platform).count,
      by_channel: schedules.group(:channel).count,
      by_status: schedules.group(:status).count
    }
  end

  def get_platform_color(platform)
    colors = {
      'twitter' => '#1DA1F2',
      'instagram' => '#E4405F',
      'linkedin' => '#0077B5',
      'facebook' => '#1877F2',
      'youtube' => '#FF0000',
      'tiktok' => '#000000'
    }
    colors[platform&.downcase] || '#6B7280'
  end

  def get_status_color(status)
    colors = {
      'draft' => '#9CA3AF',
      'scheduled' => '#3B82F6',
      'published' => '#10B981',
      'failed' => '#EF4444',
      'cancelled' => '#6B7280',
      'paused' => '#F59E0B'
    }
    colors[status] || '#9CA3AF'
  end

  def check_conflicts(schedule)
    return [] unless schedule.platform.present? && schedule.scheduled_at.present?
    
    # Check for time conflicts (check 5 minutes before and after)
    time_conflicts = ContentSchedule.find_conflicts(
      schedule.scheduled_at - 5.minutes,
      schedule.scheduled_at + 5.minutes,
      schedule.platform,
      schedule.id
    )
    
    # Check platform constraints
    constraint_violations = schedule.validate_platform_constraints
    
    conflicts = []
    
    time_conflicts.each do |conflict|
      conflicts << {
        type: 'time_overlap',
        schedule: format_schedule_for_json(conflict),
        message: "Time overlap with existing content on #{conflict.platform}"
      }
    end
    
    constraint_violations.each do |violation|
      conflicts << {
        type: 'platform_constraint',
        message: violation
      }
    end
    
    conflicts
  end

  def handle_schedule_time_change(schedule, old_time)
    # Update any associated publishing queue entries
    schedule.publishing_queues.pending.update_all(scheduled_for: schedule.scheduled_at)
    
    # Log the change
    Rails.logger.info "Content schedule #{schedule.id} time changed from #{old_time} to #{schedule.scheduled_at}"
  end

  def find_content_items(content_item_ids)
    items = []
    
    content_item_ids.each do |item_id|
      type, id = item_id.split(':')
      case type
      when 'ContentVariant'
        items << ContentVariant.find(id) if defined?(ContentVariant)
      when 'ContentAsset'
        items << ContentAsset.find(id) if defined?(ContentAsset)
      end
    rescue ActiveRecord::RecordNotFound
      # Skip invalid IDs
    end
    
    items
  end
end