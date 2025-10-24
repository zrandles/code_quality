class CreateScanRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :scan_runs do |t|
      t.references :app, null: false, foreign_key: true
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :total_issues
      t.string :status
      t.text :scan_types

      t.timestamps
    end
  end
end
