require "digest"

class ContentStorageSystem
  attr_reader :errors

  def initialize
    @errors = []
  end

  def store(content_data)
    # Validate required fields
    validate_content_data!(content_data)

    # Generate required fields for storage
    file_hash = Digest::SHA256.hexdigest("#{content_data[:title]}#{content_data[:body]}#{Time.current.to_f}")
    storage_path = "content/#{Date.current.strftime('%Y/%m')}/#{file_hash[0..7]}"

    repository = ContentRepository.create!(
      title: content_data[:title],
      body: content_data[:body],
      content_type: content_data[:content_type],
      format: content_data[:format],
      user_id: content_data[:user_id],
      campaign_id: content_data[:campaign_id],
      storage_path: storage_path,
      file_hash: file_hash
    )

    # Return structured response matching test expectations
    {
      id: repository.id,
      title: repository.title,
      content_type: repository.content_type,
      created_at: repository.created_at,
      file_hash: repository.file_hash,
      storage_path: repository.storage_path
    }
  rescue => e
    @errors << e.message
    raise e
  end

  def retrieve(content_id)
    repository = ContentRepository.find(content_id)
    {
      id: repository.id,
      title: repository.title,
      body: repository.body,
      content_type: repository.content_type,
      format: repository.format,
      created_at: repository.created_at,
      updated_at: repository.updated_at
    }
  end

  def update_metadata(content_id, metadata)
    repository = ContentRepository.find(content_id)
    repository.update!(metadata)
    true
  end

  def delete(content_id)
    repository = ContentRepository.find(content_id)
    repository.destroy!
    true
  end

  private

  def validate_content_data!(data)
    required_fields = [ :title, :body, :content_type, :format, :user_id ]
    missing_fields = required_fields.select { |field| !data.key?(field) || data[field].blank? }

    if missing_fields.any?
      raise ArgumentError, "Missing required fields: #{missing_fields.join(', ')}"
    end
  end
end
