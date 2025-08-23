# frozen_string_literal: true

# Base class for external API clients
# Provides common functionality for HTTP requests, error handling, and retry logic
class ExternalPlatforms::BaseApiClient
  include LlmServiceHelper

  # Standard HTTP client setup with retries
  attr_reader :connection, :platform_name, :base_url, :timeout

  def initialize(platform_name, base_url, timeout: 30)
    @platform_name = platform_name
    @base_url = base_url
    @timeout = timeout
    @connection = setup_connection
  end

  # Check if API is available/healthy
  def health_check
    begin
      start_time = Time.current
      response = get_request(health_check_path)
      duration = Time.current - start_time
      
      if response[:success]
        {
          status: :healthy,
          platform: platform_name,
          response_time: duration,
          last_checked: Time.current
        }
      else
        {
          status: :unhealthy,
          platform: platform_name,
          error: response[:message] || 'Health check failed',
          last_checked: Time.current
        }
      end
    rescue => error
      {
        status: :unhealthy,
        platform: platform_name,
        error: error.message,
        last_checked: Time.current
      }
    end
  end

  # Get platform-specific rate limit information
  def rate_limit_status
    # Override in subclasses to provide platform-specific rate limit checking
    { available: true, platform: platform_name }
  end

  protected

  # Setup Faraday connection with common middleware
  def setup_connection
    Faraday.new(url: base_url) do |conn|
      # Request/Response logging
      conn.request :json
      conn.response :json, content_type: /\bjson$/
      
      # Retry configuration
      conn.request :retry,
        max: 3,
        interval: 0.5,
        interval_randomness: 0.5,
        backoff_factor: 2,
        retry_statuses: [429, 500, 502, 503, 504],
        methods: [:get, :post, :put, :delete],
        retry_if: ->(env, _exception) { retriable_request?(env) }

      # Timeout configuration
      conn.options.timeout = timeout
      conn.options.open_timeout = timeout / 2

      # Default adapter
      conn.adapter Faraday.default_adapter
    end
  end

  # Make GET request with error handling
  def get_request(path, params = {}, headers = {})
    make_request(:get, path, params, headers)
  end

  # Make POST request with error handling
  def post_request(path, body = {}, headers = {})
    make_request(:post, path, body, headers)
  end

  # Make PUT request with error handling
  def put_request(path, body = {}, headers = {})
    make_request(:put, path, body, headers)
  end

  # Make DELETE request with error handling
  def delete_request(path, params = {}, headers = {})
    make_request(:delete, path, params, headers)
  end

  private

  # Central request handler with comprehensive error handling
  def make_request(method, path, data, headers)
    log_request(method, path, data)
    
    request_start = Time.current
    response = connection.public_send(method) do |req|
      req.url path
      req.headers.merge!(default_headers.merge(headers))
      
      case method
      when :get, :delete
        req.params = data if data.present?
      when :post, :put
        req.body = data if data.present?
      end
    end

    log_response(response, Time.current - request_start)
    handle_response(response)

  rescue Faraday::TimeoutError => error
    handle_timeout_error(error, method, path)
  rescue Faraday::ConnectionFailed => error
    handle_connection_error(error, method, path)
  rescue Faraday::UnauthorizedError => error
    handle_auth_error(error, method, path)
  rescue Faraday::ClientError => error
    handle_client_error(error, method, path)
  rescue Faraday::ServerError => error
    handle_server_error(error, method, path)
  rescue StandardError => error
    handle_generic_error(error, method, path)
  end

  # Handle successful responses and extract data
  def handle_response(response)
    case response.status
    when 200..299
      {
        success: true,
        data: response.body,
        status: response.status,
        headers: response.headers.to_h,
        platform: platform_name
      }
    when 400..499
      handle_client_response_error(response)
    when 500..599
      handle_server_response_error(response)
    else
      handle_unknown_response_error(response)
    end
  end

  # Default headers for all requests
  def default_headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'User-Agent' => "#{Rails.application.class.module_parent_name}/1.0"
    }
  end

  # Platform-specific health check endpoint
  def health_check_path
    '/health' # Override in subclasses
  end

  # Determine if request should be retried
  def retriable_request?(env)
    # Don't retry POST requests by default to avoid duplicate operations
    return false if env.method == :post
    
    # Check if error is temporary
    return true if env.status.in?([429, 500, 502, 503, 504])
    
    false
  end

  # Error handling methods
  def handle_timeout_error(error, method, path)
    Rails.logger.error "#{platform_name} API timeout: #{method.upcase} #{path} - #{error.message}"
    
    {
      success: false,
      error: 'timeout',
      message: "Request to #{platform_name} timed out after #{timeout} seconds",
      platform: platform_name,
      retry_after: 60
    }
  end

  def handle_connection_error(error, method, path)
    Rails.logger.error "#{platform_name} API connection failed: #{method.upcase} #{path} - #{error.message}"
    
    {
      success: false,
      error: 'connection_failed',
      message: "Failed to connect to #{platform_name} API",
      platform: platform_name,
      retry_after: 120
    }
  end

  def handle_auth_error(error, method, path)
    Rails.logger.error "#{platform_name} API authentication failed: #{method.upcase} #{path} - #{error.message}"
    
    {
      success: false,
      error: 'authentication_failed',
      message: "Authentication failed for #{platform_name} API",
      platform: platform_name,
      requires_reauth: true
    }
  end

  def handle_client_error(error, method, path)
    Rails.logger.error "#{platform_name} API client error: #{method.upcase} #{path} - #{error.message}"
    
    {
      success: false,
      error: 'client_error',
      message: "Client error: #{error.message}",
      platform: platform_name,
      status: error.response[:status]
    }
  end

  def handle_server_error(error, method, path)
    Rails.logger.error "#{platform_name} API server error: #{method.upcase} #{path} - #{error.message}"
    
    {
      success: false,
      error: 'server_error',
      message: "Server error: #{error.message}",
      platform: platform_name,
      status: error.response[:status],
      retry_after: 300
    }
  end

  def handle_generic_error(error, method, path)
    Rails.logger.error "#{platform_name} API generic error: #{method.upcase} #{path} - #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
    
    {
      success: false,
      error: 'api_error',
      message: "API error: #{error.message}",
      platform: platform_name
    }
  end

  def handle_client_response_error(response)
    error_message = extract_error_message(response.body)
    Rails.logger.warn "#{platform_name} API client response error (#{response.status}): #{error_message}"
    
    {
      success: false,
      error: 'client_response_error',
      message: error_message,
      platform: platform_name,
      status: response.status,
      response_body: response.body
    }
  end

  def handle_server_response_error(response)
    error_message = extract_error_message(response.body)
    Rails.logger.error "#{platform_name} API server response error (#{response.status}): #{error_message}"
    
    {
      success: false,
      error: 'server_response_error',
      message: error_message,
      platform: platform_name,
      status: response.status,
      retry_after: determine_retry_after(response.headers)
    }
  end

  def handle_unknown_response_error(response)
    Rails.logger.error "#{platform_name} API unknown response status (#{response.status})"
    
    {
      success: false,
      error: 'unknown_response',
      message: "Unknown response status: #{response.status}",
      platform: platform_name,
      status: response.status
    }
  end

  # Extract error message from response body
  def extract_error_message(body)
    return 'Unknown error' unless body.is_a?(Hash)
    
    # Try common error message fields
    body['error_description'] ||
    body['error_message'] ||
    body['message'] ||
    body['error'] ||
    'API request failed'
  end

  # Determine retry delay from response headers
  def determine_retry_after(headers)
    retry_after = headers['Retry-After'] || headers['retry-after']
    return 60 unless retry_after
    
    # Handle both seconds and HTTP-date formats
    retry_after.to_i > 0 ? retry_after.to_i : 60
  end

  # Request logging
  def log_request(method, path, data)
    return unless Rails.env.development?
    
    Rails.logger.info "#{platform_name} API Request: #{method.upcase} #{path}"
    Rails.logger.debug "Request Data: #{data.inspect}" if data.present?
  end

  # Response logging
  def log_response(response, duration)
    return unless Rails.env.development?
    
    Rails.logger.info "#{platform_name} API Response: #{response.status} (#{duration.round(3)}s)"
    Rails.logger.debug "Response Body: #{response.body}" if response.body.present?
  end
end