class CreateDepartments < ActiveRecord::Migration[8.0]
  def change
    create_table :departments do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.references :parent, foreign_key: { to_table: :departments } # vide pour l'instant (un seul niveau)
      t.references :manager, foreign_key: { to_table: :users }
      t.datetime :archived_at
      t.timestamps
    end

    add_index :departments, :code, unique: true
    add_index :departments, :name, unique: true
  end
end
