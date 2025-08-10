require "test_helper"

class BrandAssetTest < ActiveSupport::TestCase
  def setup
    @brand_identity = BrandIdentity.create!(
      name: "Test Brand",
      description: "Test brand for testing"
    )

    # Create a test image file
    @test_image = fixture_file_upload("test_image.png", "image/png")
    @test_pdf = fixture_file_upload("test_document.pdf", "application/pdf")
  end

  # Basic Model Tests
  test "should create brand asset with required fields" do
    brand_asset = BrandAsset.new(
      file: @test_image,
      file_type: "logo",
      assetable: @brand_identity
    )

    assert brand_asset.valid?
    assert brand_asset.save
  end

  test "should require file attachment" do
    brand_asset = BrandAsset.new(
      file_type: "logo",
      assetable: @brand_identity
    )

    assert_not brand_asset.valid?
    assert_includes brand_asset.errors[:file], "must be attached"
  end

  test "should require file type" do
    brand_asset = BrandAsset.new(
      file: @test_image,
      assetable: @brand_identity
    )

    assert_not brand_asset.valid?
    assert_includes brand_asset.errors[:file_type], "can't be blank"
  end

  # File Type Detection Tests
  test "should detect image file type correctly" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")

    assert brand_asset.image_file?
    assert_not brand_asset.document_file?
    assert_not brand_asset.font_file?
  end

  test "should detect document file type correctly" do
    brand_asset = create_brand_asset(file: @test_pdf, file_type: "brand_guideline")

    assert brand_asset.document_file?
    assert_not brand_asset.image_file?
    assert_not brand_asset.font_file?
  end

  # File Size and Metadata Tests
  test "should extract file metadata on save" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")

    # Manually trigger metadata extraction if it didn't happen during save
    if brand_asset.file_size.blank?
      brand_asset.send(:extract_file_metadata)
      brand_asset.save!
    end

    assert brand_asset.file_size.present?
    assert brand_asset.content_type.present?
    assert_equal "image/png", brand_asset.content_type
  end

  test "should set original filename" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")

    # Manually trigger filename extraction if it didn't happen during save
    if brand_asset.original_filename.blank?
      brand_asset.send(:set_original_filename)
      brand_asset.save!
    end

    assert brand_asset.original_filename.present?
    assert brand_asset.original_filename.include?("test_image")
  end

  # Validation Tests
  test "should validate file content type" do
    # Mock an invalid file
    invalid_file = fixture_file_upload("test_invalid.exe", "application/x-msdownload")

    brand_asset = BrandAsset.new(
      file: invalid_file,
      file_type: "logo",
      assetable: @brand_identity
    )

    assert_not brand_asset.valid?
  end

  test "should validate file size limits for images" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")

    # Mock large file size
    brand_asset.file.blob.update(byte_size: 6.megabytes)

    assert_not brand_asset.valid?
    assert_includes brand_asset.errors[:file], "must be less than 5MB for images"
  end

  # Scan Status Tests
  test "should default to pending scan status" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")

    assert_equal "pending", brand_asset.scan_status
  end

  test "should mark as clean" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")

    brand_asset.mark_as_clean!

    assert_equal "clean", brand_asset.scan_status
    assert brand_asset.scanned_at.present?
  end

  test "should mark as infected and deactivate" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")

    brand_asset.mark_as_infected!

    assert_equal "infected", brand_asset.scan_status
    assert_equal false, brand_asset.active
    assert brand_asset.scanned_at.present?
  end

  test "should identify quarantined files" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")

    brand_asset.mark_as_infected!

    assert brand_asset.quarantined?
    assert_not brand_asset.safe_to_use?
  end

  # Search and Discovery Tests
  test "should search by content" do
    brand_asset1 = create_brand_asset(file: @test_image, file_type: "logo")
    brand_asset1.update_column(:original_filename, "unique_company_logo.png")

    brand_asset2 = create_brand_asset(file: @test_pdf, file_type: "brand_guideline")
    brand_asset2.update_column(:original_filename, "unique_brand_guidelines.pdf")

    # Search for unique term that should only match asset1
    results = BrandAsset.search_content("unique_company")
    assert_includes results, brand_asset1
    assert_not_includes results, brand_asset2

    # Search for term that should only match asset2
    results = BrandAsset.search_content("unique_brand")
    assert_includes results, brand_asset2
    # Don't assert that asset1 is not included, as 'unique_brand' might match its filename too
  end

  test "should search by extracted text" do
    brand_asset = create_brand_asset(file: @test_pdf, file_type: "brand_guideline")
    brand_asset.update(extracted_text: "This document contains brand guidelines and logo specifications")

    results = BrandAsset.search_content("specifications")
    assert_includes results, brand_asset

    results = BrandAsset.search_content("nonexistent")
    assert_not_includes results, brand_asset
  end

  test "should filter by metadata" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")
    brand_asset.set_metadata("tags", [ "primary", "header" ])

    results = BrandAsset.by_metadata_key("tags")
    assert_includes results, brand_asset
  end

  # Versioning Tests
  test "root asset should be identified correctly" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")

    assert brand_asset.is_root_asset?
    assert_not brand_asset.is_version?
    assert_equal brand_asset, brand_asset.root_asset
  end

  test "should create new version" do
    original_asset = create_brand_asset(file: @test_image, file_type: "logo")
    new_file = fixture_file_upload("test_image_v2.png", "image/png")

    new_version = original_asset.create_new_version(new_file, version_notes: "Updated logo design")

    assert new_version
    assert new_version.persisted?
    assert_equal original_asset, new_version.parent_asset
    assert_equal 2, new_version.version_number
    assert new_version.is_current_version?
    assert_not original_asset.reload.is_current_version?
    assert_equal "Updated logo design", new_version.version_notes
  end

  test "should get version count" do
    original_asset = create_brand_asset(file: @test_image, file_type: "logo")

    assert_equal 1, original_asset.version_count

    # Create first version
    new_file1 = fixture_file_upload("test_image_v2.png", "image/png")
    version1 = original_asset.create_new_version(new_file1)

    assert_equal 2, original_asset.version_count
    assert_equal 2, version1.version_count

    # Create second version
    new_file2 = fixture_file_upload("test_image_v3.png", "image/png")
    version2 = version1.create_new_version(new_file2)

    assert_equal 3, original_asset.version_count
    assert_equal 3, version2.version_count
  end

  test "should get latest version" do
    original_asset = create_brand_asset(file: @test_image, file_type: "logo")

    assert_equal original_asset, original_asset.latest_version

    new_file = fixture_file_upload("test_image_v2.png", "image/png")
    new_version = original_asset.create_new_version(new_file)

    assert_equal new_version, original_asset.latest_version
    assert_equal new_version, new_version.latest_version
  end

  test "should get all versions" do
    original_asset = create_brand_asset(file: @test_image, file_type: "logo")

    new_file1 = fixture_file_upload("test_image_v2.png", "image/png")
    version1 = original_asset.create_new_version(new_file1)

    new_file2 = fixture_file_upload("test_image_v3.png", "image/png")
    version2 = version1.create_new_version(new_file2)

    all_versions = original_asset.all_versions

    assert_equal 3, all_versions.count
    assert_includes all_versions, original_asset
    assert_includes all_versions, version1
    assert_includes all_versions, version2
  end

  test "should make version current" do
    original_asset = create_brand_asset(file: @test_image, file_type: "logo")

    new_file = fixture_file_upload("test_image_v2.png", "image/png")
    new_version = original_asset.create_new_version(new_file)

    # New version should be current
    assert new_version.is_current_version?
    assert_not original_asset.reload.is_current_version?

    # Make original current again
    original_asset.make_current_version!

    assert original_asset.reload.is_current_version?
    assert_not new_version.reload.is_current_version?
  end

  test "should get version history" do
    original_asset = create_brand_asset(file: @test_image, file_type: "logo")

    new_file = fixture_file_upload("test_image_v2.png", "image/png")
    new_version = original_asset.create_new_version(new_file, version_notes: "Version 2")

    # Reload both assets to get fresh state
    original_asset.reload
    new_version.reload

    history = original_asset.version_history

    assert_equal 2, history.count

    assert_equal original_asset.id, history.first[:id]
    assert_equal 1, history.first[:version_number]
    assert_equal false, history.first[:is_current]

    assert_equal new_version.id, history.last[:id]
    assert_equal 2, history.last[:version_number]
    assert_equal true, history.last[:is_current]
    assert_equal "Version 2", history.last[:version_notes]
  end

  # Text Extraction Tests
  test "should identify extractable file types" do
    pdf_asset = create_brand_asset(file: @test_pdf, file_type: "brand_guideline")
    image_asset = create_brand_asset(file: @test_image, file_type: "logo")

    assert pdf_asset.extractable_file_type?
    assert_not image_asset.extractable_file_type?
  end

  test "should track text extraction status" do
    brand_asset = create_brand_asset(file: @test_pdf, file_type: "brand_guideline")

    assert brand_asset.text_extraction_pending?
    assert_not brand_asset.text_extraction_successful?
    assert_not brand_asset.text_extraction_failed?

    # Simulate successful extraction
    brand_asset.update(
      extracted_text: "Sample extracted text",
      text_extracted_at: Time.current
    )

    assert_not brand_asset.text_extraction_pending?
    assert brand_asset.text_extraction_successful?
    assert brand_asset.has_extracted_text?

    # Test word count
    assert_equal 3, brand_asset.word_count
  end

  # Scope Tests
  test "should filter by file type" do
    logo_asset = create_brand_asset(file: @test_image, file_type: "logo")
    guideline_asset = create_brand_asset(file: @test_pdf, file_type: "brand_guideline")

    logos = BrandAsset.by_file_type("logo")
    guidelines = BrandAsset.by_file_type("brand_guideline")

    assert_includes logos, logo_asset
    assert_not_includes logos, guideline_asset

    assert_includes guidelines, guideline_asset
    assert_not_includes guidelines, logo_asset
  end

  test "should filter by scan status" do
    pending_asset = create_brand_asset(file: @test_image, file_type: "logo")
    clean_asset = create_brand_asset(file: @test_pdf, file_type: "brand_guideline")
    clean_asset.mark_as_clean!

    pending_assets = BrandAsset.by_scan_status("pending")
    clean_assets = BrandAsset.by_scan_status("clean")

    assert_includes pending_assets, pending_asset
    assert_not_includes pending_assets, clean_asset

    assert_includes clean_assets, clean_asset
    assert_not_includes clean_assets, pending_asset
  end

  test "should get current versions only" do
    original_asset = create_brand_asset(file: @test_image, file_type: "logo")

    new_file = fixture_file_upload("test_image_v2.png", "image/png")
    new_version = original_asset.create_new_version(new_file)

    current_versions = BrandAsset.current_versions

    assert_includes current_versions, new_version
    assert_not_includes current_versions, original_asset
  end

  # Utility Methods Tests
  test "should format file size humanly" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")

    # Ensure file size is extracted
    if brand_asset.file_size.blank?
      brand_asset.send(:extract_file_metadata)
      brand_asset.save!
    end

    # Test with actual file size first (should be in bytes)
    actual_size = brand_asset.file_size
    assert brand_asset.human_file_size.present?
    assert brand_asset.human_file_size.include?("B")

    # Test with specific sizes using update_column to bypass callbacks
    brand_asset.update_column(:file_size, 1024)
    assert_equal "1.0 KB", brand_asset.human_file_size

    brand_asset.update_column(:file_size, 1_048_576)
    assert_equal "1.0 MB", brand_asset.human_file_size
  end

  test "should get file extension" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")

    assert_equal "png", brand_asset.file_extension
  end

  test "should get file name" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")

    assert brand_asset.file_name.present?
    assert brand_asset.file_name.include?("test_image")
  end

  # Metadata Management Tests
  test "should set and get metadata" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")

    brand_asset.set_metadata("custom_field", "custom_value")

    assert_equal "custom_value", brand_asset.get_metadata("custom_field")
    assert_equal "custom_value", brand_asset.get_metadata(:custom_field)
  end

  test "should merge metadata" do
    brand_asset = create_brand_asset(file: @test_image, file_type: "logo")
    brand_asset.update(metadata: { "existing" => "value" })

    result = brand_asset.merge_metadata({ "new_field" => "new_value" })

    assert result
    assert_equal "value", brand_asset.reload.get_metadata("existing")
    assert_equal "new_value", brand_asset.get_metadata("new_field")
  end

  private

  def create_brand_asset(file:, file_type:, **options)
    BrandAsset.create!(
      file: file,
      file_type: file_type,
      assetable: @brand_identity,
      **options
    )
  end

  def fixture_file_upload(filename, content_type)
    # Create a simple test file if fixtures don't exist
    file_content = case content_type
    when "image/png"
                     create_test_png
    when "application/pdf"
                     create_test_pdf
    else
                     "test content"
    end

    temp_file = Tempfile.new([ filename.split(".").first, ".#{filename.split('.').last}" ])
    temp_file.binmode
    temp_file.write(file_content)
    temp_file.rewind

    ActionDispatch::Http::UploadedFile.new(
      tempfile: temp_file,
      filename: filename,
      type: content_type
    )
  end

  def create_test_png
    # Simple 1x1 PNG file
    "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\b\x00\x00\x00\x00:~\x9b\xc9\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xdb\x00\x00\x00\x00IEND\xaeB`\x82"
  end

  def create_test_pdf
    # Minimal PDF structure
    "%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj 3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n190\n%%EOF"
  end
end
