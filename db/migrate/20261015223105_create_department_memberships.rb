class CreateDepartmentMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :department_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true
      t.timestamps
    end

    add_index :department_memberships, %i[user_id department_id], unique: true
  end
end
