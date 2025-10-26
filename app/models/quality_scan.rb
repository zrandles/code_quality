class QualityScan < ApplicationRecord
  belongs_to :scanned_app, foreign_key: :app_id

  SCAN_TYPES = %w[security static_analysis rubocop test_coverage js_complexity architecture drift].freeze
  SEVERITIES = %w[critical high medium low info].freeze

  validates :scan_type, inclusion: { in: SCAN_TYPES }
  validates :severity, inclusion: { in: SEVERITIES }, allow_nil: true

  scope :recent, -> { where("scanned_at > ?", 7.days.ago) }
  scope :by_type, ->(type) { where(scan_type: type) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :critical_issues, -> { where(severity: %w[critical high]) }
end
