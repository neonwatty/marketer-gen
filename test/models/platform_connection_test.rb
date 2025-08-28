# frozen_string_literal: true

require 'test_helper'

class PlatformConnectionTest < ActiveSupport::TestCase
  def setup
    @user = users(:three) # Use a different user to avoid fixture conflicts
    
    @valid_meta_credentials = {
      access_token: 'test_access_token',
      app_secret: 'test_app_secret'
    }
    @valid_google_ads_credentials = {
      access_token: 'test_access_token',
      developer_token: 'test_developer_token',
      customer_id: '123456789',
      refresh_token: 'test_refresh_token'
    }
    @valid_linkedin_credentials = {
      access_token: 'test_access_token'
    }
  end

  test "should create valid platform connection" do
    
    connection = PlatformConnection.new(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active'
    )
    
    assert connection.valid?
    assert connection.save
  end

  test "should validate platform inclusion" do
    connection = PlatformConnection.new(
      user: @user,
      platform: 'invalid_platform',
      credentials: @valid_meta_credentials.to_json
    )
    
    assert_not connection.valid?
    assert_includes connection.errors[:platform], "is not included in the list"
  end

  test "should validate status inclusion" do
    connection = PlatformConnection.new(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'invalid_status'
    )
    
    assert_not connection.valid?
    assert_includes connection.errors[:status], "is not included in the list"
  end

  test "should validate unique platform per user" do
    
    PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active'
    )
    
    duplicate = PlatformConnection.new(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active'
    )
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:platform], "has already been taken"
  end

  test "should allow same platform for different users" do
    other_user = users(:two)
    
    
    PlatformConnection.create!(
      user: @user,
      platform: 'google_ads',
      credentials: @valid_google_ads_credentials.to_json,
      status: 'active'
    )
    
    connection = PlatformConnection.new(
      user: other_user,
      platform: 'google_ads',
      credentials: @valid_google_ads_credentials.to_json,
      status: 'active'
    )
    
    assert connection.valid?
  end

  test "should store and retrieve credentials correctly" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active'
    )
    
    # Should be able to retrieve credentials correctly
    assert_equal @valid_meta_credentials.stringify_keys, connection.credential_data
  end

  test "active? should return true for active connection with valid credentials" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active'
    )
    
    assert connection.active?
  end

  test "active? should return false for inactive connection" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'inactive'
    )
    
    assert_not connection.active?
  end

  test "active? should return false for connection with invalid credentials" do
    
    invalid_credentials = { access_token: 'token' } # Missing app_secret for meta
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: invalid_credentials.to_json,
      status: 'active'
    )
    
    assert_not connection.active?
  end

  test "expired? should return true for expired status" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'expired'
    )
    
    assert connection.expired?
  end

  test "expired? should return true for token expiration" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active',
      metadata: { token_expires_at: 1.day.ago.iso8601 }
    )
    
    assert connection.expired?
  end

  test "error? should return true for error status" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'error'
    )
    
    assert connection.error?
  end

  test "credential_data should return parsed JSON" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active'
    )
    
    assert_equal @valid_meta_credentials.stringify_keys, connection.credential_data
  end

  test "credential_data should handle invalid JSON gracefully" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active'
    )
    
    # Simulate corrupted credentials
    connection.update_column(:credentials, 'invalid json')
    
    assert_equal({}, connection.credential_data)
  end

  test "update_credentials should update credentials and set status to active" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: '{}',
      status: 'inactive'
    )
    
    connection.update_credentials(@valid_meta_credentials)
    
    assert_equal 'active', connection.status
    assert_equal @valid_meta_credentials.stringify_keys, connection.credential_data
  end

  test "mark_failed! should set error status and metadata" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active'
    )
    
    error_message = 'Authentication failed'
    connection.mark_failed!(error_message)
    
    assert_equal 'error', connection.status
    assert_equal error_message, connection.metadata['last_error']
    assert connection.metadata['error_at']
  end

  test "mark_expired! should set expired status and metadata" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active'
    )
    
    connection.mark_expired!
    
    assert_equal 'expired', connection.status
    assert connection.metadata['expired_at']
  end

  test "update_sync_status! should update sync metadata on success" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active'
    )
    
    sync_data = { campaigns: 5, spend: 1000 }
    connection.update_sync_status!(true, sync_data)
    
    assert connection.last_sync_at
    assert connection.metadata['last_successful_sync']
    assert_equal 1, connection.metadata['sync_count']
    assert_equal sync_data.stringify_keys, connection.metadata['sync_data']
  end

  test "update_sync_status! should update failure metadata on failure" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active'
    )
    
    connection.update_sync_status!(false)
    
    assert connection.last_sync_at
    assert connection.metadata['last_failed_sync']
    assert_equal 1, connection.metadata['failure_count']
  end

  test "account_info should return formatted account information" do
    
    connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active',
      account_id: 'act_123',
      account_name: 'Test Account'
    )
    
    info = connection.account_info
    
    assert_equal 'act_123', info[:id]
    assert_equal 'Test Account', info[:name]
    assert_equal 'meta', info[:platform]
    assert_equal 'active', info[:status]
  end

  test "required_credential_fields should return correct fields for each platform" do
    meta_connection = PlatformConnection.new(platform: 'meta')
    assert_equal %w[access_token app_secret], meta_connection.required_credential_fields
    
    google_ads_connection = PlatformConnection.new(platform: 'google_ads')
    assert_equal %w[access_token developer_token customer_id refresh_token], google_ads_connection.required_credential_fields
    
    linkedin_connection = PlatformConnection.new(platform: 'linkedin')
    assert_equal %w[access_token], linkedin_connection.required_credential_fields
  end

  test "credentials_valid? should validate required fields for meta" do
    connection = PlatformConnection.new(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active'
    )
    
    assert connection.send(:credentials_valid?)
    
    # Missing app_secret
    invalid_credentials = { access_token: 'token' }
    connection.credentials = invalid_credentials.to_json
    
    assert_not connection.send(:credentials_valid?)
  end

  test "credentials_valid? should validate required fields for google_ads" do
    connection = PlatformConnection.new(
      user: @user,
      platform: 'google_ads',
      credentials: @valid_google_ads_credentials.to_json,
      status: 'active'
    )
    
    assert connection.send(:credentials_valid?)
    
    # Missing developer_token
    invalid_credentials = @valid_google_ads_credentials.dup
    invalid_credentials.delete(:developer_token)
    connection.credentials = invalid_credentials.to_json
    
    assert_not connection.send(:credentials_valid?)
  end

  test "credentials_valid? should validate required fields for linkedin" do
    connection = PlatformConnection.new(
      user: @user,
      platform: 'linkedin',
      credentials: @valid_linkedin_credentials.to_json,
      status: 'active'
    )
    
    assert connection.send(:credentials_valid?)
    
    # Missing access_token
    connection.credentials = {}.to_json
    
    assert_not connection.send(:credentials_valid?)
  end

  test "scopes should work correctly" do
    
    active_connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: @valid_meta_credentials.to_json,
      status: 'active'
    )
    
    inactive_connection = PlatformConnection.create!(
      user: @user,
      platform: 'linkedin',
      credentials: @valid_linkedin_credentials.to_json,
      status: 'inactive'
    )
    
    recently_synced_connection = PlatformConnection.create!(
      user: users(:one),
      platform: 'linkedin',
      credentials: @valid_linkedin_credentials.to_json,
      status: 'active',
      last_sync_at: 1.hour.ago
    )
    
    old_sync_connection = PlatformConnection.create!(
      user: users(:three),
      platform: 'google_ads',
      credentials: @valid_google_ads_credentials.to_json,
      status: 'active',
      last_sync_at: 2.days.ago
    )
    
    assert_includes PlatformConnection.active, active_connection
    assert_not_includes PlatformConnection.active, inactive_connection
    
    assert_includes PlatformConnection.for_platform('meta'), active_connection
    assert_not_includes PlatformConnection.for_platform('meta'), inactive_connection
    
    assert_includes PlatformConnection.recently_synced, recently_synced_connection
    assert_not_includes PlatformConnection.recently_synced, old_sync_connection
  end
end
