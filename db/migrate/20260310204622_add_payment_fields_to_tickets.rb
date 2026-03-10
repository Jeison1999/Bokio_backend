class AddPaymentFieldsToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :paid, :boolean, default: false, null: false
    add_column :tickets, :total_amount, :decimal, precision: 10, scale: 2, default: 0.0, null: false
    
    add_index :tickets, :paid
    add_index :tickets, [:business_id, :paid]
    add_index :tickets, [:business_id, :created_at]
  end
end
