class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2, default: 0, null: false
      t.integer :duration, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
  end
end
