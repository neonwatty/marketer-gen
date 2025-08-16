require "test_helper"

class BrandMaterialsProcessorTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @brand_identity = brand_identities(:valid_brand)
    @processor = BrandMaterialsProcessor.new(@brand_identity)
  end

  test "initializes with brand identity" do
    assert_equal @brand_identity, @processor.brand_identity
    assert_empty @processor.processed_files
  end

  test "process_all_materials returns expected structure" do
    result = @processor.process_all_materials
    
    assert result.is_a?(Hash)
    assert_includes result.keys, :extracted_data
    assert_includes result.keys, :files_processed
    assert_includes result.keys, :processing_notes
    assert_includes result.keys, :processed_at
    
    assert result[:extracted_data].is_a?(Hash)
    assert_includes result[:extracted_data].keys, :voice
    assert_includes result[:extracted_data].keys, :tone
    assert_includes result[:extracted_data].keys, :messaging
    assert_includes result[:extracted_data].keys, :restrictions
    
    assert result[:files_processed].is_a?(Hash)
    assert_includes result[:files_processed].keys, :count
    assert_includes result[:files_processed].keys, :details
    
    assert result[:processing_notes].is_a?(Array)
    assert result[:processed_at].present?
  end

  test "process_all_materials handles brand identity without attachments" do
    result = @processor.process_all_materials
    
    assert_equal 0, result[:files_processed][:count]
    assert_empty result[:files_processed][:details]
    assert_includes result[:processing_notes].first, "Consolidated guidelines extracted from 0 files"
  end

  test "process_all_materials processes attachments when present" do
    # Create a temporary file to simulate attachment
    file_content = "Brand guidelines: Be professional and friendly"
    
    # Mock the attachment behavior
    attachment = mock('attachment')
    attachment.stubs(:filename).returns(ActiveStorage::Filename.new("guidelines.txt"))
    attachment.stubs(:content_type).returns("text/plain")
    attachment.stubs(:byte_size).returns(file_content.bytesize)
    attachment.stubs(:download).returns(file_content)
    
    # Mock the brand_materials association
    @brand_identity.stubs(:brand_materials).returns(mock('collection'))
    @brand_identity.brand_materials.stubs(:attached?).returns(true)
    @brand_identity.brand_materials.stubs(:each).yields(attachment)
    
    # Mock logo_files and style_guides as not attached
    @brand_identity.stubs(:logo_files).returns(mock('collection'))
    @brand_identity.logo_files.stubs(:attached?).returns(false)
    @brand_identity.stubs(:style_guides).returns(mock('collection'))
    @brand_identity.style_guides.stubs(:attached?).returns(false)
    
    result = @processor.process_all_materials
    
    assert_equal 1, result[:files_processed][:count]
    assert_equal 1, result[:files_processed][:details].length
    
    file_detail = result[:files_processed][:details].first
    assert_equal "guidelines.txt", file_detail[:filename]
    assert_equal "text/plain", file_detail[:content_type]
    assert_equal file_content, file_detail[:processed_content]
  end

  test "extract_brand_voice returns placeholder content" do
    voice = @processor.send(:extract_brand_voice, "Some content")
    assert_includes voice, "Brand voice extracted"
    assert_includes voice, "placeholder"
  end

  test "extract_tone_guidelines returns placeholder content" do
    tone = @processor.send(:extract_tone_guidelines, "Some content")
    assert_includes tone, "Tone guidelines extracted"
    assert_includes tone, "placeholder"
  end

  test "extract_messaging_framework returns placeholder content" do
    messaging = @processor.send(:extract_messaging_framework, "Some content")
    assert_includes messaging, "Messaging framework extracted"
    assert_includes messaging, "placeholder"
  end

  test "extract_restrictions returns placeholder content" do
    restrictions = @processor.send(:extract_restrictions, "Some content")
    assert_includes restrictions, "Brand restrictions and rules extracted"
    assert_includes restrictions, "placeholder"
  end

  test "process_text_file returns file content" do
    content = "This is text file content"
    attachment = mock('attachment')
    attachment.stubs(:download).returns(content)
    
    result = @processor.send(:process_text_file, attachment)
    assert_equal content, result
  end

  test "process_pdf_file returns placeholder" do
    attachment = mock('attachment')
    result = @processor.send(:process_pdf_file, attachment)
    assert_includes result, "PDF content extracted"
    assert_includes result, "placeholder"
  end

  test "process_word_file returns placeholder" do
    attachment = mock('attachment')
    result = @processor.send(:process_word_file, attachment)
    assert_includes result, "Word document content extracted"
    assert_includes result, "placeholder"
  end

  test "process_image_file returns placeholder" do
    attachment = mock('attachment')
    result = @processor.send(:process_image_file, attachment)
    assert_includes result, "Image processed for visual brand elements"
  end

  test "process_single_file handles different content types" do
    text_attachment = mock('text_attachment')
    text_attachment.stubs(:content_type).returns("text/plain")
    text_attachment.stubs(:download).returns("text content")
    
    pdf_attachment = mock('pdf_attachment')
    pdf_attachment.stubs(:content_type).returns("application/pdf")
    
    image_attachment = mock('image_attachment')
    image_attachment.stubs(:content_type).returns("image/jpeg")
    
    word_attachment = mock('word_attachment')
    word_attachment.stubs(:content_type).returns("application/vnd.openxmlformats-officedocument.wordprocessingml.document")
    
    unsupported_attachment = mock('unsupported_attachment')
    unsupported_attachment.stubs(:content_type).returns("application/unknown")
    
    assert_equal "text content", @processor.send(:process_single_file, text_attachment)
    assert_includes @processor.send(:process_single_file, pdf_attachment), "PDF content extracted"
    assert_includes @processor.send(:process_single_file, image_attachment), "Image processed"
    assert_includes @processor.send(:process_single_file, word_attachment), "Word document content extracted"
    assert_includes @processor.send(:process_single_file, unsupported_attachment), "Unsupported file type"
  end

  test "process_single_file handles errors gracefully" do
    attachment = mock('attachment')
    attachment.stubs(:content_type).returns("text/plain")
    attachment.stubs(:download).raises(StandardError.new("Test error"))
    attachment.stubs(:filename).returns(ActiveStorage::Filename.new("test.txt"))
    
    result = @processor.send(:process_single_file, attachment)
    assert_includes result, "Error processing file"
  end
end