# MVP de Bokio (funcionalidades mínimas)

# 1️⃣ Sistema de cuentas

Funciones básicas de usuarios.

### Funciones necesarias

- Registro de usuario
- Inicio de sesión
- Recuperar contraseña
- Cerrar sesión
- Autenticación con JWT

### Roles

```
super_admin
admin
employee
client
```

---

# 2️⃣ Gestión de negocios

Para que el dueño cree su negocio.

### Funciones

Crear negocio:

- nombre
- descripción
- dirección
- teléfono
- logo

Editar negocio

Ver negocio

Slug del negocio

Ejemplo:

```
bokio.com/barberia-los-amigos
```

---

# 3️⃣ Gestión de empleados

El admin del negocio debe poder administrar su equipo.

### Funciones

Crear empleado

Campos:

- nombre
- email
- foto
- estado

Estados:

```
available
busy
break
offline
```

Editar empleado

Eliminar empleado

Asignar servicios al empleado

---

# 4️⃣ Gestión de servicios

El negocio define qué ofrece.

### Funciones

Crear servicio

Campos:

- nombre
- precio
- duración

Editar servicio

Eliminar servicio

Asignar servicios a empleados

---

# 5️⃣ Sistema de reservas

El cliente debe poder reservar.

### Funciones

Ver negocios

Ver empleados del negocio

Ver servicios disponibles

Seleccionar:

- empleado
- servicios

Confirmar reserva

---

# 6️⃣ Sistema de tickets

Este es **el corazón de Bokio**.

### Funciones

Crear ticket automáticamente

Ejemplo:

```
Ticket #23
```

Asignar ticket a empleado

Estados del ticket:

```
pending
in_progress
finished
paid
no_show
```

---

# 7️⃣ Panel del empleado

El peluquero necesita ver su trabajo.

### Funciones

Ver cola de turnos

Ver ticket actual

Cambiar estado del ticket

Ejemplo:

```
Pendiente → En proceso → Finalizado
```

Ver lista de clientes del día

---

# 8️⃣ Panel del administrador

El dueño del negocio ve su negocio.

### Funciones

Ver empleados

Ver servicios

Ver tickets

Ver clientes

Marcar ticket como pagado

---

# 9️⃣ Cola en tiempo real

Esto es lo que hace Bokio **interesante**.

### Funciones

Los clientes pueden ver:

```
Turno actual
Turno del cliente
Tiempo estimado
```

Actualización en tiempo real con:

```
WebSockets
```

---

# 🔟 Notificaciones

MVP simple.

Cuando el cliente esté cerca del turno:

```
Falta 1 cliente antes que tú
```

Puede ser:

- push notification
- o solo en la app

---

# 1️⃣1️⃣ Estadísticas básicas

Para el admin.

### Funciones

Servicios realizados hoy

Ingresos del día

Servicios por empleado

---

# 1️⃣2️⃣ Suscripción SaaS (simple)

Para que Bokio gane dinero.

### Funciones

Planes:

```
Basic
Pro
Premium
```

Asignar plan al negocio

Suspender negocio si no paga

---

# 🧠 Funciones que NO necesito en el MVP

Estas son buenas, pero **no son necesarias al inicio**:

❌ pagos online

❌ marketplace de negocios

❌ recomendaciones

❌ inteligencia artificial

❌ marketing automático

❌ CRM avanzado

❌ sistema de reviews

Primero valida el sistema de turnos.