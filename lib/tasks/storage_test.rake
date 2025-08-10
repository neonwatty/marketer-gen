namespace :storage do
  desc "Test Active Storage configuration"
  task test: :environment do
    puts "Testing Active Storage configuration..."
    puts "Current service: #{Rails.application.config.active_storage.service}"

    # Test basic Active Storage functionality
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("test content"),
      filename: "test.txt",
      content_type: "text/plain"
    )

    puts "✅ Successfully created blob: #{blob.filename}"
    puts "   - Key: #{blob.key}"
    puts "   - Size: #{blob.byte_size} bytes"
    puts "   - Service: #{blob.service.class}"

    # Test file retrieval
    content = blob.download
    puts "✅ Successfully retrieved content: #{content.inspect}"

    # Cleanup
    blob.purge
    puts "✅ Successfully cleaned up test blob"

    puts "\n🎉 Active Storage is working correctly!"
  end

  desc "List storage configuration"
  task config: :environment do
    puts "Active Storage Configuration:"
    puts "=========================="
    puts "Environment: #{Rails.env}"
    puts "Service: #{Rails.application.config.active_storage.service}"
    puts "Variant processor: #{Rails.application.config.active_storage.variant_processor}"

    # Show configured storage services
    puts "\nConfigured storage services:"
    puts "  - local (Disk storage)"
    puts "  - test (Disk storage for testing)"
    puts "  - amazon (AWS S3)"
    puts "  - google (Google Cloud Storage)"
    puts "  - production_mirror (AWS S3 + GCS mirror)"
  end

  desc "Test cloud storage connection (requires credentials)"
  task test_cloud: :environment do
    puts "Testing cloud storage connections..."

    # Test AWS S3 if credentials are available
    if Rails.application.config.active_storage.service_configurations["amazon"]
      puts "\nTesting AWS S3..."
      begin
        s3_service = ActiveStorage::Service.configure(:amazon, Rails.application.config.active_storage.service_configurations["amazon"])
        blob = ActiveStorage::Blob.new(key: "test-#{SecureRandom.hex}", filename: "test.txt", content_type: "text/plain")
        s3_service.upload(blob.key, StringIO.new("test content"))
        s3_service.delete(blob.key)
        puts "✅ AWS S3 connection successful"
      rescue => e
        puts "❌ AWS S3 connection failed: #{e.message}"
      end
    else
      puts "⚠️  AWS S3 not configured"
    end

    # Test Google Cloud Storage if credentials are available
    if Rails.application.config.active_storage.service_configurations["google"]
      puts "\nTesting Google Cloud Storage..."
      begin
        gcs_service = ActiveStorage::Service.configure(:google, Rails.application.config.active_storage.service_configurations["google"])
        blob = ActiveStorage::Blob.new(key: "test-#{SecureRandom.hex}", filename: "test.txt", content_type: "text/plain")
        gcs_service.upload(blob.key, StringIO.new("test content"))
        gcs_service.delete(blob.key)
        puts "✅ Google Cloud Storage connection successful"
      rescue => e
        puts "❌ Google Cloud Storage connection failed: #{e.message}"
      end
    else
      puts "⚠️  Google Cloud Storage not configured"
    end
  end
end
