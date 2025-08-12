# AI Monitoring Dashboard Controller
# Provides web interface for AI service monitoring and analytics
class AiMonitoringController < ApplicationController
  before_action :set_time_range, only: [:index, :metrics, :costs, :performance]
  before_action :set_filters, only: [:index, :metrics, :costs, :performance]

  def index
    @health_status = AiMonitoringService.health_status
    @real_time_costs = AiCostTracker.real_time_costs
    @recent_alerts = AiAlertingService.alert_statistics(1.hour)
    
    # Quick stats for dashboard
    @quick_stats = {
      requests_last_hour: @health_status[:metrics][:requests_per_minute] * 60,
      average_response_time: @health_status[:metrics][:average_response_time],
      error_rate: @health_status[:metrics][:error_rate],
      hourly_cost: @real_time_costs[:current_hour_cost]
    }
    
    respond_to do |format|
      format.html
      format.json { render json: { health: @health_status, costs: @real_time_costs, alerts: @recent_alerts } }
    end
  end

  def metrics
    @metrics = AiMonitoringService.get_metrics(@time_range, @filters[:provider])
    @performance_analysis = AiMonitoringService.performance_analysis(@time_range)
    
    respond_to do |format|
      format.html
      format.json { render json: { metrics: @metrics, performance: @performance_analysis } }
    end
  end

  def costs
    @cost_analysis = AiCostTracker.cost_analysis(@time_range, @filters)
    @budget_status = AiCostTracker.check_budget_status(@time_range)
    @optimization_recommendations = AiCostTracker.optimization_recommendations(@time_range)
    
    respond_to do |format|
      format.html
      format.json { render json: { costs: @cost_analysis, budget: @budget_status, recommendations: @optimization_recommendations } }
    end
  end

  def performance
    @performance_metrics = AiMonitoringService.get_metrics(@time_range, @filters[:provider])[:performance]
    @error_analysis = AiMonitoringService.get_metrics(@time_range, @filters[:provider])[:errors]
    @provider_comparison = compare_provider_performance
    
    respond_to do |format|
      format.html
      format.json { render json: { performance: @performance_metrics, errors: @error_analysis, providers: @provider_comparison } }
    end
  end

  def alerts
    @alert_stats = AiAlertingService.alert_statistics(@time_range)
    @recent_alerts = AiAlertingService.instance.alert_history.last(50).reverse
    
    respond_to do |format|
      format.html
      format.json { render json: { stats: @alert_stats, recent: @recent_alerts } }
    end
  end

  def health_check
    @health = AiMonitoringService.health_status
    @provider_health = {}
    
    # Check each provider individually
    ['anthropic', 'openai', 'gemini'].each do |provider|
      @provider_health[provider] = AiAlertingService.service_alert_status(provider)
    end
    
    respond_to do |format|
      format.html
      format.json { render json: { overall: @health, providers: @provider_health } }
    end
  end

  def export
    format = params[:format] || 'csv'
    data_type = params[:data_type] || 'metrics'
    
    case data_type
    when 'metrics'
      data = AiMonitoringService.export_metrics(format.to_sym)
      filename = "ai_metrics_#{Date.current}.#{format}"
    when 'costs'
      data = AiCostTracker.export_cost_data(@time_range, format.to_sym)
      filename = "ai_costs_#{Date.current}.#{format}"
    when 'alerts'
      data = export_alerts_data(format.to_sym)
      filename = "ai_alerts_#{Date.current}.#{format}"
    else
      return head :bad_request
    end

    send_data data, filename: filename, type: content_type_for_format(format)
  end

  # Real-time streaming endpoint for live monitoring
  def stream
    response.headers['Content-Type'] = 'text/plain'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Connection'] = 'keep-alive'
    
    # Set up SSE streaming
    sse = SSEWriter.new(response.stream)
    
    begin
      # Send initial data
      sse.write({
        type: 'initial',
        data: {
          health: AiMonitoringService.health_status,
          costs: AiCostTracker.real_time_costs
        }
      })
      
      # Keep connection alive and send updates every 10 seconds
      loop do
        sleep 10
        
        sse.write({
          type: 'update',
          timestamp: Time.current.iso8601,
          data: {
            health: AiMonitoringService.health_status,
            costs: AiCostTracker.real_time_costs,
            alerts: AiAlertingService.alert_statistics(10.minutes)
          }
        })
      end
    rescue IOError
      # Client disconnected
      Rails.logger.info "[AI_MONITORING] Client disconnected from stream"
    ensure
      sse.close
    end
  end

  private

  def set_time_range
    @time_range = case params[:period]
                  when '1h' then 1.hour
                  when '6h' then 6.hours
                  when '24h' then 24.hours
                  when '7d' then 7.days
                  when '30d' then 30.days
                  else 24.hours
                  end
  end

  def set_filters
    @filters = {
      provider: params[:provider].presence,
      operation_type: params[:operation_type].presence,
      user_id: params[:user_id].presence
    }.compact
  end

  def compare_provider_performance
    providers = ['anthropic', 'openai', 'gemini']
    comparison = {}
    
    providers.each do |provider|
      metrics = AiMonitoringService.get_metrics(@time_range, provider)
      comparison[provider] = {
        requests: metrics[:summary][:total_requests],
        success_rate: metrics[:summary][:success_rate],
        average_duration: metrics[:performance][:average_duration],
        error_rate: metrics[:summary][:error_rate]
      }
    end
    
    comparison
  end

  def export_alerts_data(format)
    alerts = AiAlertingService.instance.alert_history
    
    case format
    when :csv
      require 'csv'
      CSV.generate do |csv|
        csv << ['Timestamp', 'Type', 'Severity', 'Provider', 'Description', 'Escalated']
        alerts.each do |alert|
          csv << [
            alert[:timestamp],
            alert[:type],
            alert[:severity],
            alert[:data][:provider],
            alert[:description],
            alert[:escalated]
          ]
        end
      end
    when :json
      alerts.to_json
    else
      alerts
    end
  end

  def content_type_for_format(format)
    case format
    when 'csv' then 'text/csv'
    when 'json' then 'application/json'
    when 'xlsx' then 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else 'text/plain'
    end
  end

  # Server-Sent Events writer
  class SSEWriter
    def initialize(stream)
      @stream = stream
    end

    def write(data)
      @stream.write "data: #{data.to_json}\n\n"
    rescue IOError
      # Client disconnected
    end

    def close
      @stream.close rescue nil
    end
  end
end