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

  def time_duration_in_words(seconds)
    return nil unless seconds

    if seconds < 60
      "#{seconds.round}s"
    elsif seconds < 3600
      minutes = (seconds / 60).round
      "#{minutes}m"
    else
      hours = (seconds / 3600).round(1)
      "#{hours}h"
    end
  end
end
