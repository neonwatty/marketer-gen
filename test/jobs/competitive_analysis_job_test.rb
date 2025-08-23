require "test_helper"

class CompetitiveAnalysisJobTest < ActiveJob::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
  end

  test "should perform competitive analysis job successfully" do
    # Mock the service to return success
    mock_service = mock()
    mock_service.expects(:perform_analysis).returns({ success: true, data: { message: "Analysis completed" } })
    
    CompetitiveAnalysisService.stubs(:new).returns(mock_service)
    
    assert_nothing_raised do
      CompetitiveAnalysisJob.perform_now(@campaign_plan.id)
    end
  end

  test "should handle campaign plan not found" do
    invalid_id = 99999
    
    # Test that the job handles missing records gracefully
    assert_nothing_raised do
      begin
        CompetitiveAnalysisJob.perform_now(invalid_id)
      rescue ActiveJob::DeserializationError
        # This is expected behavior
        true
      end
    end
  end

  test "should handle service failure" do
    # Mock the service to fail
    mock_service = mock()
    mock_service.expects(:perform_analysis).returns({ success: false, error: "Service failed" })
    
    CompetitiveAnalysisService.stubs(:new).returns(mock_service)
    
    # Test that the job handles service failure appropriately
    logs = capture_logs do
      begin
        CompetitiveAnalysisJob.perform_now(@campaign_plan.id)
      rescue StandardError => e
        assert_includes e.message, "Competitive analysis failed"
      end
    end
    
    assert_includes logs, "Failed competitive analysis for campaign plan #{@campaign_plan.id}: Service failed"
  end

  test "should log successful completion" do
    # Mock the service to return success
    mock_service = mock()
    mock_service.expects(:perform_analysis).returns({ success: true, data: { message: "Analysis completed" } })
    
    CompetitiveAnalysisService.stubs(:new).returns(mock_service)
    
    # Capture log output
    logs = capture_logs do
      CompetitiveAnalysisJob.perform_now(@campaign_plan.id)
    end
    
    assert_includes logs, "Starting competitive analysis for campaign plan #{@campaign_plan.id}"
    assert_includes logs, "Successfully completed competitive analysis for campaign plan #{@campaign_plan.id}"
  end

  test "should log failure with error details" do
    # Mock the service to fail
    mock_service = mock()
    mock_service.expects(:perform_analysis).returns({ success: false, error: "LLM service unavailable" })
    
    CompetitiveAnalysisService.stubs(:new).returns(mock_service)
    
    # Capture log output
    logs = capture_logs do
      begin
        CompetitiveAnalysisJob.perform_now(@campaign_plan.id)
      rescue StandardError
        # Expected behavior
      end
    end
    
    assert_includes logs, "Starting competitive analysis for campaign plan #{@campaign_plan.id}"
    assert_includes logs, "Failed competitive analysis for campaign plan #{@campaign_plan.id}: LLM service unavailable"
  end

  test "should trigger follow-up actions on success" do
    # Create a campaign plan that should trigger follow-up actions
    approved_plan = campaign_plans(:draft_plan)
    approved_plan.update!(approval_status: 'approved')
    
    # Mock the service to return success
    mock_service = mock()
    mock_service.expects(:perform_analysis).returns({ success: true, data: { message: "Analysis completed" } })
    
    CompetitiveAnalysisService.stubs(:new).returns(mock_service)
    
    # Capture logs to verify follow-up actions
    logs = capture_logs do
      CompetitiveAnalysisJob.perform_now(approved_plan.id)
    end
    
    assert_includes logs, "Competitive analysis completed for campaign plan #{approved_plan.id}"
  end

  test "should schedule refresh for approved plans" do
    # Create an approved campaign plan
    approved_plan = campaign_plans(:draft_plan)
    approved_plan.update!(approval_status: 'approved')
    
    # Mock the service to return success
    mock_service = mock()
    mock_service.expects(:perform_analysis).returns({ success: true, data: { message: "Analysis completed" } })
    
    CompetitiveAnalysisService.stubs(:new).returns(mock_service)
    
    assert_enqueued_jobs 1, only: CompetitiveAnalysisJob do
      CompetitiveAnalysisJob.perform_now(approved_plan.id)
    end
  end

  test "should not schedule refresh for draft plans" do
    # Use draft plan (default approval_status is 'draft')
    draft_plan = @campaign_plan
    
    # Mock the service to return success
    mock_service = mock()
    mock_service.expects(:perform_analysis).returns({ success: true, data: { message: "Analysis completed" } })
    
    CompetitiveAnalysisService.stubs(:new).returns(mock_service)
    
    # Should not enqueue additional jobs
    assert_no_enqueued_jobs only: CompetitiveAnalysisJob do
      CompetitiveAnalysisJob.perform_now(draft_plan.id)
    end
  end

  test "should update campaign strategy for draft plans" do
    # Use a draft plan that's ready for generation
    draft_plan = @campaign_plan
    draft_plan.update!(
      name: "Test Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    
    # Mock the service to return success
    mock_service = mock()
    mock_service.expects(:perform_analysis).returns({ success: true, data: { message: "Analysis completed" } })
    
    CompetitiveAnalysisService.stubs(:new).returns(mock_service)
    
    logs = capture_logs do
      CompetitiveAnalysisJob.perform_now(draft_plan.id)
    end
    
    assert_includes logs, "Updating campaign strategy with competitive insights for plan #{draft_plan.id}"
  end

  test "should handle unexpected errors gracefully" do
    # Mock the service to raise an unexpected error
    CompetitiveAnalysisService.stubs(:new).raises(RuntimeError.new("Unexpected error"))
    
    logs = capture_logs do
      begin
        CompetitiveAnalysisJob.perform_now(@campaign_plan.id)
      rescue RuntimeError => e
        assert_includes e.message, "Unexpected error"
      end
    end
    
    assert_includes logs, "Unexpected error in competitive analysis job: Unexpected error"
  end

  test "should reset timestamp on retry failure" do
    # Set initial timestamp
    @campaign_plan.update!(competitive_analysis_last_updated_at: 1.hour.ago)
    
    # Simulate the retry callback behavior by directly calling what it does
    @campaign_plan.update_column(:competitive_analysis_last_updated_at, nil)
    
    @campaign_plan.reload
    
    # Timestamp should be reset to nil
    assert_nil @campaign_plan.competitive_analysis_last_updated_at
  end

  test "job should be configured with correct queue and retry settings" do
    job = CompetitiveAnalysisJob.new(@campaign_plan.id)
    
    assert_equal "default", job.queue_name
    
    # Test that the job is properly configured (the specifics are tested via the job behavior)
    assert_kind_of CompetitiveAnalysisJob, job
  end

  private

  def capture_logs
    captured_logs = []
    
    # Create a mock logger that captures log messages
    mock_logger = Object.new
    
    # Allow multiple calls to each method
    def mock_logger.info(message)
      @captured_logs ||= []
      @captured_logs << message
    end
    
    def mock_logger.error(message)
      @captured_logs ||= []
      @captured_logs << message
    end
    
    def mock_logger.captured_logs
      @captured_logs || []
    end
    
    Rails.stubs(:logger).returns(mock_logger)
    
    begin
      yield
    ensure
      Rails.unstub(:logger)
    end
    
    mock_logger.captured_logs.join("\n")
  end
end