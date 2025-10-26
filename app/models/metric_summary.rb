class MetricSummary < ApplicationRecord
  belongs_to :scanned_app, foreign_key: :app_id

  validates :scan_type, presence: true

  scope :recent, -> { where("scanned_at > ?", 7.days.ago) }
  scope :by_type, ->(type) { where(scan_type: type) }

  serialize :metadata, coder: JSON

  def status
    return "healthy" if total_issues.zero?
    return "critical" if high_severity > 0
    return "warning" if medium_severity > 5
    "healthy"
  end

  def status_color
    case status
    when "healthy" then "green"
    when "warning" then "yellow"
    when "critical" then "red"
    else "gray"
    end
  end
end
