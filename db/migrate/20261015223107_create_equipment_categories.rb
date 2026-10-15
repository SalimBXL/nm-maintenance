class CreateEquipmentCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :equipment_categories do |t|
      t.string :name, null: false
      t.text :description
      t.string :code_prefix, null: false   # ex. PETCT, SPECT, ACT (8 caractères max, sans tiret)
      t.datetime :archived_at
      t.timestamps
    end

    add_index :equipment_categories, :name, unique: true
    add_index :equipment_categories, :code_prefix, unique: true
  end
end
