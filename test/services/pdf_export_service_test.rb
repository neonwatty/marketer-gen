require 'test_helper'

class PdfExportServiceTest < ActiveSupport::TestCase
  def setup
    @campaign = campaigns(:one)
    @content_data = {
      campaign: @campaign,
      content_variants: [],
      journeys: [],
      assets: []
    }
  end

  test "should initialize with valid parameters" do
    service = PdfExportService.new(
      content_data: @content_data,
      template_type: :campaign_report,
      brand_settings: { primary_color: '#007bff' },
      options: { include_cover_page: true }
    )
    
    assert_equal @content_data, service.content_data
    assert_equal :campaign_report, service.template_type
    assert_equal '#007bff', service.brand_settings[:primary_color]
    assert service.options[:include_cover_page]
  end

  test "should generate campaign PDF report" do
    result = PdfExportService.generate_campaign_pdf(@campaign)
    
    assert_not_nil result[:data]
    assert_equal 'application/pdf', result[:content_type]
    assert result[:filename].end_with?('.pdf')
    assert result[:filename].include?('campaign-report')
    
    # Check metadata
    metadata = result[:metadata]
    assert_equal :campaign_report, metadata[:template_type]
    assert metadata[:pages] > 0
    assert_not_nil metadata[:generated_at]
  end

  test "should generate content deck PDF" do
    # Create some mock content variants
    content_variants = []
    if defined?(ContentVariant)
      content_variants = [
        OpenStruct.new(
          id: 1,
          name: 'Test Variant 1',
          variant_number: 1,
          strategy_type: 'tone_variation',
          status: 'active',
          content: 'This is test content for variant 1',
          performance_score: 0.75
        ),
        OpenStruct.new(
          id: 2,
          name: 'Test Variant 2',
          variant_number: 2,
          strategy_type: 'cta_variation',
          status: 'testing',
          content: 'This is test content for variant 2',
          performance_score: 0.65
        )
      ]
    end
    
    result = PdfExportService.generate_content_deck(content_variants)
    
    assert_not_nil result[:data]
    assert_equal 'application/pdf', result[:content_type]
    assert result[:filename].include?('content-deck')
    
    # PDF data should be binary
    assert result[:data].bytesize > 0
    assert result[:data].encoding == Encoding::ASCII_8BIT
  end

  test "should generate performance report PDF" do
    performance_data = {
      total_variants: 10,
      avg_performance: 0.67,
      top_performers: [],
      monthly_trends: {}
    }
    
    result = PdfExportService.generate_performance_report(performance_data)
    
    assert_not_nil result[:data]
    assert_equal 'application/pdf', result[:content_type]
    assert result[:filename].include?('performance-summary')
  end

  test "should apply brand settings" do
    brand_settings = {
      primary_color: '#ff6b35',
      secondary_color: '#004e89',
      company_name: 'Test Company',
      logo_text: 'TC'
    }
    
    service = PdfExportService.new(
      content_data: @content_data,
      template_type: :campaign_report,
      brand_settings: brand_settings
    )
    
    result = service.generate
    
    assert_not_nil result[:data]
    assert result[:metadata][:brand_applied]
  end

  test "should handle different template types" do
    template_types = [:standard, :campaign_report, :content_deck, :performance_summary]
    
    template_types.each do |template_type|
      service = PdfExportService.new(
        content_data: @content_data,
        template_type: template_type
      )
      
      result = service.generate
      
      assert_not_nil result[:data], "Should generate PDF for template: #{template_type}"
      assert_equal 'application/pdf', result[:content_type]
      assert_equal template_type, result[:metadata][:template_type]
    end
  end

  test "should generate to file" do
    service = PdfExportService.new(
      content_data: @content_data,
      template_type: :standard
    )
    
    temp_file = Tempfile.new(['test_pdf', '.pdf'])
    
    begin
      filepath = service.generate_to_file(temp_file.path)
      
      assert_equal temp_file.path, filepath
      assert File.exist?(filepath)
      
      # Check file is not empty and appears to be PDF
      file_content = File.binread(filepath)
      assert file_content.bytesize > 0
      assert file_content.start_with?('%PDF'), "Should be a valid PDF file"
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  test "should handle empty content data gracefully" do
    empty_data = {
      campaign: nil,
      content_variants: [],
      journeys: [],
      assets: []
    }
    
    service = PdfExportService.new(
      content_data: empty_data,
      template_type: :standard
    )
    
    result = service.generate
    
    assert_not_nil result[:data]
    assert_equal 'application/pdf', result[:content_type]
    # Should still generate a valid PDF even with empty data
  end

  test "should include proper metadata" do
    options = {
      include_cover_page: true,
      font_size: 12
    }
    
    service = PdfExportService.new(
      content_data: @content_data,
      template_type: :campaign_report,
      options: options
    )
    
    result = service.generate
    metadata = result[:metadata]
    
    assert_not_nil metadata[:generated_at]
    assert_equal :campaign_report, metadata[:template_type]
    assert metadata.key?(:pages)
    assert metadata.key?(:brand_applied)
  end

  test "should generate proper filename" do
    service = PdfExportService.new(
      content_data: @content_data,
      template_type: :content_deck
    )
    
    result = service.generate
    filename = result[:filename]
    
    assert filename.include?('content-deck')
    assert filename.end_with?('.pdf')
    assert filename.match?(/\d{8}_\d{6}/) # Should include timestamp
  end

  test "should handle PDF generation errors gracefully" do
    # Test with invalid template type
    service = PdfExportService.new(
      content_data: @content_data,
      template_type: :invalid_template
    )
    
    # Should fall back to standard template
    result = service.generate
    assert_not_nil result[:data]
    assert_equal 'application/pdf', result[:content_type]
  end

  test "should support custom PDF options" do
    custom_options = {
      pdf_options: {
        page_size: 'LETTER',
        margin: 72
      }
    }
    
    service = PdfExportService.new(
      content_data: @content_data,
      template_type: :standard,
      options: custom_options
    )
    
    result = service.generate
    
    assert_not_nil result[:data]
    assert_equal 'application/pdf', result[:content_type]
  end

  if defined?(BrandIdentity)
    test "should generate brand guidelines PDF" do
      # Create a mock brand identity
      brand_identity = OpenStruct.new(
        id: 1,
        name: 'Test Brand',
        description: 'Test brand description',
        primary_color: '#007bff',
        secondary_color: '#6c757d'
      )
      
      # Mock method to simulate brand assets relationship
      def brand_identity.brand_assets
        []
      end
      
      result = PdfExportService.generate_brand_guidelines(brand_identity)
      
      assert_not_nil result[:data]
      assert_equal 'application/pdf', result[:content_type]
      assert result[:filename].include?('brand-guidelines')
    end
  end

  test "should extract brand settings from campaign" do
    # Create a mock brand identity for the campaign
    if @campaign.respond_to?(:brand_identity=)
      brand_identity = OpenStruct.new(
        primary_color: '#ff6b35',
        name: 'Test Brand'
      )
      
      @campaign.brand_identity = brand_identity
    end
    
    brand_settings = PdfExportService.extract_brand_settings(@campaign)
    
    assert brand_settings.is_a?(Hash)
    # Should have default settings at minimum
    assert brand_settings.key?(:primary_color)
    assert brand_settings.key?(:company_name)
  end

  test "should validate PDF content structure" do
    service = PdfExportService.new(
      content_data: @content_data,
      template_type: :campaign_report
    )
    
    result = service.generate
    pdf_content = result[:data]
    
    # Basic PDF validation
    assert pdf_content.start_with?('%PDF'), "Should start with PDF header"
    assert pdf_content.include?('endobj'), "Should contain PDF objects"
    assert pdf_content.end_with?("%%EOF\n") || pdf_content.end_with?("%%EOF"), "Should end with PDF EOF marker"
  end

  test "should handle large content gracefully" do
    # Create large content data
    large_content_variants = Array.new(50) do |i|
      OpenStruct.new(
        id: i,
        name: "Large Content Variant #{i}",
        variant_number: i,
        strategy_type: 'tone_variation',
        status: 'active',
        content: "This is a very long content string for variant #{i}. " * 10,
        performance_score: rand(0.1..1.0).round(3)
      )
    end
    
    large_data = {
      campaign: @campaign,
      content_variants: large_content_variants,
      journeys: [],
      assets: []
    }
    
    result = PdfExportService.generate_content_deck(large_content_variants)
    
    assert_not_nil result[:data]
    assert result[:data].bytesize > 1000 # Should be substantial size
    assert result[:metadata][:pages] > 1 # Should span multiple pages
  end
end