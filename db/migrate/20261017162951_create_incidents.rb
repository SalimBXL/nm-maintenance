class CreateIncidents < ActiveRecord::Migration[8.0]
  def change
    create_table :incidents do |t|
      t.references :equipment, null: false, foreign_key: { to_table: :equipments }
      t.references :reported_by, null: false, foreign_key: { to_table: :users }
      t.references :assigned_to, foreign_key: { to_table: :users }
      # severity : critical, major, minor
      t.string :severity, null: false, default: 'minor'
      # nature : technical, safety, radiation_protection
      t.string :nature, null: false, default: 'technical'
      # status : declared, qualified, in_progress, resolved, closed
      t.string :status, null: false, default: 'declared'
      t.text :description, null: false
      t.datetime :detected_at, null: false
      t.datetime :resolved_at
      t.datetime :closed_at
      t.text :root_cause
      t.text :corrective_action
      t.boolean :mandatory_declaration, null: false, default: false
      t.timestamps
    end

    add_index :incidents, :status
    add_index :incidents, :severity
  end
end
