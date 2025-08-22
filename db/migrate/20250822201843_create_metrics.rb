class CreateMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :metrics do |t|
      t.string :name
      t.decimal :value
      t.string :unit
      t.string :category
      t.datetime :timestamp

      t.timestamps
    end
  end
end
