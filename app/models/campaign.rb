class Campaign < ApplicationRecord
  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :status, presence: true, inclusion: { in: %w[draft active paused completed archived] }
  validates :purpose, presence: true, length: { minimum: 10, maximum: 500 }

  scope :active, -> { where(status: 'active') }
  scope :draft, -> { where(status: 'draft') }

  def active?
    status == 'active'
  end

  def draft?
    status == 'draft'
  end

  def status_color
    case status
    when 'active' then 'bg-green-100 text-green-800'
    when 'draft' then 'bg-gray-100 text-gray-600'
    when 'paused' then 'bg-yellow-100 text-yellow-800'
    when 'completed' then 'bg-blue-100 text-blue-800'
    when 'archived' then 'bg-red-100 text-red-600'
    else 'bg-gray-100 text-gray-600'
    end
  end
end
