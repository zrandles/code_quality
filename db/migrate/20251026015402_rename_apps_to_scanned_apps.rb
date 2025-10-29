class RenameAppsToScannedApps < ActiveRecord::Migration[8.1]
  def change
    # Only rename if the old table exists and new table doesn't
    if table_exists?(:apps) && !table_exists?(:scanned_apps)
      rename_table :apps, :scanned_apps
    end
  end
end
