module ApplicationHelper
  def status_badge_classes(status)
    case status
    when 'active'
      'bg-green-100 text-green-800'
    when 'draft'
      'bg-gray-100 text-gray-800'
    when 'paused'
      'bg-yellow-100 text-yellow-800'
    when 'completed'
      'bg-blue-100 text-blue-800'
    when 'archived'
      'bg-red-100 text-red-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
end
