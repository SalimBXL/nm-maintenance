class CreateEquipmentMoves < ActiveRecord::Migration[8.0]
  def change
    create_table :equipment_moves do |t|
      t.references :equipment, null: false, foreign_key: { to_table: :equipments }
      t.references :from_location, foreign_key: { to_table: :locations }
      t.references :to_location, null: false, foreign_key: { to_table: :locations }
      t.references :user, foreign_key: true # auteur du déplacement
      t.datetime :moved_at, null: false
      t.timestamps
    end
  end
end
