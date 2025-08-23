class CreatePubsubEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :pubsub_events do |t|
      t.string :channel, null: false
      t.json :data, null: false
      t.datetime :created_at, null: false

      t.index :channel
      t.index :created_at
    end
  end
end
