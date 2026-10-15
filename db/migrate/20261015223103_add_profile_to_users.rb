# Complète la table users créée par `bin/rails generate authentication`.
class AddProfileToUsers < ActiveRecord::Migration[8.0]
  def change
    # Valeurs de role : reporter, technician, technical_manager, admin
    add_column :users, :name, :string, null: false, default: ""
    add_column :users, :role, :string, null: false, default: "reporter"
    # Date de fin de validité (optionnelle) : un utilisateur dont cette date
    # est antérieure à la date du jour est considéré comme non actif.
    add_column :users, :valid_until, :date

    add_index :users, :role
    add_index :users, :valid_until
  end
end
