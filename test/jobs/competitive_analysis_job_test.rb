require "test_helper"

class CompetitiveAnalysisJobTest < ActiveJob::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
  end

  test "should perform competitive analysis job successfully" do
    # Mock the service to return success
    mock_service = Minitest::Mock.new
    mock_service.expect(:perform_analysis, { success: true, data: { message: "Analysis completed" } })
    
    CompetitiveAnalysisService.stub(:new, mock_service) do
      assert_performed_jobs 1 do
        CompetitiveAnalysisJob.perform_now(@campaign_plan.id)
      end
    end
    
    mock_service.verify
  end

  test "should handle campaign plan not found" do
    invalid_id = 99999
    
    assert_raises(ActiveJob::DeserializationError) do
      CompetitiveAnalysisJob.perform_now(invalid_id)
    end
  end

  test "should retry on service failure" do
    # Mock the service to fail
    mock_service = Minitest::Mock.new
    mock_service.expect(:perform_analysis, { success: false, error: "Service failed" })
    
    CompetitiveAnalysisService.stub(:new, mock_service) do
      assert_raises(StandardError) do
        CompetitiveAnalysisJob.perform_now(@campaign_plan.id)
      end
    end
    
    mock_service.verify
  end

  test "should log successful completion" do
    # Mock the service to return success
    mock_service = Minitest::Mock.new
    mock_service.expect(:perform_analysis, { success: true, data: { message: "Analysis completed" } })
    
    CompetitiveAnalysisService.stub(:new, mock_service) do
      # Capture log output
      logs = capture_logs do
        CompetitiveAnalysisJob.perform_now(@campaign_plan.id)
      end
      
      assert_includes logs, "Starting competitive analysis for campaign plan #{@campaign_plan.id}"
      assert_includes logs, "Successfully completed competitive analysis for campaign plan #{@campaign_plan.id}"
    end
    
    mock_service.verify
  end

  test "should log failure with error details" do
    # Mock the service to fail
    mock_service = Minitest::Mock.new
    mock_service.expect(:perform_analysis, { success: false, error: "LLM service unavailable" })
    
    CompetitiveAnalysisService.stub(:new, mock_service) do
      # Capture log output and expect exception
      logs = capture_logs do
        assert_raises(StandardError) do
          CompetitiveAnalysisJob.perform_now(@campaign_plan.id)
        end
      end
      
      assert_includes logs, "Starting competitive analysis for campaign plan #{@campaign_plan.id}"
      assert_includes logs, "Failed competitive analysis for campaign plan #{@campaign_plan.id}: LLM service unavailable"
    end
    
    mock_service.verify
  end

  test "should trigger follow-up actions on success" do
    # Create a campaign plan that should trigger follow-up actions
    approved_plan = campaign_plans(:draft_plan)
    approved_plan.update!(approval_status: 'approved')
    
    # Mock the service to return success
    mock_service = Minitest::Mock.new
    mock_service.expect(:perform_analysis, { success: true, data: { message: "Analysis completed" } })
    
    CompetitiveAnalysisService.stub(:new, mock_service) do
      # Capture logs to verify follow-up actions
      logs = capture_logs do
        CompetitiveAnalysisJob.perform_now(approved_plan.id)
      end
      
      assert_includes logs, "Competitive analysis completed for campaign plan #{approved_plan.id}"
    end
    
    mock_service.verify
  end

  test "should schedule refresh for approved plans" do
    # Create an approved campaign plan
    approved_plan = campaign_plans(:draft_plan)
    approved_plan.update!(approval_status: 'approved')
    
    # Mock the service to return success
    mock_service = Minitest::Mock.new
    mock_service.expect(:perform_analysis, { success: true, data: { message: "Analysis completed" } })
    
    CompetitiveAnalysisService.stub(:new, mock_service) do
      assert_enqueued_jobs 1, only: CompetitiveAnalysisJob do
        CompetitiveAnalysisJob.perform_now(approved_plan.id)
      end
    end
    
    mock_service.verify
  end

  test "should not schedule refresh for draft plans" do
    # Use draft plan (default approval_status is 'draft')
    draft_plan = @campaign_plan
    
    # Mock the service to return success
    mock_service = Minitest::Mock.new
    mock_service.expect(:perform_analysis, { success: true, data: { message: "Analysis completed" } })
    
    CompetitiveAnalysisService.stub(:new, mock_service) do
      # Should not enqueue additional jobs
      assert_no_enqueued_jobs only: CompetitiveAnalysisJob do
        CompetitiveAnalysisJob.perform_now(draft_plan.id)
      end
    end
    
    mock_service.verify
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
    mock_service = Minitest::Mock.new
    mock_service.expect(:perform_analysis, { success: true, data: { message: "Analysis completed" } })
    
    CompetitiveAnalysisService.stub(:new, mock_service) do
      logs = capture_logs do
        CompetitiveAnalysisJob.perform_now(draft_plan.id)
      end
      
      assert_includes logs, "Updating campaign strategy with competitive insights for plan #{draft_plan.id}"
    end
    
    mock_service.verify
  end

  test "should handle unexpected errors gracefully" do
    # Mock the service to raise an unexpected error
    CompetitiveAnalysisService.stub(:new, -> (*) { raise RuntimeError.new("Unexpected error") }) do
      logs = capture_logs do
        assert_raises(RuntimeError) do
          CompetitiveAnalysisJob.perform_now(@campaign_plan.id)
        end
      end
      
      assert_includes logs, "Unexpected error in competitive analysis job: Unexpected error"
    end
  end

  test "should reset timestamp on retry failure" do
    # Set initial timestamp
    @campaign_plan.update!(competitive_analysis_last_updated_at: 1.hour.ago)
    initial_timestamp = @campaign_plan.competitive_analysis_last_updated_at
    
    # Mock the service to fail consistently
    mock_service = Minitest::Mock.new
    mock_service.expect(:perform_analysis, { success: false, error: "Persistent failure" })
    
    # Create a job instance to test retry behavior
    job = CompetitiveAnalysisJob.new
    job.arguments = [@campaign_plan.id]
    job.instance_variable_set(:@executions, 3) # Simulate final retry
    
    CompetitiveAnalysisService.stub(:new, mock_service) do
      # Trigger the retry_on block
      exception = StandardError.new("Persistent failure")
      job.retry_job(wait: 5.minutes, attempts: 3).call(job, exception)
      
      @campaign_plan.reload
      
      # Timestamp should be reset to nil
      assert_nil @campaign_plan.competitive_analysis_last_updated_at
    end
  end

  test "job should be configured with correct queue and retry settings" do
    job = CompetitiveAnalysisJob.new(@campaign_plan.id)
    
    assert_equal :default, job.queue_name
    
    # Verify retry configuration exists
    retry_config = CompetitiveAnalysisJob.retry_on_settings.find { |config| config[:exception] == StandardError }
    assert_not_nil retry_config
    assert_equal 5.minutes, retry_config[:wait]
    assert_equal 3, retry_config[:attempts]
  end

  private

  def capture_logs
    logs = []
    original_logger = Rails.logger
    
    # Create a mock logger that captures log messages
    mock_logger = Minitest::Mock.new
    
    # Capture info and error messages
    mock_logger.expect(:info, nil) do |message|
      logs << message
      true
    end
    
    mock_logger.expect(:error, nil) do |message|
      logs << message
      true
    end
    
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
    
    Rails.stub(:logger, mock_logger) do
      yield
    end
    
    mock_logger.captured_logs.join("\n")
  end
end