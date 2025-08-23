# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

class ExternalPlatforms::BaseApiClientTest < ActiveSupport::TestCase
  class TestApiClient < ExternalPlatforms::BaseApiClient
    def initialize
      super('Test Platform', 'https://api.example.com', timeout: 10)
    end
  end

  def setup
    @client = TestApiClient.new
  end

  test "initializes with correct attributes" do
    assert_equal 'Test Platform', @client.platform_name
    assert_equal 'https://api.example.com', @client.base_url
    assert_equal 10, @client.timeout
    assert_not_nil @client.connection
  end

  test "connection has correct configuration" do
    connection = @client.connection
    assert_equal 'https://api.example.com/', connection.url_prefix.to_s
    assert_equal 10, connection.options.timeout
    assert_equal 5, connection.options.open_timeout
  end

  test "default headers include correct content type and user agent" do
    default_headers = @client.send(:default_headers)
    assert_equal 'application/json', default_headers['Content-Type']
    assert_equal 'application/json', default_headers['Accept']
    assert_includes default_headers['User-Agent'], 'MarketerGen'
  end

  test "health check returns status structure" do
    # Mock the get_request method to return a successful response
    successful_response = {
      success: true,
      data: { status: 'ok' },
      status: 200,
      headers: {},
      platform: 'Test Platform'
    }
    
    @client.expects(:get_request).with('/health').returns(successful_response)
    
    result = @client.health_check
    assert_equal :healthy, result[:status]
    assert_equal 'Test Platform', result[:platform]
    assert result[:response_time]
    assert result[:last_checked]
  end

  test "health check handles errors gracefully" do
    @client.expects(:get_request).with('/health').raises(Faraday::ConnectionFailed.new('Connection failed'))
    
    result = @client.health_check
    assert_equal :unhealthy, result[:status]
    assert_equal 'Test Platform', result[:platform]
    assert_includes result[:error], 'Connection failed'
    assert result[:last_checked]
  end

  test "rate limit status returns default structure" do
    result = @client.rate_limit_status
    assert result[:available]
    assert_equal 'Test Platform', result[:platform]
  end

  test "make_request handles timeout errors" do
    @client.connection.expects(:get).raises(Faraday::TimeoutError.new('timeout'))
    
    result = @client.send(:make_request, :get, '/test', {}, {})
    
    assert_not result[:success]
    assert_equal 'timeout', result[:error]
    assert_includes result[:message], 'timed out'
    assert_equal 60, result[:retry_after]
  end

  test "make_request handles connection errors" do
    @client.connection.expects(:get).raises(Faraday::ConnectionFailed.new('connection failed'))
    
    result = @client.send(:make_request, :get, '/test', {}, {})
    
    assert_not result[:success]
    assert_equal 'connection_failed', result[:error]
    assert_includes result[:message], 'Failed to connect'
    assert_equal 120, result[:retry_after]
  end

  test "make_request handles authentication errors" do
    error_response = Struct.new(:status, :body).new(401, 'Unauthorized')
    @client.connection.expects(:get).raises(Faraday::UnauthorizedError.new(nil, error_response))
    
    result = @client.send(:make_request, :get, '/test', {}, {})
    
    assert_not result[:success]
    assert_equal 'authentication_failed', result[:error]
    assert result[:requires_reauth]
  end

  test "make_request handles successful responses" do
    mock_response = Struct.new(:status, :body, :headers, :env).new(
      200,
      { data: 'test' },
      { 'X-Rate-Limit' => '100' },
      Struct.new(:duration).new(0.2)
    )
    
    @client.connection.expects(:get).returns(mock_response)
    
    result = @client.send(:make_request, :get, '/test', {}, {})
    
    assert result[:success]
    assert_equal({ data: 'test' }, result[:data])
    assert_equal 200, result[:status]
    assert_equal({ 'X-Rate-Limit' => '100' }, result[:headers])
  end

  test "make_request handles client errors" do
    mock_response = Struct.new(:status, :body, :headers).new(
      400,
      { error: 'Bad request' },
      {}
    )
    
    @client.connection.expects(:get).returns(mock_response)
    
    result = @client.send(:make_request, :get, '/test', {}, {})
    
    assert_not result[:success]
    assert_equal 'client_response_error', result[:error]
    assert_equal 400, result[:status]
  end

  test "make_request handles server errors" do
    mock_response = Struct.new(:status, :body, :headers).new(
      500,
      { error: 'Internal server error' },
      { 'Retry-After' => '60' }
    )
    
    @client.connection.expects(:get).returns(mock_response)
    
    result = @client.send(:make_request, :get, '/test', {}, {})
    
    assert_not result[:success]
    assert_equal 'server_response_error', result[:error]
    assert_equal 500, result[:status]
    assert_equal 60, result[:retry_after]
  end

  test "extract_error_message handles various error formats" do
    # Hash with error_description
    error_body = { 'error_description' => 'Test error description' }
    message = @client.send(:extract_error_message, error_body)
    assert_equal 'Test error description', message

    # Hash with message
    error_body = { 'message' => 'Test message' }
    message = @client.send(:extract_error_message, error_body)
    assert_equal 'Test message', message

    # Hash with error
    error_body = { 'error' => 'Test error' }
    message = @client.send(:extract_error_message, error_body)
    assert_equal 'Test error', message

    # Non-hash
    message = @client.send(:extract_error_message, 'not a hash')
    assert_equal 'Unknown error', message

    # Empty hash
    message = @client.send(:extract_error_message, {})
    assert_equal 'API request failed', message
  end

  test "determine_retry_after handles various header formats" do
    # Numeric retry-after
    headers = { 'Retry-After' => '120' }
    retry_after = @client.send(:determine_retry_after, headers)
    assert_equal 120, retry_after

    # No retry-after header
    headers = {}
    retry_after = @client.send(:determine_retry_after, headers)
    assert_equal 60, retry_after

    # Invalid retry-after
    headers = { 'retry-after' => 'invalid' }
    retry_after = @client.send(:determine_retry_after, headers)
    assert_equal 60, retry_after
  end

  test "retriable_request? handles different scenarios" do
    # POST request should not be retried by default
    post_env = OpenStruct.new(method: :post, status: 500)
    assert_not @client.send(:retriable_request?, post_env)

    # GET request with retryable status should be retried
    get_env = OpenStruct.new(method: :get, status: 429)
    assert @client.send(:retriable_request?, get_env)

    # GET request with non-retryable status should not be retried
    get_env = OpenStruct.new(method: :get, status: 400)
    assert_not @client.send(:retriable_request?, get_env)
  end

  test "convenience methods call make_request with correct parameters" do
    @client.expects(:make_request).with(:get, '/test', { param: 'value' }, { 'Custom' => 'Header' })
    @client.send(:get_request, '/test', { param: 'value' }, { 'Custom' => 'Header' })

    @client.expects(:make_request).with(:post, '/test', { data: 'value' }, { 'Custom' => 'Header' })
    @client.send(:post_request, '/test', { data: 'value' }, { 'Custom' => 'Header' })

    @client.expects(:make_request).with(:put, '/test', { data: 'value' }, {})
    @client.send(:put_request, '/test', { data: 'value' })

    @client.expects(:make_request).with(:delete, '/test', {}, {})
    @client.send(:delete_request, '/test')
  end
end