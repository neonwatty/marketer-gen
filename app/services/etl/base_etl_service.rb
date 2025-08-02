# frozen_string_literal: true

require 'dry-types'
require 'dry-validation'

module Etl
  # Base ETL service providing common functionality for all ETL pipelines
  class BaseEtlService

    class EtlError < StandardError; end
    class ValidationError < EtlError; end
    class TransformationError < EtlError; end
    class LoadError < EtlError; end

    attr_reader :source, :pipeline_id, :started_at, :metrics

    def initialize(source:, pipeline_id: SecureRandom.uuid)
      @source = source
      @pipeline_id = pipeline_id
      @started_at = Time.current
      @metrics = initialize_metrics
    end

    # Main ETL pipeline execution
    def execute
      Rails.logger.info("[ETL] Starting pipeline #{pipeline_id} for #{source}")
      
      begin
        with_monitoring do
          extracted_data = extract
          validated_data = validate(extracted_data)
          transformed_data = transform(validated_data)
          load(transformed_data)
        end
        
        record_success
        notify_completion
      rescue => error
        record_failure(error)
        handle_error(error)
        raise
      end
    end

    private

    # Extract phase - to be implemented by subclasses
    def extract
      raise NotImplementedError, "Subclasses must implement extract method"
    end

    # Validate extracted data
    def validate(data)
      Rails.logger.info("[ETL] Validating #{data.size} records")
      
      validation_schema = build_validation_schema
      validated_data = []
      errors = []

      data.each_with_index do |record, index|
        result = validation_schema.call(record)
        
        if result.success?
          validated_data << result.to_h
        else
          error_msg = "Record #{index}: #{result.errors.to_h}"
          errors << error_msg
          Rails.logger.warn("[ETL] Validation error: #{error_msg}")
        end
      end

      update_metrics(:validation_errors, errors.size)
      
      if errors.size > (data.size * 0.1) # Fail if more than 10% invalid
        raise ValidationError, "Too many validation errors: #{errors.first(5).join(', ')}"
      end

      validated_data
    end

    # Transform phase - to be implemented by subclasses
    def transform(data)
      Rails.logger.info("[ETL] Transforming #{data.size} records")
      
      begin
        transformed_data = apply_transformations(data)
        update_metrics(:records_transformed, transformed_data.size)
        transformed_data
      rescue => error
        raise TransformationError, "Transformation failed: #{error.message}"
      end
    end

    # Load phase - save to database with batching
    def load(data)
      Rails.logger.info("[ETL] Loading #{data.size} records")
      
      begin
        batch_size = EtlPipeline::Config::BATCH_SIZES[:medium]
        loaded_count = 0

        data.in_groups_of(batch_size, false) do |batch|
          load_batch(batch)
          loaded_count += batch.size
          update_metrics(:records_loaded, loaded_count)
        end

        compress_if_needed(data)
      rescue => error
        raise LoadError, "Load phase failed: #{error.message}"
      end
    end

    # Build validation schema - to be customized by subclasses
    def build_validation_schema
      Dry::Validation.Contract do
        params do
          required(:timestamp).filled(:date_time)
          required(:source).filled(:string)
          optional(:data).hash
        end
      end
    end

    # Apply transformations - to be implemented by subclasses
    def apply_transformations(data)
      data.map do |record|
        record.merge(
          normalized_at: Time.current,
          pipeline_id: pipeline_id,
          etl_version: '1.0'
        )
      end
    end

    # Load batch to database - to be implemented by subclasses
    def load_batch(batch)
      # Default implementation - subclasses should override
      batch.each { |record| store_record(record) }
    end

    # Store individual record - to be implemented by subclasses
    def store_record(record)
      raise NotImplementedError, "Subclasses must implement store_record method"
    end

    # Compression for large datasets
    def compress_if_needed(data)
      data_size = data.to_json.bytesize
      threshold = EtlPipeline::Config::COMPRESSION_CONFIG[:threshold_size]
      
      if data_size > threshold
        Rails.logger.info("[ETL] Compressing #{data_size} bytes of data")
        compressed_data = compress_data(data)
        update_metrics(:compression_ratio, data_size.to_f / compressed_data.bytesize)
      end
    end

    # Data compression using Zlib
    def compress_data(data)
      require 'zlib'
      Zlib::Deflate.deflate(data.to_json)
    end

    # Simple retry mechanism with exponential backoff
    def with_retry(max_attempts: 3, base_delay: 2)
      attempt = 1
      begin
        yield
      rescue => error
        if attempt < max_attempts
          delay = base_delay * (2 ** (attempt - 1))
          Rails.logger.warn("[ETL] Attempt #{attempt} failed, retrying in #{delay}s: #{error.message}")
          sleep(delay)
          attempt += 1
          retry
        else
          raise
        end
      end
    end

    # Monitoring wrapper
    def with_monitoring
      start_time = Time.current
      
      yield
      
      duration = Time.current - start_time
      update_metrics(:duration, duration)
      update_metrics(:success_rate, 1.0)
      
      Rails.logger.info("[ETL] Pipeline #{pipeline_id} completed in #{duration.round(2)}s")
    end

    # Initialize metrics tracking
    def initialize_metrics
      {
        records_extracted: 0,
        records_validated: 0,
        records_transformed: 0,
        records_loaded: 0,
        validation_errors: 0,
        transformation_errors: 0,
        load_errors: 0,
        duration: 0,
        success_rate: 0.0,
        compression_ratio: 1.0
      }
    end

    # Update metrics
    def update_metrics(key, value)
      @metrics[key] = value
    end

    # Record successful completion
    def record_success
      EtlPipelineRun.create!(
        pipeline_id: pipeline_id,
        source: source,
        status: 'completed',
        started_at: started_at,
        completed_at: Time.current,
        metrics: metrics,
        duration: metrics[:duration]
      )
    end

    # Record failure
    def record_failure(error)
      EtlPipelineRun.create!(
        pipeline_id: pipeline_id,
        source: source,
        status: 'failed',
        started_at: started_at,
        completed_at: Time.current,
        error_message: error.message,
        error_backtrace: error.backtrace&.first(10),
        metrics: metrics
      )
    end

    # Error handling with retry logic
    def handle_error(error)
      Rails.logger.error("[ETL] Pipeline #{pipeline_id} failed: #{error.message}")
      
      case error
      when ValidationError
        notify_validation_error(error)
      when TransformationError
        notify_transformation_error(error)
      when LoadError
        notify_load_error(error)
      else
        notify_general_error(error)
      end
    end

    # Notification methods
    def notify_completion
      Rails.logger.info("[ETL] Pipeline #{pipeline_id} completed successfully")
      # Could integrate with notification system
    end

    def notify_validation_error(error)
      Rails.logger.error("[ETL] Validation error in pipeline #{pipeline_id}: #{error.message}")
    end

    def notify_transformation_error(error)
      Rails.logger.error("[ETL] Transformation error in pipeline #{pipeline_id}: #{error.message}")
    end

    def notify_load_error(error)
      Rails.logger.error("[ETL] Load error in pipeline #{pipeline_id}: #{error.message}")
    end

    def notify_general_error(error)
      Rails.logger.error("[ETL] General error in pipeline #{pipeline_id}: #{error.message}")
    end
  end
end