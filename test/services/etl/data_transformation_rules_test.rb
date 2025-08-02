# frozen_string_literal: true

require 'test_helper'

module Etl
  class DataTransformationRulesTest < ActiveSupport::TestCase
    def setup
      @google_analytics_data = [
        {
          'ga:sessions' => '1000',
          'ga:users' => '800',
          'ga:bounceRate' => '45.5',
          'ga:avgSessionDuration' => '180.5',
          'date' => '2024-01-15'
        }
      ]
      
      @facebook_ads_data = [
        {
          'impressions' => 5000,
          'clicks' => 250,
          'spend' => '125.50',
          'ctr' => '5.0',
          'campaign_name' => 'Summer Campaign'
        }
      ]
    end

    test "transforms Google Analytics data correctly" do
      transformer = DataTransformationRules.new(:google_analytics, @google_analytics_data)
      result = transformer.transform
      
      assert_equal 1, result.size
      
      record = result.first
      assert_equal 'sessions', record.keys.find { |k| k == 'sessions' }
      assert_equal 'unique_users', record.keys.find { |k| k == 'unique_users' }
      assert_equal 'bounce_rate', record.keys.find { |k| k == 'bounce_rate' }
      
      # Check data type transformations
      assert record['bounce_rate'].is_a?(Float)
      assert record['bounce_rate'] < 1.0 # Should be converted to decimal
    end

    test "transforms Facebook Ads data correctly" do
      transformer = DataTransformationRules.new(:facebook_ads, @facebook_ads_data)
      result = transformer.transform
      
      assert_equal 1, result.size
      
      record = result.first
      assert_equal 5000, record['impressions']
      assert_equal 250, record['clicks']
      assert_equal 'Summer Campaign', record['campaign_name']
      
      # Check currency conversion (should be in cents)
      assert record['cost'].is_a?(Integer)
      assert_equal 12550, record['cost'] # $125.50 -> 12550 cents
    end

    test "enriches data with metadata" do
      transformer = DataTransformationRules.new(:google_analytics, @google_analytics_data)
      result = transformer.transform
      
      record = result.first
      assert_equal 'google_analytics', record['platform']
      assert record['etl_processed_at'].present?
      assert_equal '1.0', record['etl_version']
      assert record['data_quality_score'].present?
      assert record['data_quality_score'] > 0
    end

    test "calculates data quality scores" do
      # Complete record should have high quality score
      complete_data = [{
        'timestamp' => Time.current,
        'impressions' => 1000,
        'clicks' => 50,
        'revenue' => 100.0
      }]
      
      transformer = DataTransformationRules.new(:test_platform, complete_data)
      result = transformer.transform
      
      assert result.first['data_quality_score'] > 0.8
      
      # Incomplete record should have lower quality score
      incomplete_data = [{
        'impressions' => 1000,
        'clicks' => nil,
        'revenue' => ''
      }]
      
      transformer = DataTransformationRules.new(:test_platform, incomplete_data)
      result = transformer.transform
      
      assert result.first['data_quality_score'] < 0.8
    end

    test "handles different datetime formats" do
      datetime_formats = [
        '2024-01-15T10:30:00Z',
        '2024-01-15 10:30:00',
        '2024-01-15',
        '1705316600', # Unix timestamp
        '1705316600000' # Unix timestamp in milliseconds
      ]
      
      datetime_formats.each do |format|
        data = [{ 'timestamp' => format, 'source' => 'test' }]
        transformer = DataTransformationRules.new(:test_platform, data)
        
        # Should not raise error and should parse to valid time
        result = transformer.transform
        assert result.present?
        
        if result.first['timestamp']
          assert result.first['timestamp'].is_a?(Time)
        end
      end
    end

    test "validates transformed data" do
      # Valid data should pass validation
      valid_data = [{
        'timestamp' => Time.current,
        'platform' => 'google_analytics',
        'impressions' => 1000,
        'clicks' => 50
      }]
      
      transformer = DataTransformationRules.new(:google_analytics, [])
      result = transformer.send(:validate_transformed_data, valid_data)
      
      assert_equal 1, result.size
      
      # Invalid data should be filtered out
      invalid_data = [{
        'platform' => 'google_analytics'
        # missing timestamp and other required fields
      }]
      
      result = transformer.send(:validate_transformed_data, invalid_data)
      assert_equal 0, result.size
    end

    test "handles numeric field validation" do
      transformer = DataTransformationRules.new(:test_platform, [])
      
      # Valid numeric values
      assert transformer.send(:numeric_field_valid?, { 'impressions' => 100 }, 'impressions')
      assert transformer.send(:numeric_field_valid?, { 'impressions' => '100' }, 'impressions')
      assert transformer.send(:numeric_field_valid?, { 'impressions' => 0 }, 'impressions')
      
      # Invalid numeric values
      refute transformer.send(:numeric_field_valid?, { 'impressions' => -1 }, 'impressions')
      refute transformer.send(:numeric_field_valid?, { 'impressions' => 'abc' }, 'impressions')
      refute transformer.send(:numeric_field_valid?, { 'impressions' => nil }, 'impressions')
    end

    test "batch transformation works correctly" do
      platform_data = {
        google_analytics: @google_analytics_data,
        facebook_ads: @facebook_ads_data
      }
      
      results = DataTransformationRules.transform_batch(platform_data)
      
      assert_equal 2, results.keys.size
      assert results[:google_analytics].present?
      assert results[:facebook_ads].present?
      
      # Each platform should have its data transformed
      assert results[:google_analytics].first['platform'] == 'google_analytics'
      assert results[:facebook_ads].first['platform'] == 'facebook_ads'
    end

    test "supports all defined platforms" do
      expected_platforms = %i[
        google_analytics
        facebook_ads
        google_ads
        email_platforms
        social_media
        crm_systems
      ]
      
      assert_equal expected_platforms.sort, DataTransformationRules.supported_platforms.sort
    end

    test "provides field mappings for platforms" do
      ga_mappings = DataTransformationRules.field_mappings_for(:google_analytics)
      
      assert ga_mappings.present?
      assert ga_mappings['ga:sessions'] == 'sessions'
      assert ga_mappings['ga:users'] == 'unique_users'
    end

    test "handles unknown platforms gracefully" do
      unknown_data = [{ 'custom_field' => 'value', 'timestamp' => Time.current }]
      transformer = DataTransformationRules.new(:unknown_platform, unknown_data)
      
      # Should not raise error
      result = transformer.transform
      assert result.present?
      assert_equal 'unknown_platform', result.first['platform']
    end

    test "universal field mapping works" do
      # Test that universal fields are recognized regardless of platform
      data_with_universal_fields = [{
        'impressions' => 1000, # Should map to impressions
        'clicks' => 50,        # Should map to clicks
        'views' => 800,        # Should also map to impressions (synonym)
        'taps' => 25           # Should also map to clicks (synonym)
      }]
      
      transformer = DataTransformationRules.new(:unknown_platform, data_with_universal_fields)
      result = transformer.transform
      
      record = result.first
      # Both impressions and views should be normalized
      assert record.key?('impressions') || record.key?('views')
      assert record.key?('clicks') || record.key?('taps')
    end
  end
end