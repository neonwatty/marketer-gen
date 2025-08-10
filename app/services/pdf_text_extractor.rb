class PdfTextExtractor
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :brand_asset

  # Error classes for different failure types
  class ExtractionError < StandardError; end
  class UnsupportedFormatError < ExtractionError; end
  class CorruptedFileError < ExtractionError; end
  class FileTooLargeError < ExtractionError; end

  # Maximum file size for text extraction (10MB)
  MAX_FILE_SIZE = 10.megabytes

  # Maximum text length to store (prevent database bloat)
  MAX_TEXT_LENGTH = 50_000

  def initialize(brand_asset)
    @brand_asset = brand_asset
    @errors = []
  end

  # Main extraction method - extracts text and updates the brand asset
  def extract!
    validate_preconditions!

    text = extract_text_from_pdf
    processed_text = process_extracted_text(text)

    @brand_asset.update!(
      extracted_text: processed_text,
      text_extracted_at: Time.current,
      text_extraction_error: nil
    )

    Rails.logger.info "Successfully extracted #{processed_text.length} characters from PDF #{@brand_asset.id}"
    true
  rescue => error
    handle_extraction_error(error)
    false
  end

  # Extract text without updating the model - useful for preview
  def extract_text_only
    validate_preconditions!
    text = extract_text_from_pdf
    process_extracted_text(text)
  end

  # Check if file is extractable
  def extractable?
    return false unless @brand_asset&.file_attached?
    return false unless pdf_file?
    return false if file_too_large?
    true
  end

  def errors
    @errors
  end

  private

  def validate_preconditions!
    raise ArgumentError, "BrandAsset is required" unless @brand_asset
    raise UnsupportedFormatError, "File must be attached" unless @brand_asset.file_attached?
    raise UnsupportedFormatError, "File must be a PDF" unless pdf_file?
    raise FileTooLargeError, "File is too large for text extraction" if file_too_large?
  end

  def extract_text_from_pdf
    pdf_content = ""

    @brand_asset.file.open do |file|
      begin
        reader = PDF::Reader.new(file)

        reader.pages.each_with_index do |page, index|
          # Add page break indicator
          pdf_content += "\n--- Page #{index + 1} ---\n" if index > 0

          page_text = page.text
          next if page_text.blank?

          # Clean and normalize the text
          cleaned_text = clean_page_text(page_text)
          pdf_content += cleaned_text
        end

      rescue PDF::Reader::MalformedPDFError => e
        raise CorruptedFileError, "PDF file appears to be corrupted: #{e.message}"
      rescue PDF::Reader::UnsupportedFeatureError => e
        raise UnsupportedFormatError, "PDF contains unsupported features: #{e.message}"
      rescue => e
        raise ExtractionError, "Failed to read PDF: #{e.message}"
      end
    end

    if pdf_content.blank?
      Rails.logger.warn "No text content found in PDF #{@brand_asset.id}"
      return "No extractable text found in this PDF document."
    end

    pdf_content
  end

  def process_extracted_text(raw_text)
    # Remove excessive whitespace and normalize line breaks
    processed = raw_text.gsub(/\s+/, " ")
                      .gsub(/\n\s*\n/, "\n\n")
                      .strip

    # Truncate if too long
    if processed.length > MAX_TEXT_LENGTH
      processed = processed[0..MAX_TEXT_LENGTH] + "\n\n[Text truncated - original document contains more content]"
    end

    processed
  end

  def clean_page_text(text)
    # Remove extra whitespace and normalize
    cleaned = text.gsub(/\s+/, " ")
                  .gsub(/\u00A0/, " ")  # Replace non-breaking spaces
                  .strip

    # Add proper line breaks for readability
    cleaned += "\n\n"

    cleaned
  end

  def pdf_file?
    return false unless @brand_asset.file_attached?

    @brand_asset.file.blob.content_type == "application/pdf" ||
    @brand_asset.file_extension == "pdf"
  end

  def file_too_large?
    return false unless @brand_asset.file_attached?

    @brand_asset.file.blob.byte_size > MAX_FILE_SIZE
  end

  def handle_extraction_error(error)
    error_message = case error
    when UnsupportedFormatError, CorruptedFileError, FileTooLargeError
                     error.message
    else
                     "Unexpected error during text extraction: #{error.message}"
    end

    @errors << error_message

    # Update brand asset with error information
    @brand_asset.update_columns(
      text_extraction_error: error_message,
      text_extracted_at: Time.current
    )

    Rails.logger.error "PDF text extraction failed for BrandAsset #{@brand_asset.id}: #{error_message}"
    Rails.logger.error error.backtrace.join("\n") if error.respond_to?(:backtrace)
  end
end
