class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :tickets do |t|
      t.references :business, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: { to_table: :users }
      t.references :employee, null: true, foreign_key: { to_table: :employees }
      t.string :ticket_number, null: false
      t.integer :status, default: 0, null: false
      t.integer :queue_position
      t.integer :estimated_time
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
    
    add_index :tickets, [:business_id, :ticket_number], unique: true
    add_index :tickets, [:business_id, :status]
  end
end
