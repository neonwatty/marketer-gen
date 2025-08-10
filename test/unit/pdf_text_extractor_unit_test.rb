require "test_helper"

class PdfTextExtractorUnitTest < ActiveSupport::TestCase
  test "extractor should handle nil brand asset" do
    extractor = PdfTextExtractor.new(nil)

    refute extractor.extractable?, "Should not be extractable with nil brand asset"
    assert_equal [], extractor.errors
  end

  test "extractor should identify valid configuration" do
    assert defined?(PdfTextExtractor::MAX_FILE_SIZE), "Should have size limit constant"
    assert defined?(PdfTextExtractor::MAX_TEXT_LENGTH), "Should have text length constant"

    assert_equal 10.megabytes, PdfTextExtractor::MAX_FILE_SIZE
    assert_equal 50_000, PdfTextExtractor::MAX_TEXT_LENGTH
  end

  test "extractor error classes should be defined" do
    assert defined?(PdfTextExtractor::ExtractionError)
    assert defined?(PdfTextExtractor::UnsupportedFormatError)
    assert defined?(PdfTextExtractor::CorruptedFileError)
    assert defined?(PdfTextExtractor::FileTooLargeError)
  end

  test "extractor should have correct inheritance" do
    assert PdfTextExtractor::UnsupportedFormatError < PdfTextExtractor::ExtractionError
    assert PdfTextExtractor::CorruptedFileError < PdfTextExtractor::ExtractionError
    assert PdfTextExtractor::FileTooLargeError < PdfTextExtractor::ExtractionError
  end

  test "extractor should include ActiveModel functionality" do
    extractor = PdfTextExtractor.new(nil)

    assert_respond_to extractor, :errors
    assert_respond_to extractor, :extractable?
  end
end
