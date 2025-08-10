require "application_system_test_case"

class BrandAssetManagementTest < ApplicationSystemTestCase
  def setup
    @brand_identity = BrandIdentity.create!(
      name: "Test Brand",
      description: "Test brand for testing"
    )

    # Create test assets
    @logo_asset = create_brand_asset("logo", "company_logo.png")
    @guideline_asset = create_brand_asset("brand_guideline", "brand_guidelines.pdf")
    @style_asset = create_brand_asset("style_guide", "style_guide.pdf")

    # Mark some as clean for testing
    @logo_asset.mark_as_clean!
    @guideline_asset.mark_as_clean!
  end

  # Basic Navigation Tests
  test "visiting the brand assets index page" do
    visit brand_assets_url

    assert_selector "h1", text: "Brand Assets"
    assert_selector ".file-card, .file-item", count: 3
  end

  test "displays file statistics correctly" do
    visit brand_assets_url

    # Check stats overview
    within ".grid.grid-cols-1.md\\:grid-cols-4" do
      assert_text "3"  # Total assets
      assert_text "2"  # Clean files (2 marked as clean)
      assert_text "1"  # Pending scan (1 still pending)
    end
  end

  # View Toggle Tests
  test "can switch between grid and list views" do
    visit brand_assets_url

    # Should start in grid view
    assert_selector "[data-file-manager-target='fileGrid']"
    assert_not_selector "[data-file-manager-target='fileList']:not(.hidden)"

    # Switch to list view
    click_button "List View" # The list view button

    # Should now show list view
    assert_selector "[data-file-manager-target='fileList']:not(.hidden)"
    assert_selector "[data-file-manager-target='fileGrid'].hidden"
  end

  test "view preference persists on page reload" do
    visit brand_assets_url

    # Switch to list view
    click_button "List View"

    # Reload page
    refresh

    # Should still be in list view
    assert_selector "[data-file-manager-target='fileList']:not(.hidden)"
  end

  # Search and Filter Tests
  test "can search for assets by name" do
    visit brand_assets_url

    fill_in "Search files, content, and metadata...", with: "logo"

    # Wait for search to complete (using AJAX)
    assert_selector ".file-card, .file-item", count: 1
    assert_text "company_logo.png"
    assert_no_text "brand_guidelines.pdf"
  end

  test "can filter by file type" do
    visit brand_assets_url

    select "Brand guideline", from: "File Type"

    # Should show only brand guideline assets
    assert_selector ".file-card, .file-item", count: 1
    assert_text "brand_guidelines.pdf"
    assert_no_text "company_logo.png"
  end

  test "can filter by scan status" do
    visit brand_assets_url

    select "Clean", from: "Scan Status"

    # Should show only clean assets (2 assets)
    assert_selector ".file-card, .file-item", count: 2
  end

  test "can combine multiple filters" do
    visit brand_assets_url

    select "Logo", from: "File Type"
    select "Clean", from: "Scan Status"

    # Should show only clean logo assets
    assert_selector ".file-card, .file-item", count: 1
    assert_text "company_logo.png"
  end

  test "can clear all filters" do
    visit brand_assets_url

    # Apply filters
    select "Logo", from: "File Type"
    fill_in "Search files, content, and metadata...", with: "test"

    # Clear filters
    click_button "Clear All"

    # Should show all assets again
    assert_selector ".file-card, .file-item", count: 3
  end

  # File Selection Tests
  test "can select individual files" do
    visit brand_assets_url

    # Select first file
    first(".file-checkbox").check

    # Bulk actions should appear
    assert_selector "[data-file-manager-target='bulkActions']:not(.hidden)"
    assert_text "1 selected"
  end

  test "can select all files" do
    visit brand_assets_url

    check "Select All"

    # All files should be selected
    assert_selector "[data-file-manager-target='bulkActions']:not(.hidden)"
    assert_text "3 selected"

    # All checkboxes should be checked
    assert_selector ".file-checkbox:checked", count: 3
  end

  test "can clear selection" do
    visit brand_assets_url

    check "Select All"
    assert_text "3 selected"

    click_button "Clear"

    # Selection should be cleared
    assert_selector "[data-file-manager-target='bulkActions'].hidden"
    assert_no_selector ".file-checkbox:checked"
  end

  # File Preview Tests
  test "can preview image files" do
    visit brand_assets_url

    # Click on image preview
    find("[data-file-id='#{@logo_asset.id}'] .cursor-pointer").click

    # Modal should open
    assert_selector "[data-file-manager-target='previewModal']:not(.hidden)"
    assert_selector ".modal-title"

    # Should show image
    assert_selector "img[src*='#{@logo_asset.id}']"
  end

  test "can preview PDF files" do
    visit brand_assets_url

    find("[data-file-id='#{@guideline_asset.id}'] .cursor-pointer").click

    # Modal should open with PDF embed
    assert_selector "[data-file-manager-target='previewModal']:not(.hidden)"
    assert_selector "embed[type='application/pdf']"
  end

  test "can close preview modal" do
    visit brand_assets_url

    find("[data-file-id='#{@logo_asset.id}'] .cursor-pointer").click
    assert_selector "[data-file-manager-target='previewModal']:not(.hidden)"

    # Close modal
    find("[data-action='click->file-manager#closePreviewModal']").click

    assert_selector "[data-file-manager-target='previewModal'].hidden"
  end

  # Metadata Editing Tests
  test "can open metadata editing modal" do
    visit brand_assets_url

    find("[data-file-id='#{@logo_asset.id}'] [title='Edit Metadata']").click

    # Modal should open
    assert_selector "[data-file-manager-target='metadataModal']:not(.hidden)"
    assert_text "Edit File Metadata"

    # Form should be populated
    assert_field "File Name", with: @logo_asset.file_name, disabled: true
    assert_field "File Type", with: @logo_asset.file_type
  end

  test "can update metadata" do
    visit brand_assets_url

    find("[data-file-id='#{@logo_asset.id}'] [title='Edit Metadata']").click

    # Update metadata
    fill_in "Purpose/Description", with: "Updated logo purpose"
    fill_in "Tags", with: "primary, header, website"
    fill_in "Description", with: "Main company logo for website header"

    click_button "Save Changes"

    # Modal should close and show success
    assert_selector "[data-file-manager-target='metadataModal'].hidden"

    # Verify update (would need to check via AJAX response or page refresh)
    refresh
    find("[data-file-id='#{@logo_asset.id}'] [title='Edit Metadata']").click
    assert_field "Purpose/Description", with: "Updated logo purpose"
  end

  test "can cancel metadata editing" do
    visit brand_assets_url

    find("[data-file-id='#{@logo_asset.id}'] [title='Edit Metadata']").click

    fill_in "Purpose/Description", with: "Changed purpose"

    click_button "Cancel"

    # Modal should close without saving
    assert_selector "[data-file-manager-target='metadataModal'].hidden"

    # Changes should not be saved
    find("[data-file-id='#{@logo_asset.id}'] [title='Edit Metadata']").click
    assert_no_field "Purpose/Description", with: "Changed purpose"
  end

  # Bulk Operations Tests
  test "can perform bulk delete" do
    visit brand_assets_url

    # Select multiple files
    first(".file-checkbox").check
    all(".file-checkbox").last.check

    assert_text "2 selected"

    # Perform delete (would normally trigger confirmation dialog)
    accept_confirm do
      click_button "Delete"
    end

    # Should show fewer assets after delete
    assert_selector ".file-card, .file-item", count: 1
  end

  test "can perform bulk download" do
    visit brand_assets_url

    check "Select All"

    # Mock download behavior (actual downloads are hard to test in system tests)
    click_button "Download"

    # Should show progress or success notification
    # Note: Actual file downloads would need special handling in tests
  end

  test "can perform bulk categorization" do
    visit brand_assets_url

    first(".file-checkbox").check
    all(".file-checkbox").last.check

    # Mock categorization (would normally prompt for new category)
    page.driver.browser.execute_script("
      window.prompt = function(msg) { return 'image_asset'; };
    ")

    click_button "Categorize"

    # Should update categories
    assert_text "2 files categorized successfully"
  end

  # Sorting Tests
  test "can sort assets by different criteria" do
    visit brand_assets_url

    # Test different sort options
    select "Name A-Z", from: "Sort By"
    # Would verify order but hard to test without more specific content

    select "Largest First", from: "Sort By"
    # Would verify order is by file size descending

    select "File Type", from: "Sort By"
    # Would verify assets are grouped by file type
  end

  # Keyboard Shortcuts Tests
  test "keyboard shortcuts work" do
    visit brand_assets_url

    # Test Ctrl+A to select all
    find("body").send_keys [ :control, "a" ]

    assert_selector "[data-file-manager-target='bulkActions']:not(.hidden)"
    assert_text "3 selected"
  end

  # Error Handling Tests
  test "handles errors gracefully" do
    visit brand_assets_url

    # Mock network error by intercepting requests
    page.driver.browser.execute_script("
      const originalFetch = window.fetch;
      window.fetch = function() {
        return Promise.reject(new Error('Network error'));
      };
    ")

    # Try to perform search
    fill_in "Search files, content, and metadata...", with: "test"

    # Should show error notification
    assert_text "Filter update failed"
  end

  # Mobile Responsiveness Tests (basic check)
  test "responsive design works on mobile" do
    resize_window_to_mobile

    visit brand_assets_url

    # Should still show basic functionality
    assert_selector "h1", text: "Brand Assets"
    assert_selector ".file-card, .file-item"

    # Mobile-specific layout adjustments
    assert_selector ".max-w-7xl.mx-auto"
  end

  # Upload Integration Tests
  test "can navigate to upload page" do
    visit brand_assets_url

    click_link "Upload Assets"

    assert_current_path new_brand_asset_path
    assert_text "Upload Brand Assets"
  end

  # Performance Tests
  test "page loads quickly with many assets" do
    # Create additional test assets
    10.times do |i|
      create_brand_asset("logo", "logo_#{i}.png")
    end

    start_time = Time.current
    visit brand_assets_url
    load_time = Time.current - start_time

    # Should load within reasonable time (2 seconds)
    assert load_time < 2.seconds

    # Should show all assets
    assert_selector ".file-card, .file-item", count: 13
  end

  private

  def create_brand_asset(file_type, filename)
    file = create_test_file(filename)

    BrandAsset.create!(
      file: file,
      file_type: file_type,
      assetable: @brand_identity,
      purpose: "Test #{file_type} for #{filename}",
      original_filename: filename
    )
  end

  def create_test_file(filename)
    content = case File.extname(filename)
    when ".png", ".jpg", ".gif"
                create_test_png
    when ".pdf"
                create_test_pdf
    else
                "test content"
    end

    temp_file = Tempfile.new([ File.basename(filename, ".*"), File.extname(filename) ])
    temp_file.binmode
    temp_file.write(content)
    temp_file.rewind

    ActionDispatch::Http::UploadedFile.new(
      tempfile: temp_file,
      filename: filename,
      type: get_mime_type(filename)
    )
  end

  def get_mime_type(filename)
    case File.extname(filename)
    when ".png" then "image/png"
    when ".jpg", ".jpeg" then "image/jpeg"
    when ".gif" then "image/gif"
    when ".pdf" then "application/pdf"
    else "text/plain"
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

  def resize_window_to_mobile
    page.driver.browser.manage.window.resize_to(375, 667)  # iPhone 6/7/8 size
  end
end
