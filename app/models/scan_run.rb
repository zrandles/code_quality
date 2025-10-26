class ScanRun < ApplicationRecord
  belongs_to :scanned_app, foreign_key: :app_id

  serialize :scan_types, coder: JSON

  scope :recent, -> { order(started_at: :desc).limit(10) }
  scope :completed, -> { where.not(completed_at: nil) }

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end
end
