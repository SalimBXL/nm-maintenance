class CreateEquipmentModels < ActiveRecord::Migration[8.0]
  def change
    create_table :equipment_models do |t|
      t.references :manufacturer, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: { to_table: :equipment_categories }
      t.string :name, null: false
      t.datetime :archived_at
      t.timestamps
    end

    add_index :equipment_models, %i[manufacturer_id name], unique: true
  end
end
