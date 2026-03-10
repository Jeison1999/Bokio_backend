class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :ticket, null: false, foreign_key: true
      t.string :notification_type, null: false
      t.text :message, null: false
      t.boolean :read, default: false, null: false
      t.datetime :sent_at

      t.timestamps
    end
    
    add_index :notifications, [:user_id, :read]
    add_index :notifications, [:user_id, :created_at]
  end
end
