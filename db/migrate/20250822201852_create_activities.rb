class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :activities do |t|
      t.text :message
      t.string :level
      t.string :source
      t.datetime :timestamp

      t.timestamps
    end
  end
end
