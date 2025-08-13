require 'test_helper'

class ExportsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @campaign = campaigns(:summer_launch)
  end

  test "should get index" do
    get exports_url
    assert_response :success
    
    assert_select 'body', /available_formats/
    # Should show available export options
  end

  test "should create CSV export" do
    post exports_url, params: {
      export_type: 'standard',
      data_scope: 'campaigns', 
      formats: ['csv'],
      status: 'active'
    }
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['metadata']
    assert response_data['download_urls']
    assert response_data['download_urls']['csv']
  end

  test "should create multi-format export" do
    post exports_url, params: {
      export_type: 'comprehensive_report',
      data_scope: 'campaigns',
      formats: ['csv', 'pdf'],
      limit: 10
    }
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['summary']
    assert response_data['download_urls']['csv']
    assert response_data['download_urls']['pdf']
  end

  test "should export specific campaign" do
    get export_campaign_url(@campaign), params: {
      formats: ['csv']
    }
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal @campaign.name, response_data['campaign']
    assert response_data['exports']
  end

  test "should download campaign CSV immediately" do
    get export_campaign_url(@campaign), params: {
      formats: ['csv'],
      download_immediately: true
    }
    
    assert_response :success
    assert_equal 'text/csv', response.content_type
    assert response.headers['Content-Disposition'].include?('attachment')
    
    # Should be valid CSV
    csv_data = response.body
    assert csv_data.include?('Id'), "Should include CSV headers"
  end

  test "should create comprehensive export" do
    post comprehensive_exports_url, params: {
      formats: ['csv'],
      date_range: 'last_30_days',
      status: 'active'
    }
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['message'].include?('Comprehensive export')
  end

  test "should create performance export" do
    post performance_exports_url, params: {
      formats: ['csv', 'pdf'],
      date_range: {
        start: 30.days.ago.to_date,
        end: Date.current
      }
    }
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['message'].include?('Performance analysis')
  end

  test "should create calendar export" do
    post calendar_exports_url, params: {
      campaign_ids: [@campaign.id],
      formats: ['calendar']
    }
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['message'].include?('Calendar export')
  end

  test "should download calendar immediately" do
    post calendar_exports_url, params: {
      campaign_ids: [@campaign.id],
      formats: ['calendar'],
      download_immediately: true
    }
    
    assert_response :success
    assert_equal 'text/calendar', response.content_type
    
    # Should be valid ICS
    ics_data = response.body
    assert ics_data.include?('BEGIN:VCALENDAR'), "Should be valid ICS format"
  end

  test "should handle bulk export" do
    post bulk_exports_url, params: {
      campaign_ids: [@campaign.id],
      formats: ['csv']
    }
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['message'].include?('Bulk export completed')
    assert response_data['results']
  end

  test "should fail bulk export without campaign IDs" do
    post bulk_exports_url, params: {
      formats: ['csv']
    }
    
    assert_response :bad_request
    
    response_data = JSON.parse(response.body)
    assert_not response_data['success']
    assert response_data['error'].include?('No campaign IDs provided')
  end

  test "should get available templates" do
    get templates_exports_url
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['available_templates']
    assert response_data['supported_formats']
    assert response_data['supported_scopes']
  end

  test "should get templates for specific format" do
    get templates_exports_url, params: { format_type: 'csv' }
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['available_templates']
    # Should return CSV-specific templates
  end

  test "should preview export" do
    get preview_exports_url, params: {
      export_type: 'standard',
      data_scope: 'campaigns',
      format: 'csv',
      limit: 5
    }
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['preview']
    assert response_data['estimated_size']
  end

  test "should handle invalid export parameters" do
    post exports_url, params: {
      export_type: 'invalid_type',
      data_scope: 'invalid_scope',
      formats: ['invalid_format']
    }
    
    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_not response_data['success']
    assert response_data['error']
  end

  test "should handle campaign not found" do
    get export_campaign_url(999999), params: {
      formats: ['csv']
    }
    
    assert_response :not_found
  end

  test "should apply filters correctly" do
    post exports_url, params: {
      export_type: 'standard',
      data_scope: 'campaigns',
      formats: ['csv'],
      status: 'active',
      search: 'test',
      limit: 10,
      order_by: 'created_at',
      order_direction: 'desc'
    }
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    
    # Check that filters were applied in metadata
    metadata = response_data['metadata']
    assert_equal 'active', metadata['filters_applied']['status']
  end

  test "should handle date range filters" do
    post exports_url, params: {
      export_type: 'standard',
      data_scope: 'campaigns',
      formats: ['csv'],
      date_range: 'last_30_days'
    }
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
  end

  test "should handle custom date range" do
    start_date = 30.days.ago.to_date
    end_date = Date.current
    
    post exports_url, params: {
      export_type: 'standard',
      data_scope: 'campaigns',
      formats: ['csv'],
      date_range: {
        start: start_date,
        end: end_date
      }
    }
    
    assert_response :success
  end

  test "should download campaign PDF" do
    get export_download_with_id_url(
      type: 'campaign',
      format: 'pdf',
      id: @campaign.id
    )
    
    assert_response :success
    assert_equal 'application/pdf', response.content_type
    assert response.headers['Content-Disposition'].include?('attachment')
    
    # Should be valid PDF
    pdf_data = response.body
    assert pdf_data.start_with?('%PDF'), "Should be valid PDF format"
  end

  test "should download comprehensive CSV" do
    get export_download_url(
      type: 'comprehensive',
      format: 'csv'
    ), params: {
      status: 'active',
      limit: 10
    }
    
    assert_response :success
    assert_equal 'text/csv', response.content_type
  end

  test "should download performance PDF" do
    get export_download_url(
      type: 'performance',
      format: 'pdf'
    ), params: {
      date_range: 'last_30_days'
    }
    
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end

  test "should handle download errors gracefully" do
    get export_download_url(
      type: 'invalid_type',
      format: 'csv'
    )
    
    assert_response :not_found
    
    response_data = JSON.parse(response.body)
    assert response_data['error']
  end

  test "should handle unsupported format" do
    get export_download_with_id_url(
      type: 'campaign',
      format: 'unsupported',
      id: @campaign.id
    )
    
    assert_response :bad_request
    
    response_data = JSON.parse(response.body)
    assert response_data['error'].include?('Unsupported format')
  end

  if defined?(BrandIdentity)
    test "should export brand package" do
      # Create a mock brand identity
      brand_identity = BrandIdentity.create!(
        name: 'Test Brand',
        description: 'Test brand for exports'
      )
      
      begin
        get export_brand_url(brand_identity), params: {
          formats: ['csv', 'pdf']
        }
        
        assert_response :success
        
        response_data = JSON.parse(response.body)
        assert response_data['success']
        assert_equal brand_identity.name, response_data['brand']
      ensure
        brand_identity.destroy if brand_identity.persisted?
      end
    end
  end

  test "should handle timezone parameter" do
    post calendar_exports_url, params: {
      campaign_ids: [@campaign.id],
      formats: ['calendar'],
      timezone: 'America/New_York'
    }
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
  end

  test "should validate required parameters" do
    # Test missing formats
    post exports_url, params: {
      export_type: 'standard',
      data_scope: 'campaigns'
      # Missing formats parameter
    }
    
    assert_response :success # Should default to CSV
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
  end

  test "should handle large dataset exports" do
    # Create multiple campaigns for testing
    campaigns = []
    5.times do |i|
      campaigns << Campaign.create!(
        name: "Large Dataset Test Campaign #{i}",
        purpose: "Test purpose #{i}",
        status: 'active',
        start_date: Date.current,
        end_date: Date.current + 30.days
      )
    end
    
    begin
      post exports_url, params: {
        export_type: 'standard',
        data_scope: 'campaigns',
        formats: ['csv'],
        status: 'active'
      }
      
      assert_response :success
      
      response_data = JSON.parse(response.body)
      assert response_data['success']
      assert response_data['metadata']['total_records'] >= 5
    ensure
      campaigns.each(&:destroy)
    end
  end

  test "should respect rate limiting" do
    # Test multiple rapid requests
    5.times do
      post exports_url, params: {
        export_type: 'standard',
        data_scope: 'campaigns',
        formats: ['csv'],
        limit: 1
      }
      
      # All should succeed for small exports
      assert_response :success
    end
  end

  test "should include proper headers in download response" do
    get export_campaign_url(@campaign), params: {
      formats: ['csv'],
      download_immediately: true
    }
    
    assert_response :success
    
    # Check headers
    assert response.headers['Content-Disposition'].include?('attachment')
    assert response.headers['Content-Disposition'].include?('.csv')
    assert_equal 'text/csv', response.content_type
  end

  test "should handle concurrent export requests" do
    # Simulate concurrent requests
    threads = []
    results = []
    
    3.times do |i|
      threads << Thread.new do
        post exports_url, params: {
          export_type: 'standard',
          data_scope: 'campaigns',
          formats: ['csv'],
          limit: 1
        }
        
        results << {
          status: response.status,
          success: JSON.parse(response.body)['success']
        }
      end
    end
    
    threads.each(&:join)
    
    # All requests should succeed
    results.each do |result|
      assert_equal 200, result[:status]
      assert result[:success]
    end
  end
end