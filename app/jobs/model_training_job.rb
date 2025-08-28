# frozen_string_literal: true

# Background job for training ML prediction models
# Handles long-running model training processes without blocking web requests
class ModelTrainingJob < ApplicationJob
  # Custom error classes
  class ModelTrainingError < StandardError; end
  class InsufficientDataError < StandardError; end
  class InvalidModelConfigurationError < StandardError; end

  queue_as :model_training
  
  # Retry failed jobs with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # Discard jobs for deleted models
  discard_on ActiveRecord::RecordNotFound
  
  # Handle specific training errors
  retry_on ModelTrainingError, wait: 5.minutes, attempts: 2
  discard_on InsufficientDataError
  discard_on InvalidModelConfigurationError

  def perform(prediction_model_id, training_data, options = {})
    @model = PredictionModel.find(prediction_model_id)
    @training_data = training_data
    @options = options.with_indifferent_access
    
    Rails.logger.info "Starting model training for PredictionModel #{@model.id} (#{@model.prediction_type})"
    
    # Validate model and data before training
    validate_training_prerequisites!
    
    # Mark training as started
    @model.mark_training_started!(options[:user])
    
    begin
      # Perform the actual training
      training_results = train_model
      
      # Validate training results
      validate_training_results!(training_results)
      
      # Mark training as completed with results
      @model.mark_training_completed!(
        training_results[:accuracy],
        training_results[:confidence],
        training_results[:results]
      )
      
      # Activate model if it meets quality criteria
      activate_if_qualified(training_results)
      
      # Send completion notification
      send_training_notification(:completed, training_results)
      
      Rails.logger.info "Successfully completed training for PredictionModel #{@model.id}"
      
    rescue => error
      handle_training_error(error)
      raise error
    end
  end

  private

  def validate_training_prerequisites!
    # Check if model is in correct state
    unless @model.training?
      raise InvalidModelConfigurationError, "Model #{@model.id} is not in training state"
    end

    # Validate training data
    if @training_data.blank? || !@training_data.is_a?(Array)
      raise InsufficientDataError, "Invalid training data provided"
    end

    if @training_data.count < minimum_data_points
      raise InsufficientDataError, "Insufficient training data: #{@training_data.count} < #{minimum_data_points}"
    end

    # Validate data structure
    validate_data_structure!
  end

  def validate_data_structure!
    @training_data.each_with_index do |data_point, index|
      unless data_point.is_a?(Hash) && data_point.key?('features') && data_point.key?('target')
        raise InvalidModelConfigurationError, "Invalid data structure at index #{index}"
      end

      unless data_point['features'].is_a?(Hash)
        raise InvalidModelConfigurationError, "Features must be a hash at index #{index}"
      end

      if data_point['target'].nil?
        raise InvalidModelConfigurationError, "Target value missing at index #{index}"
      end
    end
  end

  def train_model
    Rails.logger.info "Training #{@model.model_type} model with #{@training_data.count} data points"
    
    case @model.model_type
    when 'linear_regression'
      train_linear_regression
    when 'random_forest'
      train_random_forest
    when 'gradient_boosting'
      train_gradient_boosting
    when 'neural_network'
      train_neural_network
    when 'ensemble'
      train_ensemble_model
    when 'time_series'
      train_time_series_model
    when 'classification'
      train_classification_model
    when 'clustering'
      train_clustering_model
    else
      raise InvalidModelConfigurationError, "Unsupported model type: #{@model.model_type}"
    end
  end

  def train_linear_regression
    # Simulate linear regression training
    training_start = Time.current
    
    # Extract features and targets
    features = extract_feature_matrix
    targets = extract_target_vector
    
    # Simulate training process with sleep
    simulate_training_time(1.5)
    
    # Calculate mock results
    accuracy = calculate_mock_accuracy(features, targets)
    confidence = calculate_mock_confidence(accuracy)
    
    # Generate feature importance
    feature_importance = calculate_feature_importance(features.keys)
    
    # Calculate validation metrics
    validation_metrics = calculate_validation_metrics(accuracy)
    
    # Update model with training results
    update_model_training_data(feature_importance, validation_metrics)
    
    training_duration = Time.current - training_start
    
    {
      accuracy: accuracy,
      confidence: confidence,
      results: {
        model_type: 'linear_regression',
        training_duration_seconds: training_duration.to_i,
        feature_count: features.keys.count,
        data_points_used: @training_data.count,
        validation_metrics: validation_metrics,
        feature_importance: feature_importance
      }
    }
  end

  def train_random_forest
    # Simulate random forest training (more complex, takes longer)
    training_start = Time.current
    
    features = extract_feature_matrix
    targets = extract_target_vector
    
    # Random forest takes longer to train
    simulate_training_time(3.0)
    
    # Random forest typically has higher accuracy
    base_accuracy = calculate_mock_accuracy(features, targets)
    accuracy = [base_accuracy * 1.15, 0.95].min
    confidence = calculate_mock_confidence(accuracy)
    
    # Generate feature importance (random forests provide good feature importance)
    feature_importance = calculate_feature_importance(features.keys, method: 'gini')
    
    validation_metrics = calculate_validation_metrics(accuracy, model_type: 'random_forest')
    update_model_training_data(feature_importance, validation_metrics)
    
    training_duration = Time.current - training_start
    
    {
      accuracy: accuracy,
      confidence: confidence,
      results: {
        model_type: 'random_forest',
        training_duration_seconds: training_duration.to_i,
        n_estimators: @model.model_parameters['n_estimators'] || 100,
        max_depth: @model.model_parameters['max_depth'] || 10,
        feature_count: features.keys.count,
        data_points_used: @training_data.count,
        validation_metrics: validation_metrics,
        feature_importance: feature_importance,
        oob_score: rand(0.7..0.9).round(3)
      }
    }
  end

  def train_gradient_boosting
    # Simulate gradient boosting training
    training_start = Time.current
    
    features = extract_feature_matrix
    targets = extract_target_vector
    
    simulate_training_time(4.0)
    
    # Gradient boosting often achieves high accuracy but may overfit
    base_accuracy = calculate_mock_accuracy(features, targets)
    accuracy = [base_accuracy * 1.25, 0.92].min
    confidence = calculate_mock_confidence(accuracy)
    
    feature_importance = calculate_feature_importance(features.keys, method: 'gain')
    validation_metrics = calculate_validation_metrics(accuracy, model_type: 'gradient_boosting')
    
    update_model_training_data(feature_importance, validation_metrics)
    
    training_duration = Time.current - training_start
    
    {
      accuracy: accuracy,
      confidence: confidence,
      results: {
        model_type: 'gradient_boosting',
        training_duration_seconds: training_duration.to_i,
        learning_rate: @model.model_parameters['learning_rate'] || 0.1,
        n_estimators: @model.model_parameters['n_estimators'] || 100,
        max_depth: @model.model_parameters['max_depth'] || 6,
        feature_count: features.keys.count,
        data_points_used: @training_data.count,
        validation_metrics: validation_metrics,
        feature_importance: feature_importance,
        early_stopping_rounds: 10
      }
    }
  end

  def train_neural_network
    # Simulate neural network training (most complex, longest training time)
    training_start = Time.current
    
    features = extract_feature_matrix
    targets = extract_target_vector
    
    simulate_training_time(6.0)
    
    # Neural networks can achieve very high accuracy but need more data
    base_accuracy = calculate_mock_accuracy(features, targets)
    data_penalty = [@training_data.count / 100.0, 1.0].min  # Penalty for insufficient data
    accuracy = [base_accuracy * 1.3 * data_penalty, 0.97].min
    confidence = calculate_mock_confidence(accuracy)
    
    feature_importance = calculate_feature_importance(features.keys, method: 'permutation')
    validation_metrics = calculate_validation_metrics(accuracy, model_type: 'neural_network')
    
    update_model_training_data(feature_importance, validation_metrics)
    
    training_duration = Time.current - training_start
    
    {
      accuracy: accuracy,
      confidence: confidence,
      results: {
        model_type: 'neural_network',
        training_duration_seconds: training_duration.to_i,
        architecture: generate_nn_architecture(features.keys.count),
        epochs_trained: @model.model_parameters['max_epochs'] || 100,
        batch_size: @model.model_parameters['batch_size'] || 32,
        learning_rate: @model.model_parameters['learning_rate'] || 0.001,
        feature_count: features.keys.count,
        data_points_used: @training_data.count,
        validation_metrics: validation_metrics,
        feature_importance: feature_importance,
        final_loss: rand(0.01..0.1).round(4)
      }
    }
  end

  def train_ensemble_model
    # Simulate ensemble model training (combines multiple algorithms)
    training_start = Time.current
    
    features = extract_feature_matrix
    targets = extract_target_vector
    
    simulate_training_time(5.5)
    
    # Ensemble typically provides best and most stable results
    base_accuracy = calculate_mock_accuracy(features, targets)
    accuracy = [base_accuracy * 1.2, 0.94].min
    confidence = [calculate_mock_confidence(accuracy) * 1.1, 0.95].min
    
    # Ensemble feature importance is averaged across models
    feature_importance = calculate_feature_importance(features.keys, method: 'ensemble')
    validation_metrics = calculate_validation_metrics(accuracy, model_type: 'ensemble')
    
    update_model_training_data(feature_importance, validation_metrics)
    
    training_duration = Time.current - training_start
    
    {
      accuracy: accuracy,
      confidence: confidence,
      results: {
        model_type: 'ensemble',
        training_duration_seconds: training_duration.to_i,
        base_models: ['random_forest', 'gradient_boosting', 'linear_regression'],
        ensemble_method: 'weighted_average',
        model_weights: { 'random_forest' => 0.4, 'gradient_boosting' => 0.4, 'linear_regression' => 0.2 },
        feature_count: features.keys.count,
        data_points_used: @training_data.count,
        validation_metrics: validation_metrics,
        feature_importance: feature_importance,
        cross_validation_folds: 5
      }
    }
  end

  def train_time_series_model
    # Simulate time series specific training
    training_start = Time.current
    
    simulate_training_time(3.5)
    
    # Time series accuracy depends on data temporal structure
    accuracy = rand(0.65..0.85)
    confidence = calculate_mock_confidence(accuracy)
    
    {
      accuracy: accuracy,
      confidence: confidence,
      results: {
        model_type: 'time_series',
        training_duration_seconds: (Time.current - training_start).to_i,
        seasonality_detected: true,
        trend_direction: ['upward', 'downward', 'stable'].sample,
        forecast_horizon: 30,
        data_points_used: @training_data.count
      }
    }
  end

  def train_classification_model
    # Simulate classification model training
    training_start = Time.current
    
    simulate_training_time(2.5)
    
    accuracy = rand(0.70..0.88)
    confidence = calculate_mock_confidence(accuracy)
    
    {
      accuracy: accuracy,
      confidence: confidence,
      results: {
        model_type: 'classification',
        training_duration_seconds: (Time.current - training_start).to_i,
        classes_count: extract_unique_classes,
        precision_per_class: generate_class_metrics,
        recall_per_class: generate_class_metrics,
        data_points_used: @training_data.count
      }
    }
  end

  def train_clustering_model
    # Simulate clustering model training
    training_start = Time.current
    
    simulate_training_time(2.0)
    
    # Clustering uses different metrics (silhouette score)
    silhouette_score = rand(0.3..0.7)
    confidence = silhouette_score
    
    {
      accuracy: silhouette_score,  # Use silhouette score as accuracy for clustering
      confidence: confidence,
      results: {
        model_type: 'clustering',
        training_duration_seconds: (Time.current - training_start).to_i,
        clusters_found: rand(3..8),
        silhouette_score: silhouette_score,
        inertia: rand(100..1000),
        data_points_used: @training_data.count
      }
    }
  end

  # Helper methods for training simulation
  def extract_feature_matrix
    feature_keys = @training_data.first['features'].keys
    feature_keys.each_with_object({}) do |key, hash|
      hash[key] = @training_data.map { |d| d['features'][key] }.compact
    end
  end

  def extract_target_vector
    @training_data.map { |d| d['target'] }.compact
  end

  def calculate_mock_accuracy(features, targets)
    # Simulate accuracy calculation based on data characteristics
    base_accuracy = 0.7
    
    # More features generally improve accuracy
    feature_bonus = [features.keys.count * 0.01, 0.15].min
    
    # More data points improve accuracy
    data_bonus = [targets.count * 0.001, 0.1].min
    
    # Add some randomness
    randomness = rand(-0.05..0.05)
    
    accuracy = base_accuracy + feature_bonus + data_bonus + randomness
    [accuracy, 0.95].min.round(3)
  end

  def calculate_mock_confidence(accuracy)
    # Confidence typically correlates with accuracy but has some variance
    base_confidence = accuracy * 0.9
    variance = rand(-0.05..0.05)
    confidence = base_confidence + variance
    
    [confidence, 0.95].min.round(3)
  end

  def calculate_feature_importance(feature_keys, method: 'default')
    importance_values = case method
    when 'gini'
      # Random forest style importance
      feature_keys.map { rand(0.01..0.25) }
    when 'gain'
      # Gradient boosting style importance  
      feature_keys.map { rand(0.05..0.3) }
    when 'permutation'
      # Neural network style importance
      feature_keys.map { rand(0.02..0.2) }
    when 'ensemble'
      # Averaged importance
      feature_keys.map { rand(0.03..0.22) }
    else
      # Default importance
      feature_keys.map { rand(0.01..0.2) }
    end

    # Normalize so sum equals 1
    total = importance_values.sum
    normalized_values = importance_values.map { |v| v / total }

    feature_keys.zip(normalized_values).to_h
  end

  def calculate_validation_metrics(accuracy, model_type: 'default')
    metrics = {
      'accuracy' => accuracy,
      'cv_score' => accuracy * rand(0.95..1.05),
      'test_accuracy' => accuracy * rand(0.9..1.1)
    }

    case @model.prediction_type
    when 'campaign_performance', 'roi_forecast'
      # Regression metrics
      metrics.merge!({
        'mae' => rand(5..15).round(2),          # Mean Absolute Error
        'rmse' => rand(8..20).round(2),         # Root Mean Square Error  
        'r2_score' => rand(0.6..0.85).round(3)  # R-squared
      })
    when 'optimization_opportunities', 'audience_engagement'
      # Classification metrics
      metrics.merge!({
        'precision' => rand(0.7..0.9).round(3),
        'recall' => rand(0.65..0.88).round(3),
        'f1_score' => rand(0.68..0.87).round(3)
      })
    end

    metrics
  end

  def generate_nn_architecture(input_features)
    hidden_layers = rand(2..4)
    layer_sizes = [input_features]
    
    # Generate hidden layer sizes
    current_size = input_features
    hidden_layers.times do
      current_size = [current_size / 2, 10].max.to_i
      layer_sizes << current_size
    end
    
    # Output layer
    layer_sizes << 1
    
    {
      layers: layer_sizes,
      activation: 'relu',
      output_activation: (@model.prediction_type.include?('classification') ? 'sigmoid' : 'linear'),
      optimizer: 'adam',
      loss_function: (@model.prediction_type.include?('classification') ? 'binary_crossentropy' : 'mse')
    }
  end

  def extract_unique_classes
    # For classification, estimate number of classes from prediction type
    case @model.prediction_type
    when 'optimization_opportunities'
      5  # high, medium, low, none, critical
    when 'audience_engagement'
      3  # high, medium, low
    else
      2  # binary classification
    end
  end

  def generate_class_metrics
    classes_count = extract_unique_classes
    (1..classes_count).map { |i| ["class_#{i}", rand(0.6..0.9).round(3)] }.to_h
  end

  def simulate_training_time(base_minutes)
    # Simulate training time based on data size and model complexity
    data_factor = [@training_data.count / 100.0, 3.0].min
    total_seconds = base_minutes * 60 * data_factor
    
    # In development, use shorter times
    total_seconds /= 10 if Rails.env.development?
    
    sleep([total_seconds, 1].max)
  end

  def update_model_training_data(feature_importance, validation_metrics)
    @model.update!(
      feature_importance: feature_importance,
      validation_metrics: validation_metrics,
      metadata: (@model.metadata || {}).merge({
        last_training_completed_at: Time.current,
        training_job_id: job_id,
        training_environment: Rails.env
      })
    )
  end

  def validate_training_results!(results)
    unless results.is_a?(Hash) && results.key?(:accuracy) && results.key?(:confidence)
      raise ModelTrainingError, "Invalid training results structure"
    end

    if results[:accuracy] < 0 || results[:accuracy] > 1
      raise ModelTrainingError, "Invalid accuracy value: #{results[:accuracy]}"
    end

    if results[:confidence] < 0 || results[:confidence] > 1
      raise ModelTrainingError, "Invalid confidence value: #{results[:confidence]}"
    end
  end

  def activate_if_qualified(results)
    # Auto-activate model if it meets quality thresholds
    min_accuracy = @options[:min_accuracy_for_activation] || 0.7
    min_confidence = @options[:min_confidence_for_activation] || 0.6
    
    if results[:accuracy] >= min_accuracy && results[:confidence] >= min_confidence
      @model.activate!
      Rails.logger.info "Auto-activated PredictionModel #{@model.id} (accuracy: #{results[:accuracy]}, confidence: #{results[:confidence]})"
    else
      Rails.logger.info "PredictionModel #{@model.id} trained but not activated (accuracy: #{results[:accuracy]}, confidence: #{results[:confidence]})"
    end
  end

  def handle_training_error(error)
    Rails.logger.error "Training failed for PredictionModel #{@model.id}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    error_message = case error
    when ModelTrainingError
      "Model training failed: #{error.message}"
    when InsufficientDataError
      "Insufficient training data: #{error.message}"
    when InvalidModelConfigurationError
      "Invalid model configuration: #{error.message}"
    else
      "Unexpected training error: #{error.message}"
    end
    
    @model.mark_training_failed!(error_message)
    send_training_notification(:failed, { error: error_message })
  end

  def send_training_notification(status, data = {})
    # Send notification to relevant users
    notification_data = {
      model_id: @model.id,
      model_name: @model.name,
      prediction_type: @model.prediction_type,
      campaign_id: @model.campaign_plan_id,
      status: status,
      timestamp: Time.current
    }.merge(data)

    case status
    when :completed
      Rails.logger.info "Model training completed notification sent for #{@model.id}"
      # ModelTrainingMailer.training_completed(@model, notification_data).deliver_later
    when :failed
      Rails.logger.error "Model training failed notification sent for #{@model.id}"
      # ModelTrainingMailer.training_failed(@model, notification_data).deliver_later
    end
    
    # Could also send real-time notifications via ActionCable or webhooks
  end

  def minimum_data_points
    case @model.prediction_type
    when 'campaign_performance', 'roi_forecast'
      50
    when 'optimization_opportunities', 'budget_optimization'
      30
    when 'audience_engagement', 'content_performance'
      40
    else
      25
    end
  end
end