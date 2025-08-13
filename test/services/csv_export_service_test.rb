require 'test_helper'

class CsvExportServiceTest < ActiveSupport::TestCase
  def setup
    @campaign = campaigns(:one)
    @content_variant = content_variants(:one) if defined?(ContentVariant)
  end

  test "should initialize with valid parameters" do
    service = CsvExportService.new(
      model_class: Campaign,
      filters: { status: 'active' },
      columns: %w[id name status],
      options: { limit: 10 }
    )
    
    assert_equal Campaign, service.model_class
    assert_equal({ status: 'active' }, service.filters)
    assert_equal(%w[id name status], service.columns)
    assert_equal({ limit: 10 }, service.options)
  end

  test "should export campaigns to CSV format" do
    result = CsvExportService.export_campaigns(
      filters: {},
      options: { limit: 5 }
    )
    
    assert_not_nil result[:data]
    assert_equal 'text/csv', result[:content_type]
    assert result[:filename].end_with?('.csv')
    assert result[:metadata][:total_records] >= 0
    
    # Check CSV structure
    csv_lines = result[:data].split("\n")
    assert csv_lines.length > 0, "CSV should have header line"
    
    # Verify headers are present
    headers = csv_lines.first.split(',')
    assert headers.include?('Id'), "Should include ID column"
    assert headers.include?('Name'), "Should include Name column"
    assert headers.include?('Status'), "Should include Status column"
  end

  test "should handle empty result set" do
    result = CsvExportService.export_campaigns(
      filters: { status: 'nonexistent_status' },
      options: {}
    )
    
    assert_not_nil result[:data]
    assert_equal 'text/csv', result[:content_type]
    assert_equal 0, result[:metadata][:total_records]
    
    # Should still have headers
    csv_lines = result[:data].split("\n")
    assert csv_lines.length >= 1, "Should have at least header line"
  end

  test "should apply filters correctly" do
    # Create test data with specific status
    active_campaign = Campaign.create!(
      name: 'Test Active Campaign',
      purpose: 'Test purpose',
      status: 'active',
      start_date: Date.current,
      end_date: Date.current + 30.days
    )
    
    result = CsvExportService.export_campaigns(
      filters: { status: 'active' },
      options: {}
    )
    
    csv_data = result[:data]
    assert csv_data.include?(active_campaign.name), "Should include active campaign"
    
    # Test with different filter
    result_draft = CsvExportService.export_campaigns(
      filters: { status: 'draft' },
      options: {}
    )
    
    csv_data_draft = result_draft[:data]
    assert_not csv_data_draft.include?(active_campaign.name), "Should not include active campaign in draft filter"
  ensure
    active_campaign&.destroy
  end

  test "should support custom columns" do
    custom_columns = %w[id name status created_at]
    
    result = CsvExportService.export_campaigns(
      columns: custom_columns,
      options: { limit: 1 }
    )
    
    csv_lines = result[:data].split("\n")
    headers = csv_lines.first.split(',')
    
    # Check that headers match custom columns (humanized)
    assert headers.include?('Id')
    assert headers.include?('Name') 
    assert headers.include?('Status')
    assert headers.include?('Created at')
  end

  test "should generate proper filename" do
    service = CsvExportService.new(
      model_class: Campaign,
      filters: {},
      options: {}
    )
    
    result = service.export
    filename = result[:filename]
    
    assert filename.include?('campaigns_export_')
    assert filename.end_with?('.csv')
    assert filename.match?(/\d{8}_\d{6}/) # Should include timestamp
  end

  test "should export to file" do
    service = CsvExportService.new(
      model_class: Campaign,
      filters: {},
      options: { limit: 1 }
    )
    
    temp_file = Tempfile.new(['test_export', '.csv'])
    
    begin
      filepath = service.export_to_file(temp_file.path)
      
      assert_equal temp_file.path, filepath
      assert File.exist?(filepath)
      
      content = File.read(filepath)
      assert content.length > 0
      assert content.include?('Id') # Should have headers
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  test "should handle search filters" do
    # Create test campaign with searchable name
    test_campaign = Campaign.create!(
      name: 'Unique Searchable Campaign Name',
      purpose: 'Test purpose for search',
      status: 'draft',
      start_date: Date.current,
      end_date: Date.current + 30.days
    )
    
    result = CsvExportService.export_campaigns(
      filters: { search: 'Unique Searchable' },
      options: {}
    )
    
    csv_data = result[:data]
    assert csv_data.include?(test_campaign.name), "Should find campaign by search term"
    
    # Test search that should return no results
    result_empty = CsvExportService.export_campaigns(
      filters: { search: 'NonexistentSearchTerm' },
      options: {}
    )
    
    assert_equal 0, result_empty[:metadata][:total_records]
  ensure
    test_campaign&.destroy
  end

  test "should include metadata in export result" do
    result = CsvExportService.export_campaigns(
      filters: { status: 'draft' },
      options: { limit: 5 }
    )
    
    metadata = result[:metadata]
    
    assert_not_nil metadata
    assert metadata.key?(:total_records)
    assert metadata.key?(:exported_at)
    assert metadata.key?(:filters_applied)
    assert metadata.key?(:columns_included)
    
    assert metadata[:filters_applied][:status] == 'draft'
    assert metadata[:columns_included].is_a?(Array)
  end

  test "should handle date range filters" do
    # Create campaigns with different dates
    old_campaign = Campaign.create!(
      name: 'Old Campaign',
      purpose: 'Old test',
      status: 'completed',
      start_date: 2.months.ago,
      end_date: 1.month.ago,
      created_at: 2.months.ago
    )
    
    recent_campaign = Campaign.create!(
      name: 'Recent Campaign', 
      purpose: 'Recent test',
      status: 'active',
      start_date: 1.week.ago,
      end_date: 1.month.from_now,
      created_at: 1.week.ago
    )
    
    # Test date range filter
    date_range = {
      start: 2.weeks.ago,
      end: Date.current
    }
    
    result = CsvExportService.export_campaigns(
      filters: { date_range: date_range },
      options: {}
    )
    
    csv_data = result[:data]
    assert csv_data.include?(recent_campaign.name), "Should include recent campaign"
    assert_not csv_data.include?(old_campaign.name), "Should not include old campaign"
  ensure
    old_campaign&.destroy
    recent_campaign&.destroy
  end

  if defined?(ContentVariant)
    test "should export content variants with performance data" do
      result = CsvExportService.export_content_variants(
        filters: {},
        options: { limit: 5 }
      )
      
      assert_not_nil result[:data]
      assert_equal 'text/csv', result[:content_type]
      
      csv_lines = result[:data].split("\n")
      headers = csv_lines.first.split(',')
      
      # Check for content variant specific headers
      assert headers.any? { |h| h.include?('Variant') }
      assert headers.any? { |h| h.include?('Strategy') || h.include?('Performance') }
    end
  end

  test "should handle large datasets with batching" do
    # Create multiple campaigns
    campaigns = []
    5.times do |i|
      campaigns << Campaign.create!(
        name: "Batch Test Campaign #{i}",
        purpose: "Test purpose #{i}",
        status: 'draft',
        start_date: Date.current,
        end_date: Date.current + 30.days
      )
    end
    
    begin
      result = CsvExportService.export_campaigns(
        filters: {},
        options: { batch_size: 2 } # Small batch size for testing
      )
      
      assert_not_nil result[:data]
      assert result[:metadata][:total_records] >= 5
      
      # Should include all created campaigns
      csv_data = result[:data]
      campaigns.each do |campaign|
        assert csv_data.include?(campaign.name), "Should include campaign #{campaign.name}"
      end
    ensure
      campaigns.each(&:destroy)
    end
  end

  test "should validate required parameters" do
    assert_raises ArgumentError do
      CsvExportService.new(model_class: nil)
    end
  end

  test "should handle special characters in content" do
    campaign_with_special_chars = Campaign.create!(
      name: 'Campaign with "quotes" and, commas',
      purpose: 'Purpose with special chars: àáâãäå',
      status: 'draft',
      start_date: Date.current,
      end_date: Date.current + 30.days
    )
    
    begin
      result = CsvExportService.export_campaigns(
        filters: { ids: [campaign_with_special_chars.id] },
        options: {}
      )
      
      csv_data = result[:data]
      
      # CSV should properly escape special characters
      assert csv_data.include?(campaign_with_special_chars.name)
      
      # Should be parseable as CSV
      require 'csv'
      parsed_csv = CSV.parse(csv_data, headers: true)
      assert parsed_csv.length > 0
      
      # Find our test campaign in the parsed data
      test_row = parsed_csv.find { |row| row['Name'] == campaign_with_special_chars.name }
      assert_not_nil test_row, "Should find campaign with special characters"
    ensure
      campaign_with_special_chars&.destroy
    end
  end
end