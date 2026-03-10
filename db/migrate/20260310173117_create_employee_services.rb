class CreateEmployeeServices < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_services do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :employee_services, [:employee_id, :service_id], unique: true
  end
end
