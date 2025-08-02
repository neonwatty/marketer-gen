class AbTestsController < ApplicationController
  include ActivityTracker
  
  before_action :authenticate_user!
  before_action :set_ab_test, only: [:show, :edit, :update, :destroy, :start, :pause, :resume, :complete, :results, :analysis]
  before_action :set_campaign, only: [:index, :new, :create]
  
  # Dashboard overview
  def index
    @active_tests = current_user.ab_tests.active.includes(:ab_test_variants, :winner_variant, :campaign)
    @completed_tests = current_user.ab_tests.completed.includes(:ab_test_variants, :winner_variant, :campaign).limit(10)
    @draft_tests = current_user.ab_tests.where(status: 'draft').includes(:ab_test_variants, :campaign).limit(5)
    
    # Dashboard metrics
    @dashboard_metrics = {
      total_tests: current_user.ab_tests.count,
      running_tests: current_user.ab_tests.running.count,
      completed_tests: current_user.ab_tests.completed.count,
      tests_with_winners: current_user.ab_tests.where.not(winner_variant: nil).count,
      average_conversion_rate: calculate_average_conversion_rate,
      total_visitors: current_user.ab_tests.joins(:ab_test_variants).sum('ab_test_variants.total_visitors')
    }
    
    respond_to do |format|
      format.html
      format.json { 
        render json: {
          active_tests: @active_tests.map(&:performance_report),
          completed_tests: @completed_tests.map(&:performance_report),
          draft_tests: @draft_tests.map(&:performance_report),
          metrics: @dashboard_metrics
        }
      }
    end
  end

  def show
    @performance_data = @ab_test.performance_report
    @statistical_analysis = @ab_test.calculate_statistical_significance
    @variant_comparisons = @ab_test.variant_comparison
    @insights = @ab_test.generate_insights
    @recommendations = @ab_test.ab_test_recommendations.recent.limit(5)
    
    respond_to do |format|
      format.html
      format.json { 
        render json: {
          test: @performance_data,
          analysis: @statistical_analysis,
          comparisons: @variant_comparisons,
          insights: @insights,
          recommendations: @recommendations.map(&:as_json)
        }
      }
    end
  end

  def new
    @ab_test = (@campaign || current_user).ab_tests.build
    @ab_test.ab_test_variants.build(is_control: true, name: 'Control', traffic_percentage: 50)
    @ab_test.ab_test_variants.build(is_control: false, name: 'Treatment', traffic_percentage: 50)
    
    @journeys = current_user.journeys.published
    @test_templates = AbTestTemplate.active.order(:name)
  end

  def create
    @ab_test = (@campaign || current_user).ab_tests.build(ab_test_params)
    @ab_test.user = current_user
    
    if @ab_test.save
      track_activity('ab_test_created', { test_name: @ab_test.name, test_id: @ab_test.id })
      
      respond_to do |format|
        format.html { redirect_to @ab_test, notice: 'A/B test was successfully created.' }
        format.json { render json: { test: @ab_test.performance_report, message: 'Test created successfully' } }
      end
    else
      @journeys = current_user.journeys.published
      @test_templates = AbTestTemplate.active.order(:name)
      
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @ab_test.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @journeys = current_user.journeys.published
  end

  def update
    if @ab_test.update(ab_test_params)
      track_activity('ab_test_updated', { test_name: @ab_test.name, test_id: @ab_test.id })
      
      respond_to do |format|
        format.html { redirect_to @ab_test, notice: 'A/B test was successfully updated.' }
        format.json { render json: { test: @ab_test.performance_report, message: 'Test updated successfully' } }
      end
    else
      @journeys = current_user.journeys.published
      
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @ab_test.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    test_name = @ab_test.name
    @ab_test.destroy!
    
    track_activity('ab_test_deleted', { test_name: test_name })
    
    respond_to do |format|
      format.html { redirect_to ab_tests_url, notice: 'A/B test was successfully deleted.' }
      format.json { render json: { message: 'Test deleted successfully' } }
    end
  end

  # Test lifecycle actions
  def start
    if @ab_test.start!
      track_activity('ab_test_started', { test_name: @ab_test.name, test_id: @ab_test.id })
      
      respond_to do |format|
        format.html { redirect_to @ab_test, notice: 'A/B test has been started.' }
        format.json { render json: { test: @ab_test.performance_report, message: 'Test started successfully' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @ab_test, alert: 'Unable to start A/B test. Please check configuration.' }
        format.json { render json: { errors: ['Unable to start test'] }, status: :unprocessable_entity }
      end
    end
  end

  def pause
    @ab_test.pause!
    track_activity('ab_test_paused', { test_name: @ab_test.name, test_id: @ab_test.id })
    
    respond_to do |format|
      format.html { redirect_to @ab_test, notice: 'A/B test has been paused.' }
      format.json { render json: { test: @ab_test.performance_report, message: 'Test paused successfully' } }
    end
  end

  def resume
    if @ab_test.resume!
      track_activity('ab_test_resumed', { test_name: @ab_test.name, test_id: @ab_test.id })
      
      respond_to do |format|
        format.html { redirect_to @ab_test, notice: 'A/B test has been resumed.' }
        format.json { render json: { test: @ab_test.performance_report, message: 'Test resumed successfully' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @ab_test, alert: 'Unable to resume A/B test.' }
        format.json { render json: { errors: ['Unable to resume test'] }, status: :unprocessable_entity }
      end
    end
  end

  def complete
    if @ab_test.complete!
      track_activity('ab_test_completed', { test_name: @ab_test.name, test_id: @ab_test.id, winner: @ab_test.winner_variant&.name })
      
      respond_to do |format|
        format.html { redirect_to @ab_test, notice: 'A/B test has been completed.' }
        format.json { render json: { test: @ab_test.performance_report, message: 'Test completed successfully' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @ab_test, alert: 'Unable to complete A/B test.' }
        format.json { render json: { errors: ['Unable to complete test'] }, status: :unprocessable_entity }
      end
    end
  end

  # Analytics and reporting
  def results
    @results_summary = @ab_test.results_summary
    @variant_comparisons = @ab_test.variant_comparison
    @statistical_analysis = @ab_test.calculate_statistical_significance
    @performance_timeline = @ab_test.ab_test_results.order(:recorded_at).limit(50)
    
    respond_to do |format|
      format.html
      format.json { 
        render json: {
          summary: @results_summary,
          comparisons: @variant_comparisons,
          analysis: @statistical_analysis,
          timeline: @performance_timeline.map(&:as_json)
        }
      }
      format.csv { 
        send_data generate_results_csv, 
                 filename: "ab_test_results_#{@ab_test.name.parameterize}_#{Date.current}.csv" 
      }
    end
  end

  def analysis
    @insights = @ab_test.generate_insights
    @recommendations = @ab_test.ab_test_recommendations.includes(:user).recent
    @pattern_analysis = AbTesting::AbTestPatternRecognizer.new(@ab_test).analyze
    @outcome_predictions = AbTesting::AbTestOutcomePredictor.new(@ab_test).predict if @ab_test.running?
    
    respond_to do |format|
      format.html
      format.json { 
        render json: {
          insights: @insights,
          recommendations: @recommendations.map(&:detailed_json),
          patterns: @pattern_analysis,
          predictions: @outcome_predictions
        }
      }
    end
  end

  # Real-time data endpoints
  def live_metrics
    authorize_live_access!
    
    metrics = AbTesting::RealTimeAbTestMetrics.new(@ab_test).current_metrics
    
    render json: {
      test_id: @ab_test.id,
      status: @ab_test.status,
      metrics: metrics,
      last_updated: Time.current.iso8601
    }
  end

  def declare_winner
    variant = @ab_test.ab_test_variants.find(params[:variant_id])
    
    if @ab_test.update(winner_variant: variant, status: 'completed', end_date: Time.current)
      track_activity('ab_test_winner_declared', { 
        test_name: @ab_test.name, 
        test_id: @ab_test.id, 
        winner: variant.name 
      })
      
      # Generate AI recommendation for winner
      AbTesting::AbTestAiRecommender.new(@ab_test).generate_winner_recommendation
      
      respond_to do |format|
        format.html { redirect_to @ab_test, notice: "Winner declared: #{variant.name}" }
        format.json { render json: { test: @ab_test.performance_report, winner: variant.name } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @ab_test, alert: 'Unable to declare winner.' }
        format.json { render json: { errors: @ab_test.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_ab_test
    @ab_test = current_user.ab_tests.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to ab_tests_path, alert: 'A/B test not found.' }
      format.json { render json: { error: 'Test not found' }, status: :not_found }
    end
  end

  def set_campaign
    @campaign = current_user.campaigns.find(params[:campaign_id]) if params[:campaign_id]
  rescue ActiveRecord::RecordNotFound
    redirect_to campaigns_path, alert: 'Campaign not found.'
  end

  def ab_test_params
    params.require(:ab_test).permit(
      :name, :description, :hypothesis, :test_type, :status,
      :start_date, :end_date, :confidence_level, :significance_threshold,
      :campaign_id, :minimum_sample_size,
      ab_test_variants_attributes: [
        :id, :name, :description, :is_control, :traffic_percentage, 
        :journey_id, :variant_type, :_destroy
      ]
    )
  end

  def calculate_average_conversion_rate
    variants = current_user.ab_tests.joins(:ab_test_variants)
                          .where(status: ['running', 'completed'])
    
    return 0 if variants.empty?
    
    total_visitors = variants.sum('ab_test_variants.total_visitors')
    total_conversions = variants.sum('ab_test_variants.conversions')
    
    return 0 if total_visitors == 0
    
    (total_conversions.to_f / total_visitors * 100).round(2)
  end

  def authorize_live_access!
    # Rate limiting for real-time endpoints
    return if performed?
    
    head :too_many_requests if request_count_exceeded?
  end

  def request_count_exceeded?
    # Simple rate limiting - in production, use Redis or similar
    session[:live_requests] ||= {}
    session[:live_requests][@ab_test.id] ||= { count: 0, last_reset: Time.current }
    
    # Reset counter if more than 1 minute has passed
    if session[:live_requests][@ab_test.id][:last_reset] < 1.minute.ago
      session[:live_requests][@ab_test.id] = { count: 0, last_reset: Time.current }
    end
    
    session[:live_requests][@ab_test.id][:count] += 1
    session[:live_requests][@ab_test.id][:count] > 60 # Max 60 requests per minute
  end

  def generate_results_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << [
        'Test Name', 'Variant Name', 'Is Control', 'Traffic %', 
        'Total Visitors', 'Conversions', 'Conversion Rate %', 
        'Confidence Interval', 'Lift vs Control %', 'Statistical Significance'
      ]
      
      @ab_test.ab_test_variants.each do |variant|
        csv << [
          @ab_test.name,
          variant.name,
          variant.is_control? ? 'Yes' : 'No',
          variant.traffic_percentage,
          variant.total_visitors,
          variant.conversions,
          variant.conversion_rate,
          "#{variant.confidence_interval_range.join(' - ')}%",
          variant.lift_vs_control,
          variant.significance_vs_control
        ]
      end
    end
  end
end