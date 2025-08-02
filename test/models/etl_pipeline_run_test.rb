# frozen_string_literal: true

require 'test_helper'

class EtlPipelineRunTest < ActiveSupport::TestCase
  def setup
    @pipeline_run = EtlPipelineRun.create!(
      pipeline_id: SecureRandom.uuid,
      source: 'test_source',
      status: 'running',
      started_at: Time.current
    )
  end

  test "validates required fields" do
    pipeline_run = EtlPipelineRun.new
    
    refute pipeline_run.valid?
    assert_includes pipeline_run.errors[:pipeline_id], "can't be blank"
    assert_includes pipeline_run.errors[:source], "can't be blank"
    assert_includes pipeline_run.errors[:status], "can't be blank"
    assert_includes pipeline_run.errors[:started_at], "can't be blank"
  end

  test "validates status inclusion" do
    @pipeline_run.status = 'invalid_status'
    
    refute @pipeline_run.valid?
    assert_includes @pipeline_run.errors[:status], "is not included in the list"
  end

  test "scopes work correctly" do
    completed_run = EtlPipelineRun.create!(
      pipeline_id: SecureRandom.uuid,
      source: 'test_source',
      status: 'completed',
      started_at: 1.hour.ago,
      completed_at: 30.minutes.ago
    )
    
    failed_run = EtlPipelineRun.create!(
      pipeline_id: SecureRandom.uuid,
      source: 'test_source',
      status: 'failed',
      started_at: 2.hours.ago,
      completed_at: 1.hour.ago
    )
    
    assert_includes EtlPipelineRun.running, @pipeline_run
    assert_includes EtlPipelineRun.completed, completed_run
    assert_includes EtlPipelineRun.failed, failed_run
    assert_includes EtlPipelineRun.for_source('test_source'), @pipeline_run
  end

  test "calculates success rate correctly" do
    # Create some completed and failed runs
    3.times do
      EtlPipelineRun.create!(
        pipeline_id: SecureRandom.uuid,
        source: 'test_source',
        status: 'completed',
        started_at: 1.hour.ago,
        completed_at: 30.minutes.ago
      )
    end
    
    1.times do
      EtlPipelineRun.create!(
        pipeline_id: SecureRandom.uuid,
        source: 'test_source',
        status: 'failed',
        started_at: 2.hours.ago,
        completed_at: 1.hour.ago
      )
    end
    
    # Success rate should be 75% (3 success out of 4 total, excluding running)
    success_rate = EtlPipelineRun.success_rate
    assert_equal 75.0, success_rate
  end

  test "calculates average duration correctly" do
    EtlPipelineRun.create!(
      pipeline_id: SecureRandom.uuid,
      source: 'test_source',
      status: 'completed',
      started_at: 2.hours.ago,
      completed_at: 1.hour.ago,
      duration: 3600.0
    )
    
    EtlPipelineRun.create!(
      pipeline_id: SecureRandom.uuid,
      source: 'test_source',
      status: 'completed',
      started_at: 3.hours.ago,
      completed_at: 2.hours.ago,
      duration: 1800.0
    )
    
    avg_duration = EtlPipelineRun.average_duration
    assert_equal 2700.0, avg_duration # (3600 + 1800) / 2
  end

  test "health metrics calculation" do
    # Create various pipeline runs for health metrics
    EtlPipelineRun.create!(
      pipeline_id: SecureRandom.uuid,
      source: 'test_source',
      status: 'completed',
      started_at: 1.hour.ago,
      completed_at: 30.minutes.ago,
      duration: 1800.0
    )
    
    EtlPipelineRun.create!(
      pipeline_id: SecureRandom.uuid,
      source: 'test_source',
      status: 'failed',
      started_at: 2.hours.ago,
      completed_at: 1.hour.ago,
      duration: 600.0
    )
    
    metrics = EtlPipelineRun.health_metrics
    
    assert metrics.key?(:total_runs)
    assert metrics.key?(:successful_runs)
    assert metrics.key?(:failed_runs)
    assert metrics.key?(:success_rate)
    assert metrics.key?(:average_duration)
    assert metrics.key?(:error_rate)
    
    assert metrics[:total_runs] >= 3 # Including the one from setup
    assert metrics[:successful_runs] >= 1
    assert metrics[:failed_runs] >= 1
  end

  test "source-specific metrics" do
    source_metrics = EtlPipelineRun.source_metrics('test_source')
    
    assert_equal 'test_source', source_metrics[:source]
    assert source_metrics.key?(:total_runs)
    assert source_metrics.key?(:successful_runs)
    assert source_metrics.key?(:failed_runs)
    assert source_metrics.key?(:success_rate)
  end

  test "pipeline health check" do
    # Pipeline should be unhealthy if no successful runs
    refute EtlPipelineRun.pipeline_healthy?('new_source')
    
    # Create a recent successful run
    EtlPipelineRun.create!(
      pipeline_id: SecureRandom.uuid,
      source: 'healthy_source',
      status: 'completed',
      started_at: 30.minutes.ago,
      completed_at: 25.minutes.ago
    )
    
    assert EtlPipelineRun.pipeline_healthy?('healthy_source')
    
    # Should be unhealthy if last run was too long ago
    refute EtlPipelineRun.pipeline_healthy?('healthy_source', 10) # 10 minute threshold
  end

  test "recent errors retrieval" do
    EtlPipelineRun.create!(
      pipeline_id: SecureRandom.uuid,
      source: 'error_source',
      status: 'failed',
      started_at: 1.hour.ago,
      completed_at: 30.minutes.ago,
      error_message: 'Something went wrong'
    )
    
    errors = EtlPipelineRun.recent_errors('error_source', 5)
    
    assert errors.present?
    assert_equal 'Something went wrong', errors.first.error_message
  end

  test "mark_completed! updates status and metrics" do
    metrics = { records_processed: 100, duration: 300.0 }
    
    @pipeline_run.mark_completed!(metrics)
    @pipeline_run.reload
    
    assert_equal 'completed', @pipeline_run.status
    assert @pipeline_run.completed_at.present?
    assert @pipeline_run.duration.present?
    assert_equal metrics, @pipeline_run.metrics
  end

  test "mark_failed! records error information" do
    error = StandardError.new("Test error")
    error.set_backtrace(['line 1', 'line 2', 'line 3'])
    
    @pipeline_run.mark_failed!(error)
    @pipeline_run.reload
    
    assert_equal 'failed', @pipeline_run.status
    assert_equal 'Test error', @pipeline_run.error_message
    assert @pipeline_run.error_backtrace.present?
    assert @pipeline_run.completed_at.present?
  end

  test "mark_retrying! updates status" do
    @pipeline_run.mark_retrying!
    @pipeline_run.reload
    
    assert_equal 'retrying', @pipeline_run.status
  end

  test "too_slow? detection" do
    # Short duration should not be considered slow
    @pipeline_run.update!(
      completed_at: @pipeline_run.started_at + 10.minutes,
      duration: 600.0
    )
    
    refute @pipeline_run.too_slow?(30)
    
    # Long duration should be considered slow
    @pipeline_run.update!(
      completed_at: @pipeline_run.started_at + 45.minutes,
      duration: 2700.0
    )
    
    assert @pipeline_run.too_slow?(30)
  end

  test "formatted_duration returns human readable format" do
    @pipeline_run.duration = 45.5
    assert_equal '45.5s', @pipeline_run.formatted_duration
    
    @pipeline_run.duration = 125.0
    assert_equal '2.1m', @pipeline_run.formatted_duration
    
    @pipeline_run.duration = 3725.0
    assert_equal '1.0h', @pipeline_run.formatted_duration
    
    @pipeline_run.duration = nil
    assert_equal 'N/A', @pipeline_run.formatted_duration
  end

  test "formatted_metrics humanizes metric names" do
    @pipeline_run.metrics = {
      'records_processed' => 100,
      'error_count' => 2,
      'processing_time' => 300.5
    }
    
    formatted = @pipeline_run.formatted_metrics
    
    assert_equal 100, formatted['Records processed']
    assert_equal 2, formatted['Error count']
    assert_equal 300.5, formatted['Processing time']
  end
end