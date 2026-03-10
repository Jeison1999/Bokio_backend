class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :business, null: false, foreign_key: true
      t.integer :plan, null: false, default: 0
      t.decimal :price, precision: 10, scale: 2
      t.integer :max_employees, null: false, default: 2
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.datetime :expires_at

      t.timestamps
    end
  end
end
