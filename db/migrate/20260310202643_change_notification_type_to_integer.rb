class ChangeNotificationTypeToInteger < ActiveRecord::Migration[8.1]
  def up
    # Eliminar datos existentes (son de prueba)
    Notification.delete_all
    
    # Cambiar tipo de columna de string a integer
    change_column :notifications, :notification_type, :integer, using: 'notification_type::integer', null: false
  end
  
  def down
    change_column :notifications, :notification_type, :string
  end
end
