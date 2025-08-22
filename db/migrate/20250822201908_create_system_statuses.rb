class CreateSystemStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :system_statuses do |t|
      t.string :status
      t.integer :uptime
      t.datetime :last_check
      t.jsonb :details

      t.timestamps
    end
  end
end
