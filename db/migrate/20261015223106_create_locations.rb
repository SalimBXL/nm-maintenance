class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.references :department, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code, null: false
      t.references :referent, foreign_key: { to_table: :users } # optionnel
      t.datetime :archived_at
      t.timestamps
    end

    add_index :locations, %i[department_id code], unique: true
  end
end
