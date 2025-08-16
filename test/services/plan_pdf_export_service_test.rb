require "test_helper"

class PlanPdfExportServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @campaign_plan = campaign_plans(:completed_plan)
  end

  test "should generate PDF for completed plan" do
    service = PlanPdfExportService.new(@campaign_plan)
    result = service.generate_pdf

    assert result[:success]
    assert result[:pdf].present?
    assert_instance_of Prawn::Document, result[:pdf]
  end

  test "should not generate PDF for incomplete plan" do
    @campaign_plan.update!(status: 'draft')
    service = PlanPdfExportService.new(@campaign_plan)
    result = service.generate_pdf

    assert_not result[:success]
    assert_equal 'Plan not completed', result[:message]
  end

  test "should include plan name in PDF" do
    service = PlanPdfExportService.new(@campaign_plan)
    result = service.generate_pdf

    assert result[:success]
    
    # Try to verify PDF content if PDF::Reader is available
    begin
      require 'pdf-reader'
      pdf_content = PDF::Reader.new(StringIO.new(result[:pdf].render)).pages.first.text
      assert_includes pdf_content, @campaign_plan.name
    rescue LoadError, NameError
      skip "PDF::Reader not available for content verification"
    end
  end
end