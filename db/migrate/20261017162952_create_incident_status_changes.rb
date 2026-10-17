class CreateIncidentStatusChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :incident_status_changes do |t|
      t.references :incident, null: false, foreign_key: true
      t.string :from_status # vide pour la déclaration
      t.string :to_status, null: false
      t.references :user, foreign_key: true
      t.text :comment
      t.timestamps
    end
  end
end
