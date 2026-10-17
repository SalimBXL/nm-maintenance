class CreateEquipments < ActiveRecord::Migration[8.0]
  def change
    create_table :equipments do |t|
      t.string :code, null: false                 # TYPE-FABRICANT-NN, généré, jamais modifié
      t.string :serial_number                     # numéro de série du fabricant
      t.references :equipment_model, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      # Valeurs de status : in_service, out_of_order, under_maintenance, decommissioned
      t.string :status, null: false, default: 'in_service'
      # Valeurs de criticality : low, medium, high (à confirmer)
      t.string :criticality, null: false, default: 'medium'
      t.date :acquired_on
      t.date :commissioned_on
      t.date :warranty_ends_on
      t.date :decommissioned_on
      t.text :notes
      t.datetime :archived_at
      t.timestamps
    end

    add_index :equipments, :code, unique: true
    add_index :equipments, %i[equipment_model_id serial_number], unique: true
    add_index :equipments, :status
  end
end
