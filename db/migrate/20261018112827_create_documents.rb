# Documents techniques, versionnés. Le fichier lui-même est géré par Active
# Storage (tables créées par `bin/rails active_storage:install`).
class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      # Rattaché soit à un équipement, soit à un modèle (jamais aux deux : règle du modèle)
      t.references :equipment, foreign_key: { to_table: :equipments }
      t.references :equipment_model, foreign_key: true
      t.references :uploaded_by, foreign_key: { to_table: :users }
      # Version précédente : une version ne peut être remplacée qu'une seule fois
      t.references :supersedes, foreign_key: { to_table: :documents }, index: { unique: true }
      # document_type : manual, certificate, conformity_declaration, report, procedure, other
      t.string :document_type, null: false, default: 'other'
      t.string :title, null: false
      t.integer :version_number, null: false, default: 1
      t.string :version_label # numéro de version du document (ex. « 2.1 », « rév. B »)
      t.date :valid_until
      t.text :notes
      t.datetime :archived_at
      t.timestamps
    end
  end
end
