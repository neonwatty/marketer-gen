# frozen_string_literal: true

require 'test_helper'

module Etl
  class BaseEtlServiceTest < ActiveSupport::TestCase
    def setup
      @service = TestEtlService.new(source: 'test_source')
    end

    test "initializes with correct attributes" do
      assert_equal 'test_source', @service.source
      assert @service.pipeline_id.present?
      assert @service.started_at.present?
      assert @service.metrics.is_a?(Hash)
    end

    test "execute method runs full ETL pipeline" do
      mock_data = [
        { 'timestamp' => Time.current, 'source' => 'test', 'value' => 100 }
      ]
      
      @service.expects(:extract).returns(mock_data)
      @service.expects(:store_record).once
      
      @service.execute
      
      # Check that pipeline run was recorded
      pipeline_run = EtlPipelineRun.find_by(pipeline_id: @service.pipeline_id)
      assert pipeline_run.present?
      assert_equal 'completed', pipeline_run.status
    end

    test "handles extraction errors gracefully" do
      @service.expects(:extract).raises(StandardError.new("Extract failed"))
      
      assert_raises(StandardError) { @service.execute }
      
      # Check that failure was recorded
      pipeline_run = EtlPipelineRun.find_by(pipeline_id: @service.pipeline_id)
      assert pipeline_run.present?
      assert_equal 'failed', pipeline_run.status
      assert_equal 'Extract failed', pipeline_run.error_message
    end

    test "validates data correctly" do
      valid_data = [
        { 'timestamp' => Time.current, 'source' => 'test', 'data' => {} }
      ]
      
      invalid_data = [
        { 'source' => 'test' }, # missing timestamp
        { 'timestamp' => Time.current } # missing source
      ]
      
      # Valid data should pass
      result = @service.send(:validate, valid_data)
      assert_equal 1, result.size
      
      # Invalid data should be filtered out but not fail completely
      result = @service.send(:validate, invalid_data)
      assert_equal 0, result.size
    end

    test "applies transformations correctly" do
      data = [
        { 'timestamp' => Time.current, 'source' => 'test', 'value' => 100 }
      ]
      
      result = @service.send(:apply_transformations, data)
      
      assert_equal 1, result.size
      assert result.first.key?('normalized_at')
      assert result.first.key?('pipeline_id')
      assert result.first.key?('etl_version')
    end

    test "compresses large datasets" do
      large_data = Array.new(1000) do |i|
        { 'timestamp' => Time.current, 'source' => 'test', 'index' => i }
      end
      
      @service.send(:compress_if_needed, large_data)
      
      # Should log compression activity
      assert @service.metrics[:compression_ratio]
    end

    test "retry mechanism works with exponential backoff" do
      attempts = 0
      
      result = @service.send(:with_retry, max_attempts: 3, base_delay: 0.01) do
        attempts += 1
        raise StandardError.new("Temporary failure") if attempts < 3
        "success"
      end
      
      assert_equal "success", result
      assert_equal 3, attempts
    end

    test "metrics are tracked correctly" do
      initial_metrics = @service.metrics.dup
      
      @service.send(:update_metrics, :test_metric, 42)
      
      assert_equal 42, @service.metrics[:test_metric]
      assert_not_equal initial_metrics, @service.metrics
    end

    private

    # Test implementation of BaseEtlService for testing
    class TestEtlService < BaseEtlService
      def extract
        [
          { 'timestamp' => Time.current, 'source' => source, 'test_data' => true }
        ]
      end

      def store_record(record)
        # Mock storage - in real implementation this would save to database
        true
      end
    end
  end
end