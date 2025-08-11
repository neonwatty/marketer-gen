require "test_helper"

class BrandAssetsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @brand_identity = BrandIdentity.create!(
      name: "Test Brand",
      description: "Test brand for testing"
    )

    @brand_asset = create_brand_asset(
      file_type: "logo",
      purpose: "Primary logo for website"
    )

    @brand_asset_2 = create_brand_asset(
      file_type: "brand_guideline",
      purpose: "Brand guidelines document"
    )
  end

  # Index Action Tests
  test "should get index" do
    get brand_assets_url
    assert_response :success
    assert_select "h1", "Brand Assets"
  end

  test "should get index with JSON format" do
    get brand_assets_url, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["brand_assets"].is_a?(Array)
    assert json_response["meta"].present?
  end

  test "should filter by file type" do
    get brand_assets_url(file_type: "logo")
    assert_response :success

    # Check that only logo assets are returned in JSON
    get brand_assets_url(file_type: "logo"), as: :json
    json_response = JSON.parse(response.body)

    logo_assets = json_response["brand_assets"].select { |asset| asset["file_type"] == "logo" }
    assert_equal json_response["brand_assets"].count, logo_assets.count
  end

  test "should filter by scan status" do
    @brand_asset.mark_as_clean!

    get brand_assets_url(scan_status: "clean"), as: :json
    json_response = JSON.parse(response.body)

    clean_assets = json_response["brand_assets"].select { |asset| asset["scan_status"] == "clean" }
    assert clean_assets.count > 0
  end

  test "should search by content" do
    @brand_asset.update(original_filename: "company_logo.png")

    get brand_assets_url(search: "logo"), as: :json
    json_response = JSON.parse(response.body)

    matching_assets = json_response["brand_assets"].select do |asset|
      asset["original_filename"]&.include?("logo")
    end
    assert matching_assets.count > 0
  end

  test "should sort assets" do
    # Test different sorting options
    %w[recent oldest name name_desc size size_desc file_type].each do |sort_option|
      get brand_assets_url(sort: sort_option), as: :json
      assert_response :success

      json_response = JSON.parse(response.body)
      assert json_response["brand_assets"].is_a?(Array)
    end
  end

  test "should filter by size range" do
    get brand_assets_url(size_range: "small"), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["brand_assets"].is_a?(Array)
  end

  test "should paginate results" do
    get brand_assets_url(page: 2, per_page: 1), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["meta"]["current_page"].present?
  end

  # New Asset Action Tests
  test "should get new" do
    get new_brand_asset_url
    assert_response :success
    assert_select "h1", "Upload Brand Assets"
  end

  # Create Action Tests
  test "should create brand asset" do
    file = fixture_file_upload("test_logo.png", "image/png")

    assert_difference("BrandAsset.count", 1) do
      post brand_assets_url, params: {
        brand_asset: {
          file: file,
          file_type: "logo",
          purpose: "Test logo",
          assetable_id: @brand_identity.id,
          assetable_type: "BrandIdentity"
        }
      }
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert json_response["brand_asset"].present?
  end

  test "should not create brand asset without file" do
    assert_no_difference("BrandAsset.count") do
      post brand_assets_url, params: {
        brand_asset: {
          file_type: "logo",
          purpose: "Test logo"
        }
      }, as: :json
    end

    assert_response :unprocessable_content
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert json_response["errors"].present?
  end

  # Upload Multiple Action Tests
  test "should upload multiple files" do
    file1 = fixture_file_upload("test_logo1.png", "image/png")
    file2 = fixture_file_upload("test_logo2.png", "image/png")

    initial_count = BrandAsset.count

    assert_difference("BrandAsset.count", 2) do
      post upload_multiple_brand_assets_url, params: {
        uploads: [
          {
            file: file1,
            file_type: "logo",
            purpose: "Logo 1",
            assetable_type: "BrandIdentity",
            assetable_id: @brand_identity.id
          },
          {
            file: file2,
            file_type: "logo",
            purpose: "Logo 2",
            assetable_type: "BrandIdentity",
            assetable_id: @brand_identity.id
          }
        ]
      }
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal 2, json_response["brand_assets"].count
  end

  test "should handle partial upload failure" do
    valid_file = fixture_file_upload("test_logo.png", "image/png")
    invalid_file = fixture_file_upload("test_invalid.exe", "application/x-msdownload")

    post upload_multiple_brand_assets_url, params: {
      uploads: [
        { file: valid_file, file_type: "logo", purpose: "Valid logo", assetable_id: @brand_identity.id, assetable_type: "BrandIdentity" },
        { file: invalid_file, file_type: "logo", purpose: "Invalid file", assetable_id: @brand_identity.id, assetable_type: "BrandIdentity" }
      ]
    }

    assert_response :unprocessable_content
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_equal 1, json_response["uploaded_assets"].count
    assert_equal 1, json_response["failed_uploads"].count
  end

  # Update Action Tests
  test "should update brand asset" do
    patch brand_asset_url(@brand_asset), params: {
      brand_asset: {
        purpose: "Updated logo purpose",
        file_type: "image_asset"
      }
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]

    @brand_asset.reload
    assert_equal "Updated logo purpose", @brand_asset.purpose
    assert_equal "image_asset", @brand_asset.file_type
  end

  test "should not update with invalid data" do
    patch brand_asset_url(@brand_asset), params: {
      brand_asset: {
        file_type: ""
      }
    }, as: :json

    assert_response :unprocessable_content
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert json_response["errors"].present?
  end

  # Update Metadata Action Tests
  test "should update metadata" do
    # Ensure brand asset has some initial metadata
    @brand_asset.update(metadata: {})

    patch update_metadata_brand_asset_url(@brand_asset), params: {
      metadata: {
        tags: [ "primary", "website" ],
        description: "Main website logo",
        custom_field: "custom_value"
      }
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]

    @brand_asset.reload
    assert_equal [ "primary", "website" ], @brand_asset.get_metadata("tags")
    assert_equal "Main website logo", @brand_asset.get_metadata("description")
    assert_equal "custom_value", @brand_asset.get_metadata("custom_field")
  end

  test "should not update with invalid metadata" do
    patch update_metadata_brand_asset_url(@brand_asset), params: {
      metadata: "invalid_metadata"
    }, as: :json

    assert_response :unprocessable_content
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
  end

  # Destroy Action Tests
  test "should destroy brand asset" do
    assert_difference("BrandAsset.count", -1) do
      delete brand_asset_url(@brand_asset), as: :json
    end

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
  end

  test "should handle destroy of non-existent asset" do
    delete brand_asset_url(99999), as: :json

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
  end

  # Advanced Filtering Tests
  test "should filter by purpose" do
    get brand_assets_url(purpose: "logo"), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    matching_assets = json_response["brand_assets"].select do |asset|
      asset["purpose"]&.downcase&.include?("logo")
    end
    assert matching_assets.count > 0
  end

  test "should filter by date range" do
    # Create an asset with specific date
    old_asset = create_brand_asset(file_type: "logo")
    old_asset.update(created_at: 1.week.ago)

    get brand_assets_url(date_from: 2.days.ago.to_date), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    # Should not include the old asset
    old_asset_ids = json_response["brand_assets"].map { |a| a["id"] }
    assert_not_includes old_asset_ids, old_asset.id
  end

  test "should filter by extracted text" do
    @brand_asset.update(extracted_text: "Sample brand guidelines text")

    get brand_assets_url(has_text: "true"), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    text_assets = json_response["brand_assets"].select { |asset| asset["extracted_text"].present? }
    assert text_assets.count > 0
  end

  test "should filter by tags in metadata" do
    @brand_asset.set_metadata("tags", "primary,website")

    get brand_assets_url(tags: "primary"), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    # Should return assets with matching tags
    assert json_response["brand_assets"].present?
  end

  # Performance and Edge Cases
  test "should handle empty results" do
    BrandAsset.destroy_all

    get brand_assets_url, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal [], json_response["brand_assets"]
  end

  test "should handle invalid sort parameter" do
    get brand_assets_url(sort: "invalid_sort"), as: :json
    assert_response :success

    # Should default to recent sorting
    json_response = JSON.parse(response.body)
    assert json_response["brand_assets"].is_a?(Array)
  end

  test "should handle complex filter combinations" do
    @brand_asset.mark_as_clean!
    @brand_asset.update(purpose: "primary logo for website")

    get brand_assets_url(
      file_type: "logo",
      scan_status: "clean",
      search: "primary",
      sort: "name",
      size_range: "small"
    ), as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["brand_assets"].is_a?(Array)
  end

  # JSON Response Structure Tests
  test "should return correct JSON structure for asset" do
    get brand_assets_url, as: :json
    json_response = JSON.parse(response.body)

    first_asset = json_response["brand_assets"].first

    # Verify all expected fields are present
    expected_fields = %w[
      id file_type purpose original_filename file_size human_file_size
      content_type file_extension file_url scan_status active metadata
      extracted_text created_at updated_at assetable_type assetable_id
    ]

    expected_fields.each do |field|
      assert first_asset.key?(field), "Missing field: #{field}"
    end
  end

  test "should return correct metadata structure" do
    get brand_assets_url, as: :json
    json_response = JSON.parse(response.body)

    meta = json_response["meta"]
    assert meta.key?("current_page")
    assert meta.key?("total_pages")
    assert meta.key?("total_count")
  end

  # Security and Authorization Tests
  test "should not allow file uploads with dangerous content types" do
    dangerous_file = fixture_file_upload("test_script.js", "application/javascript")

    assert_no_difference("BrandAsset.count") do
      post brand_assets_url, params: {
        brand_asset: {
          file: dangerous_file,
          file_type: "other",
          purpose: "Test script"
        }
      }, as: :json
    end

    assert_response :unprocessable_content
  end

  test "should sanitize search parameters" do
    # Test with SQL injection attempt
    get brand_assets_url(search: "'; DROP TABLE brand_assets; --"), as: :json
    assert_response :success

    # Should not cause any database issues
    assert BrandAsset.count > 0
  end

  private

  def create_brand_asset(file_type:, **options)
    # Use appropriate file type for each category
    file_extension, content_type = case file_type
    when "logo", "image_asset"
                                     [ "png", "image/png" ]
    when "brand_guideline", "style_guide", "compliance_document", "presentation"
                                     [ "pdf", "application/pdf" ]
    when "font_file"
                                     [ "woff", "font/woff" ]
    else
                                     [ "png", "image/png" ]
    end

    file = fixture_file_upload("test_#{file_type}.#{file_extension}", content_type)

    BrandAsset.create!(
      file: file,
      file_type: file_type,
      assetable: @brand_identity,
      **options
    )
  end

  def fixture_file_upload(path_or_filename, mime_type = nil, binary = false)
    if path_or_filename.is_a?(String) && !File.exist?(path_or_filename)
      # Create a simple test file
      file_content = case mime_type
      when "image/png"
                       create_test_png
      when "application/pdf"
                       create_test_pdf
      when "application/javascript"
                       'console.log("test");'
      when "application/x-msdownload"
                       "MZ" + "\x00" * 100  # Fake exe header
      when "font/woff"
                       "WOFF\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"  # Simple WOFF header
      else
                       "test content"
      end

      temp_file = Tempfile.new([ path_or_filename.split(".").first, ".#{path_or_filename.split('.').last}" ])
      temp_file.binmode
      temp_file.write(file_content)
      temp_file.rewind

      Rack::Test::UploadedFile.new(temp_file.path, mime_type, binary)
    else
      # Use existing file path
      Rack::Test::UploadedFile.new(path_or_filename, mime_type, binary)
    end
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
