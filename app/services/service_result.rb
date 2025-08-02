# frozen_string_literal: true

class ServiceResult
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :success, :boolean, default: false
  attribute :message, :string
  attribute :data
  attribute :errors, default: -> { [] }

  def self.success(message: nil, data: nil)
    new(success: true, message: message, data: data)
  end

  def self.failure(message = nil, data: nil, errors: [])
    # Handle both positional and keyword arguments for backward compatibility
    if message.is_a?(Hash)
      options = message
      new(success: false, message: options[:message], data: options[:data], errors: Array(options[:errors] || []))
    else
      new(success: false, message: message, data: data, errors: Array(errors))
    end
  end

  def success?
    success
  end

  def failure?
    !success
  end

  def error_messages
    if errors.respond_to?(:full_messages)
      errors.full_messages
    else
      Array(errors)
    end
  end

  def to_h
    {
      success: success?,
      message: message,
      data: data,
      errors: error_messages
    }
  end

  def as_json(options = {})
    to_h.as_json(options)
  end
end