# Jetons personnels d'API. Le jeton lui-même n'est jamais stocké : seule son
# empreinte (SHA-256) l'est ; il n'est affiché qu'une fois, à sa création.
class CreateApiTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false          # libellé choisi par l'utilisateur (ex. « Poste labo 2 »)
      t.string :token_digest, null: false
      t.string :hint                       # derniers caractères, pour reconnaître le jeton
      t.datetime :expires_at, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :api_tokens, :token_digest, unique: true
  end
end
