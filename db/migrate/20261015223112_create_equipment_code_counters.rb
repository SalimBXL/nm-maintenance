# Un compteur par couple (catégorie, fabricant) pour le numéro séquentiel
# du code interne : le premier SPECT Siemens est SPECT-SIEM-01 même si
# SPECT-GE-01 existe. Le compteur ne redescend jamais : un numéro n'est
# jamais réutilisé.
class CreateEquipmentCodeCounters < ActiveRecord::Migration[8.0]
  def change
    create_table :equipment_code_counters do |t|
      t.references :category, null: false, foreign_key: { to_table: :equipment_categories }
      t.references :manufacturer, null: false, foreign_key: true
      t.integer :last_number, null: false, default: 0
      t.timestamps
    end

    add_index :equipment_code_counters, %i[category_id manufacturer_id], unique: true
  end
end
