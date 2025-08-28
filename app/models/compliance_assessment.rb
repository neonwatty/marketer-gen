class ComplianceAssessment < ApplicationRecord
  belongs_to :compliance_requirement

  scope :recent, -> { order(created_at: :desc) }
end
