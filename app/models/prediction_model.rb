class PredictionModel < ApplicationRecord
  belongs_to :campaign_plan
  belongs_to :created_by, class_name: 'User'
  belongs_to :trained_by, class_name: 'User', optional: true
  belongs_to :activated_by, class_name: 'User', optional: true

  PREDICTION_TYPES = %w[
    campaign_performance
    optimization_opportunities
    market_trends
    audience_engagement
    budget_optimization
    timeline_adjustment
    content_performance
    roi_forecast
  ].freeze

  MODEL_TYPES = %w[
    linear_regression
    random_forest
    gradient_boosting
    neural_network
    ensemble
    time_series
    classification
    clustering
  ].freeze

  STATUSES = %w[
    draft
    training
    trained
    active
    deprecated
    failed
    archived
  ].freeze

  ACCURACY_LEVELS = %w[low medium high excellent].freeze

  validates :name, presence: true, length: { maximum: 255 }
  validates :prediction_type, presence: true, inclusion: { in: PREDICTION_TYPES }
  validates :model_type, presence: true, inclusion: { in: MODEL_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :version, presence: true, uniqueness: { scope: [:campaign_plan_id, :prediction_type] }
  validates :accuracy_score, presence: true, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
  validates :confidence_level, presence: true, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }

  # JSON columns are automatically serialized in Rails 8.0+

  scope :by_prediction_type, ->(type) { where(prediction_type: type) }
  scope :by_model_type, ->(type) { where(model_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :active, -> { where(status: 'active') }
  scope :trained, -> { where(status: %w[trained active]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :high_accuracy, -> { where('accuracy_score >= ?', 0.8) }
  scope :current_version, -> { 
    joins(:campaign_plan)
      .where(status: %w[active trained])
      .group(:campaign_plan_id, :prediction_type)
      .having('version = MAX(version)')
  }

  before_validation :set_defaults, on: :create
  after_create :log_model_creation
  after_update :log_model_update, if: :saved_changes?

  def draft?
    status == 'draft'
  end

  def training?
    status == 'training'
  end

  def trained?
    status == 'trained'
  end

  def active?
    status == 'active'
  end

  def deprecated?
    status == 'deprecated'
  end

  def failed?
    status == 'failed'
  end

  def archived?
    status == 'archived'
  end

  def ready_for_training?
    draft? && training_data.present? && training_data.is_a?(Array) && training_data.any?
  end

  def can_be_activated?
    trained? && accuracy_score >= 0.5 && confidence_level >= 0.6
  end

  def accuracy_level
    case accuracy_score
    when 0.0...0.5
      'low'
    when 0.5...0.7
      'medium'
    when 0.7...0.9
      'high'
    when 0.9..1.0
      'excellent'
    else
      'unknown'
    end
  end

  def training_duration_minutes
    return nil unless training_started_at && training_completed_at
    
    ((training_completed_at - training_started_at) / 60.0).round(2)
  end

  def days_since_trained
    return nil unless training_completed_at
    
    ((Time.current - training_completed_at) / 1.day).round(1)
  end

  def is_current_version?
    self.class.where(campaign_plan: campaign_plan, prediction_type: prediction_type)
              .where('version > ?', version)
              .empty?
  end

  def previous_version
    self.class.where(campaign_plan: campaign_plan, prediction_type: prediction_type)
              .where('version < ?', version)
              .order(version: :desc)
              .first
  end

  def next_version
    self.class.where(campaign_plan: campaign_plan, prediction_type: prediction_type)
              .where('version > ?', version)
              .order(version: :asc)
              .first
  end

  def activate!
    return false unless can_be_activated?

    transaction do
      # Deprecate other active models of same type for this campaign
      self.class.where(campaign_plan: campaign_plan, prediction_type: prediction_type)
                .where.not(id: id)
                .where(status: 'active')
                .update_all(status: 'deprecated', deprecated_at: Time.current)

      update!(
        status: 'active',
        activated_at: Time.current,
        activated_by: Current.user || created_by
      )
    end

    true
  end

  def deprecate!
    return false unless active?

    update!(
      status: 'deprecated',
      deprecated_at: Time.current
    )
  end

  def mark_training_started!(user = nil)
    update!(
      status: 'training',
      training_started_at: Time.current,
      trained_by: user || Current.user || created_by
    )
  end

  def mark_training_completed!(accuracy, confidence, results = {})
    update!(
      status: 'trained',
      training_completed_at: Time.current,
      accuracy_score: accuracy,
      confidence_level: confidence,
      prediction_results: results
    )
  end

  def mark_training_failed!(error_message)
    update!(
      status: 'failed',
      training_failed_at: Time.current,
      error_message: error_message,
      metadata: (metadata || {}).merge(
        last_error: error_message,
        failed_at: Time.current
      )
    )
  end

  def generate_prediction(input_data = {})
    return { success: false, error: 'Model not active' } unless active?
    return { success: false, error: 'Invalid input data' } unless input_data.is_a?(Hash)

    begin
      # Simulate prediction generation based on model type and input
      prediction_data = case prediction_type
      when 'campaign_performance'
        generate_campaign_performance_prediction(input_data)
      when 'optimization_opportunities'
        generate_optimization_prediction(input_data)
      when 'roi_forecast'
        generate_roi_forecast(input_data)
      when 'audience_engagement'
        generate_engagement_prediction(input_data)
      else
        generate_generic_prediction(input_data)
      end

      # Update model usage statistics
      increment_usage_count

      {
        success: true,
        prediction: prediction_data,
        confidence: confidence_level,
        model_version: version,
        generated_at: Time.current
      }
    rescue => e
      Rails.logger.error "Prediction generation failed for model #{id}: #{e.message}"
      {
        success: false,
        error: e.message
      }
    end
  end

  def model_summary
    {
      id: id,
      name: name,
      prediction_type: prediction_type,
      model_type: model_type,
      status: status,
      version: version,
      accuracy: {
        score: accuracy_score,
        level: accuracy_level,
        confidence: confidence_level
      },
      training: {
        started_at: training_started_at,
        completed_at: training_completed_at,
        duration_minutes: training_duration_minutes
      },
      usage: {
        prediction_count: prediction_count || 0,
        last_prediction_at: last_prediction_at,
        is_current_version: is_current_version?
      },
      created_by: created_by&.full_name,
      created_at: created_at
    }
  end

  def validation_summary
    return {} unless validation_metrics.present?

    metrics = validation_metrics
    {
      cross_validation_score: metrics['cv_score'],
      test_accuracy: metrics['test_accuracy'],
      precision: metrics['precision'],
      recall: metrics['recall'],
      f1_score: metrics['f1_score'],
      mae: metrics['mae'], # Mean Absolute Error
      rmse: metrics['rmse'], # Root Mean Square Error
      r2_score: metrics['r2_score']
    }
  end

  def feature_analysis
    return {} unless feature_importance.present?

    {
      top_features: feature_importance.sort_by { |_, importance| -importance }.first(10),
      total_features: feature_importance.keys.count,
      feature_distribution: analyze_feature_distribution
    }
  end

  private

  def set_defaults
    self.status ||= 'draft'
    self.version ||= calculate_next_version
    self.accuracy_score ||= 0.0
    self.confidence_level ||= 0.0
    self.metadata = {} if metadata.nil?
    self.prediction_count ||= 0
  end

  def calculate_next_version
    max_version = self.class.where(campaign_plan: campaign_plan, prediction_type: prediction_type)
                            .maximum(:version) || 0
    max_version + 1
  end

  def increment_usage_count
    increment!(:prediction_count)
    touch(:last_prediction_at)
  end

  def generate_campaign_performance_prediction(input_data)
    base_performance = campaign_plan.performance_score || 70
    
    # Simulate ML-based performance prediction
    predicted_metrics = {
      engagement_rate: calculate_engagement_prediction(base_performance, input_data),
      conversion_rate: calculate_conversion_prediction(base_performance, input_data),
      reach_estimate: calculate_reach_prediction(input_data),
      cost_per_acquisition: calculate_cpa_prediction(input_data),
      roi_projection: calculate_roi_projection(base_performance, input_data)
    }

    {
      performance_score: predicted_metrics.values.sum / predicted_metrics.count,
      detailed_metrics: predicted_metrics,
      recommendations: generate_performance_recommendations(predicted_metrics),
      prediction_date: Time.current,
      data_points_used: training_data&.count || 0
    }
  end

  def generate_optimization_prediction(input_data)
    opportunities = []

    # Budget optimization
    if input_data['current_budget']
      opportunities << {
        type: 'budget_reallocation',
        impact: 'high',
        recommendation: 'Reallocate 15% of budget from low-performing channels to high-ROI segments',
        potential_improvement: '12-18%'
      }
    end

    # Timeline optimization
    opportunities << {
      type: 'timeline_adjustment',
      impact: 'medium',
      recommendation: 'Extend campaign by 2 weeks during peak season',
      potential_improvement: '8-12%'
    }

    # Content optimization
    opportunities << {
      type: 'content_optimization',
      impact: 'high',
      recommendation: 'Increase video content ratio from 30% to 55%',
      potential_improvement: '15-22%'
    }

    {
      total_opportunities: opportunities.count,
      high_impact_count: opportunities.count { |o| o[:impact] == 'high' },
      opportunities: opportunities,
      projected_overall_improvement: '20-35%',
      confidence_interval: [confidence_level - 0.1, confidence_level + 0.1]
    }
  end

  def generate_roi_forecast(input_data)
    base_roi = campaign_plan.current_roi || 150
    budget = input_data['budget']&.to_f || 10000

    # Simulate ROI prediction based on historical data
    predicted_roi = base_roi * (1 + (accuracy_score * 0.3))
    
    {
      projected_roi: predicted_roi.round(2),
      roi_range: [(predicted_roi * 0.85).round(2), (predicted_roi * 1.15).round(2)],
      break_even_point: (budget / (predicted_roi / 100)).round(2),
      projected_revenue: (budget * predicted_roi / 100).round(2),
      time_to_roi: calculate_time_to_roi(predicted_roi),
      risk_factors: identify_roi_risk_factors(input_data)
    }
  end

  def generate_engagement_prediction(input_data)
    base_engagement = campaign_plan.engagement_score || 60
    
    # Simulate engagement prediction
    predicted_engagement = base_engagement * (1 + (accuracy_score * 0.2))
    
    {
      overall_engagement_score: predicted_engagement.round(1),
      channel_breakdown: generate_channel_engagement_breakdown,
      peak_engagement_times: generate_peak_time_predictions,
      audience_segments: generate_segment_engagement_predictions,
      content_type_performance: generate_content_type_predictions
    }
  end

  def generate_generic_prediction(input_data)
    {
      prediction_type: prediction_type,
      confidence_score: confidence_level,
      generated_insights: "Prediction generated for #{prediction_type}",
      data_quality: assess_data_quality(input_data),
      recommendations: ["Monitor performance closely", "Adjust parameters based on results"]
    }
  end

  def calculate_engagement_prediction(base_performance, input_data)
    adjustment = (accuracy_score - 0.5) * 10
    [(base_performance + adjustment) * 0.01, 0.15].min
  end

  def calculate_conversion_prediction(base_performance, input_data)
    adjustment = (accuracy_score - 0.5) * 8
    [(base_performance + adjustment) * 0.005, 0.08].min
  end

  def calculate_reach_prediction(input_data)
    budget = input_data['budget']&.to_f || 5000
    (budget * (50 + accuracy_score * 30)).round(0)
  end

  def calculate_cpa_prediction(input_data)
    base_cpa = input_data['current_cpa']&.to_f || 25
    improvement = accuracy_score * 0.2
    (base_cpa * (1 - improvement)).round(2)
  end

  def calculate_roi_projection(base_performance, input_data)
    base_roi = input_data['current_roi']&.to_f || 150
    (base_roi * (1 + accuracy_score * 0.25)).round(2)
  end

  def generate_performance_recommendations(metrics)
    recommendations = []
    
    if metrics[:engagement_rate] < 0.03
      recommendations << "Increase interactive content to improve engagement"
    end
    
    if metrics[:conversion_rate] < 0.02
      recommendations << "Optimize call-to-action placement and messaging"
    end
    
    if metrics[:roi_projection] < 200
      recommendations << "Consider budget reallocation to higher-performing channels"
    end
    
    recommendations
  end

  def calculate_time_to_roi(roi)
    case roi
    when 0..100
      '6-8 months'
    when 101..200
      '3-4 months'
    when 201..300
      '2-3 months'
    else
      '1-2 months'
    end
  end

  def identify_roi_risk_factors(input_data)
    risk_factors = []
    
    if input_data['market_volatility'] == 'high'
      risk_factors << 'High market volatility may impact returns'
    end
    
    if input_data['competition_level'] == 'high'
      risk_factors << 'Increased competition may reduce effectiveness'
    end
    
    if input_data['seasonal_factors'] == 'negative'
      risk_factors << 'Seasonal trends may negatively impact performance'
    end
    
    risk_factors
  end

  def generate_channel_engagement_breakdown
    {
      'social_media' => (60 + rand(20)).round(1),
      'email' => (45 + rand(15)).round(1),
      'paid_search' => (70 + rand(20)).round(1),
      'display' => (35 + rand(15)).round(1),
      'video' => (80 + rand(15)).round(1)
    }
  end

  def generate_peak_time_predictions
    [
      { day: 'Tuesday', time: '10:00 AM', engagement_multiplier: 1.8 },
      { day: 'Wednesday', time: '2:00 PM', engagement_multiplier: 1.6 },
      { day: 'Thursday', time: '7:00 PM', engagement_multiplier: 1.9 }
    ]
  end

  def generate_segment_engagement_predictions
    {
      'millennials' => 75 + rand(15),
      'gen_z' => 85 + rand(10),
      'gen_x' => 55 + rand(20),
      'professionals' => 65 + rand(15),
      'students' => 80 + rand(12)
    }
  end

  def generate_content_type_predictions
    {
      'video' => 85 + rand(10),
      'images' => 70 + rand(15),
      'text' => 50 + rand(20),
      'interactive' => 90 + rand(8),
      'stories' => 75 + rand(12)
    }
  end

  def assess_data_quality(input_data)
    return 'low' if input_data.blank? || input_data.keys.count < 3
    return 'high' if input_data.keys.count > 10 && input_data.values.all?(&:present?)
    'medium'
  end

  def analyze_feature_distribution
    return {} unless feature_importance.present?
    
    importance_values = feature_importance.values
    {
      mean_importance: importance_values.sum / importance_values.count,
      max_importance: importance_values.max,
      min_importance: importance_values.min,
      features_above_average: importance_values.count { |v| v > importance_values.sum / importance_values.count }
    }
  end

  def log_model_creation
    Rails.logger.info "PredictionModel created: #{name} (#{prediction_type}) for campaign #{campaign_plan_id}"
  end

  def log_model_update
    Rails.logger.info "PredictionModel updated: #{name} - Status: #{status}, Accuracy: #{accuracy_score}"
  end
end