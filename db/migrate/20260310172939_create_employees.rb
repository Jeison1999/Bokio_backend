class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.references :business, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :name, null: false
      t.string :email
      t.string :phone
      t.string :avatar_url
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
