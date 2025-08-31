class DemoProgress < ApplicationRecord
  belongs_to :demo_analytic

  validates :step_number, presence: true, numericality: { greater_than: 0 }
  validates :step_title, presence: true
  validates :completed_at, presence: true
  validates :time_spent, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:step_number) }
  scope :completed_today, -> { where(completed_at: Date.current.beginning_of_day..Date.current.end_of_day) }

  def time_spent_seconds
    time_spent || 0
  end

  def time_spent_formatted
    return "0s" if time_spent.nil? || time_spent.zero?
    
    if time_spent < 60
      "#{time_spent}s"
    elsif time_spent < 3600
      minutes = time_spent / 60
      seconds = time_spent % 60
      seconds.zero? ? "#{minutes}m" : "#{minutes}m #{seconds}s"
    else
      hours = time_spent / 3600
      remaining_seconds = time_spent % 3600
      minutes = remaining_seconds / 60
      seconds = remaining_seconds % 60
      
      result = "#{hours}h"
      result += " #{minutes}m" if minutes > 0
      result += " #{seconds}s" if seconds > 0
      result
    end
  end
end
