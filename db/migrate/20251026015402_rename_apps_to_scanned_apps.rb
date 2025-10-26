class RenameAppsToScannedApps < ActiveRecord::Migration[8.1]
  def change
    rename_table :apps, :scanned_apps
  end
end
