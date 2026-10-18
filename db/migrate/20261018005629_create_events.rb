# Interventions (table « events » de la spécification).
class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.references :equipment, null: false, foreign_key: { to_table: :equipments }
      t.references :incident, foreign_key: true                      # facultatif
      t.references :performed_by, foreign_key: { to_table: :users }  # intervenant
      # event_type : preventive, corrective, quality_control, calibration, software_update
      t.string :event_type, null: false, default: 'corrective'
      # status : planned, in_progress, completed, cancelled
      t.string :status, null: false, default: 'planned'
      t.string :title, null: false
      t.date :scheduled_on
      t.datetime :started_at
      t.datetime :ended_at
      t.string :contractor          # prestataire (texte)
      t.integer :cost_cents         # coût en centimes
      t.integer :downtime_minutes   # durée d'indisponibilité, en minutes
      t.text :report
      t.timestamps
    end

    add_index :events, :status
    add_index :events, :scheduled_on
  end
end
