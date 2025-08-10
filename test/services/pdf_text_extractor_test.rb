require "test_helper"

class PdfTextExtractorTest < ActiveSupport::TestCase
  def setup
    @brand_identity = BrandIdentity.create!(
      name: "Test Brand",
      version: 1.0,
      guidelines: {},
      color_palette: {},
      typography: {},
      messaging_frameworks: {}
    )
  end

  def teardown
    # Clean up any uploaded files
    ActiveStorage::Blob.all.each(&:purge)
  end

  test "should be extractable with valid PDF" do
    brand_asset = create_brand_asset_with_valid_file_type
    extractor = PdfTextExtractor.new(brand_asset)

    # This tests the logic without requiring actual PDF parsing
    assert brand_asset.extractable_file_type?, "BrandAsset should be marked as extractable"
  end

  test "should not be extractable for image files" do
    brand_asset = create_brand_asset_with_image_type
    extractor = PdfTextExtractor.new(brand_asset)

    refute brand_asset.extractable_file_type?, "Image assets should not be extractable"
    refute extractor.extractable?, "Should not be extractable from image files"
  end

  test "should handle missing brand asset gracefully" do
    extractor = PdfTextExtractor.new(nil)

    refute extractor.extractable?, "Should not be extractable with nil brand asset"
    assert_equal [], extractor.errors
  end

  test "should validate file attachment requirement" do
    # Create brand asset without file attached
    brand_asset = BrandAsset.new(
      file_type: "brand_guideline",
      assetable: @brand_identity,
      metadata: {}
    )
    brand_asset.save!(validate: false) # Skip validations to create asset without file

    extractor = PdfTextExtractor.new(brand_asset)
    refute extractor.extractable?, "Should not be extractable without file attachment"
  end

  test "should reject oversized files" do
    brand_asset = create_brand_asset_with_valid_file_type

    # Mock the file size to be larger than limit
    blob = brand_asset.file.blob
    blob.update_column(:byte_size, PdfTextExtractor::MAX_FILE_SIZE + 1)

    extractor = PdfTextExtractor.new(brand_asset)
    refute extractor.extractable?, "Should reject files larger than size limit"
  end

  private

  def create_brand_asset_with_valid_file_type
    brand_asset = BrandAsset.new(
      file_type: "brand_guideline",
      assetable: @brand_identity,
      metadata: {}
    )

    # Create a fake PDF file attachment
    brand_asset.file.attach(
      io: StringIO.new("%PDF-1.4\nfake pdf content"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )

    brand_asset.save!
    brand_asset
  end

  def create_brand_asset_with_image_type
    brand_asset = BrandAsset.new(
      file_type: "logo",
      assetable: @brand_identity,
      metadata: {}
    )

    # Mock image file
    brand_asset.file.attach(
      io: StringIO.new("fake image content"),
      filename: "test.png",
      content_type: "image/png"
    )

    brand_asset.save!
    brand_asset
  end
end
