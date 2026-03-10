class CreateBusinesses < ActiveRecord::Migration[8.1]
  def change
    create_table :businesses do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.text :description
      t.string :slug, null: false
      t.string :address
      t.string :phone
      t.string :logo_url
      t.time :opening_time
      t.time :closing_time
      t.time :break_start_time
      t.time :break_end_time
      t.boolean :active, default: true

      t.timestamps
    end
    add_index :businesses, :slug, unique: true
  end
end
