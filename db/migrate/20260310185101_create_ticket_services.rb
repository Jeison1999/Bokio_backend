class CreateTicketServices < ActiveRecord::Migration[8.1]
  def change
    create_table :ticket_services do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :ticket_services, [:ticket_id, :service_id], unique: true
  end
end
