class CreateManufacturers < ActiveRecord::Migration[8.0]
  def change
    create_table :manufacturers do |t|
      t.string :name, null: false
      t.string :code, null: false          # ex. GE, VIK, COME, TRAS
      t.datetime :archived_at
      t.timestamps
    end

    add_index :manufacturers, :name, unique: true
    add_index :manufacturers, :code, unique: true
  end
end
