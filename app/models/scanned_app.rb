class ScannedApp < ApplicationRecord
  has_many :quality_scans, dependent: :destroy, foreign_key: :app_id
  has_many :metric_summaries, dependent: :destroy, foreign_key: :app_id
  has_many :scan_runs, dependent: :destroy, foreign_key: :app_id

  validates :name, presence: true, uniqueness: true
  validates :path, presence: true

  scope :recently_scanned, -> { where("last_scanned_at > ?", 24.hours.ago) }
  scope :needs_scan, -> { where("last_scanned_at IS NULL OR last_scanned_at < ?", 24.hours.ago) }

  def scan_status_color
    case status
    when "healthy" then "green"
    when "warning" then "yellow"
    when "critical" then "red"
    else "gray"
    end
  end

  def latest_summaries
    metric_summaries.order(scanned_at: :desc).group_by(&:scan_type).transform_values(&:first)
  end

  # Check if an app directory has been decommissioned
  # Looks for DECOMMISSIONED marker file in the app directory
  def self.decommissioned?(app_path)
    return false unless app_path

    # Check both local path and potential server path (for Capistrano deployments)
    marker_paths = [
      File.join(app_path, 'DECOMMISSIONED'),
      File.join(File.dirname(app_path), 'DECOMMISSIONED') # For /current/ subdirs
    ]

    marker_paths.any? { |path| File.exist?(path) }
  end
end
